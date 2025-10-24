const functions = require('firebase-functions');
const admin = require('firebase-admin');
const AWS = require('aws-sdk');

try { admin.initializeApp(); } catch (e) {}
const db = admin.firestore();

// Import the createFirebaseProject function
const { createFirebaseProject } = require('./createFirebaseProject');
exports.createFirebaseProject = createFirebaseProject;

// Import the verifyAndFetchFirebaseConfig function
const { verifyAndFetchFirebaseConfig } = require('./verifyAndFetchFirebaseConfig');
exports.verifyAndFetchFirebaseConfig = verifyAndFetchFirebaseConfig;

// Import the listUserFirebaseProjects function (exports itself directly)
const listUserProjectsModule = require('./listUserFirebaseProjects');
exports.listUserFirebaseProjects = listUserProjectsModule.listUserFirebaseProjects;

// Import the autoConfigureFirebaseProject function (exports itself directly)
const autoConfigureModule = require('./autoConfigureFirebaseProject');
exports.autoConfigureFirebaseProject = autoConfigureModule.autoConfigureFirebaseProject;

// Import the autoCreateAppsAndFetchConfig function (NEW - Auto-creates apps + fetches keys)
const { autoCreateAppsAndFetchConfig } = require('./autoCreateAppsAndFetchConfig');
exports.autoCreateAppsAndFetchConfig = autoCreateAppsAndFetchConfig;

