import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Service to automatically create Firebase projects for users
/// using their Google OAuth credentials
class AutoFirebaseCreator {
  // Google Sign-In with Cloud Platform scope for Firebase Management API
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/cloud-platform', // Full Cloud Platform access
      'https://www.googleapis.com/auth/firebase', // Firebase Management
      'https://www.googleapis.com/auth/cloudplatformprojects', // Project creation
    ],
  );

  /// Sign in with Google and get OAuth token with required permissions
  /// Always forces account selection, even if already logged in
  static Future<String?> signInWithGoogle() async {
    try {
      debugPrint('🔐 Starting Google Sign-In with Firebase Management permissions...');
      
      // Sign out first to force account selection on every tap
      await _googleSignIn.signOut();
      debugPrint('🔄 Signed out to force fresh login...');
      
      // Sign in - will always show account picker
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        debugPrint('❌ User cancelled Google Sign-In');
        return null;
      }

      debugPrint('✅ Google Sign-In successful: ${account.email}');

      // Get authentication
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

  /// Create a Firebase project automatically using user's credentials
  /// Returns the Firebase configuration for all platforms
  static Future<Map<String, dynamic>?> createFirebaseProject({
    required String accessToken,
    required String projectId,
    required String displayName,
    required String cloudFunctionUrl,
  }) async {
    try {
      debugPrint('🚀 Creating Firebase project: $projectId');
      debugPrint('📍 Cloud Function URL: $cloudFunctionUrl');

      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'accessToken': accessToken,
          'projectId': projectId,
          'displayName': displayName,
        }),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          debugPrint('✅ Firebase project created successfully!');
          return data;
        } else {
          debugPrint('❌ Project creation failed: ${data['error']}');
          return null;
        }
      } else {
        debugPrint('❌ HTTP Error ${response.statusCode}: ${response.body}');
        return null;
      }
      
    } catch (e) {
      debugPrint('❌ Error creating Firebase project: $e');
      return null;
    }
  }

  /// Parse the Firebase configuration response and convert to form-fillable format
  static Map<String, Map<String, String>> parseFirebaseConfig(
    Map<String, dynamic> responseData,
  ) {
    final configs = responseData['configs'] as Map<String, dynamic>?;
    if (configs == null) {
      return {};
    }

    final result = <String, Map<String, String>>{};

    // Parse Web config
    if (configs['web'] != null) {
      final webData = configs['web'] as Map<String, dynamic>;
      result['web'] = {
        'apiKey': webData['apiKey']?.toString() ?? '',
        'appId': webData['appId']?.toString() ?? '',
        'messagingSenderId': webData['messagingSenderId']?.toString() ?? '',
        'projectId': webData['projectId']?.toString() ?? '',
        'authDomain': webData['authDomain']?.toString() ?? '',
        'databaseURL': webData['databaseURL']?.toString() ?? '',
        'storageBucket': webData['storageBucket']?.toString() ?? '',
        'measurementId': webData['measurementId']?.toString() ?? '',
      };
    }

    // Parse Android config
    if (configs['android'] != null) {
      final androidData = configs['android'] as Map<String, dynamic>;
      result['android'] = {
        'apiKey': androidData['apiKey']?.toString() ?? '',
        'appId': androidData['appId']?.toString() ?? '',
        'messagingSenderId': androidData['messagingSenderId']?.toString() ?? '',
        'projectId': androidData['projectId']?.toString() ?? '',
        'databaseURL': androidData['databaseURL']?.toString() ?? '',
        'storageBucket': androidData['storageBucket']?.toString() ?? '',
      };
    }

    // Parse iOS config
    if (configs['ios'] != null) {
      final iosData = configs['ios'] as Map<String, dynamic>;
      result['ios'] = {
        'apiKey': iosData['apiKey']?.toString() ?? '',
        'appId': iosData['appId']?.toString() ?? '',
        'messagingSenderId': iosData['messagingSenderId']?.toString() ?? '',
        'projectId': iosData['projectId']?.toString() ?? '',
        'databaseURL': iosData['databaseURL']?.toString() ?? '',
        'storageBucket': iosData['storageBucket']?.toString() ?? '',
        'androidClientId': iosData['androidClientId']?.toString() ?? '',
        'iosBundleId': iosData['iosBundleId']?.toString() ?? '',
      };
    }

    // macOS and Windows can use same config as iOS/Web respectively
    if (result.containsKey('ios')) {
      result['macos'] = Map.from(result['ios']!);
    }
    if (result.containsKey('web')) {
      result['windows'] = Map.from(result['web']!);
    }

    return result;
  }

  /// Sign out from Google
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Check if user is currently signed in
  static Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Get current user email if signed in
  static Future<String?> getCurrentUserEmail() async {
    final account = _googleSignIn.currentUser;
    return account?.email;
  }

  /// Generate a valid Firebase project ID from school name
  static String generateProjectId(String schoolName) {
    // Convert to lowercase, remove special chars, replace spaces with hyphens
    String projectId = schoolName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();

    // Firebase project IDs must be 6-30 characters
    if (projectId.length < 6) {
      projectId = '$projectId-school';
    }
    if (projectId.length > 30) {
      projectId = projectId.substring(0, 30);
    }

    // Must not end with hyphen
    if (projectId.endsWith('-')) {
      projectId = projectId.substring(0, projectId.length - 1);
    }

    // Add random suffix to ensure uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    projectId = '$projectId-$timestamp';

    // Ensure final ID is valid length
    if (projectId.length > 30) {
      projectId = projectId.substring(0, 30);
    }

    return projectId;
  }

  /// Validate project ID format
  static bool isValidProjectId(String projectId) {
    // Must be 6-30 characters
    if (projectId.length < 6 || projectId.length > 30) {
      return false;
    }

    // Must start with letter, contain only lowercase letters, numbers, hyphens
    final regex = RegExp(r'^[a-z][a-z0-9-]*$');
    if (!regex.hasMatch(projectId)) {
      return false;
    }

    // Must not end with hyphen
    if (projectId.endsWith('-')) {
      return false;
    }

    return true;
  }
}
