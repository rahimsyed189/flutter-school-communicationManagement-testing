import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../firebase_options.dart';

class DynamicFirebaseOptions {
  static FirebaseOptions? _cachedOptions;
  
  // 🚀 IN-MEMORY CACHE for instant startup
  static bool? _cachedHasSchoolKey;
  static String? _cachedSchoolKey;
  static String? _cachedSchoolName;
  
  // 🚀 IN-MEMORY CACHE for login state (instant session restore!)
  static String? _cachedSessionUserId;
  static String? _cachedSessionRole;
  
  /// Get Firebase options - checks local storage first, then Firestore, or defaults
  static Future<FirebaseOptions> getOptions() async {
    // Return cached options if available in memory
    if (_cachedOptions != null) {
      return _cachedOptions!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if using default configuration
      final useDefault = prefs.getBool('use_default_firebase') ?? false;
      
      if (useDefault) {
        _cachedOptions = DefaultFirebaseOptions.currentPlatform;
        debugPrint('✅ Using default Firebase configuration (user preference)');
        return _cachedOptions!;
      }
      
      // Determine current platform
      String platform;
      if (kIsWeb) {
        platform = 'web';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            platform = 'android';
            break;
          case TargetPlatform.iOS:
            platform = 'ios';
            break;
          case TargetPlatform.macOS:
            platform = 'macos';
            break;
          case TargetPlatform.windows:
            platform = 'windows';
            break;
          default:
            platform = 'web';
        }
      }
      
      // PRIORITY 1: Check local storage for cached Firebase config (INSTANT - No network!)
      final cachedConfigJson = prefs.getString('firebase_config_cached_$platform');
      if (cachedConfigJson != null && cachedConfigJson.isNotEmpty) {
        try {
          final cachedData = jsonDecode(cachedConfigJson) as Map<String, dynamic>;
          
          _cachedOptions = FirebaseOptions(
            apiKey: cachedData['apiKey'] ?? '',
            appId: cachedData['appId'] ?? '',
            messagingSenderId: cachedData['messagingSenderId'] ?? '',
            projectId: cachedData['projectId'] ?? '',
            authDomain: cachedData['authDomain'],
            databaseURL: cachedData['databaseURL'],
            storageBucket: cachedData['storageBucket'],
            measurementId: cachedData['measurementId'],
            trackingId: cachedData['trackingId'],
            deepLinkURLScheme: cachedData['deepLinkURLScheme'],
            androidClientId: cachedData['androidClientId'],
            iosClientId: cachedData['iosClientId'],
            iosBundleId: cachedData['iosBundleId'],
            appGroupId: cachedData['appGroupId'],
          );
          
          debugPrint('⚡ Using cached Firebase config from local storage (INSTANT) for $platform');
          return _cachedOptions!;
        } catch (e) {
          debugPrint('⚠️ Error loading cached config: $e');
        }
      }
      
      // PRIORITY 2: Check if school key exists in local storage
      final schoolKey = prefs.getString('school_key');
      
      if (schoolKey != null && schoolKey.isNotEmpty) {
        // Try to load configuration for this school key from Firestore
        try {
          final doc = await FirebaseFirestore.instance
              .collection('school_registrations')
              .doc(schoolKey)
              .get();
          
          if (doc.exists) {
            final data = doc.data()!;
            
            if (data.containsKey('firebaseConfig')) {
              final firebaseConfig = data['firebaseConfig'] as Map<String, dynamic>;
              if (firebaseConfig.containsKey(platform)) {
                final platformData = firebaseConfig[platform] as Map<String, dynamic>;
                
                // Build FirebaseOptions from school-specific config
                _cachedOptions = FirebaseOptions(
                  apiKey: platformData['apiKey'] ?? '',
                  appId: platformData['appId'] ?? '',
                  messagingSenderId: platformData['messagingSenderId'] ?? '',
                  projectId: platformData['projectId'] ?? '',
                  authDomain: platformData['authDomain'],
                  databaseURL: platformData['databaseURL'],
                  storageBucket: platformData['storageBucket'],
                  measurementId: platformData['measurementId'],
                  trackingId: platformData['trackingId'],
                  deepLinkURLScheme: platformData['deepLinkURLScheme'],
                  androidClientId: platformData['androidClientId'],
                  iosClientId: platformData['iosClientId'],
                  iosBundleId: platformData['iosBundleId'],
                  appGroupId: platformData['appGroupId'],
                );
                
                // 🔥 SAVE TO LOCAL STORAGE FOR NEXT LAUNCH (Instant load!)
                await prefs.setString('firebase_config_cached_$platform', jsonEncode(platformData));
                
                debugPrint('✅ Using school-specific Firebase config for $platform (Key: $schoolKey) - SAVED TO CACHE');
                return _cachedOptions!;
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error loading school Firebase config: $e');
        }
      }
      
      // PRIORITY 3: Fallback: Try loading from old global config method (backward compatibility)
      // PRIORITY 3: Fallback: Try loading from old global config method (backward compatibility)
      try {
        final doc = await FirebaseFirestore.instance
            .collection('app_config')
            .doc('firebase_config')
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          final useCustomConfig = data['useCustomConfig'] ?? false;
          
          if (useCustomConfig) {
            if (data.containsKey(platform)) {
              final platformData = data[platform] as Map<String, dynamic>;
              
              _cachedOptions = FirebaseOptions(
                apiKey: platformData['apiKey'] ?? '',
                appId: platformData['appId'] ?? '',
                messagingSenderId: platformData['messagingSenderId'] ?? '',
                projectId: platformData['projectId'] ?? '',
                authDomain: platformData['authDomain'],
                databaseURL: platformData['databaseURL'],
                storageBucket: platformData['storageBucket'],
                measurementId: platformData['measurementId'],
                trackingId: platformData['trackingId'],
                deepLinkURLScheme: platformData['deepLinkURLScheme'],
                androidClientId: platformData['androidClientId'],
                iosClientId: platformData['iosClientId'],
                iosBundleId: platformData['iosBundleId'],
                appGroupId: platformData['appGroupId'],
              );
              
              // 🔥 SAVE TO LOCAL STORAGE FOR NEXT LAUNCH
              await prefs.setString('firebase_config_cached_$platform', jsonEncode(platformData));
              
              debugPrint('✅ Using custom Firebase config for $platform (global config) - SAVED TO CACHE');
              return _cachedOptions!;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error loading custom Firebase config: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Error in Firebase options loading: $e');
    }
    
    // Fallback to default configuration
    _cachedOptions = DefaultFirebaseOptions.currentPlatform;
    debugPrint('✅ Using default Firebase configuration (fallback)');
    return _cachedOptions!;
  }
  
  /// Clear cached options (useful after configuration changes)
  static Future<void> clearCache() async {
    _cachedOptions = null;
    
    // 🚀 Clear in-memory caches
    _cachedHasSchoolKey = null;
    _cachedSchoolKey = null;
    _cachedSchoolName = null;
    _cachedSessionUserId = null;
    _cachedSessionRole = null;
    
    // Clear local storage cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('firebase_config_cached_web');
      await prefs.remove('firebase_config_cached_android');
      await prefs.remove('firebase_config_cached_ios');
      await prefs.remove('firebase_config_cached_macos');
      await prefs.remove('firebase_config_cached_windows');
      debugPrint('🔄 Firebase options cache cleared (memory + local storage)');
    } catch (e) {
      debugPrint('⚠️ Error clearing local storage cache: $e');
    }
  }
  
  /// Check if school key is configured (INSTANT with in-memory cache!)
  static Future<bool> hasSchoolKey() async {
    // 🚀 Return cached value instantly (no storage read!)
    if (_cachedHasSchoolKey != null) {
      debugPrint('⚡ hasSchoolKey: Using in-memory cache = $_cachedHasSchoolKey (INSTANT)');
      return _cachedHasSchoolKey!;
    }
    
    // First call: Read from storage and cache it
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedHasSchoolKey = prefs.getBool('has_school_key') ?? false;
      debugPrint('✅ hasSchoolKey: Loaded from SharedPreferences = $_cachedHasSchoolKey (CACHED for next time)');
      return _cachedHasSchoolKey!;
    } catch (e) {
      _cachedHasSchoolKey = false;
      return false;
    }
  }
  
  /// Get current school key (INSTANT with in-memory cache!)
  static Future<String?> getSchoolKey() async {
    // 🚀 Return cached value instantly
    if (_cachedSchoolKey != null) {
      debugPrint('⚡ getSchoolKey: Using in-memory cache (INSTANT)');
      return _cachedSchoolKey;
    }
    
    // First call: Read from storage and cache it
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedSchoolKey = prefs.getString('school_key');
      debugPrint('✅ getSchoolKey: Loaded from SharedPreferences (CACHED for next time)');
      return _cachedSchoolKey;
    } catch (e) {
      return null;
    }
  }
  
  /// Get current school name (INSTANT with in-memory cache!)
  static Future<String?> getSchoolName() async {
    // 🚀 Return cached value instantly
    if (_cachedSchoolName != null) {
      debugPrint('⚡ getSchoolName: Using in-memory cache (INSTANT)');
      return _cachedSchoolName;
    }
    
    // First call: Read from storage and cache it
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedSchoolName = prefs.getString('school_name');
      debugPrint('✅ getSchoolName: Loaded from SharedPreferences (CACHED for next time)');
      return _cachedSchoolName;
    } catch (e) {
      return null;
    }
  }
  
  /// Update school key and refresh cache (call this when saving new school key)
  static Future<void> setSchoolKey(String schoolKey, String schoolName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('school_key', schoolKey);
      await prefs.setString('school_name', schoolName);
      await prefs.setBool('has_school_key', true);
      
      // 🚀 Update in-memory cache instantly
      _cachedSchoolKey = schoolKey;
      _cachedSchoolName = schoolName;
      _cachedHasSchoolKey = true;
      
      debugPrint('✅ School key saved and cached: $schoolKey');
    } catch (e) {
      debugPrint('⚠️ Error saving school key: $e');
    }
  }
  
