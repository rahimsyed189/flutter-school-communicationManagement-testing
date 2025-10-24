import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'services/school_context.dart';

class AdminUserDetailsPage extends StatefulWidget {
  final String userRefPath;
  const AdminUserDetailsPage({Key? key, required this.userRefPath}) : super(key: key);

  @override
  State<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage> {
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  Map<String, dynamic>? _latestData;
  String? _roleValue; // for dropdown binding

  // Mirror registration fields
  bool _loadingOptions = false;
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
      final classesSnap = await db.collection('classes').where('schoolId', isEqualTo: SchoolContext.currentSchoolId).orderBy('order', descending: false).get().catchError((_) async => await db.collection('classes').where('schoolId', isEqualTo: SchoolContext.currentSchoolId).get());
      final subjectsSnap = await db.collection('subjects').where('schoolId', isEqualTo: SchoolContext.currentSchoolId).orderBy('order', descending: false).get().catchError((_) async => await db.collection('subjects').where('schoolId', isEqualTo: SchoolContext.currentSchoolId).get());
      final classes = classesSnap.docs
          .map((d) => (d.data()['name'] as String?)?.trim())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      final subjects = subjectsSnap.docs
          .map((d) => (d.data()['name'] as String?)?.trim())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _classOptions = classes;
        _subjectOptions = subjects;
        // Keep selected values if already set from existing user data
        _selectedClass ??= classes.isNotEmpty ? classes.first : null;
        _selectedSubject ??= subjects.isNotEmpty ? subjects.first : null;
        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOptions = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load options: $e')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _passwordCtrl.dispose();
  _emailCtrl.dispose();
  _phoneCtrl.dispose();
    super.dispose();
  }

  void _enterEdit() {
    final data = _latestData ?? {};
    _nameCtrl.text = (data['name'] ?? '').toString();
  _roleCtrl.text = (data['role'] ?? 'user').toString();
  _roleValue = _roleCtrl.text.isNotEmpty ? _roleCtrl.text : 'user';
  _selectedClass = (data['class'] as String?)?.trim();
  _selectedSubject = (data['subject'] as String?)?.trim();
  _emailCtrl.text = (data['email'] ?? '').toString();
  _phoneCtrl.text = (data['phone'] ?? '').toString();
    _passwordCtrl.clear();
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    setState(() => _editing = false);
    _passwordCtrl.clear();
  }

  Future<void> _saveEdits(DocumentReference<Map<String, dynamic>> ref) async {
    final name = _nameCtrl.text.trim();
    final role = (_roleValue ?? _roleCtrl.text).trim();
  final newPass = _passwordCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone is required')));
      return;
    }

