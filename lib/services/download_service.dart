import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

/// Lazy initialization service for FileDownloader
/// Configures the downloader only when first download is attempted
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  bool _isConfigured = false;
  bool _isConfiguring = false;

  /// Ensure FileDownloader is configured before use
  /// This replaces the startup configuration for better performance
  Future<void> ensureConfigured() async {
    // If already configured, return immediately
    if (_isConfigured) return;
    
    // If currently configuring, wait for it to complete
    if (_isConfiguring) {
      while (_isConfiguring) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _isConfiguring = true;
    
    try {
      await FileDownloader().configure();
      _isConfigured = true;
      debugPrint('✅ FileDownloader configured on first use (lazy initialization)');
    } catch (e) {
      debugPrint('⚠️ Error configuring FileDownloader: $e');
      // Don't set _isConfigured to true on error
    } finally {
      _isConfiguring = false;
    }
  }

  /// Download a file with automatic configuration
  Future<TaskStatusUpdate> download(
    DownloadTask task, {
    Function(double)? onProgress,
    Function(TaskStatus)? onStatus,
  }) async {
    // Ensure configured before downloading
    await ensureConfigured();
    
    return FileDownloader().download(
      task,
      onProgress: onProgress,
      onStatus: onStatus,
    );
  }

  /// Move file to shared storage with automatic configuration
  Future<String?> moveToSharedStorage(DownloadTask task, SharedStorage storage) async {
    await ensureConfigured();
    return FileDownloader().moveToSharedStorage(task, storage);
  }

  /// Pause download with automatic configuration
  Future<bool> pause(DownloadTask task) async {
    await ensureConfigured();
    return FileDownloader().pause(task);
  }

  /// Resume download with automatic configuration
  Future<bool> resume(DownloadTask task) async {
    await ensureConfigured();
    return FileDownloader().resume(task);
  }

  /// Cancel downloads with automatic configuration
  Future<bool> cancelTasksWithIds(List<String> taskIds) async {
    await ensureConfigured();
    return FileDownloader().cancelTasksWithIds(taskIds);
  }

  /// Check if downloader is configured
  bool get isConfigured => _isConfigured;
}