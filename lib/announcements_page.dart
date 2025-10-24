import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'services/dynamic_firebase_options.dart';
import 'services/school_context.dart';
import 'package:minio/minio.dart';
import 'fast_download_manager.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:background_downloader/background_downloader.dart';
import 'services/download_service.dart';
import 'download_state.dart';
import 'widgets/r2_video_player.dart';
import 'widgets/download_all_overlay.dart';
import 'downloads_page.dart';
import 'package:path/path.dart' as path;
import 'multi_r2_uploader_page.dart';
import 'user_settings_page.dart';
import 'multi_r2_media_uploader_page.dart';
import 'template_management_page.dart';
import 'widgets/template_announcement_cards.dart';
import 'widgets/school_holiday_card.dart';
import 'widgets/ptm_announcement_card.dart';
import 'widgets/custom_template_renderer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/background_cache_service.dart';

// Template styles for media display
enum MediaTemplateStyle {
  school,    // Blue to green gradient (default)
  business,  // Dark professional theme
  modern,    // Purple to pink gradient
}

class AnnouncementsPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;
  const AnnouncementsPage({Key? key, required this.currentUserId, required this.currentUserRole}) : super(key: key);

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _preferInlinePlayback = true; // user preference

  // Download state per URL
  final Map<String, double?> _downloadProgress = {}; // 0..1 or null (indeterminate)
  final Map<String, String> _downloadedFile = {}; // url -> local path
  final Map<String, DownloadTask> _dlTask = {}; // url -> background task
  final Map<String, TaskStatus> _dlStatus = {}; // url -> task status

  // Performance caches
  final Map<String, bool> _urlImageCache = {}; // Cache for _isImageUrl results
  final Map<String, bool> _urlVideoCache = {}; // Cache for video URL checks

  // Selection mode (WhatsApp-like)
  bool _selectionActive = false;
  int? _selectedIndex;
  String? _selectedText;
  bool _selectedIsMine = false;
  DocumentReference? _selectedRef;
  OverlayEntry? _reactionsOverlay;
  bool _showFloatingPanel = false;
  bool _showAnnouncementForm = false;
  
  // Performance optimization: Cache sender names to avoid repeated database lookups
  final Map<String, String> _senderNameCache = {};
  
  // Create a stable stream to prevent unnecessary rebuilds
  late final Stream<QuerySnapshot> _announcementsStream;
  
  // Cache the last snapshot to prevent spinner flicker on rebuilds
  QuerySnapshot? _lastAnnouncementsSnapshot;

  // Background image settings
  String? _backgroundImageUrl;
  double _imageOpacity = 0.20;
  Color _gradientColor1 = const Color(0xFF667eea);
  Color _gradientColor2 = const Color(0xFF764ba2);

  // R2 configuration for presigned URLs
  String? _r2AccountId;
  String? _r2AccessKeyId;
  String? _r2SecretAccessKey;
  String? _r2BucketName;
  bool _r2Configured = false;

  Future<void> _setReaction(String emoji) async {
    final ref = _selectedRef;
    if (ref == null) return;
    try {
      await ref.update({'reactions.${widget.currentUserId}': emoji});
    } catch (e) {
      try {
        await ref.set({'reactions': {widget.currentUserId: emoji}}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  void _showReactionsOverlay(Offset globalPosition) {
    _removeReactionsOverlay();
    final overlay = Overlay.of(context);
    if (overlay == null) return;
  final media = MediaQuery.of(context);
  const margin = 12.0;
  const overlayWidth = 208.0; // Keep consistent with chat page
  final dx = globalPosition.dx;
  final dy = (globalPosition.dy - 56).clamp(kToolbarHeight + media.padding.top + margin, media.size.height - 120.0);
  final left = (dx - overlayWidth / 2).clamp(margin, media.size.width - margin - overlayWidth);
    _reactionsOverlay = OverlayEntry(
      builder: (_) => Positioned(
    left: left,
        top: dy - 48,
        child: Material(
          color: Colors.transparent,
          child: Container(
      width: overlayWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in ['👍','❤️','😂','😮','😢','🙏'])
                    InkWell(
                      onTap: () async {
                        await _setReaction(e);
                        _exitSelection();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_reactionsOverlay!);
  }

  void _removeReactionsOverlay() {
    _reactionsOverlay?.remove();
    _reactionsOverlay = null;
  }

  void _enterSelection({
    required LongPressStartDetails details,
    required bool isMine,
    required String message,
    required DocumentReference ref,
    required int index,
  }) {
    setState(() {
      _selectionActive = true;
      _selectedIndex = index;
      _selectedIsMine = isMine;
      _selectedText = message;
      _selectedRef = ref;
    });
    _showReactionsOverlay(details.globalPosition);
  }

  void _exitSelection() {
    _removeReactionsOverlay();
    if (!_selectionActive) return;
    setState(() {
      _selectionActive = false;
      _selectedIndex = null;
      _selectedIsMine = false;
      _selectedText = null;
      _selectedRef = null;
    });
  }

  Future<String> _getSenderName(String senderId) async {
    if (senderId == 'firstadmin') return 'School Admin';
    // 🔥 Filter by schoolId
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
        .where('userId', isEqualTo: senderId)
        .limit(1)
        .get();
    if (userDoc.docs.isNotEmpty && userDoc.docs.first.data().containsKey('name')) {
      return userDoc.docs.first['name'] ?? senderId;
    }
    return senderId;
  }

  Future<void> _sendAnnouncement() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final senderName = await _getSenderName(widget.currentUserId);
    await FirebaseFirestore.instance.collection('communications').add({
      'schoolId': SchoolContext.currentSchoolId,  // 🔥 ADD schoolId
      'message': text,
      'senderId': widget.currentUserId,
      'senderRole': widget.currentUserRole,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
    // Close form efficiently
    if (mounted) {
      setState(() {
        _showAnnouncementForm = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPlaybackPreference();
    _hydrateDownloads();
    _maybeRequestAndroidNotificationPermission();
    _loadBackgroundSettings(); // Load background image
    
    // Initialize stable stream to prevent rebuilds on setState
    // 🔥 Filter announcements by schoolId
    _announcementsStream = FirebaseFirestore.instance
        .collection('communications')
        .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
        .orderBy('timestamp', descending: true)
        .snapshots();
    
    // Pre-cache first snapshot for instant display (WhatsApp approach)
    _announcementsStream.first.then((snapshot) {
      if (mounted) {
        _lastAnnouncementsSnapshot = snapshot;
        debugPrint('✅ Pre-cached announcements: ${snapshot.docs.length} items');
      }
    });
    
    // Automatic cleanup for ALL users (runs on app startup)
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        await _performAutomaticCleanup();
      } catch (e) {
        print('Error during automatic cleanup: $e');
      }
    });
  }

  Future<void> _maybeRequestAndroidNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  Future<void> _loadBackgroundSettings() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      debugPrint('🎨 Loading background for school: $schoolId');
      
      // Load from cache first (instant display)
      final prefs = await SharedPreferences.getInstance();
      String? cachedUrl = prefs.getString('background_url_$schoolId');
      final cachedOpacity = prefs.getDouble('background_opacity_$schoolId');
      final cachedColor1 = prefs.getInt('background_color1_$schoolId');
      final cachedColor2 = prefs.getInt('background_color2_$schoolId');
      
      // Fix common URL issues (double colon, double slash)
      if (cachedUrl != null) {
        cachedUrl = cachedUrl.replaceAll('https:://', 'https://').replaceAll('http:://', 'http://');
        if (cachedUrl != prefs.getString('background_url_$schoolId')) {
          debugPrint('� Fixed cached URL: $cachedUrl');
          await prefs.setString('background_url_$schoolId', cachedUrl);
        }
      }
      
      debugPrint('�📦 Cache - URL: $cachedUrl, Opacity: $cachedOpacity');
      
      if (cachedUrl != null) {
        _backgroundImageUrl = cachedUrl;
      }
      if (cachedOpacity != null) {
        _imageOpacity = cachedOpacity;
      }
      if (cachedColor1 != null) {
        _gradientColor1 = Color(cachedColor1);
      }
      if (cachedColor2 != null) {
        _gradientColor2 = Color(cachedColor2);
      }
      
      // Get directory and file paths
      final dir = await getApplicationDocumentsDirectory();
      final cachedFilePath = '${dir.path}/backgrounds/bg_$schoolId.jpg';
      final cachedFile = File(cachedFilePath);
      
      // Precache background into Flutter's ImageCache (WhatsApp approach - GPU memory!)
      if (cachedFile.existsSync()) {
        if (!BackgroundCacheService().isPrecached(schoolId) && mounted) {
          await BackgroundCacheService().precacheBackground(context, schoolId);
        }
        _backgroundImageUrl = 'precached'; // Flag to indicate background ready
        
        // Show immediately
        if (mounted) {
          setState(() {});
          debugPrint('✨ Background ready (precached in GPU)!');
        }
      }
      
      // Then load from Firestore (to get latest)
      debugPrint('🔥 Fetching from Firestore...');
      final bgDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background')
          .get();
      
      debugPrint('🔥 Background doc exists: ${bgDoc.exists}');
      if (bgDoc.exists && bgDoc.data()?['objectKey'] != null) {
        final objectKey = bgDoc.data()!['objectKey'] as String;
        final cachedObjectKey = prefs.getString('background_key_$schoolId');
        
        debugPrint('🔑 Firestore key: $objectKey');
        debugPrint('📦 Cached key: $cachedObjectKey');
        
        // Only download if background changed OR file doesn't exist
        if (objectKey != cachedObjectKey || !cachedFile.existsSync()) {
          debugPrint('🆕 Background changed or missing, downloading...');
          
          // Generate presigned URL
          await _ensureR2Configured();
        if (_r2BucketName != null) {
          final minio = Minio(
            endPoint: '$_r2AccountId.r2.cloudflarestorage.com',
            accessKey: _r2AccessKeyId!,
            secretKey: _r2SecretAccessKey!,
            useSSL: true,
          );
          
          final presignedUrl = await minio.presignedGetObject(_r2BucketName!, objectKey, expires: 3600);
          debugPrint('� Presigned URL generated');
          
          // Download and save to device storage
          try {
            final response = await http.get(Uri.parse(presignedUrl));
            
            if (response.statusCode == 200) {
              await Directory('${dir.path}/backgrounds').create(recursive: true);
              await cachedFile.writeAsBytes(response.bodyBytes);
              debugPrint('💾 Saved to device: ${cachedFile.lengthSync()} bytes');
              
              // Precache into Flutter's ImageCache (WhatsApp approach!)
              if (mounted) {
                await BackgroundCacheService().precacheBackground(context, schoolId);
                debugPrint('🚀 New background precached into GPU memory!');
              }
              
              _backgroundImageUrl = 'precached';
            } else {
              _backgroundImageUrl = presignedUrl;
            }
          } catch (e) {
            debugPrint('❌ Download error: $e');
            _backgroundImageUrl = presignedUrl;
          }
          
            // Cache the object key
            await prefs.setString('background_key_$schoolId', objectKey);
            debugPrint('💾 Cached object key');
          }
        } else {
          debugPrint('✅ Background unchanged, using cached file');
        }
      } else {
        debugPrint('⚠️ No background image found in Firestore');
      }
      
      // Load opacity
      final opacityDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_image_opacity')
          .get();
      
      if (opacityDoc.exists) {
        final firestoreOpacity = opacityDoc.data()?['opacity'] ?? 0.20;
        _imageOpacity = firestoreOpacity;
        
        // Update cache
        if (cachedOpacity != firestoreOpacity) {
          await prefs.setDouble('background_opacity_$schoolId', firestoreOpacity);
        }
      }
      
      // Load gradient colors
      final gradientDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_gradient')
          .get();
      
      if (gradientDoc.exists) {
        final data = gradientDoc.data()!;
        final color1 = Color(data['color1'] ?? 0xFF667eea);
        final color2 = Color(data['color2'] ?? 0xFF764ba2);
        _gradientColor1 = color1;
        _gradientColor2 = color2;
        
        // Update cache
        if (cachedColor1 != color1.value || cachedColor2 != color2.value) {
          await prefs.setInt('background_color1_$schoolId', color1.value);
          await prefs.setInt('background_color2_$schoolId', color2.value);
        }
      }
      
      debugPrint('✅ Final background URL: $_backgroundImageUrl');
      
      // No need to call setState here if background was already shown from cache
    } catch (e) {
      debugPrint('❌ Failed to load background settings: $e');
    }
  }

  Future<void> _ensureR2Configured() async {
    if (_r2Configured) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('r2_settings')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _r2AccountId = data['accountId'] ?? '';
        _r2AccessKeyId = data['accessKeyId'] ?? '';
        _r2SecretAccessKey = data['secretAccessKey'] ?? '';
        _r2BucketName = data['bucketName'] ?? '';
        _r2Configured = true;
        debugPrint('✅ R2 configuration loaded');
      }
    } catch (e) {
      debugPrint('❌ Failed to load R2 configuration: $e');
    }
  }

  Future<void> _loadPlaybackPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _preferInlinePlayback = prefs.getBool('announcements_prefer_inline') ?? true;
      });
    } catch (_) {}
  }

  // Helper to convert string to MediaTemplateStyle enum
  MediaTemplateStyle _getTemplateStyleFromString(String? styleString) {
    switch (styleString?.toLowerCase()) {
      case 'business':
        return MediaTemplateStyle.business;
      case 'modern':
        return MediaTemplateStyle.modern;
      case 'school':
      default:
        return MediaTemplateStyle.school;
    }
  }

  Future<void> _hydrateDownloads() async {
    final saved = await DownloadState.load();
    if (!mounted) return;
    if (saved.isEmpty) return;
    setState(() {
      _downloadedFile.addAll(saved);
    });
  }

  Future<void> _togglePlaybackPreference(bool value) async {
    setState(() => _preferInlinePlayback = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('announcements_prefer_inline', value);
    } catch (_) {}
  }

  // Extract YouTube videoId from known URL shapes
  String? _extractYouTubeId(String raw) {
    try {
      final url = raw.trim();
      if (url.isEmpty) return null;
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
      if (uri.host.contains('youtube.com')) {
        if (uri.path == '/watch') {
          return uri.queryParameters['v'];
        }
        if (uri.pathSegments.length >= 2) {
          return uri.pathSegments[1];
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isImageUrl(String url) {
    // Use cache to avoid repeated URL parsing
    if (_urlImageCache.containsKey(url)) {
      return _urlImageCache[url]!;
    }
    
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _urlImageCache[url] = false;
      return false;
    }
    
    final path = uri.path.toLowerCase();
    final isImage = path.endsWith('.jpg') || 
           path.endsWith('.jpeg') || 
           path.endsWith('.png') || 
           path.endsWith('.gif') || 
           path.endsWith('.bmp') || 
           path.endsWith('.webp');
    
    _urlImageCache[url] = isImage;
    return isImage;
  }

  /// Smart image opener that checks for local files first (gallery/app storage) before downloading
  Future<void> _openImageWithPriority(String url) async {
    try {
      print('Opening image with priority: $url');
      
      // First try to get local file path
      final localPath = await _getPriorityFilePath(url);
      
      if (localPath != null) {
        // Open from local storage
        await _openLocalImageWithDeviceViewer(localPath);
      } else {
        // No local file found, download fresh from URL
        await _downloadAndOpenImageWithDeviceViewer(url);
      }
    } catch (e) {
      print('Error in _openImageWithPriority: $e');
      // Fallback to download method
      await _downloadAndOpenImageWithDeviceViewer(url);
    }
  }

  /// Open a local image file with the device's native image viewer
  Future<void> _openLocalImageWithDeviceViewer(String localPath) async {
    try {
      print('Opening local image: $localPath');
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening image…'), duration: Duration(seconds: 1)),
      );
      
      final sourceFile = File(localPath);
      if (!await sourceFile.exists()) {
        throw Exception('Local file not found: $localPath');
      }
      
      // Create external cache directory for temporary image sharing
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir == null) {
        throw Exception('Cannot access external storage');
      }
      
      final tempDir = Directory('${extDir.path}/temp_images');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      // Copy image to external cache (accessible by native image viewers)
      final tempFileName = path.basename(localPath);
      final tempFile = File('${tempDir.path}/$tempFileName');
      
      // Clean old temp file if exists
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      // Copy to accessible location
      await sourceFile.copy(tempFile.path);
      print('Copied local image to temp location: ${tempFile.path}');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Open with native image viewer/gallery
      await OpenFilex.open(tempFile.path);
      
      // Clean up after delay to save storage
      Future.delayed(const Duration(minutes: 10), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('Cleaned up temp image file: $tempFileName');
          }
        } catch (e) {
          print('Error cleaning temp image file: $e');
        }
      });
      
    } catch (e) {
      print('Error opening local image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening image: $e'), duration: const Duration(seconds: 2)),
        );
      }
      // Fallback to external URL opening
      await _openExternally(localPath);
    }
  }

  Future<void> _downloadAndOpenImageWithDeviceViewer(String url) async {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening image…'), duration: Duration(seconds: 1)),
      );
      final tempDir = await getTemporaryDirectory();
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${tempDir.path}/$fileName';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final f = File(filePath);
        await f.writeAsBytes(resp.bodyBytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await OpenFilex.open(f.path);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load image'), duration: Duration(seconds: 2)),
          );
        }
        // Fallback to external URL opening
        await _openExternally(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening image: $e'), duration: const Duration(seconds: 2)),
        );
      }
      // Fallback to external URL opening
      await _openExternally(url);
    }
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  Future<void> _downloadAndOpenWithDevicePlayer(String url) async {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading video…'), duration: Duration(seconds: 1)),
      );
      final tempDir = await getTemporaryDirectory();
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${tempDir.path}/$fileName';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final f = File(filePath);
        await f.writeAsBytes(resp.bodyBytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${f.path}'), duration: const Duration(seconds: 2)),
        );
        await OpenFilex.open(f.path);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download failed, opening externally')),
          );
        }
        await _openExternally(url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed, opening externally')),
        );
      }
      await _openExternally(url);
    }
  }

  // Background download with persistence, progress; save to shared Downloads on Android after completion
  Future<void> _startDownload(String url) async {
    final priorityPath = await _getPriorityFilePath(url);
    if (priorityPath != null || _downloadProgress.containsKey(url)) return;
    final filename = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final task = DownloadTask(
      url: url,
      filename: filename,
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      allowPause: true,
    );
    setState(() {
      _dlTask[url] = task;
      _dlStatus[url] = TaskStatus.enqueued;
      _downloadProgress[url] = 0.0;
    });
    DownloadService().download(
      task,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() => _downloadProgress[url] = progress);
      },
      onStatus: (status) async {
        if (!mounted) return;
        setState(() => _dlStatus[url] = status);
        if (status == TaskStatus.complete) {
          String? movedPath;
          try {
            if (Platform.isAndroid) {
              movedPath = await DownloadService().moveToSharedStorage(task, SharedStorage.downloads);
            }
          } catch (_) {}
          final path = movedPath ?? await task.filePath();
          setState(() {
            _downloadProgress.remove(url);
            _downloadedFile[url] = path;
          });
          // persist mapping
          DownloadState.put(url, path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $path')));
          }
        } else if (status == TaskStatus.failed || status == TaskStatus.canceled) {
          setState(() {
            _downloadProgress.remove(url);
            _dlTask.remove(url);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed')));
          }
        }
      },
    );
  }

  Future<void> _togglePauseResume(String url) async {
    final task = _dlTask[url];
    if (task == null) return;
    final status = _dlStatus[url];
    try {
      if (status == TaskStatus.running) {
        await DownloadService().pause(task);
      } else if (status == TaskStatus.paused) {
        await DownloadService().resume(task);
      }
    } catch (_) {}
  }

  Future<void> _cancelDownload(String url) async {
    final task = _dlTask[url];
    if (task == null) return;
    try {
      await DownloadService().cancelTasksWithIds([task.taskId]);
    } catch (_) {}
  }

  bool _isShortsUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (!uri.host.contains('youtube.com')) return url.contains('/shorts/');
      final segs = uri.pathSegments;
      return segs.isNotEmpty && segs.first == 'shorts';
    } catch (_) {
      return url.contains('/shorts/');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🖼️ Building announcements page - Background URL: ${_backgroundImageUrl != null ? "loaded" : "null"}, Opacity: $_imageOpacity');
    
    return WillPopScope(
      onWillPop: () async {
        if (_selectionActive) {
          _exitSelection();
          return false;
        }
        return true;
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_gradientColor1, _gradientColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _backgroundImageUrl != null && _backgroundImageUrl!.isNotEmpty
            ? Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: _imageOpacity,
                      child: BackgroundCacheService().hasBackground(SchoolContext.currentSchoolId)
                        ? Image.file(
                            File(BackgroundCacheService().getBackgroundPath(SchoolContext.currentSchoolId)!),
                            fit: BoxFit.cover,
                            gaplessPlayback: true, // Image already precached in Flutter's ImageCache (GPU) - INSTANT!
                          )
                        : _backgroundImageUrl != null && _backgroundImageUrl!.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: _backgroundImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) {
                                debugPrint('🔄 Loading background image...');
                                return Container();
                              },
                              errorWidget: (context, url, error) {
                                debugPrint('❌ Error loading background: $error');
                                return Container();
                              },
                              fadeInDuration: const Duration(milliseconds: 500),
                              fadeOutDuration: const Duration(milliseconds: 300),
                            )
                          : _backgroundImageUrl != null
                            ? Image.file(
                                File(_backgroundImageUrl!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('❌ Error loading local background: $error');
                                  return Container();
                                },
                              )
                            : Container(),
                    ),
                  ),
                  _buildScaffold(),
                ],
              )
            : _buildScaffold(),
      ),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _selectionActive ? const Text('1 selected') : const Text('Announcements'),
        leading: _selectionActive ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelection) : null,
          actions: [
            if (_selectionActive)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'copy') {
                    if (_selectedText != null) {
                      await Clipboard.setData(ClipboardData(text: _selectedText!));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                      }
                    }
                    _exitSelection();
                  } else if (v == 'delete' && _selectedIsMine) {
                    final ref = _selectedRef;
                    if (ref != null) {
                      try { await ref.delete(); } catch (_) {}
                    }
                    _exitSelection();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'copy', child: Text('Copy')),
                  if (_selectedIsMine) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            else ...[
              Row(
                children: [
                  const Text('Play inline', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: _preferInlinePlayback,
                    onChanged: (v) => _togglePlaybackPreference(v),
                  ),
                ],
              ),
              // For all users, allow quick navigation to Current Page (which lists their groups)
              IconButton(
                tooltip: 'Current Page',
                icon: const Icon(Icons.home_outlined),
                onPressed: () => Navigator.pushNamed(context, '/admin', arguments: {'userId': widget.currentUserId, 'role': widget.currentUserRole}),
              ),
              if (widget.currentUserRole == 'admin')
                IconButton(
                  icon: const Icon(Icons.group_add),
                  onPressed: () => Navigator.pushNamed(context, '/groups/new', arguments: {'userId': widget.currentUserId}),
                ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'profile') {
                    final prefs = await SharedPreferences.getInstance();
                    final name = prefs.getString('session_name') ?? '';
                    final role = prefs.getString('session_role') ?? 'user';
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Profile'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('User ID: ${widget.currentUserId}'),
                            Text('Name: ${name.isEmpty ? '(unset)' : name}'),
                            Text('Role: $role'),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                        ],
                      ),
                    );
                  } else if (value == 'cleanup_settings') {
                    await showCleanupSettings();
                  } else if (value == 'clear_downloads') {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Clear App Downloads'),
                        content: const Text('This will delete all videos and thumbnails downloaded to app storage. Continue?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              try {
                                final appDir = await getApplicationDocumentsDirectory();
                                final videosDir = Directory('${appDir.path}/app_videos');
                                final thumbnailsDir = Directory('${appDir.path}/app_thumbnails');
                                
                                if (await videosDir.exists()) await videosDir.delete(recursive: true);
                                if (await thumbnailsDir.exists()) await thumbnailsDir.delete(recursive: true);
                                
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App downloads cleared')));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clear failed: $e')));
                              }
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                  } else if (value == 'signout') {
                    // 🚀 Clear session with cache (instant logout!)
                    await DynamicFirebaseOptions.clearSession();
                    
                    // Clear session name separately
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('session_name');
                    
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'profile', child: Text('Profile')),
                  PopupMenuItem(value: 'cleanup_settings', child: Text('Auto Cleanup Settings')),
                  PopupMenuItem(value: 'clear_downloads', child: Text('Clear App Downloads')),
                  PopupMenuItem(value: 'signout', child: Text('Sign out')),
                ],
              ),
            ],
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _announcementsStream,
                builder: (context, snapshot) {
                  debugPrint('📋 StreamBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
                  
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  
                  // Cache the snapshot when we have data
                  if (snapshot.hasData) {
                    _lastAnnouncementsSnapshot = snapshot.data;
                  }
                  
                  // Use cached data if available, even during waiting state
                  final dataToUse = snapshot.hasData ? snapshot.data : _lastAnnouncementsSnapshot;
                  
                  // Show transparent container while loading - NO SPINNER
                  if (dataToUse == null) {
                    debugPrint('⏳ Loading announcements...');
                    return Container(); // Transparent - no spinner blocking view
                  }
                  
                  final docs = dataToUse.docs;
                  debugPrint('📋 Announcements loaded: ${docs.length} items');
                  if (docs.isEmpty) {
                    return const Center(child: Text('No announcements yet.'));
                  }
                  final bottomPad = 96.0 + MediaQuery.of(context).padding.bottom;
                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPad),
                    itemCount: docs.length,
                    // Enhanced performance optimizations
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    cacheExtent: 2000, // Increased cache for ultra smooth scrolling
                    addAutomaticKeepAlives: false, // Don't keep all items alive
                    addRepaintBoundaries: true, // Add repaint boundaries for better performance
                    addSemanticIndexes: false, // Skip semantic indexes for performance
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final isAdmin = data['senderRole'] == 'admin';
                      final senderId = (data['senderId'] ?? '').toString();
                      final senderName = data['senderName'];
                      final ts = data['timestamp'];
                      DateTime? time;
                      if (ts is Timestamp) time = ts.toDate();
                      final timeStr = time != null ? TimeOfDay.fromDateTime(time).format(context) : '';
                      final isMine = senderId == widget.currentUserId;

                      // Day header when date changes
                      Widget? dayHeader;
                      if (time != null) {
                        final prevTs = index > 0 ? (docs[index - 1].data() as Map<String, dynamic>)['timestamp'] : null;
                        DateTime? prevTime;
                        if (prevTs is Timestamp) prevTime = prevTs.toDate();
                        final needHeader = prevTime == null ||
                            DateTime(prevTime.year, prevTime.month, prevTime.day) !=
                                DateTime(time.year, time.month, time.day);
                        if (needHeader) {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final that = DateTime(time.year, time.month, time.day);
                          final diff = that.difference(today).inDays;
                          final label = diff == 0
                              ? 'Today'
                              : diff == -1
                                  ? 'Yesterday'
                                  : '${that.day.toString().padLeft(2, '0')}/${that.month.toString().padLeft(2, '0')}/${that.year}';
                          dayHeader = Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                              child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            ),
                          );
                        }
                      }

                      final ref = docs[index].reference;
                      final isSelected = _selectionActive && _selectedIndex == index;
                      final reactions = (data['reactions'] as Map<String, dynamic>?) ?? const {};
                      // Performance optimization: Only calculate reaction counts if there are reactions
                      final Map<String, int> reactionCounts = reactions.isNotEmpty 
                        ? (() {
                            final counts = <String, int>{};
                            for (final val in reactions.values) {
                              final emo = val?.toString() ?? '';
                              if (emo.isNotEmpty) {
                                counts[emo] = (counts[emo] ?? 0) + 1;
                              }
                            }
                            return counts;
                          })()
                        : const <String, int>{};
            // Performance optimization: Use cached sender name or get it efficiently
            final cachedName = _senderNameCache[senderId];
            String resolvedName;
            
            if (senderName != null && senderName is String && senderName.isNotEmpty) {
              resolvedName = senderName;
            } else if (cachedName != null) {
              resolvedName = cachedName;
            } else if (isAdmin) {
              resolvedName = 'School Admin';
            } else {
              resolvedName = senderId;
              // Cache the sender name asynchronously for future use
              _getSenderName(senderId).then((name) {
                if (mounted) {
                  setState(() {
                    _senderNameCache[senderId] = name;
                  });
                }
              });
            }

            final bubble = Builder(
                        builder: (context) {
              final msg = (data['message'] ?? '').toString();
                      final isYouTube = (data['type'] == 'youtube') || msg.contains('youtu');
                      final isFirebaseVideo = (data['type'] == 'firebase') && msg.startsWith('http');
                      final isR2Video = (data['type'] == 'r2');
                      // Check for both traditional r2-multi (videos field) and the new mixed media format (media field)
                      final isR2Multi = (data['type'] == 'r2-multi' && data['videos'] is List && (data['videos'] as List).isNotEmpty) ||
                                       ((data['type'] == 'r2-multi-video' || data['type'] == 'r2-multi-image' || data['type'] == 'r2-multi-media') && 
                                       data['media'] is List && (data['media'] as List).isNotEmpty);
              final videoId = (data['videoId'] ?? '') as String? ?? _extractYouTubeId(msg) ?? '';
              final thumb = (data['thumbnailUrl'] ?? '') as String? ?? (videoId.isNotEmpty
                ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
                : '');
              final title = (data['title'] ?? '') as String? ?? '';
              final desc = (data['description'] ?? '') as String? ?? '';
              final meta = (data['meta'] as Map<String, dynamic>?) ?? const {};
              final metaW = (meta['width'] as num?)?.toDouble() ?? 0;
              final metaH = (meta['height'] as num?)?.toDouble() ?? 0;
              final metaAspect = (meta['aspect'] as num?)?.toDouble();
              final effectiveAspect = () {
                if (metaAspect != null && metaAspect > 0) return metaAspect;
                if (metaW > 0 && metaH > 0) return metaW / metaH;
                return null;
              }();
                          final url = msg;
              // Decide layout: if we have meta aspect, use it; otherwise fall back to URL shorts check
              final isShorts = effectiveAspect != null
                  ? (effectiveAspect < 1.0) // vertical video treated like shorts-style card
                  : _isShortsUrl(url);

                          // Special handling for media announcements - show only template-styled media
                          if (isR2Multi) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: _R2MultiVideoGrid(
                                videos: data['videos'] is List ? 
                                  List<Map<String, dynamic>>.from(data['videos'] as List) : 
                                  List<Map<String, dynamic>>.from(data['media'] as List),
                                templateStyle: _getTemplateStyleFromString(data['templateStyle'] as String?),
                                senderName: resolvedName,
                                timestamp: time,
                                timeString: timeStr,
                                onOpenVideo: (url, isImage) async {
                                  if (isImage) {
                                    // For images, use smart priority opener (checks local files first)
                                    await _openImageWithPriority(url);
                                  } else if (_preferInlinePlayback) {
                                    // In inline mode, open fullscreen R2 player
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) => _FullScreenR2VideoPage(
                                          videoId: '',
                                          videoData: {'url': url},
                                        ),
                                      ),
                                    );
                                  } else {
                                    // External playback for videos
                                    await _openExternally(url);
                                  }
                                },
                              ),
                            );
                          }

                          // Special handling for template announcements
                          if (data['templateType'] != null) {
                            try {
                              final templateType = data['templateType'] as String;
                              
                              if (templateType == 'holiday' && data['holidayDate'] != null) {
                                final holidayDate = (data['holidayDate'] as Timestamp).toDate();
                                return SchoolHolidayCard(
                                  data: data,
                                  holidayDate: holidayDate,
                                  onTap: () {
                                    // Optional: handle tap on holiday announcement
                                  },
                                  onReaction: (emoji) {
                                    _setReaction(emoji);
                                  },
                                );
                              } else if (templateType == 'notice') {
                                return NoticeAnnouncementCard(
                                  data: data,
                                  onTap: () {
                                    // Optional: handle tap on notice
                                  },
                                );
                              } else if (templateType == 'ptm') {
                                return PTMAnnouncementCard(
                                  data: data,
                                  onTap: () {
                                    // Optional: handle tap on PTM announcement
                                  },
                                );
                              } else if (templateType == 'custom') {
                                if (data['templateData'] != null) {
                                  try {
                                    return CustomAnnouncementRenderer(
                                      templateData: data['templateData'] as Map<String, dynamic>,
                                      announcementData: data,
                                      onReaction: (emoji) => _setReaction(emoji),
                                    );
                                  } catch (e) {
                                    print('Error rendering custom template: $e');
                                    // Fallback for templates with rendering errors
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.error, color: Colors.red.shade600),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Template Rendering Error',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'This custom template contains incompatible data and cannot be displayed. Please recreate the template using the current builder.',
                                            style: TextStyle(color: Colors.red.shade600),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                } else {
                                  // Fallback for custom templates without proper data
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.warning, color: Colors.orange.shade600),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Custom Template (Missing Data)',
                                              style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Title: ${data['title'] ?? 'No title'}',
                                          style: TextStyle(color: Colors.orange.shade700),
                                        ),
                                        if (data['description'] != null && data['description'].toString().isNotEmpty)
                                          Text(
                                            'Description: ${data['description']}',
                                            style: TextStyle(color: Colors.orange.shade700),
                                          ),
                                      ],
                                    ),
                                  );
                                }
                              }
                              
                              // If no specific template type matched, fall through to regular handling
                            } catch (e) {
                              print('Error rendering template: $e');
                              // Return error container for any template type casting errors
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.error, color: Colors.red.shade600),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Template Error',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'This template contains incompatible data and cannot be displayed.',
                                      style: TextStyle(color: Colors.red.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Title: ${data['title'] ?? 'No title'}',
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                          
                          // Legacy holiday handling for backward compatibility
                          if (data['type'] == 'holiday' && data['holidayDate'] != null) {
                            final holidayDate = (data['holidayDate'] as Timestamp).toDate();
                            return SchoolHolidayCard(
                              data: data,
                              holidayDate: holidayDate,
                              onTap: () {
                                // Optional: handle tap on holiday announcement
                              },
                              onReaction: (emoji) {
                                _setReaction(emoji);
                              },
                            );
                          }

                          // Regular text announcements - centered, white, full-width
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                            child: GestureDetector(
                              onLongPressStart: (details) {
                                _enterSelection(
                                  details: details,
                                  isMine: isMine,
                                  message: msg,
                                  ref: ref,
                                  index: index,
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                    ? Colors.blue[50]
                                    : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected 
                                      ? Colors.blue[200]! 
                                      : Colors.grey[200]!,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: isAdmin ? Colors.blue[100] : Colors.grey[100],
                                          child: Icon(
                                            isAdmin ? Icons.admin_panel_settings : Icons.person,
                                            size: 16,
                                            color: isAdmin ? Colors.blue[700] : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                resolvedName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: isAdmin ? Colors.blue[800] : Colors.grey[800],
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                isAdmin ? 'Administrator' : 'User',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          ts is Timestamp ? ts.toDate().toString().substring(5, 16) : '',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (!isYouTube && !isFirebaseVideo && !isR2Video && !isR2Multi)
                                      SelectableText(
                                        msg,
                                        style: const TextStyle(
                                          fontSize: 16, 
                                          height: 1.4,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    if (isYouTube || isFirebaseVideo || isR2Video || isR2Multi) ...[
                                        // YouTube card
                                        if (isYouTube && thumb.isNotEmpty)
                                          AspectRatio(
                                            aspectRatio: () {
                                              if (effectiveAspect != null && effectiveAspect > 0) {
                                                return effectiveAspect;
                                              }
                                              return isShorts ? 9 / 16 : 16 / 9;
                                            }(),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: Image.network(
                                                    thumb,
                                                    fit: BoxFit.cover,
                                                    cacheWidth: 300, // Reduced for even better scroll performance
                                                    cacheHeight: 200,
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Container(
                                                        color: Colors.grey[200],
                                                        child: const Center(
                                                          child: SizedBox(
                                                            width: 20,
                                                            height: 20,
                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (c, e, s) => const ColoredBox(
                                                      color: Colors.black12,
                                                      child: Center(child: Icon(Icons.image_not_supported_outlined)),
                                                    ),
                                                  ),
                                                ),
                                                const Positioned.fill(
                                                  child: IgnorePointer(
                                                    ignoring: true,
                                                    child: Center(
                                                      child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white70),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        // R2 videos handled below via inline overlay or ListTile; avoid duplicate blocks
                                        if (isFirebaseVideo && _preferInlinePlayback)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                                            child: Container(
                                              height: 200,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.videocam_off, size: 48, color: Colors.grey),
                                                    SizedBox(height: 8),
                                                    Text('Firebase videos not supported', style: TextStyle(color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (isR2Video && _preferInlinePlayback)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                                            child: _R2VideoThumbnail(
                                              videoData: data,
                                              width: metaW > 0 ? metaW : 350,
                                              height: metaH > 0 ? metaH : 200,
                                              aspectRatio: effectiveAspect,
                                              isShorts: isShorts,
                                            ),
                                          ),
                                        if (!isFirebaseVideo && !isR2Video && !_preferInlinePlayback)
                                        ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                                          title: Text(
                                            title.isNotEmpty ? title : 'Video',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            desc.isNotEmpty ? desc : url,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          leading: () {
                                            final poster = (data['thumbnailUrl'] as String?) ?? (meta['thumbnailUrl'] as String?);
                                            if (poster != null && poster.isNotEmpty) {
                                              return ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: SizedBox(
                                                  width: 56,
                                                  height: 36,
                                                  child: _R2PosterImage(url: poster, fit: BoxFit.cover),
                                                ),
                                              );
                                            }
                                            return null;
                                          }(),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(_preferInlinePlayback ? Icons.play_circle_fill : Icons.open_in_new),
                                                tooltip: isYouTube
                                                    ? (_preferInlinePlayback ? 'Play inline' : 'Open in YouTube')
                                                    : isR2Video
                                                    ? (_preferInlinePlayback ? 'Play inline' : 'Open R2 video')
                                                    : (_preferInlinePlayback ? 'Play inline' : 'Open externally'),
                                                onPressed: () async {
                          if (!_preferInlinePlayback) {
                                                    if (isFirebaseVideo) {
                                                      final saved = await _getPriorityFilePath(url);
                                                      if (saved != null) {
                                                        await OpenFilex.open(saved);
                                                      } else if (!_downloadProgress.containsKey(url)) {
                                                        await _startDownload(url);
                                                      }
                                                    } else if (isR2Video) {
                            // Download (temp) then open with device player
                            final videoUrl = data['url'] ?? url;
                            await _downloadAndOpenWithDevicePlayer(videoUrl);
                                                    } else if (isR2Multi) {
                                                      // Open downloads list if any; otherwise no-op
                                                      if (!context.mounted) return;
                                                      await Navigator.of(context).push(
                                                        MaterialPageRoute(builder: (_) => const DownloadsPage()),
                                                      );
                                                    } else {
                                                      await _openExternally(url);
                                                    }
                                                    return;
                                                  }
                                                  if (isYouTube) {
                                                    if (videoId.isEmpty) {
                                                      await _openExternally(url);
                                                      return;
                                                    }
                                                    if (!context.mounted) return;
                                                    await Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (ctx) => _FullScreenYouTubePage(
                                                          videoId: videoId,
                                                          url: url,
                                                          isShorts: isShorts,
                                                          aspect: effectiveAspect,
                                                        ),
                                                      ),
                                                    );
                                                  } else if (isFirebaseVideo) {
                                                    // Show message that Firebase videos are not supported
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Firebase videos are not supported')),
                                                    );
                                                  } else if (isR2Video) {
                                                    // For R2 videos, open in fullscreen player
                                                    if (!context.mounted) return;
                                                    
                                                    final videoId = data['id'] as String? ?? '';
                                                    final videoUrl = data['url'] as String? ?? '';
                                                    
                                                    // Check if we have valid video data
                                                    if (videoId.isEmpty && videoUrl.isEmpty) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Video data is missing')),
                                                      );
                                                      return;
                                                    }
                                                    
                                                    await Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (ctx) => _FullScreenR2VideoPage(
                                                          videoId: videoId,
                                                          videoData: data,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                          onTap: () async {
                      if (!_preferInlinePlayback) {
                                              if (isFirebaseVideo) {
                                                final saved = await _getPriorityFilePath(url);
                                                if (saved != null) {
                                                  await OpenFilex.open(saved);
                                                } else if (!_downloadProgress.containsKey(url)) {
                                                  await _startDownload(url);
                                                }
                                              } else if (isR2Video) {
                        // Download (temp) then open with device player
                        final videoUrl = data['url'] ?? url;
                        await _downloadAndOpenWithDevicePlayer(videoUrl);
                                              } else {
                                                await _openExternally(url);
                                              }
                                              return;
                                            }
                                            if (isYouTube) {
                                              if (videoId.isEmpty) {
                                                await _openExternally(url);
                                                return;
                                              }
                                              if (!context.mounted) return;
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (ctx) => _FullScreenYouTubePage(
                                                    videoId: videoId,
                                                    url: url,
                                                    isShorts: isShorts,
                                                    aspect: effectiveAspect,
                                                  ),
                                                ),
                                              );
                                            } else if (isFirebaseVideo) {
                                              // Show message that Firebase videos are not supported
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Firebase videos are not supported')),
                                              );
                                            } else if (isR2Video) {
                                              // For R2 videos, open in fullscreen player
                                              if (!context.mounted) return;
                                              
                                              final videoId = data['id'] as String? ?? '';
                                              final videoUrl = data['url'] as String? ?? '';
                                              
                                              // Check if we have valid video data
                                              if (videoId.isEmpty && videoUrl.isEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Video data is missing')),
                                                );
                                                return;
                                              }
                                              
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (ctx) => _FullScreenR2VideoPage(
                                                    videoId: videoId,
                                                    videoData: data,
                                                  ),
                                                ),
                                              );
                                            } else if (isR2Multi) {
                                              // Default tap for multi: open Downloads page or do nothing
                                              if (!context.mounted) return;
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const DownloadsPage()),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                          ],
                                        ),
                                      ),
                                      if (reactionCounts.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Align(
                                          alignment: Alignment.center,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: const [BoxShadow(blurRadius: 0.3, color: Colors.black12)],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (final entry in reactionCounts.entries) ...[
                                                  Text(entry.key, style: const TextStyle(fontSize: 14)),
                                                  if (entry.value > 1)
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 2, right: 6),
                                                      child: Text('${entry.value}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                                    )
                                                  else
                                                    const SizedBox(width: 6),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );

                      // Add footer with username and timestamp (but not for media posts - they have their own footer)
                      // Check if this is a media post (r2-multi types)
                      final isMediaPost = (data['type'] == 'r2-multi' && data['videos'] is List && (data['videos'] as List).isNotEmpty) ||
                                         ((data['type'] == 'r2-multi-video' || data['type'] == 'r2-multi-image' || data['type'] == 'r2-multi-media') && 
                                         data['media'] is List && (data['media'] as List).isNotEmpty);
                      
                      final bubbleWithFooter = isMediaPost ? bubble : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          bubble,
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    resolvedName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  time != null 
                                    ? '${time.day}/${time.month}/${time.year} ${timeStr}'
                                    : '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      
                      // Wrap in RepaintBoundary for better scrolling performance
                      final itemWidget = dayHeader != null 
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [dayHeader!, bubbleWithFooter],
                            )
                          : bubbleWithFooter;
                      
                      return RepaintBoundary(
                        key: ValueKey('announcement_${docs[index].id}'),
                        child: itemWidget,
                      );
                    },
                  );
                },
              ),
            ),
            if (widget.currentUserRole == 'admin' && _showAnnouncementForm)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Announcement',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showAnnouncementForm = false;
                            });
                            _messageController.clear();
                          },
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          tooltip: 'Close',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Write your announcement message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Attachment button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.attach_file, color: Colors.blue[600]),
                            tooltip: 'Attach Media',
                            onPressed: () async {
                              showModalBottomSheet(
                                context: context,
                                showDragHandle: true,
                                builder: (ctx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const ListTile(title: Text('Attach'), subtitle: Text('Choose what to attach')),
                                      ListTile(
                                        leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.attach_file, color: Colors.white)),
                                        title: const Text('Photos & Videos'),
                                        subtitle: const Text('Upload multiple media files together'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => MultiR2MediaUploaderPage(
                                                currentUserId: widget.currentUserId,
                                                currentUserRole: widget.currentUserRole,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.video_collection, color: Colors.white)),
                                        title: const Text('Videos Only'),
                                        subtitle: const Text('Upload multiple videos'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => MultiR2UploaderPage(
                                                currentUserId: widget.currentUserId,
                                                currentUserRole: widget.currentUserRole,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const Spacer(),
                        // Send button
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.blue[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.send, color: Colors.white, size: 18),
                            label: const Text(
                              'Post',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _sendAnnouncement,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Floating Panel Overlay
          if (_showFloatingPanel)
            Positioned(
              right: 16,
              bottom: 100,
              child: Container(
                width: 280,
                height: 350,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with close button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.blue[800]),
                            onPressed: () {
                              setState(() {
                                _showFloatingPanel = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildQuickActionItem(
                              icon: Icons.announcement,
                              title: 'Create Announcement',
                              subtitle: 'Post new announcement',
                              onTap: () {
                                setState(() {
                                  _showFloatingPanel = false;
                                  _showAnnouncementForm = true;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionItem(
                              icon: Icons.attach_file,
                              title: 'Upload Media',
                              subtitle: 'Add photos or videos',
                              onTap: () {
                                setState(() {
                                  _showFloatingPanel = false;
                                });
                                // Navigate to media upload
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MultiR2MediaUploaderPage(
                                      currentUserId: widget.currentUserId,
                                      currentUserRole: widget.currentUserRole,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionItem(
                              icon: Icons.design_services,
                              title: 'Template Management',
                              subtitle: 'Holiday, Notice, PTM templates',
                              onTap: () {
                                setState(() {
                                  _showFloatingPanel = false;
                                });
                                // Navigate to template management
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TemplateManagementPage(
                                      currentUserId: widget.currentUserId,
                                      currentUserRole: widget.currentUserRole,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionItem(
                              icon: Icons.refresh,
                              title: 'Refresh',
                              subtitle: 'Reload announcements',
                              onTap: () {
                                setState(() {
                                  _showFloatingPanel = false;
                                });
                                // Trigger refresh
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionItem(
                              icon: Icons.settings,
                              title: 'Settings',
                              subtitle: 'View preferences',
                              onTap: () {
                                setState(() {
                                  _showFloatingPanel = false;
                                });
                                // Navigate to settings
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const UserSettingsPage()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: (widget.currentUserRole == 'admin' && !_showAnnouncementForm) 
            ? FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _showFloatingPanel = !_showFloatingPanel;
                  });
                },
                backgroundColor: Colors.blue[600],
                child: Icon(
                  _showFloatingPanel ? Icons.close : Icons.add,
                  color: Colors.white,
                ),
              )
            : null,
      );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.blue[700],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // Automatic cleanup for ALL users - runs on app startup
  Future<void> _performAutomaticCleanup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get user's cleanup cutoff days first to check if it's immediate cleanup
      final cutoffDaysStr = prefs.getString('cleanup_cutoff_days') ?? '4';
      final cutoffDays = int.tryParse(cutoffDaysStr) ?? 4;
      
      // Check if we should perform cleanup today (skip daily check for immediate cleanup)
      if (cutoffDays > 0) {
        final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
        final lastCleanup = prefs.getString('last_auto_cleanup_date') ?? '';
        
        if (lastCleanup == today) {
          print('🧹 Auto cleanup already performed today');
          return; // Already cleaned today
        }
      }
      
      final cutoffDate = cutoffDays == 0 ? DateTime.now() : DateTime.now().subtract(Duration(days: cutoffDays));
      
      String timeDescription;
      if (cutoffDays == 0) {
        timeDescription = 'before current time (immediate cleanup)';
      } else if (cutoffDays == 1) {
        timeDescription = 'older than 1 day';
      } else {
        timeDescription = 'older than $cutoffDays days';
      }
      
      print('🧹 Starting automatic cleanup for files $timeDescription');
      print('🧹 Cutoff date: ${cutoffDate.toIso8601String().split('T')[0]}');
      
      // Clean app storage files
      final filesDeleted = await _cleanupOldAppStorageFiles(cutoffDate);
      
      // Clean cache and temp files
      await _clearDeviceCache();
      
      // Update last cleanup date (only for non-immediate cleanup)
      if (cutoffDays > 0) {
        final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
        await prefs.setString('last_auto_cleanup_date', today);
      }
      
      if (filesDeleted > 0) {
        print('✅ Auto cleanup completed: $filesDeleted old files deleted ($timeDescription)');
      } else {
        if (cutoffDays == 0) {
          print('✅ Auto cleanup completed: All files cleaned (immediate cleanup)');
        } else {
          print('✅ Auto cleanup completed: No old files found ($timeDescription)');
        }
      }
      
    } catch (e) {
      print('❌ Error during automatic cleanup: $e');
    }
  }

  // Clean old files from app storage based on cutoff date
  Future<int> _cleanupOldAppStorageFiles(DateTime cutoffDate) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/app_videos');
      final thumbnailsDir = Directory('${appDir.path}/app_thumbnails');
      
      int deletedCount = 0;
      
      // Clean videos directory
      if (await videosDir.exists()) {
        deletedCount += await _cleanupDirectoryByDate(videosDir, cutoffDate);
      }
      
      // Clean thumbnails directory
      if (await thumbnailsDir.exists()) {
        deletedCount += await _cleanupDirectoryByDate(thumbnailsDir, cutoffDate);
      }
      
      return deletedCount;
    } catch (e) {
      print('Error cleaning app storage files: $e');
      return 0;
    }
  }

  // Clean files in directory older than cutoff date
  Future<int> _cleanupDirectoryByDate(Directory dir, DateTime cutoffDate) async {
    try {
      int deletedCount = 0;
      final entities = dir.listSync();
      
      for (final entity in entities) {
        if (entity is File) {
          final stat = await entity.stat();
          final fileDate = stat.modified;
          
          // If file is older than cutoff date, delete it
          if (fileDate.isBefore(cutoffDate)) {
            try {
              await entity.delete();
              deletedCount++;
              print('🗑️ Deleted old file: ${path.basename(entity.path)}');
              
              // Remove from download state
              final saved = await DownloadState.load();
              saved.removeWhere((url, filePath) => filePath == entity.path);
              await DownloadState.save(saved);
              
            } catch (e) {
              print('Error deleting file ${entity.path}: $e');
            }
          }
        }
      }
      
      return deletedCount;
    } catch (e) {
      print('Error cleaning directory ${dir.path}: $e');
      return 0;
    }
  }

  // Settings method for users to configure cleanup days
  Future<void> showCleanupSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final currentDays = int.tryParse(prefs.getString('cleanup_cutoff_days') ?? '4') ?? 4;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto Cleanup Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Automatically delete downloaded files older than:'),
            const SizedBox(height: 16),
            DropdownButton<int>(
              value: currentDays,
              items: [0, 1, 4, 7, 15, 30, 60, 90].map((days) {
                String label;
                if (days == 0) {
                  label = 'Immediate (before current time)';
                } else if (days == 1) {
                  label = '1 day';
                } else {
                  label = '$days days';
                }
                return DropdownMenuItem(
                  value: days,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  await prefs.setString('cleanup_cutoff_days', value.toString());
                  Navigator.pop(context);
                  
                  String message;
                  if (value == 0) {
                    message = 'Auto cleanup set to immediate (before current time)';
                  } else if (value == 1) {
                    message = 'Auto cleanup set to 1 day';
                  } else {
                    message = 'Auto cleanup set to $value days';
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _removeReactionsOverlay();
    super.dispose();
  }

  // Clear device cache for memory optimization
  Future<void> _clearDeviceCache() async {
    try {
      print('🧹 Starting comprehensive cache cleanup...');
      
      // Clear external cache directory (system cache)
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final cacheDir = Directory('${extDir.path}/cache');
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          print('📂 Cleared external cache');
        }
      }
      
      // Clear temporary video files
      if (extDir != null) {
        final tempDir = Directory('${extDir.path}/temp_videos');
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
          print('🎬 Cleared temp videos');
        }
      }
      
      // Clear system temp directory
      final tempDirectory = await getTemporaryDirectory();
      if (await tempDirectory.exists()) {
        final entities = tempDirectory.listSync();
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            // Continue deleting other files even if one fails
            print('Warning: Could not delete ${entity.path}: $e');
          }
        }
        print('🗂️ Cleared system temp directory');
      }
      
      print('✅ Comprehensive cache cleanup completed');
      
    } catch (e) {
      print('❌ Error during comprehensive cache cleanup: $e');
    }
  }
}

// Renders up to 4 thumbnails in a 2x2 grid with +N on the last tile when more,
// and shows a centered "Download all" overlay with progress.
class _R2MultiVideoGrid extends StatefulWidget {
  final List<Map<String, dynamic>> videos; // each: {url, thumbnailUrl, width, height, ...}
  final void Function(String url, bool isImage) onOpenVideo;
  final MediaTemplateStyle templateStyle;
  final String senderName;
  final DateTime? timestamp;
  final String timeString;

  const _R2MultiVideoGrid({
    required this.videos, 
    required this.onOpenVideo,
    this.templateStyle = MediaTemplateStyle.school,
    required this.senderName,
    this.timestamp,
    required this.timeString,
  });

  @override
  State<_R2MultiVideoGrid> createState() => _R2MultiVideoGridState();
}

class _R2MultiVideoGridState extends State<_R2MultiVideoGrid> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;
  bool _downloading = false;
  double _progress = 0.0; // 0..1 aggregate
  final Map<int, double> _perItem = {}; // index -> progress
  String? _r2AccountId;
  String? _r2AccessKeyId;
  String? _r2SecretAccessKey;
  String? _r2BucketName;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Save to gallery state
  bool _savingToGallery = false;
  final Map<String, bool> _galleryStatus = {}; // url -> isInGallery

  bool get _isComplete => _progress >= 1.0 - 1e-6;
  bool get _allSavedToGallery => widget.videos.every((v) => _galleryStatus[v['url']] == true);

  @override
  void initState() {
    super.initState();
    _loadR2Configuration();
    // Pre-mark any videos that are already downloaded locally so we don't re-download
    _preMarkCompletedItems();
    // Check gallery status for each media item
    _checkGalleryStatus();
    
    // Initialize pulse animation for save status
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadR2Configuration() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('r2_settings').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _r2AccountId = data['accountId'];
          _r2AccessKeyId = data['accessKeyId'];
          _r2SecretAccessKey = data['secretAccessKey'];
          _r2BucketName = data['bucketName'];
        });
      }
    } catch (_) {}
  }

  Future<String> _presign(String rawUrl) async {
    try {
      if (_r2AccountId == null || _r2AccessKeyId == null || _r2SecretAccessKey == null || _r2BucketName == null) {
        return rawUrl;
      }
      final uri = Uri.parse(rawUrl);
      final segs = uri.pathSegments;
      final objectKey = segs.join('/');
      final minio = Minio(
        endPoint: '${_r2AccountId}.r2.cloudflarestorage.com',
        accessKey: _r2AccessKeyId!,
        secretKey: _r2SecretAccessKey!,
        useSSL: true,
      );
      return await minio.presignedGetObject(_r2BucketName!, objectKey, expires: 3600);
    } catch (_) {
      return rawUrl;
    }
  }

  Future<void> _startDownloadAll() async {
    if (_downloading) return;
    
    // For app storage downloads, we don't need permission - files go to internal storage
    // This ensures Google Play compliance by respecting permission denial
    
    setState(() {
      _downloading = true;
      // Keep any items we already know are completed from a previous session
      _recomputeAggregate();
    });

    // Use internal app storage (not visible in gallery) - Google Play compliant
    Directory? appDir;
    try {
      // Get app's internal storage directory
      appDir = await getApplicationDocumentsDirectory();
      print('Using app internal storage: ${appDir.path}');
    } catch (e) {
      print('App storage error: $e');
      // Fallback to temporary directory
      appDir = await getTemporaryDirectory();
    }
    
    // Use the app_flutter subdirectory for organized storage
    final mediaDir = Directory('${appDir.path}/app_videos');
    final thumbnailsDir = Directory('${appDir.path}/app_thumbnails');
    
    print('Creating app directories: ${mediaDir.path} and ${thumbnailsDir.path}');
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
      print('Created internal thumbnails directory');
    }
    print('App directories created successfully');

    for (int i = 0; i < widget.videos.length; i++) {
      final v = widget.videos[i];
      final url = (v['url'] as String?) ?? (v['message'] as String?) ?? '';
      final thumbnailUrl = (v['thumbnailUrl'] as String?) ?? ((v['meta'] as Map<String, dynamic>?)?['thumbnailUrl'] as String?);
      
      if (url.isEmpty) {
        _perItem[i] = 1.0; // skip
        _recomputeAggregate();
        continue;
      }
      
      // Skip if already completed
      if ((_perItem[i] ?? 0) >= 1.0 - 1e-6) {
        continue;
      }
      
      try {
        final uri = Uri.parse(url);
        final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final localPath = '${mediaDir.path}/$fileName';
        
        // If file already exists locally, mark as done and persist mapping
        final existing = File(localPath);
        if (await existing.exists()) {
          setState(() {
            _perItem[i] = 1.0;
            _recomputeAggregate();
          });
          DownloadState.put(url, localPath);
          
          // Download thumbnail if available
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
            await _downloadThumbnail(thumbnailUrl, thumbnailsDir);
          }
          
          continue;
        }
        
        // Download thumbnail first (if available)
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          await _downloadThumbnail(thumbnailUrl, thumbnailsDir);
        }
        
        final presigned = await _presign(url);

        await FastDownloadManager.downloadFileWithProgress(
          url: presigned,
          filePath: localPath,
          maxConnections: 4,
          chunkSize: 512 * 1024,
          onProgress: (p, downloaded, total, speed) {
            if (!mounted) return;
            setState(() {
              _perItem[i] = p;
              _recomputeAggregate();
            });
            if (p >= 1.0 - 1e-6) {
              // Make file visible in Gallery by proper media scanning
              try {
                final file = File(localPath);
                if (Platform.isAndroid && file.existsSync()) {
                  // Set proper file permissions
                  try {
                    Process.runSync('chmod', ['644', localPath]);
                  } catch (e) {
                    print('Permission setting failed: $e');
                  }
                  
                  // Use multiple methods to ensure Gallery visibility
                  try {
                    // Method 1: Direct media scanner broadcast
                    Process.runSync('am', ['broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE', '-d', 'file://$localPath']);
                    print('Media scanner triggered for: $localPath');
                    
                    // Method 2: Refresh media database
                    Process.runSync('am', ['broadcast', '-a', 'android.intent.action.MEDIA_MOUNTED', '-d', 'file://${Directory(localPath).parent.path}']);
                    print('Media database refreshed');
                  } catch (e) {
                    print('Media scanning failed: $e');
                  }
                  
                  print('File saved and should be visible in Gallery: $localPath');
                }
              } catch (e) {
                print('Gallery visibility setup failed (file still accessible): $e');
              }
              // persist
              DownloadState.put(url, localPath);
            }
          },
        );
      } catch (_) {
        setState(() {
          _perItem[i] = 0.0; // failed; keep as 0 for aggregate
          _recomputeAggregate();
        });
      }
    }

    if (!mounted) return;
    setState(() => _downloading = false);
    
    // Show success message indicating files saved to Downloads and visible in Gallery
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Media downloaded: ${Platform.isAndroid ? 'Check Downloads folder or Gallery app for "SchoolApp Media"' : 'Documents'}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _startDownloadInApp() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      // Keep any items we already know are completed from a previous session
      _recomputeAggregate();
    });

    // Use app's internal storage - no permissions required
    final appDir = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${appDir.path}/app_videos');
    final thumbnailsDir = Directory('${appDir.path}/app_thumbnails');
    if (!await videosDir.exists()) await videosDir.create(recursive: true);
    if (!await thumbnailsDir.exists()) await thumbnailsDir.create(recursive: true);

    for (int i = 0; i < widget.videos.length; i++) {
      final v = widget.videos[i];
      final url = (v['url'] as String?) ?? (v['message'] as String?) ?? '';
      final thumbnailUrl = (v['thumbnailUrl'] as String?) ?? ((v['meta'] as Map<String, dynamic>?)?['thumbnailUrl'] as String?);
      
      if (url.isEmpty) {
        _perItem[i] = 1.0; // skip
        _recomputeAggregate();
        continue;
      }
      
      // Skip if already completed
      if ((_perItem[i] ?? 0) >= 1.0 - 1e-6) {
        continue;
      }
      
      try {
        final uri = Uri.parse(url);
        final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final localPath = '${videosDir.path}/$fileName';
        
        // If file already exists locally, mark as done and persist mapping
        final existing = File(localPath);
        if (await existing.exists()) {
          setState(() {
            _perItem[i] = 1.0;
            _recomputeAggregate();
          });
          DownloadState.put(url, localPath);
          
          // Download thumbnail if available
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
            await _downloadThumbnail(thumbnailUrl, thumbnailsDir);
          }
          
          continue;
        }
        
        // Download thumbnail first (if available)
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
          await _downloadThumbnail(thumbnailUrl, thumbnailsDir);
        }
        
        final presigned = await _presign(url);

        await FastDownloadManager.downloadFileWithProgress(
          url: presigned,
          filePath: localPath,
          maxConnections: 4,
          chunkSize: 512 * 1024,
          onProgress: (p, downloaded, total, speed) {
            if (!mounted) return;
            setState(() {
              _perItem[i] = p;
              _recomputeAggregate();
            });
            if (p >= 1.0 - 1e-6) {
              // persist to app storage mapping
              DownloadState.put(url, localPath);
            }
          },
        );
      } catch (_) {
        setState(() {
          _perItem[i] = 0.0; // failed; keep as 0 for aggregate
          _recomputeAggregate();
        });
      }
    }

    if (!mounted) return;
    setState(() => _downloading = false);
    
    // Clear device cache after successful app download for memory optimization
    // This clears only cache/temp files, NOT the downloaded videos in app storage
    await _clearDeviceCacheOnly();
    
    // Show success message indicating files saved to app storage
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Videos downloaded to app storage\nDevice cache cleared for memory optimization'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
  
  // Download thumbnail and store it locally
  Future<String?> _downloadThumbnail(String thumbnailUrl, Directory thumbnailsDir) async {
    try {
      // Check in memory cache first (faster than disk access)
      if (_R2PosterImageState._thumbnailPathCache.containsKey(thumbnailUrl)) {
        final cachedPath = _R2PosterImageState._thumbnailPathCache[thumbnailUrl]!;
        final thumbFile = File(cachedPath);
        if (await thumbFile.exists()) {
          return cachedPath;
        }
      }
      
      // Check if we already have this thumbnail stored locally
      final savedThumbnails = await DownloadState.loadThumbnails();
      if (savedThumbnails.containsKey(thumbnailUrl)) {
        final savedPath = savedThumbnails[thumbnailUrl]!;
        final thumbFile = File(savedPath);
        if (await thumbFile.exists()) {
          // Update the memory cache
          _R2PosterImageState._thumbnailPathCache[thumbnailUrl] = savedPath;
          return savedPath;
        }
      }
      
      // Extract filename from URL or create a unique one
      final uri = Uri.parse(thumbnailUrl);
      final fileName = uri.pathSegments.isNotEmpty ? 
          uri.pathSegments.last : 
          'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
      final localPath = '${thumbnailsDir.path}/$fileName';
      
      // Download the thumbnail
      final presigned = await _presign(thumbnailUrl);
      
      final response = await http.get(Uri.parse(presigned));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Save the mapping in both persistent storage and memory cache
        await DownloadState.putThumbnail(thumbnailUrl, localPath);
        _R2PosterImageState._thumbnailPathCache[thumbnailUrl] = localPath;
        
        print('Downloaded thumbnail: $thumbnailUrl -> $localPath');
        return localPath;
      }
    } catch (e) {
      print('Error downloading thumbnail: $e');
    }
    return null;
  }

  // Clear all app downloads - deletes app storage directories
  Future<void> _clearAppDownloads() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/app_videos');
      final thumbnailsDir = Directory('${appDir.path}/app_thumbnails');
      
      if (await videosDir.exists()) await videosDir.delete(recursive: true);
      if (await thumbnailsDir.exists()) await thumbnailsDir.delete(recursive: true);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App downloads cleared')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clear failed: $e')));
    }
  }

  // On mount, find which of this card's videos are already downloaded and mark them complete
  Future<void> _preMarkCompletedItems() async {
    try {
      final saved = await DownloadState.load();
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/videos');
      final updates = <int, double>{};
      for (int i = 0; i < widget.videos.length; i++) {
        final v = widget.videos[i];
        final url = (v['url'] as String?) ?? (v['message'] as String?) ?? '';
        if (url.isEmpty) continue;
        // 1) If persisted mapping exists and the file still exists, use it
        final mapped = saved[url];
        if (mapped != null) {
          final f = File(mapped);
          if (await f.exists()) {
            updates[i] = 1.0;
            continue;
          }
        }
        // 2) Fallback: derive by fileName under app documents/videos
        final fileName = Uri.tryParse(url)?.pathSegments.last;
        if (fileName != null && fileName.isNotEmpty) {
          final f = File('${videosDir.path}/$fileName');
          if (await f.exists()) {
            updates[i] = 1.0;
            // backfill mapping for consistency
            await DownloadState.put(url, f.path);
          }
        }
      }
      if (!mounted || updates.isEmpty) return;
      setState(() {
        _perItem.addAll(updates);
        _recomputeAggregate();
      });
    } catch (_) {}
  }

  void _recomputeAggregate() {
    if (_perItem.isEmpty) {
      _progress = 0.0;
      return;
    }
    final sum = _perItem.values.fold<double>(0.0, (a, b) => a + b);
    _progress = sum / (widget.videos.length);
  }

  // Check which media items are already saved to gallery
  Future<void> _checkGalleryStatus() async {
    try {
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir == null) return;
      
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String appName = packageInfo.appName.isNotEmpty ? packageInfo.appName : 'SchoolApp';
      final String basePath = extDir.path.split('/Android/')[0];
      final String galleryPath = '$basePath/Download/$appName';
      
      final updates = <String, bool>{};
      for (final video in widget.videos) {
        final url = video['url'] as String? ?? '';
        if (url.isEmpty) continue;
        
        final fileName = Uri.tryParse(url)?.pathSegments.last ?? 'media.mp4';
        final galleryFile = File('$galleryPath/$fileName');
        updates[url] = await galleryFile.exists();
      }
      
      if (mounted) {
        setState(() {
          _galleryStatus.addAll(updates);
        });
      }
    } catch (e) {
      print('Error checking gallery status: $e');
    }
  }

  // Save all media to gallery and delete from app storage
  Future<void> _saveAllToGallery() async {
    if (_savingToGallery) return;
    
    setState(() {
      _savingToGallery = true;
    });
    
    try {
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir == null) {
        throw Exception('Cannot access external storage');
      }
      
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String appName = packageInfo.appName.isNotEmpty ? packageInfo.appName : 'SchoolApp';
      final String basePath = extDir.path.split('/Android/')[0];
      final String galleryPath = '$basePath/Download/$appName';
      final galleryDir = Directory(galleryPath);
      
      // Create gallery directory if it doesn't exist
      if (!await galleryDir.exists()) {
        await galleryDir.create(recursive: true);
      }
      
      final saved = await DownloadState.load();
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/app_videos');
      
      int moveCount = 0;
      for (final video in widget.videos) {
        final url = video['url'] as String? ?? '';
        if (url.isEmpty) continue;
        
        // Skip if already in gallery
        if (_galleryStatus[url] == true) continue;
        
        // Find the app storage file
        File? appFile;
        
        // First check persisted mapping
        final mapped = saved[url];
        if (mapped != null) {
          appFile = File(mapped);
          if (!await appFile.exists()) appFile = null;
        }
        
        // Fallback: look in app_videos directory
        if (appFile == null) {
          final fileName = Uri.tryParse(url)?.pathSegments.last;
          if (fileName != null && await videosDir.exists()) {
            final candidateFile = File('${videosDir.path}/$fileName');
            if (await candidateFile.exists()) {
              appFile = candidateFile;
            }
          }
        }
        
        if (appFile == null) continue;
        
        try {
          // Copy to gallery
          final fileName = path.basename(appFile.path);
          final galleryFile = File('$galleryPath/$fileName');
          await appFile.copy(galleryFile.path);
          
          // Trigger media scanner for gallery visibility
          if (Platform.isAndroid) {
            try {
              Process.runSync('chmod', ['644', galleryFile.path]);
              Process.runSync('am', ['broadcast', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE', '-d', 'file://${galleryFile.path}']);
            } catch (e) {
              print('Media scanner failed: $e');
            }
          }
          
          // Delete from app storage
          await appFile.delete();
          
          // Update download state to point to gallery location (don't remove!)
          final currentState = await DownloadState.load();
          currentState[url] = galleryFile.path; // Update path to gallery location
          await DownloadState.save(currentState);
          
          // Update gallery status
          _galleryStatus[url] = true;
          moveCount++;
          
          print('Moved to gallery: $fileName');
        } catch (e) {
          print('Error moving $url to gallery: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          // Update download completion status since files were moved
          for (int i = 0; i < widget.videos.length; i++) {
            final url = widget.videos[i]['url'] as String? ?? '';
            if (_galleryStatus[url] == true) {
              _perItem[i] = 1.0;
            }
          }
          _recomputeAggregate();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(moveCount > 0 
              ? 'Moved $moveCount media files to Gallery' 
              : 'All media already in Gallery'),
            backgroundColor: moveCount > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save to Gallery failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingToGallery = false;
        });
      }
    }
  }

  // Get template colors based on style
  Map<String, dynamic> _getTemplateColors() {
    switch (widget.templateStyle) {
      case MediaTemplateStyle.business:
        return {
          'gradient': [const Color(0xFF1E293B), const Color(0xFF334155)],
          'accent': const Color(0xFF64748B),
          'text': Colors.white,
        };
      case MediaTemplateStyle.modern:
        return {
          'gradient': [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
          'accent': const Color(0xFFF472B6),
          'text': Colors.white,
        };
      case MediaTemplateStyle.school:
      default:
        return {
          'gradient': [const Color(0xFF8AD7FF), const Color(0xFFC6F7E6)],
          'accent': const Color(0xFF022039),
          'text': const Color(0xFF022039),
        };
    }
  }

  IconData _getTemplateIcon() {
    switch (widget.templateStyle) {
      case MediaTemplateStyle.business:
        return Icons.business_center;
      case MediaTemplateStyle.modern:
        return Icons.auto_awesome;
      case MediaTemplateStyle.school:
      default:
        return Icons.school;
    }
  }

  String _getTemplateTitle() {
    switch (widget.templateStyle) {
      case MediaTemplateStyle.business:
        return 'Business Media';
      case MediaTemplateStyle.modern:
        return 'Modern Media';
      case MediaTemplateStyle.school:
      default:
        return 'School Media';
    }
  }

  String _getTemplateLabel() {
    switch (widget.templateStyle) {
      case MediaTemplateStyle.business:
        return 'PROFESSIONAL';
      case MediaTemplateStyle.modern:
        return 'CREATIVE';
      case MediaTemplateStyle.school:
      default:
        return 'ACADEMIC';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final items = widget.videos;
    final count = items.length;
    final show = items.take(4).toList();
    final extra = items.length - show.length;

    // Get template colors
    final templateColors = _getTemplateColors();
    final gradientColors = templateColors['gradient'] as List<Color>;

    return Container(
      width: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Media Grid (Telegram style - clean and minimal)
          Container(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                _buildWhatsAppStyleGrid(show, extra, count),
                // Download overlay - Telegram style
                if (!_isComplete)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: _downloading ? null : () async {
                            await _startDownloadInApp();
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _downloading
                              ? Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    value: _progress,
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                                    backgroundColor: Colors.grey[200],
                                  ),
                                )
                              : Icon(
                                  Icons.file_download_outlined,
                                  size: 32,
                                  color: Colors.blue[600],
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Bottom Action Bar (Telegram style)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side - Username and timestamp
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.senderName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.timestamp != null 
                          ? '${widget.timestamp!.day}/${widget.timestamp!.month}/${widget.timestamp!.year} ${widget.timeString}'
                          : '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Right side - Save button
                GestureDetector(
                  onTap: _savingToGallery ? null : _saveAllToGallery,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _allSavedToGallery 
                        ? Colors.green[50]
                        : _savingToGallery
                          ? Colors.blue[50]
                          : Colors.blue[600],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _allSavedToGallery 
                          ? Colors.green
                          : _savingToGallery
                            ? Colors.blue
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_savingToGallery)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                            ),
                          )
                        else
                          Icon(
                            _allSavedToGallery ? Icons.check_circle : Icons.download_rounded,
                            color: _allSavedToGallery ? Colors.green : Colors.white,
                            size: 16,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _savingToGallery 
                            ? 'Saving'
                            : _allSavedToGallery 
                              ? 'Saved' 
                              : 'Save',
                          style: TextStyle(
                            color: _allSavedToGallery ? Colors.green : _savingToGallery ? Colors.blue[700] : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTemplateEmoji() {
    switch (widget.templateStyle) {
      case MediaTemplateStyle.business:
        return '💼';
      case MediaTemplateStyle.modern:
        return '🎨';
      case MediaTemplateStyle.school:
      default:
        return '👩‍🏫';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildWhatsAppStyleGrid(List<Map<String, dynamic>> show, int extra, int totalCount) {
    if (totalCount == 1) {
      // Single media - full container
      return Container(
        height: 250,
        child: _buildMediaTile(show[0], isLarge: true),
      );
    } else if (totalCount == 2) {
      // Two media - side by side like WhatsApp (horizontal row)
      return Container(
        height: 250,
        child: Row(
          children: [
            Expanded(child: _buildMediaTile(show[0])),
            const SizedBox(width: 8),
            Expanded(child: _buildMediaTile(show[1])),
          ],
        ),
      );
    } else if (totalCount == 3) {
      // Three media - two on top row, one below (WhatsApp style)
      return Container(
        height: 250,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildMediaTile(show[0])),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMediaTile(show[1])),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildMediaTile(show[2])),
          ],
        ),
      );
    } else {
      // Four or more - 2x2 grid with count overlay on last tile
      return Container(
        height: 250,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 4, // Always show 4 tiles
          itemBuilder: (context, index) {
            if (index < show.length) {
              return _buildMediaTile(
                show[index], 
                showExtraCount: extra > 0 && index == 3,
                extraCount: extra,
              );
            }
            return Container(); // Empty container for missing items
          },
        ),
      );
    }
  }

  Widget _buildMediaTile(Map<String, dynamic> v, {bool isLarge = false, bool showExtraCount = false, int extraCount = 0}) {
    final poster = (v['thumbnailUrl'] as String?) ?? ((v['meta'] as Map<String, dynamic>?)?['thumbnailUrl'] as String?);
    final url = (v['url'] as String?) ?? '';
    final isImage = (v['type'] == 'r2-image');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          if (_isComplete) {
            await _openCurrentDownloadsList();
          } else if (url.isNotEmpty) {
            widget.onOpenVideo(url, isImage);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (poster != null && poster.isNotEmpty)
                  _BuildBlurredThumbnail(
                    url: poster, 
                    fit: BoxFit.cover,
                    isDownloaded: _isComplete,
                    originalUrl: url,
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey[200]!,
                          Colors.grey[100]!,
                        ],
                      ),
                    ),
                  ),
                // Media type indicator
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isImage 
                          ? const Color(0xFF4CAF50).withOpacity(0.9)
                          : const Color(0xFFE91E63).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isImage ? Icons.photo_rounded : Icons.videocam_rounded,
                          size: isLarge ? 14 : 10,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isImage ? 'IMG' : 'VID',
                          style: TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: isLarge ? 9 : 7,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Gallery save status indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: isLarge ? 24 : 20,
                    height: isLarge ? 24 : 20,
                    decoration: BoxDecoration(
                      color: (_galleryStatus[url] == true) 
                        ? Colors.green.withOpacity(0.9)
                        : Colors.amber.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      (_galleryStatus[url] == true) ? Icons.check : Icons.save_alt,
                      size: isLarge ? 14 : 12,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!isImage)
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(isLarge ? 16 : 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: isLarge ? 32 : 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (showExtraCount && extraCount > 0)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+$extraCount',
                            style: const TextStyle(
                              fontFamily: 'Segoe UI',
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'more',
                            style: TextStyle(
                              fontFamily: 'Segoe UI',
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCurrentDownloadsList() async {
    // Load saved downloads and filter to current announcement's videos only.
    final map = await DownloadState.load();
    // Build entries for only downloaded items belonging to this card
    final items = <_DownloadedItem>[];
    for (final v in widget.videos) {
      final url = (v['url'] as String?) ?? (v['message'] as String?) ?? '';
      if (url.isEmpty) continue;
      final local = map[url];
      if (local == null) continue; // show only those downloaded
      
      // Use the path from DownloadState, but verify the file still exists
      final file = File(local);
      if (!await file.exists()) continue; // File no longer exists
      
      final poster = (v['thumbnailUrl'] as String?) ?? ((v['meta'] as Map<String, dynamic>?)?['thumbnailUrl'] as String?);
      final name = Uri.tryParse(url)?.pathSegments.last ?? 'video.mp4';
      items.add(_DownloadedItem(url: url, localPath: local, name: name, poster: poster));
    }

    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No videos saved yet')));
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _R2DownloadedSetPage(items: items),
      ),
    );
  }

  // Clear ONLY cache/temp files, NOT app storage files (for download operations)
  Future<void> _clearDeviceCacheOnly() async {
    try {
      print('🧹 Starting cache-only cleanup (preserving app storage)...');
      
      // Clear external cache directory (system cache)
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final cacheDir = Directory('${extDir.path}/cache');
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          print('📂 Cleared external cache');
        }
      }
      
      // Clear temporary media files (NOT app_videos directory)
      if (extDir != null) {
        final tempVideoDir = Directory('${extDir.path}/temp_videos');
        if (await tempVideoDir.exists()) {
          await tempVideoDir.delete(recursive: true);
          print('🎬 Cleared temp videos');
        }
        
        final tempImageDir = Directory('${extDir.path}/temp_images');
        if (await tempImageDir.exists()) {
          await tempImageDir.delete(recursive: true);
          print('🖼️ Cleared temp images');
        }
      }
      
      print('✅ Cache-only cleanup completed (app storage preserved)');
      
    } catch (e) {
      print('❌ Error during cache-only cleanup: $e');
    }
  }

  // Clear cache AND temp files (more comprehensive cleanup)
  Future<void> _clearDeviceCache() async {
    try {
      print('🧹 Starting comprehensive cache cleanup...');
      
      // Clear external cache directory (system cache)
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final cacheDir = Directory('${extDir.path}/cache');
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          print('📂 Cleared external cache');
        }
      }
      
      // Clear temporary media files
      if (extDir != null) {
        final tempVideoDir = Directory('${extDir.path}/temp_videos');
        if (await tempVideoDir.exists()) {
          await tempVideoDir.delete(recursive: true);
          print('🎬 Cleared temp videos');
        }
        
        final tempImageDir = Directory('${extDir.path}/temp_images');
        if (await tempImageDir.exists()) {
          await tempImageDir.delete(recursive: true);
          print('🖼️ Cleared temp images');
        }
      }
      
      // Clear system temp directory
      final tempDirectory = await getTemporaryDirectory();
      if (await tempDirectory.exists()) {
        final entities = tempDirectory.listSync();
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            // Continue deleting other files even if one fails
            print('Warning: Could not delete ${entity.path}: $e');
          }
        }
        print('🗂️ Cleared system temp directory');
      }
      
      print('✅ Comprehensive cache cleanup completed');
      
    } catch (e) {
      print('❌ Error during comprehensive cache cleanup: $e');
    }
  }
}

