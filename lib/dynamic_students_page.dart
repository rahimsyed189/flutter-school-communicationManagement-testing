import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ai_form_generator.dart';
import '../widgets/ai_form_builder_dialog.dart';
import '../widgets/dynamic_form_builder.dart';
import '../widgets/dynamic_form_builder_enhanced.dart';

class DynamicStudentsPage extends StatefulWidget {
  const DynamicStudentsPage({super.key});

  @override
  State<DynamicStudentsPage> createState() => _DynamicStudentsPageState();
}

class _DynamicStudentsPageState extends State<DynamicStudentsPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  List<Map<String, dynamic>> _formFields = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFormConfig();
  }

  Future<void> _loadFormConfig() async {
    setState(() => _loading = true);
    try {
      final fields = await AIFormGenerator.getFormConfig('students');
      setState(() {
        _formFields = fields;
        // Initialize controllers for each field
        for (var field in _formFields) {
          final fieldName = field['name'] as String;
          _controllers[fieldName] = TextEditingController();
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading form: $e')),
        );
      }
    }
  }

  Future<void> _openAIFormBuilder() async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false, // Make background visible (transparent)
        barrierColor: Colors.black.withOpacity(0.3), // Semi-transparent backdrop
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return const AIFormBuilderDialog(formType: 'students');
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide in from bottom-right corner with fade
          const begin = Offset(0.3, 0.3); // Start from bottom-right
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          
          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          var offsetAnimation = animation.drive(tween);
          
          var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: curve),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: offsetAnimation,
              child: child,
            ),
          );
        },
      ),
    );

    if (result == true) {
      // Fields were added, reload form
      _loadFormConfig();
    }
  }

  Future<void> _addStudent() async {
    if (_formKey.currentState?.validate() != true) return;

    try {
      // Collect all field values
      final Map<String, dynamic> studentData = {
        'createdAt': FieldValue.serverTimestamp(),
      };

      for (var field in _formFields) {
        final fieldName = field['name'] as String;
        final fieldType = field['type'] as String;
        final controller = _controllers[fieldName];

        if (controller != null && controller.text.isNotEmpty) {
          // Convert date strings to Timestamps
          if (fieldType == 'date') {
            final date = DynamicFormBuilder.parseDate(controller.text);
            if (date != null) {
              studentData[fieldName] = Timestamp.fromDate(date);
            }
          } else if (fieldType == 'checkbox') {
            studentData[fieldName] = controller.text == 'true';
          } else if (fieldType == 'number') {
            studentData[fieldName] = int.tryParse(controller.text) ?? controller.text;
          } else {
            studentData[fieldName] = controller.text;
          }
        }
      }

      await FirebaseFirestore.instance.collection('students').add(studentData);

      // Clear form
      for (var controller in _controllers.values) {
        controller.clear();
      }
      setState(() {
        _values.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Student added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteStudent(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('students').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Widget _buildDynamicForm() {
    if (_formFields.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 64, color: Colors.purple),
            const SizedBox(height: 16),
            const Text(
              'No form fields configured yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the AI button to generate fields',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openAIFormBuilder,
              icon: const Icon(Icons.psychology),
              label: const Text('Generate Fields with AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Use enhanced grouped form builder with beautiful styling
          ...DynamicFormBuilderEnhanced.buildGroupedFields(
            fields: _formFields,
            controllers: _controllers,
          ),
          
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _addStudent,
            icon: const Icon(Icons.add),
            label: const Text('Add Student'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = snapshot.data!.docs;

        if (students.isEmpty) {
          return const Center(
            child: Text('No students added yet'),
          );
        }

        return ListView.builder(
          itemCount: students.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final doc = students[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(
                  _getDisplayValue(data, 'name') ?? 
                  _getDisplayValue(data, 'studentName') ?? 
                  'Student ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildStudentDetails(data),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteStudent(doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _getDisplayValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is Timestamp) {
      return DynamicFormBuilder.formatDate(value.toDate());
    }
    return value.toString();
  }

  List<Widget> _buildStudentDetails(Map<String, dynamic> data) {
    final List<Widget> details = [];
    
    for (var field in _formFields) {
      final fieldName = field['name'] as String;
      final label = field['label'] as String;
      final value = _getDisplayValue(data, fieldName);
      
      if (value != null && value.isNotEmpty && fieldName != 'name' && fieldName != 'studentName') {
        details.add(
          Text(
            '$label: $value',
            style: const TextStyle(fontSize: 13),
          ),
        );
      }
    }

    return details.isEmpty ? [const Text('No additional information')] : details;
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Students (AI-Powered)'),
          backgroundColor: Colors.blue,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add), text: 'Add Student'),
              Tab(icon: Icon(Icons.list), text: 'All Students'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildDynamicForm(),
                  _buildStudentsList(),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAIFormBuilder,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('AI Fields'),
          backgroundColor: Colors.purple,
        ),
      ),
    );
  }
}
