const functions = require('firebase-functions');
const { google } = require('googleapis');
const cors = require('cors')({ origin: true });

/**
 * Enhanced Cloud Function: Auto-creates Web/Android/iOS apps and fetches API keys
 * Flow:
 * 1. Verify billing enabled
 * 2. Create Web app (if doesn't exist)
 * 3. Create Android app (if doesn't exist)
 * 4. Create iOS app (if doesn't exist)
 * 5. Fetch all API keys
 * 6. Return complete configuration
 */
exports.autoCreateAppsAndFetchConfig = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
      const { accessToken, projectId, appPackageName, iosBundleId } = req.body;

      if (!accessToken || !projectId) {
        return res.status(400).json({
          error: 'Missing required fields: accessToken, projectId'
        });
      }

      console.log(`🚀 Auto-creating apps for Firebase project: ${projectId}`);

      // Initialize OAuth2 client with user's token
      const oauth2Client = new google.auth.OAuth2();
      oauth2Client.setCredentials({ access_token: accessToken });

      // Initialize APIs
      const firebaseManagement = google.firebase({
        version: 'v1beta1',
        auth: oauth2Client
      });

      const cloudBilling = google.cloudbilling({
        version: 'v1',
        auth: oauth2Client
      });

      const cloudResourceManager = google.cloudresourcemanager({
        version: 'v1',
        auth: oauth2Client
      });

      // Step 1: Check billing status
      console.log('📊 Checking billing status...');
      let billingEnabled = false;
      let billingPlan = 'Unknown';
      let billingAccountName = '';
      let billingCheckError = null;

      try {
        const billingInfo = await cloudBilling.projects.getBillingInfo({
          name: `projects/${projectId}`
        });

        billingEnabled = billingInfo.data.billingEnabled || false;
        billingAccountName = billingInfo.data.billingAccountName || '';
        billingPlan = billingEnabled ? 'Blaze (Pay as you go)' : 'Spark (Free)';

        console.log(`✅ Billing status: ${billingPlan}`);
      } catch (error) {
        billingCheckError = error.message;
        console.log(`⚠️ Could not check billing: ${error.message}`);
      }

      // Step 1.5: Get API Key from project - Try multiple methods
      console.log('🔑 Fetching project API key...');
      let apiKey = '';
      let apiKeyMessage = '';
      
      // Method 1: Try to get from Firebase project directly
      try {
        console.log('🔍 Method 1: Fetching from Firebase project...');
        const projectInfo = await firebaseManagement.projects.get({
          name: `projects/${projectId}`
        });
        
        // Check if there's a default API key in project resources
        if (projectInfo.data.resources && projectInfo.data.resources.defaultApiKey) {
          apiKey = projectInfo.data.resources.defaultApiKey;
          console.log(`✅ API Key found from project: ${apiKey.substring(0, 10)}...`);
        }
      } catch (error) {
        console.log(`⚠️ Method 1 failed: ${error.message}`);
      }

      // Method 2: Try API Keys service if Method 1 failed
      if (!apiKey) {
        try {
          console.log('🔍 Method 2: Trying API Keys service...');
          const apiKeysService = google.apikeys({
            version: 'v2',
            auth: oauth2Client
          });

          const keysResponse = await apiKeysService.projects.locations.keys.list({
            parent: `projects/${projectId}/locations/global`
          });

          if (keysResponse.data.keys && keysResponse.data.keys.length > 0) {
            const firstKey = keysResponse.data.keys[0];
            // Extract the key value from the name
            // Format: projects/PROJECT_NUMBER/locations/global/keys/KEY_VALUE
            const keyName = firstKey.name;
            apiKey = keyName.split('/').pop();
            console.log(`✅ API Key found from API Keys service: ${apiKey.substring(0, 10)}...`);
          } else {
            console.log('⚠️ No API keys found in API Keys service');
          }
        } catch (error) {
          console.log(`⚠️ Method 2 failed: ${error.message}`);
          apiKeyMessage = 'Could not fetch API key automatically. Please add it manually from Firebase Console.';
        }
      }

      // If billing not enabled, return error
      if (!billingEnabled) {
        return res.status(400).json({
          success: false,
          error: 'Billing must be enabled (Blaze plan required)',
          billingEnabled: false,
          billingPlan,
          billingAccountName,
          needsBilling: true,
          message: 'Please upgrade to Blaze plan to use auto-create feature'
        });
      }

      // Step 2: Create or get Web app
      console.log('🌐 Creating/Getting Web app...');
      let webConfig = null;
      let webAppId = null;

      try {
        // Check if web app already exists
        const webApps = await firebaseManagement.projects.webApps.list({
          parent: `projects/${projectId}`
        });

        if (webApps.data.apps && webApps.data.apps.length > 0) {
          console.log('✅ Web app already exists');
          const webAppName = webApps.data.apps[0].name;
          webAppId = webAppName.split('/').pop(); // Extract appId from name
        } else {
          // Create new web app
          console.log('🔨 Creating new Web app...');
          const createResponse = await firebaseManagement.projects.webApps.create({
            parent: `projects/${projectId}`,
            requestBody: {
              displayName: 'School Management Web',
            }
          });

          // Extract appId from the response name
          const webAppName = createResponse.data.name;
          webAppId = webAppName.split('/').pop();
          console.log(`✅ Web app created: ${webAppId}`);
        }

        // Get web app details
        const webAppDetails = await firebaseManagement.projects.webApps.get({
          name: `projects/${projectId}/webApps/${webAppId}`
        });

        console.log('🔍 Web app details:', JSON.stringify(webAppDetails.data, null, 2));

        // Get project details for additional config
        const projectDetails = await firebaseManagement.projects.get({
          name: `projects/${projectId}`
        });

        console.log('🔍 Project details:', JSON.stringify(projectDetails.data, null, 2));

        // Extract the appId which contains the messagingSenderId
        // Format: "1:PROJECT_NUMBER:web:WEB_ID"
        const appIdParts = webAppDetails.data.appId.split(':');
        const projectNumber = appIdParts[1] || '';

        // Construct Firebase SDK config with fetched API key
        webConfig = {
          apiKey: apiKey,
          authDomain: `${projectId}.firebaseapp.com`,
          projectId: projectId,
          storageBucket: projectDetails.data.resources?.defaultStorageBucket || `${projectId}.appspot.com`,
          messagingSenderId: projectNumber,
          appId: webAppDetails.data.appId,
          measurementId: '', // GA4 measurement ID (optional)
        };
        console.log('✅ Web config constructed:', JSON.stringify(webConfig, null, 2));
      } catch (error) {
        console.log(`⚠️ Error with Web app: ${error.message}`);
        webConfig = null;
      }

      // Step 3: Create or get Android app
      console.log('🤖 Creating/Getting Android app...');
      let androidConfig = null;
      let androidAppId = null;
      const androidPackageName = appPackageName || 'com.school.management';

      try {
        // Check if android app already exists
        const androidApps = await firebaseManagement.projects.androidApps.list({
          parent: `projects/${projectId}`
        });

        if (androidApps.data.apps && androidApps.data.apps.length > 0) {
          console.log('✅ Android app already exists');
          const androidAppName = androidApps.data.apps[0].name;
          androidAppId = androidAppName.split('/').pop();
        } else {
          // Create new android app
          console.log(`🔨 Creating new Android app with package: ${androidPackageName}`);
          const createResponse = await firebaseManagement.projects.androidApps.create({
            parent: `projects/${projectId}`,
            requestBody: {
              displayName: 'School Management Android',
              packageName: androidPackageName,
            }
          });

          // Extract appId from the response name
          const androidAppName = createResponse.data.name;
          androidAppId = androidAppName.split('/').pop();
          console.log(`✅ Android app created: ${androidAppId}`);
        }

        // Get android app details
        const androidAppDetails = await firebaseManagement.projects.androidApps.get({
          name: `projects/${projectId}/androidApps/${androidAppId}`
        });

        console.log('🔍 Android app details:', JSON.stringify(androidAppDetails.data, null, 2));

        // Get project details if not already fetched
        if (!projectDetails) {
          var projectDetails = await firebaseManagement.projects.get({
            name: `projects/${projectId}`
          });
        }

        // Extract project number from appId
        // Format: "1:PROJECT_NUMBER:android:ANDROID_ID"
        const androidAppIdParts = androidAppDetails.data.appId.split(':');
        const androidProjectNumber = androidAppIdParts[1] || '';

        // Construct Android config (similar to google-services.json)
        androidConfig = {
          mobilesdk_app_id: androidAppDetails.data.appId,
          current_key: apiKey,
          project_id: projectId,
          project_number: androidProjectNumber,
          messaging_sender_id: androidProjectNumber, // Same as project_number
          storage_bucket: projectDetails.data.resources?.defaultStorageBucket || `${projectId}.appspot.com`,
        };
        console.log('✅ Android config constructed:', JSON.stringify(androidConfig, null, 2));
      } catch (error) {
        console.log(`⚠️ Error with Android app: ${error.message}`);
        androidConfig = null;
      }

      // Step 4: Create or get iOS app
      console.log('🍎 Creating/Getting iOS app...');
      let iosConfig = null;
      let iosAppId = null;
      const iosBundleIdentifier = iosBundleId || 'com.school.management';

      try {
        // Check if iOS app already exists
        const iosApps = await firebaseManagement.projects.iosApps.list({
          parent: `projects/${projectId}`
        });

        if (iosApps.data.apps && iosApps.data.apps.length > 0) {
          console.log('✅ iOS app already exists');
          const iosAppName = iosApps.data.apps[0].name;
          iosAppId = iosAppName.split('/').pop();
        } else {
          // Create new iOS app
          console.log(`🔨 Creating new iOS app with bundle ID: ${iosBundleIdentifier}`);
          const createResponse = await firebaseManagement.projects.iosApps.create({
            parent: `projects/${projectId}`,
            requestBody: {
              displayName: 'School Management iOS',
              bundleId: iosBundleIdentifier,
            }
          });

          // Extract appId from the response name
          const iosAppName = createResponse.data.name;
          iosAppId = iosAppName.split('/').pop();
          console.log(`✅ iOS app created: ${iosAppId}`);
        }

        // Get iOS app details
        const iosAppDetails = await firebaseManagement.projects.iosApps.get({
          name: `projects/${projectId}/iosApps/${iosAppId}`
        });

        console.log('🔍 iOS app details:', JSON.stringify(iosAppDetails.data, null, 2));

        // Get project details if not already fetched
        if (!projectDetails) {
          var projectDetails = await firebaseManagement.projects.get({
            name: `projects/${projectId}`
          });
        }

        // Extract project number from appId
        // Format: "1:PROJECT_NUMBER:ios:IOS_ID"
        const iosAppIdParts = iosAppDetails.data.appId.split(':');
        const iosProjectNumber = iosAppIdParts[1] || '';

        // Construct iOS config (similar to GoogleService-Info.plist)
        iosConfig = {
          mobilesdk_app_id: iosAppDetails.data.appId,
          api_key: apiKey,
          project_id: projectId,
          project_number: iosProjectNumber,
          storage_bucket: projectDetails.data.resources?.defaultStorageBucket || `${projectId}.appspot.com`,
          bundle_id: iosAppDetails.data.bundleId,
        };
        console.log('✅ iOS config constructed:', JSON.stringify(iosConfig, null, 2));
      } catch (error) {
        console.log(`⚠️ Error with iOS app: ${error.message}`);
        iosConfig = null;
      }

      // Step 5: Create or get macOS app
      console.log('🍎 Creating/Getting macOS app...');
      let macosConfig = null;
      let macosAppId = null;
      const macosBundleIdentifier = iosBundleId || 'com.school.management';

      try {
        // Check if macOS app already exists
        const macosApps = await firebaseManagement.projects.iosApps.list({
          parent: `projects/${projectId}`
        });

        // macOS apps use the same API as iOS apps, filter by bundle ID
        const existingMacosApp = macosApps.data.apps?.find(app => 
          app.bundleId === macosBundleIdentifier && app.displayName?.toLowerCase().includes('macos')
        );

        if (existingMacosApp) {
          console.log('✅ macOS app already exists');
          const macosAppName = existingMacosApp.name;
          macosAppId = macosAppName.split('/').pop();
        } else {
          // Create new macOS app (uses iOS API with different display name)
          console.log(`🔨 Creating new macOS app with bundle ID: ${macosBundleIdentifier}`);
          const createResponse = await firebaseManagement.projects.iosApps.create({
            parent: `projects/${projectId}`,
            requestBody: {
              displayName: 'School Management macOS',
              bundleId: `${macosBundleIdentifier}.macos`,
            }
          });

          const macosAppName = createResponse.data.name;
          macosAppId = macosAppName.split('/').pop();
          console.log(`✅ macOS app created: ${macosAppId}`);
        }

        // Get macOS app details
        const macosAppDetails = await firebaseManagement.projects.iosApps.get({
          name: `projects/${projectId}/iosApps/${macosAppId}`
        });

        console.log('🔍 macOS app details:', JSON.stringify(macosAppDetails.data, null, 2));

        // Extract project number from appId
        const macosAppIdParts = macosAppDetails.data.appId.split(':');
        const macosProjectNumber = macosAppIdParts[1] || '';

        // Construct macOS config (same as iOS)
        macosConfig = {
          mobilesdk_app_id: macosAppDetails.data.appId,
          api_key: apiKey,
          project_id: projectId,
          project_number: macosProjectNumber,
          storage_bucket: projectDetails.data.resources?.defaultStorageBucket || `${projectId}.appspot.com`,
          bundle_id: macosAppDetails.data.bundleId,
        };
        console.log('✅ macOS config constructed:', JSON.stringify(macosConfig, null, 2));
      } catch (error) {
        console.log(`⚠️ Error with macOS app: ${error.message}`);
        macosConfig = null;
      }

      // Step 6: Windows config (uses Web config)
      console.log('🪟 Creating Windows config...');
      let windowsConfig = null;
      
      try {
        // Windows uses the same config as Web
        if (webConfig) {
          windowsConfig = {
            ...webConfig,
            platform: 'windows',
          };
          console.log('✅ Windows config created (using Web config):', JSON.stringify(windowsConfig, null, 2));
        } else {
          console.log('⚠️ Cannot create Windows config - Web config not available');
        }
      } catch (error) {
        console.log(`⚠️ Error with Windows config: ${error.message}`);
        windowsConfig = null;
      }

      // Return success response
      console.log('🎉 Auto-create completed successfully!');
      return res.status(200).json({
        success: true,
        billingEnabled: true,
        billingPlan,
        billingAccountName,
        apiKeyMessage: apiKeyMessage || (apiKey ? 'API key fetched successfully' : 'API key empty - may need manual entry'),
        config: {
          web: webConfig,
          android: androidConfig,
          ios: iosConfig,
          macos: macosConfig,
          windows: windowsConfig,
        },
        appsCreated: {
          web: webAppId ? true : false,
          android: androidAppId ? true : false,
          ios: iosAppId ? true : false,
          macos: macosAppId ? true : false,
          windows: windowsConfig ? true : false,
        },
        projectId: projectId,
        message: 'Apps created and API keys fetched successfully for all platforms',
      });

    } catch (error) {
      console.error('❌ Error in auto-create function:', error);
      return res.status(500).json({
        success: false,
        error: error.message,
        message: 'Failed to auto-create apps'
      });
    }
  });
});