class _DownloadedItem {
  final String url;
  final String localPath;  // This will be the priority path (gallery first, then app storage)
  final String name;
  final String? poster;
  _DownloadedItem({required this.url, required this.localPath, required this.name, this.poster});
}

/// Get priority file path: gallery storage first, then app storage fallback
/// This ensures we use gallery files when available, app storage when not
Future<String?> _getPriorityFilePath(String url) async {
  try {
    final fileName = path.basename(url.split('?').first);
    
    // First check gallery directory
    try {
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final String appName = packageInfo.appName.isNotEmpty ? packageInfo.appName : 'SchoolApp';
        
        final String basePath = extDir.path.split('/Android/')[0];
        final galleryFile = File('$basePath/Download/$appName/$fileName');
        
        if (await galleryFile.exists()) {
          print('Priority: Using gallery file: ${galleryFile.path}');
          return galleryFile.path;
        }
      }
    } catch (e) {
      print('Priority: Gallery check failed: $e');
    }
    
    // Fallback to app storage
    final appDir = await getApplicationDocumentsDirectory();
    final appVideosDir = Directory('${appDir.path}/app_videos');
    final appFile = File('${appVideosDir.path}/$fileName');
    
    if (await appFile.exists()) {
      print('Priority: Using app storage file: ${appFile.path}');
      return appFile.path;
    }
    
    print('Priority: No file found for: $fileName');
    return null;
  } catch (e) {
    print('Priority: Error getting file path for $url: $e');
    return null;
  }
}

