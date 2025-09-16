import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:minio/minio.dart';
import 'dart:convert';
import 'download_state.dart';

enum CleanupPreset { today, last7, last30, custom }

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
  bool _includeR2Storage = false;
  bool _confirm = false;
  bool _busy = false;
  bool _recurring = false;
  bool _loadingPrefs = true;
  bool _r2CleanupLocked = false;
  String? _r2LockUserId;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endExclusiveOfDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  _Range _resolveRange() {
    final now = DateTime.now();
    switch (_preset) {
      case CleanupPreset.today:
        final s = _startOfDay(now);
        return _Range(s, _endExclusiveOfDay(now));
      case CleanupPreset.last7:
        final s = _startOfDay(now.subtract(const Duration(days: 6))); // include today => 7 days
        return _Range(s, _endExclusiveOfDay(now));
      case CleanupPreset.last30:
        final s = _startOfDay(now.subtract(const Duration(days: 29))); // include today => 30 days
        return _Range(s, _endExclusiveOfDay(now));
      case CleanupPreset.custom:
        final start = _customStart != null ? _startOfDay(_customStart!) : _startOfDay(now);
        final endEx = _customEnd != null ? _endExclusiveOfDay(_customEnd!) : _endExclusiveOfDay(now);
        return _Range(start, endEx);
    }
  }

  Future<int> _deleteRange(String collection, DateTime start, DateTime endExclusive) async {
    int deleted = 0;
    final Query<Map<String, dynamic>> base = FirebaseFirestore.instance
        .collection(collection)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(endExclusive))
        .orderBy('timestamp');
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> q = base.limit(300);
      if (cursor != null) q = q.startAfterDocument(cursor);
      final QuerySnapshot<Map<String, dynamic>> snap = await q.get();
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
    return deleted;
  }

  Future<int> _clearDeviceCache() async {
    // Clear the download state cache and actual files
    try {
      final prefs = await SharedPreferences.getInstance();
      int filesDeleted = 0;
      
      // Get the stored file paths first
      final Map<String, String> downloadedFiles = await DownloadState.load();
      final Map<String, String> downloadedThumbnails = await DownloadState.loadThumbnails();
      
      print("Found ${downloadedFiles.length} downloaded files and ${downloadedThumbnails.length} thumbnails in cache");
      
      // Delete actual video files
      for (final path in downloadedFiles.values) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
            filesDeleted++;
            print("Deleted file: $path");
          } else {
            print("File not found: $path");
          }
        } catch (e) {
          print("Error deleting file: $path - $e");
        }
      }
      
      // Delete actual thumbnail files
      for (final path in downloadedThumbnails.values) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
            filesDeleted++;
            print("Deleted thumbnail: $path");
          } else {
            print("Thumbnail not found: $path");
          }
        } catch (e) {
          print("Error deleting thumbnail: $path - $e");
        }
      }
      
      // Get directories
      final appDir = await getApplicationDocumentsDirectory();
      final appCacheDir = await getTemporaryDirectory();
      final videosDir = Directory('${appDir.path}/videos');
      final thumbnailsDir = Directory('${appDir.path}/thumbnails');
      
      // Log the directories we're checking
      print("Checking videos directory: ${videosDir.path}");
      print("Checking thumbnails directory: ${thumbnailsDir.path}");
      print("Checking app cache directory: ${appCacheDir.path}");
      
      // Delete files from videos directory
      if (await videosDir.exists()) {
        try {
          final videoFiles = await videosDir.list().toList();
          print("Found ${videoFiles.length} files in videos directory");
          for (final entity in videoFiles) {
            if (entity is File) {
              try {
                await entity.delete();
                filesDeleted++;
                print("Deleted file from videos dir: ${entity.path}");
              } catch (e) {
                print("Error deleting file from videos dir: ${entity.path} - $e");
              }
            }
          }
        } catch (e) {
          print("Error listing videos directory: $e");
        }
      } else {
        print("Videos directory does not exist");
      }
      
      // Delete files from thumbnails directory
      if (await thumbnailsDir.exists()) {
        try {
          final thumbnailFiles = await thumbnailsDir.list().toList();
          print("Found ${thumbnailFiles.length} files in thumbnails directory");
          for (final entity in thumbnailFiles) {
            if (entity is File) {
              try {
                await entity.delete();
                filesDeleted++;
                print("Deleted file from thumbnails dir: ${entity.path}");
              } catch (e) {
                print("Error deleting file from thumbnails dir: ${entity.path} - $e");
              }
            }
          }
        } catch (e) {
          print("Error listing thumbnails directory: $e");
        }
      } else {
        print("Thumbnails directory does not exist");
      }
      
      // Clear app cache directory - this is important and often missed
      try {
        final cacheFiles = await appCacheDir.list(recursive: true).toList();
        print("Found ${cacheFiles.length} files in app cache directory");
        for (final entity in cacheFiles) {
          if (entity is File) {
            try {
              await entity.delete();
              filesDeleted++;
              print("Deleted file from cache dir: ${entity.path}");
            } catch (e) {
              print("Error deleting file from cache dir: ${entity.path} - $e");
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
    final r2Storage = prefs.getBool('cleanup_recurring_includeR2Storage');
    setState(() {
      _recurring = enabled;
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
    await prefs.setBool('cleanup_recurring_includeR2Storage', _includeR2Storage);

    // Always cancel previous to avoid duplicates
    await Workmanager().cancelByUniqueName(_recurringUniqueName);

    if (_recurring) {
      // Choose frequency: daily is sufficient; the task itself computes range for last7/last30
      const frequency = Duration(days: 1);
      await Workmanager().registerPeriodicTask(
        _recurringUniqueName,
        _recurringTaskName,
        frequency: frequency,
        inputData: {
          'preset': _presetKey(_preset),
          'includeChats': _includeChats,
          'includeAnnouncements': _includeAnnouncements,
          'includeDeviceCache': _includeDeviceCache,
          'includeR2Storage': _includeR2Storage,
        },
  constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recurring cleanup scheduled.')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recurring cleanup disabled.')));
    }
  }

  Future<void> _runCleanup() async {
    if (!_includeChats && !_includeAnnouncements && !_includeDeviceCache && !_includeR2Storage) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one target')));
      return;
    }
    if (!_confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm deletion')));
      return;
    }
  final range = _resolveRange();
  final start = range.start;
  final endEx = range.endExclusive;
    final safe = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('CONFIRM PERMANENT DELETION'),
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
      appBar: AppBar(title: const Text('Delete Messages')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loadingPrefs) const LinearProgressIndicator(minHeight: 2),
            const Text('Range', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioListTile<CleanupPreset>(
              value: CleanupPreset.today,
              groupValue: _preset,
              title: const Text('Today'),
              onChanged: (v) => setState(() => _preset = v!),
            ),
            RadioListTile<CleanupPreset>(
              value: CleanupPreset.last7,
              groupValue: _preset,
              title: const Text('Last 7 days (including today)'),
              onChanged: (v) => setState(() => _preset = v!),
            ),
            RadioListTile<CleanupPreset>(
              value: CleanupPreset.last30,
              groupValue: _preset,
              title: const Text('Last 30 days (including today)'),
              onChanged: (v) => setState(() => _preset = v!),
            ),
            RadioListTile<CleanupPreset>(
              value: CleanupPreset.custom,
              groupValue: _preset,
              title: const Text('Custom date range'),
              onChanged: (v) => setState(() => _preset = v!),
              subtitle: _preset == CleanupPreset.custom
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _customStart ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _customStart = picked);
                            },
                            child: Text('Start: ${_customStart != null ? _startOfDay(_customStart!).toLocal().toString().split(' ').first : _startOfDay(DateTime.now()).toLocal().toString().split(' ').first}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _customEnd ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _customEnd = picked);
                            },
                            child: Text('End: ${_customEnd != null ? _startOfDay(_customEnd!).toLocal().toString().split(' ').first : _startOfDay(DateTime.now()).toLocal().toString().split(' ').first}'),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),

            const Divider(height: 32),
            const Text('Targets', style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              value: _includeChats,
              onChanged: (v) => setState(() => _includeChats = v ?? true),
              title: const Text('Chat messages'),
            ),
            CheckboxListTile(
              value: _includeAnnouncements,
              onChanged: (v) => setState(() => _includeAnnouncements = v ?? true),
              title: const Text('Announcements'),
            ),
            CheckboxListTile(
              value: _includeDeviceCache,
              onChanged: (v) => setState(() => _includeDeviceCache = v ?? false),
              title: const Text('Device cache'),
              subtitle: const Text('Clear locally cached files and thumbnails'),
            ),
            CheckboxListTile(
              value: _includeR2Storage,
              onChanged: _r2CleanupLocked ? null : (v) => setState(() => _includeR2Storage = v ?? false),
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
              onChanged: (v) => setState(() => _recurring = v),
              title: const Text('Keep this recurring'),
              subtitle: Text(
                _preset == CleanupPreset.custom
                    ? 'Recurring works only with presets (Today/Last 7/Last 30).'
                    : 'Runs daily in background. Range used each day: ${_preset == CleanupPreset.today ? 'Today' : _preset == CleanupPreset.last7 ? 'Last 7 days' : 'Last 30 days'}.'
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _saveRecurring,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Save recurring'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () async {
                      await Workmanager().cancelByUniqueName(_recurringUniqueName);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('cleanup_recurring_enabled', false);
                      if (!mounted) return;
                      setState(() => _recurring = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancelled recurring cleanup.')));
                    },
                    icon: const Icon(Icons.cancel_schedule_send),
                    label: const Text('Cancel recurring'),
                  ),
                ),
              ],
            ),

            const Divider(height: 32),
            const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              value: _confirm,
              onChanged: (v) => setState(() => _confirm = v ?? false),
              title: const Text('I understand this action is permanent.'),
            ),

            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _runCleanup,
              icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.delete_forever),
              label: Text(_busy ? 'Deleting…' : 'Delete in selected range'),
            ),

            const SizedBox(height: 16),
            Text('Effective range: ${_startOfDay(start).toLocal()} — ${endEx.subtract(const Duration(milliseconds: 1)).toLocal()}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
