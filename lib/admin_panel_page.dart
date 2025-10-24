import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/school_context.dart';

class AdminPanelPage extends StatefulWidget {
  final String currentUserId;
  const AdminPanelPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  Future<void> _addAnnouncement() async {
    await FirebaseFirestore.instance.collection('communications').add({
      'title': _titleController.text.trim(),
      'message': _messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'schoolId': SchoolContext.currentSchoolId,
    });
    _titleController.clear();
    _messageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement posted!')));
  }

  Future<void> _addUser() async {
    await FirebaseFirestore.instance.collection('users').add({
      'userId': _userIdController.text.trim(),
      'password': _passwordController.text.trim(),
      'role': _roleController.text.trim(),
      'schoolId': SchoolContext.currentSchoolId,
    });
    _userIdController.clear();
    _passwordController.clear();
    _roleController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User added!')));
  }

  Future<void> _removeUser(String userId) async {
    final query = await FirebaseFirestore.instance.collection('users').where('schoolId', isEqualTo: SchoolContext.currentSchoolId).where('userId', isEqualTo: userId).get();
    for (var doc in query.docs) {
      await doc.reference.delete();
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User removed!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Post Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _messageController, decoration: const InputDecoration(labelText: 'Message')),
            ElevatedButton(onPressed: _addAnnouncement, child: const Text('Post')),
            const Divider(),
            const Text('Add User', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _userIdController, decoration: const InputDecoration(labelText: 'User ID')),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password')),
            TextField(controller: _roleController, decoration: const InputDecoration(labelText: 'Role (user/admin)')),
            ElevatedButton(onPressed: _addUser, child: const Text('Add User')),
            const Divider(),
            const Text('Remove User', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _userIdController, decoration: const InputDecoration(labelText: 'User ID to remove')),
            ElevatedButton(onPressed: () => _removeUser(_userIdController.text.trim()), child: const Text('Remove User')),
          ],
        ),
      ),
    );
  }
}
