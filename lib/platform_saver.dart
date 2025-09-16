import 'dart:io';
import 'package:flutter/services.dart';

class PlatformSaver {
  static const _channel = MethodChannel('com.adbsmalltech.media');

  // Returns true on success
  static Future<bool> saveVideoToPhotos(String path) async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod('saveVideoToPhotos', { 'path': path });
      return res == true;
    } catch (_) {
      return false;
    }
  }
}
