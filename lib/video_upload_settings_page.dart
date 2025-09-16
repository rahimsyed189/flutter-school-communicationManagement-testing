import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoUploadSettingsPage extends StatefulWidget {
  const VideoUploadSettingsPage({super.key});

  @override
  State<VideoUploadSettingsPage> createState() => _VideoUploadSettingsPageState();
}

class _VideoUploadSettingsPageState extends State<VideoUploadSettingsPage> {
  String _defaultQuality = 'medium';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _docPath = 'app_config';
  static const _docId = 'upload_settings';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final doc = await FirebaseFirestore.instance.collection(_docPath).doc(_docId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final q = (data['defaultVideoQuality'] as String?)?.toLowerCase();
        if (q != null && ['low','medium','high','original'].contains(q)) {
          _defaultQuality = q;
        }
      }
    } catch (e) {
      _error = 'Failed to load: $e';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _save(String q) async {
    setState(() { _saving = true; _error = null; });
    try {
      await FirebaseFirestore.instance.collection(_docPath).doc(_docId).set(
        {'defaultVideoQuality': q},
        SetOptions(merge: true),
      );
      if (mounted) {
        setState(() { _defaultQuality = q; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to save: $e'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Upload settings')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  const ListTile(
                    title: Text('Default compression quality'),
                    subtitle: Text('Used as the default when uploading videos'),
                  ),
                  for (final q in const ['low','medium','high','original'])
                    RadioListTile<String>(
                      title: Text(q[0].toUpperCase() + q.substring(1)),
                      value: q,
                      groupValue: _defaultQuality,
                      onChanged: _saving ? null : (v) { if (v != null) _save(v); },
                    ),
                  if (_error != null) Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
      ),
    );
  }
}
