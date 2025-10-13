import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/ai_form_generator.dart';

class AIFormBuilderDialog extends StatefulWidget {
  final String formType; // 'students' or 'staff'
  
  const AIFormBuilderDialog({
    super.key,
    required this.formType,
  });

  @override
  State<AIFormBuilderDialog> createState() => _AIFormBuilderDialogState();
}

class _AIFormBuilderDialogState extends State<AIFormBuilderDialog> {
  final _promptController = TextEditingController();
  bool _generating = false;
  String? _error;
  List<Map<String, dynamic>>? _generatedFields;
  List<Map<String, dynamic>>? _currentFields;
  bool _loadingCurrentFields = true;
  bool _showCurrentFields = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentFields();
  }

  Future<void> _loadCurrentFields() async {
    setState(() => _loadingCurrentFields = true);
    
    final fields = await AIFormGenerator.getFormConfig(widget.formType);
    
    setState(() {
      _currentFields = fields;
      _loadingCurrentFields = false;
    });
  }

  Future<void> _generateFields() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _error = 'Please describe what fields you need';
      });
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
      _generatedFields = null;
    });

    try {
      // If we have current fields, include a concise summary in the prompt
      String enhancedPrompt = prompt;
      if (_currentFields != null && _currentFields!.isNotEmpty) {
        // Create a concise summary (just count by group)
        final groups = <String, int>{};
        for (var field in _currentFields!) {
          final group = field['group'] as String? ?? 'Other';
          groups[group] = (groups[group] ?? 0) + 1;
        }
        final groupsSummary = groups.entries.map((e) => '${e.value}x ${e.key}').join(', ');
        enhancedPrompt = 'Existing groups: $groupsSummary. New request: $prompt';
      }
      
      final fields = await AIFormGenerator.generateFields(enhancedPrompt);
      
      if (fields == null || fields.isEmpty) {
        setState(() {
          _error = 'No fields generated. Please try a different prompt.';
          _generating = false;
        });
        return;
      }

      setState(() {
        _generatedFields = fields;
        _generating = false;
      });
    } catch (e) {
      // Display the detailed error message from the API
      setState(() {
        _error = e.toString();
        _generating = false;
      });
      
      // Show snackbar for critical errors (quota, rate limit, auth issues)
      if (e.toString().contains('quota') || 
          e.toString().contains('rate limit') ||
          e.toString().contains('invalid') ||
          e.toString().contains('expired')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _addFields() async {
    if (_generatedFields == null || _generatedFields!.isEmpty) return;

    setState(() {
      _generating = true;
      _error = null;
    });

    final success = await AIFormGenerator.addFieldsToForm(
      formType: widget.formType,
      fields: _generatedFields!,
    );

    if (success) {
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate fields were added
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Added ${_generatedFields!.length} field(s) successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() {
        _error = 'Failed to save fields';
        _generating = false;
      });
    }
  }

  Future<void> _clearAllFields() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Fields?'),
        content: const Text(
          'This will remove all current form fields. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AIFormGenerator.clearFormConfig(widget.formType);
      if (success) {
        await _loadCurrentFields();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ All fields cleared successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85), // More transparent for glass effect
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(-5, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with glass effect
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade600.withOpacity(0.85),
                            Colors.blue.shade600.withOpacity(0.85),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'AI Form Builder',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                children: [
                  // Current Fields Section
                  if (_currentFields != null && _currentFields!.isNotEmpty) ...[
                    Card(
                      color: Colors.blue.shade50,
                      child: Column(
                        children: [
                          ExpansionTile(
                            title: Row(
                              children: [
                                Icon(Icons.list_alt, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Current Form Fields (${_currentFields!.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: _loadCurrentFields,
                                  tooltip: 'Refresh',
                                  color: Colors.blue.shade700,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: _clearAllFields,
                                  tooltip: 'Clear All Fields',
                                  color: Colors.red.shade700,
                                ),
                                Icon(
                                  _showCurrentFields 
                                    ? Icons.keyboard_arrow_up 
                                    : Icons.keyboard_arrow_down,
                                  color: Colors.blue.shade700,
                                ),
                              ],
                            ),
                            initiallyExpanded: _showCurrentFields,
                            onExpansionChanged: (expanded) {
                              setState(() => _showCurrentFields = expanded);
                            },
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: _currentFields!.map((field) {
                                    final groupColor = _getColorFromName(field['groupColor'] as String?);
                                    final groupIcon = _getIconFromName(field['groupIcon'] as String?);
                                    
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      elevation: 2,
                                      child: ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          backgroundColor: groupColor.withOpacity(0.2),
                                          radius: 18,
                                          child: Icon(
                                            groupIcon,
                                            color: groupColor,
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          field['label'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Type: ${field['type']} • ${field['required'] == true ? 'Required' : 'Optional'}',
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            if (field['group'] != null)
                                              Text(
                                                'Group: ${field['group']}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: groupColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Input Section
                  const Text(
                    'Describe what fields you need:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promptController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _currentFields != null && _currentFields!.isNotEmpty
                          ? 'Example: "Add blood group field to Medical Info section" or "Change student name to use blue color"'
                          : 'Example: "Create a student admission form with personal and contact details"',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Generate Button
                  ElevatedButton.icon(
                    onPressed: _generating ? null : _generateFields,
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.psychology),
                    label: Text(_generating ? 'Generating...' : 'Generate Fields'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Discover Models Button (DEBUG)
                  ElevatedButton.icon(
                    onPressed: _generating ? null : () async {
                      setState(() => _generating = true);
                      await AIFormGenerator.discoverAvailableModels();
                      setState(() => _generating = false);
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('🔍 Discover Available Models'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  
                  // Error Message
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Generated Fields Preview
                  if (_generatedFields != null && _generatedFields!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      '✨ Generated Fields:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    
                    ..._generatedFields!.map((field) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Icon(
                              _getIconForFieldType(field['type'] as String),
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            field['label'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Type: ${field['type']}'),
                              if (field['required'] == true)
                                const Text(
                                  'Required',
                                  style: TextStyle(color: Colors.orange, fontSize: 12),
                                ),
                              if (field['options'] != null)
                                Text(
                                  'Options: ${(field['options'] as List).join(', ')}',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                          ),
                        ),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 16),
                    
                    // Add Fields Button
                    ElevatedButton.icon(
                      onPressed: _generating ? null : _addFields,
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Add These Fields to Form'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                  
                  // Examples Section
                  if (_generatedFields == null) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      '💡 Example Prompts:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (_currentFields != null && _currentFields!.isNotEmpty) ...[
                      _buildExampleChip('Add blood group field to Medical Info section with red color'),
                      _buildExampleChip('Create a new Academic Details section with current grade and subjects'),
                      _buildExampleChip('Add emergency contact fields using orange color'),
                      _buildExampleChip('Reorganize fields into better groups with different colors'),
                    ] else ...[
                      _buildExampleChip('Create a complete student admission form'),
                      _buildExampleChip('I need personal info and contact details sections'),
                      _buildExampleChip('Add address with city, state, and pincode'),
                      _buildExampleChip('Medical information section with blood group'),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    ),
    ),
    );
  }

  Widget _buildExampleChip(String example) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () {
          _promptController.text = example;
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  example,
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForFieldType(String type) {
    switch (type) {
      case 'text':
        return Icons.text_fields;
      case 'number':
        return Icons.numbers;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'date':
        return Icons.calendar_today;
      case 'dropdown':
        return Icons.arrow_drop_down_circle;
      case 'textarea':
        return Icons.subject;
      case 'checkbox':
        return Icons.check_box;
      default:
        return Icons.input;
    }
  }

  Color _getColorFromName(String? colorName) {
    if (colorName == null) return Colors.blue;
    switch (colorName.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      case 'teal':
        return Colors.teal;
      case 'pink':
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  IconData _getIconFromName(String? iconName) {
    if (iconName == null) return Icons.info;
    switch (iconName.toLowerCase()) {
      case 'person':
        return Icons.person;
      case 'phone':
        return Icons.phone;
      case 'school':
        return Icons.school;
      case 'medical':
      case 'medical_services':
        return Icons.medical_services;
      case 'location':
      case 'location_on':
        return Icons.location_on;
      case 'calendar':
      case 'calendar_today':
        return Icons.calendar_today;
      case 'star':
        return Icons.star;
      default:
        return Icons.info;
    }
  }
}
