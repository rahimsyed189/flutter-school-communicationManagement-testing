import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:minio/minio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
    _loadR2Configuration();
    _loadCurrentBackground();
    _loadGradientColors();
    _loadImageFit();
    _loadImageOpacity();
    _loadApplyToPage();
  }
  
  Future<void> _loadGradientColors() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
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
      await FirebaseFirestore.instance
          .collection('app_config')
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
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
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
      await FirebaseFirestore.instance
          .collection('app_config')
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
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
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
      await FirebaseFirestore.instance
          .collection('app_config')
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
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
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
      await FirebaseFirestore.instance
          .collection('app_config')
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
            const SizedBox(height: 24),

            // Gradient Background Colors
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fallback Gradient Colors',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'These colors show while background image is loading',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Gradient Preview
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_gradientColor1, _gradientColor2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Center(
                        child: Text(
                          'Gradient Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Color 1 Picker
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Color 1 (Top-Left)',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showColorPicker(true),
                          child: Container(
                            width: 60,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _gradientColor1,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[400]!, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Color 2 Picker
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Color 2 (Bottom-Right)',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showColorPicker(false),
                          child: Container(
                            width: 60,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _gradientColor2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[400]!, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Save Gradient Button
                    ElevatedButton.icon(
                      onPressed: _saveGradientColors,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Gradient Colors'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Image Alignment / Fit Options
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Image Alignment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose how the background image should fit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Image Fit Dropdown
                    DropdownButtonFormField<String>(
                      value: _imageFit,
                      decoration: InputDecoration(
                        labelText: 'Image Fit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.aspect_ratio),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cover',
                          child: Row(
                            children: [
                              Icon(Icons.crop_free, size: 20),
                              SizedBox(width: 8),
                              Text('Cover (Zoom to Fill)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'contain',
                          child: Row(
                            children: [
                              Icon(Icons.fit_screen, size: 20),
                              SizedBox(width: 8),
                              Text('Contain (Fit Inside)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'fill',
                          child: Row(
                            children: [
                              Icon(Icons.fullscreen, size: 20),
                              SizedBox(width: 8),
                              Text('Fill (Stretch)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'fitWidth',
                          child: Row(
                            children: [
                              Icon(Icons.expand, size: 20),
                              SizedBox(width: 8),
                              Text('Fit Width'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'fitHeight',
                          child: Row(
                            children: [
                              Icon(Icons.unfold_more, size: 20),
                              SizedBox(width: 8),
                              Text('Fit Height'),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getImageFitDescription(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Save Button
                    ElevatedButton.icon(
                      onPressed: _saveImageFit,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Image Alignment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Apply To Pages Selection
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apply Background To',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose which pages should display the background image',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _applyToPage,
                      decoration: const InputDecoration(
                        labelText: 'Select Pages',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pages, color: Colors.blue),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Row(
                            children: [
                              Icon(Icons.select_all, size: 20),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('All Pages'),
                                  Text(
                                    'Login, Admin Home & Other Pages',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'login',
                          child: Row(
                            children: [
                              Icon(Icons.login, size: 20),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Login Page Only'),
                                  Text(
                                    'First page users see',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'admin_home',
                          child: Row(
                            children: [
                              Icon(Icons.home, size: 20),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Admin Home Only'),
                                  Text(
                                    'Main admin dashboard',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveApplyToPage,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Page Selection'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Image Opacity Control
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Image Opacity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Control background image transparency (lower = more transparent)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Opacity Slider
                    Row(
                      children: [
                        const Icon(Icons.opacity, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Transparency Level',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${(_imageOpacity * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _imageOpacity,
                                min: 0.05,
                                max: 1.0,
                                divisions: 19,
                                label: '${(_imageOpacity * 100).toInt()}%',
                                onChanged: (value) {
                                  setState(() => _imageOpacity = value);
                                },
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'More Transparent',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'Less Transparent',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Quick Preset Buttons
                    const Text(
                      'Quick Presets',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _imageOpacity = 0.10),
                            child: const Text('10%'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _imageOpacity = 0.20),
                            child: const Text('20%'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _imageOpacity = 0.50),
                            child: const Text('50%'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _imageOpacity = 1.0),
                            child: const Text('100%'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Save Button
                    ElevatedButton.icon(
                      onPressed: _saveImageOpacity,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Image Opacity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
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
