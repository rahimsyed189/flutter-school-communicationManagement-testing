#!/usr/bin/env node

const AWS = require('aws-sdk');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./firebase-service-account.json'); // You need to download this from Firebase Console
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// R2/S3 Configuration
const s3 = new AWS.S3({
  endpoint: process.env.R2_ENDPOINT || 'https://your-account-id.r2.cloudflarestorage.com',
  accessKeyId: process.env.R2_ACCESS_KEY_ID,
  secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
  region: 'auto',
  signatureVersion: 'v4'
});

const BUCKET_NAME = process.env.R2_BUCKET_NAME || 'your-bucket-name';

async function getCleanupSettings() {
  try {
    const doc = await db.collection('app_config').doc('cleanup_settings').get();
    if (doc.exists) {
      return doc.data();
    }
    return { r2CleanupEnabled: false, range: 'daily' };
  } catch (error) {
    console.error('Error getting cleanup settings:', error);
    return { r2CleanupEnabled: false, range: 'daily' };
  }
}

async function getCutoffDate(range) {
  const now = new Date();
  switch (range) {
    case 'weekly':
      return new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
    case 'monthly':
      return new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
    default: // daily
      return new Date(now.getTime() - (24 * 60 * 60 * 1000));
  }
}

async function listOldObjects(cutoffDate) {
  const params = {
    Bucket: BUCKET_NAME,
    MaxKeys: 1000
  };

  const oldObjects = [];
  let continuationToken = null;

  do {
    if (continuationToken) {
      params.ContinuationToken = continuationToken;
    }

    try {
      const response = await s3.listObjectsV2(params).promise();
      
      if (response.Contents) {
        for (const obj of response.Contents) {
          if (obj.LastModified && obj.LastModified < cutoffDate) {
            oldObjects.push({ Key: obj.Key });
          }
        }
      }

      continuationToken = response.NextContinuationToken;
    } catch (error) {
      console.error('Error listing objects:', error);
      break;
    }
  } while (continuationToken);

  return oldObjects;
}

async function deleteObjects(objects) {
  if (objects.length === 0) return 0;

  // S3 allows up to 1000 objects per delete request
  const chunks = [];
  for (let i = 0; i < objects.length; i += 1000) {
    chunks.push(objects.slice(i, i + 1000));
  }

  let totalDeleted = 0;

  for (const chunk of chunks) {
    try {
      const deleteParams = {
        Bucket: BUCKET_NAME,
        Delete: {
          Objects: chunk,
          Quiet: false
        }
      };

      const result = await s3.deleteObjects(deleteParams).promise();
      totalDeleted += result.Deleted ? result.Deleted.length : 0;

      if (result.Errors && result.Errors.length > 0) {
        console.error('Delete errors:', result.Errors);
      }
    } catch (error) {
      console.error('Error deleting objects:', error);
    }
  }

  return totalDeleted;
}

async function logCleanupStatus(success, deletedCount, error = null) {
  try {
    await db.collection('cleanup_logs').add({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: 'r2_cleanup',
      success,
      deletedFiles: deletedCount || 0,
      error: error ? error.message : null
    });
  } catch (logError) {
    console.error('Error logging cleanup status:', logError);
  }
}

async function main() {
  console.log('Starting R2 cleanup at:', new Date().toISOString());

  try {
    // Get cleanup configuration
    const settings = await getCleanupSettings();
    
    if (!settings.r2CleanupEnabled) {
      console.log('R2 cleanup is disabled in settings');
      await logCleanupStatus(true, 0);
      return;
    }

    const cutoffDate = await getCutoffDate(settings.range || 'daily');
    console.log(`Cleanup range: ${settings.range}, cutoff date: ${cutoffDate.toISOString()}`);

    // List old objects
    const oldObjects = await listOldObjects(cutoffDate);
    console.log(`Found ${oldObjects.length} objects older than cutoff date`);

    if (oldObjects.length === 0) {
      console.log('No objects to delete');
      await logCleanupStatus(true, 0);
      return;
    }

    // Delete old objects
    const deletedCount = await deleteObjects(oldObjects);
    console.log(`Successfully deleted ${deletedCount} objects from R2 storage`);

    await logCleanupStatus(true, deletedCount);

  } catch (error) {
    console.error('R2 cleanup failed:', error);
    await logCleanupStatus(false, 0, error);
  }
}

// Run the cleanup
main().then(() => {
  console.log('R2 cleanup completed');
  process.exit(0);
}).catch((error) => {
  console.error('R2 cleanup failed:', error);
  process.exit(1);
});
