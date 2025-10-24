import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:minio/minio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import 'services/background_services_manager.dart';
import 'youtube_uploader_page.dart';
import 'services/school_context.dart';
import 'video_upload_settings_page.dart';
import 'r2_config_page.dart';
import 'gemini_config_page.dart';
import 'firebase_config_page.dart';
import 'dynamic_students_page.dart';
import 'simple_cleanup_notification.dart';
import 'admin_cleanup_page.dart';
import 'server_cleanup_page.dart';
import 'school_notifications_template.dart';
import 'admin_background_image_page.dart';
import 'school_registration_page.dart';
import 'school_registration_wizard_page.dart';
import 'services/dynamic_firebase_options.dart';

// Global singleton to cache background image across page navigations
class BackgroundImageCache {
  static final BackgroundImageCache _instance = BackgroundImageCache._internal();
  factory BackgroundImageCache() => _instance;
  BackgroundImageCache._internal();

  String? cachedImagePath;
  ImageProvider? cachedImageProvider;
  bool isLoaded = false;
}

class AdminHomePage extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole; // 'admin' or 'user'
  const AdminHomePage({Key? key, required this.currentUserId, this.currentUserRole = 'user'}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _bgCache = BackgroundImageCache();
  String? _backgroundImageUrl;
  static String r2AccountId = '';
  static String r2AccessKeyId = '';
  static String r2SecretAccessKey = '';
  static String r2BucketName = '';
  static String r2CustomDomain = '';
  static bool _r2ConfigLoaded = false;
  ImageProvider? _cachedImageProvider; // Cache the image provider
  bool _isLoadingBackground = false; // Start as false - only show loading if needed
  bool _showContent = true; // Start as true - content visible by default
  
  // Gradient colors for fallback background
  Color _gradientColor1 = Colors.white;
  Color _gradientColor2 = Colors.white;
  
  // Image fit option
  BoxFit _imageFit = BoxFit.cover;
  
  // Image opacity
  double _imageOpacity = 0.20;
  
  // Page selection
  String _applyToPage = 'all';

  @override
  void initState() {
    super.initState();
    
    _loadGradientColors(); // Load custom gradient colors
    
    // 🚀 Initialize background services AFTER UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🎯 AdminHomePage: UI rendered, starting background services at ${DateTime.now().toIso8601String()}');
      // Initialize background services in the background (pass context for image cache)
      if (mounted) {
        BackgroundServicesManager().initializeAfterUI(
          currentUserId: widget.currentUserId,
          context: context,
        );
      }
    });
    
    // Load background image AFTER first frame is painted (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if image is already loaded in memory (from previous navigation)
      if (_bgCache.isLoaded && _bgCache.cachedImagePath != null) {
        // Image already in memory - use it immediately
        setState(() {
          _backgroundImageUrl = _bgCache.cachedImagePath;
          _cachedImageProvider = _bgCache.cachedImageProvider;
        });
        debugPrint('✅ Background image loaded from memory cache (instant, no disk read)');
        return;
      }
      
      // Otherwise, load from disk/R2 in background (won't block UI)
      _checkAndLoadBackgroundImage();
      _loadApplyToPage(); // Load page selection setting
      _loadImageFit(); // Load image fit setting
      _loadImageOpacity(); // Load image opacity setting
    });
  }
  
  Future<void> _loadGradientColors() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('background_gradient')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _gradientColor1 = Color(data['color1'] ?? 0xFFFFFFFF);
            _gradientColor2 = Color(data['color2'] ?? 0xFFFFFFFF);
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load gradient colors: $e');
    }
  }

  Future<void> _loadApplyToPage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('background_apply_to')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _applyToPage = doc.data()?['page'] ?? 'all';
        });
      }
    } catch (e) {
      debugPrint('Failed to load apply to page setting: $e');
    }
  }

  Future<void> _loadImageFit() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('background_image_fit')
          .get();
      if (doc.exists) {
        final fitString = doc.data()?['fit'] ?? 'cover';
        if (mounted) {
          setState(() {
            _imageFit = _stringToBoxFit(fitString);
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load image fit: $e');
    }
  }
  
  BoxFit _stringToBoxFit(String fitString) {
    switch (fitString) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'cover':
      default:
        return BoxFit.cover;
    }
  }
  
  Future<void> _loadImageOpacity() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('background_image_opacity')
          .get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _imageOpacity = doc.data()?['opacity'] ?? 0.20;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load image opacity: $e');
    }
  }

  Future<void> _checkAndLoadBackgroundImage() async {
    try {
      // First, check if we have a locally cached image (synchronous check)
      final appDir = await getApplicationDocumentsDirectory();
      final localImagePath = '${appDir.path}/background_image.jpg';
      final localImageFile = File(localImagePath);

      if (localImageFile.existsSync()) {
        // Precache the image for instant display
        _cachedImageProvider = FileImage(localImageFile);
        await precacheImage(_cachedImageProvider!, context);
        
        // Save to memory cache for future navigations
        _bgCache.cachedImagePath = localImageFile.path;
        _bgCache.cachedImageProvider = _cachedImageProvider;
        _bgCache.isLoaded = true;
        
        // Use local cached image - no loading overlay needed
        if (mounted) {
          setState(() {
            _backgroundImageUrl = localImageFile.path;
          });
        }
        debugPrint('✅ Background image loaded from disk cache and saved to memory: $localImagePath');
        return; // Return early - image is cached, no need to download
      }

      // If no cache exists, load in background WITHOUT blocking UI
      // (No loading overlay, just quietly load the image)
      
      await _loadBackgroundImage();
    } catch (e) {
      debugPrint('❌ Error checking cached background: $e');
      // If cache check fails, try downloading
      await _loadBackgroundImage();
    }
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localImagePath = '${appDir.path}/background_image.jpg';
      final localImageFile = File(localImagePath);

      // Load R2 configuration from Firestore
      if (!_r2ConfigLoaded) {
        final doc = await FirebaseFirestore.instance
            .collection('app_config')
            .doc('r2_settings')
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          r2AccountId = data['accountId'] ?? '';
          r2AccessKeyId = data['accessKeyId'] ?? '';
          r2SecretAccessKey = data['secretAccessKey'] ?? '';
          r2BucketName = data['bucketName'] ?? '';
          r2CustomDomain = data['customDomain'] ?? '';
          _r2ConfigLoaded = true;
        }
      }

      // Check if R2 is configured
      if (r2AccountId.isEmpty || r2AccessKeyId.isEmpty || r2SecretAccessKey.isEmpty || r2BucketName.isEmpty) {
        debugPrint('R2 not configured, skipping background image load');
        return;
      }

      // Connect to R2 and list objects in currentPageBackgroundImage folder
      final minio = Minio(
        endPoint: '$r2AccountId.r2.cloudflarestorage.com',
        accessKey: r2AccessKeyId,
        secretKey: r2SecretAccessKey,
        useSSL: true,
      );

      // List objects in the currentPageBackgroundImage folder
      final stream = minio.listObjects(
        r2BucketName,
        prefix: 'currentPageBackgroundImage/',
        recursive: true,
      );

      // Get the first image (most recent upload is typically first)
      String? firstImageKey;
      await for (final listResult in stream) {
        for (final obj in listResult.objects) {
          if (obj.key != null && obj.key!.contains('.')) {
            // Check if it's an image file
            final ext = obj.key!.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
              firstImageKey = obj.key;
              break; // Get first image and stop
            }
          }
        }
        if (firstImageKey != null) break; // Exit outer loop if found
      }

      if (firstImageKey != null) {
        // Get presigned URL from R2 (valid for 1 hour)
        String imageUrl;
        try {
          if (r2CustomDomain.isNotEmpty) {
            // If custom domain is configured, use it directly
            imageUrl = '$r2CustomDomain/$firstImageKey';
          } else {
            // Otherwise, get a presigned URL from R2
            imageUrl = await minio.presignedGetObject(r2BucketName, firstImageKey, expires: 3600);
          }
          
          debugPrint('📥 Downloading background image from R2: $imageUrl');

          // Download the image and save locally
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            await localImageFile.writeAsBytes(response.bodyBytes);
            debugPrint('💾 Background image saved to local storage: $localImagePath');
            
            // Precache and save to memory cache
            _cachedImageProvider = FileImage(localImageFile);
            await precacheImage(_cachedImageProvider!, context);
            _bgCache.cachedImagePath = localImageFile.path;
            _bgCache.cachedImageProvider = _cachedImageProvider;
            _bgCache.isLoaded = true;
            
            // Update background image without loading overlay
            if (mounted) {
              setState(() {
                _backgroundImageUrl = localImageFile.path;
              });
            }
            debugPrint('✅ Background image loaded from R2 and saved to memory cache');
          } else {
            debugPrint('❌ Failed to download image: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('❌ Error downloading background image: $e');
        }
      } else {
        debugPrint('ℹ️ No background image found in R2 currentPageBackgroundImage folder');
      }
    } catch (e) {
      debugPrint('❌ Failed to load background image from R2: $e');
    }
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(d.year, d.month, d.day);
    if (thatDay == today) {
      return TimeOfDay.fromDateTime(d).format(context);
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (thatDay == yesterday) return 'Yesterday';
    return '${thatDay.day.toString().padLeft(2, '0')}/${thatDay.month.toString().padLeft(2, '0')}/${thatDay.year % 100}';
  }

  @override
  Widget build(BuildContext context) {
    Widget pill(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        );

    Widget cardTile({
      required Widget leading,
      required String title,
      required String subtitle,
      String? trailing,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
    }) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: const [BoxShadow(blurRadius: 1, color: Colors.black12)],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (trailing != null && trailing.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  pill(trailing),
                ],
              ],
            ),
          ),
        ),
      );
    }
    // Check if background should be shown on this page
    final showBackground = _applyToPage == 'all' || _applyToPage == 'admin_home';

    return Scaffold(
      body: Stack(
        children: [
          // Full Page Background Image
          if (showBackground && _backgroundImageUrl != null)
            Positioned.fill(
              child: Opacity(
                opacity: _imageOpacity, // Use saved opacity setting
                child: _backgroundImageUrl!.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: _backgroundImageUrl!,
                        fit: _imageFit,
                        memCacheWidth: 1080, // Reduce memory usage
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _gradientColor1,
                                _gradientColor2,
                              ],
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _gradientColor1,
                                _gradientColor2,
                              ],
                            ),
                          ),
                        ),
                      )
                    : Image(
                        image: _cachedImageProvider ?? FileImage(File(_backgroundImageUrl!)),
                        fit: _imageFit,
                        filterQuality: FilterQuality.low, // Faster rendering
                        gaplessPlayback: true, // Smooth transitions
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _gradientColor1,
                                _gradientColor2,
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          // Gradient background if no image
          if (_backgroundImageUrl == null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _gradientColor1,
                      _gradientColor2,
                    ],
                  ),
                ),
              ),
            ),
          // Semi-transparent overlay for better content visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                    Colors.white.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.3, 0.7],
                ),
              ),
            ),
          ),
          // Content (always show but will be blurred when loading)
          Column(
            children: [
              // Custom Header - Compact (no title)
              Container(
                  height: 70, // Reduced from 160
                  child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Settings icon (Right side only)
                            if (widget.currentUserRole == 'admin')
                              IconButton(
                                icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (ctx) => SafeArea(
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        const ListTile(
                                          title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        const Divider(height: 0),
                                        ListTile(
                                          leading: const Icon(Icons.video_settings_outlined),
                                          title: const Text('Video Upload settings'),
                                          subtitle: const Text('Default compression quality'),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            Navigator.of(context).push(
                                              MaterialPageRoute(builder: (_) => const VideoUploadSettingsPage()),
                                            );
                                          },
                                        ),
                                        const Divider(height: 0),
                                        ListTile(
                        leading: const Icon(Icons.group_add),
                        title: const Text('Create Group'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/groups/new', arguments: {'userId': widget.currentUserId});
                        },
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text('Register User'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/admin/addUser', arguments: {'userId': widget.currentUserId});
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_sweep),
                        title: const Text('Device Cleanup'),
                        subtitle: const Text('Manual cleanup & scheduling'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/admin/cleanup', arguments: {'userId': widget.currentUserId});
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.cloud_sync),
                        title: const Text('Server Cleanup'),
                        subtitle: const Text('Automated Firebase & R2 cleanup'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ServerCleanupPage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.class_rounded),
                        title: const Text('Manage Classes'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/admin/manageClasses', arguments: {'userId': widget.currentUserId});
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.menu_book),
                        title: const Text('Manage Subjects'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/admin/manageSubjects', arguments: {'userId': widget.currentUserId});
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: const Text('All Users'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/admin/users', arguments: {'userId': widget.currentUserId});
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.verified_user),
                        title: const Text('Pending Approvals'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/admin/approvals', arguments: {'userId': widget.currentUserId});
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.campaign),
                        title: const Text('Post Announcement'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/admin/post', arguments: {'userId': widget.currentUserId});
                        },
                      ),
                      ExpansionTile(
                        leading: const Icon(Icons.storage_rounded),
                        title: const Text('Media Storage Settings'),
                        subtitle: const Text('Configure video, YouTube, and R2 storage'),
                        children: [
                          ListTile(
                            leading: const Icon(Icons.settings, color: Colors.blueGrey),
                            title: const Text('Video Upload Settings'),
                            subtitle: const Text('Change default compression quality'),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const VideoUploadSettingsPage()),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.video_collection, color: Colors.teal),
                            title: const Text('Upload Video'),
                            subtitle: const Text('Pick and upload a video; returns a sharable link'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const YouTubeUploaderPage()),
                              );
                              if (!mounted) return;
                              if (result is Map && result['url'] is String) {
                                final url = (result['url'] as String).trim();
                                final rType = (result['type'] as String?) ?? 'youtube';
                                final videoId = (result['videoId'] as String?)?.trim() ?? '';
                                final title = (result['title'] as String?)?.trim() ?? '';
                                final description = (result['description'] as String?)?.trim() ?? '';
                                final width = (result['width'] as int?) ?? 0;
                                final height = (result['height'] as int?) ?? 0;
                                final durationMs = (result['durationMs'] as int?) ?? 0;
                                if (url.isNotEmpty) {
                                  // Auto-post to Announcements
                                  try {
                                    final thumb = (rType == 'youtube' && videoId.isNotEmpty)
                                      ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
                                      : (result['thumbnailUrl'] as String?);
                                    await FirebaseFirestore.instance.collection('communications').add({
                                      'schoolId': SchoolContext.currentSchoolId,  // 🔥 ADD schoolId
                                      'type': rType,
                                      'message': url,
                                      'videoId': videoId,
                                      'thumbnailUrl': thumb,
                                      'title': title,
                                      'description': description,
                                      'meta': {
                                        'width': width,
                                        'height': height,
                                        'durationMs': durationMs,
                                        'aspect': (width > 0 && height > 0) ? (width / height) : null,
                                        'thumbnailUrl': thumb,
                                      },
                                      'senderId': widget.currentUserId,
                                      'senderRole': 'admin',
                                      'senderName': 'School Admin',
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Video posted to Announcements')),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Uploaded, but post failed: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.video_library, color: Colors.redAccent),
                            title: const Text('YouTube Config'),
                            subtitle: const Text('Configure YouTube API keys and settings'),
                            onTap: () {
                              Navigator.pop(ctx);
                              // TODO: Implement YouTube config page navigation
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.cloud, color: Colors.indigo),
                            title: const Text('R2 Config'),
                            subtitle: const Text('Configure Cloudflare R2 storage'),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const R2ConfigPage()),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.auto_awesome, color: Colors.purple),
                            title: const Text('Gemini AI Config'),
                            subtitle: const Text('AI-powered dynamic form generation'),
                            trailing: const Icon(Icons.new_releases, color: Colors.purple, size: 16),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const GeminiConfigPage()),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.local_fire_department, color: Colors.orange),
                            title: const Text('Firebase Config'),
                            subtitle: const Text('Configure Firebase API keys for all platforms'),
                            trailing: const Icon(Icons.settings_suggest, color: Colors.orange, size: 16),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const FirebaseConfigPage()),
                              );
                            },
                          ),
                          const Divider(height: 0),
                          ListTile(
                            leading: const Icon(Icons.wallpaper, color: Colors.purple),
                            title: const Text('Background Image'),
                            subtitle: const Text('Set Current Page background image'),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AdminBackgroundImagePage()),
                              ).then((_) {
                                // Reload background after returning from the page
                                _loadBackgroundImage();
                              });
                            },
                          ),
                          const Divider(height: 0),
                          ListTile(
                            leading: const Icon(Icons.photo_library, color: Colors.green),
                            title: const Text('Attach Media'),
                            subtitle: const Text('Upload videos and photos as attachments'),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.pushNamed(
                                context, 
                                '/upload/media', 
                                arguments: {
                                  'userId': widget.currentUserId,
                                  'role': widget.currentUserRole
                                }
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.notifications_active, color: Colors.orange),
                            title: const Text('School Notifications'),
                            subtitle: const Text('Send notifications with media attachments'),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SchoolNotificationsTemplate(
                                    currentUserId: widget.currentUserId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          // Confirm sign out
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: const Text('Sign out?'),
                              content: const Text('You will stop receiving notifications until you log in again.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Sign Out')),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          try {
                            // Disable notifications and unsubscribe topics
                            await NotificationService.instance.disableForUser(widget.currentUserId);
                            await NotificationService.instance.unsubscribeFromUserGroups(widget.currentUserId);
                          } catch (_) {}
                          
                          // 🚀 Clear session with cache (instant logout!)
                          await DynamicFirebaseOptions.clearSession();
                          
                          // Clear session name separately
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('session_name');
                          
                          if (!mounted) return;
                          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
                            if (widget.currentUserRole != 'admin')
                              IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (ctx) => SafeArea(
                                      child: ListView(
                                        shrinkWrap: true,
                                        children: [
                                          const ListTile(
                                            title: Text('Menu', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                          const Divider(height: 0),
                                          ListTile(
                                            leading: const Icon(Icons.logout, color: Colors.redAccent),
                                            title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (dctx) => AlertDialog(
                                                  title: const Text('Sign out?'),
                                                  content: const Text('You will stop receiving notifications until you log in again.'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
                                                    TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Sign Out')),
                                                  ],
                                                ),
                                              );
                                              if (ok != true) return;
                                              try {
                                                await NotificationService.instance.disableForUser(widget.currentUserId);
                                                await NotificationService.instance.unsubscribeFromUserGroups(widget.currentUserId);
                                              } catch (_) {}
                                              
                                              // 🚀 Clear session with cache (instant logout!)
                                              await DynamicFirebaseOptions.clearSession();
                                              
                                              // Clear session name separately
                                              final prefs = await SharedPreferences.getInstance();
                                              await prefs.remove('session_name');
                                              
                                              if (!mounted) return;
                                              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                    ),
                  ),
                ),
              ),
              // Main content area - Simple 2-column grid
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.05,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildFeatureCard(
                          icon: Icons.campaign_outlined,
                          title: 'Announcements',
                          gradientColors: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
                          subtitle: 'Open announcements',
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/announcements',
                            arguments: {
                              'userId': widget.currentUserId,
                              'role': widget.currentUserRole,
                            },
                          ),
                        ),
                        _buildFeatureCard(
                          icon: Icons.groups_outlined,
                          title: 'Group Chats',
                          gradientColors: const [Color(0xFFFF512F), Color(0xFFF09819)],
                          subtitle: 'View your groups',
                          onTap: () {
                            FirebaseFirestore.instance
                                .collection('groups')
                                .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
                                .where('members', arrayContains: widget.currentUserId)
                                .get()
                                .then((snapshot) {
                              if (snapshot.docs.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No groups yet')),
                                );
                              } else {
                                _showGroupsPicker(snapshot.docs);
                              }
                            });
                          },
                        ),
                        _buildFeatureCard(
                          icon: Icons.book_outlined,
                          title: 'Homework',
                          gradientColors: const [Color(0xFFAA076B), Color(0xFF61045F)],
                          subtitle: 'Assign and track',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon!')),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          icon: Icons.check_circle_outline,
                          title: 'Attendance',
                          gradientColors: const [Color(0xFF56AB2F), Color(0xFFA8E063)],
                          subtitle: 'Monitor presence',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon!')),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          icon: Icons.school_outlined,
                          title: 'Exam',
                          gradientColors: const [Color(0xFF7F00FF), Color(0xFFE100FF)],
                          subtitle: 'Manage exams',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon!')),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          icon: Icons.event_busy,
                          title: 'Leaves',
                          gradientColors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
                          subtitle: 'Leave requests',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon!')),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          icon: Icons.payment,
                          title: 'Fees',
                          gradientColors: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                          subtitle: 'Collect fees',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon!')),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          icon: Icons.directions_bus,
                          title: 'Transport',
                          gradientColors: const [Color(0xFF2193B0), Color(0xFF6DD5ED)],
                          subtitle: 'Track routes',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon!')),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          icon: Icons.calendar_today,
                          title: 'Calendar',
                          gradientColors: const [Color(0xFFFF5858), Color(0xFFFFA734)],
                          subtitle: 'Plan events',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon!')),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          icon: Icons.assessment_outlined,
                          title: 'Reports',
                          gradientColors: const [Color(0xFF5433FF), Color(0xFF20BDFF), Color(0xFFA5FECB)],
                          subtitle: 'Analytics',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coming soon!')),
                            );
                          },
                        ),
                        // Students - Admin only
                        if (widget.currentUserRole == 'admin')
                          _buildFeatureCard(
                            icon: Icons.people_outline,
                            title: 'Students',
                            gradientColors: const [Color(0xFF667eea), Color(0xFF764ba2)],
                            subtitle: 'Manage students',
                            onTap: () {
                              Navigator.pushNamed(context, '/students');
                            },
                          ),
                        // AI Students - Admin only (NEW)
                        if (widget.currentUserRole == 'admin')
                          _buildFeatureCard(
                            icon: Icons.auto_awesome,
                            title: 'AI Students',
                            gradientColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                            subtitle: 'Dynamic AI forms',
                            trailing: 'NEW',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const DynamicStudentsPage()),
                              );
                            },
                          ),
                        // Staff - Admin only
                        if (widget.currentUserRole == 'admin')
                          _buildFeatureCard(
                            icon: Icons.badge_outlined,
                            title: 'Staff',
                            gradientColors: const [Color(0xFFf093fb), Color(0xFFf5576c)],
                            subtitle: 'Manage staff',
                            onTap: () {
                              Navigator.pushNamed(context, '/staff');
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          // Add cleanup reminder shortcut with existing workflow
          SimpleCleanupNotification(
            currentUserId: widget.currentUserId,
              currentUserRole: widget.currentUserRole,
              onFullCleanup: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AdminCleanupPage(currentUserId: widget.currentUserId),
                  ),
                );
              },
            ),
          // Loading overlay with blur effect
          if (_isLoadingBackground)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  ),
);
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    String? subtitle,
    String? trailing,
    bool isDisabled = false,
  }) {
    final colors = gradientColors.isNotEmpty ? gradientColors : [Colors.indigo, Colors.blueAccent];
    final gradient = LinearGradient(colors: colors);
    final accentColor = colors.last;
    final inkRadius = BorderRadius.circular(20);

    final cardBody = AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: isDisabled ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: inkRadius,
          border: Border.all(color: accentColor.withOpacity(0.22), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: ShaderMask(
                    shaderCallback: (bounds) => gradient.createShader(bounds),
                    child: Icon(icon, size: 32, color: Colors.white),
                  ),
                ),
                const Spacer(),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trailing,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                subtitle ?? 'Tap to open',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => gradient.createShader(bounds),
                  child: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
                ),
                const SizedBox(width: 4),
                Text(
                  isDisabled ? 'Please wait' : 'Open',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentColor.withOpacity(isDisabled ? 0.4 : 0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return InkWell(
      borderRadius: inkRadius,
      onTap: isDisabled ? null : onTap,
      child: cardBody,
    );
  }

  void _showGroupsPicker(List<QueryDocumentSnapshot<Map<String, dynamic>>> groups) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.groups_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Your groups',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (widget.currentUserRole == 'admin')
                      IconButton(
                        tooltip: 'Create group',
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/groups/new', arguments: {'userId': widget.currentUserId});
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final doc = groups[index];
                    final data = doc.data();
                    final name = (data['name'] ?? 'Group').toString();
                    final subtitle = (data['lastMessage'] ?? '').toString();
                    Timestamp? ts;
                    final rawTs = data['lastTimestamp'];
                    if (rawTs is Timestamp) ts = rawTs;
                    final timeLabel = ts != null ? TimeOfDay.fromDateTime(ts.toDate()).format(context) : '';
                    final admins = ((data['admins'] as List?)?.map((e) => e.toString()).toList()) ?? const <String>[];
                    final canDelete = admins.contains(widget.currentUserId) || data['createdBy'] == widget.currentUserId;

                    return ListTile(
                      leading: _buildGroupAvatar(data),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: subtitle.isNotEmpty ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (timeLabel.isNotEmpty)
                            Text(
                              timeLabel,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          if (canDelete)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteGroup(ctx, doc.id, name),
                              tooltip: 'Delete group for everyone',
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(
                          context,
                          '/groups/chat',
                          arguments: {
                            'groupId': doc.id,
                            'name': name,
                            'userId': widget.currentUserId,
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupAvatar(Map<String, dynamic> data) {
    final photoUrl = (data['photoUrl'] ?? '') as String? ?? '';
    final emoji = (data['iconEmoji'] ?? '') as String? ?? '';
    final name = (data['name'] ?? 'Group') as String? ?? 'Group';

    if (photoUrl.isNotEmpty) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(photoUrl));
    }

    if (emoji.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: Colors.blueGrey.shade100,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.blueGrey.shade300,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _confirmDeleteGroup(BuildContext bottomSheetContext, String groupId, String name) async {
    final confirm = await showDialog<bool>(
      context: bottomSheetContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('Delete "$name" for all members? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      const page = 300;
      DocumentSnapshot? cursor;
      while (true) {
        Query q = groupRef.collection('messages').orderBy('timestamp').limit(page);
        if (cursor != null) {
          q = (q as Query<Map<String, dynamic>>).startAfterDocument(cursor) as Query;
        }
        final snap = await q.get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final m in snap.docs) {
          batch.delete(m.reference);
        }
        await batch.commit();
        cursor = snap.docs.last;
      }
      await groupRef.delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$name" deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}

// Additional helper method for the main page
extension AdminHomePageExtension on _AdminHomePageState {
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required List<Color> gradientColors,
    String? subtitle,
    String? trailing,
    VoidCallback? onTap,
  }) {
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradientColors,
    );
    
    final accentColor = gradientColors.first;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: ShaderMask(
                    shaderCallback: (bounds) => gradient.createShader(bounds),
                    child: Icon(icon, size: 32, color: Colors.white),
                  ),
                ),
                const Spacer(),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trailing,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminSettingsPage extends StatelessWidget {
  final String currentUserId;
  const AdminSettingsPage({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin settings')),
      body: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.app_registration, color: Colors.orange),
              title: const Text('Register School'),
              subtitle: const Text('Create new school Firebase key'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SchoolRegistrationWizardPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Create Group'),
              onTap: () => Navigator.pushNamed(context, '/groups/new', arguments: {'userId': currentUserId}),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Register User'),
              onTap: () => Navigator.pushNamed(context, '/admin/addUser', arguments: {'userId': currentUserId}),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Delete Messages'),
              subtitle: const Text('Daily / Weekly / Monthly / Custom range'),
              onTap: () => Navigator.pushNamed(context, '/admin/cleanup', arguments: {'userId': currentUserId}),
            ),
            ListTile(
              leading: const Icon(Icons.class_rounded),
              title: const Text('Manage Classes'),
              onTap: () => Navigator.pushNamed(context, '/admin/manageClasses', arguments: {'userId': currentUserId}),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Manage Subjects'),
              onTap: () => Navigator.pushNamed(context, '/admin/manageSubjects', arguments: {'userId': currentUserId}),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('All Users'),
              onTap: () => Navigator.pushNamed(context, '/admin/users', arguments: {'userId': currentUserId}),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Pending Approvals'),
              onTap: () => Navigator.pushNamed(context, '/admin/approvals', arguments: {'userId': currentUserId}),
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('Post Announcement'),
              onTap: () => Navigator.pushNamed(context, '/admin/post', arguments: {'userId': currentUserId}),
            ),
            ListTile(
              leading: const Icon(Icons.ondemand_video_outlined),
              title: const Text('Upload Video'),
              subtitle: const Text('Pick and upload a video; returns a sharable link'),
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const YouTubeUploaderPage()),
                );
                if (result is Map && result['url'] is String) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload finished')));
                }
              },
            ),
            const Divider(height: 0, thickness: 2),
            const ListTile(
              title: Text('API Configurations', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            ListTile(
              leading: const Icon(Icons.cloud, color: Colors.blue),
              title: const Text('R2 Config'),
              subtitle: const Text('Cloudflare R2 storage settings'),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const R2ConfigPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.purple),
              title: const Text('Gemini AI Config'),
              subtitle: const Text('AI-powered dynamic form generation'),
              trailing: const Icon(Icons.new_releases, color: Colors.purple, size: 20),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GeminiConfigPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for S-curve background
class SCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF667eea),  // Soft blue
          Color(0xFF764ba2),  // Purple
          Color(0xFF6B73FF),  // Light purple-blue
          Color(0xFF9D50BB),  // Pink-purple
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    
    // Start from top-left
    path.moveTo(0, 0);
    
    // Top edge
    path.lineTo(size.width, 0);
    
    // Right edge with first curve
    path.lineTo(size.width, size.height * 0.3);
    
    // First S-curve (going inward)
    path.quadraticBezierTo(
      size.width * 0.8, size.height * 0.5,
      size.width * 0.7, size.height * 0.7
    );
    
    // Second S-curve (going outward)
    path.quadraticBezierTo(
      size.width * 0.6, size.height * 0.9,
      size.width, size.height
    );
    
    // Bottom edge
    path.lineTo(0, size.height);
    
    // Left edge with curves
    path.quadraticBezierTo(
      size.width * 0.3, size.height * 0.8,
      size.width * 0.4, size.height * 0.6
    );
    
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.4,
      size.width * 0.2, size.height * 0.2
    );
    
    // Back to start
    path.lineTo(0, 0);
    
    canvas.drawPath(path, paint);
    
    // Add subtle shadow/overlay effect
    final shadowPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw some decorative curves
    final decorPath = Path();
    decorPath.moveTo(size.width * 0.1, size.height * 0.3);
    decorPath.quadraticBezierTo(
      size.width * 0.5, size.height * 0.1,
      size.width * 0.9, size.height * 0.4
    );
    
    canvas.drawPath(decorPath, shadowPaint);
    
    decorPath.reset();
    decorPath.moveTo(size.width * 0.2, size.height * 0.6);
    decorPath.quadraticBezierTo(
      size.width * 0.6, size.height * 0.8,
      size.width * 0.8, size.height * 0.5
    );
    
    canvas.drawPath(decorPath, shadowPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
