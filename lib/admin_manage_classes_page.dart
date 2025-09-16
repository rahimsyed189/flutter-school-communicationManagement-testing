import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminManageClassesPage extends StatefulWidget {
  final String currentUserId;
  const AdminManageClassesPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<AdminManageClassesPage> createState() => _AdminManageClassesPageState();
}

class _AdminManageClassesPageState extends State<AdminManageClassesPage> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _addClass() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final col = FirebaseFirestore.instance.collection('classes');
    // order = last + 1
    final last = await col.orderBy('order', descending: true).limit(1).get().catchError((_) async => await col.get());
    final nextOrder = (last.docs.isNotEmpty ? (last.docs.first.data()['order'] as int? ?? last.docs.length) : 0) + 1;
    await col.add({'name': name, 'order': nextOrder, 'createdAt': FieldValue.serverTimestamp()});
    _nameController.clear();
  }

  Future<void> _rename(DocumentReference ref, String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Class'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref.set({'name': result, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
  }

  Future<void> _delete(DocumentReference ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Class'),
        content: const Text('Are you sure you want to delete this class?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Classes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'New class name',
                    ),
                    onSubmitted: (_) => _addClass(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addClass, child: const Text('Add')),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .orderBy('order', descending: false)
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
                  return const Center(child: Text('No classes yet. Add one above.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final name = (data['name'] as String?) ?? 'Untitled';
                    return ListTile(
                      leading: const Icon(Icons.class_, color: Colors.blue),
                      title: Text(name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _rename(doc.reference, name)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(doc.reference)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
