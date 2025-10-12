import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minio/minio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:dotted_border/dotted_border.dart';
import 'school_media_card_widget.dart';

// Template styles for media display
enum MediaTemplateStyle {
  school,    // Blue to green gradient (default)
  business,  // Dark professional theme
  modern,    // Purple to pink gradient
}

class MultiR2MediaUploaderPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;
  const MultiR2MediaUploaderPage({super.key, required this.currentUserId, required this.currentUserRole});

  @override
  State<MultiR2MediaUploaderPage> createState() => _MultiR2MediaUploaderPageState();
}

class _MultiR2MediaUploaderPageState extends State<MultiR2MediaUploaderPage> {
  // R2 config
  String _accountId = '';
  String _accessKeyId = '';
  String _secretAccessKey = '';
  String _bucketName = '';
  String _customDomain = '';

  bool _loadingCfg = true;
  bool _uploading = false;
  String? _status;
  double _overallProgress = 0.0; // 0..1 across all files
  final List<_PickedItem> _items = [];
  UploadQuality _quality = UploadQuality.medium; // default medium; can be overridden by admin settings
  MediaTemplateStyle _selectedTemplate = MediaTemplateStyle.school; // default template

  @override
  void initState() {
    super.initState();
    _loadR2Configuration();
  }

  Future<void> _loadR2Configuration() async {
    try {
      // Only load R2 config for usage, not for editing or UI here
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('r2_settings').get();
      if (doc.exists) {
        final d = doc.data()!;
        _accountId = d['accountId'] ?? '';
        _accessKeyId = d['accessKeyId'] ?? '';
        _secretAccessKey = d['secretAccessKey'] ?? '';
        _bucketName = d['bucketName'] ?? '';
        _customDomain = d['customDomain'] ?? '';
      }
      // Load default quality from upload settings (admin configurable)
      try {
        final up = await FirebaseFirestore.instance.collection('app_config').doc('upload_settings').get();
        if (up.exists) {
          final q = (up.data()!['defaultVideoQuality'] as String?)?.toLowerCase();
          switch (q) {
            case 'low': _quality = UploadQuality.low; break;
            case 'high': _quality = UploadQuality.high; break;
            case 'original': _quality = UploadQuality.original; break;
            case 'medium':
            default:
              _quality = UploadQuality.medium;
          }
        }
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _loadingCfg = false);
  }

  Future<void> _pickMedia() async {
    try {
      // Check current permission status
      var storageStatus = await Permission.storage.status;
      var photoStatus = await Permission.photos.status;
      var videoStatus = await Permission.videos.status;
      
      // If permissions are not granted, show info dialog first
      if (storageStatus.isDenied || (photoStatus.isDenied && videoStatus.isDenied)) {
        // Show permission explanation dialog
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Media Access Permission'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To select photos and videos from your device, this app needs access to your media files.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This permission is used only to:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('• Select photos and videos for uploading'),
                  Text('• Create thumbnails for preview'),
                  Text('• Process media files for announcements'),
                  SizedBox(height: 12),
                  Text(
                    'Your files remain private and secure.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Grant Permission'),
                ),
              ],
            );
          },
        );
        
        if (shouldProceed != true) {
          return; // User cancelled
        }
      }
      
      // Request storage permission first
      if (storageStatus.isDenied) {
        storageStatus = await Permission.storage.request();
      }
      
      // For Android 13+ (API 33+), use specific media permissions
      if (storageStatus.isDenied) {
        if (photoStatus.isDenied) {
          photoStatus = await Permission.photos.request();
        }
        if (videoStatus.isDenied) {
          videoStatus = await Permission.videos.request();
        }
        
        if (photoStatus.isDenied && videoStatus.isDenied) {
          if (mounted) {
            // Show more detailed error message with settings option
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Permission Required'),
                    ],
                  ),
                  content: const Text(
                    'Media access permission is required to select files. '
                    'You can grant this permission in your device settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        openAppSettings(); // Open app settings
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                );
              },
            );
          }
          return;
        }
      }
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        withData: false,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', '3gp', 'mkv'],
      );
      if (result == null || result.files.isEmpty) return;

      final added = <_PickedItem>[];
      for (final f in result.files) {
        if (f.path == null || f.path!.isEmpty) continue;
        
        // Determine if it's a video or photo based on extension
        final ext = path.extension(f.path!).toLowerCase();
        final isVideo = ['mp4', 'mov', '3gp', 'mkv'].contains(ext.replaceAll('.', ''));
        
        if (isVideo) {
          // Process as video
          int? w;
          int? h;
          Duration? dur;
          try {
            final info = await VideoCompress.getMediaInfo(f.path!);
            if (info.width != null && info.height != null) { w = info.width; h = info.height; }
            if (info.duration != null) { dur = Duration(milliseconds: info.duration!.round()); }
          } catch (_) {}
          
          // Try to create a thumbnail for preview - improved quality
          String? thumbPath;
          try {
            final thumb = await VideoCompress.getFileThumbnail(f.path!, quality: 50, position: 1000);
            thumbPath = thumb.path;
          } catch (_) {}
          
          added.add(_PickedItem(
            file: f, 
            width: w, 
            height: h, 
            duration: dur, 
            thumbPath: thumbPath,
            mediaType: MediaType.video
          ));
        } else {
          // Process as photo - create very low quality thumbnail
          String? thumbPath;
          try {
            // Create a very small, low quality thumbnail for images
            thumbPath = await _createLowQualityImageThumbnail(f.path!);
          } catch (_) {
            // Fallback to original image if compression fails
            thumbPath = f.path;
          }
          
          added.add(_PickedItem(
            file: f,
            thumbPath: thumbPath ?? f.path!, // Use compressed thumbnail or fallback
            mediaType: MediaType.photo
          ));
        }
      }
      
      if (!mounted) return;
      setState(() => _items.addAll(added));
      
      // Give feedback about what was added
      final videoCount = added.where((item) => item.mediaType == MediaType.video).length;
      final photoCount = added.where((item) => item.mediaType == MediaType.photo).length;
      
      String message = '';
      if (videoCount > 0 && photoCount > 0) {
        message = 'Added $videoCount videos and $photoCount photos';
      } else if (videoCount > 0) {
        message = 'Added $videoCount videos';
      } else if (photoCount > 0) {
        message = 'Added $photoCount photos';
      }
      
      if (message.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking media: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _isConfigured => _accountId.isNotEmpty && _accessKeyId.isNotEmpty && _secretAccessKey.isNotEmpty && _bucketName.isNotEmpty;

  Future<void> _startUpload() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick at least one file')));
      return;
    }
    if (!_isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloudflare R2 not configured')));
      return;
    }

    setState(() { _uploading = true; _status = 'Uploading…'; _overallProgress = 0.0; });
    await WakelockPlus.enable();

    final minio = Minio(
      endPoint: '$_accountId.r2.cloudflarestorage.com',
      accessKey: _accessKeyId,
      secretKey: _secretAccessKey,
      useSSL: true,
    );

    final uploaded = <Map<String, dynamic>>[];

    try {
      // Upload concurrently (WhatsApp-like responsiveness)
      const maxConcurrentUploads = 3;
      int completed = 0;

      Future<void> uploadOne(int idx) async {
        final it = _items[idx];
        // mark uploading
        _items[idx] = _items[idx].copyWith(uploading: true, failed: false);
        if (mounted) setState(() {});
        
        String srcPath = it.file.path!;
        File? tempCompressed;
        
        // Handle based on media type
        if (it.mediaType == MediaType.video) {
          // Optional compression for videos based on selected quality
          if (_quality != UploadQuality.original) {
            try {
              final q = _mapQuality(_quality);
              final res = await VideoCompress.compressVideo(
                srcPath,
                quality: q,
                includeAudio: true,
              );
              if (res != null && res.path != null) {
                srcPath = res.path!;
                tempCompressed = File(srcPath);
              }
            } catch (_) {}
          }
        }

        final fileRef = File(srcPath);
        final size = await fileRef.length();
        const chunkSize = 512 * 1024; // larger chunks for fewer syscalls
        final stream = fileRef.openRead(0, size).transform(
          StreamTransformer.fromHandlers(handleData: (List<int> chunk, EventSink<Uint8List> sink) {
            if (chunk.length <= chunkSize) {
              sink.add(Uint8List.fromList(chunk));
            } else {
              for (int i = 0; i < chunk.length; i += chunkSize) {
                final end = (i + chunkSize < chunk.length) ? i + chunkSize : chunk.length;
                sink.add(Uint8List.fromList(chunk.sublist(i, end)));
              }
            }
          }),
        );

        final ts = DateTime.now().millisecondsSinceEpoch;
        final name = _sanitizeUploadName(_items[idx].file.name);
        
        // Choose appropriate folder based on media type
        final folderPath = it.mediaType == MediaType.video ? 'videos' : 'images';
        final fileName = '$folderPath/${ts}_$name';

        int sent = 0;
        await minio.putObject(
          _bucketName,
          fileName,
          stream,
          size: size,
          onProgress: (int b) {
            if (b >= sent) { sent = b; } else { sent += b; }
            final per = size > 0 ? (sent / size) : 0.0;
            _items[idx] = _items[idx].copyWith(progress: per);
            final agg = _items.map((e) => e.progress ?? 0.0).fold<double>(0.0, (a, b) => a + b) / _items.length;
            if (mounted) setState(() { _overallProgress = agg; _status = 'Uploading ${completed}/${_items.length}…'; });
          },
        );

        // Thumbnail handling (only needed for videos if we don't already have one)
        String? thumbUrl;
        if (it.mediaType == MediaType.video) {
          try {
            final thumbPath = it.thumbPath ?? '';
            if (thumbPath.isEmpty) {
              // Generate thumbnail if we don't have one - improved quality for better viewing
              final thumb = await VideoCompress.getFileThumbnail(srcPath, quality: 50, position: 1000);
              final thumbKey = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '.jpg');
              await minio.putObject(
                _bucketName,
                thumbKey,
                thumb.openRead().map((c) => Uint8List.fromList(c)),
                size: await thumb.length(),
              );
              thumbUrl = _customDomain.isNotEmpty
                  ? '$_customDomain/$thumbKey'
                  : 'https://$_accountId.r2.cloudflarestorage.com/$thumbKey';
            } else {
              // Use existing thumbnail
              final thumbFile = File(thumbPath);
              final thumbKey = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '.jpg');
              await minio.putObject(
                _bucketName,
                thumbKey,
                thumbFile.openRead().map((c) => Uint8List.fromList(c)),
                size: await thumbFile.length(),
              );
              thumbUrl = _customDomain.isNotEmpty
                  ? '$_customDomain/$thumbKey'
                  : 'https://$_accountId.r2.cloudflarestorage.com/$thumbKey';
            }
          } catch (_) {}
        } else if (it.mediaType == MediaType.photo) {
          // For photos, create and upload a very low quality thumbnail
          try {
            final lowQualityThumbPath = await _createLowQualityImageThumbnail(srcPath);
            if (lowQualityThumbPath != null) {
              final thumbKey = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '_thumb.jpg');
              final thumbFile = File(lowQualityThumbPath);
              await minio.putObject(
                _bucketName,
                thumbKey,
                thumbFile.openRead().map((c) => Uint8List.fromList(c)),
                size: await thumbFile.length(),
              );
              thumbUrl = _customDomain.isNotEmpty
                  ? '$_customDomain/$thumbKey'
                  : 'https://$_accountId.r2.cloudflarestorage.com/$thumbKey';
              
              // Clean up temporary thumbnail file
              try {
                await thumbFile.delete();
              } catch (_) {}
            } else {
              // Fallback to using the main image as thumbnail
              thumbUrl = _customDomain.isNotEmpty
                  ? '$_customDomain/$fileName'
                  : 'https://$_accountId.r2.cloudflarestorage.com/$fileName';
            }
          } catch (_) {
            // Fallback to using the main image as thumbnail
            thumbUrl = _customDomain.isNotEmpty
                ? '$_customDomain/$fileName'
                : 'https://$_accountId.r2.cloudflarestorage.com/$fileName';
          }
        }

        final publicUrl = _customDomain.isNotEmpty
            ? '$_customDomain/$fileName'
            : 'https://$_accountId.r2.cloudflarestorage.com/$fileName';

        final mediaMetadata = {
          'type': it.mediaType == MediaType.video ? 'r2-video' : 'r2-image',
          'url': publicUrl,
          if (thumbUrl != null) 'thumbnailUrl': thumbUrl,
          'width': it.width,
          'height': it.height,
          if (it.mediaType == MediaType.video) 'durationMs': it.duration?.inMilliseconds,
          'fileName': fileName,
          'bucket': _bucketName,
        };
        
        uploaded.add(mediaMetadata);

        // Cleanup temp compressed file if created
        try { if (tempCompressed != null && await tempCompressed.exists()) await tempCompressed.delete(); } catch (_) {}
        completed += 1;
        // mark done
        _items[idx] = _items[idx].copyWith(uploading: false, progress: 1.0);
        if (mounted) setState(() { _status = 'Uploading ${completed}/${_items.length}…'; });
      }

      // concurrency pool
      int idx = 0;
      Future<void> worker() async {
        while (true) {
          final my = idx;
          idx++;
          if (my >= _items.length) break;
          await uploadOne(my);
        }
      }
      await Future.wait(List.generate(maxConcurrentUploads, (_) => worker()));

      // Determine the document type based on what was uploaded
      final bool hasVideos = _items.any((item) => item.mediaType == MediaType.video);
      final bool hasPhotos = _items.any((item) => item.mediaType == MediaType.photo);
      
      String docType = 'r2-multi';
      if (hasVideos && !hasPhotos) {
        docType = 'r2-multi-video';
      } else if (!hasVideos && hasPhotos) {
        docType = 'r2-multi-image';
      } else {
        docType = 'r2-multi-media'; // mixed content
      }

      // Save an announcement document that groups all media files
      final doc = {
        'type': 'r2-multi', // Use the standard r2-multi type for backward compatibility
        'videos': uploaded, // Use 'videos' field for compatibility
        'media': uploaded,  // Keep 'media' field for future use
        'templateStyle': _selectedTemplate.name, // Store template style
        'senderId': widget.currentUserId,
        'senderRole': widget.currentUserRole,
        'senderName': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('communications').add(doc);

      if (!mounted) return;
      setState(() { _status = 'All files uploaded and announcement posted'; _uploading = false; });
      Navigator.of(context).pop(true);

    } catch (e) {
      if (!mounted) return;
      // Mark any still-uploading items as failed
      for (int i = 0; i < _items.length; i++) {
        if (_items[i].uploading == true && (_items[i].progress ?? 0) < 1.0) {
          _items[i] = _items[i].copyWith(uploading: false, failed: true);
        }
      }
      setState(() { _status = 'Upload failed: $e'; _uploading = false; });
    } finally {
      await WakelockPlus.disable();
    }
  }

  // Helper methods for template properties
  String _getTemplateName(MediaTemplateStyle style) {
    switch (style) {
      case MediaTemplateStyle.school:
        return 'School Theme';
      case MediaTemplateStyle.business:
        return 'Business Theme';
      case MediaTemplateStyle.modern:
        return 'Modern Theme';
    }
  }

  List<Color> _getTemplateGradient(MediaTemplateStyle style) {
    switch (style) {
      case MediaTemplateStyle.school:
        return [const Color(0xFF8AD7FF), const Color(0xFFC6F7E6)];
      case MediaTemplateStyle.business:
        return [const Color(0xFF1E293B), const Color(0xFF334155)];
      case MediaTemplateStyle.modern:
        return [const Color(0xFF8B5CF6), const Color(0xFFEC4899)];
    }
  }

  Color _getTemplateAccent(MediaTemplateStyle style) {
    switch (style) {
      case MediaTemplateStyle.school:
        return const Color(0xFF022039);
      case MediaTemplateStyle.business:
        return const Color(0xFF64748B);
      case MediaTemplateStyle.modern:
        return const Color(0xFFF472B6);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convert _PickedItem to MediaItem
    final mediaItems = _items.map((item) => MediaItem(
      type: item.mediaType,
      thumbnailPath: item.thumbPath,
      fileName: item.file.name,
      duration: item.duration,
      progress: item.progress,
      onRemove: _uploading ? null : () {
        setState(() => _items.remove(item));
      },
    )).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('School Media Center'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: DottedBorder(
              color: Colors.blue.withOpacity(0.5),
              strokeWidth: 2,
              dashPattern: const [8, 4],
              borderType: BorderType.RRect,
              radius: const Radius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Empty state - Show upload icon and text
                    if (_items.isEmpty) ...[
                      // Upload Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          size: 80,
                          color: Colors.blue.shade400,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Title
                      Text(
                        'Upload Media Files',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Subtitle
                      Text(
                        'Select photos and videos to share',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                    
                    // Media Grid - Show when items selected
                    if (_items.isNotEmpty) ...[
                      // Media Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Stack(
                            children: [
                              // Thumbnail Container
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: item.failed == true
                                        ? Colors.red[300]!
                                        : item.uploading == true
                                            ? Colors.blue[300]!
                                            : Colors.grey[300]!,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: item.thumbPath != null
                                      ? Image.file(
                                          File(item.thumbPath!),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        )
                                      : Container(
                                          color: Colors.grey[100],
                                          child: Icon(
                                            item.mediaType == MediaType.video
                                                ? Icons.videocam
                                                : Icons.image,
                                            size: 40,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                ),
                              ),
                              
                              // Media Type Badge
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.mediaType == MediaType.video
                                        ? Colors.red[600]!.withOpacity(0.9)
                                        : Colors.green[600]!.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item.mediaType == MediaType.video
                                            ? Icons.play_circle_outline
                                            : Icons.image,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      if (item.duration != null) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDuration(item.duration!),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Remove Button
                              if (!_uploading)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _items.removeAt(index));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ),
                              
                              // Progress Overlay
                              if (item.uploading == true && item.progress != null)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: CircularProgressIndicator(
                                              value: item.progress,
                                              color: Colors.white,
                                              strokeWidth: 3,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${(item.progress! * 100).toInt()}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              
                              // Failed State
                              if (item.failed == true)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Failed',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                    
                    // Video Quality Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quality:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<UploadQuality>(
                              value: _quality,
                              onChanged: _uploading ? null : (q) => setState(() => _quality = q ?? UploadQuality.medium),
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              items: const [
                                DropdownMenuItem(value: UploadQuality.low, child: Text('Low')),
                                DropdownMenuItem(value: UploadQuality.medium, child: Text('Medium')),
                                DropdownMenuItem(value: UploadQuality.high, child: Text('High')),
                                DropdownMenuItem(value: UploadQuality.original, child: Text('Original')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Select/Upload Buttons
                    if (_items.isEmpty)
                      // Select Media Button (Empty state)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _uploading ? null : _pickMedia,
                          icon: const Icon(Icons.add_photo_alternate, size: 24),
                          label: const Text(
                            'Select Media Files',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      )
                    else
                      // Action Buttons Row (When items selected)
                      Row(
                        children: [
                          // Add More Icon Button
                          IconButton(
                            onPressed: _uploading ? null : _pickMedia,
                            icon: const Icon(Icons.add_circle_outline),
                            iconSize: 40,
                            color: Colors.blue[600],
                            tooltip: 'Add More Media',
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Upload All Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _uploading || _items.isEmpty ? null : _startUpload,
                              icon: const Icon(Icons.cloud_upload, size: 22),
                              label: const Text(
                                'Upload All',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    
                    // Supported formats (only in empty state)
                    if (_items.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Supports: JPG, PNG, GIF, MP4, MOV',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class _PickedItem {
  final PlatformFile file;
  final int? width;
  final int? height;
  final Duration? duration;
  final double? progress;
  final String? thumbPath;
  final bool? failed;
  final bool? uploading;
  final MediaType mediaType;

  _PickedItem({
    required this.file, 
    this.width, 
    this.height, 
    this.duration, 
    this.progress, 
    this.thumbPath, 
    this.failed, 
    this.uploading,
    required this.mediaType
  });

  _PickedItem copyWith({double? progress, bool? failed, String? thumbPath, bool? uploading}) => _PickedItem(
    file: file,
    width: width,
    height: height,
    duration: duration,
    progress: progress ?? this.progress,
    thumbPath: thumbPath ?? this.thumbPath,
    failed: failed ?? this.failed,
    uploading: uploading ?? this.uploading,
    mediaType: mediaType,
  );
}

enum UploadQuality { low, medium, high, original }
enum MediaType { video, photo }

VideoQuality _mapQuality(UploadQuality q) {
  switch (q) {
    case UploadQuality.low:
      return VideoQuality.LowQuality;
    case UploadQuality.medium:
      return VideoQuality.MediumQuality;
    case UploadQuality.high:
      // Fallback to DefaultQuality for "high" if HighQuality isn't available in this package version
      return VideoQuality.DefaultQuality;
    case UploadQuality.original:
      return VideoQuality.DefaultQuality; // no real compression; pass-through
  }
}

String _sanitizeUploadName(String name) {
  // Keep extension, strip query and illegal chars
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  final cleaned = base.replaceAll(RegExp(r"[^a-zA-Z0-9._-]"), '_');
  return '$cleaned$ext';
}

/// Creates a very low quality thumbnail for images
Future<String?> _createLowQualityImageThumbnail(String imagePath) async {
  try {
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    
    // Decode the image
    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: 200, // Improved size - 200px max for better quality while maintaining performance
      targetHeight: 200, // Improved size - 200px max for better quality while maintaining performance
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    
    // Convert to better quality JPEG
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png, // Use PNG which we can control
    );
    
    if (byteData != null) {
      // Create a temporary file for the improved quality thumbnail
      final tempDir = Directory.systemTemp;
      final fileName = path.basenameWithoutExtension(imagePath);
      final thumbnailFile = File('${tempDir.path}/${fileName}_thumb_medq.jpg');
      
      // Write the compressed bytes
      await thumbnailFile.writeAsBytes(byteData.buffer.asUint8List());
      
      return thumbnailFile.path;
    }
  } catch (e) {
    print('Error creating improved quality thumbnail: $e');
  }
  
  return null;
}
