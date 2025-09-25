import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/draggable_template_components.dart';

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
  Color canvasBackgroundColor = Colors.white;
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
      body: LayoutBuilder(
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
                // Template Name Input
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF673AB7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Template Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCompactEmojiTextField(_templateNameController, 'Enter template name'),
                    ],
                  ),
                ),
                
                // Components Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Components',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildComponentsGrid(),
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
              padding: const EdgeInsets.all(20),
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
            // Mobile Layout - Vertical with bottom drawer
            return Column(
              children: [
                // Template Name Input (Mobile)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF673AB7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Template Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _templateNameController,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Enter template name...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Canvas Area (Mobile)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Mobile Canvas Controls
                        _buildMobileCanvasControls(),
                        const SizedBox(height: 12),
                        
                        // Canvas
                        Expanded(
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
                      ],
                    ),
                  ),
                ),
                
                // Mobile Components Drawer
                _buildMobileComponentsDrawer(),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildMobileCanvasControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Auto-Align Toggle
          Row(
            children: [
              Switch(
                value: _autoAlignEnabled,
                onChanged: (value) => setState(() => _autoAlignEnabled = value),
                activeColor: const Color(0xFF673AB7),
              ),
              const Text('Auto-Align', style: TextStyle(fontSize: 12)),
            ],
          ),
          
          // Clear Canvas
          TextButton.icon(
            onPressed: _clearCanvas,
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileComponentsDrawer() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drawer Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Components Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: ComponentType.values.length,
                itemBuilder: (context, index) {
                  final type = ComponentType.values[index];
                  final config = _getComponentConfig(type);
                  return _buildMobileComponentTile(type, config['icon'], config['label']);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileComponentTile(ComponentType type, IconData icon, String label) {
    return GestureDetector(
      onTap: () => _addComponentToCanvasMobile(type),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF673AB7)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Canvas Size Controls
          Row(
            children: [
              Text('Canvas: ${canvasWidth.toInt()}×${canvasHeight.toInt()}', 
                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              if (canvasWidth > minCanvasWidth || canvasHeight > minCanvasHeight) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Text(
                    'Auto-Expanded',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_with, size: 10, color: Colors.blue[700]),
                      const SizedBox(width: 2),
                      Text(
                        'Scrollable',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _showCanvasSizeDialog,
            icon: const Icon(Icons.aspect_ratio, size: 20),
            tooltip: 'Resize Canvas',
          ),
          const SizedBox(width: 20),
          
          // Background Color
          const Text('Background:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showBackgroundColorPicker,
            child: Container(
              width: 32,
              height: 24,
              decoration: BoxDecoration(
                color: canvasBackgroundColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(width: 20),
          
          // Auto Alignment
          const Text('Auto Align:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Switch(
            value: _autoAlignEnabled,
            onChanged: (value) => setState(() => _autoAlignEnabled = value),
            activeColor: const Color(0xFF673AB7),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: _performManualAlignment,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Align Now'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF673AB7),
            ),
          ),
          
          const Spacer(),
          
          // Clear Canvas
          TextButton.icon(
            onPressed: _clearCanvas,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade600,
            ),
          ),
        ],
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
    };
    
    return components[type] ?? {'icon': Icons.help_outline, 'label': 'Unknown'};
  }

  Widget _buildComponentsGrid() {
    final components = [
      {'type': ComponentType.textLabel, 'icon': Icons.text_fields, 'label': 'Text Label'},
      {'type': ComponentType.textBox, 'icon': Icons.text_snippet, 'label': 'Text Box'},
      {'type': ComponentType.dateContainer, 'icon': Icons.calendar_today, 'label': 'Date'},
      {'type': ComponentType.imageContainer, 'icon': Icons.image, 'label': 'Image'},
      {'type': ComponentType.iconContainer, 'icon': Icons.emoji_emotions, 'label': 'Icon'},
      {'type': ComponentType.woodenContainer, 'icon': Icons.crop_square, 'label': 'Container'},
      {'type': ComponentType.coloredContainer, 'icon': Icons.rectangle, 'label': 'Colored Box'},
      {'type': ComponentType.calendar, 'icon': Icons.date_range, 'label': 'Calendar'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: components.length,
      itemBuilder: (context, index) {
        final component = components[index];
        return _buildDraggableComponentTile(
          component['type'] as ComponentType,
          component['icon'] as IconData,
          component['label'] as String,
        );
      },
    );
  }

  Widget _buildDraggableComponentTile(ComponentType type, IconData icon, String label) {
    return Draggable<ComponentType>(
      data: type,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF673AB7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildComponentTileContent(icon, label),
      ),
      child: _buildComponentTileContent(icon, label),
    );
  }

  Widget _buildComponentTileContent(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: const Color(0xFF673AB7)),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
            color: canvasBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 2),
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
                      child: Container(color: canvasBackgroundColor),
                    ),
                  ),
                  ..._canvasComponents.map((component) => _buildCanvasComponent(component)).toList(),
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
              _buildComponentContent(component, isEditing: isEditing),
              
              // Selection Controls
              if (isSelected && !isEditing) ...[
                Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(0, -44),
                    child: _buildPropertiesButton(component),
                  ),
                ),
                // Edit Button
                Positioned(
                  top: -18,
                  right: -18,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _editComponent(component),
                      icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                
                // Delete Button
                Positioned(
                  top: -18,
                  left: -18,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _deleteComponent(component.id),
                      icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                
                // Resize Handle
                Positioned(
                  bottom: -18,
                  left: math.max(0.0, (component.width / 2) - 18),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
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
                      width: 36,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF673AB7),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.drag_handle, color: Colors.white, size: 16),
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

  Widget _buildComponentContent(BuilderComponent component, {bool isEditing = false}) {
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
      
      default:
        return Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.widgets, color: Colors.grey),
          ),
        );
    }
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
    component.x = _componentHorizontalPadding;
    component.width = _availableComponentWidth();
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
  final colorValue = component.properties['color'] ??
    component.properties['textColor'] ??
    0xFF000000;
  final fontFamily = component.properties['fontFamily'] is String
    ? component.properties['fontFamily'] as String
    : null;
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

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: Color(colorValue),
    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: letterSpacing,
    height: height,
    fontFamily: fontFamily,
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
        _applyFullWidthLayout(target!);
      }
      _editingComponentId = null;
    });

    _updateCanvasSize();
  }

  Widget _buildInlineTextEditorField(BuilderComponent component) {
    _inlineEditorController ??=
        TextEditingController(text: component.properties['text']?.toString() ?? '');

    final isTextBox = component.type == ComponentType.textBox;

    final editor = TextField(
      controller: _inlineEditorController,
      focusNode: _inlineEditorFocusNode,
      style: _resolveTextStyle(component),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
      ),
      keyboardType: TextInputType.multiline,
      textAlign: _resolveTextAlign(component),
      maxLines: null,
      autofocus: true,
      cursorColor: const Color(0xFF673AB7),
      onChanged: (value) {
        setState(() {
          component.properties['text'] = value;
          final measuredHeight = _calculateTextComponentHeight(component, value);
          component.properties['minTextHeight'] = measuredHeight;
          final bool autoHeight = component.properties['autoHeight'] != false;
          if (autoHeight) {
            component.height = measuredHeight;
          } else {
            component.height = math.max(component.height, measuredHeight);
          }
        });
        _updateCanvasSize();
      },
      onSubmitted: (_) => _stopInlineEditing(save: true),
    );

    final paddingValue = component.properties['padding'];
    final double padding = paddingValue is num
        ? paddingValue.toDouble()
        : (isTextBox ? 12.0 : 8.0);

    final backgroundValue = component.properties['backgroundColor'];
    Color? backgroundColor;
    if (backgroundValue is int) {
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

    final decoration = (backgroundColor != null || borderWidth > 0)
        ? BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: borderWidth > 0
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
          )
        : null;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: decoration,
      child: editor,
    );
  }

  Widget _buildStyledTextComponent(BuilderComponent component, {required bool isTextBox}) {
    final String textValue = component.properties['text']?.toString() ??
        (isTextBox ? 'Text Box Content' : 'Text Label');
    final paddingValue = component.properties['padding'];
    final double padding = paddingValue is num
        ? paddingValue.toDouble()
        : (isTextBox ? 12.0 : 8.0);

    final backgroundValue = component.properties['backgroundColor'];
    Color? backgroundColor;
    if (backgroundValue is int) {
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

    final decoration = (backgroundColor != null || borderWidth > 0)
        ? BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: borderWidth > 0
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
          )
        : null;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: decoration,
      child: Text(
        textValue,
        style: _resolveTextStyle(component),
        softWrap: true,
        textAlign: _resolveTextAlign(component),
        maxLines: maxLinesValue,
        overflow: maxLinesValue != null ? TextOverflow.ellipsis : TextOverflow.visible,
      ),
    );
  }

  Widget _buildPropertiesButton(BuilderComponent component) {
    return PopupMenuButton<String>(
      tooltip: 'Component Properties',
      elevation: 6,
      offset: const Offset(0, 6),
      constraints: const BoxConstraints(minWidth: 200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => _handlePropertySelection(component, value),
      itemBuilder: (context) => _propertyMenuItemsForComponent(component),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF673AB7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.tune, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Properties',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _propertyMenuItemsForComponent(BuilderComponent component) {
    final items = <PopupMenuEntry<String>>[];

    if (_canInlineEdit(component)) {
      final bool autoHeightEnabled = component.properties['autoHeight'] != false;
      items.add(
        PopupMenuItem<String>(
          value: 'edit_text',
          child: Row(
            children: const [
              Icon(Icons.text_fields, size: 18),
              SizedBox(width: 8),
              Text('Edit text inline'),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'font_increase',
          child: Row(
            children: const [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text('Increase font size'),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'font_decrease',
          child: Row(
            children: const [
              Icon(Icons.remove, size: 18),
              SizedBox(width: 8),
              Text('Decrease font size'),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'toggle_bold',
          child: Row(
            children: const [
              Icon(Icons.format_bold, size: 18),
              SizedBox(width: 8),
              Text('Toggle bold'),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'text_color',
          child: Row(
            children: [
              Icon(
                Icons.color_lens,
                size: 18,
                color: Color(
                  component.properties['color'] is int
                      ? component.properties['color'] as int
                      : component.properties['textColor'] is int
                          ? component.properties['textColor'] as int
                          : 0xFF000000,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Change text color'),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'text_style',
          child: Row(
            children: const [
              Icon(Icons.format_size, size: 18),
              SizedBox(width: 8),
              Text('Typography & effects'),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'text_align',
          child: Row(
            children: const [
              Icon(Icons.format_align_left, size: 18),
              SizedBox(width: 8),
              Text('Text alignment'),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'background_style',
          child: Row(
            children: const [
              Icon(Icons.layers, size: 18),
              SizedBox(width: 8),
              Text('Background & border'),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'toggle_auto_height',
          child: Row(
            children: [
              Icon(autoHeightEnabled ? Icons.height : Icons.unfold_more, size: 18),
              const SizedBox(width: 8),
              Text(autoHeightEnabled ? 'Lock height' : 'Auto-fit height'),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'reset_height',
          child: Row(
            children: const [
              Icon(Icons.refresh, size: 18),
              SizedBox(width: 8),
              Text('Reset height to fit'),
            ],
          ),
        ),
      );
    }

    if (component.type == ComponentType.dateContainer) {
      if (items.isNotEmpty) {
        items.add(const PopupMenuDivider());
      }
      items.add(
        PopupMenuItem<String>(
          value: 'change_date',
          child: Row(
            children: const [
              Icon(Icons.calendar_today, size: 18),
              SizedBox(width: 8),
              Text('Change date'),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('No configurable properties yet'),
        ),
      );
    }

    return items;
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
    const colorOptions = <int>[
      0xFF000000,
      0xFF1F2933,
      0xFF4B5563,
      0xFF6B7280,
      0xFF9CA3AF,
      0xFFFFFFFF,
      0xFFEF4444,
      0xFFF59E0B,
      0xFF10B981,
      0xFF3B82F6,
      0xFF8B5CF6,
      0xFFEC4899,
    ];

    final selectedColor = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick text color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colorOptions.map((colorValue) {
            final isSelected = component.properties['color'] == colorValue;
            return GestureDetector(
              onTap: () => Navigator.pop(context, colorValue),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(colorValue),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF673AB7) : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (!mounted || selectedColor == null) {
      return;
    }

    setState(() {
      component.properties['color'] = selectedColor;
      component.properties['textColor'] = selectedColor;
      _applyFullWidthLayout(component);
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

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Typography & effects'),
            content: SingleChildScrollView(
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
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop<Map<String, dynamic>>(context, {
                  'fontSize': fontSize,
                  'fontFamily': fontFamily,
                  'isBold': isBold,
                  'isItalic': isItalic,
                  'isUnderline': isUnderline,
                  'letterSpacing': letterSpacing,
                  'lineHeight': lineHeight,
                }),
                child: const Text('Apply'),
              ),
            ],
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

    final String? selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Text alignment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ...options.map((option) {
              final bool selected = current == option['value'];
              return ListTile(
                leading: Icon(option['icon'] as IconData,
                    color: selected ? const Color(0xFF673AB7) : null),
                title: Text(option['label'] as String),
                trailing: selected ? const Icon(Icons.check, color: Color(0xFF673AB7)) : null,
                onTap: () => Navigator.pop(context, option['value'] as String),
              );
            }).toList(),
            const SizedBox(height: 12),
          ],
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
    const colorOptions = <int>[
      0x00000000,
      0xFFFFFFFF,
      0xFFF7F7F7,
      0xFFE3F2FD,
      0xFFE8F5E9,
      0xFFFFF3E0,
      0xFFFCE4EC,
      0xFF1F2933,
      0xFF4B5563,
      0xFF8B5CF6,
      0xFF3B82F6,
      0xFF10B981,
      0xFFF59E0B,
      0xFFEF4444,
    ];

    int? backgroundColor = component.properties['backgroundColor'] is int
        ? component.properties['backgroundColor'] as int
        : null;
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Background & border'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Background color'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colorOptions.map((colorValue) {
                      final bool isSelected = backgroundColor == colorValue;
                      return GestureDetector(
                        onTap: () => setDialogState(() => backgroundColor = colorValue),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF673AB7) : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: colorValue == 0x00000000
                              ? const Center(child: Icon(Icons.disabled_by_default_outlined, size: 20))
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: showBorder,
                    onChanged: (value) => setDialogState(() => showBorder = value),
                    title: const Text('Show border'),
                  ),
                  if (showBorder) ...[
                    const SizedBox(height: 8),
                    const Text('Border width'),
                    Slider(
                      value: borderWidth.clamp(0.0, 12.0),
                      min: 0,
                      max: 12,
                      divisions: 12,
                      label: borderWidth.toStringAsFixed(1),
                      onChanged: (value) => setDialogState(() => borderWidth = value),
                    ),
                    const SizedBox(height: 12),
                    const Text('Border color'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colorOptions.map((colorValue) {
                        final bool isSelected = borderColor == colorValue;
                        return GestureDetector(
                          onTap: () => setDialogState(() => borderColor = colorValue),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF673AB7) : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Corner radius'),
                  Slider(
                    value: borderRadius.clamp(0.0, 48.0),
                    min: 0,
                    max: 48,
                    divisions: 24,
                    label: borderRadius.toStringAsFixed(0),
                    onChanged: (value) => setDialogState(() => borderRadius = value),
                  ),
                  const SizedBox(height: 12),
                  const Text('Padding'),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop<Map<String, dynamic>>(context, {
                    'backgroundColor': backgroundColor,
                    'showBorder': showBorder,
                    'borderWidth': showBorder ? borderWidth : 0.0,
                    'borderColor': showBorder ? borderColor : component.properties['borderColor'],
                    'borderRadius': borderRadius,
                    'padding': padding,
                  });
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      component.properties.addAll(result);
      if (result['showBorder'] != true) {
        component.properties['borderWidth'] = 0.0;
      }
      _applyFullWidthLayout(component);
    });
    _updateCanvasSize();
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
          'fontFamily': 'Roboto',
          'letterSpacing': 0.0,
          'lineHeight': 1.35,
          'textAlign': 'left',
          'padding': 12.0,
          'borderRadius': 12.0,
          'borderWidth': 1.0,
          'borderColor': 0xFFE0E0E0,
          'showBorder': true,
          'backgroundColor': 0xFFF7F7F7,
          'autoHeight': true,
        };
      case ComponentType.dateContainer:
        return {'selectedDate': DateTime.now().millisecondsSinceEpoch};
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

  Widget _buildCompactEmojiTextField(TextEditingController controller, String hint) {
    bool showEmojiPicker = false;
    
    return StatefulBuilder(
      builder: (context, setFieldState) => Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.emoji_emotions, color: Colors.white70, size: 20),
                onPressed: () {
                  setFieldState(() {
                    showEmojiPicker = !showEmojiPicker;
                  });
                },
              ),
            ),
            style: const TextStyle(color: Colors.white),
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
    final List<String> popularEmojis = [
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

  void _showBackgroundColorPicker() {
    final colors = [
      Colors.white, Colors.grey.shade100, Colors.grey.shade200,
      Colors.red.shade50, Colors.orange.shade50, Colors.yellow.shade50,
      Colors.green.shade50, Colors.blue.shade50, Colors.purple.shade50,
      Colors.red, Colors.orange, Colors.yellow,
      Colors.green, Colors.blue, Colors.purple,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) => GestureDetector(
            onTap: () {
              setState(() {
                canvasBackgroundColor = color;
              });
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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

  Future<void> _saveTemplate() async {
    if (_templateNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Prepare template data
      final templateData = {
        'templateName': _templateNameController.text.trim(),
        'templateType': 'CUSTOM',
        'isActive': true,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'canvasBackgroundColor': canvasBackgroundColor.value,
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
}