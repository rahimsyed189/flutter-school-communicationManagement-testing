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

  /// Get the currently signed-in user's email
  static Future<String?> getCurrentUserEmail() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return account?.email;
    } catch (e) {
      debugPrint('❌ Error getting current user email: $e');
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
    
    // Extract billing info (available in both billing_required and completed stages)
    final billingPlan = result['billingPlan'] as String?;
    final billingAccountName = result['billingAccountName'] as String?;
    final billingEnabled = result['billingEnabled'] as bool?;

    if (stage == 'billing_required') {
      // Add billing info to instructions
      final billingInstructions = Map<String, dynamic>.from(
        result['billingInstructions'] as Map<String, dynamic>? ?? {}
      );
      billingInstructions['billingPlan'] = billingPlan;
      billingInstructions['billingAccountName'] = billingAccountName;
      
      return {
        'success': false,
        'needsBilling': true,
        'billingEnabled': billingEnabled,
        'billingPlan': billingPlan,
        'billingAccountName': billingAccountName,
        'billingInstructions': billingInstructions,
        'message': result['message'] ?? 'Billing required',
      };
    }

    if (stage == 'completed') {
      return {
        'success': true,
        'needsBilling': false,
        'billingEnabled': billingEnabled,
        'billingPlan': billingPlan,
        'billingAccountName': billingAccountName,
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
        
        // Log what we received
        debugPrint('📦 Full response data: $data');
        debugPrint('🔍 Checking config data...');
        
        if (data['config'] != null) {
          debugPrint('✅ CONFIG FOUND in response!');
          final config = data['config'];
          
          if (config['web'] != null) {
            debugPrint('  ✅ WEB CONFIG FOUND:');
            debugPrint('     - apiKey: ${config['web']['apiKey']?.toString().substring(0, 10)}...');
            debugPrint('     - appId: ${config['web']['appId']}');
            debugPrint('     - projectId: ${config['web']['projectId']}');
          } else {
            debugPrint('  ⚠️ NO WEB CONFIG - Web app not created in Firebase Console');
          }
          
          if (config['android'] != null) {
            debugPrint('  ✅ ANDROID CONFIG FOUND:');
            debugPrint('     - mobilesdk_app_id: ${config['android']['mobilesdk_app_id']}');
            debugPrint('     - current_key: ${config['android']['current_key']?.toString().substring(0, 10)}...');
            debugPrint('     - project_id: ${config['android']['project_id']}');
          } else {
            debugPrint('  ⚠️ NO ANDROID CONFIG - Android app not created in Firebase Console');
          }
          
          if (config['ios'] != null) {
            debugPrint('  ✅ IOS CONFIG FOUND:');
            debugPrint('     - mobilesdk_app_id: ${config['ios']['mobilesdk_app_id']}');
            debugPrint('     - api_key: ${config['ios']['api_key']?.toString().substring(0, 10)}...');
            debugPrint('     - project_id: ${config['ios']['project_id']}');
          } else {
            debugPrint('  ⚠️ NO IOS CONFIG - iOS app not created in Firebase Console');
          }
        } else {
          debugPrint('❌ NO CONFIG DATA IN RESPONSE!');
          debugPrint('   This means no apps (Web/Android/iOS) have been created in Firebase Console yet.');
        }
        
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

  /// AUTO-CREATE APPS + FETCH CONFIG
  /// Creates Web/Android/iOS apps automatically if they don't exist,
  /// then fetches all API keys in one call
  static Future<Map<String, dynamic>?> autoCreateAppsAndFetchConfig({
    required String projectId,
    required String accessToken,
    String? androidPackageName,
    String? iosBundleId,
  }) async {
    try {
      debugPrint('🚀 AUTO-CREATING apps and fetching config for: $projectId');

      const cloudFunctionUrl = 
          'https://us-central1-adilabadautocabs.cloudfunctions.net/autoCreateAppsAndFetchConfig';

      debugPrint('📍 Calling Cloud Function: $cloudFunctionUrl');

      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accessToken': accessToken,
          'projectId': projectId,
          'appPackageName': androidPackageName ?? 'com.school.management',
          'iosBundleId': iosBundleId ?? 'com.school.management',
        }),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Auto-create completed successfully!');
        
        // Log what was created
        debugPrint('📦 Full response data: $data');
        debugPrint('🔍 Apps created status:');
        
        if (data['appsCreated'] != null) {
          final appsCreated = data['appsCreated'];
          debugPrint('  📱 Web: ${appsCreated['web'] == true ? "✅ Created/Exists" : "❌ Failed"}');
          debugPrint('  🤖 Android: ${appsCreated['android'] == true ? "✅ Created/Exists" : "❌ Failed"}');
          debugPrint('  🍎 iOS: ${appsCreated['ios'] == true ? "✅ Created/Exists" : "❌ Failed"}');
        }
        
        if (data['config'] != null) {
          debugPrint('✅ CONFIG FETCHED!');
          final config = data['config'];
          
          if (config['web'] != null) {
            final webApiKey = config['web']['apiKey']?.toString() ?? '';
            debugPrint('  ✅ WEB CONFIG: ${webApiKey.length > 10 ? webApiKey.substring(0, 10) + "..." : webApiKey.isEmpty ? "EMPTY" : webApiKey}');
          }
          
          if (config['android'] != null) {
            final androidApiKey = config['android']['current_key']?.toString() ?? '';
            debugPrint('  ✅ ANDROID CONFIG: ${androidApiKey.length > 10 ? androidApiKey.substring(0, 10) + "..." : androidApiKey.isEmpty ? "EMPTY" : androidApiKey}');
          }
          
          if (config['ios'] != null) {
            final iosApiKey = config['ios']['api_key']?.toString() ?? '';
            debugPrint('  ✅ IOS CONFIG: ${iosApiKey.length > 10 ? iosApiKey.substring(0, 10) + "..." : iosApiKey.isEmpty ? "EMPTY" : iosApiKey}');
          }
        }
        
        return data;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        debugPrint('⚠️ Auto-create failed: ${error['error']}');
        return error;
      } else {
        final error = jsonDecode(response.body);
        debugPrint('❌ Auto-create failed: ${error['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error in auto-create: $e');
      return null;
    }
  }

  /// Parse fetched config into form-fillable format
  static Map<String, Map<String, String>> parseFirebaseConfig(Map<String, dynamic> config) {
    final result = <String, Map<String, String>>{};
    
    // Parse Web config
    if (config['web'] != null) {
      result['web'] = {
        'apiKey': config['web']?['apiKey']?.toString() ?? '',
        'appId': config['web']?['appId']?.toString() ?? '',
        'messagingSenderId': config['web']?['messagingSenderId']?.toString() ?? '',
        'projectId': config['web']?['projectId']?.toString() ?? '',
        'authDomain': config['web']?['authDomain']?.toString() ?? '',
        'databaseURL': config['web']?['databaseURL']?.toString() ?? '',
        'storageBucket': config['web']?['storageBucket']?.toString() ?? '',
        'measurementId': config['web']?['measurementId']?.toString() ?? '',
      };
    }
    
    // Parse Android config
    if (config['android'] != null) {
      result['android'] = {
        'apiKey': config['android']?['current_key']?.toString() ?? '',
        'appId': config['android']?['mobilesdk_app_id']?.toString() ?? '',
        'messagingSenderId': '', // Not available in Android config
        'projectId': config['android']?['project_id']?.toString() ?? '',
        'databaseURL': '',
        'storageBucket': config['android']?['storage_bucket']?.toString() ?? '',
      };
    }
    
    // Parse iOS config
    if (config['ios'] != null) {
      result['ios'] = {
        'apiKey': config['ios']?['api_key']?.toString() ?? '',
        'appId': config['ios']?['mobilesdk_app_id']?.toString() ?? '',
        'messagingSenderId': '', // Not available in iOS config
        'projectId': config['ios']?['project_id']?.toString() ?? '',
        'databaseURL': '',
        'storageBucket': config['ios']?['storage_bucket']?.toString() ?? '',
        'androidClientId': '',
        'iosBundleId': config['ios']?['bundle_id']?.toString() ?? '',
      };
    }
    
    // macOS and Windows can reuse web config
    if (result.containsKey('web')) {
      result['macos'] = Map.from(result['web']!);
      result['windows'] = Map.from(result['web']!);
    }
    
    // If iOS exists, copy to macOS (override web)
    if (result.containsKey('ios')) {
      result['macos'] = Map.from(result['ios']!);
    }
    
    return result;
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
