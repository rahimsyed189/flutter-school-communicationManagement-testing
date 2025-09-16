import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class R2VideoPlayer extends StatefulWidget {
  final String videoId; // Firestore document ID
  final String? directUrl; // Direct R2 URL if available
  final double? width;
  final double? height;
  final bool showControls;
  final bool autoPlay;
  final BoxFit fit; // How to fit video inside its box (fullscreen pages can use cover)

  const R2VideoPlayer({
    super.key,
    required this.videoId,
    this.directUrl,
    this.width,
    this.height,
    this.showControls = true,
    this.autoPlay = false,
    this.fit = BoxFit.contain,
  });

  @override
  State<R2VideoPlayer> createState() => _R2VideoPlayerState();
}

class _R2VideoPlayerState extends State<R2VideoPlayer> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _videoData;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      String videoUrl = widget.directUrl ?? '';
      
      // If no direct URL provided, fetch from Firestore
      if (videoUrl.isEmpty) {
        // Check if videoId is valid before making Firestore call
        if (widget.videoId.isEmpty) {
          setState(() {
            _error = 'Video URL not available';
            _isLoading = false;
          });
          return;
        }
        
        final doc = await FirebaseFirestore.instance
            .collection('videos')
            .doc(widget.videoId)
            .get();
        
        if (!doc.exists) {
          setState(() {
            _error = 'Video not found';
            _isLoading = false;
          });
          return;
        }
        
        _videoData = doc.data();
        videoUrl = _videoData?['url'] ?? '';
        
        if (videoUrl.isEmpty) {
          setState(() {
            _error = 'Video URL not available';
            _isLoading = false;
          });
          return;
        }
      }

  // Check if this is a demo video
  if (_videoData?['demo'] == true) {
        setState(() {
          _error = 'Demo video - URL not accessible';
          _isLoading = false;
        });
        return;
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _controller!.initialize();

      if (widget.autoPlay) {
        await _controller!.play();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load video: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Hide loading spinner/box per UX request
      return const SizedBox.shrink();
    }

    if (_error != null) {
      // Suppress error box per UX request
      return const SizedBox.shrink();
    }

    if (_controller == null || !_controller!.value.isInitialized) {
  // Avoid extra box/text when not initialized
  return const SizedBox.shrink();
    }

    // Build a resizable video using FittedBox so it can truly fill fullscreen parents
    final videoContent = SizedBox(
      width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 16,
      height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 9,
      child: VideoPlayer(_controller!),
    );

    Widget videoPlayer = SizedBox.expand(
      child: FittedBox(
        fit: widget.fit,
        alignment: Alignment.center,
        child: videoContent,
      ),
    );

    if (widget.showControls) {
      videoPlayer = Stack(
        children: [
          videoPlayer,
          Positioned.fill(
            child: VideoControls(controller: _controller!),
          ),
        ],
      );
    }

    final child = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: videoPlayer,
    );

    if (widget.width == null && widget.height == null) {
      // Expand to fill parent when not explicitly sized
      return SizedBox.expand(child: child);
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }
}

class VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoControls({super.key, required this.controller});

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_videoListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Container(
        color: Colors.transparent,
        child: AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Play/Pause button in center
                Expanded(
                  child: Center(
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          if (widget.controller.value.isPlaying) {
                            widget.controller.pause();
                          } else {
                            widget.controller.play();
                          }
                        });
                      },
                      icon: Icon(
                        widget.controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Bottom controls
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(widget.controller.value.position),
                        style: const TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: Slider(
                          value: widget.controller.value.position.inMilliseconds
                              .toDouble(),
                          max: widget.controller.value.duration.inMilliseconds
                              .toDouble(),
                          onChanged: (value) {
                            widget.controller.seekTo(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                          activeColor: Colors.red,
                          inactiveColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      Text(
                        _formatDuration(widget.controller.value.duration),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
