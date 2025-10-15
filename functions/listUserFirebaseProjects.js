const functions = require('firebase-functions');
const { google } = require('googleapis');
const cors = require('cors')({ origin: true });

/**
 * Cloud Function to list all Firebase projects accessible by the user
 * NO BILLING REQUIRED - This is a simple read operation
 * 
 * User signs in with Google -> We list their Firebase projects -> User picks from dropdown
 */
exports.listUserFirebaseProjects = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
      const { accessToken } = req.body;

      if (!accessToken) {
        return res.status(400).json({
          error: 'Missing required field: accessToken'
        });
      }

      console.log('Listing Firebase projects for user...');

      // Initialize OAuth2 client with user's token
      const oauth2Client = new google.auth.OAuth2();
      oauth2Client.setCredentials({ access_token: accessToken });

      // Initialize Firebase Management API
      const firebaseManagement = google.firebase({
        version: 'v1beta1',
        auth: oauth2Client
      });

      // List all Firebase projects the user has access to
      const response = await firebaseManagement.projects.list({
        pageSize: 100 // Get up to 100 projects (most users have < 10)
      });

      const projects = response.data.results || [];

      console.log(`Found ${projects.length} Firebase projects`);

      // Format project list for easy display
      const projectList = projects.map(project => {
        // Extract project ID from the name format: "projects/project-id"
        const projectId = project.projectId;
        const displayName = project.displayName || projectId;
        const projectNumber = project.projectNumber;

        return {
          projectId: projectId,
          displayName: displayName,
          projectNumber: projectNumber,
          // Additional info for display
          state: project.state, // ACTIVE, DELETE_REQUESTED, etc.
          resources: project.resources || {}
        };
      });

      // Filter out deleted/inactive projects
      const activeProjects = projectList.filter(p => p.state === 'ACTIVE');

      console.log(`Returning ${activeProjects.length} active projects`);

      return res.status(200).json({
        success: true,
        count: activeProjects.length,
        projects: activeProjects,
        message: activeProjects.length > 0 
          ? `Found ${activeProjects.length} Firebase project(s)` 
          : 'No Firebase projects found. Create one first!'
      });

    } catch (error) {
      console.error('Error listing Firebase projects:', error);

      // Handle specific error cases
      if (error.code === 401 || error.code === 403) {
        return res.status(403).json({
          success: false,
          error: 'Permission denied. Please sign in with Google.',
          details: error.message
        });
      }

      if (error.code === 404) {
        return res.status(200).json({
          success: true,
          count: 0,
          projects: [],
          message: 'No Firebase projects found. Create one first!'
        });
      }

      // Generic error
      return res.status(500).json({
        success: false,
        error: 'Failed to list Firebase projects',
        details: error.message
      });
    }
  });
});
