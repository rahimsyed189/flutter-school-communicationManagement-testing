import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminApprovalsPage extends StatefulWidget {
  final String currentUserId;
  const AdminApprovalsPage({super.key, required this.currentUserId});

  @override
  State<AdminApprovalsPage> createState() => _AdminApprovalsPageState();
}

class _AdminApprovalsPageState extends State<AdminApprovalsPage> {
  final Set<String> _selected = <String>{};
  bool _bulkLoading = false;

  Future<void> _approveOne(BuildContext context, DocumentSnapshot regDoc) async {
    final data = regDoc.data() as Map<String, dynamic>? ?? {};
    final name = (data['name'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final password = (data['password'] ?? '').toString();
    final role = (data['role'] ?? 'user').toString();
    final klass = (data['class'] ?? '').toString();
    final subject = (data['subject'] ?? '').toString();
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone is required to approve')));
      }
      return;
    }
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final dup = await users.where('userId', isEqualTo: phone).limit(1).get();
      if (dup.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User already exists with this phone')));
        }
        return;
      }
      final newRef = users.doc();
      await newRef.set({
        'userId': phone,
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
        'class': role == 'student' ? (klass.isNotEmpty ? klass : null) : null,
        'subject': role == 'staff' ? (subject.isNotEmpty ? subject : null) : null,
        'notificationEnabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await regDoc.reference.update({
        'status': 'approved',
        'approvedUserRef': newRef.path,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context, DocumentSnapshot regDoc) async {
    try {
      await regDoc.reference.update({'status': 'rejected', 'rejectedAt': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _approveSelected(BuildContext context, List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    setState(() => _bulkLoading = true);
    int ok = 0, fail = 0, skipped = 0;
    for (final d in docs) {
      try {
        final data = d.data() as Map<String, dynamic>? ?? {};
        final phone = (data['phone'] ?? '').toString();
        if (phone.isEmpty) {
          skipped++;
          continue;
        }
        // Skip if user already exists
        final users = FirebaseFirestore.instance.collection('users');
        final dup = await users.where('userId', isEqualTo: phone).limit(1).get();
        if (dup.docs.isNotEmpty) {
          skipped++;
          // Still mark registration as approved referencing existing user?
          try {
            await d.reference.update({
              'status': 'approved',
              'approvedUserRef': dup.docs.first.reference.path,
              'approvedAt': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
          continue;
        }
        final name = (data['name'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final password = (data['password'] ?? '').toString();
        final role = (data['role'] ?? 'user').toString();
        final klass = (data['class'] ?? '').toString();
        final subject = (data['subject'] ?? '').toString();
        final newRef = users.doc();
        await newRef.set({
          'userId': phone,
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'role': role,
          'class': role == 'student' ? (klass.isNotEmpty ? klass : null) : null,
          'subject': role == 'staff' ? (subject.isNotEmpty ? subject : null) : null,
          'notificationEnabled': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await d.reference.update({
          'status': 'approved',
          'approvedUserRef': newRef.path,
          'approvedAt': FieldValue.serverTimestamp(),
        });
        ok++;
      } catch (_) {
        fail++;
      }
    }
    if (mounted) {
      setState(() {
        _bulkLoading = false;
        _selected.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved: $ok  •  Skipped: $skipped  •  Failed: $fail')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('registrations')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = [...snapshot.data!.docs];
          docs.sort((a, b) {
            final at = (a['createdAt'] is Timestamp) ? a['createdAt'] as Timestamp : null;
            final bt = (b['createdAt'] is Timestamp) ? b['createdAt'] as Timestamp : null;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
          if (docs.isEmpty) return const Center(child: Text('No pending registrations'));

          final allIds = docs.map((d) => d.id).toSet();
          final allSelected = allIds.isNotEmpty && allIds.every(_selected.contains);
          final selectedDocs = docs.where((d) => _selected.contains(d.id)).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: allSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected..clear()..addAll(allIds);
                          } else {
                            _selected.removeWhere((id) => allIds.contains(id));
                          }
                        });
                      },
                    ),
                    const Text('Select all'),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _bulkLoading || selectedDocs.isEmpty
                          ? null
                          : () => _approveSelected(context, selectedDocs),
                      icon: const Icon(Icons.check),
                      label: Text(_bulkLoading
                          ? 'Approving...'
                          : 'Approve selected (${selectedDocs.length})'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data() as Map<String, dynamic>? ?? {};
                    final name = (data['name'] ?? '').toString();
                    final role = (data['role'] ?? '').toString();
                    final phone = (data['phone'] ?? '').toString();
                    final email = (data['email'] ?? '').toString();
                    final klass = (data['class'] ?? '').toString();
                    final subject = (data['subject'] ?? '').toString();
                    final checked = _selected.contains(d.id);
                    return ListTile(
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: checked,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(d.id);
                              } else {
                                _selected.remove(d.id);
                              }
                            }),
                          ),
                        ],
                      ),
                      title: Text(name.isNotEmpty ? name : phone),
                      subtitle: Text([
                        if (role.isNotEmpty) 'Role: $role',
                        if (email.isNotEmpty) 'Email: $email',
                        if (phone.isNotEmpty) 'Phone: $phone',
                        if (klass.isNotEmpty) 'Class: $klass',
                        if (subject.isNotEmpty) 'Subject: $subject',
                      ].join('  •  ')),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Reject',
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _reject(context, d),
                          ),
                          IconButton(
                            tooltip: 'Approve',
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _approveOne(context, d),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
