import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/draggable_template_components.dart';
import 'widgets/custom_template_renderer.dart';
import 'template_builder_page.dart';
import 'dart:math';
import 'dart:typed_data';
import 'services/school_context.dart';

enum TemplateType {
  general,
  event,
  exam,
  result,
  fee,
}

class TemplateManagementPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;

  const TemplateManagementPage({
    Key? key,
    required this.currentUserId,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  State<TemplateManagementPage> createState() => _TemplateManagementPageState();
}

class _TemplateManagementPageState extends State<TemplateManagementPage> {
  TemplateType _selectedTemplate = TemplateType.general;
  final PageController _pageController = PageController();
  List<Map<String, dynamic>> _customTemplates = [];
  String? _selectedCustomTemplate;
  bool _isLoadingCustomTemplates = true;

  @override
  void initState() {
    super.initState();
    _loadCustomTemplates();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomTemplates() async {
    try {
      // Try with index first
      QuerySnapshot querySnapshot;
      try {
        // Simple query without ordering to avoid index requirement
        // 🔥 Filter by schoolId
        querySnapshot = await FirebaseFirestore.instance
            .collection('custom_templates')
            .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
            .where('isActive', isEqualTo: true)
            .get();
      } catch (error) {
        // If even simple query fails, get all templates and filter locally
        print('Filtered query failed, getting all templates: $error');
        // 🔥 Filter by schoolId
        querySnapshot = await FirebaseFirestore.instance
            .collection('custom_templates')
            .where('schoolId', isEqualTo: SchoolContext.currentSchoolId)
            .get();
      }

      final templates = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).where((template) => template['isActive'] == true).toList();

      // Sort locally by createdAt (newest first)
      templates.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // descending order
      });

      // Sort manually if we couldn't use orderBy
      templates.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _customTemplates = templates;
        _isLoadingCustomTemplates = false;
      });
    } catch (e) {
      setState(() {
        _customTemplates = []; // Set empty list instead of keeping old data
        _isLoadingCustomTemplates = false;
      });
      print('Error loading custom templates: $e');
      // Show user-friendly message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load custom templates. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Custom Templates',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF673AB7)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TemplateBuilderPage(),
                ),
              );
              if (result == true) {
                _loadCustomTemplates();
              }
            },
            tooltip: 'Create New Template',
          ),
        ],
      ),
      body: _isLoadingCustomTemplates
          ? const Center(child: CircularProgressIndicator())
          : _customTemplates.isEmpty
              ? _buildEmptyState()
              : _buildCustomTemplatesGrid(),
    );
  }

  Widget _buildCustomTemplateContent() {
    if (_selectedCustomTemplate == null) {
      return const Center(child: Text('No custom template selected'));
    }
    
    final customTemplate = _customTemplates.firstWhere(
      (template) => template['id'] == _selectedCustomTemplate,
      orElse: () => {},
    );
    
    if (customTemplate.isEmpty) {
      return const Center(child: Text('Custom template not found'));
    }
    
    return Column(
      children: [
        // Header with delete button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  customTemplate['templateName'] ?? 'Custom Template',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  _deleteCustomTemplate(
                    customTemplate['id'] as String,
                    customTemplate['templateName'] ?? 'Custom Template',
                  );
                },
                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                tooltip: 'Delete Template',
              ),
            ],
          ),
        ),
        // Template content
        Expanded(
          child: CustomTemplatePost(
            templateData: customTemplate,
            currentUserId: widget.currentUserId,
            currentUserRole: widget.currentUserRole,
          ),
        ),
      ],
    );
  }

  /// Navigate to edit an existing custom template
  Future<void> _editCustomTemplate(String templateId) async {
    try {
      final customTemplate = _customTemplates.firstWhere(
        (template) => template['id'] == templateId,
      );
      
      // Navigate to template builder for editing
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TemplateBuilderPage(
            existingTemplate: customTemplate,
            templateId: templateId,
            currentUserId: widget.currentUserId,
            currentUserRole: widget.currentUserRole,
          ),
        ),
      );
      
      // If a template was successfully saved, refresh custom templates
      if (result == true) {
        _loadCustomTemplates();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template not found'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Delete a custom template with confirmation
  Future<void> _deleteCustomTemplate(String templateId, String templateName) async {
    // Show confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.delete_forever,
                color: Colors.red,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Delete Template',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "$templateName"?',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('custom_templates')
            .doc(templateId)
            .delete();

        // Remove from local list
        setState(() {
          _customTemplates.removeWhere((template) => template['id'] == templateId);
          // Clear selection if deleted template was selected
          if (_selectedCustomTemplate == templateId) {
            _selectedCustomTemplate = null;
          }
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "$templateName" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete template: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Custom Templates',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your first custom template\nto get started',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TemplateBuilderPage(),
                ),
              );
              if (result == true) {
                _loadCustomTemplates();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF673AB7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTemplatesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Show 3 cards per row instead of 2
        childAspectRatio: 0.75, // Increased height to prevent overflow with long names
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _customTemplates.length,
      itemBuilder: (context, index) {
        final customTemplate = _customTemplates[index];
        return _buildCustomTemplateGridCard(customTemplate, index);
      },
    );
  }

  Widget _buildCustomTemplateGridCard(Map<String, dynamic> customTemplate, int index) {
    final templateId = customTemplate['id'] as String;
    final templateName = customTemplate['templateName'] ?? 'Untitled Template';
    final canvasWidth = (customTemplate['canvasWidth'] as num?)?.toDouble() ?? 350.0;
    final canvasHeight = (customTemplate['canvasHeight'] as num?)?.toDouble() ?? 500.0;
    final canvasColor = Color(customTemplate['canvasBackgroundColor'] ?? 0xFFFFFFFF);
    
    // Generate vibrant colors for each card
    final List<List<Color>> gradientColors = [
      [const Color(0xFF667EEA), const Color(0xFF764BA2)], // Purple
      [const Color(0xFFF093FB), const Color(0xFFF5576C)], // Pink
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)], // Blue
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)], // Green
      [const Color(0xFFFA709A), const Color(0xFFFEE140)], // Orange-Pink
      [const Color(0xFF30CFD0), const Color(0xFF330867)], // Teal-Purple
      [const Color(0xFFA8EDEA), const Color(0xFFFED6E3)], // Mint-Pink
      [const Color(0xFFFFD89B), const Color(0xFF19547B)], // Yellow-Blue
    ];
    
    final cardGradient = gradientColors[index % gradientColors.length];
    
    return GestureDetector(
      onTap: () => _editCustomTemplate(templateId),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardGradient[0].withOpacity(0.1),
                cardGradient[1].withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Colorful Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: cardGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.description,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Template Name
                    Text(
                      templateName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Delete button in top-right corner
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    onPressed: () => _deleteCustomTemplate(templateId, templateName),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: Colors.red[400],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTemplateColor(TemplateType type) {
    switch (type) {
      case TemplateType.general:
        return const Color(0xFFFF5722); // Deep Orange
      case TemplateType.event:
        return const Color(0xFF9C27B0); // Purple
      case TemplateType.exam:
        return const Color(0xFFE91E63); // Pink
      case TemplateType.result:
        return const Color(0xFF00BCD4); // Cyan
      case TemplateType.fee:
        return const Color(0xFF795548); // Brown
    }
  }

  Widget _buildTemplateForm(TemplateType templateType) {
    // If a custom template is selected, show its post form
    if (_selectedCustomTemplate != null) {
      final customTemplate = _customTemplates.firstWhere(
        (template) => template['id'] == _selectedCustomTemplate,
        orElse: () => {},
      );
      if (customTemplate.isNotEmpty) {
        return CustomTemplatePost(
          templateData: customTemplate,
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        );
      }
    }

    switch (templateType) {
      case TemplateType.general:
        return _GeneralTemplate(
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        );
      case TemplateType.event:
        return _EventTemplate(
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        );
      case TemplateType.exam:
        return _ExamTemplate(
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        );
      case TemplateType.result:
        return _ResultTemplate(
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        );
      case TemplateType.fee:
        return _FeeTemplate(
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        );
    }
  }

  IconData _getTemplateIcon(TemplateType type) {
    switch (type) {
      case TemplateType.general:
        return Icons.announcement;
      case TemplateType.event:
        return Icons.event;
      case TemplateType.exam:
        return Icons.quiz;
      case TemplateType.result:
        return Icons.grade;
      case TemplateType.fee:
        return Icons.payment;
    }
  }

  String _getTemplateName(TemplateType type) {
    switch (type) {
      case TemplateType.general:
        return 'General';
      case TemplateType.event:
        return 'Event';
      case TemplateType.exam:
        return 'Exam';
      case TemplateType.result:
        return 'Result';
      case TemplateType.fee:
        return 'Fee';
    }
  }
}

// Placeholder templates (similar structure)
class _GeneralTemplate extends StatelessWidget {
  final String currentUserId;
  final String currentUserRole;
  const _GeneralTemplate({required this.currentUserId, required this.currentUserRole});
  @override
  Widget build(BuildContext context) => Center(child: Text('General Announcement Template\n(Under Development)', style: TextStyle(fontSize: 18, color: Colors.grey[600]), textAlign: TextAlign.center));
}

class _EventTemplate extends StatelessWidget {
  final String currentUserId;
  final String currentUserRole;
  const _EventTemplate({required this.currentUserId, required this.currentUserRole});
  @override
  Widget build(BuildContext context) => Center(child: Text('Event Template\n(Under Development)', style: TextStyle(fontSize: 18, color: Colors.grey[600]), textAlign: TextAlign.center));
}

class _ExamTemplate extends StatelessWidget {
  final String currentUserId;
  final String currentUserRole;
  const _ExamTemplate({required this.currentUserId, required this.currentUserRole});
  @override
  Widget build(BuildContext context) => Center(child: Text('Exam Template\n(Under Development)', style: TextStyle(fontSize: 18, color: Colors.grey[600]), textAlign: TextAlign.center));
}

class _ResultTemplate extends StatelessWidget {
  final String currentUserId;
  final String currentUserRole;
  const _ResultTemplate({required this.currentUserId, required this.currentUserRole});
  @override
  Widget build(BuildContext context) => Center(child: Text('Result Template\n(Under Development)', style: TextStyle(fontSize: 18, color: Colors.grey[600]), textAlign: TextAlign.center));
}

class _FeeTemplate extends StatelessWidget {
  final String currentUserId;
  final String currentUserRole;
  const _FeeTemplate({required this.currentUserId, required this.currentUserRole});
  @override
  Widget build(BuildContext context) => Center(child: Text('Fee Template\n(Under Development)', style: TextStyle(fontSize: 18, color: Colors.grey[600]), textAlign: TextAlign.center));
}

// CustomTemplatePost widget for rendering custom templates
// Custom Template Builder Widget 
class _CustomTemplateBuilder extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;
  final VoidCallback? onTemplateAdded;

  const _CustomTemplateBuilder({
    required this.currentUserId,
    required this.currentUserRole,
    this.onTemplateAdded,
  });

  @override
  State<_CustomTemplateBuilder> createState() => _CustomTemplateBuilderState();
}

