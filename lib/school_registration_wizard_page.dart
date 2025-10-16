import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'firebase_options.dart';
import 'services/dynamic_firebase_options.dart';
import 'services/firebase_project_verifier.dart';

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
  
  // Step 1: School Information
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  String? _generatedKey;
  bool _isCreatingSchool = false;
  
  // Step 2: Firebase Project Selection
  List<Map<String, dynamic>> _userProjects = [];
  String? _selectedProjectId;
  String? _accessToken;
  String? _loggedInEmail; // Track logged-in Google account
  bool _isLoadingProjects = false;
  bool _isVerifyingProject = false;
  final _projectIdController = TextEditingController();
  Map<String, dynamic>? _billingInfo;
  
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
    _schoolNameController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    _projectIdController.dispose();
    for (var platform in _firebaseControllers.values) {
      for (var controller in platform.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  final List<String> _stepTitles = [
    'School Info',
    'Firebase Project',
    'API Configuration',
    'Review & Complete',
  ];

  final List<IconData> _stepIcons = [
    Icons.school_rounded,
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
        return _buildSchoolRegistrationStep();
      case 1:
        return _buildFirebaseProjectStep();
      case 2:
        return _buildAPIConfigurationStep();
      case 3:
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
  Widget _buildSchoolRegistrationStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Google-style title
            const Text(
              'Tell us about your school',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: Color(0xFF202124),
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This information will help us set up your account',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            
            // Google-style text fields (minimal, clean)
            TextFormField(
              controller: _schoolNameController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'School name',
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
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Please enter school name' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _adminNameController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Administrator name',
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
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Please enter administrator name' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _adminEmailController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Email address',
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
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Please enter email address';
                if (!value!.contains('@')) return 'Please enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _adminPhoneController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Phone number (optional)',
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
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  // STEP 2: Firebase Project Selection
  Widget _buildFirebaseProjectStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔥 Connect Firebase Project',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select or verify your Firebase project',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        
        // Load Projects Button
        if (_userProjects.isEmpty && !_isLoadingProjects)
          ElevatedButton.icon(
            onPressed: _loadUserProjects,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Load My Firebase Projects'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        
        if (_isLoadingProjects)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          ),
        
        // Project Dropdown
        if (_userProjects.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            value: _selectedProjectId,
            decoration: const InputDecoration(
              labelText: 'Select Firebase Project',
              prefixIcon: Icon(Icons.folder),
              border: OutlineInputBorder(),
            ),
            items: _userProjects.map((project) {
              return DropdownMenuItem<String>(
                value: project['projectId'] as String?,
                child: Text(project['displayName'] ?? project['projectId']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedProjectId = value;
                _projectIdController.text = value ?? '';
              });
            },
          ),
          const SizedBox(height: 16),
        ],
        
        // Manual Project ID Input
        TextFormField(
          controller: _projectIdController,
          decoration: const InputDecoration(
            labelText: 'Or Enter Project ID Manually',
            prefixIcon: Icon(Icons.vpn_key),
            border: OutlineInputBorder(),
            hintText: 'my-project-id',
          ),
          onChanged: (value) => setState(() => _selectedProjectId = value),
        ),
        const SizedBox(height: 16),
        
        // Verify Button
        ElevatedButton.icon(
          onPressed: _selectedProjectId != null && _selectedProjectId!.isNotEmpty
              ? _verifyFirebaseProject
              : null,
          icon: const Icon(Icons.verified),
          label: const Text('Verify & Auto-Configure'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        
        if (_isVerifyingProject)
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: LinearProgressIndicator(),
          ),
        
        // Billing Info Display
        if (_billingInfo != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _billingInfo!['billingEnabled'] == true
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              border: Border.all(
                color: _billingInfo!['billingEnabled'] == true
                    ? Colors.green.shade300
                    : Colors.orange.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _billingInfo!['billingEnabled'] == true
                          ? Icons.check_circle
                          : Icons.warning,
                      color: _billingInfo!['billingEnabled'] == true
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _billingInfo!['billingEnabled'] == true 
                            ? 'Billing Enabled ✅' 
                            : 'Billing Not Enabled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _billingInfo!['billingEnabled'] == true
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildInfoRow('Plan', _billingInfo!['billingPlan'] ?? 'Unknown'),
                _buildInfoRow('Billing Account', _billingInfo!['billingAccountName'] ?? 'None'),
                _buildInfoRow(
                  'Status',
                  _billingInfo!['billingEnabled'] == true ? 'Active ✅' : 'Free Tier (Spark) ⚠️',
                ),
                
                // Show "Enable Billing API" button if there's a billing check error
                if (_billingInfo!['billingCheckError'] != null && 
                    _billingInfo!['billingCheckError'].toString().contains('Cloud Billing API')) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    '⚠️ Cloud Billing API Not Enabled',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enable the Cloud Billing API to check your billing plan.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openEnableBillingApiPage(),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Enable Billing API'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
                
                // Show "Upgrade to Blaze" button if billing is not enabled (free tier)
                if (_billingInfo!['billingEnabled'] == false && 
                    _billingInfo!['billingCheckError'] == null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your project is on Spark (Free) plan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To use this school management system, you need to upgrade to the Blaze (Pay as you go) plan. This enables required Firebase features.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.card_giftcard, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Good news: You get \$300 free credits for 90 days! Most school systems use less than \$10/month.',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openUpgradeToBlazePageBlaze(),
                    icon: const Icon(Icons.upgrade, size: 18),
                    label: const Text('Upgrade to Blaze Plan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
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
          children: ['web', 'android', 'ios', 'macos', 'windows'].map((platform) {
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
          decoration: InputDecoration(
            labelText: field,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }).toList();
  }

  // STEP 4: Review
  Widget _buildReviewStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Google-style title
          const Text(
            'Review your information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Color(0xFF202124),
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure everything looks right before completing setup',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),
          
          // Review sections - Google style (minimal cards)
          _buildReviewItem('School name', _schoolNameController.text),
          _buildReviewItem('Administrator', _adminNameController.text),
          _buildReviewItem('Email', _adminEmailController.text),
          if (_adminPhoneController.text.isNotEmpty)
            _buildReviewItem('Phone', _adminPhoneController.text),
          
          const SizedBox(height: 24),
          Divider(color: Colors.grey.shade300, height: 1),
          const SizedBox(height: 24),
          
          _buildReviewItem('Firebase project', _projectIdController.text),
          if (_billingInfo != null)
            _buildReviewItem('Billing plan', _billingInfo!['billingPlan'] ?? 'Unknown'),
          
          const SizedBox(height: 32),
          
          // Generate Key Button - Only at the end!
          if (_generatedKey == null) ...[
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
                      Icon(Icons.key_rounded, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Final step',
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
                    'Generate your unique school key to complete the setup',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreatingSchool ? null : _generateSchoolKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: _isCreatingSchool
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Generate school key',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Show generated key
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Setup complete!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your school key',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _generatedKey!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _generatedKey!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Copied to clipboard'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.grey.shade800,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: Icon(Icons.content_copy, size: 20, color: Colors.green.shade700),
                          tooltip: 'Copy key',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Save this key securely. You\'ll need it to access your school account.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  // Step Navigation
  void _onStepContinue() async {
    if (_currentStep == 0) {
      // Just validate form, don't create school yet
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep++);
      }
    } else if (_currentStep == 1) {
      // Validate Firebase project
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
    } else if (_currentStep == 2) {
      setState(() => _currentStep++);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // Create School Registration
  Future<void> _createSchoolRegistration() async {
    setState(() => _isCreatingSchool = true);
    
    try {
      final key = _generateSchoolKey();
      
      await FirebaseFirestore.instance
          .collection('school_registrations')
          .doc(key)
          .set({
        'schoolName': _schoolNameController.text.trim(),
        'adminName': _adminNameController.text.trim(),
        'adminEmail': _adminEmailController.text.trim(),
        'adminPhone': _adminPhoneController.text.trim(),
        'schoolKey': key,
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
      });
      
      setState(() {
        _generatedKey = key;
        _isCreatingSchool = false;
        _currentStep++;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreatingSchool = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _generateSchoolKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
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

  // Verify Firebase Project
  Future<void> _verifyFirebaseProject() async {
    setState(() => _isVerifyingProject = true);
    
    try {
      String? token = _accessToken;
      if (token == null) {
        token = await FirebaseProjectVerifier.signInWithGoogle();
        if (token == null) throw Exception('Failed to authenticate');
        _accessToken = token;
      }
      
      final result = await FirebaseProjectVerifier.verifyAndFetchConfig(
        projectId: _selectedProjectId!,
        accessToken: token,
      );
      
      if (result == null) throw Exception('Failed to verify project');
      
      setState(() {
        _billingInfo = {
          'billingEnabled': result['billingEnabled'] ?? false,
          'billingPlan': result['billingPlan'] ?? 'Unknown',
          'billingAccountName': result['billingAccountName'] ?? '',
          'billingCheckError': result['billingCheckError'],
        };
        _isVerifyingProject = false;
      });
      
      // Auto-fill API keys if available
      if (result['config'] != null) {
        _autoFillAPIKeys(result['config']);
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
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan: $billingPlan'),
            Text('Status: ${billingEnabled ? "Active ✅" : "Free Tier - Upgrade to Blaze ⚠️"}'),
          ],
        ),
        backgroundColor: billingEnabled ? Colors.green.shade700 : Colors.orange.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
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

    // Show confirmation dialog first
    final confirmed = await _showUpgradeToBlazeDialog();
    if (confirmed != true) return;

    final urlString = 'https://console.firebase.google.com/project/$_selectedProjectId/usage/details';
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
            content: Text('✅ Opening Firebase Console. Click "Modify plan" to upgrade to Blaze.'),
            duration: Duration(seconds: 6),
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

  // Show upgrade to Blaze confirmation dialog
  Future<bool?> _showUpgradeToBlazeDialog() async {
    final email = _loggedInEmail ?? 'Unknown';
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upgrade, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Upgrade to Blaze Plan', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current account
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_circle, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Signed in as:', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Free credits info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.celebration, color: Colors.green.shade700, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You Get \$300 FREE Credits!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBulletPoint('✅ \$300 free credits for 90 days'),
                    _buildBulletPoint('✅ Only pay after free credits are used'),
                    _buildBulletPoint('✅ Most schools use <\$10/month'),
                    _buildBulletPoint('✅ You can set spending limits'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // What happens next
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade700, size: 20),
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
                    const SizedBox(height: 10),
                    _buildStep('1', 'Firebase Console opens'),
                    _buildStep('2', 'Click "Modify plan" button'),
                    _buildStep('3', 'Select "Blaze (Pay as you go)"'),
                    _buildStep('4', 'Link billing account (or create one)'),
                    _buildStep('5', 'Confirm upgrade'),
                    _buildStep('6', 'Return here and verify again'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.open_in_new, size: 20),
            label: const Text('Continue to Firebase', style: TextStyle(fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.green.shade900,
          height: 1.3,
        ),
      ),
    );
  }

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

    final urlString = 'https://console.developers.google.com/apis/api/cloudbilling.googleapis.com/overview?project=$_selectedProjectId';
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
    config.forEach((platform, platformConfig) {
      if (_firebaseControllers.containsKey(platform) && platformConfig is Map) {
        platformConfig.forEach((key, value) {
          if (_firebaseControllers[platform]!.containsKey(key)) {
            _firebaseControllers[platform]![key]!.text = value?.toString() ?? '';
          }
        });
      }
    });
  }

  // Complete Registration
  Future<void> _completeRegistration() async {
    // Check if school key is generated
    if (_generatedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate your school key first'),
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
          .doc(_generatedKey)
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
        Navigator.pop(context, _generatedKey);
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
