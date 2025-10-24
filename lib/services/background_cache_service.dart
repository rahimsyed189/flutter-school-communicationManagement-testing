import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Global singleton service for caching background images using Flutter's ImageCache
/// This is how WhatsApp does it - decoded images stay in GPU memory!
class BackgroundCacheService {
  static final BackgroundCacheService _instance = BackgroundCacheService._internal();
  factory BackgroundCacheService() => _instance;
  BackgroundCacheService._internal();

  // Track which backgrounds have been precached
  final Map<String, bool> _precached = {};
  
  // Cached directory path (set once on first access)
  String? _cachedDirPath;

  /// Initialize directory path (call once on app startup)
  Future<void> initialize() async {
    if (_cachedDirPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _cachedDirPath = dir.path;
      print('📁 BackgroundCacheService initialized: $_cachedDirPath');
    }
  }

  /// Precache background into Flutter's ImageCache (decoded in GPU memory)
  /// This is the WhatsApp approach - decode once, keep forever in GPU!
  Future<void> precacheBackground(BuildContext context, String schoolId) async {
    if (_precached[schoolId] == true) {
      print('⚡ Background already in Flutter ImageCache for $schoolId');
      return;
    }

    if (_cachedDirPath == null) {
      await initialize();
    }

    try {
      final file = File('$_cachedDirPath/backgrounds/bg_$schoolId.jpg');
      if (file.existsSync()) {
        // Precache into Flutter's ImageCache (GPU memory - WhatsApp style!)
        final imageProvider = FileImage(file);
        await precacheImage(imageProvider, context);
        _precached[schoolId] = true;
        print('🚀 Background PRECACHED into Flutter ImageCache (GPU memory): $schoolId');
      }
    } catch (e) {
      print('❌ Error precaching background: $e');
    }
  }

  /// Get background file path (image already precached in GPU)
  String? getBackgroundPath(String schoolId) {
    if (_cachedDirPath == null) return null;
    
    try {
      final file = File('$_cachedDirPath/backgrounds/bg_$schoolId.jpg');
      if (file.existsSync()) {
        return file.path;
      }
    } catch (e) {
      print('❌ Error getting background path: $e');
    }
    
    return null;
  }

  /// Check if background exists on disk
  bool hasBackground(String schoolId) {
    if (_cachedDirPath == null) return false;
    
    try {
      final file = File('$_cachedDirPath/backgrounds/bg_$schoolId.jpg');
      return file.existsSync();
    } catch (e) {
      return false;
    }
  }

  /// Check if background is precached in Flutter's ImageCache
  bool isPrecached(String schoolId) {
    return _precached[schoolId] == true;
  }

  /// Clear cache for a specific school
  void clearSchool(String schoolId) {
    _precached.remove(schoolId);
  }

  /// Clear all cached backgrounds
  void clearAll() {
    _precached.clear();
  }
}
