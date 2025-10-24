import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'services/school_context.dart';

/// Simple 3-step wizard for registering a school in the default (shared) database
/// Premium horizontal stepper UI matching Firebase wizard design
class SchoolRegistrationSimpleWizard extends StatefulWidget {
  const SchoolRegistrationSimpleWizard({Key? key}) : super(key: key);

  @override
  State<SchoolRegistrationSimpleWizard> createState() => _SchoolRegistrationSimpleWizardState();
}

class _SchoolRegistrationSimpleWizardState extends State<SchoolRegistrationSimpleWizard> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step titles for horizontal stepper
  final List<String> _stepTitles = [
    'School Details',
    'Admin Details',
    'Complete',
  ];

  // Form data
  final _schoolNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  String? _generatedSchoolId;
  String? _generatedAdminPassword;

  @override
  void dispose() {
    _schoolNameController.dispose();
    _adminNameController.dispose();
    _adminPhoneController.dispose();
    _adminEmailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  /// Generate unique school ID in format: SCHOOL_ABC_123456
  String _generateSchoolId() {
    final random = Random();
    
    // Generate 3 random uppercase letters
    String letters = '';
    for (int i = 0; i < 3; i++) {
      letters += String.fromCharCode(65 + random.nextInt(26)); // A-Z
    }
    
    // Generate 6 random digits
    String digits = '';
    for (int i = 0; i < 6; i++) {
      digits += random.nextInt(10).toString(); // 0-9
    }
    
    return 'SCHOOL_${letters}_$digits';
  }

  /// Generate random password for admin
  String _generatePassword() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#';
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Check if school ID already exists
  Future<bool> _isSchoolIdUnique(String schoolId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('school_registrations')
          .doc(schoolId)
          .get();
      return !doc.exists;
    } catch (e) {
      print('Error checking school ID: $e');
      return false;
    }
  }

  /// Register school in Firestore
  Future<void> _registerSchool() async {
    setState(() => _isLoading = true);

    try {
      // Generate unique school ID
      String schoolId;
      bool isUnique = false;
      int attempts = 0;
      
      do {
        schoolId = _generateSchoolId();
        isUnique = await _isSchoolIdUnique(schoolId);
        attempts++;
      } while (!isUnique && attempts < 10);

      if (!isUnique) {
        throw Exception('Failed to generate unique School ID. Please try again.');
      }

      _generatedSchoolId = schoolId;
      _generatedAdminPassword = _generatePassword();

      // Create school registration document
      await FirebaseFirestore.instance
          .collection('school_registrations')
          .doc(schoolId)
          .set({
        'schoolId': schoolId,
        'schoolName': _schoolNameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'adminName': _adminNameController.text.trim(),
        'adminPhone': _adminPhoneController.text.trim(),
        'adminEmail': _adminEmailController.text.trim(),
        'useSharedDatabase': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'registrationType': 'default_db',
      });

      // Create admin user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc()
          .set({
        'schoolId': schoolId,
        'userId': 'ADMIN001',
        'name': _adminNameController.text.trim(),
        'phone': _adminPhoneController.text.trim(),
        'email': _adminEmailController.text.trim(),
        'password': _generatedAdminPassword, // In production, hash this!
        'role': 'admin',
        'isApproved': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔥 IMPORTANT: Save School ID to SchoolContext so user can login immediately
      await SchoolContext.setSchool(schoolId, _schoolNameController.text.trim());

      setState(() {
        _isLoading = false;
        _currentStep = 2; // Move to success step
      });
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Register Your School',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Simple Step Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSimpleStep(1, 'School', _currentStep >= 0),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        _buildSimpleStep(2, 'Admin', _currentStep >= 1),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        _buildSimpleStep(3, 'Complete', _currentStep >= 2),
                      ],
                    ),
                  ),
                ),
                
                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
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

  Widget _buildSimpleStep(int stepNumber, String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.shade600 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$stepNumber',
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildSchoolDetailsStep();
      case 1:
        return _buildAdminDetailsStep();
      case 2:
        return _buildSuccessStep();
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
          if (_currentStep > 0 && _currentStep < 2)
            TextButton(
              onPressed: () {
                setState(() => _currentStep--);
              },
              child: const Text('Back'),
            )
          else
            const SizedBox(width: 80),
          
          if (_currentStep < 2)
            ElevatedButton(
              onPressed: _isLoading ? null : _onNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                elevation: 0,
              ),
              child: Text(_currentStep == 1 ? 'Create School' : 'Next'),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(_generatedSchoolId);
                Navigator.of(context).pop(_generatedSchoolId);
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Go to Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSchoolDetailsStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'School Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your school details to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _schoolNameController,
            decoration: const InputDecoration(
              labelText: 'School Name *',
              prefixIcon: Icon(Icons.school, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'School name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address *',
              prefixIcon: Icon(Icons.location_on, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Address is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City *',
                    prefixIcon: Icon(Icons.location_city, size: 20),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State *',
                    prefixIcon: Icon(Icons.map, size: 20),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'State is required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Administrator Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up the primary admin account for your school',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _adminNameController,
          decoration: const InputDecoration(
            labelText: 'Admin Name *',
            prefixIcon: Icon(Icons.person, size: 20),
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Admin name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _adminPhoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number *',
            prefixIcon: Icon(Icons.phone, size: 20),
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Phone number is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _adminEmailController,
          decoration: const InputDecoration(
            labelText: 'Email Address *',
            prefixIcon: Icon(Icons.email, size: 20),
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email is required';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School Registered Successfully!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your school has been created in the shared database',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        Text(
          'School Credentials',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        
        _buildCredentialCard(
          icon: Icons.school,
          label: 'School ID',
          value: _generatedSchoolId ?? 'Generating...',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        
        _buildCredentialCard(
          icon: Icons.person,
          label: 'Admin ID',
          value: 'ADMIN001',
          color: Colors.purple,
        ),
        const SizedBox(height: 12),
        
        _buildCredentialCard(
          icon: Icons.lock,
          label: 'Admin Password',
          value: _generatedAdminPassword ?? 'Generating...',
          color: Colors.orange,
        ),
        const SizedBox(height: 24),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important - Save These Credentials',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please copy and save these credentials securely. You will need them to log in to your school account.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialCard({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            color: Colors.grey.shade600,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied to clipboard'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onNextStep() async {
    if (_currentStep == 0) {
      if (_formKey.currentState?.validate() ?? false) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_adminNameController.text.trim().isEmpty ||
          _adminPhoneController.text.trim().isEmpty ||
          _adminEmailController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all admin details')),
        );
        return;
      }
      
      // Create school
      await _registerSchool();
      
      if (context.mounted && _generatedSchoolId != null) {
        setState(() => _currentStep = 2);
      }
    }
  }
}
