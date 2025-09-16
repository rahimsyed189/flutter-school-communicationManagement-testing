import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:minio/minio.dart';
import 'dart:convert';
import 'download_state.dart';

enum CleanupPreset { 
  today, 
  last7, 
  last30, 
  custom 
}

class _Range {
  final DateTime start;
  final DateTime endExclusive;
  const _Range(this.start, this.endExclusive);
}

class AdminCleanupPage extends StatefulWidget {
  final String currentUserId;
  const AdminCleanupPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<AdminCleanupPage> createState() => _AdminCleanupPageState();
}

class _AdminCleanupPageState extends State<AdminCleanupPage> {
  CleanupPreset _preset = CleanupPreset.today;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _includeChats = true;
  bool _includeAnnouncements = true;
  bool _includeDeviceCache = false;
  bool _includeAppStorage = false;
  bool _includeR2Storage = false;
  bool _confirm = false;
  bool _busy = false;
  bool _recurring = false;
  bool _loadingPrefs = true;
  bool _r2CleanupLocked = false;
  String? _r2LockUserId;
  
  // Time scheduling variables
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 6, minute: 0); // Default 6:00 AM
  bool _hasUnsavedChanges = false;
  bool _recurringEnabled = false;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endExclusiveOfDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  Future<bool> _checkDailyCleanupStatus(String preset) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD format
      final statusDoc = FirebaseFirestore.instance.collection('app_config').doc('daily_cleanup_status');
      
      bool canProceed = false;
      String? completedBy;
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(statusDoc);
        final data = doc.data();
        
        if (data != null && data['completedDate'] == today && data['preset'] == preset) {
          // Already completed today with same preset
          completedBy = data['completedBy'];
          canProceed = false;
          return;
        }
        
        // Mark as completed by current user
        transaction.set(statusDoc, {
          'completedDate': today,
          'completedBy': widget.currentUserId,
          'preset': preset,
          'timestamp': FieldValue.serverTimestamp(),
          'deviceInfo': Platform.operatingSystem,
        });
        canProceed = true;
      });
      
      if (!canProceed && completedBy != null) {
        // Get user name for display
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(completedBy).get();
          final userName = userDoc.data()?['name'] ?? 'Unknown User';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Daily cleanup already completed today by $userName'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              )
            );
          }
        } catch (_) {}
        return false;
      }
      
      return canProceed;
    } catch (e) {
      print("Error checking daily cleanup status: $e");
      return true; // Allow cleanup on error to prevent blocking
    }
  }

  _Range _resolveRange() {
    final now = DateTime.now();
    switch (_preset) {
      case CleanupPreset.today:
        final s = _startOfDay(now);
        return _Range(s, _endExclusiveOfDay(now));
      case CleanupPreset.last7:
        final s = _startOfDay(now.subtract(const Duration(days: 6)));
        return _Range(s, _endExclusiveOfDay(now));
      case CleanupPreset.last30:
        final s = _startOfDay(now.subtract(const Duration(days: 29)));
        return _Range(s, _endExclusiveOfDay(now));
      case CleanupPreset.custom:
        if (_customStart != null && _customEnd != null) {
          return _Range(_startOfDay(_customStart!), _endExclusiveOfDay(_customEnd!));
        } else {
          final s = _startOfDay(now);
          return _Range(s, _endExclusiveOfDay(now));
        }
    }
  }

  Future<int> _deleteRange(String collection, DateTime start, DateTime endExclusive) async {
    int deleted = 0;
    try {
      final base = FirebaseFirestore.instance
          .collection(collection)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThan: Timestamp.fromDate(endExclusive))
          .orderBy('timestamp');
      DocumentSnapshot? cursor;
      while (true) {
        Query q = base.limit(300);
        if (cursor != null) {
          q = (q as Query<Map<String, dynamic>>).startAfterDocument(cursor) as Query;
        }
        final snap = await q.get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        deleted += snap.docs.length;
        cursor = snap.docs.last;
        await Future<void>.delayed(Duration.zero);
      }
    } catch (e) {
      print("Error deleting from $collection: $e");
    }
    return deleted;
  }

  Future<int> _clearDeviceCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int filesDeleted = 0;
      
      // Get cache directory
      try {
        final cacheDir = await getTemporaryDirectory();
        print("Clearing cache directory: ${cacheDir.path}");
        
        if (await cacheDir.exists()) {
          final entities = cacheDir.listSync(recursive: true);
          for (final entity in entities) {
            try {
              if (entity is File) {
                await entity.delete();
                filesDeleted++;
                print("Deleted cache file: ${entity.path}");
              }
            } catch (e) {
              print("Error deleting file from cache dir: ${entity.path} - $e");
            }
          }
        }
      } catch (e) {
        print("Error listing cache directory: $e");
      }
      
      // Get downloads directory and clear downloads
      try {
        final downloadDir = await getApplicationDocumentsDirectory();
        final downloadPath = Directory('${downloadDir.path}/downloads');
        print("Clearing downloads directory: ${downloadPath.path}");
        
        if (await downloadPath.exists()) {
          final entities = downloadPath.listSync(recursive: true);
          for (final entity in entities) {
            try {
              if (entity is File) {
                await entity.delete();
                filesDeleted++;
                print("Deleted download file: ${entity.path}");
              }
            } catch (e) {
              print("Error deleting file from downloads dir: ${entity.path} - $e");
            }
          }
        }
      } catch (e) {
        print("Error listing downloads directory: $e");
      }
      
      // Get app cache directory
      try {
        final appCacheDir = await getApplicationSupportDirectory();
        print("Clearing app cache directory: ${appCacheDir.path}");
        
        if (await appCacheDir.exists()) {
          final entities = appCacheDir.listSync(recursive: true);
          for (final entity in entities) {
            try {
              if (entity is File) {
                await entity.delete();
                filesDeleted++;
                print("Deleted app cache file: ${entity.path}");
              }
            } catch (e) {
              print("Error deleting file from app cache dir: ${entity.path} - $e");
            }
          }
        }
      } catch (e) {
        print("Error listing app cache directory: $e");
      }
      
      // Clear the cache entries in SharedPreferences
      await prefs.setString('downloaded_files', '{}');
      await prefs.setString('downloaded_thumbnails', '{}');
      print("Cleared SharedPreferences cache entries");
      
      return filesDeleted > 0 ? filesDeleted : 1; // Return count of deleted files or at least 1 for success
    } catch (e) {
      print("Error clearing device cache: $e");
      return 0;
    }
  }

  Future<int> _clearAppStorage() async {
    try {
      int filesDeleted = 0;
      
      // Clear app downloads (app_videos and app_thumbnails)
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final appVideosDir = Directory('${appDir.path}/app_videos');
        final appThumbnailsDir = Directory('${appDir.path}/app_thumbnails');
        
        // Clear app_videos directory
        if (await appVideosDir.exists()) {
          print("Clearing app videos directory: ${appVideosDir.path}");
          final entities = appVideosDir.listSync(recursive: true);
          for (final entity in entities) {
            try {
              if (entity is File) {
                await entity.delete();
                filesDeleted++;
                print("Deleted app video file: ${entity.path}");
              }
            } catch (e) {
              print("Error deleting app video file: ${entity.path} - $e");
            }
          }
        }
        
        // Clear app_thumbnails directory
        if (await appThumbnailsDir.exists()) {
          print("Clearing app thumbnails directory: ${appThumbnailsDir.path}");
          final entities = appThumbnailsDir.listSync(recursive: true);
          for (final entity in entities) {
            try {
              if (entity is File) {
                await entity.delete();
                filesDeleted++;
                print("Deleted app thumbnail file: ${entity.path}");
              }
            } catch (e) {
              print("Error deleting app thumbnail file: ${entity.path} - $e");
            }
          }
        }
      } catch (e) {
        print("Error clearing app downloads directories: $e");
      }
      
      return filesDeleted > 0 ? filesDeleted : 1; // Return count of deleted files or at least 1 for success
    } catch (e) {
      print("Error clearing app storage: $e");
      return 0;
    }
  }

  Future<int> _clearR2Storage(DateTime start, DateTime endExclusive) async {
    // This function deletes ALL objects from R2 storage bucket - NO FIRESTORE CHECKS
    try {
      // Check if cleanup is already in progress (global lock across all users)
      final lockDoc = FirebaseFirestore.instance.collection('app_config').doc('cleanup_lock');
      
      final lockData = await lockDoc.get();
      if (lockData.exists) {
        final lockInfo = lockData.data() as Map<String, dynamic>;
        final isLocked = lockInfo['isLocked'] as bool? ?? false;
        final lockTime = lockInfo['lockTime'] as Timestamp?;
        
        if (isLocked && lockTime != null) {
          final lockAge = DateTime.now().difference(lockTime.toDate());
          // If lock is less than 10 minutes old, another cleanup is running
          if (lockAge.inMinutes < 10) {
            print("R2 cleanup already in progress by another user. Skipping...");
            return 0;
          } else {
            print("Found stale cleanup lock (${lockAge.inMinutes} minutes old). Will proceed...");
          }
        }
      }
      
      // Acquire cleanup lock
      await lockDoc.set({
        'isLocked': true,
        'lockTime': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      });
      
      print("Acquired R2 cleanup lock");
      
      try {
        // Get R2 configuration from Firestore
        final r2ConfigDoc = await FirebaseFirestore.instance.collection('app_config').doc('r2_settings').get();
        if (!r2ConfigDoc.exists) {
          print("R2 configuration not found");
          return 0;
        }
        
        final r2Config = r2ConfigDoc.data() as Map<String, dynamic>;
        final accountId = r2Config['accountId'] as String?;
        final accessKeyId = r2Config['accessKeyId'] as String?;
        final secretAccessKey = r2Config['secretAccessKey'] as String?;
        final bucketName = r2Config['bucketName'] as String?;
        
        if (accountId == null || accessKeyId == null || secretAccessKey == null || bucketName == null ||
            accountId.isEmpty || accessKeyId.isEmpty || secretAccessKey.isEmpty || bucketName.isEmpty) {
          print("Invalid R2 configuration");
          return 0;
        }
        
        print("Found valid R2 configuration for bucket: $bucketName");
        
        // Initialize Minio client to connect to R2
        final minio = Minio(
          endPoint: '$accountId.r2.cloudflarestorage.com',
          accessKey: accessKeyId,
          secretKey: secretAccessKey,
          useSSL: true,
          region: 'auto',
        );
        
        print("Initialized R2 client connection");
        
        int deletedCount = 0;
        
        try {
          print("Listing ALL objects in bucket $bucketName for deletion...");
          
          // List ALL objects in the bucket using the correct API
          final listStream = minio.listObjects(bucketName, recursive: true);
          List<String> allObjectKeys = [];
          
          // Collect all object keys from the stream
          await for (final listResult in listStream) {
            for (final obj in listResult.objects) {
              if (obj.key != null && obj.key!.isNotEmpty) {
                allObjectKeys.add(obj.key!);
              }
            }
          }
          
          print("Found ${allObjectKeys.length} total objects to delete");
          
          if (allObjectKeys.isEmpty) {
            print("No objects found in bucket");
            return 0;
          }
          
          // Delete all objects in batches
          const batchSize = 10;
          for (int i = 0; i < allObjectKeys.length; i += batchSize) {
            final end = (i + batchSize < allObjectKeys.length) ? i + batchSize : allObjectKeys.length;
            final batch = allObjectKeys.sublist(i, end);
            
            print("Deleting batch ${(i ~/ batchSize) + 1}/${(allObjectKeys.length / batchSize).ceil()}: ${batch.length} objects");
            
            // Delete each object in the batch
            for (final objectKey in batch) {
              try {
                await minio.removeObject(bucketName, objectKey);
                deletedCount++;
                print("✓ Deleted: $objectKey");
              } catch (e) {
                print("✗ Error deleting $objectKey: $e");
              }
            }
            
            // Short delay between batches to avoid rate limiting
            if (i + batchSize < allObjectKeys.length) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
          
          print("Successfully deleted $deletedCount out of ${allObjectKeys.length} objects from R2 bucket");
          
          // Release cleanup lock
          await lockDoc.set({
            'isLocked': false,
            'lockTime': FieldValue.serverTimestamp(),
            'completedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          });
          print("Released R2 cleanup lock");
          
          return deletedCount;
          
        } catch (e) {
          print("Error listing or deleting objects from R2: $e");
          
          // Release lock on error
          try {
            await lockDoc.set({
              'isLocked': false,
              'lockTime': FieldValue.serverTimestamp(),
              'errorBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            });
          } catch (_) {}
          
          return 0;
        }
        
      } catch (e) {
        print("Error clearing R2 storage: $e");
        
        // Release lock on any error
        try {
          await lockDoc.set({
            'isLocked': false,
            'lockTime': FieldValue.serverTimestamp(),
            'errorBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          });
        } catch (_) {}
        
        return 0;
      }
    } catch (e) {
      print("Error clearing R2 storage: $e");
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkPendingR2Cleanup();
    _checkR2CleanupLock();
  }
  
  Future<void> _checkPendingR2Cleanup() async {
    try {
      final pendingCleanupDoc = await FirebaseFirestore.instance.collection('app_config').doc('pending_r2_cleanup').get();
      if (pendingCleanupDoc.exists) {
        final data = pendingCleanupDoc.data();
        if (data != null && data['enabled'] == true) {
          print("Processing pending R2 cleanup from background task");
          
          // Get preset from the pending cleanup data
          final presetStr = data['preset'] as String? ?? 'today';
          
          // Set up date range based on preset
          final now = DateTime.now();
          DateTime start;
          DateTime endEx;
          
          switch (presetStr) {
            case 'last7':
              start = _startOfDay(now.subtract(const Duration(days: 6)));
              endEx = _endExclusiveOfDay(now);
              break;
            case 'last30':
              start = _startOfDay(now.subtract(const Duration(days: 29)));
              endEx = _endExclusiveOfDay(now);
              break;
            case 'today':
            default:
              start = _startOfDay(now);
              endEx = _endExclusiveOfDay(now);
          }
          
          // Execute the R2 cleanup
          final deletedCount = await _clearR2Storage(start, endEx);
          print("Auto-processed R2 cleanup: deleted $deletedCount files");
          
          // Mark the cleanup as completed
          await FirebaseFirestore.instance.collection('app_config').doc('pending_r2_cleanup').set({
            'enabled': false,
            'completedAt': FieldValue.serverTimestamp(),
            'deletedCount': deletedCount,
            'preset': presetStr
          });
        }
      }
    } catch (e) {
      print("Error processing pending R2 cleanup: $e");
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('cleanup_recurring_enabled') ?? false;
    final presetStr = prefs.getString('cleanup_recurring_preset');
    final chats = prefs.getBool('cleanup_recurring_includeChats');
    final ann = prefs.getBool('cleanup_recurring_includeAnnouncements');
    final deviceCache = prefs.getBool('cleanup_recurring_includeDeviceCache');
    final appStorage = prefs.getBool('cleanup_recurring_includeAppStorage');
    final r2Storage = prefs.getBool('cleanup_recurring_includeR2Storage');
    final hour = prefs.getInt('cleanup_recurring_hour') ?? 6;
    final minute = prefs.getInt('cleanup_recurring_minute') ?? 0;
    
    setState(() {
      _recurring = enabled;
      _recurringEnabled = enabled;
      _scheduledTime = TimeOfDay(hour: hour, minute: minute);
      _hasUnsavedChanges = false;
      
      if (presetStr != null) {
        switch (presetStr) {
          case 'today':
            _preset = CleanupPreset.today;
            break;
          case 'last7':
            _preset = CleanupPreset.last7;
            break;
          case 'last30':
            _preset = CleanupPreset.last30;
            break;
          default:
            _preset = CleanupPreset.today;
        }
      }
      if (chats != null) _includeChats = chats;
      if (ann != null) _includeAnnouncements = ann;
      if (deviceCache != null) _includeDeviceCache = deviceCache;
      if (appStorage != null) _includeAppStorage = appStorage;
      if (r2Storage != null) _includeR2Storage = r2Storage;
      _loadingPrefs = false;
    });
  }

  Future<void> _checkR2CleanupLock() async {
    try {
      final lockDoc = await FirebaseFirestore.instance.collection('app_config').doc('cleanup_lock').get();
      if (lockDoc.exists) {
        final lockInfo = lockDoc.data() as Map<String, dynamic>;
        final isLocked = lockInfo['isLocked'] as bool? ?? false;
        final lockTime = lockInfo['lockTime'] as Timestamp?;
        final userId = lockInfo['userId'] as String?;
        
        bool actuallyLocked = false;
        if (isLocked && lockTime != null) {
          final lockAge = DateTime.now().difference(lockTime.toDate());
          // Only consider it locked if less than 10 minutes old
          actuallyLocked = lockAge.inMinutes < 10;
        }
        
        if (mounted) {
          setState(() {
            _r2CleanupLocked = actuallyLocked;
            _r2LockUserId = actuallyLocked ? userId : null;
          });
        }
      } else if (mounted) {
        setState(() {
          _r2CleanupLocked = false;
          _r2LockUserId = null;
        });
      }
    } catch (e) {
      print("Error checking R2 cleanup lock: $e");
    }
  }

  String _presetKey(CleanupPreset p) {
    switch (p) {
      case CleanupPreset.today:
        return 'today';
      case CleanupPreset.last7:
        return 'last7';
      case CleanupPreset.last30:
        return 'last30';
      case CleanupPreset.custom:
        return 'custom';
    }
  }

  static const String _recurringUniqueName = 'cleanupRecurring';
  static const String _recurringTaskName = 'cleanupTask';

  Future<void> _saveRecurring() async {
    if (_preset == CleanupPreset.custom) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recurring is only available for presets (Today/Last 7/Last 30).')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cleanup_recurring_enabled', _recurring);
    await prefs.setString('cleanup_recurring_preset', _presetKey(_preset));
    await prefs.setBool('cleanup_recurring_includeChats', _includeChats);
    await prefs.setBool('cleanup_recurring_includeAnnouncements', _includeAnnouncements);
    await prefs.setBool('cleanup_recurring_includeDeviceCache', _includeDeviceCache);
    await prefs.setBool('cleanup_recurring_includeAppStorage', _includeAppStorage);
    await prefs.setBool('cleanup_recurring_includeR2Storage', _includeR2Storage);
    await prefs.setInt('cleanup_recurring_hour', _scheduledTime.hour);
    await prefs.setInt('cleanup_recurring_minute', _scheduledTime.minute);

    setState(() {
      _recurringEnabled = _recurring;
      _hasUnsavedChanges = false;
    });

    if (_recurring) {
      try {
        await Workmanager().registerPeriodicTask(
          _recurringUniqueName,
          _recurringTaskName,
          frequency: const Duration(days: 1),
          inputData: {
            'preset': _presetKey(_preset),
            'includeChats': _includeChats,
            'includeAnnouncements': _includeAnnouncements,
            'includeDeviceCache': _includeDeviceCache,
            'includeAppStorage': _includeAppStorage,
            'includeR2Storage': false, // ALWAYS FALSE - disable auto R2 cleanup
            'scheduledHour': _scheduledTime.hour,
            'scheduledMinute': _scheduledTime.minute,
          },
        );
        print("Scheduled recurring cleanup task for ${_scheduledTime.format(context)}");
      } catch (e) {
        print("Error scheduling recurring cleanup: $e");
      }
    } else {
      try {
        await Workmanager().cancelByUniqueName(_recurringUniqueName);
        print("Cancelled recurring cleanup task");
      } catch (e) {
        print("Error cancelling recurring cleanup: $e");
      }
    }
    
    if (mounted) {
      final isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || 
                                   defaultTargetPlatform == TargetPlatform.linux || 
                                   defaultTargetPlatform == TargetPlatform.macOS);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_recurring 
            ? 'Recurring cleanup enabled for ${_scheduledTime.format(context)} daily${isDesktop ? ' (Desktop: only works while app is running)' : ''}'
            : 'Recurring cleanup disabled'
          ),
          backgroundColor: _recurring ? Colors.green : Colors.orange,
          duration: Duration(seconds: isDesktop && _recurring ? 5 : 3),
        )
      );
    }
  }

  void _markUnsavedChanges() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _selectScheduledTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _scheduledTime) {
      setState(() {
        _scheduledTime = picked;
        _markUnsavedChanges();
      });
    }
  }

  Future<void> _logCleanupOperation({
    required bool isManual,
    required String preset,
    required int totalDeleted,
    required List<String> targets,
  }) async {
    try {
      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];
      
      // Log to a cleanup history collection
      await FirebaseFirestore.instance.collection('cleanup_history').add({
        'userId': widget.currentUserId,
        'date': today,
        'timestamp': FieldValue.serverTimestamp(),
        'preset': preset,
        'isManual': isManual,
        'type': isManual ? 'manual' : 'automatic',
        'totalDeleted': totalDeleted,
        'targets': targets,
        'deviceInfo': Platform.operatingSystem,
      });

      // If it's a manual cleanup, also update a separate manual cleanup status
      if (isManual) {
        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('manual_cleanup_status')
            .set({
          'lastManualDate': today,
          'lastManualBy': widget.currentUserId,
          'lastManualPreset': preset,
          'lastManualTimestamp': FieldValue.serverTimestamp(),
          'lastManualTotal': totalDeleted,
          'lastManualTargets': targets,
          'deviceInfo': Platform.operatingSystem,
        });
      }
      
      print("Logged cleanup operation: manual=$isManual, total=$totalDeleted");
    } catch (e) {
      print("Error logging cleanup operation: $e");
    }
  }

  Future<void> _performCleanup() async {
    await _performCleanupInternal(bypassDailyCheck: false);
  }

  Future<void> _performManualCleanup() async {
    await _performCleanupInternal(bypassDailyCheck: true);
  }

  Future<void> _performCleanupInternal({required bool bypassDailyCheck}) async {
    if (!_confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm the deletion first.')));
      return;
    }
    final range = _resolveRange();
    final start = range.start;
    final endEx = range.endExclusive;
    final safe = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(bypassDailyCheck ? 'CONFIRM MANUAL CLEANUP' : 'CONFIRM PERMANENT DELETION'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete messages from ${start.toLocal()} to ${endEx.subtract(const Duration(milliseconds: 1)).toLocal()}.'),
            const SizedBox(height: 8),
            Text('Targets: ${[
              _includeChats ? 'Chats' : null, 
              _includeAnnouncements ? 'Announcements' : null,
              _includeDeviceCache ? 'Device Cache' : null,
              _includeAppStorage ? 'App Storage' : null,
              _includeR2Storage ? 'R2 Storage' : null
            ].whereType<String>().join(', ')}.'),
            if (_includeR2Storage) ...[
              const SizedBox(height: 16),
              const Text(
                'WARNING: R2 Storage deletion will remove ALL files in the Cloudflare R2 bucket, regardless of date!', 
                style: TextStyle(
                  color: Colors.red, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (bypassDailyCheck) ...[
              const SizedBox(height: 16),
              const Text(
                'NOTE: This manual cleanup bypasses daily completion checks and can be run multiple times per day.',
                style: TextStyle(
                  color: Colors.blue,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('This action CANNOT be undone!', 
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(_includeR2Storage ? 'Yes, Delete EVERYTHING' : 'Delete'),
            style: _includeR2Storage ? ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
            ) : null,
          ),
        ],
      ),
    );
    if (safe != true) return;

    // Check daily cleanup status for shared cleanup (chats, announcements, R2) unless bypassing
    if (!bypassDailyCheck) {
      final hasSharedCleanup = _includeChats || _includeAnnouncements || _includeR2Storage;
      if (hasSharedCleanup) {
        final preset = _presetKey(_preset);
        final canProceed = await _checkDailyCleanupStatus(preset);
        if (!canProceed) {
          return; // Already shown snackbar in the check function
        }
      }
    }

    // Check R2 lock status if R2 cleanup is requested
    if (_includeR2Storage) {
      await _checkR2CleanupLock();
      if (_r2CleanupLocked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ R2 cleanup is currently in progress by another user. Please try again later.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          )
        );
        return;
      }
    }

    setState(() => _busy = true);
    int total = 0;
    try {
      if (_includeChats) {
        total += await _deleteRange('chats', start, endEx);
      }
      if (_includeAnnouncements) {
        total += await _deleteRange('communications', start, endEx);
      }
      if (_includeDeviceCache) {
        final cacheFilesDeleted = await _clearDeviceCache();
        total += cacheFilesDeleted;
        print("Deleted $cacheFilesDeleted device cache files");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared $cacheFilesDeleted device cache files'), duration: const Duration(seconds: 1))
        );
      }
      if (_includeAppStorage) {
        final appFilesDeleted = await _clearAppStorage();
        total += appFilesDeleted;
        print("Deleted $appFilesDeleted app storage files");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared $appFilesDeleted app storage files'), duration: const Duration(seconds: 1))
        );
      }
      if (_includeR2Storage) {
        final r2FilesDeleted = await _clearR2Storage(start, endEx);
        total += r2FilesDeleted;
        print("Deleted $r2FilesDeleted R2 files");
        // Refresh lock status after R2 cleanup completes
        await _checkR2CleanupLock();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $r2FilesDeleted files from R2 storage'), duration: const Duration(seconds: 1))
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $total items')));
      
      // Log the cleanup operation
      final targets = <String>[];
      if (_includeChats) targets.add('Chats');
      if (_includeAnnouncements) targets.add('Announcements');
      if (_includeDeviceCache) targets.add('Device Cache');
      if (_includeAppStorage) targets.add('App Storage');
      if (_includeR2Storage) targets.add('R2 Storage');
      
      await _logCleanupOperation(
        isManual: bypassDailyCheck,
        preset: _presetKey(_preset),
        totalDeleted: total,
        targets: targets,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _resolveRange();
    final start = range.start;
    final endEx = range.endExclusive;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleanup & Maintenance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.pushNamed(context, '/cleanup/status');
            },
            tooltip: 'Cleanup Status',
          ),
        ],
      ),
      body: _loadingPrefs 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<CleanupPreset>(
                value: _preset,
                onChanged: (v) {
                  setState(() {
                    _preset = v ?? CleanupPreset.today;
                    _markUnsavedChanges();
                  });
                },
                items: const [
                  DropdownMenuItem(value: CleanupPreset.today, child: Text('Today')),
                  DropdownMenuItem(value: CleanupPreset.last7, child: Text('Last 7 days')),
                  DropdownMenuItem(value: CleanupPreset.last30, child: Text('Last 30 days')),
                  DropdownMenuItem(value: CleanupPreset.custom, child: Text('Custom range')),
                ],
              ),
              if (_preset == CleanupPreset.custom) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text(_customStart == null ? 'Start Date' : _customStart!.toLocal().toString().split(' ')[0]),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _customStart ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => _customStart = d);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: Text(_customEnd == null ? 'End Date' : _customEnd!.toLocal().toString().split(' ')[0]),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _customEnd ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => _customEnd = d);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Range: ${start.toLocal().toString().split(' ')[0]} to ${endEx.subtract(const Duration(milliseconds: 1)).toLocal().toString().split(' ')[0]}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),

              const Divider(height: 32),
              const Text('What to delete', style: TextStyle(fontWeight: FontWeight.bold)),
              CheckboxListTile(
                value: _includeChats,
                onChanged: (v) {
                  setState(() {
                    _includeChats = v ?? false;
                    _markUnsavedChanges();
                  });
                },
                title: const Text('Chat messages'),
                subtitle: const Text('Delete chat messages in the date range'),
              ),
              CheckboxListTile(
                value: _includeAnnouncements,
                onChanged: (v) {
                  setState(() {
                    _includeAnnouncements = v ?? false;
                    _markUnsavedChanges();
                  });
                },
                title: const Text('Announcements'),
                subtitle: const Text('Delete announcements in the date range'),
              ),
              CheckboxListTile(
                value: _includeDeviceCache,
                onChanged: (v) {
                  setState(() {
                    _includeDeviceCache = v ?? false;
                    _markUnsavedChanges();
                  });
                },
                title: const Text('Device cache'),
                subtitle: const Text('Clear locally cached files and thumbnails'),
              ),
              CheckboxListTile(
                value: _includeAppStorage,
                onChanged: (v) {
                  setState(() {
                    _includeAppStorage = v ?? false;
                    _markUnsavedChanges();
                  });
                },
                title: const Text('App storage'),
                subtitle: const Text('Clear app downloads (videos and thumbnails)'),
              ),
              CheckboxListTile(
                value: _includeR2Storage,
                onChanged: _r2CleanupLocked ? null : (v) {
                  setState(() {
                    _includeR2Storage = v ?? false;
                    _markUnsavedChanges();
                  });
                },
                title: Text('R2 storage', style: TextStyle(color: _r2CleanupLocked ? Colors.grey : null)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delete ALL files in the Cloudflare R2 bucket', 
                         style: TextStyle(color: _r2CleanupLocked ? Colors.grey : null)),
                    if (_r2CleanupLocked) 
                      Text(
                        '⚠️ R2 cleanup in progress by another user',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                  ],
                ),
              ),

              const Divider(height: 32),
              const Text('Automation', style: TextStyle(fontWeight: FontWeight.bold)),
              SwitchListTile(
                value: _recurring,
                onChanged: (v) {
                  setState(() {
                    _recurring = v;
                    _markUnsavedChanges();
                  });
                },
                title: const Text('Keep this recurring'),
                subtitle: Text(
                  _preset == CleanupPreset.custom
                      ? 'Recurring works only with presets (Today/Last 7/Last 30).'
                      : 'Runs daily in background. Range used each day: ${_preset == CleanupPreset.today ? 'Today' : _preset == CleanupPreset.last7 ? 'Last 7 days' : 'Last 30 days'}.'
                ),
              ),
              
              if (_recurring) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.blue.shade800),
                            const SizedBox(width: 8),
                            Text(
                              'Schedule Settings',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          leading: Icon(Icons.access_time, color: Colors.blue.shade600),
                          title: const Text('Daily execution time'),
                          subtitle: Text('Cleanup will run at ${_scheduledTime.format(context)} every day'),
                          trailing: const Icon(Icons.edit),
                          onTap: _selectScheduledTime,
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.blue.shade200),
                          ),
                        ),
                        if (_hasUnsavedChanges) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange.shade800, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You have unsaved changes. Click "Apply Changes" to save.',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const Divider(height: 32),
              CheckboxListTile(
                value: _confirm,
                onChanged: (v) => setState(() => _confirm = v ?? false),
                title: const Text('I understand this action cannot be undone'),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: (_busy || (!_hasUnsavedChanges && _recurringEnabled == _recurring)) 
                        ? null 
                        : _saveRecurring,
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.disabled)) {
                            return Colors.grey.shade300;
                          }
                          return _hasUnsavedChanges ? Colors.orange : Colors.green;
                        }),
                      ),
                      child: Text(
                        _hasUnsavedChanges 
                          ? 'Apply Changes' 
                          : _recurringEnabled 
                            ? 'Recurring Enabled' 
                            : 'Recurring Disabled'
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _performCleanup,
                      child: _busy 
                        ? const SizedBox(
                            width: 16, 
                            height: 16, 
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        : const Text('Execute Cleanup'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _performManualCleanup,
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(Colors.orange),
                        foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                      ),
                      child: _busy 
                        ? const SizedBox(
                            width: 16, 
                            height: 16, 
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        : const Text('Manual Override'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              const Text(
                'Manual Override bypasses daily completion checks and can run multiple times per day.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Storage Diagnostic Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Storage Diagnostics',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check what is taking up storage space in the app.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy ? null : _showStorageReport,
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
                              ),
                              child: const Text('Check Storage Usage'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy ? null : _clearTempFiles,
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all<Color>(Colors.purple),
                              ),
                              child: const Text('Clear Temp Files'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : () => _performDeviceCacheCleanup(),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all<Color>(Colors.orange),
                          ),
                          child: const Text('Clear Device Cache (Memory Optimization)'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  // Storage diagnostic methods
  Future<void> _showStorageReport() async {
    setState(() => _busy = true);
    
    try {
      await _generateStorageReport();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating storage report: $e')),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _clearTempFiles() async {
    setState(() => _busy = true);
    
    try {
      // Clear temporary video files
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final tempDir = Directory('${extDir.path}/temp_videos');
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temporary files cleared successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing temp files: $e')),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _performDeviceCacheCleanup() async {
    setState(() => _busy = true);
    
    try {
      final filesDeleted = await _clearDeviceCache();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device cache cleared successfully\nDeleted $filesDeleted files'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing device cache: $e')),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _generateStorageReport() async {
    Map<String, dynamic> breakdown = {
      'appDocuments': {'size': 0, 'files': 0, 'path': ''},
      'externalCache': {'size': 0, 'files': 0, 'path': ''},
      'tempVideos': {'size': 0, 'files': 0, 'path': ''},
      'total': 0,
    };

    try {
      // Check App Documents Directory
      final appDir = await getApplicationDocumentsDirectory();
      breakdown['appDocuments']['path'] = appDir.path;
      await _calculateDirectorySize(appDir, breakdown['appDocuments'], breakdown);

      // Check External Cache Directory
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        breakdown['externalCache']['path'] = extDir.path;
        await _calculateDirectorySize(extDir, breakdown['externalCache'], breakdown);

        // Check temp_videos specifically
        final tempDir = Directory('${extDir.path}/temp_videos');
        if (await tempDir.exists()) {
          breakdown['tempVideos']['path'] = tempDir.path;
          await _calculateDirectorySize(tempDir, breakdown['tempVideos'], breakdown);
        }
      }

      // Show the report
      _showStorageDialog(breakdown);
      
    } catch (e) {
      print('Error calculating storage: $e');
    }
  }

  Future<void> _calculateDirectorySize(Directory dir, Map<String, dynamic> info, Map<String, dynamic> breakdown) async {
    try {
      int totalSize = 0;
      int fileCount = 0;

      await for (FileSystemEntity entity in dir.list(recursive: true)) {
        if (entity is File) {
          FileStat stat = await entity.stat();
          totalSize += stat.size;
          fileCount++;
        }
      }

      info['size'] = totalSize;
      info['files'] = fileCount;
      breakdown['total'] += totalSize;
    } catch (e) {
      print('Error calculating directory size: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showStorageDialog(Map<String, dynamic> breakdown) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Usage Report'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📊 Total Storage: ${_formatBytes(breakdown['total'])}', 
                   style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              Text('📁 App Private Storage: ${_formatBytes(breakdown['appDocuments']['size'])}'),
              Text('   Files: ${breakdown['appDocuments']['files']}'),
              const SizedBox(height: 8),
              
              Text('📂 External Cache: ${_formatBytes(breakdown['externalCache']['size'])}'),
              Text('   Files: ${breakdown['externalCache']['files']}'),
              const SizedBox(height: 8),
              
              Text('🎬 Temp Videos: ${_formatBytes(breakdown['tempVideos']['size'])}'),
              Text('   Files: ${breakdown['tempVideos']['files']}'),
              const SizedBox(height: 8),
              
              if (breakdown['tempVideos']['size'] > 0) 
                const Text('⚠️ Temp videos found - consider clearing them',
                           style: TextStyle(color: Colors.orange)),
              
              const SizedBox(height: 16),
              const Text('🔍 Analysis:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (breakdown['tempVideos']['size'] > 5 * 1024 * 1024)
                const Text('• Temp videos taking significant space', style: TextStyle(color: Colors.red)),
              if (breakdown['appDocuments']['size'] > 50 * 1024 * 1024)
                const Text('• App storage above 50MB - check downloaded files', style: TextStyle(color: Colors.orange)),
              if (breakdown['total'] > 100 * 1024 * 1024)
                const Text('• Total storage above 100MB - cleanup recommended', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        actions: [
          if (breakdown['tempVideos']['size'] > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clearTempFiles();
              },
              child: const Text('Clear Temp Files'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
