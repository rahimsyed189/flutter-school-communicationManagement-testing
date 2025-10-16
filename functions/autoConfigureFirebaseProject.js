const functions = require('firebase-functions');
const { google } = require('googleapis');
const cors = require('cors')({ origin: true });

/**
 * Cloud Function to automatically configure Firebase project
 * Attempts to enable services automatically and guides user if billing needed
 */
exports.autoConfigureFirebaseProject = functions.https.onRequest((req, res) => {
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

      console.log(`Auto-configuring Firebase project: ${projectId}`);

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

      const cloudBilling = google.cloudbilling({
        version: 'v1',
        auth: oauth2Client
      });

      // Step 1: Check if project exists
      let project;
      try {
        const projectResponse = await firebaseManagement.projects.get({
          name: `projects/${projectId}`
        });
        project = projectResponse.data;
        console.log('✅ Project exists');
      } catch (error) {
        console.log('❌ Project does not exist');
        return res.status(404).json({
          success: false,
          stage: 'project_check',
          error: 'Project not found',
          message: 'Firebase project does not exist or you do not have access.',
          needsBilling: false
        });
      }

      // Step 2: Check billing status and plan
      let billingEnabled = false;
      let billingAccountName = '';
      let billingPlan = 'Spark (Free)'; // Default to Spark
      let billingCheckError = null;
      
      try {
        const billingInfo = await cloudBilling.projects.getBillingInfo({
          name: `projects/${projectId}`
        });
        
        console.log('Raw billing API response:', JSON.stringify(billingInfo.data, null, 2));
        
        billingEnabled = billingInfo.data.billingEnabled || false;
        billingAccountName = billingInfo.data.billingAccountName || '';
        
        // Determine plan: If billing is enabled, it's Blaze (pay-as-you-go)
        // If billing is NOT enabled, it's Spark (free tier)
        billingPlan = billingEnabled ? 'Blaze (Pay as you go)' : 'Spark (Free)';
        
        console.log('✅ Billing status checked:', { 
          billingEnabled, 
          billingAccountName, 
          billingPlan 
        });
      } catch (error) {
        billingCheckError = error.message;
        console.log('⚠️ Warning: Could not check billing:', error.message);
        console.log('Error details:', error);
        // Continue with default values (Spark plan, no billing)
      }

      // Step 3: If no billing, return instructions
      if (!billingEnabled) {
        console.log('❌ Billing not enabled - stopping here');
        return res.status(200).json({
          success: false,
          stage: 'billing_required',
          projectExists: true,
          billingEnabled: false,
          billingPlan: billingPlan,
          billingAccountName: billingAccountName || 'None',
          billingCheckError: billingCheckError, // Include error if any
          needsBilling: true,
          message: 'Billing must be enabled before Firebase services can be configured.',
          billingInstructions: {
            title: '⚠️ Billing Required to Continue',
            description: 'Your Firebase project needs billing enabled to use Firestore, Authentication, and Storage. Don\'t worry - it\'s FREE for small schools!',
            steps: [
              {
                number: 1,
                title: 'Go to Firebase Console',
                action: 'Open console.firebase.google.com in your browser',
                url: `https://console.firebase.google.com/project/${projectId}/overview`
              },
              {
                number: 2,
                title: 'Select Your Project',
                action: `Click on "${projectId}" project`
              },
              {
                number: 3,
                title: 'Upgrade to Blaze Plan',
                action: 'Click "Upgrade" button or go to Settings → Usage and billing',
                details: 'Blaze plan is PAY-AS-YOU-GO but includes generous FREE tier'
              },
              {
                number: 4,
                title: 'Link Billing Account',
                action: 'Add your credit/debit card',
                warning: 'You won\'t be charged unless you exceed free limits (rare for schools)'
              },
              {
                number: 5,
                title: 'Set Budget Alert (Recommended)',
                action: 'Go to Google Cloud Console → Billing → Budgets',
                details: 'Set alert at $5 to get email if approaching charges',
                url: 'https://console.cloud.google.com/billing/budgets'
              },
              {
                number: 6,
                title: 'Return to This App',
                action: 'Click "Verify & Configure" button again',
                details: 'We\'ll automatically enable all services for you!'
              }
            ],
            freeTierInfo: {
              title: '💰 Free Tier Limits (Monthly)',
              limits: [
                'Firestore: 50,000 reads/day, 20,000 writes/day',
                'Authentication: 100,000 operations',
                'Storage: 5 GB stored, 1 GB downloaded/day',
                'Cloud Messaging: Unlimited'
              ],
              typical: 'Small schools (100-500 users) typically cost $0/month'
            }
          }
        });
      }

      // Step 4: Billing enabled! Try to enable services automatically
      console.log('✅ Billing enabled - proceeding with auto-configuration');

      const results = {
        projectExists: true,
        billingEnabled: true,
        servicesEnabled: {},
        appsRegistered: {},
        errors: []
      };

      // Enable Firestore
      try {
        console.log('Enabling Firestore...');
        await serviceUsage.services.enable({
          name: `projects/${projectId}/services/firestore.googleapis.com`
        });
        results.servicesEnabled.firestore = true;
        console.log('✅ Firestore enabled');
      } catch (error) {
        console.log('⚠️ Firestore enable error:', error.message);
        results.servicesEnabled.firestore = false;
        results.errors.push(`Firestore: ${error.message}`);
      }

      // Enable Authentication
      try {
        console.log('Enabling Authentication...');
        await serviceUsage.services.enable({
          name: `projects/${projectId}/services/identitytoolkit.googleapis.com`
        });
        results.servicesEnabled.auth = true;
        console.log('✅ Authentication enabled');
      } catch (error) {
        console.log('⚠️ Auth enable error:', error.message);
        results.servicesEnabled.auth = false;
        results.errors.push(`Authentication: ${error.message}`);
      }

      // Enable Storage
      try {
        console.log('Enabling Storage...');
        await serviceUsage.services.enable({
          name: `projects/${projectId}/services/storage.googleapis.com`
        });
        results.servicesEnabled.storage = true;
        console.log('✅ Storage enabled');
      } catch (error) {
        console.log('⚠️ Storage enable error:', error.message);
        results.servicesEnabled.storage = false;
        results.errors.push(`Storage: ${error.message}`);
      }

      // Enable Cloud Messaging
      try {
        console.log('Enabling Cloud Messaging...');
        await serviceUsage.services.enable({
          name: `projects/${projectId}/services/fcm.googleapis.com`
        });
        results.servicesEnabled.fcm = true;
        console.log('✅ Cloud Messaging enabled');
      } catch (error) {
        console.log('⚠️ FCM enable error:', error.message);
        results.servicesEnabled.fcm = false;
        results.errors.push(`Cloud Messaging: ${error.message}`);
      }

      // Wait a bit for services to be fully enabled
      await new Promise(resolve => setTimeout(resolve, 3000));

      // Register Web App if not exists
      try {
        console.log('Checking for Web app...');
        const webApps = await firebaseManagement.projects.webApps.list({
          parent: `projects/${projectId}`
        });

        if (!webApps.data.apps || webApps.data.apps.length === 0) {
          console.log('Creating Web app...');
          const webApp = await firebaseManagement.projects.webApps.create({
            parent: `projects/${projectId}`,
            requestBody: {
              displayName: 'School Management Web App'
            }
          });
          results.appsRegistered.web = true;
          console.log('✅ Web app created');
        } else {
          results.appsRegistered.web = true;
          console.log('✅ Web app already exists');
        }
      } catch (error) {
        console.log('⚠️ Web app error:', error.message);
        results.appsRegistered.web = false;
        results.errors.push(`Web app: ${error.message}`);
      }

      // Now fetch all configurations
      console.log('Fetching configurations...');
      
      // Fetch Web config
      let webConfig = null;
      try {
        const webApps = await firebaseManagement.projects.webApps.list({
          parent: `projects/${projectId}`
        });

        if (webApps.data.apps && webApps.data.apps.length > 0) {
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
          console.log('✅ Web config fetched');
        }
      } catch (error) {
        console.log('⚠️ Could not fetch web config:', error.message);
        results.errors.push(`Web config: ${error.message}`);
      }

      // Return success with all configurations
      return res.status(200).json({
        success: true,
        stage: 'completed',
        message: 'Firebase project configured successfully!',
        projectExists: true,
        billingEnabled: true,
        billingPlan: billingPlan,
        billingAccountName: billingAccountName || 'Connected',
        needsBilling: false,
        servicesEnabled: results.servicesEnabled,
        appsRegistered: results.appsRegistered,
        config: {
          web: webConfig
        },
        errors: results.errors.length > 0 ? results.errors : null
      });

    } catch (error) {
      console.error('Error auto-configuring project:', error);

      return res.status(500).json({
        success: false,
        stage: 'error',
        error: 'Configuration failed',
        details: error.message,
        needsBilling: false
      });
    }
  });
});