  /// Get session user ID (INSTANT with in-memory cache!)
  static Future<String?> getSessionUserId() async {
    // 🚀 Return cached value instantly
    if (_cachedSessionUserId != null) {
      debugPrint('⚡ getSessionUserId: Using in-memory cache (INSTANT)');
      return _cachedSessionUserId;
    }
    
    // First call: Read from storage and cache it
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedSessionUserId = prefs.getString('session_userId');
      debugPrint('✅ getSessionUserId: Loaded from SharedPreferences (CACHED for next time)');
      return _cachedSessionUserId;
    } catch (e) {
      return null;
    }
  }
  
  /// Get session user role (INSTANT with in-memory cache!)
  static Future<String?> getSessionRole() async {
    // 🚀 Return cached value instantly
    if (_cachedSessionRole != null) {
      debugPrint('⚡ getSessionRole: Using in-memory cache (INSTANT)');
      return _cachedSessionRole;
    }
    
    // First call: Read from storage and cache it
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedSessionRole = prefs.getString('session_role');
      debugPrint('✅ getSessionRole: Loaded from SharedPreferences (CACHED for next time)');
      return _cachedSessionRole;
    } catch (e) {
      return null;
    }
  }
  
  /// Save session and update cache (call this on login)
  static Future<void> saveSession(String userId, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_userId', userId);
      await prefs.setString('session_role', role);
      
      // 🚀 Update in-memory cache instantly
      _cachedSessionUserId = userId;
      _cachedSessionRole = role;
      
      debugPrint('✅ Session saved and cached: $userId ($role)');
    } catch (e) {
      debugPrint('⚠️ Error saving session: $e');
    }
  }
  
  /// Clear session and cache (call this on logout)
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_userId');
      await prefs.remove('session_role');
      
      // 🚀 Clear in-memory cache
      _cachedSessionUserId = null;
      _cachedSessionRole = null;
      
      debugPrint('✅ Session cleared from storage and cache');
    } catch (e) {
      debugPrint('⚠️ Error clearing session: $e');
    }
  }
}
