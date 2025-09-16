import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CleanupNotificationBar extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;
  final VoidCallback? onFullCleanup; // For admins - opens cleanup page
  
  const CleanupNotificationBar({
    Key? key,
    required this.currentUserId,
    required this.currentUserRole,
    this.onFullCleanup,
  }) : super(key: key);

  @override
  State<CleanupNotificationBar> createState() => _CleanupNotificationBarState();
}

class _CleanupNotificationBarState extends State<CleanupNotificationBar> {
  bool _isVisible = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _checkShouldShow();
  }
  
  Future<void> _checkShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDismissed = prefs.getString('cleanup_notification_dismissed');
    final lastCacheCleanup = prefs.getString('last_cache_cleanup_date');
    
    // Show if:
    // 1. Not dismissed today, AND
    // 2. Cache not cleaned today
    final shouldShow = lastDismissed != today && lastCacheCleanup != today;
    
    if (mounted) {
      setState(() {
        _isVisible = shouldShow;
      });
    }
  }
  
  Future<void> _dismissNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('cleanup_notification_dismissed', today);
    
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
      
      // Mark cache cleaned today
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('last_cache_cleanup_date', today);
      
      // Auto-dismiss notification
      await _dismissNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Cache cleaned! Deleted $deletedFiles files'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Cache cleanup failed: $e'),
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
    
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAdmin 
            ? [Colors.orange.shade100, Colors.orange.shade200]
            : [Colors.blue.shade100, Colors.blue.shade200],
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.cleaning_services,
              color: isAdmin ? Colors.orange.shade700 : Colors.blue.shade700,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAdmin ? '🧹 Daily Cleanup Reminder' : '🧹 Clean Your Cache',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAdmin ? Colors.orange.shade800 : Colors.blue.shade800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAdmin 
                      ? 'Keep the app running smoothly with daily cleanup'
                      : 'Free up space by clearing temporary files',
                    style: TextStyle(
                      color: isAdmin ? Colors.orange.shade600 : Colors.blue.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isAdmin) ...[
              // Admin: Two buttons - Quick Cache + Full Cleanup
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
                    minimumSize: const Size(60, 32),
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
                    minimumSize: const Size(60, 32),
                  ),
                ),
              ),
            ] else ...[
              // User: Single cache cleanup button
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
                    minimumSize: const Size(70, 32),
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
      ),
    );
  }
}

// Helper widget to wrap any page with cleanup notification
class PageWithCleanupNotification extends StatelessWidget {
  final Widget child;
  final String currentUserId;
  final String currentUserRole;
  final VoidCallback? onFullCleanup;
  
  const PageWithCleanupNotification({
    Key? key,
    required this.child,
    required this.currentUserId,
    required this.currentUserRole,
    this.onFullCleanup,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: CleanupNotificationBar(
            currentUserId: currentUserId,
            currentUserRole: currentUserRole,
            onFullCleanup: onFullCleanup,
          ),
        ),
      ],
    );
  }
}