// Server-side cleanup function for chats, announcements, and R2 storage
// Fixed to run daily at 2AM UTC - no custom scheduling to reduce function triggers
exports.dailyCleanup = functions.pubsub.schedule('0 2 * * *').timeZone('UTC').onRun(async (context) => {
  console.log('Starting daily cleanup at 2AM UTC:', new Date().toISOString());
  
  // Get cleanup configuration
  const configDoc = await db.collection('app_config').doc('cleanup_settings').get();
  const config = configDoc.exists ? configDoc.data() : {};
  
  const lastRun = config.lastScheduledRun;
  const now = new Date();
  
  console.log('Daily cleanup running at fixed 2AM UTC schedule');
  
  // Always run at 2AM - no custom time checking needed
  
  // Always run daily cleanup at 2AM
  console.log('✅ Running daily cleanup at fixed 2AM UTC schedule');
  
  // Update last run timestamp before starting
  await db.collection('app_config').doc('cleanup_settings').update({
    lastScheduledRun: admin.firestore.FieldValue.serverTimestamp(),
    lastScheduledStatus: 'running'
  });
  
  try {
    await performCleanup('scheduled');
    
    // Update status to success
    await db.collection('app_config').doc('cleanup_settings').update({
      lastScheduledStatus: 'completed',
      lastScheduledCompletedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ Daily cleanup completed successfully at 2AM UTC');
  } catch (error) {
    console.error('❌ Daily cleanup failed:', error);
    
    // Update status to error
    await db.collection('app_config').doc('cleanup_settings').update({
      lastScheduledStatus: 'error',
      lastScheduledError: error.message,
      lastScheduledErrorAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
});

// Test cleanup function triggered by Firestore document change
exports.testCleanup = functions.firestore
  .document('app_config/test_cleanup_trigger')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return;
    
    const data = change.after.data();
    const prevData = change.before.exists ? change.before.data() : {};
    
    console.log('Test cleanup document changed:', JSON.stringify(data, null, 2));
    
    // Check if we should trigger cleanup
    let shouldTrigger = false;
    let triggerReason = '';
    
    // Method 1: Explicit trigger from app
    if (data.triggerCleanup === true && prevData.triggerCleanup !== true) {
      shouldTrigger = true;
      triggerReason = 'triggerCleanup set to true';
    }
    
    // Method 2: includeR2Storage was set to true (and it's not already processing)
    if (data.includeR2Storage === true && !data.processing && !prevData.includeR2Storage) {
      shouldTrigger = true;
      triggerReason = 'includeR2Storage enabled';
    }
    
    // Method 3: timestamp changed with R2 storage enabled (manual trigger)
    if (data.includeR2Storage === true && !data.processing && 
        data.timestamp && (!prevData.timestamp || 
        data.timestamp._seconds !== prevData.timestamp?._seconds)) {
      shouldTrigger = true;
      triggerReason = 'timestamp updated with R2 enabled';
    }
    
    if (shouldTrigger) {
      console.log(`✅ Test cleanup triggering: ${triggerReason} at:`, new Date().toISOString());
      
      // Immediately mark as processing to prevent re-triggering
      await change.after.ref.update({
        triggerCleanup: false,
        processing: true,
        startedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      try {
        await performCleanup('test', data);
        
        // Mark as completed
        await change.after.ref.update({
          processing: false,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastResult: 'success'
        });
        
        console.log('✅ Test cleanup completed successfully');
      } catch (error) {
        console.error('❌ Test cleanup failed:', error);
        await change.after.ref.update({
          processing: false,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastResult: 'error',
          lastError: error.message
        });
      }
    } else {
      console.log('ℹ️ Skipping trigger - no valid trigger condition met');
    }
  });

// Main cleanup function used by both scheduled and test triggers
async function performCleanup(triggerType, triggerData = null) {
  let statusMessage = '';
  let overallSuccess = true;
  
  try {
    // Update status: Starting cleanup
    await updateCleanupStatus('starting', `Starting ${triggerType} cleanup...`, triggerType);
    
    // Get cleanup configuration from Firestore
    const configDoc = await db.collection('app_config').doc('cleanup_settings').get();
    const config = configDoc.exists ? configDoc.data() : {};
    
    // Get R2 credentials from Firestore
    const r2Doc = await db.collection('app_config').doc('r2_settings').get();
    const r2Config = r2Doc.exists ? r2Doc.data() : {};
    
    // Determine cleanup range based on frequency setting
    const frequency = config.frequency || 'daily';
    let cleanupRange;
    
    // Map frequency to cleanup range for backwards compatibility
    switch (frequency) {
      case 'daily':
        cleanupRange = 'daily';
        break;
      case 'weekly':
        cleanupRange = 'weekly';
        break;
      case 'monthly':
        cleanupRange = 'monthly';
        break;
      case 'custom':
        // For custom frequency, use the range setting or default to daily
        cleanupRange = config.range || 'daily';
        break;
      default:
        cleanupRange = config.range || 'daily';
        break;
    }
    
    console.log(`Cleanup configuration: frequency=${frequency}, range=${cleanupRange}, triggered by=${triggerType}`);
    
    // For test cleanup, use trigger data if available, otherwise use config
    let includeChats, includeAnnouncements, includeR2Storage;
    
    if (triggerType === 'test' && triggerData) {
      includeChats = triggerData.includeFirebase !== false;
      includeAnnouncements = triggerData.includeFirebase !== false;
      includeR2Storage = triggerData.includeR2Storage === true;
      console.log('Using trigger data for test cleanup:', {
        includeChats,
        includeAnnouncements,
        includeR2Storage
      });
    } else {
      // For scheduled cleanup, check both old and new config formats
      includeChats = config.includeChats !== false && config.includeFirebase !== false;
      includeAnnouncements = config.includeAnnouncements !== false && config.includeFirebase !== false;
      includeR2Storage = config.includeR2Storage === true;
      console.log('Using config data for cleanup:', {
        includeChats,
        includeAnnouncements,
        includeR2Storage,
        frequency,
        range: cleanupRange
      });
    }
    
    let deletedChats = 0;
    let deletedAnnouncements = 0;
    let deletedR2Files = 0;
    
    // Calculate date range based on cleanup frequency/range
    const now = new Date();
    let cutoffDate;
    
    if (triggerType === 'test') {
      // For test cleanup, we might want to delete everything
      cutoffDate = new Date(now.getTime() - (24 * 60 * 60 * 1000)); // Default to 24 hours for test
    } else {
      // For scheduled cleanup, use the configured range
      switch (cleanupRange) {
        case 'weekly':
          cutoffDate = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
          break;
        case 'monthly':
          cutoffDate = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
          break;
        case 'custom':
          // For custom range, use customDays if specified
          const customDays = config.customDays || 1;
          cutoffDate = new Date(now.getTime() - (customDays * 24 * 60 * 60 * 1000));
          break;
        default: // daily
          cutoffDate = new Date(now.getTime() - (24 * 60 * 60 * 1000));
          break;
      }
    }
    
    console.log(`Cleanup configuration: trigger=${triggerType}, range=${cleanupRange}, cutoff=${cutoffDate.toISOString()}`);
    if (config.customDays) {
      console.log(`Custom cleanup days: ${config.customDays}`);
    }
    
    // Update status: Processing Firebase data
    await updateCleanupStatus('processing', 'Processing Firebase chats and announcements...', triggerType);
    
    // Delete old chats
    if (includeChats) {
      // For test cleanup, delete ALL chats regardless of date
      const chatsQuery = triggerType === 'test' 
        ? db.collection('chats') 
        : db.collection('chats').where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoffDate));
      
      const chatsSnapshot = await chatsQuery.get();
      
      const chatBatch = db.batch();
      chatsSnapshot.docs.forEach(doc => {
        chatBatch.delete(doc.ref);
        deletedChats++;
      });
      
      if (deletedChats > 0) {
        await chatBatch.commit();
        console.log(`Deleted ${deletedChats} chat messages`);
        await updateCleanupStatus('processing', `✅ Firebase: Deleted ${deletedChats} chat messages`, triggerType);
      } else {
        await updateCleanupStatus('processing', `✅ Firebase: No chat messages to delete`, triggerType);
      }
    }
    
    // Delete old announcements (only from communications collection)
    if (includeAnnouncements) {
      // For test cleanup, delete ALL communications regardless of date
      const announcementsQuery = triggerType === 'test'
        ? db.collection('communications')
        : db.collection('communications').where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoffDate));
      
      const announcementsSnapshot = await announcementsQuery.get();
      
      const announcementsBatch = db.batch();
      announcementsSnapshot.docs.forEach(doc => {
        announcementsBatch.delete(doc.ref);
        deletedAnnouncements++;
      });
      
      if (deletedAnnouncements > 0) {
        await announcementsBatch.commit();
        console.log(`Deleted ${deletedAnnouncements} announcements`);
        await updateCleanupStatus('processing', `✅ Firebase: Deleted ${deletedAnnouncements} announcements`, triggerType);
      } else {
        await updateCleanupStatus('processing', `✅ Firebase: No announcements to delete`, triggerType);
      }
    }
    
    console.log('=== DEBUG INFO ===');
    console.log('Config:', JSON.stringify(config, null, 2));
    console.log('R2 Config:', JSON.stringify(r2Config, null, 2));
    console.log('includeR2Storage:', includeR2Storage);
    console.log('r2Config.accessKeyId exists:', !!r2Config.accessKeyId);
    console.log('r2Config.secretAccessKey exists:', !!r2Config.secretAccessKey);
    console.log('=================');
    
    // Delete old R2 storage files
    if (includeR2Storage && r2Config.accessKeyId && r2Config.secretAccessKey) {
      console.log('Starting R2 cleanup process...');
      try {
        await updateCleanupStatus('processing', 'Processing R2 storage cleanup...', triggerType);
        deletedR2Files = await cleanupR2Storage(cutoffDate, r2Config, triggerType);
        console.log(`Deleted ${deletedR2Files} files from R2 storage`);
        await updateCleanupStatus('processing', `✅ R2 Storage: Deleted ${deletedR2Files} files (ALL files cleared)`, triggerType);
      } catch (r2Error) {
        console.error('R2 cleanup failed:', r2Error);
        await updateCleanupStatus('processing', `❌ R2 Storage: Cleanup failed - ${r2Error.message}`, triggerType);
        overallSuccess = false;
      }
    } else {
      console.log('R2 cleanup skipped. Reasons:');
      console.log('- includeR2Storage:', includeR2Storage);
      console.log('- accessKeyId present:', !!r2Config.accessKeyId);
      console.log('- secretAccessKey present:', !!r2Config.secretAccessKey);
      
      if (includeR2Storage) {
        await updateCleanupStatus('processing', `⚠️ R2 Storage: Cleanup enabled but credentials missing`, triggerType);
      } else {
        await updateCleanupStatus('processing', `ℹ️ R2 Storage: Cleanup disabled`, triggerType);
      }
    }
    
    // Final status update
    const finalMessage = overallSuccess 
      ? `🎉 Cleanup completed successfully! Firebase: ${deletedChats + deletedAnnouncements} items, R2: ${deletedR2Files} files`
      : `⚠️ Cleanup completed with some errors. Firebase: ${deletedChats + deletedAnnouncements} items, R2: ${deletedR2Files} files`;
    
    await updateCleanupStatus('completed', finalMessage, triggerType);
    
    // Log cleanup status to Firestore
    await db.collection('cleanup_logs').add({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: `server_cleanup_${triggerType}`,
      frequency: config.frequency || 'daily',
      range: cleanupRange,
      deletedChats,
      deletedAnnouncements,
      deletedR2Files,
      cutoffDate: admin.firestore.Timestamp.fromDate(cutoffDate),
      success: overallSuccess,
      configSnapshot: {
        includeChats: config.includeChats,
        includeAnnouncements: config.includeAnnouncements,
        includeR2Storage: config.includeR2Storage,
        customDays: config.customDays,
        scheduledTime: config.scheduledTime
      }
    });
    
    console.log(`${triggerType} cleanup completed: ${deletedChats} chats, ${deletedAnnouncements} announcements, ${deletedR2Files} R2 files deleted`);
    return { deletedChats, deletedAnnouncements, deletedR2Files, success: overallSuccess };
    
  } catch (error) {
    console.error(`${triggerType} cleanup failed:`, error);
    await updateCleanupStatus('error', `❌ Cleanup failed: ${error.message}`, triggerType);
    
    // Log error to Firestore
    await db.collection('cleanup_logs').add({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: `server_cleanup_${triggerType}`,
      frequency: config.frequency || 'daily',
      range: cleanupRange || 'daily',
      success: false,
      error: error.message
    });
    
    throw error;
  }
}

// Helper function to cleanup R2 storage using credentials from Firestore
async function cleanupR2Storage(cutoffDate, r2Config) {
  console.log('=== R2 CLEANUP START ===');
  console.log('R2 Config received:', {
    endpoint: r2Config.endpoint,
    accountId: r2Config.accountId,
    bucketName: r2Config.bucketName,
    hasAccessKey: !!r2Config.accessKeyId,
    hasSecretKey: !!r2Config.secretAccessKey
  });

  // Configure R2/S3 client with credentials from Firestore
  const endpoint = r2Config.endpoint || (r2Config.accountId ? `https://${r2Config.accountId}.r2.cloudflarestorage.com` : 'https://your-account-id.r2.cloudflarestorage.com');
  
  console.log('Using endpoint:', endpoint);
  
  const s3 = new AWS.S3({
    endpoint: endpoint,
    accessKeyId: r2Config.accessKeyId,
    secretAccessKey: r2Config.secretAccessKey,
    region: 'auto',
    signatureVersion: 'v4'
  });

  const BUCKET_NAME = r2Config.bucketName || 'your-bucket-name';
  console.log('Using bucket:', BUCKET_NAME);
  
  let deletedCount = 0;
  let continuationToken = null;

  console.log('Starting R2 cleanup - deleting files from specific folders (excluding currentPageBackgroundImage)');
  
  // Define folders to clean (exclude currentPageBackgroundImage)
  // Support both legacy flat structure and new school-specific structure
  const foldersToClean = [
    'images/', 'videos/', 'thumbnails/', 'pdfs/', 'documents/',  // Legacy
    'schools/'  // New school-specific structure (will clean all schools)
  ];
  console.log('Folders to clean:', foldersToClean);

  try {
    // Clean each folder separately
    for (const folder of foldersToClean) {
      console.log(`\n=== Cleaning folder: ${folder} ===`);
      continuationToken = null;
      
      do {
        const params = {
          Bucket: BUCKET_NAME,
          Prefix: folder,  // Only list objects in this folder
          MaxKeys: 1000
        };

        if (continuationToken) {
          params.ContinuationToken = continuationToken;
        }

        console.log(`Listing objects in ${folder} with params:`, JSON.stringify(params, null, 2));
        
        try {
          const response = await s3.listObjectsV2(params).promise();
          console.log(`List response for ${folder}:`, {
            KeyCount: response.KeyCount,
            IsTruncated: response.IsTruncated,
            NextContinuationToken: response.NextContinuationToken
          });
          
          if (response.Contents && response.Contents.length > 0) {
            const allObjects = response.Contents.map(obj => ({ Key: obj.Key }));
            
            console.log(`Found ${allObjects.length} objects to delete in ${folder}:`);
            allObjects.slice(0, 5).forEach((obj, index) => {
              console.log(`  ${index + 1}. ${obj.Key}`);
            });
            if (allObjects.length > 5) {
              console.log(`  ... and ${allObjects.length - 5} more`);
            }

            if (allObjects.length > 0) {
              // S3 allows up to 1000 objects per delete request
              const chunks = [];
              for (let i = 0; i < allObjects.length; i += 1000) {
                chunks.push(allObjects.slice(i, i + 1000));
              }

              for (const chunk of chunks) {
                const deleteParams = {
                  Bucket: BUCKET_NAME,
                  Delete: {
                    Objects: chunk,
                    Quiet: false
                  }
                };

                console.log(`Attempting to delete ${chunk.length} objects from ${folder}...`);
                const result = await s3.deleteObjects(deleteParams).promise();
                deletedCount += result.Deleted ? result.Deleted.length : 0;
                
                console.log(`Successfully deleted ${result.Deleted ? result.Deleted.length : 0} objects from ${folder}`);

                if (result.Errors && result.Errors.length > 0) {
                  console.error(`R2 delete errors in ${folder}:`);
                  result.Errors.forEach((error, index) => {
                    console.error(`  ❌ Error deleting ${error.Key}: ${error.Code} - ${error.Message}`);
                  });
                }
              }
            }
          } else {
            console.log(`No objects found in ${folder}`);
          }

          continuationToken = response.NextContinuationToken;
        } catch (listError) {
          console.error(`Error listing R2 objects in ${folder}:`, listError);
          throw listError;
        }
      } while (continuationToken);
      
      console.log(`=== Finished cleaning folder: ${folder} ===`);
    }

    console.log(`\nR2 cleanup completed - deleted ${deletedCount} total files (currentPageBackgroundImage folder excluded)`);
    console.log('=== R2 CLEANUP END ===');
    return deletedCount;
    
  } catch (error) {
    console.error('R2 cleanup failed with error:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      stack: error.stack
    });
    throw error;
  }
}

// Helper function to update cleanup status in real-time
async function updateCleanupStatus(status, message, triggerType = 'scheduled') {
  try {
    const statusDoc = triggerType === 'test' ? 'test_status' : 'scheduled_status';
    await db.collection('cleanup_status').doc(statusDoc).set({
      status: status,
      message: message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      triggerType: triggerType
    }, { merge: true });
  } catch (error) {
    console.error('Failed to update cleanup status:', error);
  }
}
