import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class InlineFirebaseVideo extends StatefulWidget {
  final String url;
  final double? aspect; // width/height if known
  final VoidCallback? onExpand;
  final bool autoPlay; // previews are muted by default
  final String? posterUrl; // optional poster to show before init completes
  
  // Download state callbacks
  final bool? isDownloading;
  final bool? isDownloaded;
  final double? downloadProgress;
  final VoidCallback? onDownload;
  final VoidCallback? onDownloadTap;
  final VoidCallback? onDownloadLongPress;

  const InlineFirebaseVideo({
    super.key,
    required this.url,
    this.aspect,
    this.onExpand,
    this.autoPlay = false,
    this.posterUrl,
    this.isDownloading,
    this.isDownloaded,
    this.downloadProgress,
    this.onDownload,
    this.onDownloadTap,
    this.onDownloadLongPress,
  });

  @override
  State<InlineFirebaseVideo> createState() => _InlineFirebaseVideoState();
}

class _InlineFirebaseVideoState extends State<InlineFirebaseVideo> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _playing = false;
  static bool _mutedDefault = true; // sticky across instances
  bool _muted = _mutedDefault;

  @override
  void initState() {
    super.initState();
    // Only initialize video player if already downloaded (WhatsApp behavior)
    if (widget.isDownloaded == true) {
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    if (_c != null) return; // Already initialized
    
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _c!.setVolume(_muted ? 0 : 1);
        if (widget.autoPlay) {
          _c!.play();
          setState(() => _playing = true);
        }
      });
    _c!.addListener(() {
      if (!mounted) return;
      final p = _c!.value.isPlaying;
      if (p != _playing) setState(() => _playing = p);
    });
  }

  @override
  void didUpdateWidget(InlineFirebaseVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Initialize video when download completes
    if (widget.isDownloaded == true && oldWidget.isDownloaded != true) {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_ready || _c == null) return;
    if (_c!.value.isPlaying) {
      _c!.pause();
    } else {
      _c!.play();
    }
  }

  void _toggleMute() {
    if (_c == null) return;
    _muted = !_muted;
    _mutedDefault = _muted;
    _c!.setVolume(_muted ? 0 : 1);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // WhatsApp-like sizing: use available bubble width; cap height to ~60% of screen
    final screen = MediaQuery.of(context).size;
    final maxH = screen.height * 0.6;
  // Prefer the player's reported aspect (respects rotation). Metadata aspect can be wrong for mobile videos.
  final controllerAr = _ready && _c != null ? _c!.value.aspectRatio : null;
  final metaAr = widget.aspect;
  // Decide portrait vs landscape first; if unknown, bias to portrait to avoid tiny letterboxed previews.
  final isPortrait = (controllerAr != null)
    ? controllerAr > 0 && controllerAr < 1.0
    : (metaAr != null)
      ? metaAr < 1.0
      : true; // default portrait until player initializes
  // Use a display aspect for sizing: true landscape uses the real AR, portrait uses 9:16 placeholder for stable layout
  final ar = (controllerAr != null)
    ? controllerAr
    : (metaAr != null && metaAr > 0)
      ? metaAr
      : (isPortrait ? (9 / 16) : (16 / 9));
  final displayAr = isPortrait ? (9 / 16) : (ar > 0 ? ar : (16 / 9));
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : screen.width * 0.75;
        double targetW = maxW;
    double targetH = targetW / (displayAr <= 0 ? (16 / 9) : displayAr);
        if (targetH > maxH) {
          targetH = maxH;
      targetW = targetH * (displayAr <= 0 ? (16 / 9) : displayAr);
        }
        return SizedBox(
          width: math.max(80, targetW),
          height: math.max(80, targetH),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video layer (only show if downloaded and ready)
                Positioned.fill(
                  child: _ready && _c != null && widget.isDownloaded == true
                      ? (isPortrait
                          // Portrait preview: favor cover to avoid huge letterboxing
                          ? FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: 9,
                                height: 16,
                                child: VideoPlayer(_c!),
                              ),
                            )
                          // Landscape/square: render with true aspect
                          : Center(
                              child: AspectRatio(
                                aspectRatio: ar > 0 ? ar : (16 / 9),
                                child: VideoPlayer(_c!),
                              ),
                            ))
                      : (widget.posterUrl != null && widget.posterUrl!.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                // Show poster/thumbnail
                                Image.network(
                                  widget.posterUrl!,
                  fit: isPortrait ? BoxFit.cover : BoxFit.contain,
                                  errorBuilder: (c, e, s) => const ColoredBox(color: Colors.black12),
                                ),
                                // subtle scrim at bottom so overlays are readable
                                const Align(
                                  alignment: Alignment.bottomCenter,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black26],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const ColoredBox(color: Colors.black12)),
                ),

                // Big play icon when paused (only show if video is ready and downloaded)
                if (!_playing && _ready && _c != null && widget.isDownloaded == true && 
                    !(widget.isDownloading == true))
                  const Icon(Icons.play_circle_fill, size: 56, color: Colors.white70),

                // WhatsApp-style download overlay in center (only show when needed)
                if (widget.isDownloading == true || widget.isDownloaded == true || 
                    (widget.onDownloadTap != null && widget.isDownloaded != true))
                  Center(
                    child: GestureDetector(
                      onTap: widget.onDownloadTap,
                      onLongPress: widget.onDownloadLongPress,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: () {
                          if (widget.isDownloaded == true) {
                            return const Icon(Icons.play_arrow_rounded, key: ValueKey('done'), color: Colors.white, size: 36);
                          }
                          // During download: show nothing
                          if (widget.isDownloading == true) {
                            return const SizedBox.shrink(key: ValueKey('downloading'));
                          }
                          // Default: show download button
                          return const Icon(Icons.download_rounded, key: ValueKey('idle'), color: Colors.white70, size: 24);
                        }(),
                      ),
                    ),
                  ),

                // Interaction layer (only for downloaded videos)
                if (widget.isDownloaded == true && _ready && _c != null)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: _togglePlay),
                    ),
                  ),

                // Gradient bottom bar with progress and time (only for downloaded videos)
                if (widget.isDownloaded == true && _ready && _c != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black38],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: _TinyProgressBar(controller: _c!),
                      ),
                    ),
                  ),

                // Bottom-left play/pause button (only for downloaded videos)
                if (widget.isDownloaded == true && _ready && _c != null)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _roundButton(
                      icon: _playing ? Icons.pause : Icons.play_arrow,
                      onTap: _togglePlay,
                    ),
                  ),

                // Top-right controls: mute and expand (only for downloaded videos)
                if (widget.isDownloaded == true && _ready && _c != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _roundButton(
                          icon: _muted ? Icons.volume_off : Icons.volume_up,
                          onTap: _toggleMute,
                        ),
                        if (widget.onExpand != null)
                          const SizedBox(width: 6),
                        if (widget.onExpand != null)
                          _roundButton(icon: Icons.open_in_full, onTap: widget.onExpand!),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _TinyProgressBar extends StatelessWidget {
  final VideoPlayerController controller;
  const _TinyProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final v = controller.value;
    final d = v.duration.inMilliseconds;
    final p = v.position.inMilliseconds;
    final t = (d > 0) ? (p / d).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: t == 0 ? null : t,
          minHeight: 3,
          color: Colors.white,
          backgroundColor: Colors.white24,
        ),
      ],
    );
  }
}
