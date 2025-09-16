const functions = require('firebase-functions');
const admin = require('firebase-admin');
const AWS = require('aws-sdk');

try { admin.initializeApp(); } catch (e) {}
const db = admin.firestore();

// Server-side cleanup function for chats, announcements, and R2 storage
exports.dailyCleanup = functions.pubsub.schedule('0 2 * * *').timeZone('UTC').onRun(async (context) => {
  console.log('Starting daily cleanup at:', new Date().toISOString());
  await performCleanup('scheduled');
});

// Test cleanup function triggered by Firestore document change
exports.testCleanup = functions.firestore
  .document('app_config/test_cleanup_trigger')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return;
    
    const data = change.after.data();
    if (data.triggerCleanup === true) {
      console.log('Starting test cleanup triggered from UI at:', new Date().toISOString());
      await performCleanup('test');
      
      // Clear the trigger
      await change.after.ref.update({
        triggerCleanup: false,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });

// Main cleanup function used by both scheduled and test triggers
async function performCleanup(triggerType) {
  try {
    // Get cleanup configuration from Firestore
    const configDoc = await db.collection('app_config').doc('cleanup_settings').get();
    const config = configDoc.exists ? configDoc.data() : {};
    
    // Get R2 credentials from Firestore
    const r2Doc = await db.collection('app_config').doc('r2_settings').get();
    const r2Config = r2Doc.exists ? r2Doc.data() : {};
    
    const cleanupRange = config.range || 'daily'; // daily, weekly, monthly
    const includeChats = config.includeChats !== false;
    const includeAnnouncements = config.includeAnnouncements !== false;
    const includeR2Storage = config.r2CleanupEnabled === true;
    
    let deletedChats = 0;
    let deletedAnnouncements = 0;
    let deletedR2Files = 0;
    
    // Calculate date range based on cleanup frequency
    const now = new Date();
    let cutoffDate;
    
    switch (cleanupRange) {
      case 'weekly':
        cutoffDate = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
        break;
      case 'monthly':
        cutoffDate = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
        break;
      default: // daily
        cutoffDate = new Date(now.getTime() - (24 * 60 * 60 * 1000));
        break;
    }
    
    console.log(`Cleanup range: ${cleanupRange}, cutoff date: ${cutoffDate.toISOString()}`);
    
    // Delete old chats
    if (includeChats) {
      const chatsQuery = db.collection('chats').where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoffDate));
      const chatsSnapshot = await chatsQuery.get();
      
      const chatBatch = db.batch();
      chatsSnapshot.docs.forEach(doc => {
        chatBatch.delete(doc.ref);
        deletedChats++;
      });
      
      if (deletedChats > 0) {
        await chatBatch.commit();
        console.log(`Deleted ${deletedChats} chat messages`);
      }
    }
    
    // Delete old announcements (only from communications collection)
    if (includeAnnouncements) {
      const announcementsQuery = db.collection('communications').where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoffDate));
      const announcementsSnapshot = await announcementsQuery.get();
      
      const announcementsBatch = db.batch();
      announcementsSnapshot.docs.forEach(doc => {
        announcementsBatch.delete(doc.ref);
        deletedAnnouncements++;
      });
      
      if (deletedAnnouncements > 0) {
        await announcementsBatch.commit();
        console.log(`Deleted ${deletedAnnouncements} announcements`);
      }
    }
    
    // Delete old R2 storage files
    if (includeR2Storage && r2Config.accessKeyId && r2Config.secretAccessKey) {
      try {
        deletedR2Files = await cleanupR2Storage(cutoffDate, r2Config);
        console.log(`Deleted ${deletedR2Files} files from R2 storage`);
      } catch (r2Error) {
        console.error('R2 cleanup failed:', r2Error);
      }
    }
    
    // Log cleanup status to Firestore
    await db.collection('cleanup_logs').add({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: `server_cleanup_${triggerType}`,
      range: cleanupRange,
      deletedChats,
      deletedAnnouncements,
      deletedR2Files,
      cutoffDate: admin.firestore.Timestamp.fromDate(cutoffDate),
      success: true
    });
    
    console.log(`${triggerType} cleanup completed: ${deletedChats} chats, ${deletedAnnouncements} announcements, ${deletedR2Files} R2 files deleted`);
    
  } catch (error) {
    console.error(`${triggerType} cleanup failed:`, error);
    
    // Log error to Firestore
    await db.collection('cleanup_logs').add({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: `server_cleanup_${triggerType}`,
      success: false,
      error: error.message
    });
  }
}

// Helper function to cleanup R2 storage using credentials from Firestore
async function cleanupR2Storage(cutoffDate, r2Config) {
  // Configure R2/S3 client with credentials from Firestore
  const endpoint = r2Config.endpoint || (r2Config.accountId ? `https://${r2Config.accountId}.r2.cloudflarestorage.com` : 'https://your-account-id.r2.cloudflarestorage.com');
  
  const s3 = new AWS.S3({
    endpoint: endpoint,
    accessKeyId: r2Config.accessKeyId,
    secretAccessKey: r2Config.secretAccessKey,
    region: 'auto',
    signatureVersion: 'v4'
  });

  const BUCKET_NAME = r2Config.bucketName || 'your-bucket-name';
  
  let deletedCount = 0;
  let continuationToken = null;

  console.log('Starting COMPLETE R2 cleanup - deleting ALL files, folders, images, videos, thumbnails');

  do {
    const params = {
      Bucket: BUCKET_NAME,
      MaxKeys: 1000
    };

    if (continuationToken) {
      params.ContinuationToken = continuationToken;
    }

    try {
      const response = await s3.listObjectsV2(params).promise();
      
      if (response.Contents && response.Contents.length > 0) {
        // Delete ALL objects - no date filtering
        const allObjects = response.Contents.map(obj => ({ Key: obj.Key }));
        
        console.log(`Found ${allObjects.length} objects to delete in this batch`);

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

            const result = await s3.deleteObjects(deleteParams).promise();
            deletedCount += result.Deleted ? result.Deleted.length : 0;
            
            console.log(`Deleted ${result.Deleted ? result.Deleted.length : 0} objects in this chunk`);

            if (result.Errors && result.Errors.length > 0) {
              console.error('R2 delete errors:', result.Errors);
            }
          }
        }
      }

      continuationToken = response.NextContinuationToken;
    } catch (error) {
      console.error('Error during R2 cleanup:', error);
      break;
    }
  } while (continuationToken);

  console.log(`COMPLETE R2 cleanup finished - deleted ${deletedCount} total files`);
  return deletedCount;
}
