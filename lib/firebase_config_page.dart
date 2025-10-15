import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'services/dynamic_firebase_options.dart';

class FirebaseConfigPage extends StatefulWidget {
  const FirebaseConfigPage({Key? key}) : super(key: key);

  @override
  State<FirebaseConfigPage> createState() => _FirebaseConfigPageState();
}

class _FirebaseConfigPageState extends State<FirebaseConfigPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _useCustomConfig = false;
  
  // Platform selection
  String _selectedPlatform = 'web';
  
  // Text controllers for each platform
  final Map<String, Map<String, TextEditingController>> _controllers = {
    'web': {},
    'android': {},
    'ios': {},
    'macos': {},
    'windows': {},
  };
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadConfiguration();
  }
  
  void _initializeControllers() {
    // Web controllers
    _controllers['web'] = {
      'apiKey': TextEditingController(),
      'appId': TextEditingController(),
      'messagingSenderId': TextEditingController(),
      'projectId': TextEditingController(),
      'authDomain': TextEditingController(),
      'databaseURL': TextEditingController(),
      'storageBucket': TextEditingController(),
      'measurementId': TextEditingController(),
    };
    
    // Android controllers
    _controllers['android'] = {
      'apiKey': TextEditingController(),
      'appId': TextEditingController(),
      'messagingSenderId': TextEditingController(),
      'projectId': TextEditingController(),
      'databaseURL': TextEditingController(),
      'storageBucket': TextEditingController(),
    };
    
    // iOS controllers
    _controllers['ios'] = {
      'apiKey': TextEditingController(),
      'appId': TextEditingController(),
      'messagingSenderId': TextEditingController(),
      'projectId': TextEditingController(),
      'databaseURL': TextEditingController(),
      'storageBucket': TextEditingController(),
      'androidClientId': TextEditingController(),
      'iosBundleId': TextEditingController(),
    };
    
    // macOS controllers
    _controllers['macos'] = {
      'apiKey': TextEditingController(),
      'appId': TextEditingController(),
      'messagingSenderId': TextEditingController(),
      'projectId': TextEditingController(),
      'databaseURL': TextEditingController(),
      'storageBucket': TextEditingController(),
      'androidClientId': TextEditingController(),
      'iosBundleId': TextEditingController(),
    };
    
    // Windows controllers
    _controllers['windows'] = {
      'apiKey': TextEditingController(),
      'appId': TextEditingController(),
      'messagingSenderId': TextEditingController(),
      'projectId': TextEditingController(),
      'authDomain': TextEditingController(),
      'databaseURL': TextEditingController(),
      'storageBucket': TextEditingController(),
      'measurementId': TextEditingController(),
    };
  }
  
  Future<void> _loadConfiguration() async {
    setState(() => _isLoading = true);
    
    try {
      // Check if custom config exists
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('firebase_config')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _useCustomConfig = data['useCustomConfig'] ?? false;
        
        // Load configurations for each platform
        for (var platform in _controllers.keys) {
          if (data.containsKey(platform)) {
            final platformData = data[platform] as Map<String, dynamic>;
            platformData.forEach((key, value) {
              if (_controllers[platform]!.containsKey(key)) {
                _controllers[platform]![key]!.text = value?.toString() ?? '';
              }
            });
          }
        }
      } else {
        // Load default values from firebase_options.dart
        _loadDefaultValues();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading configuration: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _loadDefaultValues() {
    // Web
    _controllers['web']!['apiKey']!.text = DefaultFirebaseOptions.web.apiKey;
    _controllers['web']!['appId']!.text = DefaultFirebaseOptions.web.appId;
    _controllers['web']!['messagingSenderId']!.text = DefaultFirebaseOptions.web.messagingSenderId;
    _controllers['web']!['projectId']!.text = DefaultFirebaseOptions.web.projectId;
    _controllers['web']!['authDomain']!.text = DefaultFirebaseOptions.web.authDomain ?? '';
    _controllers['web']!['databaseURL']!.text = DefaultFirebaseOptions.web.databaseURL ?? '';
    _controllers['web']!['storageBucket']!.text = DefaultFirebaseOptions.web.storageBucket ?? '';
    _controllers['web']!['measurementId']!.text = DefaultFirebaseOptions.web.measurementId ?? '';
    
    // Android
    _controllers['android']!['apiKey']!.text = DefaultFirebaseOptions.android.apiKey;
    _controllers['android']!['appId']!.text = DefaultFirebaseOptions.android.appId;
    _controllers['android']!['messagingSenderId']!.text = DefaultFirebaseOptions.android.messagingSenderId;
    _controllers['android']!['projectId']!.text = DefaultFirebaseOptions.android.projectId;
    _controllers['android']!['databaseURL']!.text = DefaultFirebaseOptions.android.databaseURL ?? '';
    _controllers['android']!['storageBucket']!.text = DefaultFirebaseOptions.android.storageBucket ?? '';
    
    // iOS
    _controllers['ios']!['apiKey']!.text = DefaultFirebaseOptions.ios.apiKey;
    _controllers['ios']!['appId']!.text = DefaultFirebaseOptions.ios.appId;
    _controllers['ios']!['messagingSenderId']!.text = DefaultFirebaseOptions.ios.messagingSenderId;
    _controllers['ios']!['projectId']!.text = DefaultFirebaseOptions.ios.projectId;
    _controllers['ios']!['databaseURL']!.text = DefaultFirebaseOptions.ios.databaseURL ?? '';
    _controllers['ios']!['storageBucket']!.text = DefaultFirebaseOptions.ios.storageBucket ?? '';
    _controllers['ios']!['androidClientId']!.text = DefaultFirebaseOptions.ios.androidClientId ?? '';
    _controllers['ios']!['iosBundleId']!.text = DefaultFirebaseOptions.ios.iosBundleId ?? '';
    
    // macOS
    _controllers['macos']!['apiKey']!.text = DefaultFirebaseOptions.macos.apiKey;
    _controllers['macos']!['appId']!.text = DefaultFirebaseOptions.macos.appId;
    _controllers['macos']!['messagingSenderId']!.text = DefaultFirebaseOptions.macos.messagingSenderId;
    _controllers['macos']!['projectId']!.text = DefaultFirebaseOptions.macos.projectId;
    _controllers['macos']!['databaseURL']!.text = DefaultFirebaseOptions.macos.databaseURL ?? '';
    _controllers['macos']!['storageBucket']!.text = DefaultFirebaseOptions.macos.storageBucket ?? '';
    _controllers['macos']!['androidClientId']!.text = DefaultFirebaseOptions.macos.androidClientId ?? '';
    _controllers['macos']!['iosBundleId']!.text = DefaultFirebaseOptions.macos.iosBundleId ?? '';
    
    // Windows
    _controllers['windows']!['apiKey']!.text = DefaultFirebaseOptions.windows.apiKey;
    _controllers['windows']!['appId']!.text = DefaultFirebaseOptions.windows.appId;
    _controllers['windows']!['messagingSenderId']!.text = DefaultFirebaseOptions.windows.messagingSenderId;
    _controllers['windows']!['projectId']!.text = DefaultFirebaseOptions.windows.projectId;
    _controllers['windows']!['authDomain']!.text = DefaultFirebaseOptions.windows.authDomain ?? '';
    _controllers['windows']!['databaseURL']!.text = DefaultFirebaseOptions.windows.databaseURL ?? '';
    _controllers['windows']!['storageBucket']!.text = DefaultFirebaseOptions.windows.storageBucket ?? '';
    _controllers['windows']!['measurementId']!.text = DefaultFirebaseOptions.windows.measurementId ?? '';
  }
  
  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final configData = <String, dynamic>{
        'useCustomConfig': _useCustomConfig,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      // Save all platform configurations
      for (var platform in _controllers.keys) {
        final platformData = <String, dynamic>{};
        _controllers[platform]!.forEach((key, controller) {
          if (controller.text.isNotEmpty) {
            platformData[key] = controller.text;
          }
        });
        configData[platform] = platformData;
      }
      
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('firebase_config')
          .set(configData, SetOptions(merge: true));
      
      // Clear cache so users get updated config on next app restart
      await DynamicFirebaseOptions.clearCache();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuration saved! Please restart the app for changes to take effect.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving configuration: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('Are you sure you want to reset all Firebase configurations to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _useCustomConfig = false;
        _loadDefaultValues();
      });
      
      // Delete custom config from Firestore
      try {
        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('firebase_config')
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Reset to default configuration! Please restart the app.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error resetting configuration: $e')),
          );
        }
      }
    }
  }
  
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool required = true,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: controller.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$label copied to clipboard')),
                    );
                  },
                )
              : null,
        ),
        maxLines: maxLines,
        validator: required
            ? (value) => value?.isEmpty ?? true ? 'Required' : null
            : null,
      ),
    );
  }
  
  Widget _buildPlatformConfig(String platform) {
    final controllers = _controllers[platform]!;
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Common fields for all platforms
        _buildTextField(
          label: 'API Key',
          controller: controllers['apiKey']!,
          hint: 'Your Firebase API Key',
        ),
        _buildTextField(
          label: 'App ID',
          controller: controllers['appId']!,
          hint: 'Your Firebase App ID',
        ),
        _buildTextField(
          label: 'Messaging Sender ID',
          controller: controllers['messagingSenderId']!,
          hint: 'Cloud Messaging sender ID',
        ),
        _buildTextField(
          label: 'Project ID',
          controller: controllers['projectId']!,
          hint: 'Your Firebase project ID',
        ),
        
        // Platform-specific fields
        if (platform == 'web' || platform == 'windows') ...[
          _buildTextField(
            label: 'Auth Domain',
            controller: controllers['authDomain']!,
            required: false,
            hint: 'yourproject.firebaseapp.com',
          ),
          _buildTextField(
            label: 'Measurement ID',
            controller: controllers['measurementId']!,
            required: false,
            hint: 'Google Analytics measurement ID',
          ),
        ],
        
        if (platform == 'ios' || platform == 'macos') ...[
          _buildTextField(
            label: 'iOS Bundle ID',
            controller: controllers['iosBundleId']!,
            required: false,
            hint: 'com.example.app',
          ),
          _buildTextField(
            label: 'Android Client ID',
            controller: controllers['androidClientId']!,
            required: false,
            hint: 'Google Sign-In client ID',
          ),
        ],
        
        // Common optional fields
        _buildTextField(
          label: 'Database URL',
          controller: controllers['databaseURL']!,
          required: false,
          hint: 'Realtime Database URL',
        ),
        _buildTextField(
          label: 'Storage Bucket',
          controller: controllers['storageBucket']!,
          required: false,
          hint: 'yourproject.appspot.com',
        ),
        
        const SizedBox(height: 20),
        
        // Info card
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Find these values in your Firebase Console > Project Settings',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Configuration'),
        actions: [
          if (!_isLoading)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'reset') {
                  _resetToDefaults();
                } else if (value == 'help') {
                  _showHelpDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.restore, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Reset to Defaults'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Help'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Configuration toggle
                  Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Use Custom Firebase Configuration',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            _useCustomConfig
                                ? 'Using custom API keys from this page'
                                : 'Using default API keys from firebase_options.dart',
                            style: TextStyle(
                              fontSize: 12,
                              color: _useCustomConfig ? Colors.green : Colors.grey,
                            ),
                          ),
                          value: _useCustomConfig,
                          onChanged: (value) {
                            setState(() => _useCustomConfig = value);
                          },
                        ),
                        if (_useCustomConfig)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'App restart required after saving changes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Platform tabs
                  Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPlatformTab('web', 'Web', Icons.web),
                          _buildPlatformTab('android', 'Android', Icons.android),
                          _buildPlatformTab('ios', 'iOS', Icons.apple),
                          _buildPlatformTab('macos', 'macOS', Icons.laptop_mac),
                          _buildPlatformTab('windows', 'Windows', Icons.desktop_windows),
                        ],
                      ),
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // Platform configuration
                  Expanded(
                    child: _buildPlatformConfig(_selectedPlatform),
                  ),
                  
                  // Save button
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveConfiguration,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildPlatformTab(String platform, String label, IconData icon) {
    final isSelected = _selectedPlatform == platform;
    
    return InkWell(
      onTap: () {
        setState(() => _selectedPlatform = platform);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Firebase Configuration Help'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How to get Firebase configuration:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Go to Firebase Console (console.firebase.google.com)'),
              const Text('2. Select your project'),
              const Text('3. Click the gear icon > Project Settings'),
              const Text('4. Scroll down to "Your apps" section'),
              const Text('5. Select your platform (Web, Android, iOS, etc.)'),
              const Text('6. Copy the configuration values'),
              const SizedBox(height: 16),
              const Text(
                'Important Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Each platform requires separate configuration'),
              const Text('• API keys are safe to expose in client apps'),
              const Text('• Restart app after saving changes'),
              const Text('• Use security rules to protect your database'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Toggle "Use Custom Configuration" to switch between default and custom Firebase settings.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    _controllers.forEach((platform, controllers) {
      controllers.forEach((key, controller) {
        controller.dispose();
      });
    });
    super.dispose();
  }
}
