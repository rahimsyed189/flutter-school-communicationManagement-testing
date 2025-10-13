import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeminiConfigPage extends StatefulWidget {
  const GeminiConfigPage({super.key});

  @override
  State<GeminiConfigPage> createState() => _GeminiConfigPageState();
}

class _GeminiConfigPageState extends State<GeminiConfigPage> {
  final _apiKeyController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _configured = false;

  static const _docPath = 'app_config';
  static const _docId = 'gemini_config';

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
        _apiKeyController.text = data['apiKey'] ?? '';
        _configured = _apiKeyController.text.isNotEmpty;
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
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() { _error = 'API Key cannot be empty'; });
      return;
    }
    
    setState(() { _saving = true; _error = null; });
    try {
      await FirebaseFirestore.instance.collection(_docPath).doc(_docId).set({
        'apiKey': apiKey,
        'enabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _configured = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Gemini API Key saved successfully!'))
        );
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
        'apiKey': '',
        'enabled': false,
      }, SetOptions(merge: true));
      
      _apiKeyController.clear();
      _configured = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gemini API config cleared'))
        );
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
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini AI Config'),
        backgroundColor: Colors.blue,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status Badge
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Google Gemini AI Configuration',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_configured)
                      const Icon(Icons.check_circle, color: Colors.green, size: 24)
                    else
                      const Icon(Icons.cancel, color: Colors.redAccent, size: 24),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Info Card
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'AI-Powered Dynamic Forms',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enable Gemini AI to dynamically generate form fields using natural language. '
                          'Admins can describe what they need and AI will create the fields automatically!',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // API Key Input
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'AIzaSy...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: _apiKeyController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _apiKeyController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                
                // How to get API key
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'How to get your FREE API Key:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('1. Visit: https://aistudio.google.com/app/apikey', style: TextStyle(fontSize: 13)),
                        const Text('2. Click "Create API Key in new project"', style: TextStyle(fontSize: 13)),
                        const Text('3. Copy the generated key and paste above', style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 8),
                        const Text(
                          '✅ Completely FREE (15 requests/min, 1M tokens/day)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Error Message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    if (_configured) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _clear,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                
                // Features Card
                Card(
                  color: Colors.purple.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.purple.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'What you can do with AI:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('🤖 "Add a field for blood group"', style: TextStyle(fontSize: 13)),
                        const Text('🤖 "I need emergency contact details"', style: TextStyle(fontSize: 13)),
                        const Text('🤖 "Add medical information section"', style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 8),
                        const Text(
                          '→ AI will automatically create the fields!',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
