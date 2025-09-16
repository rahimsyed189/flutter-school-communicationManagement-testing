import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CleanupStatusPage extends StatefulWidget {
  const CleanupStatusPage({Key? key}) : super(key: key);

  @override
  State<CleanupStatusPage> createState() => _CleanupStatusPageState();
}

class _CleanupStatusPageState extends State<CleanupStatusPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleanup Status'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('app_config')
            .doc('daily_cleanup_status')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'No cleanup history available',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final completedDate = data['completedDate'] as String?;
          final completedBy = data['completedBy'] as String?;
          final preset = data['preset'] as String?;
          final timestamp = data['timestamp'] as Timestamp?;
          final deviceInfo = data['deviceInfo'] as String?;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Cleanup Status',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow('Date', completedDate ?? 'Not available'),
                        const SizedBox(height: 8),
                        _buildStatusRow('Preset', _formatPreset(preset)),
                        const SizedBox(height: 8),
                        if (timestamp != null)
                          _buildStatusRow(
                            'Time', 
                            DateFormat('HH:mm:ss').format(timestamp.toDate().toLocal())
                          ),
                        const SizedBox(height: 8),
                        _buildStatusRow('Device', deviceInfo ?? 'Unknown'),
                        const SizedBox(height: 8),
                        _buildStatusRow('User ID', completedBy ?? 'Not available'),
                        const SizedBox(height: 8),
                        FutureBuilder<String>(
                          future: _getUserName(completedBy),
                          builder: (context, userSnapshot) {
                            return _buildStatusRow(
                              'User Name', 
                              userSnapshot.data ?? 'Loading...'
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cleanup Information',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '• Shared cleanup (Chats, Announcements, R2 Storage) runs only once per day',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• Device cache cleanup runs individually on each device',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• First admin to trigger wins the daily cleanup slot',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('app_config')
                      .doc('cleanup_lock')
                      .snapshots(),
                  builder: (context, lockSnapshot) {
                    bool isLocked = false;
                    String? lockUser;
                    DateTime? lockTime;

                    if (lockSnapshot.hasData && lockSnapshot.data!.exists) {
                      final lockData = lockSnapshot.data!.data() as Map<String, dynamic>;
                      final locked = lockData['isLocked'] as bool? ?? false;
                      final timestamp = lockData['lockTime'] as Timestamp?;
                      
                      if (locked && timestamp != null) {
                        final age = DateTime.now().difference(timestamp.toDate());
                        if (age.inMinutes < 10) {
                          isLocked = true;
                          lockUser = lockData['userId'] as String?;
                          lockTime = timestamp.toDate();
                        }
                      }
                    }

                    return Card(
                      color: isLocked ? Colors.orange.shade50 : Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isLocked ? Icons.lock : Icons.lock_open,
                                  color: isLocked ? Colors.orange : Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isLocked ? 'R2 Cleanup In Progress' : 'R2 Cleanup Available',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isLocked ? Colors.orange.shade800 : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            if (isLocked) ...[
                              const SizedBox(height: 8),
                              FutureBuilder<String>(
                                future: _getUserName(lockUser),
                                builder: (context, userSnapshot) {
                                  return Text(
                                    'Being executed by: ${userSnapshot.data ?? "Unknown User"}',
                                    style: TextStyle(color: Colors.orange.shade800),
                                  );
                                },
                              ),
                              if (lockTime != null)
                                Text(
                                  'Started at: ${DateFormat('HH:mm:ss').format(lockTime.toLocal())}',
                                  style: TextStyle(color: Colors.orange.shade800),
                                ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                
                // Manual Cleanup Status Section
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('app_config')
                      .doc('manual_cleanup_status')
                      .snapshots(),
                  builder: (context, manualSnapshot) {
                    return Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.touch_app, color: Colors.blue.shade800),
                                const SizedBox(width: 8),
                                Text(
                                  'Manual Cleanup Status',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (manualSnapshot.hasData && manualSnapshot.data!.exists) ...[
                              Builder(
                                builder: (context) {
                                  final manualData = manualSnapshot.data!.data() as Map<String, dynamic>;
                                  final lastManualDate = manualData['lastManualDate'] as String?;
                                  final lastManualBy = manualData['lastManualBy'] as String?;
                                  final lastManualPreset = manualData['lastManualPreset'] as String?;
                                  final lastManualTimestamp = manualData['lastManualTimestamp'] as Timestamp?;
                                  final lastManualTotal = manualData['lastManualTotal'] as int?;
                                  final lastManualTargets = manualData['lastManualTargets'] as List<dynamic>?;

                                  return Column(
                                    children: [
                                      _buildStatusRow('Last Manual Date', lastManualDate ?? 'Never'),
                                      const SizedBox(height: 8),
                                      _buildStatusRow('User ID', lastManualBy ?? 'N/A'),
                                      const SizedBox(height: 8),
                                      FutureBuilder<String>(
                                        future: _getUserName(lastManualBy),
                                        builder: (context, userSnapshot) {
                                          return _buildStatusRow(
                                            'User Name', 
                                            userSnapshot.data ?? 'Loading...'
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      _buildStatusRow('Preset', _formatPreset(lastManualPreset)),
                                      const SizedBox(height: 8),
                                      _buildStatusRow('Items Deleted', '${lastManualTotal ?? 0}'),
                                      const SizedBox(height: 8),
                                      _buildStatusRow('Targets', lastManualTargets?.join(', ') ?? 'N/A'),
                                      if (lastManualTimestamp != null) ...[
                                        const SizedBox(height: 8),
                                        _buildStatusRow(
                                          'Time', 
                                          DateFormat('yyyy-MM-dd HH:mm:ss').format(lastManualTimestamp.toDate().toLocal())
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ] else ...[
                              const Text(
                                'No manual cleanup operations performed yet',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Recent Cleanup History Section
                Card(
                  color: Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history, color: Colors.grey.shade800),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Cleanup History',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('cleanup_history')
                              .orderBy('timestamp', descending: true)
                              .limit(5)
                              .snapshots(),
                          builder: (context, historySnapshot) {
                            if (!historySnapshot.hasData || historySnapshot.data!.docs.isEmpty) {
                              return const Text(
                                'No cleanup history available',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }

                            return Column(
                              children: historySnapshot.data!.docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final isManual = data['isManual'] as bool? ?? false;
                                final userId = data['userId'] as String?;
                                final preset = data['preset'] as String?;
                                final totalDeleted = data['totalDeleted'] as int? ?? 0;
                                final targets = data['targets'] as List<dynamic>? ?? [];
                                final timestamp = data['timestamp'] as Timestamp?;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isManual ? Colors.orange.shade50 : Colors.blue.shade50,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isManual ? Icons.touch_app : Icons.schedule,
                                            size: 16,
                                            color: isManual ? Colors.orange.shade800 : Colors.blue.shade800,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isManual ? 'Manual' : 'Automatic',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isManual ? Colors.orange.shade800 : Colors.blue.shade800,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (timestamp != null)
                                            Text(
                                              DateFormat('MM/dd HH:mm').format(timestamp.toDate().toLocal()),
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      FutureBuilder<String>(
                                        future: _getUserName(userId),
                                        builder: (context, userSnapshot) {
                                          return Text(
                                            'By: ${userSnapshot.data ?? "Loading..."} (${userId ?? "N/A"})',
                                            style: const TextStyle(fontSize: 12),
                                          );
                                        },
                                      ),
                                      Text(
                                        'Preset: ${_formatPreset(preset)} | Deleted: $totalDeleted items',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'Targets: ${targets.join(", ")}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }

  String _formatPreset(String? preset) {
    switch (preset) {
      case 'today':
        return 'Today';
      case 'last7':
        return 'Last 7 days';
      case 'last30':
        return 'Last 30 days';
      default:
        return preset ?? 'Unknown';
    }
  }

  Future<String> _getUserName(String? userId) async {
    if (userId == null) return 'Not Available';
    if (userId == 'background_task') return 'Background Task';
    
    try {
      print("Looking up user: $userId"); // Debug log
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final name = userData['name'] as String?;
        print("Found user name: $name for ID: $userId"); // Debug log
        return name ?? 'User Name Not Set';
      } else {
        print("User document not found for ID: $userId"); // Debug log
        return 'User Not Found';
      }
    } catch (e) {
      print("Error fetching user name for $userId: $e"); // Debug log
      return 'Error Loading User';
    }
  }
}