    final update = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name.isNotEmpty) update['name'] = name; else update['name'] = FieldValue.delete();
    if (role.isNotEmpty) update['role'] = role; else update['role'] = FieldValue.delete();
  // Admin no longer sets passwords directly here.
  // Email is optional
  if (email.isNotEmpty) update['email'] = email; else update['email'] = FieldValue.delete();
  // Phone mandatory
  update['phone'] = phone;

    // Mirror conditional fields from registration
    if (role == 'student') {
      if ((_selectedClass ?? '').isNotEmpty) update['class'] = _selectedClass; else update['class'] = FieldValue.delete();
      update['subject'] = FieldValue.delete();
    } else if (role == 'staff') {
      if ((_selectedSubject ?? '').isNotEmpty) update['subject'] = _selectedSubject; else update['subject'] = FieldValue.delete();
      update['class'] = FieldValue.delete();
    } else {
      // admin or other
      update['class'] = FieldValue.delete();
      update['subject'] = FieldValue.delete();
    }

    await ref.set(update, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User updated')));
    setState(() => _editing = false);
  }

  Future<void> _resetPassword(BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Require password reset?'),
        content: const Text('User will be asked to set a new password on next login.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.set({
        'mustChangePassword': true,
        'passwordResetAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User will be prompted to change password')));
    }
  }

  Future<void> _setNotificationsEnabled(DocumentReference<Map<String, dynamic>> ref, bool enabled) async {
    await ref.set({'notificationEnabled': enabled, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    // Best-effort: mark all device docs enabled/disabled
    final devs = await ref.collection('devices').get();
    for (final d in devs.docs) {
      await d.reference.set({'enabled': enabled, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
  }

  Future<void> _deleteDevice(DocumentReference<Map<String, dynamic>> deviceRef) async {
    await deviceRef.delete();
  }

  Future<void> _setAdminRole(DocumentReference<Map<String, dynamic>> ref, bool makeAdmin, Map<String, dynamic> current) async {
    if (makeAdmin) {
      await ref.set({
        'role': 'admin',
        'class': FieldValue.delete(),
        'subject': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User promoted to Admin')));
    } else {
      // Demote: ask which role to set
      String selected = 'staff';
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Set non-admin role'),
              content: StatefulBuilder(
                builder: (ctx2, setSt) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      value: 'staff',
                      groupValue: selected,
                      onChanged: (v) => setSt(() => selected = v ?? 'staff'),
                      title: const Text('Staff'),
                    ),
                    RadioListTile<String>(
                      value: 'student',
                      groupValue: selected,
                      onChanged: (v) => setSt(() => selected = v ?? 'staff'),
                      title: const Text('Student'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            );
          },
        );
      }
      final update = <String, dynamic>{
        'role': selected,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (selected == 'staff') {
        // keep subject if present, clear class
        update['class'] = FieldValue.delete();
        if (!(current['subject']?.toString().isNotEmpty == true)) {
          update['subject'] = FieldValue.delete();
        }
      } else {
        // student: keep class if present, clear subject
        update['subject'] = FieldValue.delete();
        if (!(current['class']?.toString().isNotEmpty == true)) {
          update['class'] = FieldValue.delete();
        }
      }
      await ref.set(update, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role set to $selected')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore.instance.doc(widget.userRefPath);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('User Details')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('User Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('User Details')),
            body: const Center(child: Text('User not found')),
          );
        }
        _latestData = data;
        final notifEnabled = (data['notificationEnabled'] ?? false) == true;

        return Scaffold(
          appBar: AppBar(
            title: const Text('User Details'),
            actions: [
              if (_editing) ...[
                TextButton(
                  onPressed: () => _saveEdits(ref),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close),
                  onPressed: _cancelEdit,
                ),
              ] else ...[
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: _enterEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.lock_reset),
                  tooltip: 'Reset Password',
                  onPressed: () => _resetPassword(context, ref),
                ),
              ],
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_editing) ...[
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone (required)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _roleValue ?? (_latestData?['role']?.toString() ?? 'student'),
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() {
                    _roleValue = v ?? 'student';
                    _roleCtrl.text = _roleValue!;
                    // Initialize dependent selections when switching role
                    if (_roleValue == 'student' && (_selectedClass == null || _selectedClass!.isEmpty)) {
                      _selectedClass = _classOptions.isNotEmpty ? _classOptions.first : null;
                    }
                    if (_roleValue == 'staff' && (_selectedSubject == null || _selectedSubject!.isEmpty)) {
                      _selectedSubject = _subjectOptions.isNotEmpty ? _subjectOptions.first : null;
                    }
                  }),
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
                else if ((_roleValue ?? (_latestData?['role']?.toString() ?? 'student')) == 'student') ...[
                  if (_classOptions.isEmpty)
                    const Text('No classes configured')
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedClass ?? (_latestData?['class']?.toString()),
                      items: _classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedClass = v),
                      decoration: const InputDecoration(labelText: 'Class'),
                    ),
                  const SizedBox(height: 12),
                ] else if ((_roleValue ?? (_latestData?['role']?.toString() ?? 'student')) == 'staff') ...[
                  if (_subjectOptions.isEmpty)
                    const Text('No subjects configured')
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedSubject ?? (_latestData?['subject']?.toString()),
                      items: _subjectOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _selectedSubject = v),
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                const Divider(),
              ] else ...[
                ListTile(title: const Text('Name'), subtitle: Text('${data['name'] ?? ''}')),
                ListTile(title: const Text('User ID'), subtitle: Text('${data['userId'] ?? ''}')),
                ListTile(title: const Text('Email'), subtitle: Text('${data['email'] ?? '-'}')),
                ListTile(title: const Text('Phone'), subtitle: Text('${data['phone'] ?? '-'}')),
                ListTile(title: const Text('Role'), subtitle: Text('${data['role'] ?? 'user'}')),
                const Divider(),
              ],
              SwitchListTile(
                value: notifEnabled,
                title: const Text('Notifications enabled'),
                onChanged: (v) => _setNotificationsEnabled(ref, v),
              ),
              SwitchListTile(
                value: (data['role']?.toString() == 'admin'),
                title: const Text('Make user an Admin'),
                onChanged: (v) => _setAdminRole(ref, v, data),
              ),
              SwitchListTile(
                value: (data['mustChangePassword'] ?? false) == true,
                title: const Text('Require password reset on next login'),
                onChanged: (v) async {
                  await ref.set({'mustChangePassword': v, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Devices', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ref.collection('devices').orderBy('lastSeen', descending: true).snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text('Error: ${snap.error}');
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final devs = snap.data!.docs;
                  if (devs.isEmpty) return const Text('No devices registered');
                  return Column(
                    children: devs.map((d) {
                      final dv = d.data();
                      final tokenStr = dv['token']?.toString();
                      final tokenShort = tokenStr != null && tokenStr.length > 20 ? tokenStr.substring(0, 20) + '…' : (tokenStr ?? d.id);
                      return ListTile(
                        title: Text(tokenShort),
                        subtitle: Text('Platform: ${dv['platform'] ?? '-'} • Enabled: ${dv['enabled'] == true ? 'Yes' : 'No'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteDevice(d.reference),
                          tooltip: 'Remove device token',
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
