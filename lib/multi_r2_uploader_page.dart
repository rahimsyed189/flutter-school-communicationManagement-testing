import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minio/minio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path/path.dart' as path;

class MultiR2UploaderPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;
  const MultiR2UploaderPage({super.key, required this.currentUserId, required this.currentUserRole});

  @override
  State<MultiR2UploaderPage> createState() => _MultiR2UploaderPageState();
}

class _MultiR2UploaderPageState extends State<MultiR2UploaderPage> {
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

  Future<void> _pickVideos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final added = <_PickedItem>[];
    for (final f in result.files) {
      if (f.path == null || f.path!.isEmpty) continue;
      // Probe metadata
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
      added.add(_PickedItem(file: f, width: w, height: h, duration: dur, thumbPath: thumbPath));
    }
    if (!mounted) return;
    setState(() => _items.addAll(added));
  }

  bool get _isConfigured => _accountId.isNotEmpty && _accessKeyId.isNotEmpty && _secretAccessKey.isNotEmpty && _bucketName.isNotEmpty;

  Future<void> _startUpload() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick at least one video')));
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
        // Optional compression based on selected quality
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
        final fileName = 'videos/${ts}_$name';

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

        // Thumbnail (best-effort) - improved quality for better viewing
        String? thumbUrl;
        try {
          final thumb = await VideoCompress.getFileThumbnail(srcPath, quality: 60, position: 1000);
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
        } catch (_) {}

        final publicUrl = _customDomain.isNotEmpty
            ? '$_customDomain/$fileName'
            : 'https://$_accountId.r2.cloudflarestorage.com/$fileName';

        uploaded.add({
          'type': 'r2',
          'url': publicUrl,
          if (thumbUrl != null) 'thumbnailUrl': thumbUrl,
          'width': it.width,
          'height': it.height,
          'durationMs': it.duration?.inMilliseconds,
          'fileName': fileName,
          'bucket': _bucketName,
        });

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

      // Save an announcement document that groups all videos
      final doc = {
        'type': 'r2-multi',
        'videos': uploaded,
        'senderId': widget.currentUserId,
        'senderRole': widget.currentUserRole,
        'senderName': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('communications').add(doc);

      if (!mounted) return;
      setState(() { _status = 'All videos uploaded and announcement posted'; _uploading = false; });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload multiple videos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingCfg) const LinearProgressIndicator(),
            Row(
              children: [
                const Text('Quality: '),
                const SizedBox(width: 8),
                DropdownButton<UploadQuality>(
                  value: _quality,
                  onChanged: _uploading ? null : (q) => setState(() => _quality = q ?? UploadQuality.medium),
                  items: const [
                    DropdownMenuItem(value: UploadQuality.low, child: Text('Low')),
                    DropdownMenuItem(value: UploadQuality.medium, child: Text('Medium')),
                    DropdownMenuItem(value: UploadQuality.high, child: Text('High')),
                    DropdownMenuItem(value: UploadQuality.original, child: Text('Original')),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _uploading ? null : _pickVideos,
                  icon: const Icon(Icons.video_collection_outlined),
                  label: const Text('Pick videos'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _uploading ? null : _startUpload,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Upload all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_status != null) Text(_status!),
            if (_uploading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _overallProgress),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final it = _items[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: it.thumbPath != null
                            ? Image.file(File(it.thumbPath!), fit: BoxFit.cover)
                            : const Icon(Icons.ondemand_video, size: 32),
                      ),
                      if ((it.progress ?? 0) > 0 && (it.progress ?? 0) < 1.0)
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 44, height: 44,
                                child: CircularProgressIndicator(value: it.progress),
                              ),
                              Text('${(((it.progress ?? 0) * 100).round())}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      if (it.failed == true)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black45,
                            child: const Center(
                              child: Icon(Icons.error_outline, color: Colors.white, size: 32),
                            ),
                          ),
                        ),
                      if (it.failed == true)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              setState(() { _items.removeAt(index); });
                            },
                            child: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.delete, color: Colors.redAccent, size: 18),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
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

  _PickedItem({required this.file, this.width, this.height, this.duration, this.progress, this.thumbPath, this.failed, this.uploading});

  _PickedItem copyWith({double? progress, bool? failed, String? thumbPath, bool? uploading}) => _PickedItem(
    file: file,
    width: width,
    height: height,
    duration: duration,
    progress: progress ?? this.progress,
    thumbPath: thumbPath ?? this.thumbPath,
    failed: failed ?? this.failed,
    uploading: uploading ?? this.uploading,
  );
}

enum UploadQuality { low, medium, high, original }

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
