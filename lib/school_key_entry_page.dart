import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'school_registration_page.dart';

class SchoolKeyEntryPage extends StatefulWidget {
  const SchoolKeyEntryPage({Key? key}) : super(key: key);

  @override
  State<SchoolKeyEntryPage> createState() => _SchoolKeyEntryPageState();
}

class _SchoolKeyEntryPageState extends State<SchoolKeyEntryPage> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _validateAndSaveKey() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final schoolKey = _keyController.text.trim().toUpperCase();
      
      // Fetch school configuration from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('school_registrations')
          .doc(schoolKey)
          .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = 'Invalid School Key. Please check and try again.';
          _isLoading = false;
        });
        return;
      }

      final data = doc.data()!;
      
      // Check if school is active
      if (data['isActive'] != true) {
        setState(() {
          _errorMessage = 'This school key has been deactivated. Contact your admin.';
          _isLoading = false;
        });
        return;
      }

      // Save school key and Firebase config to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('school_key', schoolKey);
      await prefs.setString('school_name', data['schoolName'] ?? '');
      
      // Save Firebase configuration to local storage
      if (data.containsKey('firebaseConfig')) {
        final firebaseConfig = data['firebaseConfig'] as Map<String, dynamic>;
        await prefs.setString('firebase_config', firebaseConfig.toString());
        
        // Save detailed config for each platform
        firebaseConfig.forEach((platform, config) async {
          if (config is Map) {
            final platformConfig = Map<String, dynamic>.from(config);
            await prefs.setString('firebase_config_$platform', platformConfig.toString());
          }
        });
      }

      // Mark that key has been entered
      await prefs.setBool('has_school_key', true);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${data['schoolName']}!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back with success
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validating key: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _useDefaultConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_default_firebase', true);
      await prefs.setBool('has_school_key', true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using default Firebase configuration'),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _navigateToRegistration() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SchoolRegistrationPage()),
    );

    if (result != null && result is String) {
      // School key was generated, auto-fill it
      _keyController.text = result;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo/Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.school,
                            size: 64,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Title
                        const Text(
                          'Welcome!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        const Text(
                          'Enter your School Firebase Key',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Key Input Field
                        TextFormField(
                          controller: _keyController,
                          decoration: InputDecoration(
                            labelText: 'School Firebase Key',
                            hintText: 'SCHOOL_XXXXX_123456',
                            prefixIcon: const Icon(Icons.vpn_key),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.paste, size: 20),
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null) {
                                  _keyController.text = data!.text!;
                                }
                              },
                            ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter your school key';
                            }
                            if (!value!.startsWith('SCHOOL_')) {
                              return 'Invalid key format';
                            }
                            return null;
                          },
                        ),
                        
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _validateAndSaveKey,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle),
                            label: Text(_isLoading ? 'Validating...' : 'Connect'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Create New School Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _navigateToRegistration,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Register New School'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Use Default Button
                        TextButton.icon(
                          onPressed: _useDefaultConfiguration,
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('Use Default Configuration'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Info Text
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, 
                                    size: 16, 
                                    color: Colors.blue.shade700
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Need help?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Get the key from your school admin\n'
                                '• Register new school if you\'re an admin\n'
                                '• Use default config for testing',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }
}
