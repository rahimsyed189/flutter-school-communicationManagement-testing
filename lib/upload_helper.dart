import 'dart:io';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';

class UploadHelper {
  static const int _chunkSize = 5 * 1024 * 1024; // 5MB chunks

  /// Safely reads a file in chunks to prevent memory issues
  static Stream<List<int>> createChunkedFileStream(String filePath) async* {
    final file = File(filePath);
    final randomAccess = await file.open(mode: FileMode.read);
    
    try {
      int position = 0;
      final fileLength = await randomAccess.length();
      
      while (position < fileLength) {
        final remainingBytes = fileLength - position;
        final chunkSize = remainingBytes < _chunkSize ? remainingBytes : _chunkSize;
        
        await randomAccess.setPosition(position);
        final chunk = await randomAccess.read(chunkSize);
        
        yield chunk;
        position += chunkSize;
      }
    } finally {
      await randomAccess.close();
    }
  }

  /// Prevents system from killing the app during long operations
  static Future<void> enableUploadMode() async {
    await WakelockPlus.enable();
  }

  /// Restores normal system behavior after upload
  static Future<void> disableUploadMode() async {
    await WakelockPlus.disable();
  }

  /// Formats file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Calculates upload speed
  static String calculateUploadSpeed(int bytesUploaded, Duration elapsed) {
    if (elapsed.inSeconds == 0) return '0 B/s';
    
    final bytesPerSecond = bytesUploaded / elapsed.inSeconds;
    return '${formatFileSize(bytesPerSecond.round())}/s';
  }

  /// Estimates remaining time
  static String estimateRemainingTime(int bytesUploaded, int totalBytes, Duration elapsed) {
    if (bytesUploaded == 0 || elapsed.inSeconds == 0) return 'Calculating...';
    
    final bytesPerSecond = bytesUploaded / elapsed.inSeconds;
    final remainingBytes = totalBytes - bytesUploaded;
    final remainingSeconds = (remainingBytes / bytesPerSecond).round();
    
    if (remainingSeconds < 60) return '${remainingSeconds}s';
    if (remainingSeconds < 3600) return '${(remainingSeconds / 60).round()}m';
    return '${(remainingSeconds / 3600).round()}h';
  }
}
