import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/school_context.dart';

class AdminPostPage extends StatefulWidget {
  final String currentUserId;
  const AdminPostPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<AdminPostPage> createState() => _AdminPostPageState();
}

class _AdminPostPageState extends State<AdminPostPage> {
  final TextEditingController _messageController = TextEditingController();

  Future<void> _post() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;
    // Save the announcement
    await FirebaseFirestore.instance.collection('communications').add({
      'message': msg,
      'senderId': widget.currentUserId,
      'senderRole': 'admin',
      'senderName': 'School Admin',
      'timestamp': FieldValue.serverTimestamp(),
      'schoolId': SchoolContext.currentSchoolId,
    });
    // Optional: enqueue a notification doc that a backend Cloud Function can send to topic 'all'
    try {
      await FirebaseFirestore.instance.collection('notificationQueue').add({
        'title': 'New Announcement',
        'body': msg,
        'topic': 'all',
        'createdAt': FieldValue.serverTimestamp(),
        'schoolId': SchoolContext.currentSchoolId,
      });
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted')));
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Announcement')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _post, child: const Text('Post')),
          ],
        ),
      ),
    );
  }
}
