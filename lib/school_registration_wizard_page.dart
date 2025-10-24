import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'firebase_options.dart';
import 'services/dynamic_firebase_options.dart';
import 'services/firebase_project_verifier.dart';
import 'services/school_context.dart';

/// Modern step-by-step wizard for school registration
/// Premium horizontal stepper UI similar to Google's Material Design
class SchoolRegistrationWizardPage extends StatefulWidget {
  const SchoolRegistrationWizardPage({Key? key}) : super(key: key);

  @override
  State<SchoolRegistrationWizardPage> createState() => _SchoolRegistrationWizardPageState();
}

class _SchoolRegistrationWizardPageState extends State<SchoolRegistrationWizardPage> with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animationController;
  
  // School Information (loaded from existing registration)
  Map<String, dynamic>? _schoolData;
  bool _isLoadingSchool = false;
  String? _schoolId;
  bool _isPasswordVisible = false; // For password visibility toggle
  
  // Step 2: Firebase Project Selection
  List<Map<String, dynamic>> _userProjects = [];
  String? _selectedProjectId;
  String? _accessToken;
  String? _loggedInEmail; // Track logged-in Google account
  bool _isLoadingProjects = false;
  bool _isVerifyingProject = false;
  final _projectIdController = TextEditingController();
  Map<String, dynamic>? _billingInfo;
  Timer? _debounceTimer; // For auto-verify debouncing
  String? _apiKeyMessage; // Message about API key fetch status
  bool _apiKeyMissing = false; // Track if API key needs to be enabled
  
  // Step 3: Firebase Configuration
  String _selectedPlatform = 'web';
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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeFirebaseControllers();
    _loadDefaultFirebaseValues();
    _loadExistingSchoolData();
  }
  
  Future<void> _loadExistingSchoolData() async {
    debugPrint('🔄 Loading existing school data...');
    setState(() => _isLoadingSchool = true);
    
    try {
      // Use SchoolContext which is already initialized
      final existingKey = SchoolContext.currentSchoolIdOrNull;
      debugPrint('📝 School key from SchoolContext: $existingKey');
      
      if (existingKey != null && existingKey.isNotEmpty) {
        _schoolId = existingKey;
        
        // Load school data from Firestore (using DEFAULT Firebase, not new one)
        debugPrint('🔍 Fetching school data from Firestore for key: $existingKey');
        final doc = await FirebaseFirestore.instance
            .collection('school_registrations')
            .doc(existingKey)
            .get();
        
        debugPrint('📄 Document exists: ${doc.exists}');
        
        if (doc.exists) {
          final data = doc.data();
          
          // Also fetch admin user credentials
          debugPrint('🔍 Fetching admin credentials...');
          final adminQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('schoolId', isEqualTo: existingKey)
              .where('role', isEqualTo: 'admin')
              .limit(1)
              .get();
          
          debugPrint('📄 Admin query found ${adminQuery.docs.length} results');
          
          if (adminQuery.docs.isNotEmpty) {
            final adminData = adminQuery.docs.first.data();
            debugPrint('Admin data: ${adminData.toString()}');
            data!['adminUserId'] = adminData['userId'] ?? 'N/A';
            data['adminPassword'] = adminData['password'] ?? 'N/A';
            debugPrint('✅ Admin credentials loaded: userId=${data['adminUserId']}, password=${data['adminPassword']}');
          } else {
            debugPrint('⚠️ No admin user found for this school');
            data!['adminUserId'] = 'N/A';
            data['adminPassword'] = 'N/A';
          }
          
          setState(() {
            _schoolData = data;
            _schoolData!['schoolKey'] = existingKey;
            _isLoadingSchool = false;
          });
          debugPrint('✅ Loaded school data for: ${_schoolData!['schoolName']}');
        } else {
          setState(() => _isLoadingSchool = false);
          debugPrint('❌ School document not found in Firestore');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('School not found. Please register first.')),
            );
          }
        }
      } else {
        setState(() => _isLoadingSchool = false);
        debugPrint('❌ No school key in SchoolContext');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No school key found. Please register first.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoadingSchool = false);
      debugPrint('❌ Error loading school: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading school: $e')),
        );
      }
    }
  }

  void _initializeFirebaseControllers() {
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
    _firebaseControllers['web']!['apiKey']!.text = DefaultFirebaseOptions.web.apiKey;
    _firebaseControllers['web']!['appId']!.text = DefaultFirebaseOptions.web.appId;
    _firebaseControllers['web']!['messagingSenderId']!.text = DefaultFirebaseOptions.web.messagingSenderId;
    _firebaseControllers['web']!['projectId']!.text = DefaultFirebaseOptions.web.projectId;
    _firebaseControllers['web']!['authDomain']!.text = DefaultFirebaseOptions.web.authDomain ?? '';
    _firebaseControllers['web']!['storageBucket']!.text = DefaultFirebaseOptions.web.storageBucket ?? '';
    _firebaseControllers['web']!['measurementId']!.text = DefaultFirebaseOptions.web.measurementId ?? '';
    
    _firebaseControllers['android']!['apiKey']!.text = DefaultFirebaseOptions.android.apiKey;
    _firebaseControllers['android']!['appId']!.text = DefaultFirebaseOptions.android.appId;
    _firebaseControllers['android']!['messagingSenderId']!.text = DefaultFirebaseOptions.android.messagingSenderId;
    _firebaseControllers['android']!['projectId']!.text = DefaultFirebaseOptions.android.projectId;
    _firebaseControllers['android']!['storageBucket']!.text = DefaultFirebaseOptions.android.storageBucket ?? '';
    
    _firebaseControllers['ios']!['apiKey']!.text = DefaultFirebaseOptions.ios.apiKey;
    _firebaseControllers['ios']!['appId']!.text = DefaultFirebaseOptions.ios.appId;
    _firebaseControllers['ios']!['messagingSenderId']!.text = DefaultFirebaseOptions.ios.messagingSenderId;
    _firebaseControllers['ios']!['projectId']!.text = DefaultFirebaseOptions.ios.projectId;
    _firebaseControllers['ios']!['storageBucket']!.text = DefaultFirebaseOptions.ios.storageBucket ?? '';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _projectIdController.dispose();
    _debounceTimer?.cancel();
    for (var platform in _firebaseControllers.values) {
      for (var controller in platform.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  final List<String> _stepTitles = [
    'Firebase Project',
    'API Configuration',
    'Review & Complete',
  ];

  final List<IconData> _stepIcons = [
    Icons.cloud_outlined,
    Icons.settings_applications_rounded,
    Icons.check_circle_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Set up your school',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
      ),
      body: Column(
        children: [
          // Premium Horizontal Stepper Header
          _buildHorizontalStepper(),
          
          // Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),
          
          // Navigation Buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildHorizontalStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(_stepTitles.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line - Google style (very subtle)
            int stepIndex = index ~/ 2;
            bool isCompleted = _currentStep > stepIndex;
            
            return Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: isCompleted ? Colors.blue.shade600 : Colors.grey.shade300,
              ),
            );
          } else {
            // Step indicator
            int stepIndex = index ~/ 2;
            bool isCompleted = _currentStep > stepIndex;
            bool isActive = _currentStep == stepIndex;
            
            return _buildStepIndicator(
              stepIndex: stepIndex,
              isCompleted: isCompleted,
              isActive: isActive,
            );
          }
        }),
      ),
    );
  }

  Widget _buildStepIndicator({
    required int stepIndex,
    required bool isCompleted,
    required bool isActive,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Simple circle - Google style (minimal, flat)
        Container(
          width: isActive ? 32 : 28,
          height: isActive ? 32 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.blue.shade600
                : isActive
                    ? Colors.blue.shade600
                    : Colors.grey.shade300,
          ),
          child: Center(
            child: isCompleted
                ? Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _stepTitles[stepIndex],
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
            color: isActive
                ? Colors.grey.shade800
                : isCompleted
                    ? Colors.grey.shade700
                    : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildFirebaseProjectStep();
      case 1:
        return _buildAPIConfigurationStep();
      case 2:
        return _buildReviewStep();
      default:
        return Container();
    }
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: Text(
                'Back',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              ),
            )
          else
            const SizedBox(),
          
          if (_currentStep < 3)
            ElevatedButton(
              onPressed: _onStepContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            )
          else
            ElevatedButton(
              onPressed: _completeRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  // STEP 1: School Registration
  // STEP 1: Firebase Project Selection
  Widget _buildFirebaseProjectStep() {
    // Show centered logo and connect button if not yet connected
    if (_userProjects.isEmpty && !_isLoadingProjects && _accessToken == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Firebase Logo - Smaller, Google-style
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.15),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 32,
                color: Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect to Firebase',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Link your Firebase project to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUserProjects,
              icon: const Icon(Icons.cloud_outlined, size: 18),
              label: const Text(
                'Connect to Your Firebase',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      );
    }

    // Show animated checklist after connection
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Firebase logo (moved to top after connection)
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: Colors.orange.shade600,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Firebase Project',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Setting up your project...',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Checklist
        _buildChecklistItem(
          icon: Icons.account_circle,
          title: 'Sign in to Google',
          subtitle: _loggedInEmail ?? 'Authenticating...',
          isCompleted: _accessToken != null,
          isLoading: _isLoadingProjects && _accessToken == null,
        ),
        
        _buildChecklistItem(
          icon: Icons.cloud_sync,
          title: 'Load Firebase Projects',
          subtitle: _userProjects.isEmpty 
              ? 'Fetching your projects...' 
              : 'Found ${_userProjects.length} project(s)',
          isCompleted: _userProjects.isNotEmpty,
          isLoading: _isLoadingProjects,
        ),
        
        // Project Selection Checklist Item
        if (_userProjects.isNotEmpty) ...[
          _buildChecklistItem(
            icon: Icons.folder_special,
            title: 'Select Your Project',
            subtitle: _selectedProjectId == null 
                ? 'Choose a project from the list below' 
                : 'Selected: $_selectedProjectId',
            isCompleted: _selectedProjectId != null,
            isLoading: false,
          ),
          
          // Project List
          if (_selectedProjectId == null) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 52),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _userProjects.map((project) {
                  final projectId = project['projectId'] as String;
                  final displayName = project['displayName'] ?? projectId;
                  
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedProjectId = projectId;
                          _projectIdController.text = projectId;
                        });
                        _verifyFirebaseProject();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              color: Colors.blue.shade400,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    projectId,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey.shade400,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
        
        // Verification Checklist Item
        if (_selectedProjectId != null) ...[
          _buildChecklistItem(
            icon: Icons.verified_user,
            title: 'Verify Project & Fetch Config',
            subtitle: _isVerifyingProject 
                ? 'Checking billing and creating apps...'
                : _billingInfo != null 
                    ? 'Billing: ${_billingInfo!['billingPlan'] ?? 'Unknown'}'
                    : 'Waiting to verify...',
            isCompleted: _billingInfo != null && !_isVerifyingProject && !_apiKeyMissing,
            isLoading: _isVerifyingProject,
          ),
          
          // API Key Status Checklist Item (show if API keys couldn't be fetched)
          if (_apiKeyMissing && !_isVerifyingProject) ...[
            Container(
              margin: const EdgeInsets.only(left: 48, top: 8, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'API Keys API Not Enabled',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _apiKeyMessage ?? 'Could not fetch API keys automatically. Please enable the API Keys API.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  // Show the actual link
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            onTap: () => _openEnableApiKeysPage(),
                            child: Text(
                              'https://console.cloud.google.com/apis/library/apikeys.googleapis.com?project=$_selectedProjectId',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _openEnableApiKeysPage(),
                          child: Icon(Icons.open_in_new, size: 14, color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Click the link above to enable, then refresh',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ),
                      IconButton(
                        onPressed: _verifyFirebaseProject,
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Retry fetching API keys',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          backgroundColor: Colors.blue.shade50,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Manual API Key Input Section
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Or Enter API Keys Manually',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No apps registered yet?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'If you don\'t see any apps (🌐 Web, 🤖 Android, 🍎 iOS) in "Your apps" section, you need to add them first:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionStep('1', 'In Firebase Console, look for "Add app" buttons'),
                        _buildInstructionStep('2', 'Click the 🌐 Web icon to add Web app'),
                        _buildInstructionStep('3', 'Give it a name (e.g., "School Management Web")'),
                        _buildInstructionStep('4', 'After registration, you\'ll see the config with apiKey'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openFirebaseConsoleApiKeys(),
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('Add Web App Manually'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  textStyle: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isVerifyingProject ? null : _autoCreateFirebaseApps,
                                icon: _isVerifyingProject 
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.auto_awesome, size: 16),
                                label: Text(_isVerifyingProject ? 'Creating...' : 'Auto-Create All Apps'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  textStyle: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Single button to open Firebase Console
                  ElevatedButton.icon(
                    onPressed: () => _openFirebaseConsoleApiKeys(),
                    icon: const Icon(Icons.open_in_browser, size: 18),
                    label: const Text('Open Firebase Console'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    '1. Click your app (Web/Android/iOS)\n2. Download config file or copy API key\n3. Upload file below or paste API key',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  
                  // Upload buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _uploadAndroidConfig(),
                          icon: const Icon(Icons.android, size: 16),
                          label: const Text('Upload Android'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _uploadiOSConfig(),
                          icon: const Icon(Icons.apple, size: 16),
                          label: const Text('Upload iOS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Web API Key Input
                  TextField(
                    controller: _firebaseControllers['web']!['apiKey'],
                    decoration: InputDecoration(
                      labelText: 'Web API Key *',
                      hintText: 'AIzaSy...',
                      prefixIcon: const Icon(Icons.key, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste, size: 18),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            setState(() {
                              _firebaseControllers['web']!['apiKey']!.text = data!.text!;
                            });
                          }
                        },
                        tooltip: 'Paste from clipboard',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  // Android API Key Input
                  TextField(
                    controller: _firebaseControllers['android']!['apiKey'],
                    decoration: InputDecoration(
                      labelText: 'Android API Key *',
                      hintText: 'AIzaSy...',
                      prefixIcon: const Icon(Icons.android, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste, size: 18),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            setState(() {
                              _firebaseControllers['android']!['apiKey']!.text = data!.text!;
                            });
                          }
                        },
                        tooltip: 'Paste from clipboard',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  // iOS API Key Input
                  TextField(
                    controller: _firebaseControllers['ios']!['apiKey'],
                    decoration: InputDecoration(
                      labelText: 'iOS API Key *',
                      hintText: 'AIzaSy...',
                      prefixIcon: const Icon(Icons.apple, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste, size: 18),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            setState(() {
                              _firebaseControllers['ios']!['apiKey']!.text = data!.text!;
                            });
                          }
                        },
                        tooltip: 'Paste from clipboard',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Mark API keys as entered manually
                        setState(() {
                          _apiKeyMissing = false;
                          _billingInfo = {
                            'billingEnabled': true,
                            'billingPlan': 'Manual Entry',
                          };
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ API keys entered manually. You can now continue to next step.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Submit API Keys'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'After submitting, the verification will be marked complete.',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
          
          // Billing Warning (show if billing not enabled)
          if (_billingInfo != null && _billingInfo!['billingEnabled'] == false && !_isVerifyingProject) ...[
            Container(
              margin: const EdgeInsets.only(left: 48, top: 8, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Billing Not Enabled (Free Tier)',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your project is on Spark (Free) plan. Upgrade to Blaze (Pay as you go) to use this school management system.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.card_giftcard, color: Colors.green.shade700, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Good news: \$300 free credits for 90 days!',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            onTap: () => _openUpgradeToBlazePageBlaze(),
                            child: Text(
                              'https://console.firebase.google.com/project/$_selectedProjectId/usage/details',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade700,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _openUpgradeToBlazePageBlaze(),
                          child: Icon(Icons.open_in_new, size: 14, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Click the link above to upgrade, then refresh',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ),
                      IconButton(
                        onPressed: _verifyFirebaseProject,
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Check billing status again',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.orange.shade700,
                          backgroundColor: Colors.orange.shade50,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
        
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        
        // Billing Info Display - REMOVED (not needed)
        // Manual Project ID Input - REMOVED (not needed)
      ],
    );
  }

  // Helper widget for info rows - REMOVED
  
  // Build Step 3: Firebase API Configuration
  Widget _buildStep3() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 3 content will be here
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isLoading,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted 
                  ? Colors.green.shade50 
                  : isLoading 
                      ? Colors.blue.shade50 
                      : Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted 
                    ? Colors.green.shade400 
                    : isLoading 
                        ? Colors.blue.shade400 
                        : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                  )
                : Icon(
                    isCompleted ? Icons.check_circle : icon,
                    color: isCompleted 
                        ? Colors.green.shade600 
                        : Colors.grey.shade400,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.green.shade900 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 3: API Configuration
  Widget _buildAPIConfigurationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚙️ Configure API Keys',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Platform-specific configuration',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        
        // Platform Selector
        Wrap(
          spacing: 8,
          children: ['web', 'android', 'ios'].map((platform) {
            return ChoiceChip(
              label: Text(platform.toUpperCase()),
              selected: _selectedPlatform == platform,
              onSelected: (selected) {
                if (selected) setState(() => _selectedPlatform = platform);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        
        // Platform Config Fields
        ..._buildPlatformFields(_selectedPlatform),
      ],
    );
  }

  List<Widget> _buildPlatformFields(String platform) {
    final controllers = _firebaseControllers[platform]!;
    final fields = ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'storageBucket'];
    
    return fields.map((field) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TextFormField(
          controller: controllers[field],
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: field,
            labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            isDense: true,
          ),
        ),
      );
    }).toList();
  }

  // STEP 3: Review
  Widget _buildReviewStep() {
    // Show loading state only if still loading
    if (_isLoadingSchool) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading school information...',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    
    // If not loading but still no data, show error
    if (_schoolData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              SizedBox(height: 16),
              Text(
                'School information not available',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                'Please make sure you are logged in with a registered school.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Google-style title
          const Text(
            'Review & Link Firebase',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Color(0xFF202124),
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Link your Firebase project to this school',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),
          
          // School Information Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school_rounded, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'School Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildReviewItem('School Key', _schoolData!['schoolKey'] ?? _schoolId ?? 'N/A'),
                _buildReviewItem('School Name', _schoolData!['schoolName'] ?? 'N/A'),
                _buildReviewItem('Administrator', _schoolData!['adminName'] ?? 'N/A'),
                _buildReviewItem('Email', _schoolData!['adminEmail'] ?? 'N/A'),
                if (_schoolData!['adminPhone'] != null && _schoolData!['adminPhone'].toString().isNotEmpty)
                  _buildReviewItem('Phone', _schoolData!['adminPhone']),
                const SizedBox(height: 16),
                Divider(color: Colors.blue.shade200, height: 1),
                const SizedBox(height: 16),
                Text(
                  'Admin Login Credentials',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 12),
                _buildReviewItem('Admin ID', _schoolData!['adminUserId'] ?? 'ADMIN001'),
                _buildPasswordReviewItem('Password', _schoolData!['adminPassword'] ?? 'N/A'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Divider(color: Colors.grey.shade300, height: 1),
          const SizedBox(height: 24),
          
          // Firebase Project Section
          _buildReviewItem('Firebase Project', _projectIdController.text),
          if (_billingInfo != null)
            _buildReviewItem('Billing Plan', _billingInfo!['billingPlan'] ?? 'Unknown'),
          
          const SizedBox(height: 32),
          
          // Link Firebase Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link_rounded, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ready to Link',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect your Firebase project to ${_schoolData!['schoolName']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoadingSchool ? null : _linkFirebaseToSchool,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: _isLoadingSchool
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Link Firebase to School',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF202124),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isPasswordVisible ? value : '••••••••',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF202124),
                      fontWeight: FontWeight.w500,
                      letterSpacing: _isPasswordVisible ? 0 : 2,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                  tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step Navigation
  void _onStepContinue() async {
    if (_currentStep == 0) {
      // Step 1: Firebase project validation
      if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or enter a Firebase project')),
        );
        return;
      }
      if (_billingInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify your Firebase project first')),
        );
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      // Step 2: Validate all API keys are filled
      bool allApiKeysFilled = true;
      String missingKeys = '';
      
      // Check Web API key
      if (_firebaseControllers['web']!['apiKey']!.text.trim().isEmpty) {
        allApiKeysFilled = false;
        missingKeys += 'Web API Key, ';
      }
      
      // Check Android API key
      if (_firebaseControllers['android']!['apiKey']!.text.trim().isEmpty) {
        allApiKeysFilled = false;
        missingKeys += 'Android API Key, ';
      }
      
      // Check iOS API key
      if (_firebaseControllers['ios']!['apiKey']!.text.trim().isEmpty) {
        allApiKeysFilled = false;
        missingKeys += 'iOS API Key, ';
      }
      
      if (!allApiKeysFilled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Please fill all required API keys: ${missingKeys.substring(0, missingKeys.length - 2)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      
      setState(() => _currentStep++);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // Create School Registration
  // Link Firebase to existing school
  Future<void> _linkFirebaseToSchool() async {
    if (_schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School ID not found')),
      );
      return;
    }
    
    setState(() => _isLoadingSchool = true);
    
    try {
      // Save Firebase configuration to Firestore or SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Save API keys for each platform
      await prefs.setString('firebase_web_apiKey', _firebaseControllers['web']!['apiKey']!.text);
      await prefs.setString('firebase_android_apiKey', _firebaseControllers['android']!['apiKey']!.text);
      await prefs.setString('firebase_ios_apiKey', _firebaseControllers['ios']!['apiKey']!.text);
      await prefs.setString('firebase_projectId', _projectIdController.text);
      
      setState(() => _isLoadingSchool = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Firebase linked to ${_schoolData!['schoolName']}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return to previous page
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoadingSchool = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error linking Firebase: $e')),
        );
      }
    }
  }

  // Load User Projects
  Future<void> _loadUserProjects() async {
    setState(() => _isLoadingProjects = true);
    
    try {
      final token = await FirebaseProjectVerifier.signInWithGoogle();
      if (token == null) {
        throw Exception('Failed to sign in');
      }
      
      // Get the logged-in email
      final email = await FirebaseProjectVerifier.getCurrentUserEmail();
      
      final projects = await FirebaseProjectVerifier.listUserProjects(accessToken: token);
      
      setState(() {
        _accessToken = token;
        _loggedInEmail = email;
        _userProjects = projects ?? [];
        _isLoadingProjects = false;
      });
    } catch (e) {
      setState(() => _isLoadingProjects = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading projects: $e')),
        );
      }
    }
  }

  // Verify Firebase Project (with AUTO-CREATE apps)
  Future<void> _verifyFirebaseProject() async {
    setState(() => _isVerifyingProject = true);
    
    try {
      String? token = _accessToken;
      if (token == null) {
        token = await FirebaseProjectVerifier.signInWithGoogle();
        if (token == null) throw Exception('Failed to authenticate');
        _accessToken = token;
      }
      
      // Use AUTO-CREATE function instead of just verify
      print('🚀 Using AUTO-CREATE function to create apps and fetch keys...');
      final result = await FirebaseProjectVerifier.autoCreateAppsAndFetchConfig(
        projectId: _selectedProjectId!,
        accessToken: token,
        androidPackageName: 'com.school.management',
        iosBundleId: 'com.school.management',
      );
      
      if (result == null) throw Exception('Failed to verify project');
      
      print('🔍 Full verification result: $result');
      print('🔍 Config data: ${result['config']}');
      
      // Track previous billing state
      final wasBillingDisabled = _billingInfo != null && _billingInfo!['billingEnabled'] == false;
      
      setState(() {
        _billingInfo = {
          'billingEnabled': result['billingEnabled'] ?? false,
          'billingPlan': result['billingPlan'] ?? 'Unknown',
          'billingAccountName': result['billingAccountName'] ?? '',
          'billingCheckError': result['billingCheckError'],
        };
        _apiKeyMessage = result['apiKeyMessage'];
        _isVerifyingProject = false;
      });
      
      // Show success message if billing was just enabled
      if (wasBillingDisabled && result['billingEnabled'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Billing enabled! Plan: ${result['billingPlan'] ?? 'Blaze'}. You can now proceed.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // Auto-fill API keys if available
      if (result['config'] != null) {
        print('✅ Config found, calling auto-fill...');
        _autoFillAPIKeys(result['config']);
        
        // Check if API keys are empty after auto-fill
        final webApiKey = _firebaseControllers['web']!['apiKey']!.text;
        final androidApiKey = _firebaseControllers['android']!['apiKey']!.text;
        final iosApiKey = _firebaseControllers['ios']!['apiKey']!.text;
        
        if (webApiKey.isEmpty || androidApiKey.isEmpty || iosApiKey.isEmpty) {
          print('⚠️ API keys are empty. API Keys API may not be enabled...');
          setState(() => _apiKeyMissing = true);
          // Don't show popup - user will see warning card in the UI
        } else {
          print('✅ API keys fetched successfully!');
          final wasApiKeyMissing = _apiKeyMissing;
          setState(() => _apiKeyMissing = false);
          
          // Show success message if this was a retry after enabling API
          if (wasApiKeyMissing && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ API keys fetched successfully! You can now proceed.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        print('⚠️ No config data in response!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No API keys found. Make sure you have created Web/Android/iOS apps in Firebase Console.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
      
      if (mounted) {
        _showBillingStatusSnackBar(result);
      }
    } catch (e) {
      setState(() => _isVerifyingProject = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showBillingStatusSnackBar(Map<String, dynamic> status) {
    final billingEnabled = status['billingEnabled'] ?? false;
    final billingPlan = status['billingPlan'] ?? 'Unknown';
    final appsCreated = status['appsCreated'];
    
    // Build message about created apps
    String appsMessage = '';
    if (appsCreated != null) {
      final webCreated = appsCreated['web'] == true;
      final androidCreated = appsCreated['android'] == true;
      final iosCreated = appsCreated['ios'] == true;
      
      if (webCreated || androidCreated || iosCreated) {
        appsMessage = '\n🎉 Apps created: ';
        if (webCreated) appsMessage += 'Web ';
        if (androidCreated) appsMessage += 'Android ';
        if (iosCreated) appsMessage += 'iOS';
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan: $billingPlan'),
            Text('Status: ${billingEnabled ? "Active ✅" : "Free Tier - Upgrade to Blaze ⚠️"}'),
            if (appsMessage.isNotEmpty) Text(appsMessage),
          ],
        ),
        backgroundColor: billingEnabled ? Colors.green.shade700 : Colors.orange.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Auto-create Web, Android, and iOS apps in Firebase
  Future<void> _autoCreateFirebaseApps() async {
    if (_selectedProjectId == null || _accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Firebase project first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingProject = true;
      _apiKeyMessage = 'Creating Web, Android, and iOS apps...';
    });

    try {
      final result = await FirebaseProjectVerifier.autoCreateAppsAndFetchConfig(
        projectId: _selectedProjectId!,
        accessToken: _accessToken!,
      );

      if (result != null && result['success'] == true) {
        // Extract config data
        final configData = result['config'];
        final apiKeyMessage = result['apiKeyMessage'];
        
        if (configData != null) {
          // Check if API keys are empty
          bool apiKeysEmpty = true;
          
          // Populate all platform fields
          for (var platform in ['web', 'android', 'ios']) {
            if (configData.containsKey(platform)) {
              final platformData = configData[platform] as Map<String, dynamic>;
              platformData.forEach((key, value) {
                if (_firebaseControllers[platform]!.containsKey(key)) {
                  final stringValue = value?.toString() ?? '';
                  _firebaseControllers[platform]![key]!.text = stringValue;
                  
                  // Check if we got actual API keys
                  if (key == 'apiKey' || key == 'api_key' || key == 'current_key') {
                    if (stringValue.isNotEmpty && stringValue != 'EMPTY') {
                      apiKeysEmpty = false;
                    }
                  }
                }
              });
            }
          }

          setState(() {
            _billingInfo = {
              'billingEnabled': result['billingEnabled'] ?? false,
              'billingPlan': result['billingPlan'] ?? 'Unknown',
            };
            
            // If API keys are empty, keep the warning visible
            if (apiKeysEmpty) {
              _apiKeyMissing = true;
              _apiKeyMessage = apiKeyMessage ?? 'Apps created! Now copy API keys manually (see instructions below)';
            } else {
              _apiKeyMissing = false;
            }
            
            _isVerifyingProject = false;
          });

          if (mounted) {
            if (apiKeysEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Apps created successfully! Now manually copy the API keys from Firebase Console using the instructions below.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 6),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Successfully created all apps and fetched API keys!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        } else {
          setState(() {
            _isVerifyingProject = false;
            _apiKeyMessage = result['message'] ?? 'Could not create apps. Please try manual method.';
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to create apps'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        setState(() {
          _isVerifyingProject = false;
          _apiKeyMessage = 'Auto-create failed. Please use manual method.';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Could not auto-create apps. Please add them manually in Firebase Console.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isVerifyingProject = false;
        _apiKeyMessage = 'Error: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error auto-creating apps: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Upload and parse Android config file
  Future<void> _uploadAndroidConfig() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final jsonString = utf8.decode(result.files.single.bytes!);
        final jsonData = json.decode(jsonString);
        
        // Extract API key from google-services.json
        // Structure: client[0].api_key[0].current_key
        if (jsonData['client'] != null && jsonData['client'].isNotEmpty) {
          final client = jsonData['client'][0];
          
          // Get current_key (API key)
          if (client['api_key'] != null && client['api_key'].isNotEmpty) {
            final apiKey = client['api_key'][0]['current_key'];
            
            setState(() {
              _firebaseControllers['android']!['apiKey']!.text = apiKey ?? '';
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Android API key extracted successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else {
            throw Exception('API key not found in google-services.json');
          }
        } else {
          throw Exception('Invalid google-services.json format');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error reading Android config: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Upload and parse iOS config file
  Future<void> _uploadiOSConfig() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final plistString = utf8.decode(result.files.single.bytes!);
        
        // Parse plist format (XML parsing with multiple patterns)
        // Try different regex patterns for API_KEY
        String? apiKey;
        
        // Pattern 1: <key>API_KEY</key>\n<string>VALUE</string>
        var apiKeyMatch = RegExp(
          r'<key>API_KEY</key>\s*<string>([^<]+)</string>',
          multiLine: true,
          caseSensitive: false,
        ).firstMatch(plistString);
        
        if (apiKeyMatch != null && apiKeyMatch.group(1) != null) {
          apiKey = apiKeyMatch.group(1)!.trim();
        }
        
        // Pattern 2: Try without newlines
        if (apiKey == null || apiKey.isEmpty) {
          apiKeyMatch = RegExp(
            r'<key>API_KEY</key><string>([^<]+)</string>',
            caseSensitive: false,
          ).firstMatch(plistString);
          
          if (apiKeyMatch != null && apiKeyMatch.group(1) != null) {
            apiKey = apiKeyMatch.group(1)!.trim();
          }
        }
        
        // Pattern 3: Case variations
        if (apiKey == null || apiKey.isEmpty) {
          apiKeyMatch = RegExp(
            r'<key>api_key</key>\s*<string>([^<]+)</string>',
            multiLine: true,
            caseSensitive: false,
          ).firstMatch(plistString);
          
          if (apiKeyMatch != null && apiKeyMatch.group(1) != null) {
            apiKey = apiKeyMatch.group(1)!.trim();
          }
        }
        
        if (apiKey != null && apiKey.isNotEmpty) {
          setState(() {
            _firebaseControllers['ios']!['apiKey']!.text = apiKey!;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ iOS API key extracted successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          throw Exception('API_KEY not found in GoogleService-Info.plist. Please check the file format.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error reading iOS config: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Open Enable API Keys API Page
  Future<void> _openEnableApiKeysPage() async {
    if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Firebase project first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final email = _loggedInEmail ?? '';
    final urlString = email.isNotEmpty
        ? 'https://console.cloud.google.com/apis/library/apikeys.googleapis.com?project=$_selectedProjectId&authuser=$email'
        : 'https://console.cloud.google.com/apis/library/apikeys.googleapis.com?project=$_selectedProjectId';
    final url = Uri.parse(urlString);

    try {
      bool launched = false;
      
      try {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        print('External application launch failed: $e');
      }

      if (!launched) {
        try {
          launched = await launchUrl(url, mode: LaunchMode.platformDefault);
        } catch (e) {
          print('Platform default launch failed: $e');
        }
      }

      if (!launched && mounted) {
        _showManualUrlDialog(urlString);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Open Firebase Console API Keys Page
  Future<void> _openFirebaseConsoleApiKeys() async {
    if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Firebase project first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final email = _loggedInEmail ?? '';
    final urlString = email.isNotEmpty
        ? 'https://console.firebase.google.com/project/$_selectedProjectId/settings/general?authuser=$email'
        : 'https://console.firebase.google.com/project/$_selectedProjectId/settings/general';
    final url = Uri.parse(urlString);

    try {
      bool launched = false;
      
      try {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        print('External application launch failed: $e');
      }

      if (!launched) {
        try {
          launched = await launchUrl(url, mode: LaunchMode.platformDefault);
        } catch (e) {
          print('Platform default launch failed: $e');
        }
      }

      if (!launched && mounted) {
        _showManualUrlDialog(urlString);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Open Upgrade to Blaze Plan Page
  Future<void> _openUpgradeToBlazePageBlaze() async {
    if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Firebase project first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Add authuser parameter to help browser open with correct account
    final email = _loggedInEmail ?? '';
    final urlString = email.isNotEmpty 
        ? 'https://console.firebase.google.com/project/$_selectedProjectId/usage/details?authuser=$email'
        : 'https://console.firebase.google.com/project/$_selectedProjectId/usage/details';
    final url = Uri.parse(urlString);

    try {
      // Try different launch modes
      bool launched = false;
      
      try {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        print('External application mode failed: $e');
      }
      
      if (!launched) {
        try {
          launched = await launchUrl(url, mode: LaunchMode.platformDefault);
        } catch (e) {
          print('Platform default mode failed: $e');
        }
      }
      
      if (!launched) {
        try {
          launched = await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
        } catch (e) {
          print('External non-browser mode failed: $e');
        }
      }
      
      if (launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Opening Firebase Console billing page. Enable Blaze plan there.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        if (mounted) {
          _showManualUrlDialog(urlString);
        }
      }
    } catch (e) {
      if (mounted) {
        _showManualUrlDialog(urlString);
      }
    }
  }

  // Show upgrade to Blaze confirmation dialog - REMOVED, just open link directly
  Future<bool?> _showUpgradeToBlazeDialog() async {
    // Just open the Firebase Console billing page directly
    _openUpgradeToBlazePageBlaze();
    return true;
  }

  // REMOVED - Old dialog code and duplicate methods
  
  // Open Cloud Billing API Enable Page
  Future<void> _openEnableBillingApiPage() async {
    if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Firebase project first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show account verification dialog first
    final confirmed = await _showAccountConfirmationDialog();
    if (confirmed != true) return;

    // Add authuser parameter to help browser open with correct account
    final email = _loggedInEmail ?? '';
    final urlString = email.isNotEmpty
        ? 'https://console.developers.google.com/apis/api/cloudbilling.googleapis.com/overview?project=$_selectedProjectId&authuser=$email'
        : 'https://console.developers.google.com/apis/api/cloudbilling.googleapis.com/overview?project=$_selectedProjectId';
    final url = Uri.parse(urlString);

    try {
      // Try different launch modes for better compatibility
      bool launched = false;
      
      // Try external application first (opens in browser)
      try {
        launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        print('External application mode failed: $e');
      }
      
      // If external app fails, try platform default
      if (!launched) {
        try {
          launched = await launchUrl(
            url,
            mode: LaunchMode.platformDefault,
          );
        } catch (e) {
          print('Platform default mode failed: $e');
        }
      }
      
      // If still not launched, try external non-browser mode
      if (!launched) {
        try {
          launched = await launchUrl(
            url,
            mode: LaunchMode.externalNonBrowserApplication,
          );
        } catch (e) {
          print('External non-browser mode failed: $e');
        }
      }
      
      if (launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Opening Google Cloud Console. Enable the API and come back to verify again.'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        // If all launch methods fail, show URL for manual copy
        if (mounted) {
          _showManualUrlDialog(urlString);
        }
      }
    } catch (e) {
      if (mounted) {
        _showManualUrlDialog(urlString);
      }
    }
  }

  // Show account confirmation dialog
  Future<bool?> _showAccountConfirmationDialog() async {
    final email = _loggedInEmail ?? 'Unknown';
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified_user, color: Colors.blue.shade700, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Important: Verify Account',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current logged-in account
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_circle, size: 24, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'You are signed in as:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.email, size: 20, color: Colors.blue.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              email,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy, size: 18, color: Colors.blue.shade700),
                            tooltip: 'Copy email',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: email));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('📋 Email copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Critical warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CRITICAL: Account Must Match!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your browser MUST be logged into:',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '📌 If your browser is logged into a different account, switch accounts by clicking the profile icon in Google Console.',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Steps
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist, color: Colors.grey.shade700, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'What happens next:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStep('1', 'Browser opens to Google Cloud Console'),
                    _buildStep('2', 'Check profile icon shows: $email'),
                    _buildStep('3', 'If wrong account, click profile → Switch account'),
                    _buildStep('4', 'Click "ENABLE" button for Cloud Billing API'),
                    _buildStep('5', 'Return here and click "Verify & Configure" again'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.open_in_new, size: 20),
            label: const Text('I Understand, Continue', style: TextStyle(fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show dialog with URL to copy manually
  void _showManualUrlDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Cannot Open Browser'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unable to open the browser automatically. Please copy this URL and open it manually in your browser:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '📋 Steps:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Copy the URL above', style: TextStyle(fontSize: 13)),
            const Text('2. Open it in Chrome/Browser', style: TextStyle(fontSize: 13)),
            const Text('3. Click "ENABLE" button', style: TextStyle(fontSize: 13)),
            const Text('4. Return here and verify again', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ URL copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Copy URL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _autoFillAPIKeys(Map<String, dynamic> config) {
    print('═══════════════════════════════════════════════════════');
    print('🔑 AUTO-FILL API KEYS STARTED');
    print('═══════════════════════════════════════════════════════');
    print('📦 Config received: $config');
    
    int fieldsFilledCount = 0;
    
    // Web platform
    if (config['web'] != null && config['web'] is Map) {
      print('\n📱 FILLING WEB CONFIG:');
      final webConfig = config['web'] as Map<String, dynamic>;
      
      final webApiKey = webConfig['apiKey']?.toString() ?? '';
      final webAppId = webConfig['appId']?.toString() ?? '';
      final webMessagingSenderId = webConfig['messagingSenderId']?.toString() ?? '';
      final webProjectId = webConfig['projectId']?.toString() ?? '';
      final webAuthDomain = webConfig['authDomain']?.toString() ?? '';
      final webStorageBucket = webConfig['storageBucket']?.toString() ?? '';
      final webMeasurementId = webConfig['measurementId']?.toString() ?? '';
      
      _firebaseControllers['web']!['apiKey']!.text = webApiKey;
      _firebaseControllers['web']!['appId']!.text = webAppId;
      _firebaseControllers['web']!['messagingSenderId']!.text = webMessagingSenderId;
      _firebaseControllers['web']!['projectId']!.text = webProjectId;
      _firebaseControllers['web']!['authDomain']!.text = webAuthDomain;
      _firebaseControllers['web']!['storageBucket']!.text = webStorageBucket;
      _firebaseControllers['web']!['measurementId']!.text = webMeasurementId;
      
      if (webApiKey.isNotEmpty) fieldsFilledCount++;
      if (webAppId.isNotEmpty) fieldsFilledCount++;
      if (webProjectId.isNotEmpty) fieldsFilledCount++;
      
      print('  ✅ apiKey: ${webApiKey.length > 10 ? webApiKey.substring(0, 10) + "..." : webApiKey.isEmpty ? "EMPTY" : webApiKey}');
      print('  ✅ appId: $webAppId');
      print('  ✅ messagingSenderId: $webMessagingSenderId');
      print('  ✅ projectId: $webProjectId');
      print('  ✅ authDomain: $webAuthDomain');
      print('  ✅ storageBucket: $webStorageBucket');
      print('  ✅ measurementId: $webMeasurementId');
      print('  ✅ WEB CONFIG FILLED SUCCESSFULLY!');
    } else {
      print('\n⚠️ NO WEB CONFIG - Skipping web platform');
    }
    
    // Android platform
    if (config['android'] != null && config['android'] is Map) {
      print('\n🤖 FILLING ANDROID CONFIG:');
      final androidConfig = config['android'] as Map<String, dynamic>;
      
      final androidAppId = androidConfig['mobilesdk_app_id']?.toString() ?? '';
      final androidApiKey = androidConfig['current_key']?.toString() ?? '';
      final androidProjectId = androidConfig['project_id']?.toString() ?? '';
      final androidStorageBucket = androidConfig['storage_bucket']?.toString() ?? '';
      final androidMessagingSenderId = androidConfig['messaging_sender_id']?.toString() ?? androidConfig['project_number']?.toString() ?? '';
      
      _firebaseControllers['android']!['appId']!.text = androidAppId;
      _firebaseControllers['android']!['apiKey']!.text = androidApiKey;
      _firebaseControllers['android']!['projectId']!.text = androidProjectId;
      _firebaseControllers['android']!['storageBucket']!.text = androidStorageBucket;
      _firebaseControllers['android']!['messagingSenderId']!.text = androidMessagingSenderId;
      
      if (androidAppId.isNotEmpty) fieldsFilledCount++;
      if (androidApiKey.isNotEmpty) fieldsFilledCount++;
      if (androidProjectId.isNotEmpty) fieldsFilledCount++;
      
      print('  ✅ appId (mobilesdk_app_id): $androidAppId');
      print('  ✅ apiKey (current_key): ${androidApiKey.length > 10 ? androidApiKey.substring(0, 10) + "..." : androidApiKey.isEmpty ? "EMPTY" : androidApiKey}');
      print('  ✅ projectId (project_id): $androidProjectId');
      print('  ✅ messagingSenderId: $androidMessagingSenderId');
      print('  ✅ storageBucket: $androidStorageBucket');
      print('  ✅ ANDROID CONFIG FILLED SUCCESSFULLY!');
    } else {
      print('\n⚠️ NO ANDROID CONFIG - Skipping android platform');
    }
    
    // iOS platform
    if (config['ios'] != null && config['ios'] is Map) {
      print('\n🍎 FILLING IOS CONFIG:');
      final iosConfig = config['ios'] as Map<String, dynamic>;
      
      final iosAppId = iosConfig['mobilesdk_app_id']?.toString() ?? '';
      final iosApiKey = iosConfig['api_key']?.toString() ?? '';
      final iosProjectId = iosConfig['project_id']?.toString() ?? '';
      final iosStorageBucket = iosConfig['storage_bucket']?.toString() ?? '';
      
      _firebaseControllers['ios']!['appId']!.text = iosAppId;
      _firebaseControllers['ios']!['apiKey']!.text = iosApiKey;
      _firebaseControllers['ios']!['projectId']!.text = iosProjectId;
      _firebaseControllers['ios']!['storageBucket']!.text = iosStorageBucket;
      
      if (iosAppId.isNotEmpty) fieldsFilledCount++;
      if (iosApiKey.isNotEmpty) fieldsFilledCount++;
      if (iosProjectId.isNotEmpty) fieldsFilledCount++;
      
      print('  ✅ appId (mobilesdk_app_id): $iosAppId');
      print('  ✅ apiKey (api_key): ${iosApiKey.length > 10 ? iosApiKey.substring(0, 10) + "..." : iosApiKey.isEmpty ? "EMPTY" : iosApiKey}');
      print('  ✅ projectId (project_id): $iosProjectId');
      print('  ✅ storageBucket: $iosStorageBucket');
      print('  ✅ IOS CONFIG FILLED SUCCESSFULLY!');
    } else {
      print('\n⚠️ NO IOS CONFIG - Skipping ios platform');
    }

    // 🍎 Fill macOS config
    if (config['macos'] != null) {
      print('\n🍎 FILLING MACOS CONFIG:');
      final macosApiKey = config['macos']['api_key']?.toString() ?? '';
      final macosAppId = config['macos']['mobilesdk_app_id']?.toString() ?? '';
      final macosProjectId = config['macos']['project_id']?.toString() ?? '';
      final macosStorageBucket = config['macos']['storage_bucket']?.toString() ?? '';
      
      _firebaseControllers['macos']!['apiKey']!.text = macosApiKey;
      _firebaseControllers['macos']!['appId']!.text = macosAppId;
      _firebaseControllers['macos']!['projectId']!.text = macosProjectId;
      _firebaseControllers['macos']!['storageBucket']!.text = macosStorageBucket;
      
      if (macosAppId.isNotEmpty) fieldsFilledCount++;
      if (macosApiKey.isNotEmpty) fieldsFilledCount++;
      if (macosProjectId.isNotEmpty) fieldsFilledCount++;
      
      print('  ✅ appId (mobilesdk_app_id): $macosAppId');
      print('  ✅ apiKey (api_key): ${macosApiKey.length > 10 ? macosApiKey.substring(0, 10) + "..." : macosApiKey.isEmpty ? "EMPTY" : macosApiKey}');
      print('  ✅ projectId (project_id): $macosProjectId');
      print('  ✅ storageBucket: $macosStorageBucket');
      print('  ✅ MACOS CONFIG FILLED SUCCESSFULLY!');
    } else {
      print('\n⚠️ NO MACOS CONFIG - Skipping macos platform');
    }

    // 🪟 Fill Windows config
    if (config['windows'] != null) {
      print('\n🪟 FILLING WINDOWS CONFIG:');
      final windowsApiKey = config['windows']['apiKey']?.toString() ?? '';
      final windowsAppId = config['windows']['appId']?.toString() ?? '';
      final windowsProjectId = config['windows']['projectId']?.toString() ?? '';
      final windowsStorageBucket = config['windows']['storageBucket']?.toString() ?? '';
      final windowsMessagingSenderId = config['windows']['messagingSenderId']?.toString() ?? '';
      final windowsAuthDomain = config['windows']['authDomain']?.toString() ?? '';
      
      _firebaseControllers['windows']!['apiKey']!.text = windowsApiKey;
      _firebaseControllers['windows']!['appId']!.text = windowsAppId;
      _firebaseControllers['windows']!['messagingSenderId']!.text = windowsMessagingSenderId;
      _firebaseControllers['windows']!['projectId']!.text = windowsProjectId;
      _firebaseControllers['windows']!['authDomain']!.text = windowsAuthDomain;
      _firebaseControllers['windows']!['storageBucket']!.text = windowsStorageBucket;
      
      if (windowsApiKey.isNotEmpty) fieldsFilledCount++;
      if (windowsAppId.isNotEmpty) fieldsFilledCount++;
      if (windowsProjectId.isNotEmpty) fieldsFilledCount++;
      
      print('  ✅ apiKey: ${windowsApiKey.length > 10 ? windowsApiKey.substring(0, 10) + "..." : windowsApiKey.isEmpty ? "EMPTY" : windowsApiKey}');
      print('  ✅ appId: $windowsAppId');
      print('  ✅ messagingSenderId: $windowsMessagingSenderId');
      print('  ✅ projectId: $windowsProjectId');
      print('  ✅ authDomain: $windowsAuthDomain');
      print('  ✅ storageBucket: $windowsStorageBucket');
      print('  ✅ WINDOWS CONFIG FILLED SUCCESSFULLY!');
    } else {
      print('\n⚠️ NO WINDOWS CONFIG - Skipping windows platform');
    }
    
    print('\n═══════════════════════════════════════════════════════');
    print('✅ AUTO-FILL COMPLETED!');
    print('📊 Total fields filled: $fieldsFilledCount');
    print('═══════════════════════════════════════════════════════\n');
    
    // Force UI update
    setState(() {});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ API keys auto-filled! ($fieldsFilledCount fields)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Complete Registration
  Future<void> _completeRegistration() async {
    // Check if school data is loaded
    if (_schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('School ID not found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Save Firebase configuration
    try {
      final firebaseConfig = <String, dynamic>{};
      _firebaseControllers.forEach((platform, controllers) {
        firebaseConfig[platform] = {
          for (var entry in controllers.entries)
            entry.key: entry.value.text,
        };
      });
      
      await FirebaseFirestore.instance
          .collection('school_registrations')
          .doc(_schoolId)
          .update({'firebaseConfig': firebaseConfig});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Setup complete! Welcome aboard'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Navigate back and return the school key
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, _schoolId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing registration: $e')),
        );
      }
    }
  }
}
