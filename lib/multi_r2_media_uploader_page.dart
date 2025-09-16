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
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('School Media Center'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0B1220),
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SchoolMediaCardWidget(
            title: 'School Media Center',
            subtitle: 'Upload & Share — Media Files',
            senderInfo: 'Admin Panel',
            recipientInfo: 'For: All Users',
            timestamp: DateTime.now(),
            mediaItems: mediaItems,
            isUploadMode: true,
            uploadControls: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE6F9F1), Color(0xFFE9F1FF)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF04324F).withOpacity(0.06),
                ),
              ),
              child: Column(
                children: [
                  // Template selector with visual previews
                  const Text(
                    'Choose Template Style:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF04324F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // School Template
                      Expanded(
                        child: GestureDetector(
                          onTap: _uploading ? null : () => setState(() => _selectedTemplate = MediaTemplateStyle.school),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8AD7FF), Color(0xFFC6F7E6)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedTemplate == MediaTemplateStyle.school
                                    ? const Color(0xFF04324F)
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: _selectedTemplate == MediaTemplateStyle.school
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF04324F).withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'School Template',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF04324F),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  const Icon(
                                    Icons.school,
                                    color: Color(0xFF04324F),
                                    size: 16,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Academic',
                                    style: TextStyle(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF04324F).withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Business Template
                      Expanded(
                        child: GestureDetector(
                          onTap: _uploading ? null : () => setState(() => _selectedTemplate = MediaTemplateStyle.business),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E293B), Color(0xFF334155)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedTemplate == MediaTemplateStyle.business
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: _selectedTemplate == MediaTemplateStyle.business
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Business Template',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  const Icon(
                                    Icons.business,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Professional',
                                    style: TextStyle(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Modern Template
                      Expanded(
                        child: GestureDetector(
                          onTap: _uploading ? null : () => setState(() => _selectedTemplate = MediaTemplateStyle.modern),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedTemplate == MediaTemplateStyle.modern
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: _selectedTemplate == MediaTemplateStyle.modern
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Modern Template',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Creative',
                                    style: TextStyle(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Template preview
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF04324F).withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview: ${_getTemplateName(_selectedTemplate)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getTemplateGradient(_selectedTemplate),
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getTemplateAccent(_selectedTemplate).withOpacity(0.2),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Your media style',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _getTemplateAccent(_selectedTemplate),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Quality selector
                  Row(
                    children: [
                      const Text(
                        'Video Quality: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Color(0xFF04324F),
                        ),
                      ),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UploadQuality>(
                            value: _quality,
                            onChanged: _uploading ? null : (q) => setState(() => _quality = q ?? UploadQuality.medium),
                            style: const TextStyle(
                              color: Color(0xFF04324F),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: UploadQuality.low, child: Text('Low', style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(value: UploadQuality.medium, child: Text('Medium', style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(value: UploadQuality.high, child: Text('High', style: TextStyle(fontSize: 11))),
                              DropdownMenuItem(value: UploadQuality.original, child: Text('Original', style: TextStyle(fontSize: 11))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Buttons row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _uploading ? null : _pickMedia,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text(
                            'Select Media',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF04324F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB6F0E0), Color(0xFFBFE0FF)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF04324F).withOpacity(0.12),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _uploading ? null : _startUpload,
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text(
                              'Upload All',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: const Color(0xFF04324F),
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_loadingCfg) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      backgroundColor: const Color(0xFF64748B).withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF04324F)),
                    ),
                  ],
                ],
              ),
            ),
            progressOverlay: _uploading ? Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: _overallProgress,
                        strokeWidth: 6,
                        backgroundColor: const Color(0xFF64748B).withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF04324F)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status ?? 'Uploading...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF04324F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_overallProgress * 100).toStringAsFixed(1)}% completed',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF64748B).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ) : null,
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
