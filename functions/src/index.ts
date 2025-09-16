import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();

// When an announcement is created, send FCM to topic 'all'
export const onAnnouncementCreated = functions.firestore
  .document('communications/{docId}')
  .onCreate(async (snap, _ctx) => {
    const data = snap.data();
    const message: admin.messaging.Message = {
      topic: 'all',
      notification: {
        title: data.senderName || 'New Announcement',
        body: data.message || '',
      },
      android: {
        notification: { channelId: 'announcements_channel', priority: 'high' },
      },
      apns: {
        payload: {
          aps: { sound: 'default' },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      return null;
    } catch (e) {
      console.error('FCM send failed', e);
      return null;
    }
  });

// Optional: queue-based trigger
export const onNotificationQueued = functions.firestore
  .document('notificationQueue/{docId}')
  .onCreate(async (snap, _ctx) => {
    const data = snap.data();
    const message: admin.messaging.Message = {
      topic: data.topic || 'all',
      notification: {
        title: data.title || 'Notification',
        body: data.body || '',
      },
      android: {
        notification: { channelId: 'announcements_channel', priority: 'high' },
      },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    };

    try {
      await admin.messaging().send(message);
      return null;
    } catch (e) {
      console.error('FCM send failed', e);
      return null;
    }
  });
