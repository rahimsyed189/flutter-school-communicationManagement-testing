import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'firebase_options.dart';
import 'services/dynamic_firebase_options.dart';
import 'services/firebase_project_verifier.dart';

class SchoolRegistrationPage extends StatefulWidget {
  const SchoolRegistrationPage({Key? key}) : super(key: key);

  @override
  State<SchoolRegistrationPage> createState() => _SchoolRegistrationPageState();
}

class _SchoolRegistrationPageState extends State<SchoolRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  
  bool _isLoading = false;
  bool _showFirebaseConfig = false;
  bool _isVerifyingProject = false;
  bool _isLoadingProjects = false;
  String _creationProgress = '';
  String? _generatedKey;
  
  // Project ID for verification
  final _projectIdController = TextEditingController();
  
  // Project list feature
  List<Map<String, dynamic>> _userProjects = [];
  String? _selectedProjectId;
  String? _accessToken;
  
  // Platform selection
  String _selectedPlatform = 'web';
  
  // Firebase config controllers for each platform
  final Map<String, Map<String, TextEditingController>> _firebaseControllers = {
    'web': {},
    'android': {},
    'ios': {},
    'macos': {},
    'windows': {},
  };

  @override
  void initState() {
    super.initState();
    _initializeFirebaseControllers();
    _loadDefaultFirebaseValues();
  }

  void _initializeFirebaseControllers() {
    // Initialize controllers for all platforms
    for (var platform in _firebaseControllers.keys) {
      _firebaseControllers[platform] = {
        'apiKey': TextEditingController(),
        'appId': TextEditingController(),
        'messagingSenderId': TextEditingController(),
        'projectId': TextEditingController(),
        'authDomain': TextEditingController(),
        'databaseURL': TextEditingController(),
        'storageBucket': TextEditingController(),
        'measurementId': TextEditingController(),
        'androidClientId': TextEditingController(),
        'iosBundleId': TextEditingController(),
      };
    }
  }

  void _loadDefaultFirebaseValues() {
    // Pre-fill with default values from firebase_options.dart
    // Web
    _firebaseControllers['web']!['apiKey']!.text = DefaultFirebaseOptions.web.apiKey;
    _firebaseControllers['web']!['appId']!.text = DefaultFirebaseOptions.web.appId;
    _firebaseControllers['web']!['messagingSenderId']!.text = DefaultFirebaseOptions.web.messagingSenderId;
    _firebaseControllers['web']!['projectId']!.text = DefaultFirebaseOptions.web.projectId;
    _firebaseControllers['web']!['authDomain']!.text = DefaultFirebaseOptions.web.authDomain ?? '';
    _firebaseControllers['web']!['databaseURL']!.text = DefaultFirebaseOptions.web.databaseURL ?? '';
    _firebaseControllers['web']!['storageBucket']!.text = DefaultFirebaseOptions.web.storageBucket ?? '';
    _firebaseControllers['web']!['measurementId']!.text = DefaultFirebaseOptions.web.measurementId ?? '';
    
    // Android
    _firebaseControllers['android']!['apiKey']!.text = DefaultFirebaseOptions.android.apiKey;
    _firebaseControllers['android']!['appId']!.text = DefaultFirebaseOptions.android.appId;
    _firebaseControllers['android']!['messagingSenderId']!.text = DefaultFirebaseOptions.android.messagingSenderId;
    _firebaseControllers['android']!['projectId']!.text = DefaultFirebaseOptions.android.projectId;
    _firebaseControllers['android']!['databaseURL']!.text = DefaultFirebaseOptions.android.databaseURL ?? '';
    _firebaseControllers['android']!['storageBucket']!.text = DefaultFirebaseOptions.android.storageBucket ?? '';
    
    // iOS
    _firebaseControllers['ios']!['apiKey']!.text = DefaultFirebaseOptions.ios.apiKey;
    _firebaseControllers['ios']!['appId']!.text = DefaultFirebaseOptions.ios.appId;
    _firebaseControllers['ios']!['messagingSenderId']!.text = DefaultFirebaseOptions.ios.messagingSenderId;
    _firebaseControllers['ios']!['projectId']!.text = DefaultFirebaseOptions.ios.projectId;
    _firebaseControllers['ios']!['databaseURL']!.text = DefaultFirebaseOptions.ios.databaseURL ?? '';
    _firebaseControllers['ios']!['storageBucket']!.text = DefaultFirebaseOptions.ios.storageBucket ?? '';
    _firebaseControllers['ios']!['androidClientId']!.text = DefaultFirebaseOptions.ios.androidClientId ?? '';
    _firebaseControllers['ios']!['iosBundleId']!.text = DefaultFirebaseOptions.ios.iosBundleId ?? '';
    
    // macOS
    _firebaseControllers['macos']!['apiKey']!.text = DefaultFirebaseOptions.macos.apiKey;
    _firebaseControllers['macos']!['appId']!.text = DefaultFirebaseOptions.macos.appId;
    _firebaseControllers['macos']!['messagingSenderId']!.text = DefaultFirebaseOptions.macos.messagingSenderId;
    _firebaseControllers['macos']!['projectId']!.text = DefaultFirebaseOptions.macos.projectId;
    _firebaseControllers['macos']!['databaseURL']!.text = DefaultFirebaseOptions.macos.databaseURL ?? '';
    _firebaseControllers['macos']!['storageBucket']!.text = DefaultFirebaseOptions.macos.storageBucket ?? '';
    _firebaseControllers['macos']!['androidClientId']!.text = DefaultFirebaseOptions.macos.androidClientId ?? '';
    _firebaseControllers['macos']!['iosBundleId']!.text = DefaultFirebaseOptions.macos.iosBundleId ?? '';
    
    // Windows
    _firebaseControllers['windows']!['apiKey']!.text = DefaultFirebaseOptions.windows.apiKey;
    _firebaseControllers['windows']!['appId']!.text = DefaultFirebaseOptions.windows.appId;
    _firebaseControllers['windows']!['messagingSenderId']!.text = DefaultFirebaseOptions.windows.messagingSenderId;
    _firebaseControllers['windows']!['projectId']!.text = DefaultFirebaseOptions.windows.projectId;
    _firebaseControllers['windows']!['authDomain']!.text = DefaultFirebaseOptions.windows.authDomain ?? '';
    _firebaseControllers['windows']!['databaseURL']!.text = DefaultFirebaseOptions.windows.databaseURL ?? '';
    _firebaseControllers['windows']!['storageBucket']!.text = DefaultFirebaseOptions.windows.storageBucket ?? '';
    _firebaseControllers['windows']!['measurementId']!.text = DefaultFirebaseOptions.windows.measurementId ?? '';
  }

  String _generateSchoolKey() {
    final random = Random();
    final schoolName = _schoolNameController.text.trim().replaceAll(' ', '_').toUpperCase();
    final randomPart = random.nextInt(999999).toString().padLeft(6, '0');
    return 'SCHOOL_${schoolName}_$randomPart';
  }

  // Load user's Firebase projects (NO BILLING REQUIRED!)
  Future<void> _loadUserProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _creationProgress = 'Signing in with Google...';
      _selectedProjectId = null; // Clear any previous selection
      _userProjects = []; // Clear previous projects list
    });

    try {
      // Step 1: Sign in with Google
      final accessToken = await FirebaseProjectVerifier.signInWithGoogle();
      
      if (accessToken == null) {
        throw Exception('Google Sign-In cancelled or failed');
      }

      // Store token for later verification
      _accessToken = accessToken;

      setState(() {
        _creationProgress = 'Loading your Firebase projects...';
      });

      // Step 2: List user's projects
      final projects = await FirebaseProjectVerifier.listUserProjects(
        accessToken: accessToken,
      );

      setState(() {
        _isLoadingProjects = false;
        _creationProgress = '';
      });

      if (projects == null) {
        throw Exception('Failed to load projects. Please try again.');
      }

      if (projects.isEmpty) {
        // No projects found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 No Firebase projects found.\n\nPlease create a Firebase project first, then come back here.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Projects loaded successfully
      setState(() {
        _userProjects = projects;
        _selectedProjectId = null; // Clear any previous selection
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Found ${projects.length} Firebase project(s)!\nSelect one from the dropdown below.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

    } catch (e) {
      setState(() {
        _isLoadingProjects = false;
        _creationProgress = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Verify selected project from dropdown (with auto-configure)
  Future<void> _verifySelectedProject() async {
    if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please select a project from the dropdown'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please sign in first by clicking "Load My Projects"'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingProject = true;
      _creationProgress = 'Step 1/4: Checking project...';
    });

    try {
      // Step 1: Auto-configure (checks billing, enables services)
      final result = await FirebaseProjectVerifier.autoConfigureProject(
        projectId: _selectedProjectId!,
        accessToken: _accessToken!,
      );

      setState(() => _creationProgress = 'Step 2/4: Checking configuration...');

      // Step 2: Check auto-configure status
      final status = FirebaseProjectVerifier.getAutoConfigureStatus(result);

      // Step 2.5: Show billing status info
      _showBillingStatusInfo(status);

      // Step 3: Handle billing required
      if (status['needsBilling'] == true) {
        setState(() {
          _isVerifyingProject = false;
          _creationProgress = '';
        });

        // Show billing instructions dialog
        _showBillingInstructionsDialog(status['billingInstructions']);
        return;
      }

      // Step 4: Check if configuration successful
      if (!status['success']) {
        throw Exception(status['message'] ?? 'Configuration failed');
      }

      setState(() => _creationProgress = 'Step 3/4: Fetching API keys...');

      // Step 5: Parse and auto-fill forms
      final config = status['config'] as Map<String, dynamic>?;
      if (config != null) {
        final parsedConfigs = FirebaseProjectVerifier.parseFirebaseConfig(config);

        for (var platform in parsedConfigs.keys) {
          final platformConfig = parsedConfigs[platform]!;
          platformConfig.forEach((key, value) {
            if (_firebaseControllers[platform]?.containsKey(key) == true) {
              _firebaseControllers[platform]![key]!.text = value;
            }
          });
        }
      }

      setState(() {
        _isVerifyingProject = false;
        _creationProgress = '';
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Project "$_selectedProjectId" configured!\n${status['message']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

    } catch (e) {
      setState(() {
        _isVerifyingProject = false;
        _creationProgress = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }

  // Show billing status info
  void _showBillingStatusInfo(Map<String, dynamic> status) {
    final billingPlan = status['billingPlan'] ?? 'Unknown';
    final billingEnabled = status['billingEnabled'] ?? false;
    final billingAccount = status['billingAccountName'] ?? 'None';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  billingEnabled ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Billing Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Plan: $billingPlan'),
            Text('Account: $billingAccount'),
            Text('Status: ${billingEnabled ? "Active ✅" : "Not Enabled ❌"}'),
          ],
        ),
        backgroundColor: billingEnabled ? Colors.green.shade700 : Colors.orange.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show billing instructions dialog
  void _showBillingInstructionsDialog(Map<String, dynamic>? billingInfo) {
    if (billingInfo == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Billing Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Status:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Plan: ${billingInfo['billingPlan'] ?? 'Spark (Free)'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.credit_card, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Billing: ${billingInfo['billingAccountName'] ?? 'Not Connected'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  billingInfo['description'] ?? 'Billing must be enabled to continue',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Steps
              const Text(
                'Follow these steps:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              ...(billingInfo['steps'] as List? ?? []).map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${step['number']}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step['action'] ?? '',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                            if (step['details'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                step['details'],
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              ),
                            ],
                            if (step['warning'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '⚠️ ${step['warning']}',
                                style: const TextStyle(fontSize: 12, color: Colors.orange),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 16),

              // Free Tier Info
              if (billingInfo['freeTierInfo'] != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        billingInfo['freeTierInfo']['title'] ?? 'Free Tier',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                      const SizedBox(height: 8),
                      ...(billingInfo['freeTierInfo']['limits'] as List? ?? []).map((limit) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $limit',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      Text(
                        billingInfo['freeTierInfo']['typical'] ?? '',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // User will go to Firebase Console, enable billing, and come back
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('👉 After enabling billing, click "Verify & Configure" again'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 5),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Firebase Console'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Verify existing Firebase project and auto-fetch config
  Future<void> _verifyAndFetchConfig() async {
    final projectId = _projectIdController.text.trim();
    
    if (projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter your Firebase Project ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingProject = true;
      _creationProgress = 'Step 1/4: Signing in with Google...';
    });

    try {
      // Step 1: Sign in with Google
      final accessToken = await FirebaseProjectVerifier.signInWithGoogle();
      
      if (accessToken == null) {
        throw Exception('Google Sign-In cancelled or failed');
      }

      setState(() => _creationProgress = 'Step 2/4: Verifying project setup...');

      // Step 2: Verify project and fetch config
      final result = await FirebaseProjectVerifier.verifyAndFetchConfig(
        projectId: projectId,
        accessToken: accessToken,
      );

      setState(() => _creationProgress = 'Step 3/4: Checking configuration...');

      // Step 3: Check verification status
      final status = FirebaseProjectVerifier.getVerificationStatus(result);

      if (!status['success']) {
        // Show what's missing
        final missing = status['missing'] as List<String>?;
        final suggestions = status['suggestions'] as List<String>?;
        
        String errorMessage = status['message'];
        if (suggestions != null && suggestions.isNotEmpty) {
          errorMessage += '\n\nTo fix:\n${suggestions.map((s) => '• $s').join('\n')}';
        }

        throw Exception(errorMessage);
      }

      setState(() => _creationProgress = 'Step 4/4: Auto-filling forms...');

      // Step 4: Parse and auto-fill forms
      final config = status['config'] as Map<String, dynamic>;
      final parsedConfigs = FirebaseProjectVerifier.parseFirebaseConfig(config);

      for (var platform in parsedConfigs.keys) {
        final platformConfig = parsedConfigs[platform]!;
        platformConfig.forEach((key, value) {
          if (_firebaseControllers[platform]?.containsKey(key) == true) {
            _firebaseControllers[platform]![key]!.text = value;
          }
        });
      }

      setState(() {
        _isVerifyingProject = false;
        _creationProgress = '';
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Project "$projectId" verified!\nAll API keys have been auto-filled.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

    } catch (e) {
      setState(() {
        _isVerifyingProject = false;
        _creationProgress = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Guide',
            textColor: Colors.white,
            onPressed: () {
              // TODO: Show setup guide dialog
            },
          ),
        ),
      );
    }
  }

  Future<void> _registerSchool() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Generate unique school key
      final schoolKey = _generateSchoolKey();
      
      // Prepare Firebase configuration data
      final firebaseConfigData = <String, dynamic>{};
      for (var platform in _firebaseControllers.keys) {
        final platformData = <String, dynamic>{};
        _firebaseControllers[platform]!.forEach((key, controller) {
          if (controller.text.isNotEmpty) {
            platformData[key] = controller.text;
          }
        });
        firebaseConfigData[platform] = platformData;
      }
      
      // Save school registration to Firestore
      await FirebaseFirestore.instance
          .collection('school_registrations')
          .doc(schoolKey)
          .set({
        'schoolKey': schoolKey,
        'schoolName': _schoolNameController.text.trim(),
        'adminName': _adminNameController.text.trim(),
        'adminEmail': _adminEmailController.text.trim(),
        'adminPhone': _adminPhoneController.text.trim(),
        'firebaseConfig': firebaseConfigData,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Clear cache so the new config can be fetched
      await DynamicFirebaseOptions.clearCache();

      setState(() {
        _generatedKey = schoolKey;
        _isLoading = false;
      });

      // Show success dialog with key
      _showSuccessDialog(schoolKey);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering school: $e')),
      );
    }
  }

  void _showSuccessDialog(String key) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('School Registered!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your school has been successfully registered!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Your School Firebase Key:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      key,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: key));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Key copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Important:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Save this key securely\n'
                    '• Share with all school users\n'
                    '• Users need this key to connect\n'
                    '• This key cannot be recovered',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Key copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Key'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, key);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool required = true,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: required
            ? (value) => value?.isEmpty ?? true ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _buildPlatformConfig(String platform) {
    final controllers = _firebaseControllers[platform]!;
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
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
      ],
    );
  }

  Widget _buildPlatformTab(String platform, String label, IconData icon) {
    final isSelected = _selectedPlatform == platform;
    
    return InkWell(
      onTap: () => setState(() => _selectedPlatform = platform),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            Icon(icon, size: 18, color: isSelected ? Colors.blue : Colors.grey),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register School'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // School Info Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.school, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'School Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'School Name',
                      controller: _schoolNameController,
                      hint: 'Enter school name',
                    ),
                    _buildTextField(
                      label: 'Admin Name',
                      controller: _adminNameController,
                      hint: 'Enter admin name',
                    ),
                    _buildTextField(
                      label: 'Admin Email',
                      controller: _adminEmailController,
                      hint: 'admin@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _buildTextField(
                      label: 'Admin Phone',
                      controller: _adminPhoneController,
                      hint: '+1234567890',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Firebase Config Section
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Configure Firebase',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _showFirebaseConfig
                          ? 'Custom Firebase configuration enabled'
                          : 'Using default Firebase configuration',
                      style: TextStyle(
                        fontSize: 12,
                        color: _showFirebaseConfig ? Colors.green : Colors.grey,
                      ),
                    ),
                    secondary: const Icon(Icons.local_fire_department, color: Colors.orange),
                    value: _showFirebaseConfig,
                    onChanged: (value) => setState(() => _showFirebaseConfig = value),
                  ),
                  
                  if (_showFirebaseConfig) ...[
                    const Divider(height: 1),
                    
                    // Verify & Fetch Config Section (RECOMMENDED)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Recommended badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.recommend, size: 16, color: Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'RECOMMENDED - Works for 100% of users',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          const Text(
                            'Verify Existing Firebase Project',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          const Text(
                            'Option 1: Select from your existing projects (easiest!)\n'
                            'Option 2: Enter project ID manually',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          
                          // OPTION 1: Load Projects Button
                          ElevatedButton.icon(
                            onPressed: (_isLoadingProjects || _isVerifyingProject) ? null : _loadUserProjects,
                            icon: _isLoadingProjects
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_download),
                            label: Text(_isLoadingProjects ? 'Loading...' : '🔑 Load My Firebase Projects'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                          
                          // Show dropdown if projects loaded
                          if (_userProjects.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Found ${_userProjects.length} project(s)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _userProjects.any((p) => p['projectId'] == _selectedProjectId) 
                                        ? _selectedProjectId 
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: 'Select Firebase Project *',
                                      prefixIcon: const Icon(Icons.folder_special),
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: _userProjects.map((project) {
                                      final projectId = project['projectId'] as String;
                                      final displayName = project['displayName'] as String;
                                      return DropdownMenuItem<String>(
                                        value: projectId,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              projectId,
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedProjectId = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: (_isVerifyingProject || _selectedProjectId == null) 
                                        ? null 
                                        : _verifySelectedProject,
                                    icon: _isVerifyingProject
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.verified),
                                    label: Text(_isVerifyingProject ? 'Verifying...' : 'Verify & Auto-Fill Forms'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      minimumSize: const Size(double.infinity, 50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 20),
                          
                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade400)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade400)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // OPTION 2: Manual Entry
                          Text(
                            'Option 2: Enter Project ID Manually',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Project ID input field
                          TextFormField(
                            controller: _projectIdController,
                            decoration: InputDecoration(
                              labelText: 'Firebase Project ID *',
                              hintText: 'e.g., my-school-abc123',
                              prefixIcon: const Icon(Icons.folder_special),
                              border: const OutlineInputBorder(),
                              helperText: 'Find this in Firebase Console → Project Settings',
                              helperMaxLines: 2,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.help_outline),
                                tooltip: 'Where to find Project ID',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Finding Your Project ID'),
                                      content: const SingleChildScrollView(
                                        child: Text(
                                          '1. Go to Firebase Console (console.firebase.google.com)\n'
                                          '2. Select your project\n'
                                          '3. Click the ⚙️ Settings icon\n'
                                          '4. Go to "Project settings"\n'
                                          '5. Find "Project ID" at the top\n\n'
                                          'Example: my-school-abc123',
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
                                },
                              ),
                            ),
                            enabled: !_isVerifyingProject,
                          ),
                          const SizedBox(height: 16),
                          
                          // Verify & Fetch button
                          ElevatedButton.icon(
                            onPressed: _isVerifyingProject ? null : _verifyAndFetchConfig,
                            icon: _isVerifyingProject
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.verified),
                            label: Text(_isVerifyingProject ? 'Verifying...' : 'Verify & Fetch Config'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Setup guide button
                          OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Open setup guide
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Firebase Setup Guide'),
                                  content: const SingleChildScrollView(
                                    child: Text(
                                      'Step-by-step guide:\n\n'
                                      '1. Go to console.firebase.google.com\n'
                                      '2. Click "Add project"\n'
                                      '3. Enter your school name\n'
                                      '4. Accept terms and create\n'
                                      '5. Enable billing (required, but free tier available)\n'
                                      '6. Enable Authentication, Firestore, Storage\n'
                                      '7. Register a Web app\n'
                                      '8. Come back and enter your Project ID\n\n'
                                      'See FIREBASE_SETUP_GUIDE_HYBRID.md for detailed instructions.',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.menu_book),
                            label: const Text('View Setup Guide'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                          
                          if (_creationProgress.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _creationProgress,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          const Divider(height: 32),
                        ],
                      ),
                    ),
                    
                    Container(
                      color: Colors.grey.shade100,
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
                    SizedBox(
                      height: 400,
                      child: _buildPlatformConfig(_selectedPlatform),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Register Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _registerSchool,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(_isLoading ? 'Registering...' : 'Register School'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'How it works:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Fill in your school details\n'
                    '2. (Optional) Configure custom Firebase\n'
                    '3. Click Register to generate your School Key\n'
                    '4. Share the key with all school users\n'
                    '5. Users enter this key to connect to your school',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
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

  @override
  void dispose() {
    _schoolNameController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    
    _firebaseControllers.forEach((platform, controllers) {
      controllers.forEach((key, controller) {
        controller.dispose();
      });
    });
    
    super.dispose();
  }
}
