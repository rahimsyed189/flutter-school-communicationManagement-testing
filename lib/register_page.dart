import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'services/school_context.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _role = 'student';
  String? _selectedClass;
  String? _selectedSubject;
  bool _isLoading = false;
  List<String> _classes = [];
  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      // 🔥 Filter by schoolId
      final classesSnap = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
          .get();
      final subjectsSnap = await FirebaseFirestore.instance
          .collection('subjects')
          .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
          .get();
      setState(() {
        _classes = classesSnap.docs.map((d) => (d['name'] ?? d.id).toString()).toList();
        _subjects = subjectsSnap.docs.map((d) => (d['name'] ?? d.id).toString()).toList();
      });
    } catch (_) {}
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      // Check duplicates by phone/email if provided
      // 🔥 Filter by schoolId - only check within THIS school
      final col = FirebaseFirestore.instance.collection('users');
      final dupPhone = await col
          .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
          .where('phone', isEqualTo: _phoneController.text.trim())
          .limit(1)
          .get();
      if (dupPhone.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone already in use')));
        setState(() { _isLoading = false; });
        return;
      }
      if (_emailController.text.trim().isNotEmpty) {
        // 🔥 Filter by schoolId
        final dupEmail = await col
            .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
            .where('email', isEqualTo: _emailController.text.trim())
            .limit(1)
            .get();
        if (dupEmail.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email already in use')));
          setState(() { _isLoading = false; });
          return;
        }
      }

      final regRef = FirebaseFirestore.instance.collection('registrations').doc();
      await regRef.set({
        'schoolId': SchoolContext.currentSchoolId,  // 🔥 ADD schoolId
        'status': 'pending', // pending|approved|rejected
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
        'role': _role,
        'class': _role == 'student' ? _selectedClass : null,
        'subject': _role == 'staff' ? _selectedSubject : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save pending prefill values so login is autofilled
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_userId', _phoneController.text.trim());
      await prefs.setString('pending_password', _passwordController.text);

  if (!mounted) return;
      // Take user to Login with the values prefilled
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(
            onLoginSuccess: () {},
            prefillUserId: _phoneController.text.trim(),
            prefillPassword: _passwordController.text,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = _role == 'student';
    final isStaff = _role == 'staff';
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 3) ? 'Min 3 chars' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'student'),
              ),
              if (isStudent) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedClass,
                  decoration: const InputDecoration(labelText: 'Class (for student)'),
                  items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedClass = v),
                ),
              ],
              if (isStaff) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  decoration: const InputDecoration(labelText: 'Subject (for staff)'),
                  items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedSubject = v),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitRegistration,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Submit for approval'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