/// Full screen view of the downloaded videos for a single announcement.
/// Layout rules:
/// - 1 item: full-page tile with poster and central play button
/// - 2 items: two tiles split 50/50 vertically
/// - 3 items: collage: top row 2 tiles, bottom row 1 tile full width
/// - 4 or more: 2-column grid, scrollable
class _R2DownloadedSetPage extends StatefulWidget {
  final List<_DownloadedItem> items;
  const _R2DownloadedSetPage({required this.items});

  @override
  State<_R2DownloadedSetPage> createState() => _R2DownloadedSetPageState();
}

class _R2DownloadedSetPageState extends State<_R2DownloadedSetPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isDownloadingToGallery = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Downloaded Files (${count})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareAllToWhatsApp(),
            tooltip: 'Share all to WhatsApp',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Download to Gallery button at the top
            Container(
              margin: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDownloadingToGallery ? null : () => _downloadAllToGallery(),
                  icon: _isDownloadingToGallery 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.download, color: Colors.white),
                  label: Text(
                    _isDownloadingToGallery ? 'Downloading to Gallery...' : 'Download All to Gallery',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ),
            // Vertical list of media items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: widget.items.map((item) => _verticalListTile(context, item)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(BuildContext context) {
    final count = widget.items.length;
    if (count == 1) {
      return _fullTile(context, widget.items[0]);
    }
    if (count == 2) {
      return Column(
        children: [
          Expanded(child: _fullTile(context, widget.items[0])),
          const SizedBox(height: 4),
          Expanded(child: _fullTile(context, widget.items[1])),
        ],
      );
    }
    if (count == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _fullTile(context, widget.items[0])),
                const SizedBox(width: 4),
                Expanded(child: _fullTile(context, widget.items[1])),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _fullTile(context, widget.items[2])),
        ],
      );
    }
    // 4 or more: grid
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) => _gridTile(context, widget.items[index]),
    );
  }

  Widget _verticalListTile(BuildContext context, _DownloadedItem item) {
    final isImage = _isImageFile(item);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Gap between items
      child: InkWell(
        onTap: () => _openFullViewer(context, item),
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Media with original aspect ratio
              if (isImage)
                Image.file(
                  File(item.localPath),
                  width: double.infinity,
                  fit: BoxFit.fitWidth, // Maintain aspect ratio
                  cacheWidth: 800, // Cache resized version
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.grey),
                      ),
                    );
                  },
                )
              else if (item.poster != null && item.poster!.isNotEmpty)
                _R2PosterImage(
                  url: item.poster!,
                  fit: BoxFit.fitWidth, // Maintain aspect ratio
                )
              else
                Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.videocam, size: 48, color: Colors.grey),
                  ),
                ),
              
              // Play button overlay (only for videos)
              if (!isImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              
              // Media name overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isImageFile(_DownloadedItem item) {
    final extension = item.name.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  Widget _fullTile(BuildContext context, _DownloadedItem item) {
    final isImage = _isImageFile(item);
    
    // Debug print
    if (isImage) {
      print('DISPLAYING LOCAL IMAGE: ${item.localPath}');
    }
    
    return InkWell(
      onTap: () => _openFullViewer(context, item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image/poster - use local file for images, R2 poster for videos
          if (isImage)
            Image.file(
              File(item.localPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('ERROR loading local image: ${item.localPath} - $error');
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image, size: 48, color: Colors.grey),
                  ),
                );
              },
            )
          else if (item.poster != null && item.poster!.isNotEmpty)
            _R2PosterImage(url: item.poster!, fit: BoxFit.cover)  // Use video thumbnail
          else
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.videocam, size: 48, color: Colors.grey),
              ),
            ),
          
          // Play button overlay (only for videos)
          if (!isImage)
            const Center(
              child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
            ),
          
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          
          // Title overlay
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridTile(BuildContext context, _DownloadedItem item) {
    final isImage = _isImageFile(item);
    
    return InkWell(
      onTap: () => _openFullViewer(context, item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image/poster - use local file for images, R2 poster for videos
          if (isImage)
            Image.file(
              File(item.localPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image, size: 32, color: Colors.grey),
                ),
              ),
            )
          else if (item.poster != null && item.poster!.isNotEmpty)
            _R2PosterImage(url: item.poster!, fit: BoxFit.cover)  // Use video thumbnail
          else
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.videocam, size: 32, color: Colors.grey),
              ),
            ),
          
          // Play button overlay (only for videos)
          if (!isImage)
            const Center(
              child: Icon(Icons.play_circle_fill, size: 32, color: Colors.white70),
            ),
          
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          
          // Title overlay
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _openFullViewer(BuildContext context, _DownloadedItem selectedItem) async {
    try {
      // Check file type - videos can play directly, images need gallery permission
      final fileName = selectedItem.name.toLowerCase();
      final isVideo = fileName.endsWith('.mp4') || fileName.endsWith('.mov') || 
                     fileName.endsWith('.3gp') || fileName.endsWith('.mkv') || 
                     fileName.endsWith('.avi') || fileName.endsWith('.webm');

      // For videos, handle both gallery and app storage
      if (isVideo) {
        // If video is in app storage, copy to external cache for native player access
        if (selectedItem.localPath.contains('/app_videos/') || selectedItem.localPath.contains('/app_flutter/')) {
          await _openVideoFromAppStorage(selectedItem);
        } else {
          // Video is in gallery, can open directly
          await OpenFilex.open(selectedItem.localPath);
        }
        return;
      }

      // For images, check if file exists in gallery directory first
      bool isInGallery = false;
      try {
        final Directory? extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final PackageInfo packageInfo = await PackageInfo.fromPlatform();
          final String appName = packageInfo.appName.isNotEmpty ? packageInfo.appName : 'SchoolApp';
          final String basePath = extDir.path.split('/Android/')[0];
          final fileName = path.basename(selectedItem.localPath);
          final galleryFile = File('$basePath/Download/$appName/$fileName');
          isInGallery = await galleryFile.exists();
        }
      } catch (e) {
        print('Error checking gallery file: $e');
      }

      // If image is only in app storage (not in gallery), copy to temp and open
      if (!isInGallery && selectedItem.localPath.contains('/app_videos/')) {
        await _openImageFromAppStorage(selectedItem);
        return;
      }

      // Open file in device's native media player/gallery
      await OpenFilex.open(selectedItem.localPath);
    } catch (e) {
      print('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${selectedItem.name}')),
      );
    }
  }

  Future<void> _openVideoFromAppStorage(_DownloadedItem selectedItem) async {
    try {
      print('Opening video from app storage: ${selectedItem.localPath}');
      
      // Clean old temp files first to save space
      await _cleanupOldTempVideos();
      
      // Create external cache directory for temporary video sharing
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir == null) {
        throw Exception('Cannot access external storage');
      }
      
      final tempDir = Directory('${extDir.path}/temp_videos');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      // Copy video to external cache (accessible by native players)
      final sourceFile = File(selectedItem.localPath);
      final tempFileName = path.basename(selectedItem.localPath);
      final tempFile = File('${tempDir.path}/$tempFileName');
      
      // Clean old temp files first
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      // Copy to accessible location
      await sourceFile.copy(tempFile.path);
      print('Copied video to temp location: ${tempFile.path}');
      
      // Open with native player
      await OpenFilex.open(tempFile.path);
      
      // Clean up after shorter delay to save storage
      Future.delayed(const Duration(minutes: 5), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('Cleaned up temp video file: $tempFileName');
          }
        } catch (e) {
          print('Error cleaning temp file: $e');
        }
      });
      
    } catch (e) {
      print('Error opening video from app storage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play video: ${selectedItem.name}')),
      );
    }
  }

  Future<void> _openImageFromAppStorage(_DownloadedItem selectedItem) async {
    try {
      print('Opening image from app storage: ${selectedItem.localPath}');
      
      // Create external cache directory for temporary image sharing
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir == null) {
        throw Exception('Cannot access external storage');
      }
      
      final tempDir = Directory('${extDir.path}/temp_images');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      // Copy image to external cache (accessible by native image viewers)
      final sourceFile = File(selectedItem.localPath);
      final tempFileName = path.basename(selectedItem.localPath);
      final tempFile = File('${tempDir.path}/$tempFileName');
      
      // Clean old temp file if exists
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      // Copy to accessible location
      await sourceFile.copy(tempFile.path);
      print('Copied image to temp location: ${tempFile.path}');
      
      // Open with native image viewer/gallery
      await OpenFilex.open(tempFile.path);
      
      // Clean up after delay to save storage
      Future.delayed(const Duration(minutes: 10), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('Cleaned up temp image file: $tempFileName');
          }
        } catch (e) {
          print('Error cleaning temp image file: $e');
        }
      });
      
    } catch (e) {
      print('Error opening image from app storage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open image: ${selectedItem.name}')),
      );
    }
  }

  // Clean up old temporary video and image files to prevent storage buildup
  Future<void> _cleanupOldTempVideos() async {
    try {
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir == null) return;
      
      // Clean up temp videos
      final tempVideoDir = Directory('${extDir.path}/temp_videos');
      if (await tempVideoDir.exists()) {
        await _cleanupTempDirectory(tempVideoDir, 'video');
      }
      
      // Clean up temp images
      final tempImageDir = Directory('${extDir.path}/temp_images');
      if (await tempImageDir.exists()) {
        await _cleanupTempDirectory(tempImageDir, 'image');
      }
    } catch (e) {
      print('Error during temp file cleanup: $e');
    }
  }

  Future<void> _cleanupTempDirectory(Directory tempDir, String fileType) async {
    try {
      final List<FileSystemEntity> files = tempDir.listSync();
      final DateTime now = DateTime.now();
      
      for (final file in files) {
        if (file is File) {
          final FileStat stat = await file.stat();
          final Duration age = now.difference(stat.modified);
          
          // Delete files older than 30 minutes
          if (age.inMinutes > 30) {
            await file.delete();
            print('Cleaned up old temp $fileType: ${path.basename(file.path)}');
          }
        }
      }
    } catch (e) {
      print('Error cleaning temp $fileType directory: $e');
    }
  }

  // Manual cleanup method (can be called from settings or when app closes)
  Future<void> clearAllTempVideos() async {
    try {
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir == null) return;
      
      final tempDir = Directory('${extDir.path}/temp_videos');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        print('Cleared all temporary video files');
      }
    } catch (e) {
      print('Error clearing temp videos: $e');
    }
  }

  // Storage diagnostic function to identify what's taking up space
  Future<Map<String, dynamic>> getStorageBreakdown() async {
    Map<String, dynamic> breakdown = {
      'appDocuments': {'size': 0, 'files': 0, 'path': ''},
      'externalCache': {'size': 0, 'files': 0, 'path': ''},
      'tempVideos': {'size': 0, 'files': 0, 'path': ''},
      'downloadedFiles': {'size': 0, 'files': 0, 'types': {}},
      'total': 0,
    };

    try {
      // Check App Documents Directory (private storage)
      final appDir = await getApplicationDocumentsDirectory();
      breakdown['appDocuments']['path'] = appDir.path;
      await _calculateDirectorySize(appDir, breakdown['appDocuments'], breakdown);

      // Check External Cache Directory
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        breakdown['externalCache']['path'] = extDir.path;
        await _calculateDirectorySize(extDir, breakdown['externalCache'], breakdown);

        // Specifically check temp_videos directory
        final tempDir = Directory('${extDir.path}/temp_videos');
        if (await tempDir.exists()) {
          breakdown['tempVideos']['path'] = tempDir.path;
          await _calculateDirectorySize(tempDir, breakdown['tempVideos'], breakdown);
        }
      }

      // Analyze downloaded files by type
      await _analyzeDownloadedFiles(breakdown);

    } catch (e) {
      print('Error calculating storage breakdown: $e');
    }

    return breakdown;
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
      print('Error calculating directory size for ${dir.path}: $e');
    }
  }

  Future<void> _analyzeDownloadedFiles(Map<String, dynamic> breakdown) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/app_videos');
      
      if (await videosDir.exists()) {
        Map<String, dynamic> types = {};
        
        await for (FileSystemEntity entity in videosDir.list()) {
          if (entity is File) {
            String extension = path.extension(entity.path).toLowerCase();
            FileStat stat = await entity.stat();
            
            if (types[extension] == null) {
              types[extension] = {'count': 0, 'size': 0};
            }
            
            types[extension]['count']++;
            types[extension]['size'] += stat.size;
            breakdown['downloadedFiles']['size'] += stat.size;
            breakdown['downloadedFiles']['files']++;
          }
        }
        
        breakdown['downloadedFiles']['types'] = types;
      }
    } catch (e) {
      print('Error analyzing downloaded files: $e');
    }
  }

  // Helper method to format bytes into readable format
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Method to print detailed storage report
  Future<void> printStorageReport() async {
    final breakdown = await getStorageBreakdown();
    
    print('\n=== STORAGE BREAKDOWN REPORT ===');
    print('Total App Storage: ${formatBytes(breakdown['total'])}');
    print('');
    
    print('📁 App Documents (Private): ${formatBytes(breakdown['appDocuments']['size'])}');
    print('   Files: ${breakdown['appDocuments']['files']}');
    print('   Path: ${breakdown['appDocuments']['path']}');
    print('');
    
    print('📁 External Cache: ${formatBytes(breakdown['externalCache']['size'])}');
    print('   Files: ${breakdown['externalCache']['files']}');
    print('   Path: ${breakdown['externalCache']['path']}');
    print('');
    
    print('🎬 Temp Videos: ${formatBytes(breakdown['tempVideos']['size'])}');
    print('   Files: ${breakdown['tempVideos']['files']}');
    print('   Path: ${breakdown['tempVideos']['path']}');
    print('');
    
    print('📥 Downloaded Media: ${formatBytes(breakdown['downloadedFiles']['size'])}');
    print('   Files: ${breakdown['downloadedFiles']['files']}');
    
    Map<String, dynamic> types = breakdown['downloadedFiles']['types'];
    if (types.isNotEmpty) {
      print('   By Type:');
      types.forEach((ext, data) {
        print('   $ext: ${data['count']} files, ${formatBytes(data['size'])}');
      });
    }
    
    print('\n=== END REPORT ===\n');
  }

  void _showPermissionRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gallery Permission Required'),
        content: const Text(
          'To view images, you need to first download them to your gallery. This requires storage permission.\n\nTap "Download All to Gallery" button above to move files to gallery where images can be opened.\n\n(Videos can be played directly from app storage)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAllToGallery();
            },
            child: const Text('Download to Gallery'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAllToGallery() async {
    setState(() {
      _isDownloadingToGallery = true;
    });

    try {
      if (widget.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files to download')),
        );
        return;
      }

      // Request storage permission for gallery access - Google Play compliant
      var status = await Permission.storage.status;
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
      
      bool hasPermission = status.isGranted;
      
      // For Android 13+ (API 33+), use specific media permissions
      if (status.isDenied) {
        var photoStatus = await Permission.photos.status;
        var videoStatus = await Permission.videos.status;
        
        if (photoStatus.isDenied) {
          photoStatus = await Permission.photos.request();
        }
        if (videoStatus.isDenied) {
          videoStatus = await Permission.videos.request();
        }
        
        // Need at least one of the media permissions
        hasPermission = photoStatus.isGranted || videoStatus.isGranted;
      }
      
      // If no permissions granted, show dialog and return
      if (!hasPermission) {
        setState(() {
          _isDownloadingToGallery = false;
        });
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Gallery Permission Required'),
              content: const Text(
                'To save files to your gallery where you can easily share them, please grant storage permission in Settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Settings'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Get gallery directory with permission granted
      Directory? galleryDir;
      try {
        if (Platform.isAndroid) {
          // Get external storage directory and navigate to public Downloads
          final Directory? extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            // Get app name dynamically
            final PackageInfo packageInfo = await PackageInfo.fromPlatform();
            final String appName = packageInfo.appName.isNotEmpty ? packageInfo.appName : 'SchoolApp';
            
            // Get public Downloads directory path
            final String basePath = extDir.path.split('/Android/')[0];
            galleryDir = Directory('$basePath/Download/$appName');
            print('Using public Downloads directory: ${galleryDir.path}');
          } else {
            throw Exception('Cannot access external storage');
          }
        } else {
          galleryDir = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        print('Gallery directory access failed: $e');
        // Close progress dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot access gallery directory'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!await galleryDir.exists()) {
        await galleryDir.create(recursive: true);
      }

      int successCount = 0;
      List<String> newGalleryPaths = [];
      
      for (final item in widget.items) {
        try {
          final sourceFile = File(item.localPath);
          if (await sourceFile.exists()) {
            // Create gallery file path
            final fileName = path.basename(item.localPath);
            final galleryFilePath = '${galleryDir.path}/$fileName';
            final galleryFile = File(galleryFilePath);
            
            // Copy file to gallery location
            await sourceFile.copy(galleryFilePath);
            
            // Verify copy succeeded
            if (await galleryFile.exists()) {
              // Delete from app storage after successful copy
              await sourceFile.delete();
              
              // Update DownloadState with new gallery path
              final saved = await DownloadState.load();
              saved[item.url] = galleryFilePath;
              await DownloadState.save(saved);
              
              // Update the main page's download state too
              if (context.findAncestorStateOfType<_AnnouncementsPageState>() != null) {
                context.findAncestorStateOfType<_AnnouncementsPageState>()!._downloadedFile[item.url] = galleryFilePath;
              }
              
              newGalleryPaths.add(galleryFilePath);
              successCount++;
              print('Moved file from app storage to gallery: $fileName');
            }
          }
        } catch (e) {
          print('Error moving ${item.name} to gallery: $e');
        }
      }

      // Trigger media scanner to make files visible in gallery
      if (Platform.isAndroid && newGalleryPaths.isNotEmpty) {
        try {
          // Use a platform channel or package to trigger media scanner
          print('Triggering media scanner for ${newGalleryPaths.length} files');
        } catch (e) {
          print('Media scanner trigger failed: $e');
        }
      }

      // Show result and update UI
      if (successCount > 0) {
        // Clear device cache for memory saving after successful gallery transfer
        await _clearDeviceCache();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully moved $successCount files to gallery\nDevice cache cleared for memory optimization'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Navigate back since files are now in gallery, not app storage
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isDownloadingToGallery = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No files were moved to gallery'),
            backgroundColor: Colors.orange,
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isDownloadingToGallery = false;
      });
      
      print('Error downloading to gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error downloading files to gallery'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareAllToWhatsApp() async {
    try {
      if (widget.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files to share')),
        );
        return;
      }

      // Create a list of file paths
      final filePaths = widget.items.map((item) => item.localPath).toList();
      print('Sharing ${filePaths.length} files to WhatsApp:');
      for (int i = 0; i < filePaths.length; i++) {
        print('File $i: ${filePaths[i]}');
      }
      
      // Use platform channel to share multiple files to WhatsApp
      const platform = MethodChannel('com.adbsmalltech.adbapp/share');
      await platform.invokeMethod('shareFilesToWhatsApp', {
        'filePaths': filePaths,
        'text': 'Shared from School App - ${widget.items.length} files',
      });

    } catch (e) {
      print('Error sharing files: $e');
      
      // Fallback: Open first file if sharing fails
      if (widget.items.isNotEmpty) {
        try {
          await OpenFilex.open(widget.items.first.localPath);
        } catch (fallbackError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not share or open files')),
          );
        }
      }
    }
  }

  // Clear device cache for memory optimization
  Future<void> _clearDeviceCache() async {
    try {
      print('🧹 Starting comprehensive cache cleanup...');
      
      // Clear external cache directory (system cache)
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final cacheDir = Directory('${extDir.path}/cache');
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          print('📂 Cleared external cache');
        }
      }
      
      // Clear temporary video files
      if (extDir != null) {
        final tempDir = Directory('${extDir.path}/temp_videos');
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
          print('🎬 Cleared temp videos');
        }
      }
      
      // Clear system temp directory
      final tempDirectory = await getTemporaryDirectory();
      if (await tempDirectory.exists()) {
        final entities = tempDirectory.listSync();
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            // Continue deleting other files even if one fails
            print('Warning: Could not delete ${entity.path}: $e');
          }
        }
        print('🗂️ Cleared system temp directory');
      }
      
      print('✅ Comprehensive cache cleanup completed');
      
    } catch (e) {
      print('❌ Error during comprehensive cache cleanup: $e');
    }
  }
}

