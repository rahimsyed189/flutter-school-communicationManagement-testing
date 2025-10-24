import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:minio/minio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/school_context.dart';

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
  bool _isLoading = true; // Track initial data loading
  double? _progress;
  String? _status;
  String? _currentBackgroundUrl;
  
  // Gradient colors for fallback background
  Color _gradientColor1 = Colors.white;
  Color _gradientColor2 = Colors.white;
  
  // Image alignment/fit option
  String _imageFit = 'cover'; // cover, contain, fill, fitWidth, fitHeight
  
  // Image opacity
  double _imageOpacity = 0.20;
  
  // Page selection for background application
  String _applyToPage = 'all'; // all, login, admin_home

  @override
  void initState() {
    super.initState();
    // Load all data in parallel after first frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }
  
  // Load all data in parallel for faster page load
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadR2Configuration(),
      _loadGradientColors(),
      _loadImageFit(),
      _loadImageOpacity(),
      _loadApplyToPage(),
    ]);
    // Load background last as it depends on R2 config
    await _loadCurrentBackground();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadGradientColors() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_gradient')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _gradientColor1 = Color(data['color1'] ?? 0xFFFFFFFF);
          _gradientColor2 = Color(data['color2'] ?? 0xFFFFFFFF);
        });
      }
    } catch (e) {
      debugPrint('Failed to load gradient colors: $e');
    }
  }
  
  Future<void> _saveGradientColors() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_gradient')
          .set({
        'color1': _gradientColor1.value,
        'color2': _gradientColor2.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Gradient colors saved')),
        );
      }
    } catch (e) {
      debugPrint('Failed to save gradient colors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }
  
  Future<void> _loadImageFit() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_image_fit')
          .get();
      if (doc.exists) {
        setState(() {
          _imageFit = doc.data()?['fit'] ?? 'cover';
        });
      }
    } catch (e) {
      debugPrint('Failed to load image fit: $e');
    }
  }
  
  Future<void> _saveImageFit() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_image_fit')
          .set({
        'fit': _imageFit,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Image alignment saved')),
        );
      }
    } catch (e) {
      debugPrint('Failed to save image fit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }
  
  Future<void> _loadImageOpacity() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_image_opacity')
          .get();
      if (doc.exists) {
        setState(() {
          _imageOpacity = doc.data()?['opacity'] ?? 0.20;
        });
      }
    } catch (e) {
      debugPrint('Failed to load image opacity: $e');
    }
  }
  
  Future<void> _saveImageOpacity() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_image_opacity')
          .set({
        'opacity': _imageOpacity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Image opacity saved')),
        );
      }
    } catch (e) {
      debugPrint('Failed to save image opacity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _loadApplyToPage() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_apply_to')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _applyToPage = doc.data()?['page'] ?? 'all';
        });
      }
    } catch (e) {
      debugPrint('Failed to load apply to page setting: $e');
    }
  }

  Future<void> _saveApplyToPage() async {
    try {
      final schoolId = SchoolContext.currentSchoolId;
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background_apply_to')
          .set({'page': _applyToPage});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Page selection saved')),
        );
      }
    } catch (e) {
      debugPrint('Failed to save apply to page: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
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
      final schoolId = SchoolContext.currentSchoolId;
      
      // Load from Firestore to get the object key
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background')
          .get();
      
      if (doc.exists && doc.data()?['objectKey'] != null) {
        final objectKey = doc.data()!['objectKey'];
        
        // Generate presigned URL
        await _loadR2Configuration();
        
        final minio = Minio(
          endPoint: '$r2AccountId.r2.cloudflarestorage.com',
          accessKey: r2AccessKeyId,
          secretKey: r2SecretAccessKey,
          useSSL: true,
        );
        
        final presignedUrl = await minio.presignedGetObject(r2BucketName, objectKey, expires: 3600);
        
        setState(() {
          _currentBackgroundUrl = presignedUrl;
        });
        
        // Cache the object key
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('background_key_$schoolId', objectKey);
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
      _status = 'Uploading new background to R2…';
    });

    await WakelockPlus.enable();
    try {
      final schoolId = SchoolContext.currentSchoolId;
      debugPrint('🎨 Uploading background for school: $schoolId');
      
      final minio = Minio(
        endPoint: '$r2AccountId.r2.cloudflarestorage.com',
        accessKey: r2AccessKeyId,
        secretKey: r2SecretAccessKey,
        useSSL: true,
        enableTrace: false,
      );

      // No deletion - just upload new image, old ones are kept
      final name = file.name;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final key = 'schools/$schoolId/background/${timestamp}_$name';
      
      debugPrint('📤 Uploading to R2 path: $key');

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

      debugPrint('📦 File size: ${(total / 1024 / 1024).toStringAsFixed(2)} MB');

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

      debugPrint('✅ Upload to R2 complete');

      // Save the R2 object key (not full URL) to Firestore
      debugPrint('💾 Saving to Firestore...');
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('config')
          .doc('background')
          .set({
        'objectKey': key, // Store the object key
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileName': name,
      });
      
      debugPrint('✅ Saved object key to Firestore: $key');

      // Generate presigned URL for immediate preview (reuse minio instance)
      final presignedUrl = await minio.presignedGetObject(r2BucketName, key, expires: 3600);
      debugPrint('🔗 Presigned URL generated: $presignedUrl');

      // Cache the object key locally by school ID (not the presigned URL)
      debugPrint('💾 Caching object key locally...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('background_key_$schoolId', key);
      debugPrint('✅ Cached successfully');

      setState(() {
        _uploading = false;
        _progress = null;
        _status = null;
        _currentBackgroundUrl = presignedUrl; // Use presigned URL for display
        _pickedFile = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Background uploaded successfully'))
        );
      }
      
      debugPrint('🎉 Upload process complete!');
    } catch (e) {
      debugPrint('❌ Upload error: $e');
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
        final schoolId = SchoolContext.currentSchoolId;
        
        // Remove from Firestore
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('config')
            .doc('background')
            .delete();

        // Clear cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('background_url_$schoolId');

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
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      body: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading settings...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
        child: Column(
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.wallpaper_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Customize Your Background',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload images, customize gradients, and control appearance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current Background Preview
                  _buildModernCard(
                    title: 'Current Background',
                    subtitle: 'Preview your active background',
                    icon: Icons.preview_rounded,
                    iconColor: Colors.purple,
                    child: Column(
                children: [
                  if (_currentBackgroundUrl != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CachedNetworkImage(
                              imageUrl: _currentBackgroundUrl!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 3),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.broken_image_rounded, size: 60, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _removeBackground,
                            icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                            label: const Text('Remove Background'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_gradientColor1, _gradientColor2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.gradient_rounded,
                              size: 48,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Default Gradient',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                shadows: const [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 4,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No custom image uploaded',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                                shadows: const [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black26,
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
                  const SizedBox(height: 20),

                  // Upload New Background
                  _buildModernCard(
                    title: 'Upload New Background',
                    subtitle: 'Select and upload a custom image',
                    icon: Icons.cloud_upload_rounded,
                    iconColor: Colors.green,
                    child: Column(
                children: [
                  // Pick Image Button
                  _buildActionButton(
                    onPressed: _uploading ? null : _pickImage,
                    icon: Icons.add_photo_alternate_rounded,
                    label: 'Select Image File',
                    color: Colors.blue,
                    isOutlined: true,
                  ),
                  
                  if (_pickedFile != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[50]!, Colors.green[100]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[300]!, width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _pickedFile!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_pickedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Upload Button
                    _buildActionButton(
                      onPressed: _uploading ? null : _upload,
                      icon: Icons.backup_rounded,
                      label: 'Upload to Cloud Storage',
                      color: Colors.green,
                    ),
                  ],

                  if (_uploading) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 8,
                              backgroundColor: Colors.blue[100],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _status ?? 'Uploading...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber[200]!, width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_rounded, color: Colors.amber[700], size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tip: Use landscape images (16:9 ratio) with max 2MB size for optimal performance.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
                  const SizedBox(height: 20),

                  // Gradient Background Colors
                  _buildModernCard(
              title: 'Gradient Colors',
              subtitle: 'Fallback colors shown while image loads',
              icon: Icons.gradient_rounded,
              iconColor: Colors.orange,
              child: Column(
                children: [
                  // Gradient Preview
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_gradientColor1, _gradientColor2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Live Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 6,
                              color: Colors.black38,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Color Pickers
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        // Color 1 Picker
                        Row(
                          children: [
                            Icon(Icons.looks_one_rounded, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Top-Left Color',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showColorPicker(true),
                              child: Container(
                                width: 70,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _gradientColor1,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _gradientColor1.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.colorize_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey[300], height: 1),
                        const SizedBox(height: 16),
                        
                        // Color 2 Picker
                        Row(
                          children: [
                            Icon(Icons.looks_two_rounded, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Bottom-Right Color',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showColorPicker(false),
                              child: Container(
                                width: 70,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _gradientColor2,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _gradientColor2.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.colorize_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Save Gradient Button
                  _buildActionButton(
                    onPressed: _saveGradientColors,
                    icon: Icons.save_rounded,
                    label: 'Save Gradient Colors',
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
                  const SizedBox(height: 20),
            
                  // Image Alignment / Fit Options
                  _buildModernCard(
              title: 'Image Alignment',
              subtitle: 'Control how the background image fits',
              icon: Icons.aspect_ratio_rounded,
              iconColor: Colors.indigo,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _imageFit,
                    decoration: InputDecoration(
                      labelText: 'Select Fit Mode',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      prefixIcon: Icon(Icons.fit_screen_rounded, color: Colors.indigo[400]),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'cover',
                        child: Row(
                          children: [
                            Icon(Icons.crop_free_rounded, size: 20, color: Colors.indigo),
                            SizedBox(width: 12),
                            Text('Cover (Zoom to Fill)', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'contain',
                        child: Row(
                          children: [
                            Icon(Icons.fit_screen_rounded, size: 20, color: Colors.indigo),
                            SizedBox(width: 12),
                            Text('Contain (Fit Inside)', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'fill',
                        child: Row(
                          children: [
                            Icon(Icons.fullscreen_rounded, size: 20, color: Colors.indigo),
                            SizedBox(width: 12),
                            Text('Fill (Stretch)', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'fitWidth',
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 20, color: Colors.indigo),
                            SizedBox(width: 12),
                            Text('Fit Width', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'fitHeight',
                        child: Row(
                          children: [
                            Icon(Icons.swap_vert_rounded, size: 20, color: Colors.indigo),
                            SizedBox(width: 12),
                            Text('Fit Height', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _imageFit = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Description for selected fit
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo[50]!, Colors.indigo[100]!.withOpacity(0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo[200]!, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: Colors.indigo[700], size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getImageFitDescription(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Save Button
                  _buildActionButton(
                    onPressed: _saveImageFit,
                    icon: Icons.save_rounded,
                    label: 'Save Image Alignment',
                    color: Colors.indigo,
                  ),
                ],
              ),
            ),
            
                  const SizedBox(height: 20),
            
                  // Apply To Pages Selection
                  _buildModernCard(
              title: 'Apply To Pages',
              subtitle: 'Choose where to display the background',
              icon: Icons.pages_rounded,
              iconColor: Colors.teal,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _applyToPage,
                    decoration: InputDecoration(
                      labelText: 'Select Pages',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      prefixIcon: Icon(Icons.layers_rounded, color: Colors.teal[400]),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Row(
                          children: [
                            Icon(Icons.select_all_rounded, size: 18, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('All Pages', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'login',
                        child: Row(
                          children: [
                            Icon(Icons.login_rounded, size: 18, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('Login Page Only', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'admin_home',
                        child: Row(
                          children: [
                            Icon(Icons.home_rounded, size: 18, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('Admin Home Only', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _applyToPage = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    onPressed: _saveApplyToPage,
                    icon: Icons.save_rounded,
                    label: 'Save Page Selection',
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
                  const SizedBox(height: 20),
            
                  // Image Opacity Control
                  _buildModernCard(
              title: 'Image Opacity',
              subtitle: 'Control background transparency',
              icon: Icons.opacity_rounded,
              iconColor: Colors.pink,
              child: Column(
                children: [
                  // Visual Opacity Display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink[50]!, Colors.pink[100]!.withOpacity(0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_rounded, color: Colors.pink[700], size: 32),
                        const SizedBox(width: 16),
                        Text(
                          '${(_imageOpacity * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink[700],
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Opacity Slider
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transparency Level',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.pink[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${(_imageOpacity * 100).toInt()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.pink[700],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Colors.pink[400],
                          inactiveTrackColor: Colors.pink[100],
                          thumbColor: Colors.pink[600],
                          overlayColor: Colors.pink.withOpacity(0.2),
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _imageOpacity,
                          min: 0.05,
                          max: 1.0,
                          divisions: 19,
                          label: '${(_imageOpacity * 100).toInt()}%',
                          onChanged: (value) {
                            setState(() => _imageOpacity = value);
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.visibility_off_rounded, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'More Transparent',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Less Transparent',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.visibility_rounded, size: 14, color: Colors.grey[600]),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Quick Preset Buttons
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flash_on_rounded, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Quick Presets',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPresetButton('10%', 0.10),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPresetButton('20%', 0.20),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPresetButton('50%', 0.50),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPresetButton('100%', 1.0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Save Button
                  _buildActionButton(
                    onPressed: _saveImageOpacity,
                    icon: Icons.save_rounded,
                    label: 'Save Image Opacity',
                    color: Colors.pink,
                  ),
                ],
              ),
            ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
        ),
    );
  }
  
  // Preset button helper
  Widget _buildPresetButton(String label, double value) {
    final isSelected = (_imageOpacity - value).abs() < 0.01;
    return OutlinedButton(
      onPressed: () => setState(() => _imageOpacity = value),
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? Colors.pink[700] : Colors.grey[700],
        side: BorderSide(
          color: isSelected ? Colors.pink[400]! : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        backgroundColor: isSelected ? Colors.pink[50] : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
  
  String _getImageFitDescription() {
    switch (_imageFit) {
      case 'cover':
        return 'Zooms image to fill entire screen, may crop edges';
      case 'contain':
        return 'Shows entire image, may have empty space on sides';
      case 'fill':
        return 'Stretches image to fill screen, may distort';
      case 'fitWidth':
        return 'Fits image width, may crop top/bottom';
      case 'fitHeight':
        return 'Fits image height, may crop left/right';
      default:
        return '';
    }
  }
  
  // Modern card builder helper
  Widget _buildModernCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconColor.withOpacity(0.1), iconColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
  
  // Action button builder helper
  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: color.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }
  
  void _showColorPicker(bool isFirstColor) {
    Color pickerColor = isFirstColor ? _gradientColor1 : _gradientColor2;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isFirstColor ? 'Pick Color 1' : 'Pick Color 2'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Select'),
              onPressed: () {
                setState(() {
                  if (isFirstColor) {
                    _gradientColor1 = pickerColor;
                  } else {
                    _gradientColor2 = pickerColor;
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
