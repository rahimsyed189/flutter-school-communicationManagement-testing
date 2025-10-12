import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:minio/minio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import 'youtube_uploader_page.dart';
import 'video_upload_settings_page.dart';
import 'r2_config_page.dart';
import 'simple_cleanup_notification.dart';
import 'admin_cleanup_page.dart';
import 'server_cleanup_page.dart';
import 'school_notifications_template.dart';
import 'admin_background_image_page.dart';

class AdminHomePage extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole; // 'admin' or 'user'
  const AdminHomePage({Key? key, required this.currentUserId, this.currentUserRole = 'user'}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  String? _backgroundImageUrl;
  static String r2AccountId = '';
  static String r2AccessKeyId = '';
  static String r2SecretAccessKey = '';
  static String r2BucketName = '';
  static String r2CustomDomain = '';
  static bool _r2ConfigLoaded = false;
  ImageProvider? _cachedImageProvider; // Cache the image provider

  @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      // First, check if we have a locally cached image
      final appDir = await getApplicationDocumentsDirectory();
      final localImagePath = '${appDir.path}/background_image.jpg';
      final localImageFile = File(localImagePath);

      if (localImageFile.existsSync()) {
        // Precache the image for instant display
        _cachedImageProvider = FileImage(localImageFile);
        await precacheImage(_cachedImageProvider!, context);
        
        // Use local cached image
        if (mounted) {
          setState(() {
            _backgroundImageUrl = localImageFile.path;
          });
        }
        debugPrint('✅ Background image loaded from local cache: $localImagePath');
        return; // Return early - no need to fetch from R2 if we have it cached
      }

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
            
            if (mounted) {
              setState(() {
                _backgroundImageUrl = localImageFile.path;
              });
            }
            debugPrint('✅ Background image loaded and cached from R2');
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

    return Scaffold(
      body: Stack(
        children: [
          // Full Page Background Image
          if (_backgroundImageUrl != null)
            Positioned.fill(
              child: _backgroundImageUrl!.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: _backgroundImageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 1080, // Reduce memory usage
                      placeholder: (context, url) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF667eea),
                              Color(0xFF764ba2),
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF667eea),
                              Color(0xFF764ba2),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Image(
                      image: _cachedImageProvider ?? FileImage(File(_backgroundImageUrl!)),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low, // Faster rendering
                      gaplessPlayback: true, // Smooth transitions
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF667eea),
                              Color(0xFF764ba2),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          // Gradient background if no image
          if (_backgroundImageUrl == null)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF667eea),
                      Color(0xFF764ba2),
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
          // Content
          Column(
            children: [
              // Custom Header
              Container(
                height: 160,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row with back button and actions
                        Row(
                          children: [
                            const Spacer(),
                            if (widget.currentUserRole == 'admin')
                              IconButton(
                                icon: const Icon(Icons.settings, color: Colors.white),
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
                          // Clear session
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('session_userId');
                          await prefs.remove('session_role');
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
                                              final prefs = await SharedPreferences.getInstance();
                                              await prefs.remove('session_userId');
                                              await prefs.remove('session_role');
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
                        const Spacer(),
                        // Title
                        const Text(
                          'Current Page',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Main content area
              Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('communications')
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snap) {
                String subtitle = 'Open announcements chat';
                String trailing = '';
                if (snap.hasData && snap.data!.docs.isNotEmpty) {
                  final data = snap.data!.docs.first.data();
                  final msg = (data['message'] ?? data['text'] ?? '').toString();
                  subtitle = msg.isNotEmpty ? msg : subtitle;
                  final ts = data['timestamp'];
                  if (ts is Timestamp) trailing = _formatTime(ts.toDate());
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.05,
                ),
                children: [
                  _buildFeatureCard(
                    icon: Icons.campaign_outlined,
                    title: 'Announcements',
                    gradientColors: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
                    subtitle: subtitle,
                    trailing: trailing.isNotEmpty ? trailing : null,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/announcements',
                      arguments: {
                        'userId': widget.currentUserId,
                        'role': widget.currentUserRole,
                      },
                    ),
                  ),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('groups')
                        .where('members', arrayContains: widget.currentUserId)
                        .snapshots(),
                    builder: (context, groupsSnap) {
                      if (groupsSnap.hasError) {
                        return _buildFeatureCard(
                          icon: Icons.groups_outlined,
                          title: 'Group Chats',
                          gradientColors: const [Color(0xFFFF512F), Color(0xFFF09819)],
                          subtitle: 'Unable to load groups',
                          onTap: () {},
                        );
                      }
                      if (groupsSnap.connectionState == ConnectionState.waiting) {
                        return _buildFeatureCard(
                          icon: Icons.groups_outlined,
                          title: 'Group Chats',
                          gradientColors: const [Color(0xFFFF512F), Color(0xFFF09819)],
                          subtitle: 'Loading groups...',
                          onTap: () {},
                          isDisabled: true,
                        );
                      }

                      final groups = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(groupsSnap.data?.docs ?? const []);
                      if (groups.isNotEmpty) {
                        groups.sort((a, b) {
                          final aTs = a.data()['lastTimestamp'];
                          final bTs = b.data()['lastTimestamp'];
                          Timestamp? aT;
                          Timestamp? bT;
                          if (aTs is Timestamp) aT = aTs;
                          if (bTs is Timestamp) bT = bTs;
                          if (aT != null && bT != null) {
                            return bT.compareTo(aT);
                          }
                          return 0;
                        });
                      }

                      final groupCount = groups.length;
                      final previewName = groupCount > 0 ? (groups.first.data()['name'] ?? 'Group') : 'No groups yet';
                      final subtitleText = groupCount > 0
                          ? 'Latest: ${previewName.toString()}'
                          : 'Create or join a group';

                      return _buildFeatureCard(
                        icon: Icons.groups_outlined,
                        title: 'Group Chats',
                        gradientColors: const [Color(0xFFFF512F), Color(0xFFF09819)],
                        subtitle: subtitleText,
                        trailing: groupCount > 0 ? '$groupCount active' : null,
                        onTap: () {
                          if (groupCount == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No groups yet. Create one from settings.')),
                            );
                          } else {
                            _showGroupsPicker(groups);
                          }
                        },
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.book_outlined,
                    title: 'Homework',
                    gradientColors: const [Color(0xFFAA076B), Color(0xFF61045F)],
                    subtitle: 'Assign and track homework',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Homework module - Coming soon!')),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.check_circle_outline,
                    title: 'Attendance',
                    gradientColors: const [Color(0xFF56AB2F), Color(0xFFA8E063)],
                    subtitle: 'Monitor daily presence',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Attendance module - Coming soon!')),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.school_outlined,
                    title: 'Exam',
                    gradientColors: const [Color(0xFF7F00FF), Color(0xFFE100FF)],
                    subtitle: 'Schedule and manage exams',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Exam module - Coming soon!')),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.event_busy,
                    title: 'Leaves',
                    gradientColors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
                    subtitle: 'Review leave requests',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Leaves module - Coming soon!')),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.payment,
                    title: 'Fees',
                    gradientColors: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                    subtitle: 'Collect and reconcile fees',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fees module - Coming soon!')),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.directions_bus,
                    title: 'Transport',
                    gradientColors: const [Color(0xFF2193B0), Color(0xFF6DD5ED)],
                    subtitle: 'Track routes & buses',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transport module - Coming soon!')),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.calendar_today,
                    title: 'Calendar',
                    gradientColors: const [Color(0xFFFF5858), Color(0xFFFFA734)],
                    subtitle: 'Plan events & PTMs',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Calendar module - Coming soon!')),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.assessment_outlined,
                    title: 'Reports',
                    gradientColors: const [Color(0xFF5433FF), Color(0xFF20BDFF), Color(0xFFA5FECB)],
                    subtitle: 'Insights & analytics',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reports module - Coming soon!')),
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
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
              color: accentColor.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
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
              color: accentColor.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
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
