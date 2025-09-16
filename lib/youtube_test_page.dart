import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';

class YouTubeTestPage extends StatefulWidget {
  const YouTubeTestPage({super.key});

  @override
  State<YouTubeTestPage> createState() => _YouTubeTestPageState();
}

class _YouTubeTestPageState extends State<YouTubeTestPage> {
  final TextEditingController _linkCtrl = TextEditingController();
  final _coll = FirebaseFirestore.instance.collection('youtube_tests');
  String? _lastError;

  // Simple extract: accepts full/watch/short youtu.be links
  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
      if (uri.host.contains('youtube.com')) {
        if (uri.path == '/watch') {
          return uri.queryParameters['v'];
        }
        final segs = uri.pathSegments;
        // e.g., /shorts/<id> or /live/<id>
        if (segs.length >= 2) return segs[1];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveLink() async {
    setState(() => _lastError = null);
    final raw = _linkCtrl.text.trim();
    if (raw.isEmpty) return;
    final id = _extractVideoId(raw);
    if (id == null || id.length < 6) {
      setState(() => _lastError = 'Invalid YouTube link');
      return;
    }
    final url = 'https://youtu.be/$id';
    try {
      await _coll.add({
        'url': url,
        'videoId': id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _linkCtrl.clear();
    } catch (e) {
      setState(() => _lastError = 'Save failed: $e');
    }
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Unlisted – Test')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _linkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Paste YouTube URL (Unlisted)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _saveLink,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
          if (_lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_lastError!, style: const TextStyle(color: Colors.red)),
            ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _coll.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No videos yet'));
                }
        return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
          final doc = docs[i];
          final d = doc.data() as Map<String, dynamic>;
          final id = (d["videoId"] ?? "") as String;
          final url = (d["url"] ?? "") as String;
          return _YouTubeListTile(videoId: id, url: url, docRef: doc.reference);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _YouTubeListTile extends StatefulWidget {
  final String videoId;
  final String url;
  final DocumentReference docRef;
  const _YouTubeListTile({required this.videoId, required this.url, required this.docRef});

  @override
  State<_YouTubeListTile> createState() => _YouTubeListTileState();
}

class _YouTubeListTileState extends State<_YouTubeListTile> {
  late final YoutubePlayerController _controller = YoutubePlayerController(
    params: const YoutubePlayerParams(
      showFullscreenButton: true,
      strictRelatedVideos: true,
  // autoPlay and desktopMode are not available in 5.1.3
    ),
  );

  bool _expanded = false;

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumb = 'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        elevation: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail preview
            AspectRatio(
              aspectRatio: 16 / 9,
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
                  // Play overlay hint
                  if (!_expanded)
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
            ListTile(
              title: Text('https://youtu.be/${widget.videoId}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(widget.url, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_expanded ? Icons.expand_less : Icons.play_circle_fill),
                    onPressed: () {
                      setState(() => _expanded = !_expanded);
                      if (_expanded) {
                        _controller.loadVideoById(videoId: widget.videoId);
                      } else {
                        _controller.stopVideo();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: _openExternally,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (!mounted) return;
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete video link?'),
                          content: const Text('This removes the saved link from Firestore.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      );
            if (ok == true) {
                        try {
                          await widget.docRef.delete();
                        } catch (e) {
              if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            if (_expanded)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: _controller),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
