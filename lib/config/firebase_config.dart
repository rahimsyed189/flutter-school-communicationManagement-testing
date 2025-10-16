/// Firebase Cloud Functions Configuration
/// 
/// Update these URLs if you move to a different Firebase project
/// or change the region where functions are deployed.

class FirebaseConfig {
  /// Base URL for Cloud Functions
  /// Format: https://{region}-{projectId}.cloudfunctions.net
  static const String cloudFunctionsBaseUrl = 
      'https://us-central1-adilabadautocabs.cloudfunctions.net';
  
  /// Individual function endpoints
  static const String listProjectsFunction = '$cloudFunctionsBaseUrl/listUserFirebaseProjects';
  static const String autoCreateAppsFunction = '$cloudFunctionsBaseUrl/autoCreateAppsAndFetchConfig';
  static const String verifyConfigFunction = '$cloudFunctionsBaseUrl/verifyAndFetchFirebaseConfig';
  
  /// API Keys Console URL (for enabling API Keys API)
  static String getApiKeysConsoleUrl(String projectId) {
    return 'https://console.cloud.google.com/apis/library/apikeys.googleapis.com?project=$projectId';
  }
  
  /// Upgrade to Blaze Plan URL
  static String getUpgradeToBlazeUrl(String projectId) {
    return 'https://console.firebase.google.com/project/$projectId/usage/details';
  }
  
  /// Firebase Console Project Settings URL
  static String getFirebaseConsoleUrl(String projectId) {
    return 'https://console.firebase.google.com/project/$projectId/settings/general';
  }
}

/// Maintenance Notes:
/// 
/// ✅ ONE-TIME SETUP:
/// - Cloud Functions are deployed once
/// - API versions are stable (v1, v1beta1, v2)
/// - No periodic updates needed
/// 
/// ⚠️ UPDATE ONLY IF:
/// 1. You move to a different Firebase hosting project
///    → Change 'adilabadautocabs' to new project ID in cloudFunctionsBaseUrl
/// 
/// 2. You change Cloud Functions region
///    → Change 'us-central1' to new region (e.g., 'europe-west1')
/// 
/// 3. You upgrade Node.js runtime in functions
///    → No code changes needed, just redeploy functions
/// 
/// 🔄 TO DEPLOY FUNCTIONS:
/// cd functions
/// firebase deploy --only functions
/// 
/// 📝 CURRENT SETUP:
/// - Hosting Project: adilabadautocabs
/// - Region: us-central1
/// - Runtime: Node.js 18 (consider upgrading to 20+)
/// - APIs Used:
///   * Firebase Management API v1beta1
///   * Cloud Billing API v1
///   * API Keys API v2