// In-app media viewer with slide functionality
class _InAppMediaViewer extends StatefulWidget {
  final List<_DownloadedItem> items;
  final int initialIndex;
  
  const _InAppMediaViewer({
    required this.items,
    required this.initialIndex,
  });

  @override
  State<_InAppMediaViewer> createState() => _InAppMediaViewerState();
}

class _InAppMediaViewerState extends State<_InAppMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      // If zoomed in, reset to normal
      _transformationController.value = Matrix4.identity();
    } else {
      // If normal, zoom to 2x
      _transformationController.value = Matrix4.identity()..scale(2.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.items[_currentIndex];
    final isImage = _isImageFile(currentItem);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        title: Text(
          '${_currentIndex + 1} of ${widget.items.length}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Zoom reset button (only show for images)
          if (isImage)
            IconButton(
              icon: const Icon(Icons.zoom_out_map, color: Colors.white),
              onPressed: _resetZoom,
              tooltip: 'Reset zoom',
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            onPressed: () => OpenFilex.open(currentItem.localPath),
            tooltip: 'Open with external app',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Reset zoom when changing pages
          _resetZoom();
        },
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final itemIsImage = _isImageFile(item);
          
          return Container(
            width: double.infinity,
            height: double.infinity,
            child: Column(
              children: [
                // Main media area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Display the actual media file
                        if (itemIsImage)
                          // For images: Native zoom functionality with InteractiveViewer
                          GestureDetector(
                            onDoubleTap: _handleDoubleTap,
                            child: InteractiveViewer(
                              transformationController: _transformationController,
                              minScale: 0.5,
                              maxScale: 5.0,
                              clipBehavior: Clip.none,
                              child: Image.file(
                                File(item.localPath),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 80,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          // For videos: Show poster/thumbnail with play button
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              if (item.poster != null && item.poster!.isNotEmpty)
                                _R2PosterImage(
                                  url: item.poster!,
                                  fit: BoxFit.contain,
                                )
                              else
                                Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(
                                      Icons.videocam,
                                      size: 80,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                              
                              // Play button overlay for videos
                              Center(
                                child: GestureDetector(
                                  onTap: () => OpenFilex.open(item.localPath),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(40),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        
                        // File info overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  itemIsImage ? 'Image File' : 'Video File',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                if (itemIsImage) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Pinch to zoom • Double-tap to zoom 2x',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (widget.items.length > 1) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Swipe left/right to navigate',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: widget.items.length > 1 ? Container(
        color: Colors.black.withOpacity(0.9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconButton(
              onPressed: _currentIndex > 0 ? () => _previousItem() : null,
              icon: const Icon(Icons.skip_previous),
              color: _currentIndex > 0 ? Colors.white : Colors.grey,
            ),
            Expanded(
              child: Text(
                '${_currentIndex + 1} of ${widget.items.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            IconButton(
              onPressed: _currentIndex < widget.items.length - 1 ? () => _nextItem() : null,
              icon: const Icon(Icons.skip_next),
              color: _currentIndex < widget.items.length - 1 ? Colors.white : Colors.grey,
            ),
          ],
        ),
      ) : null,
    );
  }

  void _previousItem() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextItem() {
    if (_currentIndex < widget.items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isImageFile(_DownloadedItem item) {
    final extension = item.name.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }
}

// Grid view for multiple downloaded items
class _R2DownloadedGridPage extends StatelessWidget {
  final List<_DownloadedItem> items;
  const _R2DownloadedGridPage({required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Downloaded Files (${items.length})'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final count = items.length;
    if (count == 2) {
      return Column(
        children: [
          Expanded(child: _fullTile(context, items[0])),
          const SizedBox(height: 4),
          Expanded(child: _fullTile(context, items[1])),
        ],
      );
    }
    if (count == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _fullTile(context, items[0])),
                const SizedBox(width: 4),
                Expanded(child: _fullTile(context, items[1])),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _fullTile(context, items[2])),
        ],
      );
    }
    // 4 or more: grid
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _gridTile(context, items[index]),
    );
  }

  Widget _gridTile(BuildContext context, _DownloadedItem it) {
    return _posterTile(context, it);
  }

  Widget _fullTile(BuildContext context, _DownloadedItem it) {
    return _posterTile(context, it);
  }

  Widget _posterTile(BuildContext context, _DownloadedItem it) {
    final isImage = _isImageFile(it);
    
    return InkWell(
      onTap: () => _openInAppViewer(context, it),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background - use local file for images, R2 poster for videos
          if (isImage)
            Image.file(
              File(it.localPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image, size: 32, color: Colors.grey),
                ),
              ),
            )
          else if (it.poster != null && it.poster!.isNotEmpty)
            _R2PosterImage(url: it.poster!, fit: BoxFit.cover)
          else
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.videocam, size: 32, color: Colors.grey),
              ),
            ),
          
          // Play button overlay (only for videos)
          if (!isImage)
            const Center(
              child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
            ),
          
          // File type indicator
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isImage ? 'IMG' : 'VID',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openInAppViewer(BuildContext context, _DownloadedItem selectedItem) {
    final selectedIndex = items.indexOf(selectedItem);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InAppMediaViewer(
          items: items,
          initialIndex: selectedIndex,
        ),
      ),
    );
  }

  bool _isImageFile(_DownloadedItem item) {
    final extension = item.name.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }
}

class _DownloadIcon extends StatelessWidget {
  final String url;
  final bool small;
  const _DownloadIcon({required this.url, this.small = false});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AnnouncementsPageState>();
    final v = state?._downloadProgress[url];
    final st = state?._dlStatus[url];
    final size = small ? 20.0 : 18.0;
    if (v == null && st == null) {
      return Icon(Icons.download_rounded, size: size, color: small ? null : Colors.white);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CircularProgressIndicator(
          strokeWidth: 2,
          value: v,
          valueColor: small ? null : const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        if (v != null)
          Center(
            child: Text('${(v * 100).round()}%', style: TextStyle(fontSize: small ? 8 : 8, color: small ? null : Colors.white, fontWeight: FontWeight.bold)),
          ),
        if (st == TaskStatus.paused)
          Center(child: Icon(Icons.pause, size: small ? 12 : 12, color: small ? null : Colors.white)),
      ],
    );
  }
}

