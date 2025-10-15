const functions = require('firebase-functions');
const { google } = require('googleapis');
const cors = require('cors')({ origin: true });

/**
 * Cloud Function to verify existing Firebase project and fetch all API keys
 * User creates project manually, this function validates setup and retrieves config
 */
exports.verifyAndFetchFirebaseConfig = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
      const { accessToken, projectId } = req.body;

      if (!accessToken || !projectId) {
        return res.status(400).json({
          error: 'Missing required fields: accessToken, projectId'
        });
      }

      console.log(`Verifying Firebase project: ${projectId}`);

      // Initialize OAuth2 client with user's token
      const oauth2Client = new google.auth.OAuth2();
      oauth2Client.setCredentials({ access_token: accessToken });

      // Initialize APIs
      const firebaseManagement = google.firebase({
        version: 'v1beta1',
        auth: oauth2Client
      });

      const serviceUsage = google.serviceusage({
        version: 'v1',
        auth: oauth2Client
      });

      // Step 1: Check if project exists
      let projectExists = false;
      let firestoreEnabled = false;
      let authEnabled = false;
      let storageEnabled = false;
      let fcmEnabled = false;

      try {
        const project = await firebaseManagement.projects.get({
          name: `projects/${projectId}`
        });
        projectExists = !!project.data;
        console.log('✅ Project exists');
      } catch (error) {
        console.log('❌ Project does not exist or no access');
        return res.status(404).json({
          error: 'Project not found',
          details: 'Project does not exist or you do not have access to it',
          suggestions: [
            `Create project at https://console.firebase.google.com`,
            'Ensure you are signed in with the project owner account'
          ]
        });
      }

      // Step 2: Check enabled services
      try {
        const services = await serviceUsage.services.list({
          parent: `projects/${projectId}`,
          filter: 'state:ENABLED'
        });

        const enabledServices = services.data.services || [];
        const serviceNames = enabledServices.map(s => s.config?.name || '');

        firestoreEnabled = serviceNames.includes('firestore.googleapis.com');
        authEnabled = serviceNames.includes('identitytoolkit.googleapis.com');
        storageEnabled = serviceNames.includes('storage.googleapis.com');
        fcmEnabled = serviceNames.includes('fcm.googleapis.com');

        console.log('Service status:', {
          firestore: firestoreEnabled,
          auth: authEnabled,
          storage: storageEnabled,
          fcm: fcmEnabled
        });
      } catch (error) {
        console.log('Warning: Could not check services:', error.message);
      }

      // Step 3: Get web app config
      let webConfig = null;
      let webAppExists = false;

      try {
        const webApps = await firebaseManagement.projects.webApps.list({
          parent: `projects/${projectId}`
        });

        if (webApps.data.apps && webApps.data.apps.length > 0) {
          webAppExists = true;
          const webAppName = webApps.data.apps[0].name;
          
          const configResponse = await firebaseManagement.projects.webApps.getConfig({
            name: `${webAppName}/config`
          });

          webConfig = {
            apiKey: configResponse.data.apiKey,
            authDomain: configResponse.data.authDomain,
            projectId: configResponse.data.projectId,
            storageBucket: configResponse.data.storageBucket,
            messagingSenderId: configResponse.data.messagingSenderId,
            appId: configResponse.data.appId,
            measurementId: configResponse.data.measurementId || '',
          };
          console.log('✅ Web app config fetched');
        }
      } catch (error) {
        console.log('Warning: Could not fetch web config:', error.message);
      }

      // Step 4: Get Android app config
      let androidConfig = null;
      let androidAppExists = false;

      try {
        const androidApps = await firebaseManagement.projects.androidApps.list({
          parent: `projects/${projectId}`
        });

        if (androidApps.data.apps && androidApps.data.apps.length > 0) {
          androidAppExists = true;
          const androidAppName = androidApps.data.apps[0].name;
          
          const configResponse = await firebaseManagement.projects.androidApps.getConfig({
            name: `${androidAppName}/config`
          });

          // Parse the config file content
          const configJson = JSON.parse(
            Buffer.from(configResponse.data.configFileContents, 'base64').toString()
          );

          androidConfig = {
            mobilesdk_app_id: configJson.client[0].client_info.mobilesdk_app_id,
            current_key: configJson.client[0].api_key[0].current_key,
            project_id: configJson.project_info.project_id,
            storage_bucket: configJson.project_info.storage_bucket,
          };
          console.log('✅ Android app config fetched');
        }
      } catch (error) {
        console.log('Warning: Could not fetch Android config:', error.message);
      }

      // Step 5: Get iOS app config
      let iosConfig = null;
      let iosAppExists = false;

      try {
        const iosApps = await firebaseManagement.projects.iosApps.list({
          parent: `projects/${projectId}`
        });

        if (iosApps.data.apps && iosApps.data.apps.length > 0) {
          iosAppExists = true;
          const iosAppName = iosApps.data.apps[0].name;
          
          const configResponse = await firebaseManagement.projects.iosApps.getConfig({
            name: `${iosAppName}/config`
          });

          // Parse the plist content
          const configContent = Buffer.from(
            configResponse.data.configFileContents, 
            'base64'
          ).toString();

          // Extract values from plist (simple regex-based extraction)
          const extractPlistValue = (key) => {
            const regex = new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`);
            const match = configContent.match(regex);
            return match ? match[1] : '';
          };

          iosConfig = {
            mobilesdk_app_id: extractPlistValue('GOOGLE_APP_ID'),
            api_key: extractPlistValue('API_KEY'),
            project_id: extractPlistValue('PROJECT_ID'),
            storage_bucket: extractPlistValue('STORAGE_BUCKET'),
          };
          console.log('✅ iOS app config fetched');
        }
      } catch (error) {
        console.log('Warning: Could not fetch iOS config:', error.message);
      }

      // Return verification status and configs
      return res.status(200).json({
        status: {
          projectExists,
          firestoreEnabled,
          authEnabled,
          storageEnabled,
          fcmEnabled,
          webAppExists,
          androidAppExists,
          iosAppExists,
        },
        config: {
          web: webConfig,
          android: androidConfig,
          ios: iosConfig,
        },
        projectId: projectId,
        message: 'Project verification complete',
      });

    } catch (error) {
      console.error('Error verifying Firebase project:', error);
      return res.status(500).json({
        error: 'Failed to verify Firebase project',
        details: error.message,
        stack: error.stack
      });
    }
  });
});
