import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ForcePasswordChangePage extends StatefulWidget {
  final String userId; // this is users.userId
  const ForcePasswordChangePage({super.key, required this.userId});

  @override
  State<ForcePasswordChangePage> createState() => _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState extends State<ForcePasswordChangePage> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = _p1.text.trim();
    final b = _p2.text.trim();
    if (a.isEmpty || b.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter and confirm the new password')));
      return;
    }
    if (a != b) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _saving = true);
    try {
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: widget.userId)
          .limit(1)
          .get();
      if (qs.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
        }
        setState(() => _saving = false);
        return;
      }
      await qs.docs.first.reference.set({
        'password': a,
        'mustChangePassword': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set New Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Your password was reset by admin. Please set a new password to continue.',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: _p1,
              decoration: const InputDecoration(labelText: 'New password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _p2,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save and Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