class _CustomTemplateBuilderState extends State<_CustomTemplateBuilder> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Custom Template Builder',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Under Development',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// Animated Template Card Widget
class _AnimatedTemplateCard extends StatefulWidget {
  final Map<String, dynamic> customTemplate;
  final bool isSelected;
  final Color templateColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AnimatedTemplateCard({
    required this.customTemplate,
    required this.isSelected,
    required this.templateColor,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_AnimatedTemplateCard> createState() => _AnimatedTemplateCardState();
}

class _AnimatedTemplateCardState extends State<_AnimatedTemplateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tap to edit • Long press to delete',
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              onLongPress: widget.onLongPress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                transform: widget.isSelected 
                    ? (Matrix4.identity()..scale(1.05))
                    : Matrix4.identity(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.isSelected 
                              ? [widget.templateColor, widget.templateColor.withOpacity(0.7)]
                              : [widget.templateColor.withOpacity(0.2), widget.templateColor.withOpacity(0.1)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: widget.isSelected 
                            ? Border.all(color: widget.templateColor, width: 2)
                            : null,
                        boxShadow: widget.isSelected ? [
                          BoxShadow(
                            color: widget.templateColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return RotationTransition(
                            turns: animation,
                            child: ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          Icons.auto_awesome,
                          key: ValueKey(widget.isSelected),
                          color: widget.isSelected ? Colors.white : widget.templateColor,
                          size: widget.isSelected ? 24 : 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
                        color: widget.isSelected ? widget.templateColor : Colors.grey[600],
                      ),
                      child: Text(
                        widget.customTemplate['templateName'] ?? 'Custom',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Custom clipper for ribbon notch/tail
class _NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.75, size.height);
    path.lineTo(size.width * 0.25, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Custom clipper for horizontal ribbon tail
class _HorizontalNotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * 0.8, 0);
    path.lineTo(size.width, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

