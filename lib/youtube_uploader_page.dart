import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minio/minio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class YouTubeUploaderPage extends StatefulWidget {
  const YouTubeUploaderPage({super.key});

  @override
  State<YouTubeUploaderPage> createState() => _YouTubeUploaderPageState();
}

class _YouTubeUploaderPageState extends State<YouTubeUploaderPage> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  String _destination = 'youtube'; // 'youtube' | 'r2'

  // Cloudflare R2 Configuration - These should be configured by the user
  static String r2AccountId = '';
  static String r2AccessKeyId = ''; 
  static String r2SecretAccessKey = '';
  static String r2BucketName = '';
  static String r2CustomDomain = ''; // Optional: https://media.yourdomain.com
  static bool _r2ConfigLoaded = false;

  PlatformFile? _pickedFile;
  bool _uploading = false;
  String? _status;
  double? _progress; // 0..1 if available (not all transports support progress)
  int? _totalBytes;
  int _bytesSent = 0;
  int? _videoWidth;
  int? _videoHeight;
  Duration? _videoDuration;
  VideoQuality _selectedCompressionQuality = VideoQuality.MediumQuality;
  // Live compression progress subscription (video_compress subscription)
  dynamic _compressionSub;

  @override
  void initState() {
    super.initState();
    _loadR2Configuration();
  }

  // Load R2 configuration from Firebase
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
        
        if (mounted) {
          setState(() {}); // Refresh UI to show loaded config
        }
      }
    } catch (e) {
      print('Failed to load R2 configuration: $e');
    }
  }

  // Save R2 configuration to Firebase
  Future<void> _saveR2Configuration() async {
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('r2_settings')
          .set({
        'accountId': r2AccountId,
        'accessKeyId': r2AccessKeyId,
        'secretAccessKey': r2SecretAccessKey,
        'bucketName': r2BucketName,
        'customDomain': r2CustomDomain,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('R2 configuration saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save R2 configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        // Critical: don't load the entire file into memory; we'll stream from disk
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      // Show an immediate spinner for large selections while we prepare the next step
      if (mounted) {
        setState(() {
          _uploading = true;
          _progress = null; // indeterminate
          _status = 'Preparing video…';
        });
      }

      // Ensure we have a readable file path; bail out if not available
      if ((picked.path == null || picked.path!.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read selected file path. Please pick a file from local storage.')),
        );
        setState(() => _uploading = false);
        return;
      }
      
      // Show compression dialog before processing
      final shouldCompress = await _showCompressionDialog();
      if (shouldCompress == null) {
        if (mounted) setState(() => _uploading = false);
        return; // User cancelled
      }
      
  setState(() {
        _status = 'Processing video...';
        _uploading = true;
      });

      PlatformFile finalFile = picked;
      
      // Compress if user chose to
      if (shouldCompress) {
        try {
          setState(() {
            _status = 'Compressing video...';
            _progress = 0.0;
          });
          
          // Enable wake lock during compression
          await WakelockPlus.enable();
          
          // Set up compression with progress callback (0..100)
          // Ensure previous subscription is cleared
          try { _compressionSub?.unsubscribe(); } catch (_) {}
          _compressionSub = VideoCompress.compressProgress$.subscribe((dynamic pct) {
            if (!mounted) return;
            final double p = (pct is num) ? pct.toDouble().clamp(0.0, 100.0) : 0.0;
            setState(() {
              _progress = p / 100.0;
              _status = 'Compressing video… ${p.toStringAsFixed(0)}%';
            });
          });
          
          final compressedFile = await VideoCompress.compressVideo(
            picked.path!,
            quality: _selectedCompressionQuality,
            deleteOrigin: false,
            includeAudio: true,
            frameRate: 30, // Limit to 30fps for better compression
          );
          
          if (compressedFile != null && compressedFile.file != null) {
            // Don't load compressed file into memory, just use the path
            finalFile = PlatformFile(
              name: 'compressed_${picked.name}',
              size: await compressedFile.file!.length(),
              path: compressedFile.path,
              // Don't load bytes into memory to avoid crashes
            );
            
            final originalSizeMB = picked.size / 1024 / 1024;
            final compressedSizeMB = finalFile.size / 1024 / 1024;
            final compressionRatio = ((originalSizeMB - compressedSizeMB) / originalSizeMB * 100);
            
            setState(() {
              _progress = null;
              _status = 'Compression complete! Size reduced from ${originalSizeMB.toStringAsFixed(1)}MB to ${compressedSizeMB.toStringAsFixed(1)}MB (${compressionRatio.toStringAsFixed(0)}% smaller)';
            });
          } else {
            throw 'Compression failed - no output file';
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Compression failed: $e')),
          );
          setState(() {
            _uploading = false;
            _progress = null;
            _status = null;
          });
          return;
        } finally {
          // Disable wake lock after compression
          await WakelockPlus.disable();
          try { _compressionSub?.unsubscribe(); } catch (_) {}
          try { await VideoCompress.cancelCompression(); } catch (_) {}
          _compressionSub = null;
        }
      }
      
      // Probe basic metadata (width/height/duration)
      int? w;
      int? h;
      Duration? dur;
      try {
        final info = await VideoCompress.getMediaInfo(finalFile.path ?? '');
        if (info.width != null && info.height != null) {
          w = info.width;
          h = info.height;
        }
        if (info.duration != null) {
          dur = Duration(milliseconds: info.duration!.round());
        }
      } catch (e) {
        print('Error getting video metadata: $e');
        // Set defaults if metadata extraction fails
        w = null;
        h = null;
        dur = null;
      }
      
      setState(() {
        _pickedFile = finalFile;
        _videoWidth = w;
        _videoHeight = h;
        _videoDuration = dur;
        _uploading = false;
        _status = shouldCompress ? 'Video compressed and ready to upload' : 'Video ready to upload';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
      setState(() => _uploading = false);
    }
  }

  Future<bool?> _showCompressionDialog() async {
    VideoQuality selectedQuality = VideoQuality.MediumQuality;
    
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Video Compression'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose compression quality:'),
              const SizedBox(height: 12),
              RadioListTile<VideoQuality>(
                title: const Text('High Quality'),
                subtitle: const Text('Best quality, larger file'),
                value: VideoQuality.HighestQuality,
                groupValue: selectedQuality,
                onChanged: (value) => setDialogState(() => selectedQuality = value!),
              ),
              RadioListTile<VideoQuality>(
                title: const Text('Medium Quality'),
                subtitle: const Text('Good balance (recommended)'),
                value: VideoQuality.MediumQuality,
                groupValue: selectedQuality,
                onChanged: (value) => setDialogState(() => selectedQuality = value!),
              ),
              RadioListTile<VideoQuality>(
                title: const Text('Low Quality'),
                subtitle: const Text('Smallest file, lower quality'),
                value: VideoQuality.LowQuality,
                groupValue: selectedQuality,
                onChanged: (value) => setDialogState(() => selectedQuality = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Original'),
            ),
            TextButton(
              onPressed: () {
                // Store selected quality for compression
                _selectedCompressionQuality = selectedQuality;
                Navigator.pop(context, true);
              },
              child: const Text('Compress'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    final file = _pickedFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a video first')),
      );
      return;
    }

    // Check R2 configuration if uploading to R2
    if (_destination == 'r2' && !_isR2Configured()) {
      final configured = await _showR2ConfigDialog();
      if (!configured) return;
    }

    setState(() {
      _uploading = true;
      _status = _destination == 'youtube' ? 'Signing in to Google…' : 'Preparing R2 upload…';
  _progress = 0.0;
    });

    try {
      if (_destination == 'youtube') {
        await _uploadToYouTube(file);
      } else {
        await _uploadToR2(file);
      }
    } catch (e) {
      if (!mounted) return;
      String friendly = _destination == 'youtube' ? 'YouTube upload failed: $e' : 'R2 upload failed: $e';
      
      // Provide a clearer hint when the YouTube Data API is not enabled on the project
      if (_destination == 'youtube' && e is commons.DetailedApiRequestError) {
        final msg = (e.message ?? '').toLowerCase();
        final reason = e.errors.isNotEmpty ? (e.errors.first.reason ?? '') : '';
        if (e.status == 403 &&
            (msg.contains('has not been used') || msg.contains('disabled') || reason.contains('accessNotConfigured'))) {
          const projectNumber = '402790849608';
          const projectId = 'adilabadautocabs';
          final url = 'https://console.developers.google.com/apis/api/youtube.googleapis.com/overview?project=$projectNumber';
          friendly = 'YouTube Data API v3 is not enabled for project "$projectId".\n'
              'Open: $url, click "Enable", then retry.\n'
              'Also ensure your OAuth consent screen is configured and your account is a Test user (or app is in Production).';
        }
      }
      
      setState(() {
        _uploading = false;
        _status = 'Failed: $friendly';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    }
  }

  bool _isR2Configured() {
    return r2AccountId.isNotEmpty && 
           r2AccessKeyId.isNotEmpty && 
           r2SecretAccessKey.isNotEmpty && 
           r2BucketName.isNotEmpty;
  }

  Future<bool> _showR2ConfigDialog() async {
    final accountIdCtrl = TextEditingController(text: r2AccountId);
    final accessKeyCtrl = TextEditingController(text: r2AccessKeyId);
    final secretKeyCtrl = TextEditingController(text: r2SecretAccessKey);
    final bucketNameCtrl = TextEditingController(text: r2BucketName);
    final customDomainCtrl = TextEditingController(text: r2CustomDomain);

    final isConfigured = r2AccessKeyId.isNotEmpty && 
                        r2SecretAccessKey.isNotEmpty && 
                        r2BucketName.isNotEmpty;

    bool? result;
    try {
      result = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Prevent accidental dismissal
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isConfigured ? Icons.check_circle : Icons.settings,
                color: isConfigured ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isConfigured ? 'Edit R2 Configuration' : 'Configure Cloudflare R2',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isConfigured) 
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'R2 configured for bucket: ${r2BucketName}',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'R2 not configured. Enter credentials below.',
                              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: accountIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Account ID *',
                      border: OutlineInputBorder(),
                      hintText: 'Your Cloudflare Account ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accessKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Access Key ID *',
                      border: OutlineInputBorder(),
                      hintText: 'R2 Access Key ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: secretKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Secret Access Key *',
                      border: OutlineInputBorder(),
                      hintText: 'R2 Secret Access Key',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bucketNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bucket Name *',
                      border: OutlineInputBorder(),
                      hintText: 'Your R2 bucket name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customDomainCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Custom Domain (optional)',
                      hintText: 'https://media.yourdomain.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '* Required fields',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isConfigured)
              TextButton(
                onPressed: () {
                  // Clear configuration
                  r2AccountId = '';
                  r2AccessKeyId = '';
                  r2SecretAccessKey = '';
                  r2BucketName = '';
                  r2CustomDomain = '';
                  _saveR2Configuration();
                  Navigator.of(context).pop(false);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear Config'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final accountId = accountIdCtrl.text.trim();
                final accessKey = accessKeyCtrl.text.trim();
                final secretKey = secretKeyCtrl.text.trim();
                final bucketName = bucketNameCtrl.text.trim();
                
                if (accountId.isEmpty || accessKey.isEmpty || secretKey.isEmpty || bucketName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                r2AccountId = accountId;
                r2AccessKeyId = accessKey;
                r2SecretAccessKey = secretKey;
                r2BucketName = bucketName;
                r2CustomDomain = customDomainCtrl.text.trim();
                
                _saveR2Configuration();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(isConfigured ? 'Update' : 'Save'),
            ),
          ],
        ),
      );
    } finally {
      // Properly dispose controllers
      accountIdCtrl.dispose();
      accessKeyCtrl.dispose();
      secretKeyCtrl.dispose();
      bucketNameCtrl.dispose();
      customDomainCtrl.dispose();
    }

    return result ?? false;
  }

  Future<void> _uploadToYouTube(PlatformFile file) async {
    final gSignIn = GoogleSignIn(
      scopes: const [
        youtube.YouTubeApi.youtubeUploadScope,
        youtube.YouTubeApi.youtubeReadonlyScope,
      ],
    );
    final account = await gSignIn.signIn();
    if (account == null) {
      throw 'Sign-in canceled';
    }
    final client = await gSignIn.authenticatedClient();
    if (client == null) {
      throw 'Failed to get authenticated client';
    }

    setState(() => _status = 'Preparing upload…');

    final api = youtube.YouTubeApi(client);
    final video = youtube.Video(
      snippet: youtube.VideoSnippet(
        title: (_titleCtrl.text.trim().isEmpty)
            ? 'Untitled video'
            : _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      ),
      status: youtube.VideoStatus(privacyStatus: 'unlisted'),
    );

    // Build a stream for upload
    Stream<List<int>> stream;
    int length;
    if (file.path != null) {
      final f = File(file.path!);
      length = await f.length();
      stream = f.openRead();
    } else if (file.bytes != null) {
      final bytes = file.bytes!;
      length = bytes.length;
      stream = Stream<List<int>>.fromIterable([bytes]);
    } else {
      throw 'No file data available';
    }

    // Track progress by wrapping the stream and counting bytes
    _bytesSent = 0;
    _totalBytes = length;
    stream = stream.map((chunk) {
      _bytesSent += chunk.length;
      if (mounted && _totalBytes != null && _totalBytes! > 0) {
        final p = _bytesSent / _totalBytes!;
        setState(() {
          _progress = p;
          _status = 'Uploading to YouTube… ${(p * 100).toStringAsFixed(0)}%';
        });
      }
      return chunk;
    });

    final media = commons.Media(stream, length, contentType: 'video/*');

    setState(() => _status = 'Uploading to YouTube…');

    final result = await api.videos.insert(
      video,
      ['snippet', 'status'],
      uploadMedia: media,
    );

    if (!mounted) return;
    setState(() {
      _uploading = false;
      _status = 'Upload complete';
    });

    final id = result.id;
    if (id == null || id.isEmpty) {
      throw 'Upload finished but no video id returned';
    }

    final url = 'https://youtu.be/$id';
    
    // Save video metadata to Firestore
    try {
      final videoData = {
        'type': 'youtube',
        'videoId': id,
        'url': url,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'width': _videoWidth,
        'height': _videoHeight,
        'durationMs': _videoDuration?.inMilliseconds,
        'uploadedAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await FirebaseFirestore.instance
          .collection('videos')
          .add(videoData);
      
      setState(() => _status = 'Video uploaded to YouTube and metadata saved');
      
      if (!mounted) return;
      Navigator.of(context).pop({
        ...videoData,
        'id': docRef.id,
      });
    } catch (e) {
      setState(() => _status = 'Upload complete but failed to save metadata: $e');
      
      if (!mounted) return;
      Navigator.of(context).pop({
        'type': 'youtube',
        'videoId': id,
        'url': url,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'width': _videoWidth,
        'height': _videoHeight,
        'durationMs': _videoDuration?.inMilliseconds,
        'error': 'Failed to save metadata',
      });
    }
  }

  Future<void> _uploadToR2(PlatformFile file) async {
    setState(() => _status = 'Uploading to Cloudflare R2…');
    
    // Enable wake lock to prevent system from killing the app
    await WakelockPlus.enable();
    
    try {
      // Check if R2 is configured
      if (r2AccessKeyId.isEmpty || r2SecretAccessKey.isEmpty || r2BucketName.isEmpty) {
        setState(() {
          _uploading = false;
          _status = 'R2 not configured. Please configure R2 credentials first.';
        });
        return;
      }
      
  // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.extension ?? 'mp4';
      final fileName = 'videos/${timestamp}_${file.name}';
      // Build thumbnail name by replacing original extension with .jpg
      String baseName = file.name;
      final dot = baseName.lastIndexOf('.');
      if (dot > 0) {
        baseName = baseName.substring(0, dot);
      }
  // Store thumbnail alongside videos to simplify access/policy
  final thumbName = 'videos/${timestamp}_${baseName}.jpg';
      
      // Get file size without loading into memory
      late int fileSize;
      late Stream<Uint8List> fileStream;
      
      if (file.path != null) {
        final fileRef = File(file.path!);
        fileSize = await fileRef.length();
        // Stream file in modest chunks to avoid memory spikes (256KB)
        const chunkSize = 256 * 1024;
        fileStream = fileRef.openRead(0, fileSize).transform(
          StreamTransformer.fromHandlers(handleData: (List<int> chunk, EventSink<Uint8List> sink) {
            // Split overly large chunks defensively
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
      } else if (file.bytes != null) {
        fileSize = file.bytes!.length;
        // Avoid single giant buffer; emit in 256KB slices
        const chunkSize = 256 * 1024;
        final bytes = file.bytes!;
        final controller = StreamController<Uint8List>();
        () async {
          for (int i = 0; i < bytes.length; i += chunkSize) {
            final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
            controller.add(Uint8List.sublistView(bytes, i, end));
            await Future<void>.delayed(Duration.zero); // yield to UI loop
          }
          await controller.close();
        }();
        fileStream = controller.stream;
      } else {
        throw 'No file data available';
      }
      
      _totalBytes = fileSize;
      _bytesSent = 0;
      
  print('Starting R2 upload - File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');
      
      // Create Minio client for Cloudflare R2
      final minio = Minio(
        endPoint: '${r2AccountId}.r2.cloudflarestorage.com',
        accessKey: r2AccessKeyId,
        secretKey: r2SecretAccessKey,
        useSSL: true,
      );
      
      // Prepare thumbnail (first frame)
      setState(() => _status = 'Generating thumbnail…');
      String? publicThumbUrl;
      try {
        if (file.path != null && file.path!.isNotEmpty) {
          final thumbFile = await VideoCompress.getFileThumbnail(
            file.path!,
            quality: 80,
            position: 1000, // 1s position for a cleaner frame
          );
          final thumbSize = await thumbFile.length();
          final thumbStream = thumbFile.openRead().map((c) => Uint8List.fromList(c));

          // Upload thumbnail
          setState(() => _status = 'Uploading thumbnail…');
          await minio.putObject(
            r2BucketName,
            thumbName,
            thumbStream,
            size: thumbSize,
          );

          publicThumbUrl = r2CustomDomain.isNotEmpty
              ? '$r2CustomDomain/$thumbName'
              : 'https://${r2AccountId}.r2.cloudflarestorage.com/$thumbName';
        }
      } catch (e) {
        print('Thumbnail generation/upload failed: $e');
        // Proceed without blocking the main upload
      }

      // Upload file to R2 using streaming with simple retry
      setState(() => _status = 'Connecting to Cloudflare R2…');
      int attempt = 0;
      const int maxAttempts = 3;
      while (true) {
        try {
          await minio.putObject(
            r2BucketName,
            fileName,
            fileStream,
            size: fileSize,
            onProgress: (int bytes) {
          // Some Minio clients report cumulative bytes; others report delta per chunk. Handle both.
          if (bytes >= _bytesSent) {
            _bytesSent = bytes; // cumulative
          } else {
            _bytesSent += bytes; // delta
          }
          if (_totalBytes != null && _bytesSent > _totalBytes!) {
            _bytesSent = _totalBytes!; // clamp
          }
          if (mounted && _totalBytes != null && _totalBytes! > 0) {
            final progress = _bytesSent / _totalBytes!;
            final uploadedMB = _bytesSent / 1024 / 1024;
            final totalMB = _totalBytes! / 1024 / 1024;
            setState(() {
              _progress = progress;
              _status = 'Uploading to R2… ${(progress * 100).toStringAsFixed(0)}% (${uploadedMB.toStringAsFixed(1)}/${totalMB.toStringAsFixed(1)}MB)';
            });
          }
            },
          );
          break; // success
        } catch (e) {
          attempt++;
          if (attempt >= maxAttempts) rethrow;
          // Brief backoff and retry
          setState(() => _status = 'Upload interrupted, retrying ($attempt/$maxAttempts)…');
          await Future.delayed(const Duration(seconds: 2 * 1));
        }
      }
      
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _status = 'Upload to R2 complete!';
      });
      
      // Generate public URL
      final publicUrl = r2CustomDomain.isNotEmpty 
          ? '$r2CustomDomain/$fileName'
          : 'https://${r2AccountId}.r2.cloudflarestorage.com/$fileName';
      
      // Save video metadata to Firestore
      final videoData = {
        'type': 'r2',
        'url': publicUrl,
  if (publicThumbUrl != null) 'thumbnailUrl': publicThumbUrl,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'width': _videoWidth,
        'height': _videoHeight,
        'durationMs': _videoDuration?.inMilliseconds,
        'fileName': fileName,
        'bucket': r2BucketName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'demo': false, // Real upload
      };
      
      final docRef = await FirebaseFirestore.instance
          .collection('videos')
          .add(videoData);
      
      setState(() => _status = 'Video uploaded to R2 and metadata saved to Firestore');
      
      if (!mounted) return;
      Navigator.of(context).pop({
        ...videoData,
        'id': docRef.id,
      });
      
    } catch (e) {
      print('R2 upload error: $e');
      setState(() => _status = 'R2 upload failed: $e');
      
      if (!mounted) return;
      Navigator.of(context).pop({
        'type': 'r2',
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'width': _videoWidth,
        'height': _videoHeight,
        'durationMs': _videoDuration?.inMilliseconds,
        'error': 'R2 upload failed: $e',
      });
    } finally {
      // Disable wake lock when upload is complete
      await WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    try {
  try { _compressionSub?.unsubscribe(); } catch (_) {}
      VideoCompress.deleteAllCache(); // Clean up compressed video cache
      WakelockPlus.disable(); // Ensure wake lock is disabled
    } catch (e) {
      print('Error clearing video cache or disabling wake lock: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _pickedFile?.name;
    final fileSizeMB = _pickedFile?.size != null
        ? (_pickedFile!.size / (1024 * 1024)).toStringAsFixed(2)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
        // No R2 config icon or status
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            // Destination selector
            SegmentedButton<String>(
              segments: [
                const ButtonSegment<String>(
                  value: 'youtube', 
                  label: Text('YouTube'),
                  icon: Icon(Icons.video_library),
                ),
                const ButtonSegment<String>(
                  value: 'r2', 
                  label: Text('R2'),
                  icon: Icon(Icons.cloud),
                ),
              ],
              selected: {_destination},
              onSelectionChanged: _uploading ? null : (s) => setState(() => _destination = s.first),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _pickVideo,
              icon: const Icon(Icons.video_file_outlined),
              label: const Text('Pick video'),
            ),
            const SizedBox(height: 8),
            if (fileName != null)
              Text('Selected: $fileName${fileSizeMB != null ? ' ($fileSizeMB MB)' : ''}'),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              enabled: !_uploading,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
              enabled: !_uploading,
            ),
            const SizedBox(height: 16),
            if (_status != null) Text(_status!),
            if (_uploading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Builder(
                builder: (_) {
                  if (_totalBytes == null || _totalBytes == 0) return const SizedBox.shrink();
                  final sentMB = (_bytesSent / (1024 * 1024)).toStringAsFixed(2);
                  final totalMB = ((_totalBytes ?? 0) / (1024 * 1024)).toStringAsFixed(2);
                  final pct = _progress != null ? ' ${(100 * _progress!).toStringAsFixed(0)}%' : '';
                  return Text('$sentMB MB / $totalMB MB$pct', style: const TextStyle(fontSize: 12));
                },
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text('Upload to ${_destination == 'youtube' ? 'YouTube' : 'Cloudflare R2'}'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
