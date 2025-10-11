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
        querySnapshot = await FirebaseFirestore.instance
            .collection('custom_templates')
            .where('isActive', isEqualTo: true)
            .get();
      } catch (error) {
        // If even simple query fails, get all templates and filter locally
        print('Filtered query failed, getting all templates: $error');
        querySnapshot = await FirebaseFirestore.instance
            .collection('custom_templates')
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Horizontal Scrollable Template Selection (Built-in + Custom)
          Container(
            height: 90,
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Built-in templates
                  ...TemplateType.values.map((templateType) {
                    final isSelected = _selectedTemplate == templateType && _selectedCustomTemplate == null;
                    final templateColor = _getTemplateColor(templateType);
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTemplate = templateType;
                          _selectedCustomTemplate = null;
                        });
                        final index = TemplateType.values.indexOf(templateType);
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isSelected 
                                      ? [templateColor, templateColor.withOpacity(0.7)]
                                      : [templateColor.withOpacity(0.2), templateColor.withOpacity(0.1)],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: isSelected 
                                    ? Border.all(color: templateColor, width: 2)
                                    : null,
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: templateColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : null,
                              ),
                              child: Icon(
                                _getTemplateIcon(templateType),
                                color: isSelected ? Colors.white : templateColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _getTemplateName(templateType),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? templateColor : Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  
                  // Custom templates
                  if (_customTemplates.isNotEmpty) ...[
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    ..._customTemplates.map((customTemplate) {
                      final isSelected = _selectedCustomTemplate == customTemplate['id'];
                      const templateColor = Color(0xFF673AB7);
                      
                      return _AnimatedTemplateCard(
                        customTemplate: customTemplate,
                        isSelected: isSelected,
                        templateColor: templateColor,
                        onTap: () {
                          _editCustomTemplate(customTemplate['id'] as String);
                        },
                        onLongPress: () {
                          _deleteCustomTemplate(
                            customTemplate['id'] as String,
                            customTemplate['templateName'] ?? 'Custom Template',
                          );
                        },
                      );
                    }).toList(),
                  ],
                  
                  // Loading indicator for custom templates
                  if (_isLoadingCustomTemplates)
                    Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.only(right: 12),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Template Preview and Form
          Expanded(
            child: _selectedCustomTemplate != null
                ? _buildCustomTemplateContent()
                : PageView.builder(
                    controller: _pageController,
                    itemCount: TemplateType.values.length,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedTemplate = TemplateType.values[index];
                        _selectedCustomTemplate = null;
                      });
                    },
                    itemBuilder: (context, index) {
                      final templateType = TemplateType.values[index];
                      return _buildTemplateForm(templateType);
                    },
                  ),
          ),
        ],
      ),
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

class _CustomTemplateBuilderState extends State<_CustomTemplateBuilder> {
  final List<DraggableComponent> _canvasComponents = [];
  final TextEditingController _templateNameController = TextEditingController();
  String? _selectedComponentId;
  bool _isLoading = false;
  final GlobalKey _canvasKey = GlobalKey();
  bool _isPaletteCollapsed = false;
  bool _isPropertiesCollapsed = false;
  bool _isFloatingPaletteExpanded = false;

  // Canvas properties
  double canvasWidth = 350;
  double canvasHeight = 500;
  Color canvasBackgroundColor = Colors.white;
  bool _autoAlignment = false;

