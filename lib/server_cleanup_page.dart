import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerCleanupPage extends StatefulWidget {
  const ServerCleanupPage({Key? key}) : super(key: key);

  @override
  State<ServerCleanupPage> createState() => _ServerCleanupPageState();
}

class _ServerCleanupPageState extends State<ServerCleanupPage> {
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  
  // Cleanup settings
  String _cleanupRange = 'weekly';
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 2, minute: 0);
  bool _includeChats = true;
  bool _includeAnnouncements = true;
  bool _includeR2Storage = false;
  
  bool _isTestingCleanup = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load cleanup settings
      final cleanupDoc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('cleanup_settings')
          .get();

      if (cleanupDoc.exists) {
        final data = cleanupDoc.data()!;
        setState(() {
          _cleanupRange = data['range'] ?? 'weekly';
          _includeChats = data['includeChats'] ?? true;
          _includeAnnouncements = data['includeAnnouncements'] ?? true;
          _includeR2Storage = data['includeR2Storage'] ?? false;
          
          if (data['scheduledHour'] != null && data['scheduledMinute'] != null) {
            _scheduledTime = TimeOfDay(
              hour: data['scheduledHour'],
              minute: data['scheduledMinute'],
            );
          }
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Save cleanup settings
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('cleanup_settings')
          .set({
        'range': _cleanupRange,
        'scheduledHour': _scheduledTime.hour,
        'scheduledMinute': _scheduledTime.minute,
        'includeChats': _includeChats,
        'includeAnnouncements': _includeAnnouncements,
        'includeR2Storage': _includeR2Storage,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testCleanup() async {
    try {
      setState(() {
        _isTestingCleanup = true;
      });

      // Trigger test cleanup by writing to test_cleanup_trigger collection
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('test_cleanup_trigger')
          .set({
        'timestamp': FieldValue.serverTimestamp(),
        'range': _cleanupRange,
        'includeChats': _includeChats,
        'includeAnnouncements': _includeAnnouncements,
        'includeR2Storage': _includeR2Storage,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test cleanup initiated! Check status below.'),
            backgroundColor: Colors.blue,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initiating test cleanup: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingCleanup = false;
        });
      }
    }
  }

  Widget _buildCleanupStatus() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cleanup_status')
          .doc('test_status')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final status = data['status'] ?? '';
        final message = data['message'] ?? '';
        final timestamp = data['timestamp'] as Timestamp?;

        Color statusColor = Colors.grey;
        IconData statusIcon = Icons.info;

        switch (status) {
          case 'running':
            statusColor = Colors.blue;
            statusIcon = Icons.refresh;
            break;
          case 'success':
            statusColor = Colors.green;
            statusIcon = Icons.check_circle;
            break;
          case 'error':
            statusColor = Colors.red;
            statusIcon = Icons.error;
            break;
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      'Cleanup Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(color: statusColor),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: ${timestamp.toDate().toLocal()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Cleanup'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_hasUnsavedChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'R2 Configuration',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'R2 storage credentials are configured in the dedicated R2 Config page. Firebase Functions will automatically use those settings.',
                                  style: TextStyle(color: Colors.blue.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Cleanup Frequency Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cleanup Frequency',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _cleanupRange,
                            decoration: const InputDecoration(
                              labelText: 'Cleanup Range',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'daily', child: Text('Daily')),
                              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _cleanupRange = value;
                                  _hasUnsavedChanges = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text('Scheduled Time: '),
                              TextButton(
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _scheduledTime,
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _scheduledTime = time;
                                      _hasUnsavedChanges = true;
                                    });
                                  }
                                },
                                child: Text(_scheduledTime.format(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Data Types Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data Types to Clean',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: const Text('Chat Messages'),
                            subtitle: const Text('Clean old chat messages from Firestore'),
                            value: _includeChats,
                            onChanged: (value) {
                              setState(() {
                                _includeChats = value ?? true;
                                _hasUnsavedChanges = true;
                              });
                            },
                          ),
                          CheckboxListTile(
                            title: const Text('Announcements'),
                            subtitle: const Text('Clean old announcements from Firestore'),
                            value: _includeAnnouncements,
                            onChanged: (value) {
                              setState(() {
                                _includeAnnouncements = value ?? true;
                                _hasUnsavedChanges = true;
                              });
                            },
                          ),
                          CheckboxListTile(
                            title: const Text('R2 Storage'),
                            subtitle: const Text('Clean files from Cloudflare R2 storage (uses R2 Config settings)'),
                            value: _includeR2Storage,
                            onChanged: (value) {
                              setState(() {
                                _includeR2Storage = value ?? false;
                                _hasUnsavedChanges = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status Section
                  _buildCleanupStatus(),
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTestingCleanup ? null : _testCleanup,
                          icon: _isTestingCleanup 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow),
                          label: Text(_isTestingCleanup ? 'Testing...' : 'Test Cleanup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveSettings,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
