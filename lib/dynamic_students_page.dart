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

class _DynamicStudentsPageState extends State<DynamicStudentsPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  List<Map<String, dynamic>> _formFields = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFormConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
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
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'No Form Fields Yet',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Let AI create a perfect form for you',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openAIFormBuilder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.psychology_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Generate with AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Use enhanced grouped form builder with beautiful styling
            ...DynamicFormBuilderEnhanced.buildGroupedFields(
              fields: _formFields,
              controllers: _controllers,
            ),
            
            const SizedBox(height: 30),
            Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _addStudent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Add Student',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                strokeWidth: 3,
              ),
            ),
          );
        }

        final students = snapshot.data!.docs;

        if (students.isEmpty) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade100,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'No Students Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add your first student to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: Colors.white,
          child: ListView.builder(
            itemCount: students.length,
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              final doc = students[index];
              final data = doc.data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // Future: Navigate to student details
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6366F1),
                                  Color(0xFF8B5CF6),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getDisplayValue(data, 'name') ?? 
                                  _getDisplayValue(data, 'studentName') ?? 
                                  'Student ${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF1F2937),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._buildStudentDetails(data),
                              ],
                            ),
                          ),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.red.shade100,
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red.shade600,
                                size: 22,
                              ),
                              onPressed: () => _deleteStudent(doc.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
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
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label: $value',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return details.isEmpty 
        ? [
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'No additional information',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ] 
        : details;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Students Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6366F1),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.person_add_rounded),
              text: 'Add Student',
            ),
            Tab(
              icon: Icon(Icons.people_rounded),
              text: 'All Students',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDynamicForm(),
                _buildStudentsList(),
              ],
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _openAIFormBuilder,
          icon: const Icon(Icons.auto_awesome, color: Colors.white),
          label: const Text(
            'AI Form Builder',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
    );
  }
}

