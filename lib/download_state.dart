import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistence for downloaded files mapping: url -> local path
class DownloadState {
  static const String _key = 'downloaded_files';
  static const String _thumbKey = 'downloaded_thumbnails';

  static Future<Map<String, String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return {};
      final Map<String, dynamic> map = jsonDecode(raw);
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> loadThumbnails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_thumbKey);
      if (raw == null || raw.isEmpty) return {};
      final Map<String, dynamic> map = jsonDecode(raw);
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(Map<String, String> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(map));
    } catch (_) {}
  }

  static Future<void> saveThumbnails(Map<String, String> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_thumbKey, jsonEncode(map));
    } catch (_) {}
  }

  static Future<void> put(String url, String path) async {
    final current = await load();
    current[url] = path;
    await save(current);
  }

  static Future<void> putThumbnail(String url, String path) async {
    final current = await loadThumbnails();
    current[url] = path;
    await saveThumbnails(current);
  }
}
