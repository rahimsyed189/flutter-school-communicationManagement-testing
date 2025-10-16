import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'firebase_options.dart';
import 'services/dynamic_firebase_options.dart';
import 'services/firebase_project_verifier.dart';

/// Premium horizontal stepper wizard for school registration
/// Material Design 3 style with horizontal progress indicator
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

  final List<String> _stepTitles = [
    'School Info',
    'Firebase Project',
    'API Configuration',
    'Complete',
  ];

  final List<IconData> _stepIcons = [
    Icons.school_rounded,
    Icons.cloud_outlined,
    Icons.settings_applications_rounded,
    Icons.check_circle_outline_rounded,
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('School Registration'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Premium Horizontal Stepper Header
          _buildHorizontalStepper(),
          
          // Content Area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildStepContent(),
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_stepTitles.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            int stepIndex = index ~/ 2;
            bool isCompleted = _currentStep > stepIndex;
            bool isActive = _currentStep == stepIndex + 1;
            
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCompleted
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : isActive
                            ? [Colors.blue.shade300, Colors.blue.shade100]
                            : [Colors.grey.shade300, Colors.grey.shade300],
                  ),
                ),
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 56 : 48,
          height: isActive ? 56 : 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isCompleted
                ? LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : isActive
                    ? LinearGradient(
                        colors: [Colors.blue.shade500, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade400],
                      ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.blue.shade300.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : _stepIcons[stepIndex],
            color: Colors.white,
            size: isActive ? 28 : 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _stepTitles[stepIndex],
          style: TextStyle(
            fontSize: isActive ? 13 : 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? Colors.blue.shade700
                : isCompleted
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    return SingleChildScrollView(
      key: ValueKey(_currentStep),
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: _getStepWidget(_currentStep),
        ),
      ),
    );
  }

  Widget _getStepWidget(int step) {
    switch (step) {
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            )
          else
            const SizedBox(),
          
          if (_currentStep < 3)
            ElevatedButton.icon(
              onPressed: _onStepContinue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _completeRegistration,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Complete Registration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // STEP 1: School Registration
  Widget _buildSchoolRegistrationStep() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School Information',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Enter your school details to get started',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _schoolNameController,
                decoration: InputDecoration(
                  labelText: 'School Name *',
                  prefixIcon: const Icon(Icons.school),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _adminNameController,
                decoration: InputDecoration(
                  labelText: 'Admin Name *',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _adminEmailController,
                decoration: InputDecoration(
                  labelText: 'Admin Email *',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (!value!.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _adminPhoneController,
                decoration: InputDecoration(
                  labelText: 'Admin Phone *',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                onPressed: _isCreatingSchool ? null : _generateSchoolKey,
                icon: _isCreatingSchool 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.generating_tokens),
                label: Text(_generatedKey == null ? 'Generate School Key' : 'Regenerate Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              if (_generatedKey != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'School Key Generated!',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                _generatedKey!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _generatedKey!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('School key copied!')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded),
                              tooltip: 'Copy to clipboard',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Keep all the existing step building methods and logic methods from the original file
  // (I'll import them from the old file to save space)
  Widget _buildFirebaseProjectStep() {
    // TODO: Copy from original file - Firebase project selection UI
    return const Center(child: Text('Firebase Project Step - TODO'));
  }

  Widget _buildAPIConfigurationStep() {
    // TODO: Copy from original file - API configuration UI
    return const Center(child: Text('API Configuration Step - TODO'));
  }

  Widget _buildReviewStep() {
    // TODO: Copy from original file - Review UI
    return const Center(child: Text('Review Step - TODO'));
  }

  void _generateSchoolKey() async {
    // TODO: Copy from original file
  }

  void _onStepContinue() {
    // TODO: Copy from original file
  }

  void _completeRegistration() async {
    // TODO: Copy from original file
  }
}
