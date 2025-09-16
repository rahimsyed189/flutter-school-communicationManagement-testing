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

// Helper to chunk arrays
const chunk = (arr, size) => arr.reduce((acc, _, i) => (i % size ? acc : [...acc, arr.slice(i, i + size)]), []);

// Helper: collect tokens for a set of userIds (uses users.fcmToken and users/{id}/devices)
async function collectTokensForUsers(userIds) {
  const tokensSet = new Set();
  const batches = chunk(userIds, 10);
  for (const b of batches) {
    if (!b || b.length === 0) continue;
    const snapUsers = await db.collection('users').where('userId', 'in', b).get();
    for (const doc of snapUsers.docs) {
      const u = doc.data() || {};
      const tk = String(u.fcmToken || '');
      if (tk) tokensSet.add(tk);
      try {
        const devs = await doc.ref.collection('devices').where('enabled', '==', true).get();
        for (const d of devs.docs) {
          const t = String((d.data() || {}).token || d.id || '');
          if (t) tokensSet.add(t);
        }
      } catch (e) {}
    }
  }
  return Array.from(tokensSet);
}

// Helper: collect tokens for all users (optionally excluding some userIds)
async function collectTokensForAllUsers(excludeUserIds = []) {
  const tokensSet = new Set();
  const exclude = new Set(excludeUserIds);
  const snap = await db.collection('users').get();
  for (const doc of snap.docs) {
    const u = doc.data() || {};
    const userId = String(u.userId || '');
    if (userId && exclude.has(userId)) continue;
    const tk = String(u.fcmToken || '');
    if (tk) tokensSet.add(tk);
    try {
      const devs = await doc.ref.collection('devices').where('enabled', '==', true).get();
      for (const d of devs.docs) {
        const t = String((d.data() || {}).token || d.id || '');
        if (t) tokensSet.add(t);
      }
    } catch (e) {}
  }
  return Array.from(tokensSet);
}

// Notify group members (by per-user FCM tokens) when a new message is created
exports.onGroupMessageCreate = functions.firestore
  .document('groups/{groupId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const { groupId } = context.params;
    const data = snap.data() || {};
  const sender = String(data.sender || '');
    const message = String(data.message || '');

    // Fetch group name for nicer title
    let groupName = 'Group';
    let members = [];
    try {
      const groupDoc = await db.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        const g = groupDoc.data() || {};
        groupName = String(g.name || g.groupName || 'Group');
        if (Array.isArray(g.members)) {
          members = g.members.map((m) => String(m || '')).filter((m) => m);
        }
      }
    } catch (_) {}

    const title = `New message in ${groupName}`;
    const body = message.length > 0 ? message : 'Open to view the message';

  // Collect target userIds (include sender too so single-device tests receive notifications)
  const targetUserIds = members.filter((u) => u);

    // Fetch user docs by userId in batches of 10 (Firestore in operator limit)
    let tokensSet = new Set();
    try {
      const arr = await collectTokensForUsers(targetUserIds);
      for (const t of arr) tokensSet.add(t);
    } catch (e) {
      console.error('Error fetching user tokens', e);
    }

  const allTokens = Array.from(tokensSet);

    const msgData = {
      type: 'group',
      groupId: groupId,
      groupName: groupName,
    };

    // FCM multicast limit is 500 tokens per request
    if (allTokens.length > 0) {
      const tokenBatches = chunk(allTokens, 500);
      for (const tb of tokenBatches) {
        try {
          const res = await admin.messaging().sendMulticast({
            tokens: tb,
            notification: { title, body },
            data: msgData,
            android: { priority: 'high' },
            apns: { headers: { 'apns-priority': '10' } },
          });
          console.log('Sent group message notification to', tb.length, 'tokens. Success:', res.successCount, 'Fail:', res.failureCount);
        } catch (err) {
          console.error('Failed sending to tokens batch', err);
        }
      }
    } else {
      console.log('No tokens to notify for group', groupId);
    }

    // Fallback: also publish to topic for legacy clients
    try {
      await admin.messaging().send({
        topic: `group_${groupId}`,
        notification: { title, body },
        data: msgData,
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10' } },
      });
      console.log('Published group notification to topic group_' + groupId);
    } catch (err) {
      console.error('Failed sending group topic fallback', err);
    }

    return null;
  });

// Notify all users (by per-user tokens) when a new announcement is created
exports.onAnnouncementCreate = functions.firestore
  .document('communications/{announcementId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
  const senderId = String(data.senderId || '');
    const body = String(data.message || 'New announcement');
    const title = 'New Announcement';

    let tokens = [];
    try {
      // Include sender too so they also get the notification
      tokens = await collectTokensForAllUsers([]);
    } catch (e) {
      console.error('Error collecting tokens for announcements', e);
    }
  if (!tokens) tokens = [];

    const msgData = { type: 'announcement' };
    if (tokens.length > 0) {
      for (const tb of chunk(tokens, 500)) {
        try {
          const res = await admin.messaging().sendMulticast({
            tokens: tb,
            notification: { title, body },
            data: msgData,
            android: { priority: 'high' },
            apns: { headers: { 'apns-priority': '10' } },
          });
          console.log('Sent announcement notification to', tb.length, 'tokens. Success:', res.successCount, 'Fail:', res.failureCount);
        } catch (err) {
          console.error('Failed sending announcement to tokens batch', err);
        }
      }
    } else {
      console.log('No tokens found for announcements; relying on topic fallback');
    }

    // Fallback: also publish to topic 'all'
    try {
      await admin.messaging().send({
        topic: 'all',
        notification: { title, body },
        data: msgData,
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10' } },
      });
      console.log('Published announcement to topic all');
    } catch (err) {
      console.error('Failed sending announcement topic fallback', err);
    }
    return null;
  });

// Notify all other users for messages in global chat collection 'chats'
exports.onChatMessageCreate = functions.firestore
  .document('chats/{messageId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
  const sender = String(data.sender || '');
    const message = String(data.message || 'New message');
    const title = 'New chat message';
    let tokens = [];
    try {
      // Include sender too so they also get the notification
      tokens = await collectTokensForAllUsers([]);
    } catch (e) {
      console.error('Error collecting tokens for chat', e);
    }
  if (!tokens) tokens = [];

    const msgData = { type: 'chat' };
    if (tokens.length > 0) {
      for (const tb of chunk(tokens, 500)) {
        try {
          const res = await admin.messaging().sendMulticast({
            tokens: tb,
            notification: { title, body: message },
            data: msgData,
            android: { priority: 'high' },
            apns: { headers: { 'apns-priority': '10' } },
          });
          console.log('Sent chat notification to', tb.length, 'tokens. Success:', res.successCount, 'Fail:', res.failureCount);
        } catch (err) {
          console.error('Failed sending chat to tokens batch', err);
        }
      }
    } else {
      console.log('No tokens found for chat; relying on topic fallback');
    }

    // Fallback: also publish to topic 'all'
    try {
      await admin.messaging().send({
        topic: 'all',
        notification: { title, body: message },
        data: msgData,
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10' } },
      });
      console.log('Published chat to topic all');
    } catch (err) {
      console.error('Failed sending chat topic fallback', err);
    }
    return null;
  });
