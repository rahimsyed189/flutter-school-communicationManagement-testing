import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:minio/minio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminBackgroundImagePage extends StatefulWidget {
  const AdminBackgroundImagePage({super.key});

  @override
  State<AdminBackgroundImagePage> createState() => _AdminBackgroundImagePageState();
}

class _AdminBackgroundImagePageState extends State<AdminBackgroundImagePage> {
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
  String? _currentBackgroundUrl;

  @override
  void initState() {
    super.initState();
    _loadR2Configuration();
    _loadCurrentBackground();
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

  Future<void> _loadCurrentBackground() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('current_page_background')
          .get();
      if (doc.exists && doc.data()?['imageUrl'] != null) {
        setState(() {
          _currentBackgroundUrl = doc.data()!['imageUrl'];
        });
      }
    } catch (e) {
      debugPrint('Failed to load current background: $e');
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
    return r2AccountId.isNotEmpty && 
           r2AccessKeyId.isNotEmpty && 
           r2SecretAccessKey.isNotEmpty && 
           r2BucketName.isNotEmpty;
  }

  Future<void> _upload() async {
    final file = _pickedFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an image first'))
      );
      return;
    }
    if (!_isConfigured()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure R2 in Admin Settings'))
      );
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0.0;
      _status = 'Deleting old background images from R2…';
    });

    await WakelockPlus.enable();
    try {
      final minio = Minio(
        endPoint: '$r2AccountId.r2.cloudflarestorage.com',
        accessKey: r2AccessKeyId,
        secretKey: r2SecretAccessKey,
        useSSL: true,
        enableTrace: false,
      );

      // Delete all existing images in currentPageBackgroundImage folder
      final objectsStream = minio.listObjects(
        r2BucketName,
        prefix: 'currentPageBackgroundImage/',
        recursive: true,
      );

      await for (final listResult in objectsStream) {
        for (final obj in listResult.objects) {
          if (obj.key != null) {
            await minio.removeObject(r2BucketName, obj.key!);
            debugPrint('🗑️ Deleted old background: ${obj.key}');
          }
        }
      }

      setState(() {
        _status = 'Uploading new background to R2…';
      });

      final name = file.name;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final key = 'currentPageBackgroundImage/${timestamp}_$name';

      int total;
      Stream<Uint8List> fileStream;
      if (file.bytes != null) {
        total = file.bytes!.length;
        fileStream = Stream.value(file.bytes!);
      } else if (file.path != null) {
        final f = File(file.path!);
        total = await f.length();
        fileStream = f.openRead().cast<Uint8List>();
      } else {
        throw Exception('No file data available');
      }

      await minio.putObject(
        r2BucketName,
        key,
        fileStream,
        size: total,
        onProgress: (sent) {
          if (mounted) {
            setState(() {
              _progress = sent / total;
              _status = 'Uploading: ${(sent / 1024 / 1024).toStringAsFixed(1)}MB / ${(total / 1024 / 1024).toStringAsFixed(1)}MB';
            });
          }
        },
      );

      final imageUrl = r2CustomDomain.isNotEmpty
          ? '$r2CustomDomain/$key'
          : 'https://$r2AccountId.r2.cloudflarestorage.com/$r2BucketName/$key';

      // Save URL to Firestore
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('current_page_background')
          .set({
        'imageUrl': imageUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileName': name,
      });

      setState(() {
        _uploading = false;
        _progress = null;
        _status = null;
        _currentBackgroundUrl = imageUrl;
        _pickedFile = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Background uploaded successfully'))
        );
      }
    } catch (e) {
      setState(() {
        _uploading = false;
        _progress = null;
        _status = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'))
        );
      }
    } finally {
      await WakelockPlus.disable();
    }
  }

  Future<void> _removeBackground() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Background?'),
        content: const Text('This will revert to the default gradient background.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('current_page_background')
            .delete();

        setState(() {
          _currentBackgroundUrl = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Background removed'))
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove: $e'))
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Page Background'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Background Preview
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Background',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_currentBackgroundUrl != null)
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _currentBackgroundUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.error, size: 50),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _removeBackground,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove Background'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Default Gradient\n(No custom background)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Upload New Background
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload New Background',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Pick Image Button
                    ElevatedButton.icon(
                      onPressed: _uploading ? null : _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Select Image'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    
                    if (_pickedFile != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _pickedFile!.name,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              '${(_pickedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Upload Button
                      ElevatedButton.icon(
                        onPressed: _uploading ? null : _upload,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload to R2'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],

                    if (_uploading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 8),
                      Text(
                        _status ?? 'Uploading...',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[300]!),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Recommended: Use landscape images (16:9 ratio) with max 2MB size for best performance.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
