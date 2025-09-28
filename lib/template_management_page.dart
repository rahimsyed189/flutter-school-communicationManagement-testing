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
  holiday,
  notice,
  ptm,
  announcement,
  event,
  exam,
  result,
  fee,
  custom,
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
  TemplateType _selectedTemplate = TemplateType.holiday;
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
        querySnapshot = await FirebaseFirestore.instance
            .collection('custom_templates')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .get();
      } catch (indexError) {
        // If index error, fall back to simpler query
        print('Index not available, using simple query: $indexError');
        querySnapshot = await FirebaseFirestore.instance
            .collection('custom_templates')
            .where('isActive', isEqualTo: true)
            .get();
      }

      final templates = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

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
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCustomTemplate = customTemplate['id'];
                            _selectedTemplate = TemplateType.custom;
                          });
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
                                  Icons.auto_awesome,
                                  color: isSelected ? Colors.white : templateColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                customTemplate['templateName'] ?? 'Custom',
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
                  
                  // Builder Button
                  _buildBuilderButton(),
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
    
    return CustomTemplatePost(
      templateData: customTemplate,
      currentUserId: widget.currentUserId,
      currentUserRole: widget.currentUserRole,
    );
  }

  Widget _buildBuilderButton() {
    return GestureDetector(
      onTap: _navigateToBuilder,
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF673AB7), Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF673AB7).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_circle,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Builder',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF673AB7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToBuilder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TemplateBuilderPage(),
      ),
    );
    
    // If a template was successfully saved, refresh custom templates
    if (result == true) {
      _loadCustomTemplates();
    }
  }

  Color _getTemplateColor(TemplateType type) {
    switch (type) {
      case TemplateType.holiday:
        return const Color(0xFFFF9800); // Orange
      case TemplateType.notice:
        return const Color(0xFF4CAF50); // Green
      case TemplateType.ptm:
        return const Color(0xFF2196F3); // Blue
      case TemplateType.announcement:
        return const Color(0xFFFF5722); // Deep Orange
      case TemplateType.event:
        return const Color(0xFF9C27B0); // Purple
      case TemplateType.exam:
        return const Color(0xFFE91E63); // Pink
      case TemplateType.result:
        return const Color(0xFF00BCD4); // Cyan
      case TemplateType.fee:
        return const Color(0xFF795548); // Brown
      case TemplateType.custom:
        return const Color(0xFF673AB7); // Deep Purple
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
      case TemplateType.holiday:
        return _HolidayTemplate(
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        );
      case TemplateType.notice:
        return _NoticeTemplate(
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        );
      case TemplateType.ptm:
        return _PTMTemplate(
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        );
      case TemplateType.announcement:
        return _AnnouncementTemplate(
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
      case TemplateType.custom:
        return _CustomTemplateBuilder(
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
          onTemplateAdded: _loadCustomTemplates,
        );
    }
  }

  IconData _getTemplateIcon(TemplateType type) {
    switch (type) {
      case TemplateType.holiday:
        return Icons.celebration;
      case TemplateType.notice:
        return Icons.campaign;
      case TemplateType.ptm:
        return Icons.groups;
      case TemplateType.announcement:
        return Icons.announcement;
      case TemplateType.event:
        return Icons.event;
      case TemplateType.exam:
        return Icons.quiz;
      case TemplateType.result:
        return Icons.grade;
      case TemplateType.fee:
        return Icons.payment;
      case TemplateType.custom:
        return Icons.build_circle;
    }
  }

  String _getTemplateName(TemplateType type) {
    switch (type) {
      case TemplateType.holiday:
        return 'Holiday';
      case TemplateType.notice:
        return 'Notice';
      case TemplateType.ptm:
        return 'PTM';
      case TemplateType.announcement:
        return 'General';
      case TemplateType.event:
        return 'Event';
      case TemplateType.exam:
        return 'Exam';
      case TemplateType.result:
        return 'Result';
      case TemplateType.fee:
        return 'Fee';
      case TemplateType.custom:
        return 'Builder';
    }
  }
}

