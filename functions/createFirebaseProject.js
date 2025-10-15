const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');
const cors = require('cors')({ origin: true });

/**
 * Cloud Function to automatically create a Firebase project for a user
 * using their Google OAuth token
 */
exports.createFirebaseProject = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
      const { accessToken, projectId, displayName } = req.body;

      if (!accessToken || !projectId || !displayName) {
        return res.status(400).json({
          error: 'Missing required fields: accessToken, projectId, displayName'
        });
      }

      // Initialize OAuth2 client with user's token
      const oauth2Client = new google.auth.OAuth2();
      oauth2Client.setCredentials({ access_token: accessToken });

      // Initialize Firebase Management API
      const firebaseManagement = google.firebase({
        version: 'v1beta1',
        auth: oauth2Client
      });

      // Initialize Cloud Resource Manager API
      const cloudResourceManager = google.cloudresourcemanager({
        version: 'v3',
        auth: oauth2Client
      });

      console.log(`Creating Firebase project: ${projectId}`);

      // Step 1: Create Google Cloud Project
      // Note: For personal Google accounts, omit 'parent' field
      // Only use 'parent' for Google Workspace organization accounts
      const cloudProject = await cloudResourceManager.projects.create({
        requestBody: {
          projectId: projectId,
          displayName: displayName,
          // parent field omitted - works for personal Google accounts
        }
      });

      console.log('Cloud project created:', cloudProject.data);

      // Give the project a moment to propagate (project creation is usually fast)
      await new Promise(resolve => setTimeout(resolve, 3000)); // 3 seconds

      // Step 2: Add Firebase to the project
      const firebaseProject = await firebaseManagement.projects.addFirebase({
        project: `projects/${projectId}`,
        requestBody: {}
      });

      console.log('Firebase added to project:', firebaseProject.data);

      // Give Firebase a moment to fully initialize
      await new Promise(resolve => setTimeout(resolve, 3000)); // 3 seconds

      // Step 3: Enable required APIs
      const serviceUsage = google.serviceusage({
        version: 'v1',
        auth: oauth2Client
      });

      const requiredServices = [
        'firestore.googleapis.com',
        'identitytoolkit.googleapis.com', // Firebase Auth
        'firebase.googleapis.com',
        'storage-api.googleapis.com',
        'storage-component.googleapis.com',
        'fcm.googleapis.com' // Firebase Cloud Messaging
      ];

      console.log('Enabling required services...');
      await Promise.all(
        requiredServices.map(service =>
          serviceUsage.services.enable({
            name: `projects/${projectId}/services/${service}`
          }).catch(err => console.log(`Service ${service} enable error:`, err.message))
        )
      );

      // Step 4: Create Web App
      console.log('Creating Web app...');
      const webApp = await firebaseManagement.projects.webApps.create({
        parent: `projects/${projectId}`,
        requestBody: {
          displayName: `${displayName} Web`
        }
      });

      const webAppId = webApp.data.name.split('/').pop();

      // Get Web App config
      const webConfig = await firebaseManagement.projects.webApps.getConfig({
        name: `projects/${projectId}/webApps/${webAppId}`
      });

      // Step 5: Create Android App
      console.log('Creating Android app...');
      const androidApp = await firebaseManagement.projects.androidApps.create({
        parent: `projects/${projectId}`,
        requestBody: {
          displayName: `${displayName} Android`,
          packageName: `com.${projectId.toLowerCase().replace(/-/g, '')}.app`
        }
      }).catch(err => {
        console.log('Android app creation error:', err.message);
        return null;
      });

      let androidConfig = null;
      if (androidApp && androidApp.data) {
        const androidAppId = androidApp.data.name.split('/').pop();
        androidConfig = await firebaseManagement.projects.androidApps.getConfig({
          name: `projects/${projectId}/androidApps/${androidAppId}`
        });
      }

      // Step 6: Create iOS App
      console.log('Creating iOS app...');
      const iosApp = await firebaseManagement.projects.iosApps.create({
        parent: `projects/${projectId}`,
        requestBody: {
          displayName: `${displayName} iOS`,
          bundleId: `com.${projectId.toLowerCase().replace(/-/g, '')}.app`
        }
      }).catch(err => {
        console.log('iOS app creation error:', err.message);
        return null;
      });

      let iosConfig = null;
      if (iosApp && iosApp.data) {
        const iosAppId = iosApp.data.name.split('/').pop();
        iosConfig = await firebaseManagement.projects.iosApps.getConfig({
          name: `projects/${projectId}/iosApps/${iosAppId}`
        });
      }

      // Step 7: Initialize Firestore
      console.log('Initializing Firestore...');
      const firestore = google.firestore({
        version: 'v1',
        auth: oauth2Client
      });

      await firestore.projects.databases.create({
        parent: `projects/${projectId}`,
        databaseId: '(default)',
        requestBody: {
          locationId: 'us-central', // Default location
          type: 'FIRESTORE_NATIVE'
        }
      }).catch(err => console.log('Firestore init error:', err.message));

      // Prepare response with all configurations
      const response = {
        success: true,
        projectId: projectId,
        displayName: displayName,
        configs: {
          web: webConfig.data,
          android: androidConfig ? androidConfig.data : null,
          ios: iosConfig ? iosConfig.data : null
        },
        message: 'Firebase project created successfully!'
      };

      console.log('Project creation completed successfully');
      return res.status(200).json(response);

    } catch (error) {
      console.error('Error creating Firebase project:', error);
      return res.status(500).json({
        error: 'Failed to create Firebase project',
        details: error.message,
        stack: error.stack
      });
    }
  });
});
