import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Service to verify existing Firebase projects and fetch their API keys
/// User creates project manually, then we auto-fetch all configuration
class FirebaseProjectVerifier {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/firebase.readonly', // Read Firebase config
      'https://www.googleapis.com/auth/cloud-platform', // Access Cloud resources
    ],
  );

  /// Sign in with Google (read-only Firebase permissions)
  static Future<String?> signInWithGoogle() async {
    try {
      debugPrint('🔐 Starting Google Sign-In for Firebase verification...');
      
      // Sign out first to force fresh login
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        debugPrint('❌ User cancelled Google Sign-In');
        return null;
      }

      debugPrint('✅ Google Sign-In successful: ${account.email}');

      final GoogleSignInAuthentication auth = await account.authentication;
      
      if (auth.accessToken == null) {
        debugPrint('❌ Failed to get access token');
        return null;
      }

      debugPrint('✅ Access token obtained');
      return auth.accessToken;
      
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      return null;
    }
  }

  /// List all Firebase projects accessible by the user
  /// NO BILLING REQUIRED - This is a simple read operation!
  static Future<List<Map<String, dynamic>>?> listUserProjects({
    required String accessToken,
  }) async {
    try {
      debugPrint('📋 Listing user\'s Firebase projects...');

      const cloudFunctionUrl = 
          'https://us-central1-adilabadautocabs.cloudfunctions.net/listUserFirebaseProjects';

      debugPrint('📍 Calling Cloud Function: $cloudFunctionUrl');

      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accessToken': accessToken,
        }),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final projects = List<Map<String, dynamic>>.from(data['projects']);
          debugPrint('✅ Found ${projects.length} Firebase project(s)');
          return projects;
        } else {
          debugPrint('❌ Failed to list projects: ${data['message']}');
          return null;
        }
      } else {
        final error = jsonDecode(response.body);
        debugPrint('❌ Error listing projects: ${error['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Exception listing projects: $e');
      return null;
    }
  }

  /// Auto-configure Firebase project (enables services automatically)
  /// Checks billing first and provides clear instructions if needed
  static Future<Map<String, dynamic>?> autoConfigureProject({
    required String projectId,
    required String accessToken,
  }) async {
    try {
      debugPrint('🔧 Auto-configuring Firebase project: $projectId');

      const cloudFunctionUrl = 
          'https://us-central1-adilabadautocabs.cloudfunctions.net/autoConfigureFirebaseProject';

      debugPrint('📍 Calling Cloud Function: $cloudFunctionUrl');

      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accessToken': accessToken,
          'projectId': projectId,
        }),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Auto-configure response received');
        return data;
      } else {
        final error = jsonDecode(response.body);
        debugPrint('❌ Error auto-configuring: ${error['error']}');
        return error;
      }
    } catch (e) {
      debugPrint('❌ Exception auto-configuring: $e');
      return null;
    }
  }

  /// Parse auto-configure status and provide user-friendly information
  static Map<String, dynamic> getAutoConfigureStatus(Map<String, dynamic>? result) {
    if (result == null) {
      return {
        'success': false,
        'needsBilling': false,
        'message': 'Failed to connect to configuration service',
      };
    }

    final success = result['success'] == true;
    final needsBilling = result['needsBilling'] == true;
    final stage = result['stage'] as String?;

    if (stage == 'billing_required') {
      return {
        'success': false,
        'needsBilling': true,
        'billingInstructions': result['billingInstructions'],
        'message': result['message'] ?? 'Billing required',
      };
    }

    if (stage == 'completed') {
      return {
        'success': true,
        'needsBilling': false,
        'config': result['config'],
        'servicesEnabled': result['servicesEnabled'],
        'message': result['message'] ?? 'Configuration completed successfully',
      };
    }

    return {
      'success': success,
      'needsBilling': needsBilling,
      'message': result['message'] ?? 'Unknown status',
      'error': result['error'],
    };
  }

  /// Verify Firebase project exists and fetch all API keys
  static Future<Map<String, dynamic>?> verifyAndFetchConfig({
    required String projectId,
    required String accessToken,
  }) async {
    try {
      debugPrint('🔍 Verifying Firebase project: $projectId');

      const cloudFunctionUrl = 
          'https://us-central1-adilabadautocabs.cloudfunctions.net/verifyAndFetchFirebaseConfig';

      debugPrint('📍 Calling Cloud Function: $cloudFunctionUrl');

      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accessToken': accessToken,
          'projectId': projectId,
        }),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Project verified and config fetched successfully');
        return data;
      } else {
        final error = jsonDecode(response.body);
        debugPrint('❌ Verification failed: ${error['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error verifying project: $e');
      return null;
    }
  }

  /// Parse fetched config into form-fillable format
  static Map<String, Map<String, String>> parseFirebaseConfig(Map<String, dynamic> config) {
    return {
      'web': {
        'apiKey': config['web']?['apiKey'] ?? '',
        'authDomain': config['web']?['authDomain'] ?? '',
        'projectId': config['web']?['projectId'] ?? '',
        'storageBucket': config['web']?['storageBucket'] ?? '',
        'messagingSenderId': config['web']?['messagingSenderId'] ?? '',
        'appId': config['web']?['appId'] ?? '',
        'measurementId': config['web']?['measurementId'] ?? '',
      },
      'android': {
        'mobilesdk_app_id': config['android']?['mobilesdk_app_id'] ?? '',
        'current_key': config['android']?['current_key'] ?? '',
        'project_id': config['android']?['project_id'] ?? '',
        'storage_bucket': config['android']?['storage_bucket'] ?? '',
      },
      'ios': {
        'mobilesdk_app_id': config['ios']?['mobilesdk_app_id'] ?? '',
        'api_key': config['ios']?['api_key'] ?? '',
        'project_id': config['ios']?['project_id'] ?? '',
        'storage_bucket': config['ios']?['storage_bucket'] ?? '',
      },
    };
  }

  /// Get verification status with helpful messages
  static Map<String, dynamic> getVerificationStatus(Map<String, dynamic>? result) {
    if (result == null) {
      return {
        'success': false,
        'message': 'Failed to verify project',
        'suggestions': [
          'Check if project ID is correct',
          'Ensure you are signed in with the project owner account',
          'Verify billing is enabled on the project',
        ],
      };
    }

    final status = result['status'] as Map<String, dynamic>?;
    if (status == null) {
      return {
        'success': false,
        'message': 'Invalid response from server',
      };
    }

    final List<String> missing = [];
    final List<String> suggestions = [];

    if (status['projectExists'] != true) {
      missing.add('Project does not exist');
      suggestions.add('Create the project at https://console.firebase.google.com');
    }

    if (status['billingEnabled'] != true) {
      missing.add('Billing not enabled');
      suggestions.add('Enable billing at https://console.cloud.google.com/billing');
    }

    if (status['firestoreEnabled'] != true) {
      missing.add('Firestore not enabled');
      suggestions.add('Enable Firestore in Firebase Console');
    }

    if (status['authEnabled'] != true) {
      missing.add('Authentication not enabled');
      suggestions.add('Enable Authentication in Firebase Console');
    }

    if (status['storageEnabled'] != true) {
      missing.add('Storage not enabled');
      suggestions.add('Enable Storage in Firebase Console');
    }

    if (status['webAppExists'] != true) {
      missing.add('Web app not registered');
      suggestions.add('Register a web app in Firebase Console');
    }

    if (missing.isEmpty) {
      return {
        'success': true,
        'message': '✅ Project fully configured and ready!',
        'config': result['config'],
      };
    } else {
      return {
        'success': false,
        'message': 'Project incomplete: ${missing.join(", ")}',
        'missing': missing,
        'suggestions': suggestions,
      };
    }
  }
}
