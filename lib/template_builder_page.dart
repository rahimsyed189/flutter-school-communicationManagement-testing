import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'widgets/draggable_template_components.dart';
import 'widgets/color_picker_dialog.dart';

// Simple component class for the builder
class BuilderComponent {
  final String id;
  final ComponentType type;
  double x;
  double y;
  double width;
  double height;
  Map<String, dynamic> properties;

  BuilderComponent({
    required this.id,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 120,
    this.height = 40,
    Map<String, dynamic>? properties,
  }) : properties = properties ?? {};
}

class TemplateBuilderPage extends StatefulWidget {
  const TemplateBuilderPage({Key? key}) : super(key: key);

  @override
  State<TemplateBuilderPage> createState() => _TemplateBuilderPageState();
}

class _TemplateBuilderPageState extends State<TemplateBuilderPage> {
  // Canvas properties
  double canvasWidth = 400;
  double canvasHeight = 360;
  Color canvasBackgroundColor = const Color(0xFFF8FAFC); // Light gradient start color
  Gradient? canvasBackgroundGradient;
  bool useGradientBackground = true; // Default to gradient
  Color canvasBorderColor = Colors.grey.shade300;
  double canvasBorderRadius = 12.0; // Curved corners
  double canvasBorderWidth = 0.0;
  static const String _customGradientPresetId = 'custom_gradient';
  static const String _defaultGradientDirection = 'diagonal';
  static const Map<String, List<Alignment>> _gradientDirectionPresets = {
    'horizontal': const <Alignment>[Alignment.centerLeft, Alignment.centerRight],
    'vertical': const <Alignment>[Alignment.topCenter, Alignment.bottomCenter],
    'diagonal': const <Alignment>[Alignment.topLeft, Alignment.bottomRight],
    'reverseDiagonal': const <Alignment>[Alignment.bottomLeft, Alignment.topRight],
  };
  static const Map<String, String> _gradientDirectionLabels = {
    'horizontal': 'Horizontal',
    'vertical': 'Vertical',
    'diagonal': 'Diagonal',
    'reverseDiagonal': 'Reverse Diagonal',
  };
  String _selectedBackgroundPresetId = 'preset_solid_white';
  Color _customGradientStartColor = const Color(0xFFF8FAFC); // Very light blue-gray
  Color _customGradientEndColor = const Color(0xFFBFDBFE); // Light blue
  String _customGradientDirection = _defaultGradientDirection;
  final GlobalKey _canvasKey = GlobalKey();

  // Template properties
  final TextEditingController _templateNameController = TextEditingController();
  List<BuilderComponent> _canvasComponents = [];
  String? _selectedComponentId;
  bool _isLoading = false;
  bool _isDraggingComponent = false;
  bool _isResizingComponent = false;
  String? _editingComponentId;
  TextEditingController? _inlineEditorController;
  final FocusNode _inlineEditorFocusNode = FocusNode();

  // Auto-alignment
  bool _autoAlignEnabled = true;
  
