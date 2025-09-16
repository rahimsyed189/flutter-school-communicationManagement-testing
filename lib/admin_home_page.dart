import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'youtube_uploader_page.dart';
import 'video_upload_settings_page.dart';
import 'r2_config_page.dart';
import 'simple_cleanup_notification.dart';
import 'admin_cleanup_page.dart';
import 'server_cleanup_page.dart';
import 'school_notifications_template.dart';

class AdminHomePage extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole; // 'admin' or 'user'
  const AdminHomePage({Key? key, required this.currentUserId, this.currentUserRole = 'user'}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
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
      appBar: AppBar(
        title: const Text('Current Page'),
        actions: [
          if (widget.currentUserRole == 'admin')
            IconButton(
              icon: const Icon(Icons.settings),
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
              icon: const Icon(Icons.more_vert),
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
      body: Column(
        children: [
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
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              // Announcements card on top
        cardTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal.shade400,
                  child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                title: 'Announcements',
                subtitle: subtitle,
                trailing: trailing.isNotEmpty ? trailing : null,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/announcements',
          arguments: {'userId': widget.currentUserId, 'role': widget.currentUserRole},
                ),
              ),

              // Groups list below
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .where('members', arrayContains: widget.currentUserId)
                    .snapshots(),
                builder: (context, snapG) {
                  if (snapG.hasError) return const SizedBox.shrink();
                  final items = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapG.data?.docs ?? const []);
                  items.sort((a, b) {
                    final aTs = a.data()['lastTimestamp'];
                    final bTs = b.data()['lastTimestamp'];
                    Timestamp? aT;
                    Timestamp? bT;
                    if (aTs is Timestamp) aT = aTs;
                    if (bTs is Timestamp) bT = bTs;
                    int cmp;
                    if (aT != null && bT != null) {
                      cmp = bT.compareTo(aT);
                    } else if (aT == null && bT == null) {
                      final aC = a.data()['createdAt'];
                      final bC = b.data()['createdAt'];
                      Timestamp? aCt;
                      Timestamp? bCt;
                      if (aC is Timestamp) aCt = aC;
                      if (bC is Timestamp) bCt = bC;
                      if (aCt != null && bCt != null) {
                        cmp = bCt.compareTo(aCt);
                      } else {
                        cmp = 0;
                      }
                    } else {
                      cmp = (bT != null ? 1 : 0) - (aT != null ? 1 : 0);
                    }
                    return cmp;
                  });
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      ...items.map((d) {
                        final data = d.data();
                        final photoUrl = (data['photoUrl'] ?? '') as String? ?? '';
                        final emoji = (data['iconEmoji'] ?? '') as String? ?? '';
                        final name = (data['name'] ?? 'Group') as String? ?? 'Group';
                        final admins = ((data['admins'] as List?)?.map((e) => e.toString()).toList()) ?? const <String>[];
                        final canDelete = admins.contains(widget.currentUserId) || (data['createdBy'] == widget.currentUserId);
                        Widget avatar;
                        if (photoUrl.isNotEmpty) {
                          avatar = CircleAvatar(radius: 24, backgroundImage: NetworkImage(photoUrl));
                        } else {
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'G';
                          avatar = CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blueGrey.shade300,
                            child: emoji.isNotEmpty ? Text(emoji, style: const TextStyle(fontSize: 18)) : Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          );
                        }
                        String timeText = '';
                        final ts = d['lastTimestamp'];
                        if (ts is Timestamp) {
                          timeText = TimeOfDay.fromDateTime(ts.toDate()).format(context);
                        }
                        return cardTile(
                          leading: avatar,
                          title: name,
                          subtitle: (data['lastMessage'] ?? '') as String? ?? '',
                          trailing: timeText.isNotEmpty ? timeText : null,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/groups/chat',
                            arguments: {
                              'groupId': d.id,
                              'name': name,
                              'userId': widget.currentUserId,
                            },
                          ),
                          onLongPress: () async {
                            if (!canDelete) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only group admin can delete this group')));
                              return;
                            }
                            final confirm = await showDialog<bool>(
                              context: context,
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
                              final groupRef = FirebaseFirestore.instance.collection('groups').doc(d.id);
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
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                              }
                            }
                          },
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ],
          );
        },
            ),
          ),
          // Add cleanup notification at bottom
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
