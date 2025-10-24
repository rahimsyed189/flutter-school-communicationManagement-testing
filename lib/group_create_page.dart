import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'services/school_context.dart';

class GroupCreatePage extends StatefulWidget {
  final String currentUserId;
  const GroupCreatePage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _photoUrlCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selected = <String>{};
  String? _iconEmoji;
  bool _busy = false;

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || (_selected.isEmpty && widget.currentUserId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name and select members')));
      return;
    }
    setState(() => _busy = true);
    try {
      final members = <String>{..._selected, widget.currentUserId}.toList();
  final doc = await FirebaseFirestore.instance.collection('groups').add({
        'name': name,
        'photoUrl': _photoUrlCtrl.text.trim().isEmpty ? null : _photoUrlCtrl.text.trim(),
        'iconEmoji': _iconEmoji,
        'createdBy': widget.currentUserId,
        'members': members,
  'admins': [widget.currentUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'schoolId': SchoolContext.currentSchoolId,
      });
  // Subscribe creator to this group's topic
  try { await NotificationService.instance.subscribeToGroup(doc.id); } catch (_) {}
  if (!mounted) return;
      // Go to Current Page so the admin sees the new group in the list
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/admin',
        (route) => false,
        arguments: {'userId': widget.currentUserId},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _create,
            child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal.shade400,
                  child: _iconEmoji != null
                      ? Text(_iconEmoji!, style: const TextStyle(fontSize: 20))
                      : const Icon(Icons.group, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _photoUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Photo URL (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  onSelected: (v) => setState(() => _iconEmoji = v == 'clear' ? null : v),
                  itemBuilder: (ctx) => [
                    for (final e in ['👍','💬','🎓','🏫','📣','✨','👥','📚','🚌'])
                      PopupMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 18))),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'clear', child: Text('No icon')),
                  ],
                )
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Add members', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').where('schoolId', isEqualTo: SchoolContext.currentSchoolId).orderBy('name', descending: false).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final q = _searchCtrl.text.trim().toLowerCase();
                final docs = snap.data!.docs.where((d) {
                  final data = d.data();
                  final userId = (data['userId'] ?? '').toString();
                  final name = (data['name'] ?? userId).toString();
                  if (userId == widget.currentUserId) return true; // show self (will be included anyway)
                  if (q.isEmpty) return true;
                  return userId.toLowerCase().contains(q) || name.toLowerCase().contains(q);
                }).toList();
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final userId = (data['userId'] ?? '').toString();
                    final name = (data['name'] ?? userId).toString();
                    final isSelf = userId == widget.currentUserId;
                    final selected = _selected.contains(userId) || isSelf;
                    return CheckboxListTile(
                      value: selected,
                      onChanged: isSelf
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  _selected.add(userId);
                                } else {
                                  _selected.remove(userId);
                                }
                              }),
                      title: Text(name),
                      subtitle: Text(userId),
                      secondary: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blueGrey.shade200,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