class _InlineYouTubeDialog extends StatefulWidget {
  final String videoId;
  final String url;
  final bool isShorts;
  const _InlineYouTubeDialog({required this.videoId, required this.url, this.isShorts = false});

  @override
  State<_InlineYouTubeDialog> createState() => _InlineYouTubeDialogState();
}

class _FullScreenYouTubePage extends StatefulWidget {
  final String videoId;
  final String url;
  final bool isShorts;
  final double? aspect; // use original aspect for non-shorts when available
  const _FullScreenYouTubePage({required this.videoId, required this.url, this.isShorts = false, this.aspect});

  @override
  State<_FullScreenYouTubePage> createState() => _FullScreenYouTubePageState();
}

class _FullScreenYouTubePageState extends State<_FullScreenYouTubePage> {
  late YoutubePlayerController _controller;
  late bool _portraitLocked = widget.isShorts;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
    if (widget.isShorts) {
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!widget.isShorts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          try {
            (_controller as dynamic).enterFullScreen();
          } catch (_) {}
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.close();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video layer: Shorts use a full-screen cover fit (like YouTube Shorts),
          // regular videos keep a centered 16:9 player.
          Positioned.fill(
            child: widget.isShorts
                ? ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: 9,
                        height: 16,
                        child: YoutubePlayer(controller: _controller),
                      ),
                    ),
                  )
                : Center(
                    child: AspectRatio(
                      aspectRatio: (widget.aspect != null && widget.aspect! > 0) ? widget.aspect! : 16 / 9,
                      child: YoutubePlayer(controller: _controller),
                    ),
                  ),
          ),
          Positioned(
            top: pad.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: pad.top + 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_portraitLocked ? Icons.screen_lock_rotation : Icons.screen_rotation, color: Colors.white),
                  tooltip: _portraitLocked ? 'Portrait locked' : 'Allow rotate',
                  onPressed: () {
                    setState(() => _portraitLocked = !_portraitLocked);
                    if (_portraitLocked) {
                      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
                    } else {
                      SystemChrome.setPreferredOrientations(const [
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  onPressed: () async => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: SizedBox(height: pad.bottom)),
          ),
        ],
      ),
    );
  }
}