  @override
  void dispose() {
    _templateNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 800;
    
    if (isTablet) {
      // Desktop/Tablet Layout
      return Row(
        children: [
          // Component Palette (Left Side) - Collapsible
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isPaletteCollapsed ? 50 : 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!_isPaletteCollapsed) ...[
                      Text(
                        'Components',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const Spacer(),
                    ],
                    IconButton(
                      icon: Icon(
                        _isPaletteCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_left,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPaletteCollapsed = !_isPaletteCollapsed;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                  ],
                ),
                if (!_isPaletteCollapsed) ...[
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildComponentCategory('Basic', [
                            _buildComponentPalette(ComponentType.textLabel, 'Text', Icons.text_fields),
                            _buildComponentPalette(ComponentType.textBox, 'Text Box', Icons.text_snippet),
                            _buildComponentPalette(ComponentType.iconContainer, 'Icon', Icons.star),
                          ]),
                          const SizedBox(height: 12),
                          _buildComponentCategory('Containers', [
                            _buildComponentPalette(ComponentType.coloredContainer, 'Color Box', Icons.rectangle),
                            _buildComponentPalette(ComponentType.woodenContainer, 'Wood Box', Icons.inventory_2),
                          ]),
                          const SizedBox(height: 12),
                          _buildComponentCategory('Date/Time', [
                            _buildComponentPalette(ComponentType.calendar, 'Calendar', Icons.calendar_today),
                            _buildComponentPalette(ComponentType.dateContainer, 'Date Box', Icons.event),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Collapsed icons only
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildCollapsedComponent(ComponentType.textLabel, Icons.text_fields),
                          _buildCollapsedComponent(ComponentType.calendar, Icons.calendar_today),
                          _buildCollapsedComponent(ComponentType.coloredContainer, Icons.rectangle),
                          _buildCollapsedComponent(ComponentType.woodenContainer, Icons.inventory_2),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Canvas Area (Center)
          Expanded(
            flex: 2,
            child: _buildCanvasArea(),
          ),
          // Properties Panel (Right Side) - Collapsible
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isPropertiesCollapsed ? 50 : 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPropertiesCollapsed ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_right,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPropertiesCollapsed = !_isPropertiesCollapsed;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                    if (!_isPropertiesCollapsed) ...[
                      const Spacer(),
                      Text(
                        'Properties',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
                if (!_isPropertiesCollapsed) ...[
                  const SizedBox(height: 12),
                  Expanded(
                    child: _selectedComponentId != null
                        ? _buildPropertiesPanel()
                        : const Center(
                            child: Text(
                              'Select a component to edit properties',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                ] else ...[
                  // Collapsed state - just show if component is selected
                  const SizedBox(height: 12),
                  if (_selectedComponentId != null)
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF673AB7).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.settings,
                        size: 16,
                        color: Color(0xFF673AB7),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      );
    } else {
      // Mobile Layout - Vertical Tabs (Removed Components tab as they're available in canvas)
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Tab Bar
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Color(0xFF673AB7),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF673AB7),
                tabs: [
                  Tab(icon: Icon(Icons.design_services), text: 'Canvas'),
                  Tab(icon: Icon(Icons.settings), text: 'Properties'),
                ],
              ),
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                children: [
                  _buildMobileCanvasTab(),
                  _buildMobilePropertiesTab(),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCanvasArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Canvas Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactEmojiTextField(_templateNameController, 'Template Name'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveTemplate,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(_isLoading ? 'Saving...' : 'Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF673AB7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Canvas Controls Row
                Row(
                  children: [
                    // Canvas Size Controls
                    Text('Size: ${canvasWidth.toInt()}x${canvasHeight.toInt()}', 
                         style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showCanvasSizeDialog(),
                      icon: const Icon(Icons.aspect_ratio, size: 18),
                      tooltip: 'Resize Canvas',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 16),
                    // Auto Alignment Toggle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Auto Align:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.8,
                          child: Checkbox(
                            value: _autoAlignment,
                            onChanged: (value) {
                              setState(() {
                                _autoAlignment = value ?? false;
                                if (_autoAlignment && _canvasComponents.isNotEmpty) {
                                  _performAutoAlignment();
                                }
                              });
                            },
                            activeColor: const Color(0xFF673AB7),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Manual Align Button
                        IconButton(
                          onPressed: _canvasComponents.length > 1 ? () {
                            setState(() {
                              _performAutoAlignment();
                            });
                          } : null,
                          icon: const Icon(Icons.align_horizontal_left, size: 18),
                          tooltip: 'Align Components Now',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Background Color
                    const Text('Background:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showCanvasBackgroundDialog(),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: canvasBackgroundColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Canvas
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Canvas Background
                    Container(
                      key: _canvasKey,
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: canvasBackgroundColor,
                        // Removed grid pattern to fix asset error
                      ),
                    ),
                    // Drop Target
                    DragTarget<ComponentType>(
                      onAccept: (componentType) {
                        _addComponentToCanvas(componentType, const Offset(50, 50));
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            border: candidateData.isNotEmpty
                                ? Border.all(color: Colors.blue, width: 2)
                                : null,
                          ),
                          child: Stack(
                            children: [
                              // Canvas Components
                              ..._canvasComponents.map((component) => 
                                _buildCanvasComponent(component)
                              ),
                              
                              // Floating Component Palette
                              _buildFloatingComponentPalette(),
                              
                              // Empty state message
                              if (_canvasComponents.isEmpty)
                                const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.drag_handle,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 16),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 20),
                                        child: Text(
                                          'Use floating palette or drag components here',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileComponentsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildComponentCategory('Basic Elements', [
              _buildMobileComponentPalette(ComponentType.textLabel, 'Text Label', Icons.text_fields),
              _buildMobileComponentPalette(ComponentType.textBox, 'Text Box', Icons.text_snippet),
              _buildMobileComponentPalette(ComponentType.iconContainer, 'Icon', Icons.star),
              _buildMobileComponentPalette(ComponentType.imageContainer, 'Image', Icons.image),
            ]),
            const SizedBox(height: 20),
            _buildComponentCategory('Containers', [
              _buildMobileComponentPalette(ComponentType.coloredContainer, 'Colored Box', Icons.rectangle),
              _buildMobileComponentPalette(ComponentType.woodenContainer, 'Wooden Box', Icons.inventory_2),
            ]),
            const SizedBox(height: 20),
            _buildComponentCategory('Date & Time', [
              _buildMobileComponentPalette(ComponentType.calendar, 'Calendar', Icons.calendar_today),
              _buildMobileComponentPalette(ComponentType.dateContainer, 'Date Box', Icons.event),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCanvasTab() {
    return _buildCanvasArea();
  }

  Widget _buildMobilePropertiesTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: _selectedComponentId != null
          ? _buildPropertiesPanel()
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.settings,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No Component Selected',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Go to Canvas tab and select a component to edit its properties',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildComponentCategory(String title, List<Widget> components) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ...components,
      ],
    );
  }

  Widget _buildComponentPalette(ComponentType type, String name, IconData icon) {
    return Draggable<ComponentType>(
      data: type,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF673AB7).withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        height: 50,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF673AB7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: const Color(0xFF673AB7), size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileComponentPalette(ComponentType type, String label, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Draggable<ComponentType>(
        data: type,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 120,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF673AB7).withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.grey.shade300,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon, 
                    color: Colors.grey.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Dragging $label...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF673AB7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon, 
                  color: const Color(0xFF673AB7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drag to add to canvas',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF673AB7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedComponent(ComponentType type, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Draggable<ComponentType>(
        data: type,
        feedback: Material(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF673AB7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF673AB7).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF673AB7).withOpacity(0.3)),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF673AB7),
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingComponentPalette() {
    return Positioned(
      top: 20,
      right: 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isFloatingPaletteExpanded ? 200 : 50,
        height: _isFloatingPaletteExpanded ? 300 : 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isFloatingPaletteExpanded 
            ? _buildExpandedFloatingPalette()
            : _buildCollapsedFloatingPalette(),
      ),
    );
  }

  Widget _buildCollapsedFloatingPalette() {
    return InkWell(
      onTap: () {
        setState(() {
          _isFloatingPaletteExpanded = true;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF673AB7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildExpandedFloatingPalette() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            children: [
              const Text(
                'Components',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF673AB7),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isFloatingPaletteExpanded = false;
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Component buttons
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildFloatingComponentButton(ComponentType.textLabel, 'Text', Icons.text_fields),
                  _buildFloatingComponentButton(ComponentType.textBox, 'Text Box', Icons.text_snippet),
                  _buildFloatingComponentButton(ComponentType.calendar, 'Calendar', Icons.calendar_today),
                  _buildFloatingComponentButton(ComponentType.dateContainer, 'Date Box', Icons.event),
                  _buildFloatingComponentButton(ComponentType.coloredContainer, 'Color Box', Icons.rectangle),
                  _buildFloatingComponentButton(ComponentType.woodenContainer, 'Wood Box', Icons.inventory_2),
                  _buildFloatingComponentButton(ComponentType.iconContainer, 'Icon', Icons.star),
                  _buildFloatingComponentButton(ComponentType.imageContainer, 'Image', Icons.image),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingComponentButton(ComponentType type, String name, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Add component to center of canvas when tapped
          _addComponentToCanvas(type, Offset(canvasWidth / 2 - 75, canvasHeight / 2 - 50));
          // Auto-collapse the palette
          setState(() {
            _isFloatingPaletteExpanded = false;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: const Color(0xFF673AB7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasComponent(DraggableComponent component) {
    final isSelected = _selectedComponentId == component.id;
    
    return Positioned(
      left: component.x,
      top: component.y,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedComponentId = component.id;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            component.x += details.delta.dx;
            component.y += details.delta.dy;
            // Keep component within canvas bounds
            component.x = component.x.clamp(0, canvasWidth - component.width);
            component.y = component.y.clamp(0, canvasHeight - component.height);
          });
        },
        onPanEnd: (details) {
          // Apply auto-alignment when dragging ends
          if (_autoAlignment) {
            setState(() {
              _performAutoAlignment();
            });
          }
        },
        child: Container(
          width: component.width,
          height: component.height,
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: const Color(0xFF673AB7), width: 2)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main component
              Positioned.fill(
                child: component.buildWidget(),
              ),
              
              // Selection handles and controls
              if (isSelected) ...[
                // Delete button (top-right) - Made bigger and more visible
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    onTap: () => _removeComponent(component.id),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),

                // Edit button (top-left) - Made bigger and more visible
                Positioned(
                  top: -12,
                  left: -12,
                  child: GestureDetector(
                    onTap: () => _editComponent(component),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF673AB7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),

                // Resize handle (bottom-right) - Made bigger for better usability
                Positioned(
                  bottom: -8,
                  right: -8,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        component.width = (component.width + details.delta.dx).clamp(50.0, 300.0);
                        component.height = (component.height + details.delta.dy).clamp(30.0, 300.0);
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF673AB7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),

                // Move handle (top-center) - Added for better drag control
                Positioned(
                  top: -10,
                  left: (component.width / 2) - 10,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        component.x += details.delta.dx;
                        component.y += details.delta.dy;
                        // Keep component within canvas bounds
                        component.x = component.x.clamp(0, canvasWidth - component.width);
                        component.y = component.y.clamp(0, canvasHeight - component.height);
                      });
                    },
                    onPanEnd: (details) {
                      // Apply auto-alignment when dragging ends
                      if (_autoAlignment) {
                        setState(() {
                          _performAutoAlignment();
                        });
                      }
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.drag_indicator,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertiesPanel() {
    final component = _canvasComponents.firstWhere(
      (c) => c.id == _selectedComponentId,
      orElse: () => _canvasComponents.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Component: ${component.type.name}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        // Size controls
        Text(
          'Size',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Width', style: TextStyle(fontSize: 10)),
                  Slider(
                    value: component.width,
                    min: 50,
                    max: 300,
                    divisions: 25,
                    label: component.width.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        component.width = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Height', style: TextStyle(fontSize: 10)),
                  Slider(
                    value: component.height,
                    min: 30,
                    max: 200,
                    divisions: 17,
                    label: component.height.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        component.height = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Position controls
        Text(
          'Position',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('X', style: TextStyle(fontSize: 10)),
                  Slider(
                    value: component.x,
                    min: 0,
                    max: canvasWidth - component.width,
                    divisions: 20,
                    label: component.x.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        component.x = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Y', style: TextStyle(fontSize: 10)),
                  Slider(
                    value: component.y,
                    min: 0,
                    max: canvasHeight - component.height,
                    divisions: 20,
                    label: component.y.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        component.y = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Component-specific properties button
        ElevatedButton.icon(
          onPressed: () => _showComponentEditDialog(component),
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Edit Properties'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: Colors.black87,
          ),
        ),
      ],
    );
  }

  void _addComponentToCanvas(ComponentType type, Offset position) {
    final String id = 'component_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    
    DraggableComponent component;
    switch (type) {
      case ComponentType.calendar:
        component = CalendarComponent(id: id, x: position.dx, y: position.dy);
        break;
      case ComponentType.dateContainer:
        component = DateContainerComponent(id: id, x: position.dx, y: position.dy);
        break;
      case ComponentType.textLabel:
        component = TextLabelComponent(id: id, x: position.dx, y: position.dy);
        break;
      case ComponentType.textBox:
        component = TextBoxComponent(id: id, x: position.dx, y: position.dy);
        break;
      case ComponentType.woodenContainer:
        component = WoodenContainerComponent(id: id, x: position.dx, y: position.dy);
        break;
      case ComponentType.coloredContainer:
        component = ColoredContainerComponent(id: id, x: position.dx, y: position.dy);
        break;
      case ComponentType.imageContainer:
        component = ImageContainerComponent(id: id, x: position.dx, y: position.dy);
        break;
      case ComponentType.iconContainer:
        component = IconContainerComponent(id: id, x: position.dx, y: position.dy);
        break;
      case ComponentType.gradientDivider:
        component = GradientDividerComponent(id: id, x: position.dx, y: position.dy);
        break;
      case ComponentType.multipleChoice:
        component = MultipleChoiceComponent(id: id, x: position.dx, y: position.dy);
        break;
    }

    setState(() {
      _canvasComponents.add(component);
      _selectedComponentId = component.id;
    });
  }

  void _removeComponent(String componentId) {
    setState(() {
      _canvasComponents.removeWhere((c) => c.id == componentId);
      if (_selectedComponentId == componentId) {
        _selectedComponentId = null;
      }
    });
  }

  void _editComponent(DraggableComponent component) {
    // For text components, enable inline editing in canvas, not properties dialog
    if (component.type == ComponentType.textLabel || component.type == ComponentType.textBox) {
      _showInlineTextEditor(component);
    } else if (component.type == ComponentType.dateContainer) {
      // For date components, show date picker inline
      _showInlineDatePicker(component);
    } else {
      // For other components, use properties for styling only
      _showStylePropertiesDialog(component);
    }
  }

  void _showInlineTextEditor(DraggableComponent component) {
    final currentText = component.properties['text'] ?? 'Sample Text';
    final textController = TextEditingController(text: currentText);
    bool showEmojiPicker = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${component.type == ComponentType.textLabel ? 'Label' : 'Text Box'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        labelText: 'Text Content',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: component.type == ComponentType.textBox ? 3 : 1,
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions, color: Colors.orange),
                    tooltip: 'Add Emojis',
                    onPressed: () {
                      setDialogState(() {
                        showEmojiPicker = !showEmojiPicker;
                      });
                    },
                  ),
                ],
              ),
              if (showEmojiPicker) ...[
                const SizedBox(height: 16),
                _buildEmojiPicker(textController),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  component.properties['text'] = textController.text;
                });
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker(TextEditingController textController) {
    // Popular emojis categorized
    final List<List<String>> emojiCategories = [
      // Smileys & People
      ['😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙'],
      // Hearts & Love
      ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝'],
      // Celebration & Party
      ['🎉', '🎊', '🥳', '🎈', '🎁', '🎂', '🍰', '🧁', '🎇', '🎆', '✨', '⭐', '🌟', '💫', '🔥', '💥', '🎵', '🎶'],
      // School & Education
      ['📚', '📖', '📝', '✏️', '📏', '📐', '🎒', '🏫', '👨‍🏫', '👩‍🏫', '👨‍🎓', '👩‍🎓', '🎓', '📜', '🏆', '🥇', '🥈', '🥉'],
      // Common Objects
      ['📱', '💻', '📧', '📞', '📍', '📅', '⏰', '🔔', '📢', '📣', '⚠️', '❗', '❓', '✅', '❌', '🔴', '🟠', '🟡'],
    ];

    return Container(
      height: 200,
      width: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTabController(
        length: emojiCategories.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: const [
                Tab(text: '😀'),
                Tab(text: '❤️'),
                Tab(text: '🎉'),
                Tab(text: '📚'),
                Tab(text: '📱'),
              ],
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorSize: TabBarIndicatorSize.tab,
            ),
            Expanded(
              child: TabBarView(
                children: emojiCategories.map((category) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: category.length,
                    itemBuilder: (context, index) {
                      final emoji = category[index];
                      return GestureDetector(
                        onTap: () {
                          // Insert emoji at cursor position
                          final currentText = textController.text;
                          final selection = textController.selection;
                          final newText = currentText.replaceRange(
                            selection.start,
                            selection.end,
                            emoji,
                          );
                          textController.text = newText;
                          textController.selection = TextSelection.collapsed(
                            offset: selection.start + emoji.length,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey.shade50,
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiTextFormField({
    required TextEditingController controller,
    required String hintText,
    required String labelText,
    Icon? prefixIcon,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    bool showEmojiPicker = false;
    
    return StatefulBuilder(
      builder: (context, setFieldState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  onChanged: onChanged,
                  maxLines: maxLines,
                  decoration: InputDecoration(
                    hintText: hintText,
                    labelText: labelText,
                    prefixIcon: prefixIcon,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.emoji_emotions, color: Colors.orange, size: 20),
                      tooltip: 'Add Emojis',
                      onPressed: () {
                        setFieldState(() {
                          showEmojiPicker = !showEmojiPicker;
                        });
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), 
                      borderSide: const BorderSide(color: Colors.orange, width: 2)
                    ),
                    filled: true, 
                    fillColor: const Color(0xFFF8F9FA),
                  ),
                ),
              ),
            ],
          ),
          if (showEmojiPicker) ...[
            const SizedBox(height: 8),
            _buildCompactEmojiPicker(controller),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactEmojiPicker(TextEditingController textController) {
    // More compact emoji picker for forms
    final List<String> popularEmojis = [
      // Most used emojis for school communications
      '😀', '😊', '😍', '🥰', '😎', '🤗', '😇', '🙂', '😉', '😋',
      '👍', '👏', '🙌', '💪', '✨', '⭐', '🌟', '🔥', '💯', '❤️',
      '🎉', '🎊', '🥳', '🎈', '🎁', '🎂', '🏆', '🥇', '📚', '📖',
      '✏️', '📝', '🎒', '🏫', '👨‍🏫', '👩‍🏫', '👨‍🎓', '👩‍🎓', '🎓', '📜',
    ];

    return Container(
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: popularEmojis.length,
        itemBuilder: (context, index) {
          final emoji = popularEmojis[index];
          return GestureDetector(
            onTap: () {
              // Insert emoji at cursor position
              final currentText = textController.text;
              final selection = textController.selection;
              final newText = currentText.replaceRange(
                selection.start,
                selection.end,
                emoji,
              );
              textController.text = newText;
              textController.selection = TextSelection.collapsed(
                offset: selection.start + emoji.length,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade50,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactEmojiTextField(TextEditingController controller, String labelText) {
    bool showEmojiPicker = false;
    
    return StatefulBuilder(
      builder: (context, setFieldState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: IconButton(
                icon: const Icon(Icons.emoji_emotions, color: Colors.orange, size: 18),
                tooltip: 'Add Emojis',
                onPressed: () {
                  setFieldState(() {
                    showEmojiPicker = !showEmojiPicker;
                  });
                },
              ),
            ),
          ),
          if (showEmojiPicker) ...[
            const SizedBox(height: 4),
            Container(
              height: 80,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
                color: Colors.white,
              ),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 12,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: 24, // Just show top emojis for compact view
                itemBuilder: (context, index) {
                  final List<String> topEmojis = [
                    '😀', '😊', '😍', '🥰', '😎', '🤗', '😇', '🙂', '😉', '😋',
                    '👍', '👏', '🙌', '💪', '✨', '⭐', '🌟', '🔥', '💯', '❤️',
                    '🎉', '🎊', '🥳', '🎈'
                  ];
                  final emoji = topEmojis[index];
                  return GestureDetector(
                    onTap: () {
                      final currentText = controller.text;
                      final selection = controller.selection;
                      final newText = currentText.replaceRange(
                        selection.start,
                        selection.end,
                        emoji,
                      );
                      controller.text = newText;
                      controller.selection = TextSelection.collapsed(
                        offset: selection.start + emoji.length,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.grey.shade50,
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showInlineDatePicker(DraggableComponent component) {
    final currentDate = component.properties['selectedDate'] is int 
        ? DateTime.fromMillisecondsSinceEpoch(component.properties['selectedDate'])
        : DateTime.now();
    
    showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    ).then((selectedDate) {
      if (selectedDate != null) {
        setState(() {
          component.properties['selectedDate'] = selectedDate.millisecondsSinceEpoch;
        });
      }
    });
  }

  void _showStylePropertiesDialog(DraggableComponent component) {
    // Show only styling properties, not content editing
    showDialog(
      context: context,
      builder: (context) => _buildStyleOnlyDialog(component),
    );
  }

  Widget _buildStyleOnlyDialog(DraggableComponent component) {
    if (component.type == ComponentType.textLabel || component.type == ComponentType.textBox) {
      return _buildTextStyleDialog(component);
    } else if (component.type == ComponentType.coloredContainer || component.type == ComponentType.woodenContainer) {
      return _buildContainerStyleDialog(component);
    } else {
      return _buildGeneralStyleDialog(component);
    }
  }

  Widget _buildTextStyleDialog(DraggableComponent component) {
    double fontSize = component.properties['fontSize']?.toDouble() ?? 16.0;
    String fontWeight = component.properties['fontWeight'] ?? 'normal';
    String alignment = component.properties['alignment'] ?? 'center';
    Color textColor = Color(component.properties['textColor'] ?? Colors.black87.value);
    Color backgroundColor = Color(component.properties['backgroundColor'] ?? Colors.transparent.value);

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Text Styling'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Font Size
                Text('Font Size: ${fontSize.toInt()}'),
                Slider(
                  value: fontSize,
                  min: 8,
                  max: 32,
                  divisions: 24,
                  onChanged: (value) => setState(() => fontSize = value),
                ),
                
                // Font Weight
                DropdownButton<String>(
                  value: fontWeight,
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'bold', child: Text('Bold')),
                  ],
                  onChanged: (value) => setState(() => fontWeight = value ?? 'normal'),
                ),
                
                // Alignment
                DropdownButton<String>(
                  value: alignment,
                  items: const [
                    DropdownMenuItem(value: 'left', child: Text('Left')),
                    DropdownMenuItem(value: 'center', child: Text('Center')),
                    DropdownMenuItem(value: 'right', child: Text('Right')),
                  ],
                  onChanged: (value) => setState(() => alignment = value ?? 'center'),
                ),
                
                // Text Color
                const SizedBox(height: 10),
                const Text('Text Color:'),
                Wrap(
                  children: [
                    Colors.black87, Colors.white, Colors.red, Colors.blue,
                    Colors.green, Colors.orange, Colors.purple, Colors.brown,
                  ].map((color) => GestureDetector(
                    onTap: () => setState(() => textColor = color),
                    child: Container(
                      width: 30, height: 30, margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle,
                        border: textColor == color ? Border.all(width: 3) : null,
                      ),
                    ),
                  )).toList(),
                ),
                
                // Background Color
                const SizedBox(height: 10),
                const Text('Background Color:'),
                Wrap(
                  children: [
                    Colors.transparent, Colors.white, Colors.grey.shade200,
                    Colors.blue.shade100, Colors.green.shade100, Colors.orange.shade100,
                  ].map((color) => GestureDetector(
                    onTap: () => setState(() => backgroundColor = color),
                    child: Container(
                      width: 30, height: 30, margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle,
                        border: backgroundColor == color ? Border.all(width: 3) : null,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                this.setState(() {
                  component.properties.addAll({
                    'fontSize': fontSize,
                    'fontWeight': fontWeight,
                    'alignment': alignment,
                    'textColor': textColor.value,
                    'backgroundColor': backgroundColor.value,
                  });
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContainerStyleDialog(DraggableComponent component) {
    Color backgroundColor = Color(component.properties['backgroundColor'] ?? Colors.blue.value);
    
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Container Styling'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Background Color:'),
              const SizedBox(height: 10),
              Wrap(
                children: [
                  Colors.blue, Colors.red, Colors.green, Colors.orange,
                  Colors.purple, Colors.brown, Colors.grey, Colors.teal,
                ].map((color) => GestureDetector(
                  onTap: () => setState(() => backgroundColor = color),
                  child: Container(
                    width: 40, height: 40, margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(8),
                      border: backgroundColor == color ? Border.all(width: 3) : null,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                this.setState(() {
                  component.properties['backgroundColor'] = backgroundColor.value;
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGeneralStyleDialog(DraggableComponent component) {
    return AlertDialog(
      title: const Text('Component Styling'),
      content: const Text('Styling options will be available for this component type.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _showCanvasSizeDialog() {
    double tempWidth = canvasWidth;
    double tempHeight = canvasHeight;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Canvas Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Width: ${tempWidth.toInt()}px'),
              Slider(
                value: tempWidth,
                min: 250,
                max: 500,
                divisions: 25,
                onChanged: (value) => setState(() => tempWidth = value),
              ),
              const SizedBox(height: 16),
              Text('Height: ${tempHeight.toInt()}px'),
              Slider(
                value: tempHeight,
                min: 300,
                max: 700,
                divisions: 40,
                onChanged: (value) => setState(() => tempHeight = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                this.setState(() {
                  canvasWidth = tempWidth;
                  canvasHeight = tempHeight;
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCanvasBackgroundDialog() {
    final backgroundColors = [
      Colors.white,
      Colors.grey.shade100,
      Colors.grey.shade200,
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.purple.shade50,
      Colors.red.shade50,
      Colors.yellow.shade50,
      Colors.teal.shade50,
      Colors.pink.shade50,
      Colors.indigo.shade50,
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Canvas Background'),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: backgroundColors.length,
            itemBuilder: (context, index) {
              final color = backgroundColors[index];
              final isSelected = canvasBackgroundColor == color;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    canvasBackgroundColor = color;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF673AB7) : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF673AB7))
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _performAutoAlignment() {
    if (_canvasComponents.length < 2) return;

    // Detect if components are more aligned vertically or horizontally
    bool isColumnLayout = _detectColumnLayout();
    
    if (isColumnLayout) {
      _alignComponentsInColumn();
    } else {
      _alignComponentsInRow();
    }
  }

  bool _detectColumnLayout() {
    if (_canvasComponents.length < 2) return false;

    // Calculate the span in X and Y directions
    double minX = _canvasComponents.map((c) => c.x).reduce((a, b) => a < b ? a : b);
    double maxX = _canvasComponents.map((c) => c.x + c.width).reduce((a, b) => a > b ? a : b);
    double minY = _canvasComponents.map((c) => c.y).reduce((a, b) => a < b ? a : b);
    double maxY = _canvasComponents.map((c) => c.y + c.height).reduce((a, b) => a > b ? a : b);

    double xSpan = maxX - minX;
    double ySpan = maxY - minY;

    // If the vertical span is significantly larger than horizontal span, it's a column
    // If they're similar, use variance method as fallback
    if (ySpan > xSpan * 1.5) return true;
    if (xSpan > ySpan * 1.5) return false;

    // Fallback to variance calculation for ambiguous cases
    double avgX = _canvasComponents.map((c) => c.x).reduce((a, b) => a + b) / _canvasComponents.length;
    double avgY = _canvasComponents.map((c) => c.y).reduce((a, b) => a + b) / _canvasComponents.length;
    
    double xVariance = _canvasComponents.map((c) => (c.x - avgX) * (c.x - avgX)).reduce((a, b) => a + b) / _canvasComponents.length;
    double yVariance = _canvasComponents.map((c) => (c.y - avgY) * (c.y - avgY)).reduce((a, b) => a + b) / _canvasComponents.length;

    return xVariance <= yVariance;
  }

  void _alignComponentsInColumn() {
    if (_canvasComponents.isEmpty) return;

    // Calculate the average X position for center alignment, or use leftmost for left alignment
    double avgX = _canvasComponents.map((c) => c.x).reduce((a, b) => a + b) / _canvasComponents.length;
    double leftmostX = _canvasComponents.map((c) => c.x).reduce((a, b) => a < b ? a : b);
    
    // Use average X but ensure it's not too close to edges
    double alignX = avgX.clamp(20.0, canvasWidth - 150);
    
    // Sort components by Y position and align them vertically
    final sortedByY = List<DraggableComponent>.from(_canvasComponents)
      ..sort((a, b) => a.y.compareTo(b.y));

    double currentY = sortedByY.first.y.clamp(20.0, 50.0); // Start near the top component
    const double verticalSpacing = 15;

    for (var component in sortedByY) {
      component.x = alignX;
      component.y = currentY;
      currentY += component.height + verticalSpacing;
      
      // Ensure components don't go off the bottom of canvas
      if (currentY + component.height > canvasHeight - 20) {
        break;
      }
    }
  }

  void _alignComponentsInRow() {
    if (_canvasComponents.isEmpty) return;

    // Calculate the average Y position for center alignment
    double avgY = _canvasComponents.map((c) => c.y).reduce((a, b) => a + b) / _canvasComponents.length;
    double topmostY = _canvasComponents.map((c) => c.y).reduce((a, b) => a < b ? a : b);
    
    // Use average Y but ensure it's not too close to edges
    double alignY = avgY.clamp(20.0, canvasHeight - 100);
    
    // Sort components by X position and align them horizontally
    final sortedByX = List<DraggableComponent>.from(_canvasComponents)
      ..sort((a, b) => a.x.compareTo(b.x));

    double currentX = sortedByX.first.x.clamp(20.0, 50.0); // Start near the left component
    const double horizontalSpacing = 15;

    for (var component in sortedByX) {
      component.x = currentX;
      component.y = alignY;
      currentX += component.width + horizontalSpacing;
      
      // Ensure components don't go off the right side of canvas
      if (currentX + component.width > canvasWidth - 20) {
        break;
      }
    }
  }

  void _showComponentEditDialog(DraggableComponent component) {
    // Deprecated - use _editComponent instead
    _editComponent(component);
  }

  ImageProvider _createGridPattern() {
    // Return a transparent image since we removed grid pattern from canvas background
    return MemoryImage(
      // 1x1 transparent pixel
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, 65, 84, 120, 156, 99, 248, 15, 0, 0, 1, 0, 1, 0, 24, 221, 139, 175, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130])
    );
  }

  Future<void> _saveTemplate() async {
    if (_templateNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name')),
      );
      return;
    }

    if (_canvasComponents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one component')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final templateData = {
        'name': _templateNameController.text.trim(),
        'templateType': 'custom',
        'createdBy': widget.currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'components': _canvasComponents.map((c) => c.toJson()).toList(),
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'canvasBackgroundColor': canvasBackgroundColor.value,
        'isActive': true,
      };

      await FirebaseFirestore.instance
          .collection('custom_templates')
          .add(templateData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear the canvas after saving
      setState(() {
        _canvasComponents.clear();
        _templateNameController.clear();
        _selectedComponentId = null;
      });

      // Notify parent to refresh templates
      if (widget.onTemplateAdded != null) {
        widget.onTemplateAdded!();
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving template: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
