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
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundColor1, backgroundColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isCompleted 
              ? Icons.check_circle 
              : (isAdmin ? Icons.admin_panel_settings : Icons.cleaning_services),
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isCompleted 
                    ? '✅ Cleanup Complete!' 
                    : (isAdmin ? '🧹 Daily Cleanup Reminder' : '🧹 Clean Your Device'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isCompleted 
                    ? _completionMessage
                    : (isAdmin 
                      ? 'Keep the app running smoothly with daily cleanup'
                      : 'Free up space: Clear cache & downloaded media files'),
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_isCompleted) ...[
            // Completed state: Show green OK button
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: null, // Disabled when completed
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Done', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.green.shade600,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ] else if (isAdmin) ...[
            // Admin: Two buttons
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _performCacheCleanup,
                icon: _isLoading 
                  ? const SizedBox(
                      width: 12, 
                      height: 12, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : const Icon(Icons.cleaning_services, size: 16),
                label: const Text('Cache', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: widget.onFullCleanup,
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Full', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ] else ...[
            // User: Single button
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _performCacheCleanup,
                icon: _isLoading 
                  ? const SizedBox(
                      width: 12, 
                      height: 12, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : const Icon(Icons.cleaning_services, size: 16),
                label: const Text('Clean', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          // Dismiss button
          SizedBox(
            height: 32,
            width: 32,
            child: IconButton(
              onPressed: _dismissNotification,
              icon: const Icon(Icons.close, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.grey.shade700,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