// Holiday Template Widget
class _HolidayTemplate extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;

  const _HolidayTemplate({
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  State<_HolidayTemplate> createState() => _HolidayTemplateState();
}

class _HolidayTemplateState extends State<_HolidayTemplate> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController(text: 'HOLIDAY');
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedEndDate;
  bool _isDateRange = false;
  bool _isLoading = false;
  
  // Inline editing states
  bool _isEditingTitle = false;
  bool _isEditingDescription = false;
  bool _isEditingDates = false;
  bool _isEditingTag = false;
  
  // Color scheme selection
  int _selectedColorScheme = 0;
  
  // Light gradient color schemes
  final List<Map<String, dynamic>> _colorSchemes = [
    {
      'name': 'Light Blue',
      'background': [Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
      'tag': Color(0xFF42A5F5),
      'ribbon': Color(0xFF1976D2),
    },
    {
      'name': 'Light Green', 
      'background': [Color(0xFFE8F5E8), Color(0xFFFFFFFF)],
      'tag': Color(0xFF66BB6A),
      'ribbon': Color(0xFF388E3C),
    },
    {
      'name': 'Light Orange',
      'background': [Color(0xFFFFF3E0), Color(0xFFFFFFFF)],
      'tag': Color(0xFFFF9800),
      'ribbon': Color(0xFFE65100),
    },
    {
      'name': 'Light Purple',
      'background': [Color(0xFFF3E5F5), Color(0xFFFFFFFF)],
      'tag': Color(0xFFAB47BC),
      'ribbon': Color(0xFF7B1FA2),
    },
    {
      'name': 'Light Pink',
      'background': [Color(0xFFFCE4EC), Color(0xFFFFFFFF)],
      'tag': Color(0xFFEC407A),
      'ribbon': Color(0xFFC2185B),
    },
    {
      'name': 'Light Teal',
      'background': [Color(0xFFE0F2F1), Color(0xFFFFFFFF)],
      'tag': Color(0xFF26A69A),
      'ribbon': Color(0xFF00695C),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Preview Card
          _buildHolidayPreview(),
          const SizedBox(height: 24),
          // Form
          _buildHolidayForm(),
        ],
      ),
    );
  }

  Widget _buildHolidayPreview() {
    final daysUntil = _selectedDate.difference(DateTime.now()).inDays;

    // EXACT 100% IDENTICAL structure to SchoolHolidayCard
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {}, // Preview only
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Info Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: _colorSchemes[_selectedColorScheme]['background'],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Horizontal Ribbon Tag (inline editable)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _isEditingTag
                            ? Container(
                                width: 100,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _tagController,
                                  autofocus: true,
                                  textAlign: TextAlign.center,
                                  textCapitalization: TextCapitalization.characters,
                                  maxLength: 12,
                                  style: const TextStyle(
                                    color: Color(0xFF2b2b2b),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    hintText: 'TAG TEXT',
                                    hintStyle: TextStyle(color: Colors.grey),
                                  ),
                                  onFieldSubmitted: (_) {
                                    setState(() => _isEditingTag = false);
                                    _saveTemplate();
                                  },
                                ),
                              )
                            : GestureDetector(
                                onTap: () => setState(() => _isEditingTag = true),
                                child: Container(
                                  height: 28,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Main ribbon body
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              _colorSchemes[_selectedColorScheme]['tag'],
                                              _colorSchemes[_selectedColorScheme]['tag'].withOpacity(0.9),
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(6),
                                            bottomLeft: Radius.circular(6),
                                            topRight: Radius.circular(2),
                                            bottomRight: Radius.circular(2),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.15),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Metal eyelet
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const RadialGradient(
                                                  center: Alignment(-0.3, -0.3),
                                                  colors: [
                                                    Colors.white,
                                                    Color(0x99FFFFFF),
                                                    Colors.transparent,
                                                  ],
                                                  stops: [0.0, 0.3, 0.8],
                                                ),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.3),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 3,
                                                  height: 3,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Color(0xFFf9d976),
                                                        Color(0xFFf39c12),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Text
                                            Text(
                                              _tagController.text.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black26,
                                                    blurRadius: 1,
                                                    offset: Offset(0, 0.5),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Folded corner/notch
                                      ClipPath(
                                        clipper: _HorizontalNotchClipper(),
                                        child: Container(
                                          width: 12,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                _colorSchemes[_selectedColorScheme]['tag'].withOpacity(0.8),
                                                _colorSchemes[_selectedColorScheme]['ribbon'],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 12),

                      // Title (inline editable)
                      _isEditingTitle
                          ? Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _titleController,
                                    autofocus: true,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF003366),
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '🎉 Enter holiday title',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () {
                                    setState(() {
                                      _isEditingTitle = false;
                                    });
                                    _saveTemplate();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _isEditingTitle = false;
                                    });
                                  },
                                ),
                              ],
                            )
                          : GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isEditingTitle = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _titleController.text.isEmpty ? '🎉 Tap to add holiday title' : _titleController.text,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _titleController.text.isEmpty ? Colors.grey : const Color(0xFF003366),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                      const SizedBox(height: 12),

                      // Description (inline editable)
                      _isEditingDescription
                          ? Column(
                              children: [
                                TextFormField(
                                  controller: _descriptionController,
                                  autofocus: true,
                                  maxLines: 3,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF666666),
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Add custom description (optional)...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isEditingDescription = false;
                                        });
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _isEditingDescription = false;
                                        });
                                        _saveTemplate();
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            )
                          : GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isEditingDescription = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF333333),
                                      height: 1.4,
                                      fontFamily: 'Segoe UI',
                                    ),
                                    children: [
                                      // Custom description (only if user added one)
                                      if (_descriptionController.text.isNotEmpty && 
                                          !_descriptionController.text.contains('The school will be closed') &&
                                          !_descriptionController.text.contains('The school will remain closed')) ...[
                                        TextSpan(
                                          text: '${_descriptionController.text}\n\n',
                                          style: const TextStyle(
                                            color: Color(0xFF666666),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      
                                      // Default school closure text (always shown - matches SchoolHolidayCard)
                                      if (_isDateRange && _selectedEndDate != null) ...[
                                        const TextSpan(text: 'From '),
                                        TextSpan(
                                          text: DateFormat('dd MMM').format(_selectedDate),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(text: ' To '),
                                        TextSpan(
                                          text: DateFormat('dd MMM').format(_selectedEndDate!),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(text: '.'),
                                      ] else ...[
                                        const TextSpan(text: 'On '),
                                        TextSpan(
                                          text: DateFormat('dd MMMM yyyy').format(_selectedDate),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(text: '.'),
                                      ],
                                      
                                      // Placeholder text if no custom description
                                      if (_descriptionController.text.isEmpty) ...[
                                        const TextSpan(
                                          text: '\n\nTap description area below to add custom message...',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                      const SizedBox(height: 12),

                      // Countdown (EXACT same as SchoolHolidayCard)
                      Container(
                        child: Text(
                          daysUntil > 0 
                              ? '⏳ $daysUntil days remaining until holidays begin!'
                              : daysUntil == 0
                                  ? '🎉 Holiday starts today!'
                                  : daysUntil == -1
                                      ? '🎉 Holiday started yesterday!'
                                      : '📅 Holiday was ${daysUntil.abs()} days ago',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0066cc),
                          ),
                        ),
                      ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Calendar Section (EXACT same as SchoolHolidayCard)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFeeeeee), width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Calendar Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _colorSchemes[_selectedColorScheme]['ribbon'],
                        ),
                        child: Text(
                          DateFormat('MMMM yyyy').format(_isDateRange ? _selectedDate : _selectedDate),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Calendar Grid or Date Editor
                      _isEditingDates
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date range toggle
                                  CheckboxListTile(
                                    title: const Text('Multiple days holiday'),
                                    value: _isDateRange,
                                    onChanged: (value) {
                                      setState(() {
                                        _isDateRange = value ?? false;
                                        if (!_isDateRange) _selectedEndDate = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Start date
                                  ListTile(
                                    leading: const Icon(Icons.calendar_today),
                                    title: const Text('Start Date'),
                                    subtitle: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          _selectedDate = date;
                                        });
                                      }
                                    },
                                  ),
                                  
                                  // End date (if range)
                                  if (_isDateRange) ...[
                                    const SizedBox(height: 8),
                                    ListTile(
                                      leading: const Icon(Icons.calendar_today),
                                      title: const Text('End Date'),
                                      subtitle: Text(_selectedEndDate != null 
                                          ? DateFormat('dd MMMM yyyy').format(_selectedEndDate!) 
                                          : 'Select end date'),
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: _selectedEndDate ?? _selectedDate.add(const Duration(days: 1)),
                                          firstDate: _selectedDate,
                                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                        );
                                        if (date != null) {
                                          setState(() {
                                            _selectedEndDate = date;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _isEditingDates = false;
                                          });
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _isEditingDates = false;
                                          });
                                          _saveTemplate();
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isEditingDates = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Column(
                                  children: [
                                    _buildCalendarGrid(
                                      _isDateRange ? _selectedDate : _selectedDate,
                                      _isDateRange ? _selectedEndDate : _selectedDate,
                                      _isDateRange,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to edit dates',
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),

                // Bottom section with timestamp (EXACT same as SchoolHolidayCard)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Timestamp
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Posted recently',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHolidayForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Edit the template above by clicking on any element, then post it directly to announcements',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Color Scheme Selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Color Theme',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(_colorSchemes.length, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColorScheme = index;
                        });
                        _saveTemplate();
                      },
                      child: Container(
                        width: 80,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _colorSchemes[index]['background'],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedColorScheme == index 
                                ? _colorSchemes[index]['tag'] 
                                : Colors.grey.withOpacity(0.3),
                            width: _selectedColorScheme == index ? 3 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _colorSchemes[index]['tag'],
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 30,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _colorSchemes[index]['ribbon'],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Post Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _postHoliday,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Post This Template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? _selectedDate.add(const Duration(days: 1)),
      firstDate: _selectedDate.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFD54F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF333333),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedEndDate) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFD54F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF333333),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildCalendarGrid(DateTime startDate, DateTime? endDate, bool isRange) {
    final DateTime firstDayOfMonth = DateTime(startDate.year, startDate.month, 1);
    final DateTime lastDayOfMonth = DateTime(startDate.year, startDate.month + 1, 0);
    final int firstWeekday = firstDayOfMonth.weekday % 7; // Convert to 0=Sunday, 1=Monday, etc.
    
    // Day headers
    const List<String> dayHeaders = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    
    List<Widget> calendarCells = [];
    
    // Add day headers
    for (String day in dayHeaders) {
      calendarCells.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4), // Reduced from 6
          child: Text(
            day,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
              fontSize: 11, // Reduced from 12
            ),
          ),
        ),
      );
    }
    
    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstWeekday; i++) {
      calendarCells.add(Container());
    }
    
    // Add days of the month
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final DateTime currentDate = DateTime(startDate.year, startDate.month, day);
      final bool isHolidayDay = isRange && endDate != null
          ? (currentDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
             currentDate.isBefore(endDate.add(const Duration(days: 1))))
          : currentDate.day == startDate.day && currentDate.month == startDate.month;
      
      calendarCells.add(
        Container(
          margin: const EdgeInsets.all(0.5), // Reduced margin
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Date container
              Container(
                width: 28, // Reduced from 32
                height: 28, // Reduced from 32
                decoration: BoxDecoration(
                  color: isHolidayDay ? const Color(0xFF4CAF50) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14), // Adjusted for smaller size
                  border: isHolidayDay 
                      ? Border.all(color: const Color(0xFF2E7D32), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      color: isHolidayDay ? Colors.white : const Color(0xFF333333),
                      fontWeight: isHolidayDay ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12, // Reduced from 13
                    ),
                  ),
                ),
              ),
              
              // Holiday tag
              if (isHolidayDay)
                Positioned(
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'H',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
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
      constraints: const BoxConstraints(maxHeight: 240), // Reduced calendar height
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.2, // Make cells slightly more compact
        mainAxisSpacing: 2, // Reduced gap
        crossAxisSpacing: 2, // Reduced gap
        children: calendarCells,
      ),
    );
  }



  Future<void> _postHoliday() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a holiday title'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isDateRange && _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an end date for the holiday range'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('communications').doc();
      
      // Calculate total days for date range
      int totalDays = 1;
      if (_isDateRange && _selectedEndDate != null) {
        totalDays = _selectedEndDate!.difference(_selectedDate).inDays + 1;
      }

      // Only include custom description if user added one
      final customDescription = _descriptionController.text.trim();
      final hasCustomDescription = customDescription.isNotEmpty && 
          !customDescription.contains('The school will be closed') &&
          !customDescription.contains('The school will remain closed');

      await docRef.set({
        'id': docRef.id,
        'message': '', // Don't use message field to avoid duplication
        'description': hasCustomDescription ? customDescription : '', // Only custom description
        'title': _titleController.text.trim(),
        'tag': _tagController.text.trim(), // Custom tag
        'colorScheme': _selectedColorScheme, // Color scheme index
        'type': 'holiday',
        'templateType': 'holiday',
        'holidayDate': _selectedDate,
        'holidayStartDate': _selectedDate,
        'holidayEndDate': _isDateRange ? _selectedEndDate : _selectedDate,
        'isHolidayRange': _isDateRange,
        'totalDays': totalDays,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.currentUserId,
        'senderId': widget.currentUserId,
        'senderRole': widget.currentUserRole,
        'userRole': widget.currentUserRole,
        'senderName': 'School Admin',
        'reactions': {},
        'isImportant': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isDateRange && _selectedEndDate != null
                        ? 'Holiday "${_titleController.text.trim()}" (${totalDays} days) posted successfully!'
                        : 'Holiday "${_titleController.text.trim()}" posted successfully!',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFFD54F),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Clear form
        _titleController.clear();
        _descriptionController.clear();
        _tagController.text = 'HOLIDAY'; // Reset to default
        setState(() {
          _selectedDate = DateTime.now();
          _selectedEndDate = null;
          _isDateRange = false;
          _selectedColorScheme = 0; // Reset to default color scheme
        });
        
        // Navigate back to announcements page after a short delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop(); // Go back to announcements page
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting holiday: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Save template data to shared preferences
  Future<void> _saveTemplate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('holiday_title', _titleController.text);
      await prefs.setString('holiday_description', _descriptionController.text);
      await prefs.setString('holiday_tag', _tagController.text);
      await prefs.setInt('holiday_color_scheme', _selectedColorScheme);
      await prefs.setString('holiday_date', _selectedDate.toIso8601String());
      await prefs.setBool('holiday_is_range', _isDateRange);
      if (_selectedEndDate != null) {
        await prefs.setString('holiday_end_date', _selectedEndDate!.toIso8601String());
      } else {
        await prefs.remove('holiday_end_date');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving template: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Load saved template data
  Future<void> _loadTemplate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final title = prefs.getString('holiday_title') ?? '';
      final description = prefs.getString('holiday_description') ?? _getDefaultDescription();
      final tag = prefs.getString('holiday_tag') ?? 'HOLIDAY';
      final colorScheme = prefs.getInt('holiday_color_scheme') ?? 0;
      final dateStr = prefs.getString('holiday_date');
      final isRange = prefs.getBool('holiday_is_range') ?? false;
      final endDateStr = prefs.getString('holiday_end_date');
      
      setState(() {
        _titleController.text = title;
        _tagController.text = tag;
        _selectedColorScheme = colorScheme;
        
        if (dateStr != null) {
          _selectedDate = DateTime.parse(dateStr);
        }
        _isDateRange = isRange;
        if (endDateStr != null) {
          _selectedEndDate = DateTime.parse(endDateStr);
        }
        
        // Only load custom descriptions (not default closure text)
        if (description.isNotEmpty && 
            !description.contains('The school will be closed') &&
            !description.contains('The school will remain closed')) {
          _descriptionController.text = description;
        }
      });
    } catch (e) {
      print('Error loading template: $e');
      // Set default description if loading fails
      setState(() {
        _descriptionController.text = _getDefaultDescription();
      });
    }
  }

  // Get default description text (empty since SchoolHolidayCard generates closure text automatically)
  String _getDefaultDescription() {
    return ''; // Return empty string as default since closure text is auto-generated
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTemplate();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Notice Template Widget
class _NoticeTemplate extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;

  const _NoticeTemplate({
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  State<_NoticeTemplate> createState() => _NoticeTemplateState();
}

class _NoticeTemplateState extends State<_NoticeTemplate> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _priority = 'Medium';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildNoticePreview(),
          const SizedBox(height: 24),
          _buildNoticeForm(),
        ],
      ),
    );
  }

  Widget _buildNoticePreview() {
    final priorityColor = _priority == 'High' ? Colors.red : _priority == 'Medium' ? Colors.orange : Colors.green;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            priorityColor.withOpacity(0.1),
            priorityColor.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: priorityColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text('NOTICE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _priority.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.notifications_active, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text.isEmpty ? 'Notice Title' : _titleController.text,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: priorityColor),
                      ),
                      SizedBox(height: 8),
                      if (_contentController.text.isNotEmpty)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
                          child: Text(_contentController.text, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text('Notice Title *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter notice title 😊',
              prefixIcon: const Icon(Icons.title, color: Colors.orange),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              filled: true, fillColor: const Color(0xFFF8F9FA),
            ),
          ),
          const SizedBox(height: 20),
          
          // Priority
          const Text('Priority Level *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
          const SizedBox(height: 8),
          Row(
            children: ['High', 'Medium', 'Low'].map((priority) => 
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _priority = priority),
                  child: Container(
                    margin: EdgeInsets.only(right: priority != 'Low' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _priority == priority ? (priority == 'High' ? Colors.red : priority == 'Medium' ? Colors.orange : Colors.green) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(priority, textAlign: TextAlign.center, style: TextStyle(color: _priority == priority ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ).toList(),
          ),
          const SizedBox(height: 20),
          
          // Content
          const Text('Notice Content *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
          const SizedBox(height: 8),
          TextFormField(
            controller: _contentController,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter notice content... 📝✨',
              prefixIcon: const Icon(Icons.description, color: Colors.orange),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
              filled: true, fillColor: const Color(0xFFF8F9FA),
            ),
          ),
          const SizedBox(height: 24),
          
          // Post Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _postNotice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Text('Post Notice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _postNotice() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('communications').doc();
      await docRef.set({
        'id': docRef.id,
        'message': _contentController.text.trim(),
        'title': _titleController.text.trim(),
        'type': 'notice',
        'templateType': 'notice',
        'priority': _priority,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.currentUserId,
        'senderId': widget.currentUserId,
        'senderRole': widget.currentUserRole,
        'userRole': widget.currentUserRole,
        'senderName': 'School Admin',
        'reactions': {},
        'isImportant': _priority == 'High',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Notice posted successfully!')]), backgroundColor: Colors.orange),
        );
        _titleController.clear();
        _contentController.clear();
        setState(() => _priority = 'Medium');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting notice: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}

// PTM Template - Wooden board design inspired by school theme
class _PTMTemplate extends StatefulWidget {
  final String currentUserId;
  final String currentUserRole;

  const _PTMTemplate({required this.currentUserId, required this.currentUserRole});

  @override
  State<_PTMTemplate> createState() => _PTMTemplateState();
}

class _PTMTemplateState extends State<_PTMTemplate> {
  final TextEditingController _titleController = TextEditingController(text: 'Parent Teacher Meeting');
  final TextEditingController _descriptionController = TextEditingController(text: 'Work together for a better future');
  final TextEditingController _venueController = TextEditingController(text: 'School Auditorium');
  final TextEditingController _phoneController = TextEditingController(text: '+91 90000 11234');
  final TextEditingController _tagController = TextEditingController(text: 'PTM');
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 18, minute: 0);
  int _selectedColorScheme = 0;
  bool _isLoading = false;
  bool _isEditingTag = false;
  
  // Inline editing states
  bool _isEditingTitle = false;
  bool _isEditingDescription = false;
  bool _isEditingDates = false;
  bool _isEditingVenue = false;

  // PTM Color Schemes (inspired by your HTML design)
  final List<Map<String, dynamic>> _colorSchemes = [
    {
      'name': 'School Navy & Gold',
      'primary': Color(0xFF1F5FA6), // school navy
      'secondary': Color(0xFFF2B631), // school gold
      'accent': Color(0xFF2C3E50), // footer color
      'background': [Color(0xFFFBFBFF), Color(0xFFEEF6FF)], // light & airy
      'wood': [Color(0xFFF7E6D0), Color(0xFFF0CFA2)], // light wood tones
      'text': Color(0xFF0F1720), // chalk color
      'muted': Color(0xFF6B6F76),
    },
    {
      'name': 'Forest Green',
      'primary': Color(0xFF2E7D32),
      'secondary': Color(0xFF66BB6A),
      'accent': Color(0xFF1B5E20),
      'background': [Color(0xFFF8FFF8), Color(0xFFE8F5E8)],
      'wood': [Color(0xFFE8D5C2), Color(0xFFD7C3A8)],
      'text': Color(0xFF1B5E20),
      'muted': Color(0xFF757575),
    },
    {
      'name': 'Royal Purple',
      'primary': Color(0xFF7B1FA2),
      'secondary': Color(0xFFBA68C8),
      'accent': Color(0xFF4A148C),
      'background': [Color(0xFFFCF8FF), Color(0xFFF3E5F5)],
      'wood': [Color(0xFFE6D7F0), Color(0xFFD1C4E9)],
      'text': Color(0xFF4A148C),
      'muted': Color(0xFF757575),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPTMPreview(),
          const SizedBox(height: 20),
          _buildColorSchemeSelector(),
          const SizedBox(height: 20),
          _buildPostButton(),
        ],
      ),
    );
  }

  Widget _buildPTMPreview() {
    final colorScheme = _colorSchemes[_selectedColorScheme];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colorScheme['background'],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [

                // Wooden board
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: colorScheme['wood'],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Title (inline editable)
                        _isEditingTitle
                            ? Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _titleController,
                                      autofocus: true,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme['text'],
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: '📅 Enter PTM title',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () {
                                      setState(() {
                                        _isEditingTitle = false;
                                      });
                                      _saveTemplate();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _isEditingTitle = false;
                                      });
                                    },
                                  ),
                                ],
                              )
                            : GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isEditingTitle = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _titleController.text.isEmpty ? '📅 Tap to add PTM title' : _titleController.text.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: _titleController.text.isEmpty ? Colors.grey : colorScheme['text'],
                                      letterSpacing: 1.2,
                                      height: 1.1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                        
                        const SizedBox(height: 8),
                        
                        // Description (inline editable)
                        _isEditingDescription
                            ? Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _descriptionController,
                                      autofocus: true,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme['muted'],
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter description',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () {
                                      setState(() {
                                        _isEditingDescription = false;
                                      });
                                      _saveTemplate();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _isEditingDescription = false;
                                      });
                                    },
                                  ),
                                ],
                              )
                            : GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isEditingDescription = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _descriptionController.text.isEmpty ? 'Tap to add description' : _descriptionController.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _descriptionController.text.isEmpty ? Colors.grey : colorScheme['muted'],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Date and Time (inline editable)
                _isEditingDates
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Date:', style: TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () => _selectDate(),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Time:', style: TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => _selectStartTime(),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(_startTime.format(context)),
                                              ),
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8),
                                            child: Text('to'),
                                          ),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => _selectEndTime(),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(_endTime.format(context)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () {
                                    setState(() {
                                      _isEditingDates = false;
                                    });
                                    _saveTemplate();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _isEditingDates = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEditingDates = true;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _buildInfoCard(
                              icon: Icons.calendar_month,
                              title: DateFormat('EEEE, dd MMMM').format(_selectedDate),
                              subtitle: '${_formatTimeToAMPM(_startTime)} to ${_formatTimeToAMPM(_endTime)}',
                              colorScheme: colorScheme,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 20),

                // Note section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme['muted'].withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 16,
                            color: colorScheme['primary'],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Note:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme['primary'],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please arrive 10 minutes early. Bring your child\'s progress report and any specific concerns you\'d like to discuss.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme['text'],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Ribbon Tag (inline editable)
          Positioned(
            top: 8,
            right: 8,
            child: _isEditingTag
                ? Container(
                    width: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _tagController,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 12,
                      style: const TextStyle(
                        color: Color(0xFF2b2b2b),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        hintText: 'TAG TEXT',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onFieldSubmitted: (_) {
                        setState(() => _isEditingTag = false);
                        _saveTemplate();
                      },
                    ),
                  )
                : GestureDetector(
                    onTap: () => setState(() => _isEditingTag = true),
                    child: Container(
                      height: 28,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Main ribbon body
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  colorScheme['primary'],
                                  colorScheme['primary'].withOpacity(0.9),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                bottomLeft: Radius.circular(6),
                                topRight: Radius.circular(2),
                                bottomRight: Radius.circular(2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Metal eyelet
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      center: Alignment(-0.3, -0.3),
                                      colors: [
                                        Colors.white,
                                        Color(0x99FFFFFF),
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.3, 0.8],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            colorScheme['secondary'],
                                            colorScheme['secondary'].withOpacity(0.8),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Text
                                Text(
                                  _tagController.text.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 1,
                                        offset: Offset(0, 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Folded corner/notch
                          ClipPath(
                            clipper: _HorizontalNotchClipper(),
                            child: Container(
                              width: 12,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    colorScheme['primary'].withOpacity(0.8),
                                    colorScheme['secondary'].withOpacity(0.6),
                                  ],
                                ),
                              ),
                            ),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Map<String, dynamic> colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Icon(
              icon,
              size: 18,
              color: colorScheme['secondary'],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme['muted'],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSchemeSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B46C1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.palette, color: Color(0xFF6B46C1), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Choose Theme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _colorSchemes.length,
              itemBuilder: (context, index) {
                final scheme = _colorSchemes[index];
                final isSelected = _selectedColorScheme == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColorScheme = index);
                    _saveTemplate();
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? scheme['primary'] : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2.5 : 1,
                      ),
                      color: isSelected ? scheme['primary'].withOpacity(0.05) : Colors.white,
                      boxShadow: isSelected
                          ? [BoxShadow(color: scheme['primary'].withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
                          : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: scheme['primary'],
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), bottomLeft: Radius.circular(6)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: scheme['secondary'],
                                  borderRadius: const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scheme['name'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? scheme['primary'] : const Color(0xFF6B7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostButton() {
    final colorScheme = _colorSchemes[_selectedColorScheme];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme['primary'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.groups, color: colorScheme['primary'], size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Schedule PTM',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme['primary'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _postPTM,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme['primary'],
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                shadowColor: colorScheme['primary'].withOpacity(0.3),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Schedule PTM Meeting',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _postPTM() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a PTM title'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_venueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a venue'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('communications').doc();
      
      await docRef.set({
        'id': docRef.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'message': '', // Keep message empty to avoid duplication
        'tag': _tagController.text.trim(),
        'colorScheme': _selectedColorScheme,
        'type': 'ptm',
        'templateType': 'ptm',
        'ptmDate': _selectedDate,
        'ptmStartTime': '${_startTime.hour}:${_startTime.minute.toString().padLeft(2, '0')}',
        'ptmEndTime': '${_endTime.hour}:${_endTime.minute.toString().padLeft(2, '0')}',
        'venue': _venueController.text.trim(),
        'phone': _phoneController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.currentUserId,
        'senderId': widget.currentUserId,
        'senderRole': widget.currentUserRole,
        'userRole': widget.currentUserRole,
        'senderName': 'School Admin',
        'reactions': {},
        'isImportant': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('PTM "${_titleController.text.trim()}" scheduled successfully!'),
                ),
              ],
            ),
            backgroundColor: _colorSchemes[_selectedColorScheme]['primary'],
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Clear form
        _titleController.text = 'Parent Teacher Meeting';
        _descriptionController.text = 'Work together for a better future';
        _venueController.text = 'School Auditorium';
        _phoneController.text = '+91 90000 11234';
        _tagController.text = 'PTM';
        setState(() {
          _selectedDate = DateTime.now().add(const Duration(days: 7));
          _startTime = TimeOfDay(hour: 16, minute: 0);
          _endTime = TimeOfDay(hour: 18, minute: 0);
          _selectedColorScheme = 0;
        });
        
        // Navigate back after a short delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling PTM: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Save template data to shared preferences
  Future<void> _saveTemplate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ptm_title', _titleController.text);
      await prefs.setString('ptm_description', _descriptionController.text);
      await prefs.setString('ptm_venue', _venueController.text);
      await prefs.setString('ptm_phone', _phoneController.text);
      await prefs.setString('ptm_tag', _tagController.text);
      await prefs.setInt('ptm_color_scheme', _selectedColorScheme);
      await prefs.setString('ptm_date', _selectedDate.toIso8601String());
      await prefs.setString('ptm_start_time', '${_startTime.hour}:${_startTime.minute}');
      await prefs.setString('ptm_end_time', '${_endTime.hour}:${_endTime.minute}');
    } catch (e) {
      // Silent save - don't show error to user for auto-save
    }
  }

  // Load saved template data
  Future<void> _loadTemplate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final title = prefs.getString('ptm_title') ?? 'Parent Teacher Meeting';
      final description = prefs.getString('ptm_description') ?? 'Work together for a better future';
      final venue = prefs.getString('ptm_venue') ?? 'School Auditorium';
      final phone = prefs.getString('ptm_phone') ?? '+91 90000 11234';
      final tag = prefs.getString('ptm_tag') ?? 'PTM';
      final colorScheme = prefs.getInt('ptm_color_scheme') ?? 0;
      final dateStr = prefs.getString('ptm_date');
      final startTimeStr = prefs.getString('ptm_start_time');
      final endTimeStr = prefs.getString('ptm_end_time');

      setState(() {
        _titleController.text = title;
        _descriptionController.text = description;
        _venueController.text = venue;
        _phoneController.text = phone;
        _tagController.text = tag;
        _selectedColorScheme = colorScheme;
        
        if (dateStr != null) {
          _selectedDate = DateTime.parse(dateStr);
        }
        
        if (startTimeStr != null) {
          final parts = startTimeStr.split(':');
          _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
        
        if (endTimeStr != null) {
          final parts = endTimeStr.split(':');
          _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      });
    } catch (e) {
      // Silent load failure - use defaults
    }
  }

  // Helper function to format TimeOfDay to AM/PM
  String _formatTimeToAMPM(TimeOfDay time) {
    String period = 'AM';
    int hour = time.hour;
    if (hour >= 12) {
      period = 'PM';
      if (hour > 12) hour -= 12;
    }
    if (hour == 0) hour = 12;
    
    String minuteStr = time.minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $period';
  }

  // Date and time picker methods
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _saveTemplate();
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
      _saveTemplate();
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
      _saveTemplate();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _phoneController.dispose();
    _tagController.dispose();
    super.dispose();
  }
}

// Placeholder templates (similar structure)
class _AnnouncementTemplate extends StatelessWidget {
  final String currentUserId;
  final String currentUserRole;
  const _AnnouncementTemplate({required this.currentUserId, required this.currentUserRole});
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
