import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({Key? key}) : super(key: key);

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  bool _includeCache = true;
  bool _includeAppStorage = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _includeCache = prefs.getBool('user_cleanup_cache') ?? true;
      _includeAppStorage = prefs.getBool('user_cleanup_app_storage') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_cleanup_cache', _includeCache);
    await prefs.setBool('user_cleanup_app_storage', _includeAppStorage);
  }

  Future<void> _performManualCleanup() async {
    if (!_includeCache && !_includeAppStorage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one cleanup option'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int cacheFiles = 0;
      int appStorageFiles = 0;

      // Clear cache if selected
      if (_includeCache) {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          final files = tempDir.listSync(recursive: true);
          for (final file in files) {
            if (file is File) {
              try {
                await file.delete();
                cacheFiles++;
              } catch (e) {
                // Skip files that can't be deleted
              }
            }
          }
        }
      }

      // Clear app storage if selected
      if (_includeAppStorage) {
        final appDir = await getApplicationDocumentsDirectory();
        final appVideosDir = Directory('${appDir.path}/app_videos');
        final appThumbnailsDir = Directory('${appDir.path}/app_thumbnails');

        if (await appVideosDir.exists()) {
          final videoFiles = appVideosDir.listSync(recursive: true);
          for (final file in videoFiles) {
            if (file is File) {
              try {
                await file.delete();
                appStorageFiles++;
              } catch (e) {
                // Skip files that can't be deleted
              }
            }
          }
        }

        if (await appThumbnailsDir.exists()) {
          final thumbFiles = appThumbnailsDir.listSync(recursive: true);
          for (final file in thumbFiles) {
            if (file is File) {
              try {
                await file.delete();
                appStorageFiles++;
              } catch (e) {
                // Skip files that can't be deleted
              }
            }
          }
        }
      }

      // Update last cleanup date
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('last_cache_cleanup_date', today);

      String message = 'Cleanup complete! ';
      if (_includeCache && _includeAppStorage) {
        message += 'Cache: $cacheFiles files, App Storage: $appStorageFiles files';
      } else if (_includeCache) {
        message += 'Cache: $cacheFiles files';
      } else {
        message += 'App Storage: $appStorageFiles files';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $message'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Cleanup failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Cleanup Settings'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Cleanup Options',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose what to clean when performing device cleanup:',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Cache Files'),
                      subtitle: const Text('Temporary files, thumbnails, and app cache'),
                      value: _includeCache,
                      onChanged: (value) {
                        setState(() {
                          _includeCache = value ?? true;
                        });
                        _saveSettings();
                      },
                      activeColor: Colors.blue.shade600,
                    ),
                    CheckboxListTile(
                      title: const Text('App Storage'),
                      subtitle: const Text('Downloaded media files and app data'),
                      value: _includeAppStorage,
                      onChanged: (value) {
                        setState(() {
                          _includeAppStorage = value ?? true;
                        });
                        _saveSettings();
                      },
                      activeColor: Colors.blue.shade600,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cleaning_services, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Manual Cleanup',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Clean your device storage manually with the options selected above.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _performManualCleanup,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cleaning_services),
                        label: Text(_isLoading ? 'Cleaning...' : 'Clean Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Daily Reminder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '💡 The app shows a daily cleanup reminder each morning. You can clean both cache and app storage directly from the notification.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '🔄 Cache: Temporary files and thumbnails\n'
                      '📱 App Storage: Downloaded media files\n'
                      '⚡ Both help free up device space',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
