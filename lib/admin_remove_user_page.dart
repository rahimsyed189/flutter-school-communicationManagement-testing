import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/school_context.dart';

class AdminRemoveUserPage extends StatefulWidget {
  final String currentUserId;
  const AdminRemoveUserPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<AdminRemoveUserPage> createState() => _AdminRemoveUserPageState();
}

class _AdminRemoveUserPageState extends State<AdminRemoveUserPage> {
  final TextEditingController _userIdController = TextEditingController();

  Future<void> _remove() async {
    final id = _userIdController.text.trim();
    if (id.isEmpty) return;
    final q = await FirebaseFirestore.instance.collection('users').where('schoolId', isEqualTo: SchoolContext.currentSchoolId).where('userId', isEqualTo: id).get();
    for (final d in q.docs) {
      await d.reference.delete();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed (if existed)')));
    _userIdController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remove User')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _userIdController, decoration: const InputDecoration(labelText: 'User ID to remove')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _remove, child: const Text('Remove')),
          ],
        ),
      ),
    );
  }
}
