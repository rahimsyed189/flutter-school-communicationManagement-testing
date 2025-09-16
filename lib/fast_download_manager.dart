import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:collection';
import 'package:http/http.dart' as http;

class FastDownloadManager {
  static const int _defaultChunkSize = 1024 * 1024; // 1MB chunks
  static const int _maxConcurrentConnections = 4; // Parallel downloads
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 30);

  /// WhatsApp-style fast download with parallel connections
  static Future<void> downloadFileWithProgress({
    required String url,
    required String filePath,
    required Function(double progress, int downloadedBytes, int totalBytes, String speed) onProgress,
    Map<String, String>? headers,
    int? chunkSize,
    int? maxConnections,
  }) async {
    final actualChunkSize = chunkSize ?? _defaultChunkSize;
    final actualMaxConnections = maxConnections ?? _maxConcurrentConnections;

    print('FastDownload: Starting parallel download with $actualMaxConnections connections');
    print('FastDownload: Chunk size: ${_formatBytes(actualChunkSize)}');

    // Step 1: Get file size using HEAD request with Range GET fallback
    final fileSize = await _getFileSize(url, headers);
    if (fileSize == null) {
      // Fallback to single-stream download with best-effort total detection
      print('FastDownload: File size unknown, falling back to single-stream download');
      await _downloadSingleStream(
        url: url,
        filePath: filePath,
        headers: headers,
        onProgress: onProgress,
      );
      return;
    }

    print('FastDownload: File size: ${_formatBytes(fileSize)}');

    // Step 2: Calculate chunks for parallel download
    final chunks = _calculateChunks(fileSize, actualChunkSize, actualMaxConnections);
    print('FastDownload: Created ${chunks.length} chunks for parallel download');

    // Step 3: Create file and prepare for writing
    final file = File(filePath);
    await file.create(recursive: true);
    final randomAccessFile = await file.open(mode: FileMode.write);

    try {
      // Step 4: Download chunks in parallel
      await _downloadChunksInParallel(
        url: url,
        headers: headers,
        chunks: chunks,
        fileSize: fileSize,
        randomAccessFile: randomAccessFile,
        onProgress: onProgress,
        maxConnections: actualMaxConnections,
      );

      print('FastDownload: All chunks downloaded successfully');
    } finally {
      await randomAccessFile.close();
    }
  }

  /// Get file size using HEAD request. If not available, try a Range GET (bytes=0-0)
  static Future<int?> _getFileSize(String url, Map<String, String>? headers) async {
    try {
      final client = http.Client();
      final request = http.Request('HEAD', Uri.parse(url));
      
      if (headers != null) {
        request.headers.addAll(headers);
      }

      final response = await client.send(request).timeout(_connectionTimeout);
      client.close();

      if (response.statusCode == 200 || response.statusCode == 206) {
        final contentLength = response.headers['content-length'];
        if (contentLength != null) {
          return int.parse(contentLength);
        }
      }
    } catch (e) {
      print('FastDownload: Error getting file size: $e');
    }

    // Fallback 1: Try a Range GET for bytes=0-0 and parse Content-Range: bytes 0-0/total
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Range'] = 'bytes=0-0';
      if (headers != null) {
        request.headers.addAll(headers);
      }
      final response = await client.send(request).timeout(_connectionTimeout);

      if (response.statusCode == 206) {
        final contentRange = response.headers['content-range'];
        if (contentRange != null) {
          // Format: bytes 0-0/12345
          final parts = contentRange.split('/');
          if (parts.length == 2) {
            final totalStr = parts[1].trim();
            final total = int.tryParse(totalStr);
            if (total != null) {
              await response.stream.drain();
              client.close();
              return total;
            }
          }
        }
      }

      // If server answered 200, we might have Content-Length
      final cl = response.headers['content-length'];
      if (cl != null) {
        final total = int.tryParse(cl);
        await response.stream.drain();
        client.close();
        return total;
      }

      // Clean up
      await response.stream.drain();
      client.close();
    } catch (e) {
      print('FastDownload: Range GET fallback failed: $e');
    }

    return null;
  }

  /// Calculate optimal chunks for parallel download
  static List<DownloadChunk> _calculateChunks(int fileSize, int chunkSize, int maxConnections) {
    final chunks = <DownloadChunk>[];
    
    // Calculate optimal chunk size based on file size and max connections
    final optimalChunkSize = (fileSize / maxConnections).ceil();
    final actualChunkSize = optimalChunkSize < chunkSize ? optimalChunkSize : chunkSize;

    int start = 0;
    int chunkId = 0;

    while (start < fileSize) {
      final end = (start + actualChunkSize - 1).clamp(0, fileSize - 1);
      chunks.add(DownloadChunk(
        id: chunkId++,
        start: start,
        end: end,
        size: end - start + 1,
      ));
      start = end + 1;
    }

    return chunks;
  }

  /// Download chunks in parallel
  static Future<void> _downloadChunksInParallel({
    required String url,
    required Map<String, String>? headers,
    required List<DownloadChunk> chunks,
    required int fileSize,
    required RandomAccessFile randomAccessFile,
    required Function(double, int, int, String) onProgress,
    required int maxConnections,
  }) async {
    final downloadedBytes = List<int>.filled(chunks.length, 0);
    int totalDownloaded = 0;
    final startTime = DateTime.now();

    // Create progress timer
    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      final elapsed = DateTime.now().difference(startTime);
      final speed = _calculateSpeed(totalDownloaded, elapsed);
      final progress = totalDownloaded / fileSize;
      
      onProgress(progress, totalDownloaded, fileSize, speed);
    });

    try {
      // Download chunks in parallel using Future.wait with concurrency limit
      final semaphore = Semaphore(maxConnections.clamp(1, chunks.length));
      final writeSemaphore = Semaphore(1); // serialize writes to avoid RAF position races
      
      await Future.wait(
        chunks.map((chunk) async {
          await semaphore.acquire();
          try {
            await _downloadChunk(
              url: url,
              headers: headers,
              chunk: chunk,
              randomAccessFile: randomAccessFile,
              writeSemaphore: writeSemaphore,
              onChunkProgress: (bytes) {
                downloadedBytes[chunk.id] = bytes;
                totalDownloaded = downloadedBytes.reduce((a, b) => a + b);
              },
            );
          } finally {
            semaphore.release();
          }
        }),
      );

      // Final progress update
      final elapsed = DateTime.now().difference(startTime);
      final speed = _calculateSpeed(totalDownloaded, elapsed);
      onProgress(1.0, totalDownloaded, fileSize, speed);

    } finally {
      progressTimer?.cancel();
    }
  }

  /// Download a single chunk
  static Future<void> _downloadChunk({
    required String url,
    required Map<String, String>? headers,
    required DownloadChunk chunk,
    required RandomAccessFile randomAccessFile,
    required Semaphore writeSemaphore,
    required Function(int) onChunkProgress,
  }) async {
    const int maxRetries = 2;
    int attempt = 0;
    while (true) {
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));

        // Add Range header for chunk download
        request.headers['Range'] = 'bytes=${chunk.start}-${chunk.end}';

        if (headers != null) {
          request.headers.addAll(headers);
        }

        final response = await client.send(request).timeout(_connectionTimeout);

        if (response.statusCode != 206 && response.statusCode != 200) {
          throw Exception('Chunk download failed: ${response.statusCode}');
        }

        int chunkDownloaded = 0;
        final buffer = <int>[];
        const bufferSize = 8192; // 8KB buffer

        await for (final data in response.stream) {
          buffer.addAll(data);
          chunkDownloaded += data.length;
          onChunkProgress(chunkDownloaded);

          // Write buffer when it's full or at the end
          if (buffer.length >= bufferSize || chunkDownloaded >= chunk.size) {
            await writeSemaphore.acquire();
            try {
              await randomAccessFile.setPosition(chunk.start + chunkDownloaded - buffer.length);
              await randomAccessFile.writeFrom(buffer);
            } finally {
              writeSemaphore.release();
            }
            buffer.clear();
          }
        }
        // success
        break;
      } catch (e) {
        print('FastDownload: Chunk ${chunk.id} error (attempt ${attempt + 1}): $e');
        if (attempt >= maxRetries) {
          rethrow;
        }
        // small backoff
        await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        attempt++;
      } finally {
        client.close();
      }
    }
  }

  /// Calculate download speed
  static String _calculateSpeed(int bytes, Duration elapsed) {
    if (elapsed.inSeconds == 0) return '0 B/s';
    
    final bytesPerSecond = bytes / elapsed.inSeconds;
    return '${_formatBytes(bytesPerSecond.round())}/s';
  }

  /// Format bytes to human readable
  static String formatBytes(num bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format bytes to human readable (private)
  static String _formatBytes(num bytes) => formatBytes(bytes);

  /// Single-stream download fallback when size is unknown or server doesn't support Range
  static Future<void> _downloadSingleStream({
    required String url,
    required String filePath,
    required Map<String, String>? headers,
    required Function(double progress, int downloadedBytes, int totalBytes, String speed) onProgress,
  }) async {
    final file = File(filePath);
    await file.create(recursive: true);
    final sink = file.openWrite();

    final client = http.Client();
    final startTime = DateTime.now();
    int downloaded = 0;
    int total = 0;
    Timer? progressTimer;
    try {
      final request = http.Request('GET', Uri.parse(url));
      if (headers != null) request.headers.addAll(headers);
      final response = await client.send(request).timeout(_connectionTimeout);

      total = int.tryParse(response.headers['content-length'] ?? '') ?? 0;

      progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        final elapsed = DateTime.now().difference(startTime);
        final speed = _calculateSpeed(downloaded, elapsed);
        final progress = total > 0 ? (downloaded / total) : 0.0;
        onProgress(progress, downloaded, total, speed);
      });

      await for (final data in response.stream) {
        downloaded += data.length;
        sink.add(data);
      }

      // final update
      final elapsed = DateTime.now().difference(startTime);
      final speed = _calculateSpeed(downloaded, elapsed);
      onProgress(1.0, downloaded, total, speed);
    } finally {
      await sink.close();
      progressTimer?.cancel();
      client.close();
    }
  }
}

/// Represents a download chunk
class DownloadChunk {
  final int id;
  final int start;
  final int end;
  final int size;

  DownloadChunk({
    required this.id,
    required this.start,
    required this.end,
    required this.size,
  });

  @override
  String toString() => 'Chunk $id: $start-$end (${FastDownloadManager._formatBytes(size)})';
}

/// Semaphore for controlling concurrent downloads
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
