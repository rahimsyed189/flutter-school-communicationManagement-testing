import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class R2ConfigPage extends StatefulWidget {
  const R2ConfigPage({super.key});

  @override
  State<R2ConfigPage> createState() => _R2ConfigPageState();
}

class _R2ConfigPageState extends State<R2ConfigPage> {
  final _accountIdController = TextEditingController();
  final _accessKeyIdController = TextEditingController();
  final _secretAccessKeyController = TextEditingController();
  final _bucketNameController = TextEditingController();
  final _customDomainController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _configured = false;

  static const _docPath = 'app_config';
  static const _docId = 'r2_settings';

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
        _accountIdController.text = data['accountId'] ?? '';
        _accessKeyIdController.text = data['accessKeyId'] ?? '';
        _secretAccessKeyController.text = data['secretAccessKey'] ?? '';
        _bucketNameController.text = data['bucketName'] ?? '';
        _customDomainController.text = data['customDomain'] ?? '';
        _configured = [
          _accountIdController.text,
          _accessKeyIdController.text,
          _secretAccessKeyController.text,
          _bucketNameController.text
        ].every((v) => v.isNotEmpty);
      } else {
        _configured = false;
      }
    } catch (e) {
      _error = 'Failed to load: $e';
      _configured = false;
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await FirebaseFirestore.instance.collection(_docPath).doc(_docId).set({
        'accountId': _accountIdController.text.trim(),
        'accessKeyId': _accessKeyIdController.text.trim(),
        'secretAccessKey': _secretAccessKeyController.text.trim(),
        'bucketName': _bucketNameController.text.trim(),
        'customDomain': _customDomainController.text.trim(),
      }, SetOptions(merge: true));
      _configured = [
        _accountIdController.text,
        _accessKeyIdController.text,
        _secretAccessKeyController.text,
        _bucketNameController.text
      ].every((v) => v.isNotEmpty);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to save: $e'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  Future<void> _clear() async {
    setState(() { _saving = true; _error = null; });
    try {
      await FirebaseFirestore.instance.collection(_docPath).doc(_docId).set({
        'accountId': '',
        'accessKeyId': '',
        'secretAccessKey': '',
        'bucketName': '',
        'customDomain': '',
      }, SetOptions(merge: true));
      _accountIdController.clear();
      _accessKeyIdController.clear();
      _secretAccessKeyController.clear();
      _bucketNameController.clear();
      _customDomainController.clear();
      _configured = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('R2 config cleared')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to clear: $e'; });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _accessKeyIdController.dispose();
    _secretAccessKeyController.dispose();
    _bucketNameController.dispose();
    _customDomainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('R2 Config')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Cloudflare R2 API Keys', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 8),
                    if (_configured)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20)
                    else
                      const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _accountIdController,
                  decoration: const InputDecoration(labelText: 'Account ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accessKeyIdController,
                  decoration: const InputDecoration(labelText: 'Access Key ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secretAccessKeyController,
                  decoration: const InputDecoration(labelText: 'Secret Access Key'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bucketNameController,
                  decoration: const InputDecoration(labelText: 'Bucket Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customDomainController,
                  decoration: const InputDecoration(labelText: 'Custom Domain (optional)'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Update'),
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Config'),
                        onPressed: _saving ? null : _clear,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        onPressed: _saving ? null : () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                if (_error != null) Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
    );
  }
}
