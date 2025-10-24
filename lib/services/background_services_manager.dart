import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'school_context.dart';
import '../notification_service.dart';
import '../main.dart' show initializeWorkmanagerInBackground;
import 'dynamic_firebase_options.dart';
import 'background_cache_service.dart';

/// Background Services Manager
/// Handles initialization of heavy services AFTER the UI is shown
/// This improves perceived startup performance significantly
class BackgroundServicesManager {
  static final BackgroundServicesManager _instance = BackgroundServicesManager._internal();
  factory BackgroundServicesManager() => _instance;
  BackgroundServicesManager._internal();

  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Initialize all background services after UI is ready
  /// This should be called after the user sees the main interface
  Future<void> initializeAfterUI({String? currentUserId, BuildContext? context}) async {
    if (_isInitialized || _isInitializing) return;
    
    _isInitializing = true;
    final bgStopwatch = Stopwatch()..start();
    print('🚀 BackgroundServices: Starting initialization at ${DateTime.now().toIso8601String()}');
    
    try {
      // Run background initializations in parallel where possible
      await Future.wait([
        _initializeWorkmanager(),
        _initializeDesktopServices(),
        _initializeNotificationService(currentUserId),
        _initializeBackgroundImageAndCache(context),
        _ensureFirstAdminUser(),
        _updateFirebaseConfigInBackground(),
      ]);
      
      _isInitialized = true;
      print('✅ BackgroundServices: All services initialized in ${bgStopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      print('❌ BackgroundServices: Error in initialization after ${bgStopwatch.elapsedMilliseconds}ms: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Initialize Workmanager for mobile background tasks
  Future<void> _initializeWorkmanager() async {
    final stopwatch = Stopwatch()..start();
    try {
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || 
                      defaultTargetPlatform == TargetPlatform.iOS)) {
        
        // Call the deferred Workmanager initialization from main.dart
        await initializeWorkmanagerInBackground();
        print('📱 BackgroundServices: Workmanager initialized in ${stopwatch.elapsedMilliseconds}ms');
      } else {
        print('📱 BackgroundServices: Workmanager skipped (not mobile) - ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      print('❌ BackgroundServices: Workmanager error after ${stopwatch.elapsedMilliseconds}ms: $e');
    }
  }

  /// Initialize desktop cleanup timer
  Future<void> _initializeDesktopServices() async {
    final stopwatch = Stopwatch()..start();
    try {
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || 
                      defaultTargetPlatform == TargetPlatform.linux || 
                      defaultTargetPlatform == TargetPlatform.macOS)) {
        
        _startDesktopCleanupTimer();
        print('🖥️ BackgroundServices: Desktop services initialized in ${stopwatch.elapsedMilliseconds}ms');
      } else {
        print('🖥️ BackgroundServices: Desktop services skipped (not desktop) - ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      print('❌ BackgroundServices: Desktop services error after ${stopwatch.elapsedMilliseconds}ms: $e');
    }
  }

  /// Initialize notification service with user context
  Future<void> _initializeNotificationService(String? currentUserId) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (currentUserId != null && currentUserId.isNotEmpty) {
        await NotificationService.instance.init(currentUserId: currentUserId);
        // Always attempt to enable and save token on session restore
        await NotificationService.instance.enableForUser(currentUserId);
        print('🔔 BackgroundServices: Notification service initialized in ${stopwatch.elapsedMilliseconds}ms');
      } else {
        print('🔔 BackgroundServices: Notification service skipped (no user) - ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      print('❌ BackgroundServices: Notification service error after ${stopwatch.elapsedMilliseconds}ms: $e');
    }
  }

  /// Initialize background image and cache service
  Future<void> _initializeBackgroundImageAndCache(BuildContext? context) async {
    final stopwatch = Stopwatch()..start();
    try {
      // Load background image
      final bgStopwatch = Stopwatch()..start();
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final localImagePath = '${appDir.path}/background_image.jpg';
        final localImageFile = File(localImagePath);
        
        if (localImageFile.existsSync()) {
          print('🖼️ BackgroundServices: Background image loaded - ${bgStopwatch.elapsedMilliseconds}ms');
        } else {
          print('🖼️ BackgroundServices: No background image found - ${bgStopwatch.elapsedMilliseconds}ms');
        }
      } catch (e) {
        print('❌ BackgroundServices: Background image error - ${bgStopwatch.elapsedMilliseconds}ms: $e');
      }
      
      // Initialize BackgroundCacheService
      final cacheStopwatch = Stopwatch()..start();
      try {
        await BackgroundCacheService().initialize();
        
        // Precache school background into Flutter's ImageCache if context available
        if (context != null && context.mounted) {
          final schoolId = SchoolContext.currentSchoolId;
          await BackgroundCacheService().precacheBackground(context, schoolId);
        }
        print('🎨 BackgroundServices: Background cache service initialized - ${cacheStopwatch.elapsedMilliseconds}ms');
      } catch (e) {
        print('❌ BackgroundServices: Background cache error - ${cacheStopwatch.elapsedMilliseconds}ms: $e');
      }
      
      print('🖼️ BackgroundServices: Background image and cache complete in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      print('❌ BackgroundServices: Background image/cache error after ${stopwatch.elapsedMilliseconds}ms: $e');
    }
  }

  /// Ensure first admin user exists (moved from startup)
  Future<void> _ensureFirstAdminUser() async {
    final stopwatch = Stopwatch()..start();
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final adminQuery = await users.where('userId', isEqualTo: 'firstadmin').limit(1).get();
      
      if (adminQuery.docs.isEmpty) {
        await users.add({
          'userId': 'firstadmin',
          'password': '123',
          'role': 'admin',
          'name': 'School Admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('👤 BackgroundServices: First admin user created in ${stopwatch.elapsedMilliseconds}ms');
      } else {
        print('👤 BackgroundServices: First admin user already exists - ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      print('❌ BackgroundServices: First admin user error after ${stopwatch.elapsedMilliseconds}ms: $e');
    }
  }

  /// Update Firebase configuration in background (moved from startup)
  Future<void> _updateFirebaseConfigInBackground() async {
    final stopwatch = Stopwatch()..start();
    try {
      await DynamicFirebaseOptions.updateConfigInBackground();
      print('🔥 BackgroundServices: Firebase config updated in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      print('❌ BackgroundServices: Firebase config error after ${stopwatch.elapsedMilliseconds}ms: $e');
    }
  }

  /// Desktop cleanup timer (copied from main.dart)
  Timer? _desktopCleanupTimer;
  
  void _startDesktopCleanupTimer() {
    // Check every minute for scheduled cleanup time
    _desktopCleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool('cleanup_recurring_enabled') ?? false;
        
        if (!enabled) return;
        
        final hour = prefs.getInt('cleanup_recurring_hour') ?? 6;
        final minute = prefs.getInt('cleanup_recurring_minute') ?? 0;
        final now = DateTime.now();
        
        // Check if it's the scheduled time (within 1 minute window)
        if (now.hour == hour && now.minute == minute) {
          debugPrint("Desktop cleanup timer triggered at ${now.hour}:${now.minute}");
          
          // Execute the cleanup similar to the background task
          final preset = prefs.getString('cleanup_recurring_preset') ?? 'today';
          final includeChats = prefs.getBool('cleanup_recurring_includeChats') ?? true;
          final includeAnnouncements = prefs.getBool('cleanup_recurring_includeAnnouncements') ?? true;
          final includeDeviceCache = prefs.getBool('cleanup_recurring_includeDeviceCache') ?? false;
          
          await _performDesktopCleanup(preset, includeChats, includeAnnouncements, includeDeviceCache);
        }
      } catch (e) {
        debugPrint("Desktop cleanup timer error: $e");
      }
    });
  }

  /// Perform desktop cleanup (simplified version)
  Future<void> _performDesktopCleanup(String preset, bool includeChats, bool includeAnnouncements, bool includeDeviceCache) async {
    try {
      debugPrint("Executing desktop cleanup with preset: $preset");
      // Cleanup logic would go here
      // For now, just log that it would happen
    } catch (e) {
      debugPrint("Desktop cleanup error: $e");
    }
  }

  /// Check if services are initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  void dispose() {
    _desktopCleanupTimer?.cancel();
    _desktopCleanupTimer = null;
  }
}