  // Background presets
  static final List<Map<String, dynamic>> _backgroundPresets = [
    {
      'id': 'preset_solid_white',
      'name': 'Pure White',
      'type': 'solid',
      'color': Colors.white,
    },
    {
      'id': 'preset_solid_light_gray',
      'name': 'Light Gray',
      'type': 'solid',
      'color': const Color(0xFFF5F5F5),
    },
    {
      'id': 'preset_solid_dark',
      'name': 'Dark Theme',
      'type': 'solid',
      'color': const Color(0xFF1E1E1E),
    },
    {
      'id': 'preset_solid_navy',
      'name': 'Navy Blue',
      'type': 'solid',
      'color': const Color(0xFF1A237E),
    },
    {
      'id': 'preset_gradient_ocean',
      'name': 'Ocean Gradient',
      'type': 'gradient',
      'gradient': LinearGradient(
        colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'preset_gradient_sunset',
      'name': 'Sunset Gradient',
      'type': 'gradient',
      'gradient': LinearGradient(
        colors: [Color(0xFFFF9A8B), Color(0xFFA8E6CF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    },
    {
      'id': 'preset_gradient_purple',
      'name': 'Purple Dream',
      'type': 'gradient',
      'gradient': LinearGradient(
        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'preset_gradient_dark',
      'name': 'Dark Gradient',
      'type': 'gradient',
      'gradient': LinearGradient(
        colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    },
    {
      'id': 'preset_gradient_forest',
      'name': 'Green Forest',
      'type': 'gradient',
      'gradient': LinearGradient(
        colors: [Color(0xFF134E5E), Color(0xFF71B280)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'preset_gradient_rose',
      'name': 'Rose Gold',
      'type': 'gradient',
      'gradient': LinearGradient(
        colors: [Color(0xFFE8CBC0), Color(0xFF636FA4)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    },
  ];

  Alignment _resolveAlignment(AlignmentGeometry geometry) {
    if (geometry is Alignment) {
      return geometry;
    }
    return geometry.resolve(TextDirection.ltr);
  }

  bool _alignmentsMatch(Alignment a, Alignment b, {double tolerance = 0.001}) {
    return (a.x - b.x).abs() < tolerance && (a.y - b.y).abs() < tolerance;
  }

  String _detectGradientDirection(LinearGradient gradient) {
    final begin = _resolveAlignment(gradient.begin);
    final end = _resolveAlignment(gradient.end);

    for (final entry in _gradientDirectionPresets.entries) {
      final presetBegin = entry.value[0];
      final presetEnd = entry.value[1];
      if (_alignmentsMatch(begin, presetBegin) &&
          _alignmentsMatch(end, presetEnd)) {
        return entry.key;
      }
    }

    return _defaultGradientDirection;
  }

  LinearGradient _buildGradientFromState({
    Color? startColor,
    Color? endColor,
    String? direction,
  }) {
    final selectedDirection = direction ?? _customGradientDirection;
    final alignmentPair =
        _gradientDirectionPresets[selectedDirection] ?? _gradientDirectionPresets[_defaultGradientDirection]!;

    return LinearGradient(
      colors: [
        startColor ?? _customGradientStartColor,
        endColor ?? _customGradientEndColor,
      ],
      begin: alignmentPair[0],
      end: alignmentPair[1],
    );
  }
  
  // Dynamic canvas sizing
  static const double minCanvasWidth = 400;
  static const double minCanvasHeight = 320;
  static const double canvasPadding = 50; // Extra space around components
  static const double _componentHorizontalPadding = 24.0;
  static const double _componentMinContentWidth = 120.0;
  static const double _componentVerticalSpacing = 16.0;

  @override
  void initState() {
    super.initState();
    _templateNameController.text = 'My Custom Template';
    _inlineEditorFocusNode.addListener(_handleInlineEditorFocusChange);
    _initializeDefaultCanvasState();
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    _inlineEditorController?.dispose();
    _inlineEditorFocusNode
      ..removeListener(_handleInlineEditorFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF673AB7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _showSettingsMenu,
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Canvas Settings',
          ),
          IconButton(
            onPressed: _isLoading ? null : _saveTemplate,
            icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  )
                : const Icon(Icons.save, color: Colors.white),
            tooltip: _isLoading ? 'Saving...' : 'Save Template',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth > 600;
                
                if (isTablet) {
            // Tablet/Desktop Layout - Side by side
            return Row(
              children: [
                // Components Palette (Left Side)
                Container(
                  width: 280,
                  color: Colors.white,
            child: Column(
              children: [
                
                // Canvas Tools Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Canvas Tools',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildCanvasToolsPanel(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Canvas Area (Right Side)
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 150), // Extra bottom padding for components panel
              child: Column(
                children: [
                  // Canvas Controls
                  _buildCanvasControls(),
                  const SizedBox(height: 16),
                  
                  // Canvas
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
            physics: (_isDraggingComponent || _isResizingComponent)
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _buildCanvas(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]);
          } else {
            // Mobile Layout - Canvas with fixed bottom components panel
            return Column(
              children: [
                // Canvas Area (Mobile) - takes remaining space, with bottom padding for components panel
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 120), // Extra bottom padding for components panel
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        physics: (_isDraggingComponent || _isResizingComponent)
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _buildCanvas(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
                }
              },
            ),
          ),
          // Fixed Bottom Components Panel (for all screen sizes)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth > 600;
                return isTablet ? _buildSlidingComponentsPanel() : _buildSlidingComponentsPanelMobile();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidingComponentsPanelMobile() {
    bool _isPanelExpanded = false;
    
    return StatefulBuilder(
      builder: (context, setSliderState) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with drag handle and toggle
            Container(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 12),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4FC3F7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.construction,
                          size: 18,
                          color: const Color(0xFF4FC3F7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Component Library',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Drag & drop to build',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${canvasWidth.toInt()}×${canvasHeight.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setSliderState(() {
                            _isPanelExpanded = !_isPanelExpanded;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4FC3F7).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF4FC3F7).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _isPanelExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: const Color(0xFF4FC3F7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Animated components list
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _isPanelExpanded ? 100 : 0,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                  child: _buildModernComponentsGrid(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHorizontalComponentsList() {
    final components = [
      {'type': ComponentType.textLabel, 'icon': Icons.text_fields, 'label': 'Text'},
      {'type': ComponentType.textBox, 'icon': Icons.text_snippet, 'label': 'Box'},
      {'type': ComponentType.dateContainer, 'icon': Icons.calendar_today, 'label': 'Date'},
      {'type': ComponentType.imageContainer, 'icon': Icons.image, 'label': 'Image'},
      {'type': ComponentType.iconContainer, 'icon': Icons.emoji_emotions, 'label': 'Icon'},
      {'type': ComponentType.woodenContainer, 'icon': Icons.crop_square, 'label': 'Container'},
      {'type': ComponentType.coloredContainer, 'icon': Icons.rectangle, 'label': 'Box'},
      {'type': ComponentType.calendar, 'icon': Icons.date_range, 'label': 'Calendar'},
      {'type': ComponentType.gradientDivider, 'icon': Icons.horizontal_rule, 'label': 'Divider'},
    ];

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: components.length,
        itemBuilder: (context, index) {
          final component = components[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildMobileComponentTile(
              component['type'] as ComponentType,
              component['icon'] as IconData,
              component['label'] as String,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileComponentTile(ComponentType type, IconData icon, String label) {
    return GestureDetector(
      onTap: () => _addComponentToCanvasMobile(type),
      child: Container(
        width: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF8F9FA),
              const Color(0xFFEEF1F5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF673AB7).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF673AB7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF673AB7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Color(0xFF555555),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildCanvasControls() {
    return _buildSlidingComponentsPanel();
  }

  Widget _buildSlidingComponentsPanel() {
    bool _isPanelExpanded = false;
    
    return StatefulBuilder(
      builder: (context, setSliderState) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F0F23),
              const Color(0xFF1A1A2E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 25,
              offset: const Offset(0, -8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with drag handle and toggle
            Container(
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 16),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4FC3F7),
                              const Color(0xFF29B6F6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4FC3F7).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.construction,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Component Library',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Drag components to canvas • Build amazing templates',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Canvas: ${canvasWidth.toInt()}×${canvasHeight.toInt()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setSliderState(() {
                            _isPanelExpanded = !_isPanelExpanded;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4FC3F7).withOpacity(0.3),
                                const Color(0xFF29B6F6).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4FC3F7).withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _isPanelExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: const Color(0xFF4FC3F7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Animated components list
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              height: _isPanelExpanded ? 130 : 0,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
                  child: _buildModernComponentsGrid(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalComponentsList() {
    final components = [
      {'type': ComponentType.textLabel, 'icon': Icons.text_fields, 'label': 'Text'},
      {'type': ComponentType.textBox, 'icon': Icons.text_snippet, 'label': 'Text Box'},
      {'type': ComponentType.dateContainer, 'icon': Icons.calendar_today, 'label': 'Date'},
      {'type': ComponentType.imageContainer, 'icon': Icons.image, 'label': 'Image'},
      {'type': ComponentType.iconContainer, 'icon': Icons.emoji_emotions, 'label': 'Icon'},
      {'type': ComponentType.woodenContainer, 'icon': Icons.crop_square, 'label': 'Container'},
      {'type': ComponentType.coloredContainer, 'icon': Icons.rectangle, 'label': 'Box'},
      {'type': ComponentType.calendar, 'icon': Icons.date_range, 'label': 'Calendar'},
      {'type': ComponentType.gradientDivider, 'icon': Icons.horizontal_rule, 'label': 'Divider'},
    ];

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: components.length,
        itemBuilder: (context, index) {
          final component = components[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildHorizontalComponentTile(
              component['type'] as ComponentType,
              component['icon'] as IconData,
              component['label'] as String,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalComponentTile(ComponentType type, IconData icon, String label) {
    return GestureDetector(
      onTap: () => _addComponentToCanvasTablet(type),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF8F9FA),
              const Color(0xFFEEF1F5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF673AB7).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF673AB7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 24,
                color: const Color(0xFF673AB7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF555555),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernComponentsGrid() {
    final components = [
      {'type': ComponentType.textLabel, 'icon': Icons.text_fields, 'label': 'Text', 'color': const Color(0xFF4FC3F7)},
      {'type': ComponentType.textBox, 'icon': Icons.text_snippet, 'label': 'Text Box', 'color': const Color(0xFF66BB6A)},
      {'type': ComponentType.dateContainer, 'icon': Icons.calendar_today, 'label': 'Date', 'color': const Color(0xFFEF5350)},
      {'type': ComponentType.imageContainer, 'icon': Icons.image, 'label': 'Image', 'color': const Color(0xFFFF7043)},
      {'type': ComponentType.iconContainer, 'icon': Icons.emoji_emotions, 'label': 'Icon', 'color': const Color(0xFFFFCA28)},
      {'type': ComponentType.woodenContainer, 'icon': Icons.crop_square, 'label': 'Panel', 'color': const Color(0xFF8D6E63)},
      {'type': ComponentType.coloredContainer, 'icon': Icons.rectangle, 'label': 'Box', 'color': const Color(0xFF9C27B0)},
      {'type': ComponentType.calendar, 'icon': Icons.date_range, 'label': 'Calendar', 'color': const Color(0xFF5C6BC0)},
      {'type': ComponentType.gradientDivider, 'icon': Icons.horizontal_rule, 'label': 'Divider', 'color': const Color(0xFF26A69A)},
    ];

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: components.length,
        itemBuilder: (context, index) {
          final component = components[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: _buildModernComponentTile(
              component['type'] as ComponentType,
              component['icon'] as IconData,
              component['label'] as String,
              component['color'] as Color,
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernComponentTile(ComponentType type, IconData icon, String label, Color accentColor) {
    return GestureDetector(
      onTap: () => _addComponentToCanvasTablet(type),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor,
                    accentColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getComponentConfig(ComponentType type) {
    final components = {
      ComponentType.textLabel: {'icon': Icons.text_fields, 'label': 'Text Label'},
      ComponentType.textBox: {'icon': Icons.text_snippet, 'label': 'Text Box'},
      ComponentType.dateContainer: {'icon': Icons.calendar_today, 'label': 'Date'},
      ComponentType.imageContainer: {'icon': Icons.image, 'label': 'Image'},
      ComponentType.iconContainer: {'icon': Icons.emoji_emotions, 'label': 'Icon'},
      ComponentType.woodenContainer: {'icon': Icons.crop_square, 'label': 'Container'},
      ComponentType.coloredContainer: {'icon': Icons.rectangle, 'label': 'Colored Box'},
      ComponentType.calendar: {'icon': Icons.date_range, 'label': 'Calendar'},
      ComponentType.gradientDivider: {'icon': Icons.horizontal_rule, 'label': 'Divider'},
    };
    
    return components[type] ?? {'icon': Icons.help_outline, 'label': 'Unknown'};
  }

  String _humanReadableComponentName(ComponentType type) {
    switch (type) {
      case ComponentType.textLabel:
        return 'Text Label';
      case ComponentType.textBox:
        return 'Text Box';
      case ComponentType.dateContainer:
        return 'Date Container';
      case ComponentType.imageContainer:
        return 'Image Container';
      case ComponentType.iconContainer:
        return 'Icon';
      case ComponentType.woodenContainer:
        return 'Decorative Panel';
      case ComponentType.coloredContainer:
        return 'Color Block';
      case ComponentType.calendar:
        return 'Calendar';
      case ComponentType.gradientDivider:
        return 'Gradient Divider';
    }
    return 'Component';
  }

  Widget _buildCanvasToolsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Canvas Size
        _buildToolSection(
          'Canvas Size',
          Icons.aspect_ratio,
          [
            _buildToolTile(
              icon: Icons.fullscreen,
              label: 'Resize Canvas',
              onTap: _showCanvasSizeDialog,
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Auto Alignment
        _buildToolSection(
          'Auto Alignment',
          Icons.auto_fix_high,
          [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: const Color(0xFF673AB7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Auto Align',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _autoAlignEnabled,
                    onChanged: (value) => setState(() => _autoAlignEnabled = value),
                    activeColor: const Color(0xFF673AB7),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF673AB7).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF673AB7).withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info,
                    color: const Color(0xFF673AB7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Tip',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF673AB7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Components are now in the sliding panel at the top of the canvas. Use the settings menu for more tools.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: const Color(0xFF673AB7),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildToolTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF673AB7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPropertiesPanelContentList(BuilderComponent component) {
    final bool isTextComponent = _canInlineEdit(component);
    final bool autoHeightEnabled = component.properties['autoHeight'] != false;
    final double fontSize = component.properties['fontSize'] is num
        ? (component.properties['fontSize'] as num).toDouble()
        : _defaultFontSizeFor(component);
    final bool isBold = component.properties['isBold'] == true;
    final int? colorValue = component.properties['textColor'] is int
        ? component.properties['textColor'] as int
        : component.properties['color'] is int
            ? component.properties['color'] as int
            : null;
    final Color textColor = Color(colorValue ?? 0xFF000000);
    final TextAlign textAlign = _resolveTextAlign(component);

    final List<Widget> body = [];

    if (isTextComponent) {
      final bool widthFitEnabled = component.properties['widthFit'] != false;
      body
        ..add(_buildPanelSectionTitle('Quick actions'))
        ..add(
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPanelPillButton(
                icon: Icons.edit,
                label: 'Edit text',
                onTap: () => _handlePropertySelection(component, 'edit_text'),
              ),
              _buildPanelPillButton(
                icon: autoHeightEnabled ? Icons.height : Icons.unfold_more,
                label: autoHeightEnabled ? 'Auto height on' : 'Auto height off',
                isActive: autoHeightEnabled,
                onTap: () => _handlePropertySelection(component, 'toggle_auto_height'),
              ),
              _buildPanelPillButton(
                icon: widthFitEnabled ? Icons.fit_screen : Icons.expand,
                label: widthFitEnabled ? 'Width fit on' : 'Width fit off',
                isActive: widthFitEnabled,
                onTap: () => _handlePropertySelection(component, 'toggle_width_fit'),
              ),
              _buildPanelPillButton(
                icon: Icons.refresh,
                label: 'Reset height',
                onTap: () => _handlePropertySelection(component, 'reset_height'),
              ),
            ],
          ),
        )
        ..add(const SizedBox(height: 24))
        ..add(_buildPanelSectionTitle('Typography'))
        ..add(_buildFontSizeControl(component, fontSize))
        ..add(const SizedBox(height: 12))
        ..add(
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPanelPillButton(
                icon: Icons.format_bold,
                label: isBold ? 'Bold enabled' : 'Bold disabled',
                isActive: isBold,
                onTap: () => _handlePropertySelection(component, 'toggle_bold'),
              ),
            ],
          ),
        )
        ..add(const SizedBox(height: 12))
        ..add(
          _buildPanelListTile(
            icon: Icons.format_color_text,
            title: 'Text color',
            subtitle: _formatColorLabel(textColor),
            onTap: () => _handlePropertySelection(component, 'text_color'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildColorSwatch(textColor),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        )
        ..add(
          _buildPanelListTile(
            icon: Icons.auto_fix_high,
            title: 'Typography & effects',
            subtitle: 'Font family, italics, underline',
            onTap: () => _handlePropertySelection(component, 'text_style'),
          ),
        )
        ..add(
          _buildPanelListTile(
            icon: Icons.format_align_left,
            title: 'Text alignment',
            subtitle: _panelTextAlignLabel(textAlign),
            onTap: () => _handlePropertySelection(component, 'text_align'),
          ),
        )
        ..add(
          _buildPanelListTile(
            icon: Icons.layers,
            title: 'Background & border',
            subtitle: 'Fill color, radius, border width',
            onTap: () => _handlePropertySelection(component, 'background_style'),
          ),
        );
    }

    if (component.type == ComponentType.dateContainer) {
      if (body.isNotEmpty) {
        body.add(const SizedBox(height: 24));
      }
      body
        ..add(_buildPanelSectionTitle('Date'))
        ..add(
          _buildPanelListTile(
            icon: Icons.calendar_month,
            title: 'Change date',
            subtitle: _formatDateSummary(component),
            onTap: () => _handlePropertySelection(component, 'change_date'),
          ),
        );
    }

    if (body.isEmpty) {
      body
        ..add(const SizedBox(height: 16))
        ..add(_buildEmptyPropertiesPlaceholder());
    }

    body
      ..add(const SizedBox(height: 24))
      ..add(_buildPanelSectionTitle('Component info'))
      ..add(_buildComponentInfoCard(component, autoHeightEnabled: autoHeightEnabled, isTextComponent: isTextComponent))
      ..add(const SizedBox(height: 28))
      ..add(
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            _deleteComponent(component.id);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete component'),
        ),
      )
      ..add(const SizedBox(height: 12));

    return body;
  }

  Widget _buildPanelSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              letterSpacing: 0.2,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        Container(
          height: 1,
          color: Colors.grey.shade300,
          margin: const EdgeInsets.only(bottom: 12),
        ),
      ],
    );
  }

  Widget _buildPanelPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final Color activeColor = const Color(0xFFEEE8FD);
    final Color inactiveColor = const Color(0xFFF3F4F6);
    final Color borderColor = isActive ? const Color(0xFF673AB7) : Colors.transparent;
    final Color iconColor = isActive ? const Color(0xFF5B21B6) : const Color(0xFF4B5563);
    final Color textColor = isActive ? const Color(0xFF4C1D95) : const Color(0xFF1F2937);

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeControl(BuilderComponent component, double fontSize) {
    final String displaySize = fontSize % 1 == 0
        ? fontSize.toStringAsFixed(0)
        : fontSize.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.format_size, color: Color(0xFF5B21B6)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Font size',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          _buildStepperButton(
            icon: Icons.remove,
            onTap: () => _handlePropertySelection(component, 'font_decrease'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              displaySize,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          _buildStepperButton(
            icon: Icons.add,
            onTap: () => _handlePropertySelection(component, 'font_increase'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: const Color(0xFF4B5563)),
        ),
      ),
    );
  }

  Widget _buildPanelListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final Widget trailingWidget = trailing ??
        const Icon(Icons.chevron_right, color: Color(0xFF6B7280));

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF4B5563), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                      fontFamily: 'Roboto',
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailingWidget,
          ],
        ),
      ),
    );
  }

  String _panelTextAlignLabel(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return 'Centered';
      case TextAlign.right:
        return 'Right aligned';
      case TextAlign.justify:
        return 'Justified';
      case TextAlign.start:
        return 'Start aligned';
      case TextAlign.end:
        return 'End aligned';
      case TextAlign.left:
      default:
        return 'Left aligned';
    }
  }

  String _formatColorLabel(Color color) {
    final int rgb = color.value & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Widget _buildColorSwatch(Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.computeLuminance() > 0.6
              ? const Color(0xFF9CA3AF)
              : Colors.white,
          width: 1.2,
        ),
      ),
    );
  }

  String _formatDateSummary(BuilderComponent component) {
    final dynamic rawDate = component.properties['selectedDate'];
    DateTime date;
    if (rawDate is int) {
      date = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is DateTime) {
      date = rawDate;
    } else {
      date = DateTime.now();
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyPropertiesPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: const [
          Icon(Icons.lightbulb_outline, size: 32, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text(
            'No editable properties yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Select a different component or add more features to unlock additional settings.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComponentInfoCard(
    BuilderComponent component, {
    required bool autoHeightEnabled,
    required bool isTextComponent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Type', _humanReadableComponentName(component.type)),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Position',
            'X: ${component.x.toStringAsFixed(0)}, Y: ${component.y.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Size',
            '${component.width.toStringAsFixed(0)} × ${component.height.toStringAsFixed(0)}',
          ),
          if (isTextComponent) ...[
            const SizedBox(height: 10),
            _buildInfoRow('Auto height', autoHeightEnabled ? 'Enabled' : 'Disabled'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundPresetGrid() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _backgroundPresets.length + 1,
        itemBuilder: (context, index) {
          if (index == _backgroundPresets.length) {
            final isSelected = _selectedBackgroundPresetId == _customGradientPresetId;
            final customGradient = _buildGradientFromState();

            return GestureDetector(
              onTap: _showBackgroundColorPicker,
              child: Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white24,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(gradient: customGradient),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Icon(Icons.tune, color: Colors.white.withOpacity(0.9), size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final preset = _backgroundPresets[index];
          final isSelected = _selectedBackgroundPresetId == preset['id'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedBackgroundPresetId = preset['id'] as String;
                final gradient = preset['gradient'] as LinearGradient?;
                final color = preset['color'] as Color?;

                if (gradient != null) {
                  useGradientBackground = true;
                  canvasBackgroundGradient = gradient;
                  canvasBackgroundColor = gradient.colors.isNotEmpty
                      ? gradient.colors.first
                      : canvasBackgroundColor;
                  _customGradientStartColor = gradient.colors.isNotEmpty
                      ? gradient.colors.first
                      : _customGradientStartColor;
                  _customGradientEndColor = gradient.colors.length > 1
                      ? gradient.colors.last
                      : _customGradientEndColor;
                  _customGradientDirection = _detectGradientDirection(gradient);
                } else {
                  useGradientBackground = false;
                  canvasBackgroundColor = color ?? Colors.white;
                  canvasBackgroundGradient = null;
                }
              });
            },
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: preset['color'],
                    gradient: preset['gradient'],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double minAllowedWidth =
            (_componentHorizontalPadding * 2) + _componentMinContentWidth;
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : minCanvasWidth;
        final double targetWidth = math.max(availableWidth, minAllowedWidth);

        if ((canvasWidth - targetWidth).abs() > 0.5) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              canvasWidth = targetWidth;
              _alignComponentsToCanvasWidth();
            });
            _updateCanvasSize();
          });
        }

        return Container(
          key: _canvasKey,
          width: targetWidth,
          height: canvasHeight,
          decoration: BoxDecoration(
            color: useGradientBackground ? null : canvasBackgroundColor,
            gradient: useGradientBackground ? canvasBackgroundGradient : null,
            borderRadius: BorderRadius.circular(canvasBorderRadius),
            border: canvasBorderWidth > 0 
                ? Border.all(color: canvasBorderColor, width: canvasBorderWidth)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: DragTarget<ComponentType>(
            onAcceptWithDetails: (details) {
              _addComponentToCanvas(details.data, details.offset);
            },
            builder: (context, candidateData, rejectedData) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _stopInlineEditing(save: true);
                        setState(() {
                          _selectedComponentId = null;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: useGradientBackground
                              ? Colors.transparent
                              : canvasBackgroundColor,
                          gradient: useGradientBackground
                              ? canvasBackgroundGradient
                              : null,
                        ),
                      ),
                    ),
                  ),
                  ..._canvasComponents.map((component) => _buildCanvasComponent(component)).toList(),
                  // Canvas Properties Button
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: _buildCanvasPropertiesButton(),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCanvasComponent(BuilderComponent component) {
    final isSelected = _selectedComponentId == component.id;
    final isEditing = _editingComponentId == component.id;
    
    return Positioned(
      left: component.x,
      top: component.y,
      child: GestureDetector(
        onPanStart: isEditing
            ? null
            : (_) {
                setState(() {
                  _isDraggingComponent = true;
                });
              },
        onPanUpdate: isEditing
            ? null
            : (details) {
                setState(() {
                  _applyFullWidthLayout(component, recomputeHeight: false);
                  component.y = (component.y + details.delta.dy).clamp(0.0, double.infinity);
                });
                _updateCanvasSize(); // Expand canvas if needed
              },
        onPanEnd: isEditing
            ? null
            : (_) {
                setState(() {
                  _isDraggingComponent = false;
                });
                if (_autoAlignEnabled) {
                  _performAutoAlignment();
                }
              },
        onPanCancel: isEditing
            ? null
            : () {
                setState(() {
                  _isDraggingComponent = false;
                });
              },
        onTap: () {
          setState(() {
            _selectedComponentId = isSelected ? null : component.id;
          });
          if (!isEditing) {
            _stopInlineEditing(save: true);
          }
        },
        onDoubleTap: () {
          if (_canInlineEdit(component)) {
            _startInlineTextEditing(component);
          }
        },
        child: Container(
          width: component.width,
          height: component.height,
          decoration: BoxDecoration(
            border: isSelected ? Border.all(color: const Color(0xFF673AB7), width: 2) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Component Content
              Container(
                key: ValueKey('component_${component.id}_${component.properties['color'] ?? component.properties['textColor'] ?? 0xFF000000}'),
                child: _buildComponentContent(component, isEditing: isEditing, isSelected: isSelected),
              ),
              
              // Selection Controls
              if (isSelected && !isEditing) ...[
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: _buildResizeHandle(component),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentContent(BuilderComponent component, {bool isEditing = false, bool isSelected = false}) {
    switch (component.type) {
      case ComponentType.textLabel:
        if (isEditing) {
          return _buildInlineTextEditorField(component);
        }
        return _buildStyledTextComponent(component, isTextBox: false);
      
      case ComponentType.textBox:
        if (isEditing) {
          return _buildInlineTextEditorField(component);
        }
        return _buildStyledTextComponent(component, isTextBox: true);
      
      case ComponentType.dateContainer:
        final date = component.properties['selectedDate'] is int 
            ? DateTime.fromMillisecondsSinceEpoch(component.properties['selectedDate'])
            : DateTime.now();
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
        );
      
      case ComponentType.gradientDivider:
        // Create gradient divider component
        final color1 = Color(component.properties['color1'] ?? 0xFF6366F1);
        final color2 = Color(component.properties['color2'] ?? 0xFF8B5CF6);
        final dividerHeight = component.properties['height']?.toDouble() ?? 4.0;
        final cornerRadius = component.properties['cornerRadius']?.toDouble() ?? 2.0;
        
        return Container(
          width: component.width,
          height: component.height, // Use full component height for clickable area
          alignment: Alignment.center, // Center the visual divider
          child: Container(
            width: component.width,
            height: dividerHeight, // Visual height
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cornerRadius),
              gradient: LinearGradient(
                colors: [color1, color2],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        );
      
      default:
        return Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.widgets, color: Colors.grey),
          ),
        );
    }
  }

  Widget _buildToolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    Color backgroundColor = Colors.white24,
    bool isActive = false,
    Color? activeIconColor,
    Color? activeBackgroundColor,
  }) {
    final Color resolvedIconColor =
        isActive ? (activeIconColor ?? iconColor) : iconColor;
    final Color resolvedBackgroundColor =
        isActive ? (activeBackgroundColor ?? backgroundColor) : backgroundColor;

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: resolvedBackgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 16, color: resolvedIconColor),
          ),
        ),
      ),
    );
  }

  Widget _buildResizeHandle(BuilderComponent component) {
    return Tooltip(
      message: 'Drag to adjust height',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          setState(() {
            _isResizingComponent = true;
            if (_canInlineEdit(component)) {
              component.properties['autoHeight'] = false;
            }
          });
        },
        onPanUpdate: (details) {
          setState(() {
            final minHeight = _minimumComponentHeight(component);
            final proposed = component.height + details.delta.dy;
            component.height = math.max(minHeight, proposed);
            if (_canInlineEdit(component)) {
              component.properties['autoHeight'] = false;
            }
          });
          _updateCanvasSize();
        },
        onPanEnd: (_) {
          setState(() {
            _isResizingComponent = false;
          });
          if (_autoAlignEnabled) {
            _performAutoAlignment();
          }
        },
        onPanCancel: () {
          setState(() {
            _isResizingComponent = false;
          });
        },
        child: Container(
          width: 48,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.drag_indicator, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  bool _canInlineEdit(BuilderComponent component) {
    return component.type == ComponentType.textLabel || component.type == ComponentType.textBox;
  }

  double _defaultFontSizeFor(BuilderComponent component) {
    switch (component.type) {
      case ComponentType.textLabel:
        return 14.0;
      case ComponentType.textBox:
        return 12.0;
      default:
        return 14.0;
    }
  }

  double _availableComponentWidth() {
    return math.max(
      _componentMinContentWidth,
      canvasWidth - (_componentHorizontalPadding * 2),
    );
  }

  void _alignComponentsToCanvasWidth() {
    for (final component in _canvasComponents) {
      _applyFullWidthLayout(component);
    }
  }

  BuilderComponent? _findComponentById(String? id) {
    if (id == null) return null;
    for (final component in _canvasComponents) {
      if (component.id == id) {
        return component;
      }
    }
    return null;
  }

  void _showPropertiesDialog(BuilderComponent component) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isTextComponent = _canInlineEdit(component);
            final bool autoHeightEnabled = component.properties['autoHeight'] != false;
            double fontSize = component.properties['fontSize'] is num
                ? (component.properties['fontSize'] as num).toDouble()
                : _defaultFontSizeFor(component);
            bool isBold = component.properties['isBold'] == true;
            final int? colorValue = component.properties['textColor'] is int
                ? component.properties['textColor'] as int
                : component.properties['color'] is int
                    ? component.properties['color'] as int
                    : null;
            Color textColor = Color(colorValue ?? 0xFF000000);
            final TextAlign textAlign = _resolveTextAlign(component);

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 400,
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Component Properties',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      height: 1,
                      color: Colors.grey.shade300,
                    ),
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gradient Divider Properties
                            if (component.type == ComponentType.gradientDivider) ...[
                              Text(
                                'Gradient Divider Settings',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Height Slider
                              Text('Height: ${(component.properties['height']?.toDouble() ?? 4.0).toInt()}px', 
                                style: TextStyle(fontWeight: FontWeight.w500)),
                              Slider(
                                value: component.properties['height']?.toDouble() ?? 4.0,
                                min: 1.0,
                                max: 20.0,
                                divisions: 19,
                                onChanged: (value) {
                                  setDialogState(() {
                                    component.properties['height'] = value;
                                    component.height = value;
                                  });
                                  setState(() {}); // Update main UI
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Corner Radius Slider
                              Text('Corner Radius: ${(component.properties['cornerRadius']?.toDouble() ?? 2.0).toStringAsFixed(1)}px', 
                                style: TextStyle(fontWeight: FontWeight.w500)),
                              Slider(
                                value: component.properties['cornerRadius']?.toDouble() ?? 2.0,
                                min: 0.0,
                                max: 10.0,
                                divisions: 20,
                                onChanged: (value) {
                                  setDialogState(() {
                                    component.properties['cornerRadius'] = value;
                                  });
                                  setState(() {}); // Update main UI
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Gradient Colors
                              Row(
                                children: [
                                  // Start Color
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Start Color', style: TextStyle(fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () async {
                                            final newColor = await _showAdvancedColorPicker(
                                              context,
                                              Color(component.properties['color1'] ?? 0xFF6366F1),
                                              'Select Start Color',
                                            );
                                            if (newColor != null) {
                                              setDialogState(() {
                                                component.properties['color1'] = newColor.value;
                                              });
                                              setState(() {}); // Update main UI
                                            }
                                          },
                                          child: Container(
                                            width: double.infinity,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Color(component.properties['color1'] ?? 0xFF6366F1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: const Icon(Icons.palette, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // End Color
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('End Color', style: TextStyle(fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () async {
                                            final newColor = await _showAdvancedColorPicker(
                                              context,
                                              Color(component.properties['color2'] ?? 0xFF8B5CF6),
                                              'Select End Color',
                                            );
                                            if (newColor != null) {
                                              setDialogState(() {
                                                component.properties['color2'] = newColor.value;
                                              });
                                              setState(() {}); // Update main UI
                                            }
                                          },
                                          child: Container(
                                            width: double.infinity,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Color(component.properties['color2'] ?? 0xFF8B5CF6),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: const Icon(Icons.palette, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Preview
                              Text('Preview:', style: TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                height: component.properties['height']?.toDouble() ?? 4.0,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(component.properties['cornerRadius']?.toDouble() ?? 2.0),
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(component.properties['color1'] ?? 0xFF6366F1),
                                      Color(component.properties['color2'] ?? 0xFF8B5CF6),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            
                            if (isTextComponent) ...[
                              // Typography Section
                              Text(
                                'Typography',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Font Size Slider
                              Text('Font Size: ${fontSize.toInt()}', 
                                style: TextStyle(fontWeight: FontWeight.w500)),
                              Slider(
                                value: fontSize,
                                min: 8.0,
                                max: 48.0,
                                divisions: 40,
                                label: fontSize.toInt().toString(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    fontSize = value;
                                    component.properties['fontSize'] = value;
                                  });
                                  setState(() {}); // Update main UI
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Bold Toggle
                              CheckboxListTile(
                                title: Text('Bold'),
                                value: isBold,
                                onChanged: (value) {
                                  setDialogState(() {
                                    isBold = value ?? false;
                                    component.properties['isBold'] = isBold;
                                  });
                                  setState(() {}); // Update main UI
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Text Color
                              Text('Text Color', 
                                style: TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final newColor = await _showAdvancedColorPicker(
                                    context,
                                    textColor,
                                    'Select Text Color',
                                  );
                                  if (newColor != null) {
                                    setDialogState(() {
                                      textColor = newColor;
                                      component.properties['textColor'] = newColor.value;
                                    });
                                    setState(() {}); // Update main UI
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: textColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.color_lens, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tap to change color',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            
                            // Quick Actions
                            Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildPanelPillButton(
                                  icon: Icons.edit,
                                  label: 'Edit text',
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handlePropertySelection(component, 'edit_text');
                                  },
                                ),
                                _buildPanelPillButton(
                                  icon: Icons.auto_fix_high,
                                  label: 'Typography',
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handlePropertySelection(component, 'text_style');
                                  },
                                ),
                                _buildPanelPillButton(
                                  icon: Icons.format_align_left,
                                  label: 'Alignment',
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handlePropertySelection(component, 'text_align');
                                  },
                                ),
                                _buildPanelPillButton(
                                  icon: Icons.layers,
                                  label: 'Background',
                                  onTap: () {
                                    Navigator.pop(context);
                                    _handlePropertySelection(component, 'background_style');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Close', style: TextStyle(color: Colors.grey.shade700)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade600,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _initializeDefaultCanvasState() {
    if (_canvasComponents.isNotEmpty) return;

    final defaultProperties = Map<String, dynamic>.from(
      _getDefaultProperties(ComponentType.textBox),
    );
    defaultProperties['text'] = 'Double tap to edit text';

    final placeholder = BuilderComponent(
      id: 'component_${DateTime.now().millisecondsSinceEpoch}_default',
      type: ComponentType.textBox,
      x: _componentHorizontalPadding,
      y: canvasPadding * 0.45,
      width: _availableComponentWidth(),
      height: 72,
      properties: defaultProperties,
    );

    _applyFullWidthLayout(placeholder);
    _canvasComponents = [placeholder];

    final double requiredHeight =
        placeholder.y + placeholder.height + canvasPadding;
    canvasHeight = math.max(minCanvasHeight, requiredHeight);
  }

  void _handleInlineEditorFocusChange() {
    if (_editingComponentId != null && !_inlineEditorFocusNode.hasFocus) {
      _stopInlineEditing(save: true);
    }
  }

  void _applyFullWidthLayout(BuilderComponent component, {bool recomputeHeight = true}) {
    // Check if widthFit is enabled for this component
    final bool widthFit = component.properties['widthFit'] != false; // Default to true
    
    if (widthFit) {
      // Apply full width layout as before
      component.x = _componentHorizontalPadding;
      component.width = _availableComponentWidth();
    }
    // If widthFit is false, preserve current x and width values
    
    if (recomputeHeight && _canInlineEdit(component)) {
      final measuredHeight = _calculateTextComponentHeight(
        component,
        component.properties['text']?.toString() ?? '',
      );
      component.properties['minTextHeight'] = measuredHeight;
      final bool autoHeight = component.properties['autoHeight'] != false;
      if (autoHeight) {
        component.height = measuredHeight;
      } else {
        component.height = math.max(component.height, measuredHeight);
      }
    }
  }

  double _findNextAvailableY(double componentHeight) {
    if (_canvasComponents.isEmpty) {
      return canvasPadding * 0.5;
    }

    double maxBottom = 0;
    for (final component in _canvasComponents) {
      final bottom = component.y + component.height;
      if (bottom > maxBottom) {
        maxBottom = bottom;
      }
    }

    return maxBottom + _componentVerticalSpacing;
  }

  TextStyle _resolveTextStyle(BuilderComponent component) {
    final fontSizeValue = component.properties['fontSize'];
    final double fontSize = fontSizeValue is num
        ? fontSizeValue.toDouble()
        : _defaultFontSizeFor(component);
    final fontWeight = component.properties['isBold'] == true
        ? FontWeight.bold
        : FontWeight.normal;
    // For text components, prefer textColor over color property
    final colorValue = component.properties['textColor'] ??
        component.properties['color'] ??
        0xFF000000;
    final fontFamily = component.properties['fontFamily'] is String
        ? component.properties['fontFamily'] as String
        : 'Roboto';
    final isItalic = component.properties['isItalic'] == true;
    final isUnderline = component.properties['isUnderline'] == true;
    final letterSpacingValue = component.properties['letterSpacing'];
    final double? letterSpacing = letterSpacingValue is num
        ? letterSpacingValue.toDouble()
        : null;
    final lineHeightValue = component.properties['lineHeight'];
    final double height = lineHeightValue is num
        ? lineHeightValue.toDouble().clamp(1.0, 3.0)
        : 1.25;

    // Use Google Fonts for better cross-platform support
    TextStyle baseStyle;
    try {
      switch (fontFamily.toLowerCase()) {
        case 'roboto':
          baseStyle = GoogleFonts.roboto();
          break;
        case 'poppins':
          baseStyle = GoogleFonts.poppins();
          break;
        case 'lato':
          baseStyle = GoogleFonts.lato();
          break;
        case 'nunito':
          baseStyle = GoogleFonts.nunito();
          break;
        case 'montserrat':
          baseStyle = GoogleFonts.montserrat();
          break;
        case 'open sans':
          baseStyle = GoogleFonts.openSans();
          break;
        case 'merriweather':
          baseStyle = GoogleFonts.merriweather();
          break;
        default:
          baseStyle = GoogleFonts.roboto();
      }
    } catch (e) {
      // Fallback to system font if Google Fonts fails
      baseStyle = const TextStyle();
    }

    return baseStyle.copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: Color(colorValue),
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: letterSpacing,
      height: height,
      decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
    );
  }

  double _calculateTextComponentHeight(BuilderComponent component, String text) {
    final textToMeasure = text.isEmpty ? ' ' : text;
    final textPainter = TextPainter(
      text: TextSpan(text: textToMeasure, style: _resolveTextStyle(component)),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final paddingValue = component.properties['padding'];
    final double padding = paddingValue is num ? paddingValue.toDouble() : 8.0;
    final double horizontalPadding = padding * 2;
    final double availableWidth = math.max(component.width - horizontalPadding, 80);
    textPainter.layout(maxWidth: availableWidth);
    final double verticalPadding = padding * 2;
    return math.max(textPainter.size.height + verticalPadding, 36);
  }

  TextAlign _resolveTextAlign(BuilderComponent component) {
    final alignment = component.properties['textAlign'];
    switch (alignment) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      case 'center':
      default:
        return TextAlign.center;
    }
  }

  double _minimumComponentHeight(BuilderComponent component) {
    switch (component.type) {
      case ComponentType.textLabel:
      case ComponentType.textBox:
        final textValue = component.properties['text']?.toString() ?? '';
        final measured = _calculateTextComponentHeight(component, textValue);
        return math.max(40.0, measured);
      case ComponentType.dateContainer:
        return 56.0;
      case ComponentType.imageContainer:
        return 80.0;
      case ComponentType.iconContainer:
        return 48.0;
      case ComponentType.woodenContainer:
      case ComponentType.coloredContainer:
        return 80.0;
      case ComponentType.calendar:
        return 120.0;
      default:
        return 48.0;
    }
  }

  void _startInlineTextEditing(BuilderComponent component) {
    if (!_canInlineEdit(component)) return;
    if (_editingComponentId == component.id) return;

    if (_editingComponentId != null) {
      _stopInlineEditing(save: true);
    }

    final initialText = component.properties['text']?.toString() ?? '';
    _inlineEditorController ??= TextEditingController();
    _inlineEditorController!
      ..text = initialText
      ..selection = TextSelection.collapsed(offset: initialText.length);

    setState(() {
      _editingComponentId = component.id;
      _selectedComponentId = component.id;
      _applyFullWidthLayout(component);
      // Ensure proper height for initial text content
      _adjustComponentHeightForText(component, initialText);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_inlineEditorController != null) {
        _inlineEditorFocusNode.requestFocus();
      }
    });
  }

  void _stopInlineEditing({bool save = true}) {
    if (_editingComponentId == null) return;

    final editingId = _editingComponentId!;
    BuilderComponent? target;
    for (final component in _canvasComponents) {
      if (component.id == editingId) {
        target = component;
        break;
      }
    }

    final updatedText = _inlineEditorController?.text ??
        target?.properties['text']?.toString() ??
        '';

    setState(() {
      if (save && target != null) {
        target!.properties['text'] = updatedText;
        // Final height adjustment based on saved text
        _adjustComponentHeightForText(target!, updatedText);
        _applyFullWidthLayout(target!);
      }
      _editingComponentId = null;
    });

    // Clean up the controller and its listeners
    _inlineEditorController?.dispose();
    _inlineEditorController = null;

    _updateCanvasSize();
  }

  Widget _buildInlineTextEditorField(BuilderComponent component) {
    final bool isTextBox = component.type == ComponentType.textBox;
    final paddingValue = component.properties['padding'];
    final double padding = paddingValue is num
        ? paddingValue.toDouble()
        : (isTextBox ? 12.0 : 8.0);

    final backgroundValue = component.properties['backgroundColor'];
    final bool useGradient = component.properties['useGradient'] == true;
    final int gradientStart = component.properties['gradientStart'] is int 
        ? component.properties['gradientStart'] as int 
        : 0xFF3B82F6;
    final int gradientEnd = component.properties['gradientEnd'] is int 
        ? component.properties['gradientEnd'] as int 
        : 0xFF8B5CF6;
    
    Color? backgroundColor;
    Gradient? gradient;
    
    if (useGradient) {
      gradient = LinearGradient(
        colors: [Color(gradientStart), Color(gradientEnd)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (backgroundValue is int) {
      backgroundColor = Color(backgroundValue);
    } else if (isTextBox) {
      backgroundColor = const Color(0xFFF7F7F7);
    }

    final borderRadiusValue = component.properties['borderRadius'];
    final double borderRadius = borderRadiusValue is num
        ? borderRadiusValue.toDouble()
        : (isTextBox ? 12.0 : 8.0);

    final borderWidthValue = component.properties['borderWidth'];
    double borderWidth = borderWidthValue is num
        ? borderWidthValue.toDouble()
        : (isTextBox ? 1.0 : 0.0);

    final borderColorValue = component.properties['borderColor'];
    final Color borderColor = Color(borderColorValue is int
        ? borderColorValue
        : (isTextBox ? 0xFFE0E0E0 : 0xFFDDDDDD));

    final bool showBorder = component.properties['showBorder'] == true;
    if (!showBorder) {
      borderWidth = 0.0;
    } else if (borderWidth <= 0) {
      borderWidth = 1.0;
    }

    final BoxDecoration? decoration =
        (backgroundColor != null || gradient != null || borderWidth > 0)
            ? BoxDecoration(
                color: gradient == null ? backgroundColor : null,
                gradient: gradient,
                borderRadius: BorderRadius.circular(borderRadius),
                border: borderWidth > 0
                    ? Border.all(color: borderColor, width: borderWidth)
                    : null,
              )
            : null;

    final TextEditingController controller =
        _inlineEditorController ??= TextEditingController(
      text: component.properties['text']?.toString() ?? '',
    );

    // Add listener for dynamic height adjustment
    // Create a local function to avoid issues with listener management
    void heightAdjustmentListener() {
      if (mounted && _editingComponentId == component.id) {
        _adjustComponentHeightForText(component, controller.text);
      }
    }
    
    // Add the listener (it will be cleaned up when controller is disposed)
    controller.addListener(heightAdjustmentListener);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: decoration,
      child: TextField(
        controller: controller,
        focusNode: _inlineEditorFocusNode,
        autofocus: true,
        maxLines: null,
        minLines: 1,
        textAlign: _resolveTextAlign(component),
        style: _resolveTextStyle(component),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: (_) => _stopInlineEditing(save: true),
      ),
    );
  }

  void _adjustComponentHeightForText(BuilderComponent component, String text) {
    if (!mounted) return;
    
    final TextStyle textStyle = _resolveTextStyle(component);
    final bool isTextBox = component.type == ComponentType.textBox;
    final double paddingHorizontal = isTextBox ? 24.0 : 16.0; // Left + right padding
    final double paddingVertical = isTextBox ? 24.0 : 16.0; // Top + bottom padding
    
    final double availableWidth = component.width - paddingHorizontal;
    
    // Use the text with a minimum of one line to ensure proper height calculation
    final String measureText = text.isEmpty ? 'Ag' : text;
    
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: measureText, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    
    textPainter.layout(maxWidth: math.max(availableWidth, 50.0));
    
    final double minHeight = _initialComponentHeight(component.type);
    final double textHeight = textPainter.height;
    
    // Add extra space for cursor and better visibility during editing
    final double extraSpace = _editingComponentId == component.id ? 8.0 : 0.0;
    final double requiredHeight = textHeight + paddingVertical + extraSpace;
    
    // Update height if there's a significant difference
    final double newHeight = math.max(minHeight, requiredHeight);
    if ((component.height - newHeight).abs() > 3.0) {
      setState(() {
        component.height = newHeight;
      });
      
      // Schedule a canvas size update to avoid conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateCanvasSize();
        }
      });
    }
  }

  Widget _buildStyledTextComponent(BuilderComponent component, {required bool isTextBox}) {
    final String textValue = component.properties['text']?.toString() ??
        (isTextBox ? 'Text Box Content' : 'Text Label');
    final paddingValue = component.properties['padding'];
    final double padding = paddingValue is num
        ? paddingValue.toDouble()
        : (isTextBox ? 12.0 : 8.0);

    final backgroundValue = component.properties['backgroundColor'];
    final bool useGradient = component.properties['useGradient'] == true;
    final int gradientStart = component.properties['gradientStart'] is int 
        ? component.properties['gradientStart'] as int 
        : 0xFF3B82F6;
    final int gradientEnd = component.properties['gradientEnd'] is int 
        ? component.properties['gradientEnd'] as int 
        : 0xFF8B5CF6;
    
    Color? backgroundColor;
    Gradient? gradient;
    
    if (useGradient) {
      gradient = LinearGradient(
        colors: [Color(gradientStart), Color(gradientEnd)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (backgroundValue is int) {
      backgroundColor = Color(backgroundValue);
    } else if (isTextBox) {
      backgroundColor = const Color(0xFFF7F7F7);
    }

    final borderRadiusValue = component.properties['borderRadius'];
    final double borderRadius = borderRadiusValue is num
        ? borderRadiusValue.toDouble()
        : (isTextBox ? 12.0 : 8.0);

    final borderWidthValue = component.properties['borderWidth'];
    double borderWidth = borderWidthValue is num
        ? borderWidthValue.toDouble()
        : (isTextBox ? 1.0 : 0.0);

    final borderColorValue = component.properties['borderColor'];
    final Color borderColor = Color(borderColorValue is int
        ? borderColorValue
        : (isTextBox ? 0xFFE0E0E0 : 0xFFDDDDDD));

    final bool showBorder = component.properties['showBorder'] == true;
    if (!showBorder) {
      borderWidth = 0.0;
    } else if (borderWidth <= 0) {
      borderWidth = 1.0;
    }

    final int? maxLinesValue = component.properties['maxLines'] is int
        ? component.properties['maxLines'] as int
        : null;

    final decoration = (backgroundColor != null || gradient != null || borderWidth > 0)
        ? BoxDecoration(
            color: gradient == null ? backgroundColor : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: borderWidth > 0
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
          )
        : null;

    // Check if width fit is enabled
    final bool widthFitEnabled = component.properties['widthFit'] != false;

    Widget textWidget = Text(
      textValue,
      style: _resolveTextStyle(component),
      softWrap: true,
      textAlign: _resolveTextAlign(component),
      maxLines: maxLinesValue,
      overflow: maxLinesValue != null ? TextOverflow.ellipsis : TextOverflow.visible,
    );

    // If width fit is enabled, wrap text in a SizedBox to take full width
    if (widthFitEnabled) {
      textWidget = SizedBox(
        width: double.infinity,
        child: textWidget,
      );
    }

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: decoration,
      child: textWidget,
    );
  }

  Widget _buildPropertiesButton(BuilderComponent component) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolbarIconButton(
            icon: Icons.palette,
            tooltip: 'Show properties',
            onTap: () {
              _showPropertiesDialog(component);
            },
            isActive: false,
            iconColor: Colors.white,
            backgroundColor: Colors.white24,
            activeIconColor: const Color(0xFF512DA8),
            activeBackgroundColor: Colors.white,
          ),
          const SizedBox(width: 8),
          _buildToolbarIconButton(
            icon: Icons.edit,
            tooltip: 'Edit content',
            onTap: () => _editComponent(component),
            iconColor: Colors.white,
            backgroundColor: const Color(0xFF1976D2),
          ),
          const SizedBox(width: 8),
          _buildToolbarIconButton(
            icon: Icons.close,
            tooltip: 'Remove component',
            onTap: () => _deleteComponent(component.id),
            iconColor: Colors.white,
            backgroundColor: const Color(0xFFD32F2F),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasPropertiesButton() {
    BuilderComponent? selectedComponent;
    if (_selectedComponentId != null) {
      try {
        selectedComponent = _canvasComponents.firstWhere((c) => c.id == _selectedComponentId);
      } catch (e) {
        selectedComponent = null;
      }
    }
    
    return Tooltip(
      message: selectedComponent != null ? 'Component Properties' : 'Canvas Properties',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (selectedComponent != null) {
              _showPropertiesDialog(selectedComponent);
            } else {
              _showCanvasBackgroundStyleEditor();
            }
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: selectedComponent != null 
                  ? const Color(0xFF673AB7).withOpacity(0.9) // Purple for component properties
                  : Colors.black.withOpacity(0.7), // Black for canvas properties
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              selectedComponent != null ? Icons.tune : Icons.palette,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _handlePropertySelection(BuilderComponent component, String action) {
    if (action != 'edit_text') {
      _stopInlineEditing(save: true);
    }

    switch (action) {
      case 'edit_text':
        _startInlineTextEditing(component);
        break;
      case 'font_increase':
        setState(() {
          final fontSizeValue = component.properties['fontSize'];
          final currentSize = fontSizeValue is num
              ? fontSizeValue.toDouble()
              : _defaultFontSizeFor(component);
          final newSize = math.min(currentSize + 2, 72);
          component.properties['fontSize'] = newSize;
          _applyFullWidthLayout(component);
        });
        _updateCanvasSize();
        break;
      case 'font_decrease':
        setState(() {
          final fontSizeValue = component.properties['fontSize'];
          final currentSize = fontSizeValue is num
              ? fontSizeValue.toDouble()
              : _defaultFontSizeFor(component);
          final newSize = math.max(currentSize - 2, 8);
          component.properties['fontSize'] = newSize;
          _applyFullWidthLayout(component);
        });
        _updateCanvasSize();
        break;
      case 'toggle_bold':
        setState(() {
          final isBold = component.properties['isBold'] == true;
          component.properties['isBold'] = !isBold;
          _applyFullWidthLayout(component);
        });
        _updateCanvasSize();
        break;
      case 'text_color':
        _showTextColorPicker(component);
        break;
      case 'text_style':
        _showTextStyleEditor(component);
        break;
      case 'text_align':
        _showTextAlignmentPicker(component);
        break;
      case 'background_style':
        _showBackgroundStyleEditor(component);
        break;
      case 'toggle_auto_height':
        setState(() {
          final bool currentlyAuto = component.properties['autoHeight'] != false;
          final bool nextAuto = !currentlyAuto;
          component.properties['autoHeight'] = nextAuto;
          final textValue = component.properties['text']?.toString() ?? '';
          final measuredHeight = _calculateTextComponentHeight(component, textValue);
          component.properties['minTextHeight'] = measuredHeight;
          if (nextAuto) {
            component.height = measuredHeight;
          } else {
            component.height = math.max(component.height, measuredHeight);
          }
        });
        _updateCanvasSize();
        break;
      case 'toggle_width_fit':
        setState(() {
          final bool currentlyWidthFit = component.properties['widthFit'] != false;
          component.properties['widthFit'] = !currentlyWidthFit;
          if (!currentlyWidthFit) {
            // If enabling width fit, apply full width layout
            _applyFullWidthLayout(component);
          }
        });
        _updateCanvasSize();
        break;
      case 'reset_height':
        setState(() {
          final textValue = component.properties['text']?.toString() ?? '';
          final measuredHeight = _calculateTextComponentHeight(component, textValue);
          component.properties['autoHeight'] = true;
          component.properties['minTextHeight'] = measuredHeight;
          component.height = measuredHeight;
        });
        _updateCanvasSize();
        break;
      case 'change_date':
        _showInlineDatePicker(component);
        break;
    }
  }

  Future<void> _showTextColorPicker(BuilderComponent component) async {
    final currentColorValue = component.properties['color'] ?? component.properties['textColor'] ?? 0xFF000000;
    final currentColor = Color(currentColorValue);

    final Color? selectedColor = await _showAdvancedColorPicker(
      context,
      currentColor,
      'Pick Text Color',
    );

    if (!mounted || selectedColor == null) {
      return;
    }

    setState(() {
      // Find the component in the main list and update it
      final componentIndex = _canvasComponents.indexWhere((c) => c.id == component.id);
      
      if (componentIndex != -1) {
        // Only set textColor for text components, this takes precedence
        _canvasComponents[componentIndex].properties['textColor'] = selectedColor.value;
        _applyFullWidthLayout(_canvasComponents[componentIndex]);
      } else {
        // Fallback to direct component update
        component.properties['textColor'] = selectedColor.value;
        _applyFullWidthLayout(component);
      }
    });
    _updateCanvasSize();
  }

  Future<void> _showTextStyleEditor(BuilderComponent component) async {
    final availableFonts = <String>[
      'Roboto',
      'Poppins',
      'Lato',
      'Nunito',
      'Montserrat',
      'Open Sans',
      'Merriweather',
    ];

    double fontSize = component.properties['fontSize'] is num
        ? (component.properties['fontSize'] as num).toDouble()
        : _defaultFontSizeFor(component);
    bool isBold = component.properties['isBold'] == true;
    bool isItalic = component.properties['isItalic'] == true;
    bool isUnderline = component.properties['isUnderline'] == true;
    String fontFamily = component.properties['fontFamily'] is String
        ? component.properties['fontFamily'] as String
        : 'Roboto';
    double letterSpacing = component.properties['letterSpacing'] is num
        ? (component.properties['letterSpacing'] as num).toDouble()
        : 0.0;
    double lineHeight = component.properties['lineHeight'] is num
        ? (component.properties['lineHeight'] as num).toDouble()
        : 1.25;
    
    // Text shadow properties
    bool hasShadow = component.properties['hasShadow'] == true;
    int shadowColor = component.properties['shadowColor'] ?? 0xFF000000;
    double shadowOffsetX = component.properties['shadowOffsetX'] is num
        ? (component.properties['shadowOffsetX'] as num).toDouble()
        : 1.0;
    double shadowOffsetY = component.properties['shadowOffsetY'] is num
        ? (component.properties['shadowOffsetY'] as num).toDouble()
        : 1.0;
    double shadowBlurRadius = component.properties['shadowBlurRadius'] is num
        ? (component.properties['shadowBlurRadius'] as num).toDouble()
        : 2.0;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 400,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Typography & Effects',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: Colors.grey.shade600),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Font size'),
                          Slider(
                            value: fontSize.clamp(8.0, 72.0),
                            min: 8,
                            max: 72,
                            divisions: 64,
                            label: fontSize.toStringAsFixed(0),
                            onChanged: (value) => setDialogState(() => fontSize = value),
                          ),
                          const SizedBox(height: 12),
                          const Text('Font family'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableFonts.map((font) {
                              final bool selected = fontFamily == font;
                              return ChoiceChip(
                                label: Text(font),
                                selected: selected,
                                onSelected: (value) {
                                  if (value) {
                                    setDialogState(() => fontFamily = font);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            children: [
                              FilterChip(
                                label: const Text('Bold'),
                                selected: isBold,
                                onSelected: (value) => setDialogState(() => isBold = value),
                              ),
                              FilterChip(
                                label: const Text('Italic'),
                                selected: isItalic,
                                onSelected: (value) => setDialogState(() => isItalic = value),
                              ),
                              FilterChip(
                                label: const Text('Underline'),
                                selected: isUnderline,
                                onSelected: (value) => setDialogState(() => isUnderline = value),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Letter spacing'),
                          Slider(
                            value: letterSpacing.clamp(-1.0, 5.0),
                            min: -1,
                            max: 5,
                            divisions: 60,
                            label: letterSpacing.toStringAsFixed(2),
                            onChanged: (value) => setDialogState(() => letterSpacing = value),
                          ),
                          const SizedBox(height: 12),
                          const Text('Line height'),
                          Slider(
                            value: lineHeight.clamp(1.0, 3.0),
                            min: 1.0,
                            max: 3.0,
                            divisions: 20,
                            label: lineHeight.toStringAsFixed(2),
                            onChanged: (value) => setDialogState(() => lineHeight = value),
                          ),
                          const SizedBox(height: 16),
                          // Text Shadow Section
                          Row(
                            children: [
                              Text('Text Shadow', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Switch(
                                value: hasShadow,
                                onChanged: (value) => setDialogState(() => hasShadow = value),
                              ),
                            ],
                          ),
                          if (hasShadow) ...[
                            const SizedBox(height: 12),
                            const Text('Shadow Color', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final Color? newColor = await _showAdvancedColorPicker(
                                  context,
                                  Color(shadowColor),
                                  'Select Shadow Color',
                                );
                                if (newColor != null) {
                                  setDialogState(() => shadowColor = newColor.value);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Color(shadowColor),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.palette,
                                      color: Color(shadowColor).computeLuminance() > 0.5 
                                          ? Colors.black54 
                                          : Colors.white70,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tap to choose color',
                                      style: TextStyle(
                                        color: Color(shadowColor).computeLuminance() > 0.5 
                                            ? Colors.black 
                                            : Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Horizontal Offset: ${shadowOffsetX.toStringAsFixed(1)}px'),
                            Slider(
                              value: shadowOffsetX.clamp(-10.0, 10.0),
                              min: -10,
                              max: 10,
                              divisions: 40,
                              onChanged: (value) => setDialogState(() => shadowOffsetX = value),
                            ),
                            const SizedBox(height: 8),
                            Text('Vertical Offset: ${shadowOffsetY.toStringAsFixed(1)}px'),
                            Slider(
                              value: shadowOffsetY.clamp(-10.0, 10.0),
                              min: -10,
                              max: 10,
                              divisions: 40,
                              onChanged: (value) => setDialogState(() => shadowOffsetY = value),
                            ),
                            const SizedBox(height: 8),
                            Text('Blur Radius: ${shadowBlurRadius.toStringAsFixed(1)}px'),
                            Slider(
                              value: shadowBlurRadius.clamp(0.0, 20.0),
                              min: 0,
                              max: 20,
                              divisions: 40,
                              onChanged: (value) => setDialogState(() => shadowBlurRadius = value),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop<Map<String, dynamic>>(context, {
                            'fontSize': fontSize,
                            'fontFamily': fontFamily,
                            'isBold': isBold,
                            'isItalic': isItalic,
                            'isUnderline': isUnderline,
                            'letterSpacing': letterSpacing,
                            'lineHeight': lineHeight,
                            'hasShadow': hasShadow,
                            'shadowColor': shadowColor,
                            'shadowOffsetX': shadowOffsetX,
                            'shadowOffsetY': shadowOffsetY,
                            'shadowBlurRadius': shadowBlurRadius,
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      component.properties.addAll(result);
      _applyFullWidthLayout(component);
    });
    _updateCanvasSize();
  }

  Future<void> _showTextAlignmentPicker(BuilderComponent component) async {
    final options = <Map<String, dynamic>>[
      {'label': 'Align left', 'value': 'left', 'icon': Icons.format_align_left},
      {'label': 'Align center', 'value': 'center', 'icon': Icons.format_align_center},
      {'label': 'Align right', 'value': 'right', 'icon': Icons.format_align_right},
      {'label': 'Justify', 'value': 'justify', 'icon': Icons.format_align_justify},
    ];

    final String current = component.properties['textAlign']?.toString() ?? 'left';

    final String? selection = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Text Alignment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                height: 1,
                color: Colors.grey.shade300,
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: options.map((option) {
                    final bool selected = current == option['value'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(option['icon'] as IconData,
                            color: selected ? const Color(0xFF673AB7) : Colors.grey.shade600),
                        title: Text(option['label'] as String),
                        trailing: selected ? const Icon(Icons.check, color: Color(0xFF673AB7)) : null,
                        onTap: () => Navigator.pop(context, option['value'] as String),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tileColor: selected ? const Color(0xFF673AB7).withOpacity(0.1) : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selection == null) return;

    setState(() {
      component.properties['textAlign'] = selection;
      _applyFullWidthLayout(component);
    });
    _updateCanvasSize();
  }

  Future<void> _showBackgroundStyleEditor(BuilderComponent component) async {

    int? backgroundColor = component.properties['backgroundColor'] is int
        ? component.properties['backgroundColor'] as int
        : null;
    bool useGradient = component.properties['useGradient'] == true;
    int gradientStart = component.properties['gradientStart'] is int
        ? component.properties['gradientStart'] as int
        : 0xFF3B82F6; // Default blue
    int gradientEnd = component.properties['gradientEnd'] is int
        ? component.properties['gradientEnd'] as int
        : 0xFF8B5CF6; // Default purple
    bool showBorder = component.properties['showBorder'] == true;
    double borderWidth = component.properties['borderWidth'] is num
        ? (component.properties['borderWidth'] as num).toDouble().clamp(0.0, 12.0)
        : (showBorder ? 1.0 : 0.0);
    int borderColor = component.properties['borderColor'] is int
        ? component.properties['borderColor'] as int
        : 0xFFE0E0E0;
    double borderRadius = component.properties['borderRadius'] is num
        ? (component.properties['borderRadius'] as num).toDouble().clamp(0.0, 48.0)
        : 12.0;
    double padding = component.properties['padding'] is num
        ? (component.properties['padding'] as num).toDouble().clamp(0.0, 36.0)
        : 12.0;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 480,
                maxHeight: 500,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Background & Border',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: Icon(Icons.close, color: Colors.grey.shade600),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Background color'),
                          if (!useGradient) ...[
                            const SizedBox(height: 8),
                            const Text('Background Color', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final Color? newColor = await _showAdvancedColorPicker(
                                  context,
                                  backgroundColor != null ? Color(backgroundColor!) : Colors.white,
                                  'Select Background Color',
                                );
                                if (newColor != null) {
                                  setDialogState(() => backgroundColor = newColor.value);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: backgroundColor != null ? Color(backgroundColor!) : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.palette,
                                      color: backgroundColor != null
                                          ? (Color(backgroundColor!).computeLuminance() > 0.5 ? Colors.black54 : Colors.white70)
                                          : Colors.black54,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tap to choose color',
                                      style: TextStyle(
                                        color: backgroundColor != null
                                            ? (Color(backgroundColor!).computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                            : Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
                              onPressed: () => setDialogState(() => backgroundColor = null),
                              icon: const Icon(Icons.clear, size: 14),
                              label: const Text('Remove', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: useGradient,
                            onChanged: (value) => setDialogState(() => useGradient = value),
                            title: const Text('Use gradient background', style: TextStyle(fontSize: 13)),
                            dense: true,
                          ),
                          if (useGradient) ...[
                            const SizedBox(height: 4),
                            const Text('Gradient Colors:', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Start Color Picker
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Start Color', style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () async {
                                          final Color? newColor = await _showAdvancedColorPicker(
                                            context,
                                            Color(gradientStart),
                                            'Select Start Color',
                                          );
                                          if (newColor != null) {
                                            setDialogState(() => gradientStart = newColor.value);
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Color(gradientStart),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Icon(
                                            Icons.palette,
                                            color: Color(gradientStart).computeLuminance() > 0.5 
                                                ? Colors.black54 
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // End Color Picker
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('End Color', style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () async {
                                          final Color? newColor = await _showAdvancedColorPicker(
                                            context,
                                            Color(gradientEnd),
                                            'Select End Color',
                                          );
                                          if (newColor != null) {
                                            setDialogState(() => gradientEnd = newColor.value);
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Color(gradientEnd),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Icon(
                                            Icons.palette,
                                            color: Color(gradientEnd).computeLuminance() > 0.5 
                                                ? Colors.black54 
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      setDialogState(() {
                                        final temp = gradientStart;
                                        gradientStart = gradientEnd;
                                        gradientEnd = temp;
                                      });
                                    },
                                    icon: const Icon(Icons.swap_horiz, size: 16),
                                    label: const Text('Swap Colors', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(gradientStart), Color(gradientEnd)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                child: Text(
                                  'Gradient Preview',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    shadows: [Shadow(color: Colors.black54, offset: Offset(0, 1))],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: showBorder,
                            onChanged: (value) => setDialogState(() => showBorder = value),
                            title: const Text('Show border', style: TextStyle(fontSize: 13)),
                            dense: true,
                          ),
                          if (showBorder) ...[
                            const SizedBox(height: 4),
                            const Text('Border width', style: TextStyle(fontSize: 12)),
                            Slider(
                              value: borderWidth.clamp(0.0, 12.0),
                              min: 0,
                              max: 12,
                              divisions: 12,
                              label: borderWidth.toStringAsFixed(1),
                              onChanged: (value) => setDialogState(() => borderWidth = value),
                            ),
                            const SizedBox(height: 6),
                            const Text('Border Color', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final Color? newColor = await _showAdvancedColorPicker(
                                  context,
                                  Color(borderColor),
                                  'Select Border Color',
                                );
                                if (newColor != null) {
                                  setDialogState(() => borderColor = newColor.value);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Color(borderColor),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.border_color,
                                      color: Color(borderColor).computeLuminance() > 0.5 
                                          ? Colors.black54 
                                          : Colors.white70,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tap to choose border color',
                                      style: TextStyle(
                                        color: Color(borderColor).computeLuminance() > 0.5 
                                            ? Colors.black 
                                            : Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          const Text('Corner radius', style: TextStyle(fontSize: 12)),
                          Slider(
                            value: borderRadius.clamp(0.0, 48.0),
                            min: 0,
                            max: 48,
                            divisions: 24,
                            label: borderRadius.toStringAsFixed(0),
                            onChanged: (value) => setDialogState(() => borderRadius = value),
                          ),
                          const SizedBox(height: 4),
                          const Text('Padding', style: TextStyle(fontSize: 12)),
                          Slider(
                            value: padding.clamp(0.0, 36.0),
                            min: 0,
                            max: 36,
                            divisions: 18,
                            label: padding.toStringAsFixed(0),
                            onChanged: (value) => setDialogState(() => padding = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop<Map<String, dynamic>>({
                              'backgroundColor': useGradient ? null : backgroundColor,
                              'useGradient': useGradient,
                              'gradientStart': useGradient ? gradientStart : null,
                              'gradientEnd': useGradient ? gradientEnd : null,
                              'showBorder': showBorder,
                              'borderWidth': showBorder ? borderWidth : 0.0,
                              'borderColor': showBorder ? borderColor : component.properties['borderColor'],
                              'borderRadius': borderRadius,
                              'padding': padding,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!mounted || result == null) return;

    final Map<String, dynamic> resultMap = result;
    setState(() {
      component.properties.addAll(resultMap);
    });
    _updateCanvasSize();
  }

  Future<void> _showCanvasBackgroundStyleEditor() async {
    const colorOptions = <int>[
      0xFFFFFFFF, // White
      0xFFF7F7F7, // Light Gray
      0xFFE3F2FD, // Light Blue
      0xFFE8F5E9, // Light Green
      0xFFFFF3E0, // Light Orange
      0xFFFCE4EC, // Light Pink
      0xFF1F2933, // Dark Gray
      0xFF4B5563, // Slate Gray
      0xFF8B5CF6, // Purple
      0xFF3B82F6, // Blue
      0xFF10B981, // Green
      0xFFF59E0B, // Orange
      0xFFEF4444, // Red
      0xFF6B7280, // Gray
    ];

    int? backgroundColor = canvasBackgroundColor.value == 0xFFFFFFFF ? null : canvasBackgroundColor.value;
    bool useGradient = useGradientBackground;
    int gradientStart = _customGradientStartColor.value;
    int gradientEnd = _customGradientEndColor.value;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 480,
                maxHeight: 500,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Canvas Background',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Background color'),
                          if (!useGradient) ...[
                            const SizedBox(height: 8),
                            const Text('Background Color', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final Color? newColor = await _showAdvancedColorPicker(
                                  context,
                                  backgroundColor != null ? Color(backgroundColor!) : Colors.white,
                                  'Select Background Color',
                                );
                                if (newColor != null) {
                                  setDialogState(() => backgroundColor = newColor.value);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: backgroundColor != null ? Color(backgroundColor!) : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.palette,
                                      color: backgroundColor != null
                                          ? (Color(backgroundColor!).computeLuminance() > 0.5 ? Colors.black54 : Colors.white70)
                                          : Colors.black54,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tap to choose color',
                                      style: TextStyle(
                                        color: backgroundColor != null
                                            ? (Color(backgroundColor!).computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                            : Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
                              onPressed: () => setDialogState(() => backgroundColor = 0xFFFFFFFF),
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text('Reset to White', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: useGradient,
                            onChanged: (value) => setDialogState(() => useGradient = value),
                            title: const Text('Use gradient background', style: TextStyle(fontSize: 13)),
                            dense: true,
                          ),
                          if (useGradient) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Start Color Picker
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Start Color', style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () async {
                                          final Color? newColor = await _showAdvancedColorPicker(
                                            context,
                                            Color(gradientStart),
                                            'Select Start Color',
                                          );
                                          if (newColor != null) {
                                            setDialogState(() => gradientStart = newColor.value);
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Color(gradientStart),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Icon(
                                            Icons.palette,
                                            color: Color(gradientStart).computeLuminance() > 0.5 
                                                ? Colors.black54 
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // End Color Picker
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('End Color', style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () async {
                                          final Color? newColor = await _showAdvancedColorPicker(
                                            context,
                                            Color(gradientEnd),
                                            'Select End Color',
                                          );
                                          if (newColor != null) {
                                            setDialogState(() => gradientEnd = newColor.value);
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Color(gradientEnd),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Icon(
                                            Icons.palette,
                                            color: Color(gradientEnd).computeLuminance() > 0.5 
                                                ? Colors.black54 
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      setDialogState(() {
                                        final temp = gradientStart;
                                        gradientStart = gradientEnd;
                                        gradientEnd = temp;
                                      });
                                    },
                                    icon: const Icon(Icons.swap_horiz, size: 16),
                                    label: const Text('Swap Colors', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(gradientStart), Color(gradientEnd)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                child: Text(
                                  'Gradient Preview',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    shadows: [Shadow(color: Colors.black54, offset: Offset(0, 1))],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          
                          // Border Section
                          const SizedBox(height: 24),
                          Text(
                            'Border Style',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Border Color
                          Text('Border Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final Color? newColor = await _showAdvancedColorPicker(
                                context,
                                canvasBorderColor,
                                'Select Border Color',
                              );
                              if (newColor != null) {
                                setDialogState(() => canvasBorderColor = newColor);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: canvasBorderColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.border_color,
                                    color: canvasBorderColor.computeLuminance() > 0.5 
                                        ? Colors.black54 
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tap to choose border color',
                                    style: TextStyle(
                                      color: canvasBorderColor.computeLuminance() > 0.5 
                                          ? Colors.black 
                                          : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Border Width
                          Text('Border Width: ${canvasBorderWidth.toInt()}px', 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Slider(
                            value: canvasBorderWidth,
                            min: 0.0,
                            max: 10.0,
                            divisions: 20,
                            label: '${canvasBorderWidth.toInt()}px',
                            onChanged: (value) {
                              setDialogState(() => canvasBorderWidth = value);
                            },
                          ),
                          const SizedBox(height: 8),
                          
                          // Border Radius
                          Text('Border Radius: ${canvasBorderRadius.toInt()}px', 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Slider(
                            value: canvasBorderRadius,
                            min: 0.0,
                            max: 50.0,
                            divisions: 25,
                            label: '${canvasBorderRadius.toInt()}px',
                            onChanged: (value) {
                              setDialogState(() => canvasBorderRadius = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop<Map<String, dynamic>>({
                              'backgroundColor': useGradient ? null : backgroundColor,
                              'useGradient': useGradient,
                              'gradientStart': useGradient ? gradientStart : null,
                              'gradientEnd': useGradient ? gradientEnd : null,
                              'borderColor': canvasBorderColor.value,
                              'borderWidth': canvasBorderWidth,
                              'borderRadius': canvasBorderRadius,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!mounted || result == null) return;

    final Map<String, dynamic> resultMap = result;
    setState(() {
      if (resultMap['useGradient'] == true) {
        // Apply gradient
        useGradientBackground = true;
        _customGradientStartColor = Color(resultMap['gradientStart'] as int);
        _customGradientEndColor = Color(resultMap['gradientEnd'] as int);
        canvasBackgroundGradient = LinearGradient(
          colors: [_customGradientStartColor, _customGradientEndColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        canvasBackgroundColor = _customGradientStartColor;
        _selectedBackgroundPresetId = _customGradientPresetId;
      } else {
        // Apply solid color
        useGradientBackground = false;
        canvasBackgroundColor = Color(resultMap['backgroundColor'] as int? ?? 0xFFFFFFFF);
        canvasBackgroundGradient = null;
        _selectedBackgroundPresetId = 'custom_solid';
      }
      
      // Apply border properties
      if (resultMap['borderColor'] != null) {
        canvasBorderColor = Color(resultMap['borderColor'] as int);
      }
      if (resultMap['borderWidth'] != null) {
        canvasBorderWidth = resultMap['borderWidth'] as double;
      }
      if (resultMap['borderRadius'] != null) {
        canvasBorderRadius = resultMap['borderRadius'] as double;
      }
    });
  }

  void _addComponentToCanvas(ComponentType type, Offset globalOffset) {
    final RenderBox? canvasBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;

    final localOffset = canvasBox.globalToLocal(globalOffset);
    final double componentWidth = _availableComponentWidth();
    final double baseHeight = _initialComponentHeight(type);
    final BuilderComponent component = BuilderComponent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      x: _componentHorizontalPadding,
      y: math.max(0, localOffset.dy - baseHeight / 2),
      width: componentWidth,
      height: baseHeight,
      properties: _getDefaultProperties(type),
    );

    _applyFullWidthLayout(component);

    setState(() {
      _canvasComponents.add(component);
    });

    _updateCanvasSize();
  }

  void _addComponentToCanvasMobile(ComponentType type) {
    final double componentWidth = _availableComponentWidth();
    final double baseHeight = _initialComponentHeight(type);
    final double y = _findNextAvailableY(baseHeight);

    final component = BuilderComponent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      x: _componentHorizontalPadding,
      y: y,
      width: componentWidth,
      height: baseHeight,
      properties: _getDefaultProperties(type),
    );

    _applyFullWidthLayout(component);

    setState(() {
      _canvasComponents.add(component);
    });

    _updateCanvasSize();
  }

  void _addComponentToCanvasTablet(ComponentType type) {
    final double componentWidth = _availableComponentWidth();
    final double baseHeight = _initialComponentHeight(type);
    final double y = _findNextAvailableY(baseHeight);

    final component = BuilderComponent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      x: _componentHorizontalPadding,
      y: y,
      width: componentWidth,
      height: baseHeight,
      properties: _getDefaultProperties(type),
    );

    _applyFullWidthLayout(component);

    setState(() {
      _canvasComponents.add(component);
    });

    _updateCanvasSize();
  }

  Map<String, dynamic> _getDefaultProperties(ComponentType type) {
    switch (type) {
      case ComponentType.textLabel:
        return {
          'text': 'Text Label',
          'fontSize': 16.0,
          'color': 0xFF000000,
          'textColor': 0xFF000000,
          'isBold': false,
          'isItalic': false,
          'isUnderline': false,
          'fontFamily': 'Roboto',
          'letterSpacing': 0.0,
          'lineHeight': 1.25,
          'textAlign': 'left',
          'padding': 8.0,
          'borderRadius': 8.0,
          'borderWidth': 0.0,
          'showBorder': false,
          'autoHeight': true,
          'widthFit': true,
        };
      case ComponentType.textBox:
        return {
          'text': 'Text Box Content',
          'fontSize': 14.0,
          'color': 0xFF000000,
          'textColor': 0xFF000000,
          'isBold': false,
          'isItalic': false,
          'isUnderline': false,
          'fontFamily': 'Poppins', // Changed to Poppins
          'letterSpacing': 0.0,
          'lineHeight': 1.35,
          'textAlign': 'left',
          'padding': 12.0,
          'borderRadius': 12.0,
          'borderWidth': 0.0, // No border
          'borderColor': 0xFFE0E0E0,
          'showBorder': false, // No border
          'backgroundColor': 0x00000000, // Transparent background
          'autoHeight': true,
          'widthFit': true,
        };
      case ComponentType.dateContainer:
        return {'selectedDate': DateTime.now().millisecondsSinceEpoch};
      case ComponentType.gradientDivider:
        return {
          'color1': 0xFF6366F1, // Modern indigo
          'color2': 0xFF8B5CF6, // Modern purple
          'height': 4.0,
          'width': 200.0,
          'cornerRadius': 2.0,
          'padding': 0.0, // No padding
        };
      default:
        return {};
    }
  }

  double _initialComponentHeight(ComponentType type) {
    switch (type) {
      case ComponentType.textLabel:
        return 56.0;
      case ComponentType.textBox:
        return 72.0;
      case ComponentType.dateContainer:
        return 60.0;
      case ComponentType.gradientDivider:
        return 24.0; // Larger clickable area
      case ComponentType.imageContainer:
        return 180.0;
      case ComponentType.iconContainer:
        return 120.0;
      case ComponentType.woodenContainer:
      case ComponentType.coloredContainer:
        return 160.0;
      case ComponentType.calendar:
        return 220.0;
      default:
        return 100.0;
    }
  }

  void _editComponent(BuilderComponent component) {
    if (_selectedComponentId != component.id) {
      setState(() {
        _selectedComponentId = component.id;
      });
    }
    if (component.type == ComponentType.textLabel || component.type == ComponentType.textBox) {
      _startInlineTextEditing(component);
    } else if (component.type == ComponentType.dateContainer) {
      _showInlineDatePicker(component);
    }
  }

  void _showInlineTextEditor(BuilderComponent component) {
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

  void _showInlineDatePicker(BuilderComponent component) {
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

  Widget _buildEmojiPicker(TextEditingController textController) {
    // Emoji picker implementation (same as in template_management_page.dart)
    final List<List<String>> emojiCategories = [
      ['😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙'],
      ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝'],
      ['🎉', '🎊', '🥳', '🎈', '🎁', '🎂', '🍰', '🧁', '🎇', '🎆', '✨', '⭐', '🌟', '💫', '🔥', '💥', '🎵', '🎶'],
      ['📚', '📖', '📝', '✏️', '📏', '📐', '🎒', '🏫', '👨‍🏫', '👩‍🏫', '👨‍🎓', '👩‍🎓', '🎓', '📜', '🏆', '🥇', '🥈', '🥉'],
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

  void _deleteComponent(String componentId) {
    if (_editingComponentId == componentId) {
      _stopInlineEditing(save: false);
    }

    setState(() {
      _canvasComponents.removeWhere((c) => c.id == componentId);
      if (_selectedComponentId == componentId) {
        _selectedComponentId = null;
      }
    });
    _updateCanvasSize();
    
    // Show confirmation dialog with OK button
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Component Deleted',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            fontFamily: 'Roboto',
          ),
        ),
        content: const Text(
          'The component has been successfully removed from the canvas.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontFamily: 'Roboto',
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B5563),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearCanvas() {
    _stopInlineEditing(save: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Canvas'),
        content: const Text('Are you sure you want to remove all components from the canvas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _canvasComponents.clear();
                _selectedComponentId = null;
                canvasHeight = minCanvasHeight;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _updateCanvasSize() {
    if (_canvasComponents.isEmpty) {
      if ((canvasHeight - minCanvasHeight).abs() > 0.5) {
        setState(() {
          canvasHeight = minCanvasHeight;
        });
      }
      return;
    }

    double maxY = 0;
    for (final component in _canvasComponents) {
      final bottomEdge = component.y + component.height;
      if (bottomEdge > maxY) {
        maxY = bottomEdge;
      }
    }

    final newHeight = math.max(minCanvasHeight, maxY + canvasPadding);

    if ((newHeight - canvasHeight).abs() > 0.5) {
      setState(() {
        canvasHeight = newHeight;
      });
    }
  }

  void _showCanvasSizeDialog() {
    final widthController = TextEditingController(text: canvasWidth.toString());
    final heightController = TextEditingController(text: canvasHeight.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Canvas Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widthController,
              decoration: const InputDecoration(labelText: 'Width'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: heightController,
              decoration: const InputDecoration(labelText: 'Height'),
              keyboardType: TextInputType.number,
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
              setState(() {
                canvasWidth = double.tryParse(widthController.text) ?? canvasWidth;
                canvasHeight = double.tryParse(heightController.text) ?? canvasHeight;
                _alignComponentsToCanvasWidth();
              });
              _updateCanvasSize();
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientColorTile({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final textColor =
        color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor.withOpacity(0.86),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
              style: TextStyle(
                color: textColor.withOpacity(0.86),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackgroundColorPicker() {
    Color tempStartColor = _customGradientStartColor;
    Color tempEndColor = _customGradientEndColor;
    String tempDirection = _customGradientDirection;

    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewGradient = _buildGradientFromState(
              startColor: tempStartColor,
              endColor: tempEndColor,
              direction: tempDirection,
            );

            return AlertDialog(
              title: const Text('Custom Canvas Gradient'),
              content: SizedBox(
                height: 400, // Constrain height to prevent overflow
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: previewGradient,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGradientColorTile(
                              label: 'Start Color',
                              color: tempStartColor,
                              onTap: () async {
                                final selectedColor = await showColorPickerDialog(
                                  context: context,
                                  initialColor: tempStartColor,
                                  title: 'Select Start Color',
                                );
                                if (selectedColor != null) {
                                  setDialogState(() {
                                    tempStartColor = selectedColor;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGradientColorTile(
                              label: 'End Color',
                              color: tempEndColor,
                              onTap: () async {
                                final selectedColor = await showColorPickerDialog(
                                  context: context,
                                  initialColor: tempEndColor,
                                  title: 'Select End Color',
                                );
                                if (selectedColor != null) {
                                  setDialogState(() {
                                    tempEndColor = selectedColor;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Direction',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Swap Colors',
                            icon: const Icon(Icons.swap_horiz),
                            onPressed: () {
                              setDialogState(() {
                                final temp = tempStartColor;
                                tempStartColor = tempEndColor;
                                tempEndColor = temp;
                              });
                            },
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _gradientDirectionPresets.keys.map((directionKey) {
                          final isSelected = directionKey == tempDirection;
                          return ChoiceChip(
                            label: Text(
                              _gradientDirectionLabels[directionKey] ?? directionKey,
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setDialogState(() {
                                tempDirection = directionKey;
                              });
                            },
                            selectedColor: const Color(0xFF673AB7),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF333333),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop<Map<String, dynamic>>(dialogContext, {
                      'startColor': tempStartColor,
                      'endColor': tempEndColor,
                      'direction': tempDirection,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply Gradient'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result == null) return;

      final Color startColor =
          result['startColor'] as Color? ?? _customGradientStartColor;
      final Color endColor =
          result['endColor'] as Color? ?? _customGradientEndColor;
      final String direction =
          result['direction'] as String? ?? _customGradientDirection;

      setState(() {
        _customGradientStartColor = startColor;
        _customGradientEndColor = endColor;
        _customGradientDirection = direction;
        useGradientBackground = true;
        canvasBackgroundGradient = _buildGradientFromState(
          startColor: startColor,
          endColor: endColor,
          direction: direction,
        );
        canvasBackgroundColor = startColor;
        _selectedBackgroundPresetId = _customGradientPresetId;
      });
    });
  }

  void _performAutoAlignment() {
    if (_canvasComponents.isEmpty) return;

    final List<BuilderComponent> ordered = List.of(_canvasComponents)
      ..sort((a, b) => a.y.compareTo(b.y));
    double currentY = canvasPadding * 0.5;

    setState(() {
      for (final component in ordered) {
        _applyFullWidthLayout(component);
        component.y = currentY;
        currentY += component.height + _componentVerticalSpacing;
      }
    });

    _updateCanvasSize();
  }

  void _performManualAlignment() {
    _performAutoAlignment();
  }

  void _showSettingsMenu() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        size.width - 200,
        kToolbarHeight,
        20,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'auto_align',
          child: Row(
            children: const [
              Icon(Icons.auto_fix_high, size: 18, color: Color(0xFF673AB7)),
              SizedBox(width: 12),
              Text('Auto Align'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear_canvas',
          child: Row(
            children: const [
              Icon(Icons.clear_all, size: 18, color: Colors.red),
              SizedBox(width: 12),
              Text('Clear Canvas'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'auto_align') {
        _performAutoAlignment();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Components auto-aligned!'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF673AB7),
          ),
        );
      } else if (value == 'clear_canvas') {
        _clearCanvas();
      }
    });
  }

  Future<String?> _showTemplateNameDialog() async {
    final TextEditingController dialogController = TextEditingController();
    dialogController.text = 'My Custom Template'; // Default name
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Save Template',
            style: TextStyle(
              color: Color(0xFF673AB7),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a name for your template:',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dialogController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Template name...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF673AB7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF673AB7), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(context).pop(value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = dialogController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.of(context).pop(name);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a template name')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF673AB7),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTemplate() async {
    // Show dialog to get template name first
    final templateName = await _showTemplateNameDialog();
    if (templateName == null || templateName.trim().isEmpty) {
      return; // User cancelled or entered empty name
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic>? gradientData;
      if (useGradientBackground && canvasBackgroundGradient is LinearGradient) {
        final linearGradient = canvasBackgroundGradient as LinearGradient;
        final begin = _resolveAlignment(linearGradient.begin);
        final end = _resolveAlignment(linearGradient.end);
        gradientData = {
          'colors': linearGradient.colors.map((color) => color.value).toList(),
          'begin': {'x': begin.x, 'y': begin.y},
          'end': {'x': end.x, 'y': end.y},
          'direction': _customGradientDirection,
        };
        if (linearGradient.stops != null) {
          gradientData['stops'] = List<double>.from(linearGradient.stops!);
        }
      }

      // Prepare template data
      final templateData = {
        'templateName': templateName.trim(),
        'templateType': 'CUSTOM',
        'isActive': true,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'canvasBackgroundColor': canvasBackgroundColor.value,
        'canvasBackgroundMode': useGradientBackground ? 'gradient' : 'solid',
        'canvasBackgroundPresetId': _selectedBackgroundPresetId,
        'canvasBackgroundGradient': gradientData,
        'components': _canvasComponents.map((component) => {
          'id': component.id,
          'type': component.type.toString(),
          'position': {'x': component.x, 'y': component.y},
          'size': {'width': component.width, 'height': component.height},
          'properties': component.properties,
        }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('custom_templates')
          .add(templateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Template saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Go back to template management
        Navigator.pop(context, true); // Pass true to indicate successful save
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Shows an advanced HSV color picker dialog with square color area
  Future<Color?> _showAdvancedColorPicker(
    BuildContext context,
    Color initialColor,
    String title,
  ) async {
    Color selectedColor = initialColor;

    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              height: 400,
              child: ColorPicker(
                pickerColor: selectedColor,
                onColorChanged: (Color color) {
                  selectedColor = color;
                },
                displayThumbColor: true,
                enableAlpha: false,
                pickerAreaHeightPercent: 0.8,
                labelTypes: const [],
                paletteType: PaletteType.hsv,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            ElevatedButton(
              child: const Text('Select'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop(selectedColor);
              },
            ),
          ],
        );
      },
    );
  }
}