class _InlineYouTubeDialogState extends State<_InlineYouTubeDialog> {
  late final YoutubePlayerController _controller = YoutubePlayerController(
    params: const YoutubePlayerParams(
      showFullscreenButton: true,
      strictRelatedVideos: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.loadVideoById(videoId: widget.videoId);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(0),
      content: AspectRatio(
        aspectRatio: widget.isShorts ? 9 / 16 : 16 / 9,
        child: YoutubePlayer(controller: _controller),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () async => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
          child: const Text('Open in YouTube'),
        ),
      ],
    );
  }
}

class _FullScreenR2VideoPage extends StatefulWidget {
  final String videoId;
  final Map<String, dynamic> videoData;

  const _FullScreenR2VideoPage({
    required this.videoId,
    required this.videoData,
  });

  @override
  State<_FullScreenR2VideoPage> createState() => _FullScreenR2VideoPageState();
}

class _FullScreenR2VideoPageState extends State<_FullScreenR2VideoPage> {
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: R2VideoPlayer(
                videoId: widget.videoId,
                directUrl: widget.videoData['url'],
                showControls: true,
                autoPlay: true,
              ),
            ),
          ),
          Positioned(
            top: pad.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: pad.top + 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.videoData['url'] != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.white),
                    onPressed: () async {
                      final url = widget.videoData['url'] as String;
                      final uri = Uri.parse(url);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
              ],
            ),
          ),
          // Video info overlay
          Positioned(
            bottom: pad.bottom + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.videoData['title'] != null)
                    Text(
                      widget.videoData['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (widget.videoData['description'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.videoData['description'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (widget.videoData['demo'] == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DEMO MODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _R2VideoThumbnail extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final double width;
  final double height;
  final double? aspectRatio;
  final bool isShorts;

  const _R2VideoThumbnail({
    required this.videoData,
    required this.width,
    required this.height,
    this.aspectRatio,
    required this.isShorts,
  });

  @override
  State<_R2VideoThumbnail> createState() => _R2VideoThumbnailState();
}

class _R2VideoThumbnailState extends State<_R2VideoThumbnail> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localFilePath;
  String? _videoSize;
  String? _posterUrl;

  // R2 credentials - loaded from Firebase
  String? _r2AccountId;
  String? _r2AccessKeyId;
  String? _r2SecretAccessKey;
  String? _r2BucketName;

  @override
  void initState() {
    super.initState();
    // Delay heavy operations to improve scroll performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadR2Configuration();
        _checkIfVideoExists();
        _getVideoSize();
        _resolvePoster();
      }
    });
  }

  // Load R2 configuration from Firebase
  Future<void> _loadR2Configuration() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('r2_settings')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _r2AccountId = data['accountId'];
        _r2AccessKeyId = data['accessKeyId'];
        _r2SecretAccessKey = data['secretAccessKey'];
        _r2BucketName = data['bucketName'];
        
        print('R2 Config loaded: Account=${_r2AccountId}, Bucket=${_r2BucketName}');
      } else {
        print('R2 configuration not found in Firebase');
      }
    } catch (e) {
      print('Failed to load R2 configuration: $e');
    }
  }

  Future<void> _checkIfVideoExists() async {
    // Try to get URL from multiple possible fields
    final videoUrl = widget.videoData['url'] as String? ?? 
                     widget.videoData['message'] as String? ?? 
                     '';
    if (videoUrl.isEmpty) return;

    // Use priority path system: gallery first, then app storage fallback
    final priorityPath = await _getPriorityFilePath(videoUrl);
    if (priorityPath != null) {
      setState(() {
        _localFilePath = priorityPath;
      });
    }
  }

  void _resolvePoster() {
    final thumb = (widget.videoData['thumbnailUrl'] as String?)
        ?? ((widget.videoData['meta'] as Map<String, dynamic>?)?['thumbnailUrl'] as String?);
    if (thumb != null && thumb.isNotEmpty) {
      setState(() => _posterUrl = thumb);
    }
  }

  Future<bool> _ensureSharedStorageAccess() async {
    if (!Platform.isAndroid) return true;
    // Prefer Android 13+ scoped media permission for videos
    try {
      final videosStatus = await Permission.videos.status;
      if (videosStatus.isGranted) return true;
      final videosReq = await Permission.videos.request();
      if (videosReq.isGranted) return true;
      if (videosReq.isDenied) {
        final retry = await Permission.videos.request();
        if (retry.isGranted) return true;
      }
      if (videosReq.isPermanentlyDenied) {
        var askAgain = false;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission needed'),
            content: const Text('Please allow access to videos to save downloads to your device.'),
            actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Run without saving')),
              TextButton(
                onPressed: () { askAgain = true; Navigator.of(ctx).pop(); },
                child: const Text('Ask again'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (askAgain) {
          final retry = await Permission.videos.request();
          if (retry.isGranted) return true;
        }
        return false;
      }
    } catch (_) {}

    // Fallback for older Android versions
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;
    final storageReq = await Permission.storage.request();
    if (storageReq.isGranted) return true;
    if (storageReq.isDenied) {
      final retry = await Permission.storage.request();
      if (retry.isGranted) return true;
    }
    if (storageReq.isPermanentlyDenied) {
      var askAgain = false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission needed'),
          content: const Text('Storage permission is required to save downloads to your device.'),
          actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Run without saving')),
            TextButton(
              onPressed: () { askAgain = true; Navigator.of(ctx).pop(); },
              child: const Text('Ask again'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (askAgain) {
        final retry = await Permission.storage.request();
        if (retry.isGranted) return true;
      }
      return false;
    }

    // Optional last resort for Android 11+
    try {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;
      final manageReq = await Permission.manageExternalStorage.request();
      if (manageReq.isGranted) return true;
      if (manageReq.isDenied) {
        final retry = await Permission.manageExternalStorage.request();
        if (retry.isGranted) return true;
      }
      if (manageReq.isPermanentlyDenied) {
        var askAgain = false;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission needed'),
            content: const Text('Allow file management to save downloads to your device.'),
            actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Run without saving')),
              TextButton(
                onPressed: () { askAgain = true; Navigator.of(ctx).pop(); },
                child: const Text('Ask again'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (askAgain) {
          final retry = await Permission.manageExternalStorage.request();
          if (retry.isGranted) return true;
        }
        return false;
      }
    } catch (_) {}

    return false;
  }

  Future<void> _getVideoSize() async {
    // Try to get URL from multiple possible fields
    final videoUrl = widget.videoData['url'] as String? ?? 
                     widget.videoData['message'] as String? ?? 
                     '';
    if (videoUrl.isEmpty) return;

    try {
      final response = await http.head(Uri.parse(videoUrl));
      final contentLength = response.headers['content-length'];
      if (contentLength != null) {
        final bytes = int.parse(contentLength);
        setState(() {
          _videoSize = _formatFileSize(bytes);
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _downloadVideo() async {
    // Try to get URL from multiple possible fields
    final videoUrl = widget.videoData['url'] as String? ?? 
                     widget.videoData['message'] as String? ?? 
                     '';
    
    print('Download video - URL found: $videoUrl');
    print('Download video - videoData: ${widget.videoData}');
    
    if (videoUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video URL is missing')),
        );
      }
      return;
    }

    // Check if R2 credentials are loaded
    if (_r2AccountId == null || _r2AccessKeyId == null || _r2SecretAccessKey == null || _r2BucketName == null) {
      print('Download video - R2 credentials not loaded, retrying...');
      await _loadR2Configuration();
      
      if (_r2AccountId == null || _r2AccessKeyId == null || _r2SecretAccessKey == null || _r2BucketName == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('R2 configuration missing')),
          );
        }
        return;
      }
    }

    // Validate URL format
    Uri? uri;
    try {
      uri = Uri.parse(videoUrl);
      print('Download video - Parsed URI: $uri');
    } catch (e) {
      print('Download video - Invalid URL format: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid video URL format: $e')),
        );
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
    // Request proper media/storage access so user sees the system dialog
      if (Platform.isAndroid) {
        final ok = await _ensureSharedStorageAccess();
        if (!ok) {
      // If not granted, offer streaming playback without downloading
      setState(() { _isDownloading = false; });
      await _playStreamWithoutDownload(videoUrl);
      return;
        }
      }

      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      final fileName = uri.pathSegments.last;
      print('Download video - File name: $fileName');
      final localFile = File('${videosDir.path}/$fileName');

      // Create Minio client for authenticated R2 access
      final minio = Minio(
        endPoint: '${_r2AccountId}.r2.cloudflarestorage.com',
        accessKey: _r2AccessKeyId!,
        secretKey: _r2SecretAccessKey!,
        useSSL: true,
      );

      // Generate presigned URL for download (valid for 1 hour)
      // Extract the file path from the original URL to match R2 storage structure
      final pathSegments = uri.pathSegments;
      final objectKey = pathSegments.join('/'); // This will be "videos/filename.mp4"
      
      final presignedUrl = await minio.presignedGetObject(
        _r2BucketName!,
        objectKey,
        expires: 3600, // 1 hour
      );
      
      print('Download video - Using presigned URL: $presignedUrl');

      // Use WhatsApp-style fast parallel download
      await FastDownloadManager.downloadFileWithProgress(
        url: presignedUrl,
        filePath: localFile.path,
        maxConnections: 4, // 4 parallel connections like WhatsApp
        chunkSize: 512 * 1024, // 512KB chunks for mobile optimization
        onProgress: (progress, downloadedBytes, totalBytes, speed) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
            
            print('FastDownload: ${(progress * 100).toInt()}% '
                  '(${FastDownloadManager.formatBytes(downloadedBytes)}/'
                  '${FastDownloadManager.formatBytes(totalBytes)}) at $speed');
          }
        },
      );
      
      setState(() {
        _isDownloading = false;
        _localFilePath = localFile.path;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video downloaded successfully with parallel connections!')),
        );
      }
      
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      
      print('Download video - Error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _playVideo() async {
    if (_localFilePath != null) {
      await OpenFilex.open(_localFilePath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.videoData['title'] as String? ?? 'Video';
    final description = widget.videoData['description'] as String? ?? '';
    final isDemo = widget.videoData['demo'] == true;
    
    return InkWell(
      onTap: _localFilePath != null ? _playVideo : (_isDownloading ? null : null), // No action on main tap when not downloaded - buttons handle it
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video thumbnail with download/play button
            AspectRatio(
              aspectRatio: widget.aspectRatio ?? (widget.isShorts ? 9 / 16 : 16 / 9),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Stack(
                  children: [
                    // Poster image or fallback placeholder
                    Positioned.fill(
            child: _posterUrl != null && _posterUrl!.isNotEmpty
              ? _R2PosterImage(url: _posterUrl!, fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(
                                  Icons.videocam_outlined,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                    ),
                    // Overlay with download/play button
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                        child: Center(
                          child: _buildActionButton(),
                        ),
                      ),
                    ),
                    // Video size indicator (top right)
                    if (_videoSize != null && _localFilePath == null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _videoSize!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Demo mode indicator
                    if (isDemo)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DEMO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Video info
            if (title.isNotEmpty || description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isDownloading) {
      // Show progress circle with percentage
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: _downloadProgress,
              strokeWidth: 4,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          Text(
            '${(_downloadProgress * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (_localFilePath != null) {
      // Show play button (video downloaded)
      return const Icon(
        Icons.play_circle_fill,
        size: 60,
        color: Colors.white,
        shadows: [
          Shadow(
            offset: Offset(1, 1),
            blurRadius: 3,
            color: Colors.black45,
          ),
        ],
      );
    } else {
      // Show both download and view online buttons (video not downloaded)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Download button
          GestureDetector(
            onTap: _downloadVideo,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download_for_offline,
                    size: 24,
                    color: Colors.white,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Download',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // View Online button
          GestureDetector(
            onTap: () => _playStreamWithoutDownload(widget.videoData['url'] as String),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 24,
                    color: Colors.white,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'View Online',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  Future<void> _playStreamWithoutDownload(String rawUrl) async {
    // Validate and presign if needed, then open a fullscreen in-app player
    try {
      Uri? uri;
      try { uri = Uri.parse(rawUrl); } catch (_) {}
      if (uri == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid video URL')),
          );
        }
        return;
      }

      // Ensure R2 config loaded to presign
      if (_r2AccountId == null || _r2AccessKeyId == null || _r2SecretAccessKey == null || _r2BucketName == null) {
        await _loadR2Configuration();
      }

      String playbackUrl = rawUrl;
      if (_r2AccountId != null && _r2AccessKeyId != null && _r2SecretAccessKey != null && _r2BucketName != null) {
        try {
          final pathSegments = uri.pathSegments;
          final objectKey = pathSegments.join('/');
          final minio = Minio(
            endPoint: '${_r2AccountId}.r2.cloudflarestorage.com',
            accessKey: _r2AccessKeyId!,
            secretKey: _r2SecretAccessKey!,
            useSSL: true,
          );
          final presignedUrl = await minio.presignedGetObject(
            _r2BucketName!,
            objectKey,
            expires: 3600,
          );
          playbackUrl = presignedUrl;
        } catch (_) {
          // Fall back to raw URL if presign fails
        }
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullScreenR2StreamPage(directUrl: playbackUrl),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start streaming playback')),
        );
      }
    }
  }

}

class _FullScreenR2StreamPage extends StatefulWidget {
  final String directUrl;
  const _FullScreenR2StreamPage({required this.directUrl});

  @override
  State<_FullScreenR2StreamPage> createState() => _FullScreenR2StreamPageState();
}

class _FullScreenR2StreamPageState extends State<_FullScreenR2StreamPage> {
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: R2VideoPlayer(
              videoId: '',
              directUrl: widget.directUrl,
              showControls: true,
              autoPlay: true,
              fit: BoxFit.cover, // truly fullscreen with cropping when needed
            ),
          ),
          Positioned(
            top: pad.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: SizedBox(height: pad.bottom)),
          ),
        ],
      ),
    );
  }
}

// New component for handling blurred thumbnails and local high-quality images
class _BuildBlurredThumbnail extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final bool isDownloaded;
  final String originalUrl;

  const _BuildBlurredThumbnail({
    required this.url,
    this.fit = BoxFit.cover,
    required this.isDownloaded,
    required this.originalUrl,
  });

  @override
  State<_BuildBlurredThumbnail> createState() => _BuildBlurredThumbnailState();
}

class _BuildBlurredThumbnailState extends State<_BuildBlurredThumbnail> {
  String? _localThumbnailPath;
  bool _isLoadingLocal = false;

  @override
  void initState() {
    super.initState();
    if (widget.isDownloaded) {
      _loadLocalThumbnail();
    }
  }

  @override
  void didUpdateWidget(_BuildBlurredThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDownloaded && !oldWidget.isDownloaded) {
      _loadLocalThumbnail();
    }
  }

  Future<void> _loadLocalThumbnail() async {
    if (_isLoadingLocal) return;
    setState(() => _isLoadingLocal = true);

    try {
      // Check if we have a local high-quality thumbnail
      final thumbnails = await DownloadState.loadThumbnails();
      final localPath = thumbnails[widget.url];
      
      if (localPath != null && await File(localPath).exists()) {
        if (mounted) {
          setState(() {
            _localThumbnailPath = localPath;
            _isLoadingLocal = false;
          });
        }
        return;
      }

      // If no local thumbnail, try to find downloaded file and generate one
      final downloads = await DownloadState.load();
      final downloadedPath = downloads[widget.originalUrl];
      
      if (downloadedPath != null) {
        // Use priority path system: gallery first, then app storage fallback
        final priorityPath = await _getPriorityFilePath(widget.originalUrl);
        if (priorityPath != null && await File(priorityPath).exists()) {
          // For now, use the existing thumbnail but mark as downloaded
          if (mounted) {
            setState(() => _isLoadingLocal = false);
          }
        }
      }
    } catch (e) {
      print('Error loading local thumbnail: $e');
      if (mounted) {
        setState(() => _isLoadingLocal = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have a local high-quality thumbnail, use it
    if (_localThumbnailPath != null) {
      return Image.file(
        File(_localThumbnailPath!),
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildBlurredNetworkImage();
        },
      );
    }

    // Otherwise show blurred network thumbnail
    return _buildBlurredNetworkImage();
  }

  Widget _buildBlurredNetworkImage() {
    return ImageFiltered(
      imageFilter: widget.isDownloaded 
          ? ImageFilter.blur(sigmaX: 0, sigmaY: 0) // No blur when downloaded
          : ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Very blurred when not downloaded
      child: _R2PosterImage(
        url: widget.url, 
        fit: widget.fit,
      ),
    );
  }
}

class _R2PosterImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  const _R2PosterImage({required this.url, this.fit = BoxFit.cover});

  @override
  State<_R2PosterImage> createState() => _R2PosterImageState();
}

class _R2PosterImageState extends State<_R2PosterImage> {
  String? _resolvedUrl;
  String? _localPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLocalThumbnail();
  }
  
  Future<void> _checkLocalThumbnail() async {
    // Check if this is an image file - if so, use original instead of thumbnail
    final isImageFile = _isImageUrl(widget.url);
    
    // First check if we have a local copy of this thumbnail
    try {
      // Store thumbnail URL to check against in a persistent cache
      final thumbnailUrl = widget.url;
      
      // For image files, skip thumbnail check and go straight to original
      if (isImageFile) {
        print('Image detected, using original: ${widget.url}');
        _presignIfNeeded();
        return;
      }
      
      // Check in memory cache first for better performance (for videos only)
      final cachedThumbnailsPaths = await _getLocalThumbnailsCache();
      final localPath = cachedThumbnailsPaths[thumbnailUrl];
      
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          if (mounted) {
            setState(() {
              _localPath = localPath;
              _isLoading = false;
            });
            print('Using cached thumbnail: $localPath');
            return;
          }
        }
      }
      
      // If not in memory, check the persisted thumbnails
      final thumbnails = await DownloadState.loadThumbnails();
      final persistedPath = thumbnails[thumbnailUrl];
      
      if (persistedPath != null) {
        final file = File(persistedPath);
        if (await file.exists()) {
          if (mounted) {
            // Update the memory cache
            _updateLocalThumbnailCache(thumbnailUrl, persistedPath);
            
            setState(() {
              _localPath = persistedPath;
              _isLoading = false;
            });
            print('Using persisted thumbnail: $persistedPath');
            return;
          }
        }
      }
    } catch (e) {
      print('Error checking local thumbnail: $e');
    }
    
    // If no local copy, proceed with presigning
    _presignIfNeeded();
  }
  
  // In-memory cache for thumbnail paths to avoid frequent disk access
  static final Map<String, String> _thumbnailPathCache = {};
  
  // Check if URL is an image file
  bool _isImageUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.contains('.jpg') || 
           lowercaseUrl.contains('.jpeg') || 
           lowercaseUrl.contains('.png') || 
           lowercaseUrl.contains('.gif') || 
           lowercaseUrl.contains('.webp');
  }
  
  // Get the in-memory cache for thumbnails
  Future<Map<String, String>> _getLocalThumbnailsCache() async {
    return _thumbnailPathCache;
  }
  
  // Update the in-memory cache for thumbnails
  void _updateLocalThumbnailCache(String url, String path) {
    _thumbnailPathCache[url] = path;
  }

  Future<void> _presignIfNeeded() async {
    final raw = widget.url;
    if (raw.contains('X-Amz-Signature') || raw.contains('X-Amz-Algorithm')) {
      setState(() { 
        _resolvedUrl = raw;
        _isLoading = false;
      });
      return;
    }
    Uri? uri;
    try { uri = Uri.parse(raw); } catch (_) {}
    if (uri == null) { 
      setState(() { 
        _resolvedUrl = raw;
        _isLoading = false;
      });
      return;
    }
    if (!uri.host.endsWith('.r2.cloudflarestorage.com')) {
      setState(() { 
        _resolvedUrl = raw;
        _isLoading = false;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('r2_settings').get();
      if (!doc.exists) { 
        setState(() { 
          _resolvedUrl = raw;
          _isLoading = false;
        });
        return;
      }
      final data = doc.data()!;
      final accountId = data['accountId'] as String?;
      final accessKeyId = data['accessKeyId'] as String?;
      final secretKey = data['secretAccessKey'] as String?;
      final bucket = data['bucketName'] as String?;
      if ([accountId, accessKeyId, secretKey, bucket].any((e) => e == null || (e as String).isEmpty)) {
        setState(() {
          _resolvedUrl = raw;
          _isLoading = false;
        });
        return;
      }
      final segs = uri.pathSegments;
      String objectKey;
      if (segs.isNotEmpty && segs.first == bucket) {
        objectKey = segs.skip(1).join('/');
      } else {
        objectKey = segs.join('/');
      }
      final minio = Minio(
        endPoint: '$accountId.r2.cloudflarestorage.com',
        accessKey: accessKeyId!,
        secretKey: secretKey!,
        useSSL: true,
      );
      final signed = await minio.presignedGetObject(bucket!, objectKey, expires: 600);
      if (mounted) {
        setState(() {
          _resolvedUrl = signed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedUrl = raw;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have a local file, use it
    if (_localPath != null) {
      return Image.file(
        File(_localPath!), 
        fit: widget.fit,
        cacheHeight: 300, // Cache the image in memory for better performance
        cacheWidth: 300,
        errorBuilder: (c, e, s) {
          // If local file fails, fall back to network but don't trigger presign right away
          print('Error loading local thumbnail: $e');
          return Container(
            color: Colors.grey[300],
            child: _resolvedUrl != null ? Image.network(
              _resolvedUrl!,
              fit: widget.fit,
              errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
            ) : null,
          );
        }
      );
    }
    
    // If still loading or no URL available yet, show placeholder
    if (_isLoading || _resolvedUrl == null) {
      return Container(color: Colors.grey[300]);
    }
    
    // Otherwise use network image with caching
    return Image.network(
      _resolvedUrl!, 
      fit: widget.fit,
      cacheHeight: 300, // Cache the image in memory for better performance
      cacheWidth: 300,
      errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        } else {
          // Show loading indicator
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / 
                      (loadingProgress.expectedTotalBytes ?? 1)
                    : null,
              ),
            ),
          );
        }
      },
    );
  }
}
