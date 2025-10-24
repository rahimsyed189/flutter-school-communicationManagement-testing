import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'services/school_context.dart';

class AdminUsersPage extends StatelessWidget {
  final String currentUserId;
  const AdminUsersPage({Key? key, required this.currentUserId}) : super(key: key);

  Future<void> _deleteUser(BuildContext context, DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    final userId = (data['userId'] ?? '').toString();
    if (userId.isNotEmpty && userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You can't delete the currently signed-in user.")));
      return;
    }
    final role = (data['role'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('This will permanently delete user "$userId"${role.isNotEmpty ? ' (role: ' + role + ')' : ''}. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Delete known subcollections (devices)
      final devices = await ref.collection('devices').get();
      for (final d in devices.docs) {
        await d.reference.delete();
      }
      await ref.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Users')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No users found'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final userId = (data['userId'] ?? '').toString();
              final role = (data['role'] ?? 'user').toString();
              final enabled = (data['notificationEnabled'] ?? false) == true;
              return ListTile(
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                title: Text(name.isNotEmpty ? name : '(no name)'),
                subtitle: Text('ID: $userId • Role: $role • Notif: ${enabled ? 'On' : 'Off'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit user',
                      icon: const Icon(Icons.edit),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/admin/users/details',
                        arguments: {
                          'userRefPath': doc.reference.path,
                          'userId': userId,
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete user',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(context, doc.reference, data),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/admin/users/details',
                  arguments: {
                    'userRefPath': doc.reference.path,
                    'userId': userId,
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
