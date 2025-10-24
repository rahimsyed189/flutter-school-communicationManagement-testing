import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:minio/minio.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:background_downloader/background_downloader.dart';
import 'services/download_service.dart';
import 'youtube_test_page.dart';
import 'youtube_uploader_page.dart';
import 'download_state.dart';
import 'widgets/r2_video_player.dart';

class ChatPage extends StatefulWidget {
  final String userEmail;
  const ChatPage({super.key, required this.userEmail});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Cache of sender->display name
  final Map<String, String> _nameCache = {};
  bool _preferInlinePlayback = false;

  // Download state per URL
  final Map<String, double?> _downloadProgress = {}; // 0.0..1.0, or null for indeterminate
  final Map<String, String> _downloadedFile = {}; // url -> local file path
  final Map<String, DownloadTask> _dlTask = {}; // url -> task
  final Map<String, TaskStatus> _dlStatus = {}; // url -> status

  // Selection mode state (WhatsApp-like)
  bool _selectionActive = false;
  int? _selectedIndex;
  String? _selectedText;
  bool _selectedIsMine = false;
  DocumentReference? _selectedRef;
  OverlayEntry? _reactionsOverlay;

  Future<void> _setReaction(String emoji) async {
    final ref = _selectedRef;
    if (ref == null) return;
    try {
      await ref.update({'reactions.${widget.userEmail}': emoji});
    } catch (e) {
      // If field doesn't exist, set merge
      try {
        await ref.set({'reactions': {widget.userEmail: emoji}}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  void _showReactionsOverlay(Offset globalPosition) {
    _removeReactionsOverlay();
    final overlay = Overlay.of(context);
    if (overlay == null) return;

  final media = MediaQuery.of(context);
  const margin = 12.0;
  const overlayWidth = 208.0; // ~6 emojis x (20 font + padding) + container padding
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

  // Resolve and cache display names for senders (supports email or userId fallback)
  Future<void> _fetchDisplayNamesIfNeeded(Iterable<String> senders) async {
    // Determine which senders we still need
    final missing = senders.where((s) => s.isNotEmpty && !_nameCache.containsKey(s)).toSet();
    if (missing.isEmpty) return;

    // Split into emails vs userIds
    final emails = missing.where((s) => s.contains('@')).toList();
    final userIds = missing.where((s) => !s.contains('@')).toList();

    Future<void> queryChunks(List<String> values, String field) async {
      const int chunkSize = 30; // Firestore whereIn max 30
      for (var i = 0; i < values.length; i += chunkSize) {
        final chunk = values.sublist(i, (i + chunkSize).clamp(0, values.length));
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where(field, whereIn: chunk)
              .get();
          for (final d in snap.docs) {
            final data = d.data();
            final key = (data[field] ?? '').toString();
            final name = (data['name'] ?? '').toString();
            if (key.isNotEmpty) {
              _nameCache[key] = name.isNotEmpty ? name : key;
            }
          }
        } catch (_) {
          // ignore and fallback to showing raw sender
        }
      }
    }

    if (emails.isNotEmpty) await queryChunks(emails, 'email');
    if (userIds.isNotEmpty) await queryChunks(userIds, 'userId');

    if (mounted) setState(() {});
  }

  String _formatDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = that.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return '${that.day.toString().padLeft(2, '0')}/${that.month.toString().padLeft(2, '0')}/${that.year}';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await FirebaseFirestore.instance.collection('chats').add({
      'sender': widget.userEmail,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
      'schoolId': SchoolContext.currentSchoolId,
    });
    _messageController.clear();
  }

  @override
  void initState() {
    super.initState();
    _loadPlaybackPreference();
  _hydrateDownloads();
    _maybeRequestAndroidNotificationPermission();
  }

  Future<void> _maybeRequestAndroidNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        // Only meaningful on Android 13+
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  // Ensure we have permission to save to public Downloads (Android).
  // Shows the system permission dialog if not yet granted.
  Future<bool> _ensureSharedStorageAccess() async {
    if (!Platform.isAndroid) return true;
    // Prefer Android 13+ scoped media permission for videos when available.
    try {
      // This may throw if the plugin version doesn't support it; that's fine.
      final videosStatus = await Permission.videos.status;
      if (videosStatus.isGranted) return true;
      final videosReq = await Permission.videos.request();
      if (videosReq.isGranted) return true;
      if (videosReq.isDenied) {
        // Ask again to show the OS Allow/Deny dialog immediately
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
                onPressed: () {
                  askAgain = true;
                  Navigator.of(ctx).pop();
                },
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

    // Fallback for older Android versions: broad storage permission.
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
              onPressed: () {
                askAgain = true;
                Navigator.of(ctx).pop();
              },
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

    // Optional last resort for apps that truly need broad file access on Android 11+.
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
                onPressed: () {
                  askAgain = true;
                  Navigator.of(ctx).pop();
                },
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
      }
    } catch (_) {}

    return false;
  }

  Future<void> _loadPlaybackPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
  _preferInlinePlayback = prefs.getBool('announcements_prefer_inline') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _togglePlaybackPreference(bool value) async {
    setState(() => _preferInlinePlayback = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('announcements_prefer_inline', value);
    } catch (_) {}
  }

  Future<void> _hydrateDownloads() async {
    final saved = await DownloadState.load();
    if (!mounted) return;
    if (saved.isEmpty) return;
    setState(() {
      _downloadedFile.addAll(saved);
    });
  }

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
        if (uri.pathSegments.length >= 2) return uri.pathSegments[1];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  // Download the video to a temp file and open with the device's default player
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
        // fallback to handing off the URL to external apps
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

  // Stream background download with progress and store local path; do not auto-open.
  Future<void> _startDownload(String url) async {
    if (_downloadedFile.containsKey(url) || _downloadProgress.containsKey(url)) return;
    // Ensure user sees the permission prompt before we begin, so saving to Downloads works.
    if (Platform.isAndroid) {
      final ok = await _ensureSharedStorageAccess();
      if (!ok) {
        // If permission not granted, play the stream without downloading
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _FullScreenStreamPage(url: Uri.parse(url))),
        );
        return;
      }
    }
    final filename = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    // Download to app documents first, then move to public Downloads using shared storage
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
    // Start and listen to updates
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
          // Move to shared Downloads so user can access via Files app on Android
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
          // persist for future sessions
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

  Future<void> _playStreamWithoutDownload(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _FullScreenStreamPage(url: uri)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start streaming playback')),
        );
      }
    }
  }

  Future<void> _togglePauseResume(String url) async {
    final task = _dlTask[url];
    if (task == null) return;
    final status = _dlStatus[url];
    try {
      if (status == TaskStatus.running) {
        await FileDownloader().pause(task);
      } else if (status == TaskStatus.paused) {
        await FileDownloader().resume(task);
      }
    } catch (_) {}
  }

  Future<void> _cancelDownload(String url) async {
    final task = _dlTask[url];
    if (task == null) return;
    try {
      await FileDownloader().cancelTasksWithIds([task.taskId]);
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
    return WillPopScope(
      onWillPop: () async {
        if (_selectionActive) {
          _exitSelection();
          return false;
        }
        return true;
      },
      child: Scaffold(
      appBar: AppBar(
        title: _selectionActive
            ? const Text('1 selected')
            : Text('Chat (${widget.userEmail})'),
        leading: _selectionActive
            ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelection)
            : null,
        actions: [
          if (_selectionActive) ...[
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
            ),
          ] else ...[
            Row(
              children: [
                const Text('Play inline', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _preferInlinePlayback,
                  onChanged: (v) => _togglePlaybackPreference(v),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Video test',
              icon: const Icon(Icons.ondemand_video_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const YouTubeTestPage()),
                );
              },
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
        // Pre-fetch display names for all senders visible
        final allSenders = docs
          .map((d) => (d.data() as Map<String, dynamic>)['sender']?.toString() ?? '')
          .where((s) => s.isNotEmpty);
        _fetchDisplayNamesIfNeeded(allSenders);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });
                final bottomPad = 96.0 + MediaQuery.of(context).padding.bottom;
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(bottom: bottomPad),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final sender = (data['sender'] ?? 'Unknown').toString();
                    final displayName = _nameCache[sender] ?? sender;
                    final message = (data['message'] ?? '').toString();
                    final meta = (data['meta'] as Map<String, dynamic>?) ?? const {};
                    final metaAspect = (meta['aspect'] as num?)?.toDouble();
                    final ts = data['timestamp'];
                    DateTime? time;
                    if (ts is Timestamp) time = ts.toDate();
                    final timeStr = time != null ? TimeOfDay.fromDateTime(time).format(context) : '';
                    final isMine = sender == widget.userEmail;

                    // Day header (like WhatsApp)
                    Widget? dayHeader;
                    if (time != null) {
                      final prevTs = index > 0 ? (docs[index - 1].data() as Map<String, dynamic>)['timestamp'] : null;
                      DateTime? prevTime;
                      if (prevTs is Timestamp) prevTime = prevTs.toDate();
                      final needHeader = prevTime == null ||
                          DateTime(prevTime.year, prevTime.month, prevTime.day) != DateTime(time.year, time.month, time.day);
                      if (needHeader) {
                        dayHeader = Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_formatDay(time), style: const TextStyle(color: Colors.black87, fontSize: 12)),
                          ),
                        );
                      }
                    }

                    final ref = docs[index].reference;
                    final isSelected = _selectionActive && _selectedIndex == index;
                    final reactions = (data['reactions'] as Map<String, dynamic>?) ?? const {};
                    final Map<String, int> reactionCounts = {};
                    reactions.values.forEach((val) {
                      final emo = val?.toString() ?? '';
                      if (emo.isEmpty) return;
                      reactionCounts[emo] = (reactionCounts[emo] ?? 0) + 1;
                    });
          final isYouTube = (data['type'] == 'youtube') || message.contains('youtu');
          final isFirebaseVideo = (data['type'] == 'firebase') && message.startsWith('http');
          final isR2Video = (data['type'] == 'r2');
          final videoId = _extractYouTubeId(message) ?? '';
          final thumb = videoId.isNotEmpty
            ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
            : '';
          final isShort = metaAspect != null
        ? (metaAspect < 1.0)
        : _isShortsUrl(message);
          final effectiveAspect = (metaAspect != null && metaAspect > 0) ? metaAspect : null;
          final posterUrl = (data['thumbnailUrl'] as String?) ?? (meta['thumbnailUrl'] as String?) ?? '';
          final bubble = Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPressStart: (details) {
                          _enterSelection(
                            details: details,
                            isMine: isMine,
                            message: message,
                            ref: ref,
                            index: index,
                          );
                        },
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isMine ? const Color(0xFFA5D6A7) : const Color(0xFFDDDDDD))
                                  : (isMine ? const Color(0xFFD2F8C6) : const Color(0xFFFFFFFF)),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMine ? 16 : 4),
                                bottomRight: Radius.circular(isMine ? 4 : 16),
                              ),
                              boxShadow: const [BoxShadow(blurRadius: 0.3, color: Colors.black12)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isMine)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(displayName, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                  ),
                                if (!isYouTube && !isFirebaseVideo)
                                  SelectableText(
                                    message,
                                    style: const TextStyle(fontSize: 16, height: 1.3),
                                    cursorWidth: 1,
                                  )
                                else ...[
                                  if (isYouTube && thumb.isNotEmpty)
                                    AspectRatio(
                                      aspectRatio: () {
                                        if (metaAspect != null && metaAspect > 0) return metaAspect;
                                        return isShort ? 9 / 16 : 16 / 9;
                                      }(),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Image.network(
                                              thumb,
                                              fit: BoxFit.cover,
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
                  if (isFirebaseVideo && _preferInlinePlayback)
                                    const SizedBox.shrink()
                  else if (isR2Video && _preferInlinePlayback)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                                      child: GestureDetector(
                                        onTap: () async {
                                          final url = data['url'] ?? message;
                                          await _downloadAndOpenWithDevicePlayer(url);
                                        },
                                        child: AspectRatio(
                                          aspectRatio: (effectiveAspect != null && effectiveAspect > 0)
                                              ? effectiveAspect!
                                              : (isShort ? 9 / 16 : 16 / 9),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: (posterUrl.isNotEmpty)
                                                      ? _R2PosterImage(url: posterUrl)
                                                      : Container(color: Colors.grey[300]),
                                                ),
                                                Positioned.fill(
                                                  child: Center(
                                                    child: Container(
                                                      decoration: const BoxDecoration(
                                                        color: Colors.black45,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding: const EdgeInsets.all(8),
                                                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                                    title: Text(
                                      'Video',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                  leading: (posterUrl.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 56,
                          height: 36,
                          child: _R2PosterImage(url: posterUrl, fit: BoxFit.cover),
                        ),
                      )
                    : null,
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
                                                // If already downloaded, open; else start download
                                                final saved = _downloadedFile[message];
                                                if (saved != null) {
                                                  await OpenFilex.open(saved);
                                                } else if (!_downloadProgress.containsKey(message)) {
                                                  await _startDownload(message);
                                                }
                                              } else if (isR2Video) {
                                                // Download (temp) then open with device player
                                                final url = data['url'] ?? message;
                                                await _downloadAndOpenWithDevicePlayer(url);
                                              } else {
                                                await _openExternally(message);
                                              }
                                              return;
                                            }
                                            if (isYouTube) {
                                              if (videoId.isEmpty) {
                                                await _openExternally(message);
                                                return;
                                              }
                                              if (!context.mounted) return;
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (ctx) => _FullScreenYouTubePage(
                                                    videoId: videoId,
                                                    url: message,
                                                    isShorts: isShort,
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
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (ctx) => _FullScreenR2VideoPage(
                                                    videoId: data['id'] ?? '',
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
                                          final saved = _downloadedFile[message];
                                          if (saved != null) {
                                            await OpenFilex.open(saved);
                                          } else if (!_downloadProgress.containsKey(message)) {
                                            await _startDownload(message);
                                          }
                                        } else if (isR2Video) {
                                          // Download (temp) then open with device player
                                          final url = data['url'] ?? message;
                                          await _downloadAndOpenWithDevicePlayer(url);
                                        } else {
                                          await _openExternally(message);
                                        }
                                        return;
                                      }
                                      if (isYouTube) {
                                        if (videoId.isEmpty) {
                                          await _openExternally(message);
                                          return;
                                        }
                                        if (!context.mounted) return;
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (ctx) => _FullScreenYouTubePage(
                                              videoId: videoId,
                                              url: message,
                                              isShorts: isShort,
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
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (ctx) => _FullScreenR2VideoPage(
                                              videoId: data['id'] ?? '',
                                              videoData: data,
                                            ),
                                          ),
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
                                      if (isMine) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.check, size: 14, color: Colors.black45),
                                      ],
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
                                          ]
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    if (dayHeader != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [dayHeader!, bubble],
                      );
                    }
                    return bubble;
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  color: Colors.black54,
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.teal),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  color: Colors.black54,
                  onPressed: () async {
                    // Open YouTube uploader; when it returns a link, send it as a message
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const YouTubeUploaderPage()),
                    );
                    if (result is Map && result['url'] is String) {
                      final url = (result['url'] as String).trim();
                      final rType = (result['type'] as String?) ?? 'youtube';
                      if (url.isNotEmpty) {
                        // Write chat message with aspect metadata so bubbles can render original frame
                        try {
                          final width = (result['width'] as int?) ?? 0;
                          final height = (result['height'] as int?) ?? 0;
                          final durationMs = (result['durationMs'] as int?) ?? 0;
                          await FirebaseFirestore.instance.collection('chats').add({
                            'sender': widget.userEmail,
                            'message': url,
                            'type': rType,
                            'timestamp': FieldValue.serverTimestamp(),
                            'schoolId': SchoolContext.currentSchoolId,
                            'meta': {
                              'width': width,
                              'height': height,
                              'durationMs': durationMs,
                              'aspect': (width > 0 && height > 0) ? (width / height) : null,
                              // pass through thumbnailUrl when available (Firebase path)
                              'thumbnailUrl': (result['thumbnailUrl'] as String?)
                            },
                          });
                        } catch (_) {
                          // fallback if meta write fails
                          _messageController.text = url;
                          await _sendMessage();
                        }
                        // Also auto-post to announcements for visibility
                        try {
                          final videoId = (result['videoId'] as String?)?.trim() ?? '';
                          final title = (result['title'] as String?)?.trim() ?? '';
                          final description = (result['description'] as String?)?.trim() ?? '';
                          final width = (result['width'] as int?) ?? 0;
                          final height = (result['height'] as int?) ?? 0;
                          final durationMs = (result['durationMs'] as int?) ?? 0;
                          final thumb = videoId.isNotEmpty
                              ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
                              : null;
                          await FirebaseFirestore.instance.collection('communications').add({
                            'type': rType,
                            'message': url,
                            'videoId': videoId,
                            'thumbnailUrl': (rType == 'youtube')
                                ? thumb
                                : (result['thumbnailUrl'] as String?),
                            'title': title,
                            'description': description,
                            'meta': {
                              'width': width,
                              'height': height,
                              'durationMs': durationMs,
                              'aspect': (width > 0 && height > 0) ? (width / height) : null,
                              'thumbnailUrl': (result['thumbnailUrl'] as String?)
                            },
                            'senderId': widget.userEmail,
                            'senderRole': 'admin', // Treat chat uploader as admin post if applicable
                            'senderName': widget.userEmail,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                        } catch (_) {}
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.teal,
                  onPressed: _sendMessage,
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
  _removeReactionsOverlay();
    super.dispose();
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
  final double? aspect;
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
    // Orientation policy: Shorts locked to portrait; regular videos allow rotate (no forced rotation)
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
    // Try to auto-enter the player's own fullscreen (same as tapping the square button)
    if (!widget.isShorts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          try {
            // Use dynamic to avoid build-time dependency if method name changes
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
                        fit: BoxFit.cover, // fill screen height, crop sides if needed
                        child: SizedBox(
                          width: 9, // base 9:16 box, scaled by FittedBox
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
            // Reserve bottom safe area so system gesture areas don't hide content
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: SizedBox(height: pad.bottom),
              ),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
                directUrl: (widget.videoData['url'] as String?) ?? (widget.videoData['message'] as String? ?? ''),
                showControls: true,
                autoPlay: true,
                fit: BoxFit.cover,
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

class _R2PosterImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  const _R2PosterImage({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  State<_R2PosterImage> createState() => _R2PosterImageState();
}

class _R2PosterImageState extends State<_R2PosterImage> {
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _presignIfNeeded();
  }

  Future<void> _presignIfNeeded() async {
    final raw = widget.url;
    // If already presigned (has X-Amz-Signature), just use it
    if (raw.contains('X-Amz-Signature') || raw.contains('X-Amz-Algorithm')) {
      setState(() => _resolvedUrl = raw);
      return;
    }

    Uri? uri;
    try { uri = Uri.parse(raw); } catch (_) {}
    if (uri == null) {
      setState(() => _resolvedUrl = raw);
      return;
    }

    // Only presign Cloudflare R2 bucket host
    if (!uri.host.endsWith('.r2.cloudflarestorage.com')) {
      setState(() => _resolvedUrl = raw);
      return;
    }

    try {
      // Load R2 credentials from app_config/r2_settings
      final doc = await cf.FirebaseFirestore.instance.collection('app_config').doc('r2_settings').get();
      if (!doc.exists) {
        setState(() => _resolvedUrl = raw);
        return;
      }
      final data = doc.data()!;
      final accountId = data['accountId'] as String?;
      final accessKeyId = data['accessKeyId'] as String?;
      final secretKey = data['secretAccessKey'] as String?;
      final bucket = data['bucketName'] as String?;
      if ([accountId, accessKeyId, secretKey, bucket].any((e) => e == null || (e as String).isEmpty)) {
        setState(() => _resolvedUrl = raw);
        return;
      }

      // Compute object key from path. If URL is path-style with bucket at first segment, strip it.
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
      if (mounted) setState(() => _resolvedUrl = signed);
    } catch (_) {
      if (mounted) setState(() => _resolvedUrl = raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl;
    if (url == null) {
      return Container(color: Colors.grey[300]);
    }
    return Image.network(
      url,
      fit: widget.fit,
      errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
    );
  }
}

class _FullScreenStreamPage extends StatefulWidget {
  final Uri url;
  const _FullScreenStreamPage({required this.url});

  @override
  State<_FullScreenStreamPage> createState() => _FullScreenStreamPageState();
}

class _FullScreenStreamPageState extends State<_FullScreenStreamPage> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(widget.url)
      ..setLooping(false)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller?.play();
      }).catchError((_) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _ready && _controller != null
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 16,
                        height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 9,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          Positioned(
            top: pad.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (_controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: pad.bottom + 16,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_controller!.value.isPlaying) {
                            _controller!.pause();
                          } else {
                            _controller!.play();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}