import 'dart:async';
import 'package:background_downloader/background_downloader.dart';

class PersistentDownloadManager {
  PersistentDownloadManager._private();
  static final PersistentDownloadManager instance = PersistentDownloadManager._private();

  final Map<String, DownloadTask> _tasks = {};
  final Map<String, TaskStatus> _statuses = {};
  final Map<String, double?> _progress = {};
  final StreamController<Map<String, double?>> _progressController = StreamController.broadcast();

  Stream<Map<String, double?>> get progressStream => _progressController.stream;

  void startDownload(String url) {
    if (_tasks.containsKey(url)) return;
    final filename = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final task = DownloadTask(
      url: url,
      filename: filename,
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      allowPause: true,
    );
    _tasks[url] = task;
    _statuses[url] = TaskStatus.enqueued;
    _progress[url] = 0.0;
    _progressController.add(_progress);
    FileDownloader().download(
      task,
      onProgress: (progress) {
        _progress[url] = progress;
        _progressController.add(_progress);
      },
      onStatus: (status) async {
        _statuses[url] = status;
        if (status == TaskStatus.complete || status == TaskStatus.failed || status == TaskStatus.canceled) {
          _tasks.remove(url);
          _progress.remove(url);
        }
        _progressController.add(_progress);
      },
    );
  }

  double? getProgress(String url) => _progress[url];
  TaskStatus? getStatus(String url) => _statuses[url];
}
