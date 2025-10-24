import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:minio/minio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ImageUploaderPage extends StatefulWidget {
  const ImageUploaderPage({super.key});

  @override
  State<ImageUploaderPage> createState() => _ImageUploaderPageState();
}

class _ImageUploaderPageState extends State<ImageUploaderPage> {
  static String r2AccountId = '';
  static String r2AccessKeyId = '';
  static String r2SecretAccessKey = '';
  static String r2BucketName = '';
  static String r2CustomDomain = '';
  static bool _r2ConfigLoaded = false;

  PlatformFile? _pickedFile;
  bool _uploading = false;
  double? _progress;
  String? _status;
  int? _totalBytes;
  int _bytesSent = 0;

  final _titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadR2Configuration();
  }

  Future<void> _loadR2Configuration() async {
    if (_r2ConfigLoaded) return;
    try {
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
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load R2 configuration: $e');
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  bool _isConfigured() {
    return r2AccountId.isNotEmpty && r2AccessKeyId.isNotEmpty && r2SecretAccessKey.isNotEmpty && r2BucketName.isNotEmpty;
  }

  Future<void> _upload() async {
    final file = _pickedFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an image first')));
      return;
    }
    if (!_isConfigured()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure R2 in Admin Settings')));
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0.0;
      _status = 'Uploading to R2…';
    });

    await WakelockPlus.enable();
    try {
      final name = file.name;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final schoolId = SchoolContext.currentSchoolId ?? 'default';
      final key = 'schools/$schoolId/images/${timestamp}_$name';

      int total;
      Stream<Uint8List> stream;
      if (file.path != null && file.path!.isNotEmpty) {
        final f = File(file.path!);
        total = await f.length();
        stream = f.openRead().map((c) => Uint8List.fromList(c));
      } else if (file.bytes != null) {
        total = file.bytes!.length;
        stream = Stream.fromIterable([file.bytes!]);
      } else {
        throw 'No file data available';
      }
      _totalBytes = total;
      _bytesSent = 0;

      final minio = Minio(
        endPoint: '${r2AccountId}.r2.cloudflarestorage.com',
        accessKey: r2AccessKeyId,
        secretKey: r2SecretAccessKey,
        useSSL: true,
      );

      await minio.putObject(
        r2BucketName,
        key,
        stream,
        size: total,
        onProgress: (n) {
          if (n >= _bytesSent) {
            _bytesSent = n;
          } else {
            _bytesSent += n;
          }
          if (mounted && _totalBytes != null && _totalBytes! > 0) {
            setState(() {
              _progress = _bytesSent / _totalBytes!;
              _status = 'Uploading to R2… ${(100 * (_progress ?? 0)).toStringAsFixed(0)}%';
            });
          }
        },
      );

      final url = r2CustomDomain.isNotEmpty
          ? '$r2CustomDomain/$key'
          : 'https://${r2AccountId}.r2.cloudflarestorage.com/$key';

      final data = {
        'type': 'r2-image',
        'url': url,
        'key': key,
        'bucket': r2BucketName,
        'title': _titleCtrl.text.trim(),
        'uploadedAt': FieldValue.serverTimestamp(),
        'schoolId': SchoolContext.currentSchoolId,
      };

      await FirebaseFirestore.instance.collection('images').add(data);
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _status = 'Image uploaded';
      });
      Navigator.of(context).pop(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _status = 'Upload failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      await WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    try { WakelockPlus.disable(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _pickedFile?.name;
    final fileSizeMB = _pickedFile?.size != null ? (_pickedFile!.size / (1024 * 1024)).toStringAsFixed(2) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Image to R2')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _uploading ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Pick image'),
            ),
            const SizedBox(height: 8),
            if (fileName != null) Text('Selected: $fileName${fileSizeMB != null ? ' ($fileSizeMB MB)' : ''}'),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(),
              ),
              enabled: !_uploading,
            ),
            const SizedBox(height: 16),
            if (_status != null) Text(_status!),
            if (_uploading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload to Cloudflare R2'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
