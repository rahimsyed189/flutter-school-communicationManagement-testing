import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/school_context.dart';

class AdminAddUserPage extends StatefulWidget {
  final String currentUserId;
  const AdminAddUserPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<AdminAddUserPage> createState() => _AdminAddUserPageState();
}

class _AdminAddUserPageState extends State<AdminAddUserPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _role = 'student';
  bool _preEnableNotifications = true;
  bool _isSaving = false;
  bool _loadingOptions = true;

  List<String> _classOptions = [];
  List<String> _subjectOptions = [];
  String? _selectedClass;
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadDropdownOptions();
  }

  Future<void> _loadDropdownOptions() async {
    setState(() => _loadingOptions = true);
    final db = FirebaseFirestore.instance;
    try {
      // Load classes
      final classesSnap = await db
          .collection('classes')
          .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
          .orderBy('order', descending: false)
          .get()
          .catchError((_) async => await db.collection('classes').where('schoolId', isEqualTo: SchoolContext.currentSchoolId).get());
      var classes = classesSnap.docs
          .map((d) => (d.data()['name'] as String?)?.trim())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      if (classes.isEmpty) {
        await db.collection('classes').add({'name': 'Class 1', 'order': 1, 'schoolId': SchoolContext.currentSchoolId});
        await db.collection('classes').add({'name': 'Class 2', 'order': 2, 'schoolId': SchoolContext.currentSchoolId});
        classes = ['Class 1', 'Class 2'];
      }

      // Load subjects
      final subjectsSnap = await db
          .collection('subjects')
          .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
          .orderBy('order', descending: false)
          .get()
          .catchError((_) async => await db.collection('subjects').where('schoolId', isEqualTo: SchoolContext.currentSchoolId).get());
      var subjects = subjectsSnap.docs
          .map((d) => (d.data()['name'] as String?)?.trim())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      if (subjects.isEmpty) {
        await db.collection('subjects').add({'name': 'Subject 1', 'order': 1, 'schoolId': SchoolContext.currentSchoolId});
        await db.collection('subjects').add({'name': 'Subject 2', 'order': 2, 'schoolId': SchoolContext.currentSchoolId});
        subjects = ['Subject 1', 'Subject 2'];
      }

      if (!mounted) return;
      setState(() {
        _classOptions = classes;
        _subjectOptions = subjects;
        _selectedClass = classes.isNotEmpty ? classes.first : null;
        _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOptions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load options: $e')),
      );
    }
  }

  Future<String> _generateUniqueUserId({int tries = 20}) async {
    final users = FirebaseFirestore.instance.collection('users');
    for (int i = 0; i < tries; i++) {
      final candidate = (10000 + (DateTime.now().microsecondsSinceEpoch % 90000)).toString();
      final clash = await users.where('schoolId', isEqualTo: SchoolContext.currentSchoolId).where('userId', isEqualTo: candidate).limit(1).get();
      if (clash.docs.isEmpty) return candidate;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Fallback to random-ish suffix
    final fallback = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return fallback.padLeft(5, '0').substring(0, 5);
  }

  Future<void> _addUser() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || password.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, password, and phone are required')));
      return;
    }
    if (_role == 'student' && (_selectedClass == null || _selectedClass!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a class for the student')));
      return;
    }
    if (_role == 'staff' && (_selectedSubject == null || _selectedSubject!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a subject for the staff member')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final users = FirebaseFirestore.instance.collection('users');
      // Always generate a unique 5-digit userId
      final userId = await _generateUniqueUserId();

      final data = <String, dynamic>{
        'name': name,
        'userId': userId,
        'password': password,
  'email': email,
  'phone': phone,
        'role': _role,
        'notificationEnabled': _preEnableNotifications,
        'createdAt': FieldValue.serverTimestamp(),
        'schoolId': SchoolContext.currentSchoolId,
      };
      if (_role == 'student') {
        data['class'] = _selectedClass;
      } else if (_role == 'staff') {
        data['subject'] = _selectedSubject;
      }

      final ref = await users.add(data);
      if (_preEnableNotifications) {
        // Add a placeholder devices doc so we can track consent even before first login
        await ref.collection('devices').doc('placeholder').set({
          'enabled': true,
          'note': 'will be replaced with real token on first login',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('User registered'),
          content: Text('Assigned User ID: $userId'),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: userId));
                Navigator.of(ctx).pop();
              },
              child: const Text('Copy & Close'),
            ),
          ],
        ),
      );
      _nameController.clear();
      _passwordController.clear();
  _emailController.clear();
  _phoneController.clear();
      setState(() {
        _role = 'student';
        _selectedClass = _classOptions.isNotEmpty ? _classOptions.first : null;
        _selectedSubject = _subjectOptions.isNotEmpty ? _subjectOptions.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register User'),
        actions: [
          IconButton(
            tooltip: 'Reload options',
            onPressed: _loadingOptions ? null : _loadDropdownOptions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone (required)'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            // User ID is auto-generated; no manual entry field
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'student', child: Text('Student')),
                DropdownMenuItem(value: 'staff', child: Text('Staff')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() { _role = v ?? 'student'; }),
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 12),
            if (_loadingOptions)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else if (_role == 'student')
              DropdownButtonFormField<String>(
                value: _selectedClass,
                items: _classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedClass = v),
                decoration: const InputDecoration(labelText: 'Class'),
              )
            else if (_role == 'staff')
              DropdownButtonFormField<String>(
                value: _selectedSubject,
                items: _subjectOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _selectedSubject = v),
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _preEnableNotifications,
                  onChanged: (v) => setState(() => _preEnableNotifications = v ?? true),
                ),
                const Expanded(child: Text('Enable notifications for this user')),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _isSaving ? null : _addUser, child: _isSaving ? const CircularProgressIndicator() : const Text('Create User')),
          ],
        ),
      ),
    );
  }
}
