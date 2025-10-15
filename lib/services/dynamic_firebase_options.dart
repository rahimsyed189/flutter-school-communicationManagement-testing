import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../firebase_options.dart';

class DynamicFirebaseOptions {
  static FirebaseOptions? _cachedOptions;
  
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
  
  /// Check if school key is configured
  static Future<bool> hasSchoolKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('has_school_key') ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Get current school key
  static Future<String?> getSchoolKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('school_key');
    } catch (e) {
      return null;
    }
  }
  
  /// Get current school name
  static Future<String?> getSchoolName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('school_name');
    } catch (e) {
      return null;
    }
  }
}
