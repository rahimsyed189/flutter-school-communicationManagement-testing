import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SimpleCleanupNotification extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;
  final VoidCallback? onFullCleanup;
  
  const SimpleCleanupNotification({
    Key? key,
    required this.currentUserId,
    required this.currentUserRole,
    this.onFullCleanup,
  }) : super(key: key);

  @override
  State<SimpleCleanupNotification> createState() => _SimpleCleanupNotificationState();
}

class _SimpleCleanupNotificationState extends State<SimpleCleanupNotification> {
  bool _isVisible = false;
  bool _isLoading = false;
  bool _isCompleted = false; // New: track completion state
  String _completionMessage = '';
  
  @override
  void initState() {
    super.initState();
    _checkShouldShow();
  }
  
  Future<void> _checkShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDismissed = prefs.getString('cleanup_notification_dismissed_$today');
    final lastCacheCleanup = prefs.getString('last_cache_cleanup_date');
    
    // Always show if not manually dismissed
    // If cache was cleaned today, show as completed
    final shouldShow = lastDismissed == null;
    final isCompleted = lastCacheCleanup == today;
    
    if (mounted) {
      setState(() {
        _isVisible = shouldShow;
        _isCompleted = isCompleted;
        if (isCompleted) {
          _completionMessage = 'Cache cleaned today! ✅';
        }
      });
    }
  }
  
  Future<void> _dismissNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('cleanup_notification_dismissed_$today', 'true');
    
    if (mounted) {
      setState(() {
        _isVisible = false;
      });
    }
  }
  
  Future<void> _performCacheCleanup() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      int deletedFiles = 0;
      int appStorageFiles = 0;
      
      // Clear app cache directory
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final files = tempDir.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            try {
              await file.delete();
              deletedFiles++;
            } catch (e) {
              // Skip files that can't be deleted
            }
          }
        }
      }
      
      // Clear app storage (downloaded media)
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
      
      // Mark cache cleaned today
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('last_cache_cleanup_date', today);
      
      // Set completion state instead of hiding
      if (mounted) {
        setState(() {
          _isCompleted = true;
          _completionMessage = 'Cleaned ${deletedFiles} cache files & ${appStorageFiles} app storage files ✅';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Cleanup complete! Cache: $deletedFiles files, App Storage: $appStorageFiles files'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Cleanup failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
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
  
  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }
    
    final isAdmin = widget.currentUserRole == 'admin';
    
    // Choose colors based on completion state
    final primaryColor = _isCompleted ? Colors.green : (isAdmin ? Colors.orange : Colors.blue);
    final backgroundColor1 = _isCompleted ? Colors.green.shade100 : (isAdmin ? Colors.orange.shade100 : Colors.blue.shade100);
    final backgroundColor2 = _isCompleted ? Colors.green.shade200 : (isAdmin ? Colors.orange.shade200 : Colors.blue.shade200);
    final iconColor = _isCompleted ? Colors.green.shade700 : (isAdmin ? Colors.orange.shade700 : Colors.blue.shade700);
    final textColor = _isCompleted ? Colors.green.shade800 : (isAdmin ? Colors.orange.shade800 : Colors.blue.shade800);
    final subtitleColor = _isCompleted ? Colors.green.shade600 : (isAdmin ? Colors.orange.shade600 : Colors.blue.shade600);
    
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _isLoading ? null : _showCleanupSheet,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        backgroundColor1.withOpacity(0.5),
                        backgroundColor2.withOpacity(0.5)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _isCompleted ? Icons.check_circle_outline : Icons.cleaning_services,
                        color: iconColor,
                        size: 24,
                      ),
                      if (_isLoading)
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: _dismissNotification,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCleanupSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final isAdmin = widget.currentUserRole == 'admin';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCompleted ? Icons.check_circle_outline : Icons.cleaning_services,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isCompleted
                            ? 'Cache already clean'
                            : (isAdmin ? 'Admin quick cleanup' : 'Quick cleanup assistant'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isCompleted
                      ? _completionMessage
                      : (isAdmin
                          ? 'Free up cached videos, app downloads, and thumbnails for everyone. Quick clean will remove files just from this device.'
                          : 'Remove cached announcements and media downloads to reclaim storage on this device.'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          if (_isCompleted) {
                            widget.onFullCleanup?.call();
                          } else {
                            _performCacheCleanup();
                          }
                        },
                  icon: Icon(_isCompleted ? Icons.manage_history : Icons.cleaning_services),
                  label: Text(_isCompleted ? 'Open cleanup tools' : 'Clean now'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.onFullCleanup != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      widget.onFullCleanup?.call();
                    },
                    icon: const Icon(Icons.settings_backup_restore),
                    label: const Text('Advanced cleanup options'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                if (!_isCompleted) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _dismissNotification();
                    },
                    child: const Text('Remind me tomorrow'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
