import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:minio/minio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SchoolNotificationsTemplate extends StatefulWidget {
  final String currentUserId;
  const SchoolNotificationsTemplate({super.key, required this.currentUserId});

  @override
  State<SchoolNotificationsTemplate> createState() => _SchoolNotificationsTemplateState();
}

class _SchoolNotificationsTemplateState extends State<SchoolNotificationsTemplate> {
  // R2 Configuration
  static String r2AccountId = '';
  static String r2AccessKeyId = '';
  static String r2SecretAccessKey = '';
  static String r2BucketName = '';
  static String r2CustomDomain = '';
  static bool _r2ConfigLoaded = false;

  // Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  // Media Upload State
  final List<PlatformFile> _attachedFiles = [];
  final List<Map<String, dynamic>> _uploadedMedia = [];
  bool _uploading = false;
  double? _uploadProgress;
  String? _uploadStatus;
  int? _totalBytes;
  int _bytesSent = 0;

  // Notification Categories
  String _selectedCategory = 'general';
  final List<Map<String, String>> _categories = [
    {'value': 'general', 'label': '📢 General Announcement'},
    {'value': 'academic', 'label': '📚 Academic Notice'},
    {'value': 'events', 'label': '🎉 School Events'},
    {'value': 'emergency', 'label': '🚨 Emergency Alert'},
    {'value': 'sports', 'label': '⚽ Sports Update'},
    {'value': 'exam', 'label': '📝 Exam Schedule'},
    {'value': 'holiday', 'label': '🏖️ Holiday Notice'},
  ];

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

  bool _isConfigured() {
    return r2AccountId.isNotEmpty && 
           r2AccessKeyId.isNotEmpty && 
           r2SecretAccessKey.isNotEmpty && 
           r2BucketName.isNotEmpty;
  }

  Future<void> _pickMediaFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
      withData: true,
    );
    
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _attachedFiles.addAll(result.files);
      });
    }
  }

  void _removeAttachedFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  Future<void> _uploadMediaFiles() async {
    if (_attachedFiles.isEmpty || !_isConfigured()) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing upload...';
    });

    await WakelockPlus.enable();
    
    try {
      final minio = Minio(
        endPoint: '${r2AccountId}.r2.cloudflarestorage.com',
        accessKey: r2AccessKeyId,
        secretKey: r2SecretAccessKey,
        useSSL: true,
      );

      for (int i = 0; i < _attachedFiles.length; i++) {
        final file = _attachedFiles[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileExtension = file.extension ?? '';
        final key = 'school_notifications/${timestamp}_${i}_${file.name}';

        setState(() {
          _uploadStatus = 'Uploading ${file.name} (${i + 1}/${_attachedFiles.length})...';
        });

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
          throw 'No file data available for ${file.name}';
        }

        await minio.putObject(
          r2BucketName,
          key,
          stream,
          size: total,
          onProgress: (n) {
            if (mounted) {
              setState(() {
                _uploadProgress = (i + n / total) / _attachedFiles.length;
              });
            }
          },
        );

        final url = r2CustomDomain.isNotEmpty
            ? '$r2CustomDomain/$key'
            : 'https://${r2AccountId}.r2.cloudflarestorage.com/$key';

        final mediaData = {
          'type': _getMediaType(fileExtension),
          'url': url,
          'key': key,
          'bucket': r2BucketName,
          'fileName': file.name,
          'fileSize': total,
          'uploadedAt': FieldValue.serverTimestamp(),
        };

        _uploadedMedia.add(mediaData);
      }

      setState(() {
        _uploading = false;
        _uploadStatus = 'All files uploaded successfully!';
        _uploadProgress = 1.0;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadStatus = 'Upload failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'))
        );
      }
    } finally {
      await WakelockPlus.disable();
    }
  }

  String _getMediaType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return 'video';
      case 'mp3':
      case 'wav':
      case 'aac':
        return 'audio';
      case 'pdf':
        return 'document';
      default:
        return 'file';
    }
  }

  Future<void> _publishNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both title and message'))
      );
      return;
    }

    try {
      // Upload media files first if any
      if (_attachedFiles.isNotEmpty && _uploadedMedia.isEmpty) {
        await _uploadMediaFiles();
      }

      // Create notification document
      final notificationData = {
        'title': title,
        'message': message,
        'category': _selectedCategory,
        'senderId': widget.currentUserId,
        'senderRole': 'admin',
        'senderName': 'School Administration',
        'attachments': _uploadedMedia,
        'timestamp': FieldValue.serverTimestamp(),
        'isPublished': true,
      };

      await FirebaseFirestore.instance
          .collection('school_notifications')
          .add(notificationData);

      // Add to notification queue for push notifications
      try {
        await FirebaseFirestore.instance.collection('notificationQueue').add({
          'title': title,
          'body': message,
          'topic': 'all_students',
          'category': _selectedCategory,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Notification queue is optional
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School notification published successfully!'))
      );

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _attachedFiles.clear();
        _uploadedMedia.clear();
        _selectedCategory = 'general';
        _uploadStatus = null;
        _uploadProgress = null;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish notification: $e'))
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    try { 
      WakelockPlus.disable(); 
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Notifications'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.school, color: Colors.blue, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'School Communication Center',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'Send important notifications with media attachments to students and parents',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Category Selection
            const Text(
              'Notification Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['value'],
                      child: Text(category['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title Input
            const Text(
              'Notification Title',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Enter notification title...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              enabled: !_uploading,
            ),
            const SizedBox(height: 20),

            // Message Input
            const Text(
              'Message Content',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Type your message here...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              enabled: !_uploading,
            ),
            const SizedBox(height: 24),

            // Media Attachment Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_file, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Media Attachments',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _uploading ? null : _pickMediaFiles,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Media'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Display attached files
                  if (_attachedFiles.isNotEmpty) ...[
                    const Text(
                      'Selected Files:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_attachedFiles.length, (index) {
                      final file = _attachedFiles[index];
                      final sizeInMB = (file.size / (1024 * 1024)).toStringAsFixed(2);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getFileIcon(file.extension ?? ''),
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '$sizeInMB MB',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _uploading ? null : () => _removeAttachedFile(index),
                              icon: const Icon(Icons.close, color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Configuration warning
                  if (!_isConfigured()) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Media upload requires R2 configuration in Admin Settings',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Upload Progress Section
            if (_uploading || _uploadStatus != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud_upload, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Upload Progress',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_uploadStatus != null) Text(_uploadStatus!),
                    if (_uploading && _uploadProgress != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_uploadProgress! * 100).toStringAsFixed(1)}% completed',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Publish Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _uploading ? null : _publishNotification,
                icon: const Icon(Icons.send),
                label: const Text(
                  'Publish School Notification',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }
}
