import 'dart:io';
import 'package:flutter/material.dart';
import 'multi_r2_media_uploader_page.dart' show MediaType;

class SchoolMediaCardWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String senderInfo;
  final String recipientInfo;
  final DateTime timestamp;
  final List<MediaItem> mediaItems;
  final VoidCallback? onDownloadAll;
  final VoidCallback? onOpenGallery;
  final bool isUploadMode;
  final Widget? uploadControls;
  final Widget? progressOverlay;

  const SchoolMediaCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.senderInfo,
    required this.recipientInfo,
    required this.timestamp,
    required this.mediaItems,
    this.onDownloadAll,
    this.onOpenGallery,
    this.isUploadMode = false,
    this.uploadControls,
    this.progressOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 760),
      height: isUploadMode ? 520 : null,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF081432).withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF0B1220).withOpacity(0.04),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: isUploadMode ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // Top section with gradient
              Container(
                height: isUploadMode ? 130 : 100,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8AD7FF), Color(0xFFC6F7E6)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // Logo
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.18),
                                  Colors.white.withOpacity(0.06),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF020617).withOpacity(0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(title),
                                style: const TextStyle(
                                  color: Color(0xFF022039),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Color(0xFF022039),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Color(0xFF022039),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          senderInfo,
                          style: TextStyle(
                            color: const Color(0xFF022039).withOpacity(0.85),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          recipientInfo,
                          style: TextStyle(
                            color: const Color(0xFF022039).withOpacity(0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Divider with date
              Container(
                height: 20,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 10,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF022039).withOpacity(0.06),
                              const Color(0xFF022039).withOpacity(0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF022039).withOpacity(0.03),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF081432).withOpacity(0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            _formatDate(timestamp),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Media area
              if (isUploadMode)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        if (uploadControls != null) ...[
                          uploadControls!,
                          const SizedBox(height: 12),
                        ],
                        Expanded(
                          child: _buildMediaGrid(context),
                        ),
                        const SizedBox(height: 12),
                        _buildBottomCaption(),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _buildMediaGrid(context),
                      const SizedBox(height: 12),
                      _buildBottomCaption(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaGrid(BuildContext context) {
    return Container(
      height: isUploadMode ? null : 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF022039).withOpacity(0.05),
        ),
      ),
      child: Stack(
        children: [
          if (mediaItems.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: const Color(0xFF64748B).withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No media available',
                    style: TextStyle(
                      color: const Color(0xFF64748B).withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                shrinkWrap: !isUploadMode,
                physics: isUploadMode ? null : const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: mediaItems.length > 4 ? 4 : mediaItems.length,
                itemBuilder: (context, i) {
                  final item = mediaItems[i];
                  final isLast = i == 3 && mediaItems.length > 4;
                  
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF020617).withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildMediaContent(item),
                          
                          if (isLast)
                            Container(
                              color: Colors.black.withOpacity(0.56),
                              child: Center(
                                child: Text(
                                  '+${mediaItems.length - 4} more',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),

                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: item.type == MediaType.video 
                                    ? Colors.red.withOpacity(0.8)
                                    : Colors.green.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                item.type == MediaType.video ? Icons.videocam : Icons.photo,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          if (item.progress != null && item.progress! < 1.0)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        value: item.progress,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${((item.progress! * 100).round())}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (item.onRemove != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: item.onRemove,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          if (progressOverlay != null)
            progressOverlay!,

          // Download button for announcement mode
          if (!isUploadMode && mediaItems.isNotEmpty && onDownloadAll != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                child: Container(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: 0.0, // Always hidden, shows on hover in web
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB6F0E0), Color(0xFFBFE0FF)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF04324F).withOpacity(0.12),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: onDownloadAll,
                          icon: const Icon(Icons.download),
                          label: const Text(
                            'Download',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: const Color(0xFF04324F),
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(MediaItem item) {
    if (item.thumbnailPath != null) {
      return Image.file(
        File(item.thumbnailPath!),
        fit: BoxFit.cover,
      );
    } else if (item.url != null) {
      return Image.network(
        item.url!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF64748B).withOpacity(0.1),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: const Color(0xFF64748B),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFF64748B).withOpacity(0.1),
            child: Icon(
              item.type == MediaType.video ? Icons.ondemand_video : Icons.photo,
              size: 32,
              color: const Color(0xFF64748B),
            ),
          );
        },
      );
    } else {
      return Container(
        color: const Color(0xFF64748B).withOpacity(0.1),
        child: Icon(
          item.type == MediaType.video ? Icons.ondemand_video : Icons.photo,
          size: 32,
          color: const Color(0xFF64748B),
        ),
      );
    }
  }

  Widget _buildBottomCaption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            isUploadMode 
                ? 'Select photos & videos to upload to the school announcement system.'
                : 'Photos & media from school announcements. Tap to view full size.',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF64748B).withOpacity(0.8),
            ),
          ),
        ),
        if (mediaItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE6F9F1), Color(0xFFE9F1FF)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF04324F).withOpacity(0.06),
              ),
            ),
            child: GestureDetector(
              onTap: onOpenGallery,
              child: Text(
                isUploadMode 
                    ? '${mediaItems.where((i) => i.type == MediaType.video).length} 🎥 ${mediaItems.where((i) => i.type == MediaType.photo).length} 📷'
                    : 'View Gallery',
                style: const TextStyle(
                  color: Color(0xFF04324F),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getInitials(String text) {
    List<String> words = text.split(' ');
    if (words.isEmpty) return 'SC';
    if (words.length == 1) return words[0].substring(0, 2).toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class MediaItem {
  final MediaType type;
  final String? url;
  final String? thumbnailPath;
  final String? fileName;
  final Duration? duration;
  final String? downloadUrl;
  final double? progress;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  MediaItem({
    required this.type,
    this.url,
    this.thumbnailPath,
    this.fileName,
    this.duration,
    this.downloadUrl,
    this.progress,
    this.onRemove,
    this.onTap,
  });
}
