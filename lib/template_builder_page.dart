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
  double canvasHeight = 600;
  Color canvasBackgroundColor = Colors.white;
  
  // Template properties
  final TextEditingController _templateNameController = TextEditingController();
  List<BuilderComponent> _canvasComponents = [];
  String? _selectedComponentId;
  bool _isLoading = false;
  
  // Auto-alignment
  bool _autoAlignEnabled = true;
  
  // Dynamic canvas sizing
  static const double minCanvasWidth = 400;
  static const double minCanvasHeight = 600;
  static const double canvasPadding = 50; // Extra space around components

  @override
  void initState() {
    super.initState();
    _templateNameController.text = 'My Custom Template';
  }

  @override
  void dispose() {
    _templateNameController.dispose();
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
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: _buildCanvas(),
                            ),
                          ),
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
                              scrollDirection: Axis.vertical,
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: _buildCanvas(),
                                  ),
                                ),
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
    return Container(
      width: canvasWidth,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DragTarget<ComponentType>(
          onAcceptWithDetails: (details) {
            _addComponentToCanvas(details.data, details.offset);
          },
          builder: (context, candidateData, rejectedData) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Canvas Background
                Positioned.fill(
                  child: Container(color: canvasBackgroundColor),
                ),
                
                // Components
                ..._canvasComponents.map((component) => _buildCanvasComponent(component)).toList(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCanvasComponent(BuilderComponent component) {
    final isSelected = _selectedComponentId == component.id;
    
    return Positioned(
      left: component.x,
      top: component.y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // Allow components to be dragged beyond current canvas bounds
            component.x = (component.x + details.delta.dx).clamp(0.0, double.infinity);
            component.y = (component.y + details.delta.dy).clamp(0.0, double.infinity);
          });
          _updateCanvasSize(); // Expand canvas if needed
        },
        onPanEnd: (_) {
          if (_autoAlignEnabled) {
            _performAutoAlignment();
          }
        },
        onTap: () {
          setState(() {
            _selectedComponentId = isSelected ? null : component.id;
          });
        },
        child: Container(
          width: component.width,
          height: component.height,
          decoration: BoxDecoration(
            border: isSelected ? Border.all(color: const Color(0xFF673AB7), width: 2) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // Component Content
              _buildComponentContent(component),
              
              // Selection Controls
              if (isSelected) ...[
                // Edit Button
                Positioned(
                  top: -8,
                  right: -8,
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
                  top: -8,
                  left: -8,
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
                  bottom: -8,
                  right: -8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF673AB7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.drag_indicator, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentContent(BuilderComponent component) {
    switch (component.type) {
      case ComponentType.textLabel:
        return Container(
          padding: const EdgeInsets.all(8),
          child: Text(
            component.properties['text'] ?? 'Text Label',
            style: TextStyle(
              fontSize: (component.properties['fontSize'] ?? 14).toDouble(),
              fontWeight: component.properties['isBold'] == true ? FontWeight.bold : FontWeight.normal,
              color: Color(component.properties['color'] ?? 0xFF000000),
            ),
          ),
        );
      
      case ComponentType.textBox:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            component.properties['text'] ?? 'Text Box Content',
            style: TextStyle(
              fontSize: (component.properties['fontSize'] ?? 12).toDouble(),
              color: Color(component.properties['color'] ?? 0xFF000000),
            ),
          ),
        );
      
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

  void _addComponentToCanvas(ComponentType type, Offset globalOffset) {
    // Convert global offset to canvas-relative offset
    final RenderBox? canvasBox = context.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;
    
    final localOffset = canvasBox.globalToLocal(globalOffset);
    
    // Adjust for canvas position within the widget
    final canvasOffset = Offset(
      (localOffset.dx - 300).clamp(0.0, canvasWidth - 100), // 300 is approximate left panel width
      (localOffset.dy - 100).clamp(0.0, canvasHeight - 50), // 100 is approximate top offset
    );
    
    final component = BuilderComponent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      x: canvasOffset.dx,
      y: canvasOffset.dy,
      width: 120,
      height: 40,
      properties: _getDefaultProperties(type),
    );
    
    setState(() {
      _canvasComponents.add(component);
    });
    _updateCanvasSize();
  }

  void _addComponentToCanvasMobile(ComponentType type) {
    // Find an available position to avoid overlapping
    final componentWidth = 120.0;
    final componentHeight = 40.0;
    final spacing = 15.0;
    
    double x = 20.0; // Start from left margin
    double y = 20.0; // Start from top margin
    
    // If there are existing components, place new one below the bottom-most component
    if (_canvasComponents.isNotEmpty) {
      double maxY = 0;
      for (final comp in _canvasComponents) {
        final bottomEdge = comp.y + comp.height;
        if (bottomEdge > maxY) maxY = bottomEdge;
      }
      y = maxY + spacing;
    }
    
    final component = BuilderComponent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      x: x,
      y: y,
      width: componentWidth,
      height: componentHeight,
      properties: _getDefaultProperties(type),
    );
    
    setState(() {
      _canvasComponents.add(component);
    });
    _updateCanvasSize();
  }

  Map<String, dynamic> _getDefaultProperties(ComponentType type) {
    switch (type) {
      case ComponentType.textLabel:
        return {'text': 'Text Label', 'fontSize': 14, 'color': 0xFF000000, 'isBold': false};
      case ComponentType.textBox:
        return {'text': 'Text Box Content', 'fontSize': 12, 'color': 0xFF000000};
      case ComponentType.dateContainer:
        return {'selectedDate': DateTime.now().millisecondsSinceEpoch};
      default:
        return {};
    }
  }

  void _editComponent(BuilderComponent component) {
    if (component.type == ComponentType.textLabel || component.type == ComponentType.textBox) {
      _showInlineTextEditor(component);
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
    setState(() {
      _canvasComponents.removeWhere((c) => c.id == componentId);
      if (_selectedComponentId == componentId) {
        _selectedComponentId = null;
      }
    });
  }

  void _clearCanvas() {
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
    if (_canvasComponents.isEmpty) return;

    // Calculate the bounds of all components
    double maxX = 0;
    double maxY = 0;
    
    for (final component in _canvasComponents) {
      final rightEdge = component.x + component.width;
      final bottomEdge = component.y + component.height;
      
      if (rightEdge > maxX) maxX = rightEdge;
      if (bottomEdge > maxY) maxY = bottomEdge;
    }
    
    // Add padding and ensure minimum size
    final newWidth = math.max(minCanvasWidth, maxX + canvasPadding);
    final newHeight = math.max(minCanvasHeight, maxY + canvasPadding);
    
    // Only update if size needs to increase
    if (newWidth > canvasWidth || newHeight > canvasHeight) {
      setState(() {
        canvasWidth = newWidth;
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
              });
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
    if (_canvasComponents.length < 2) return;

    // Detect layout pattern and apply alignment
    final isColumnLayout = _detectColumnLayout();
    
    if (isColumnLayout) {
      _alignComponentsInColumn();
    } else {
      _alignComponentsInRow();
    }
    
    // Update canvas size after alignment
    _updateCanvasSize();
  }

  void _performManualAlignment() {
    _performAutoAlignment();
  }

  bool _detectColumnLayout() {
    if (_canvasComponents.length < 2) return false;
    
    // Calculate average vertical spacing vs horizontal spacing
    double totalVerticalSpan = 0;
    double totalHorizontalSpan = 0;
    
    for (int i = 0; i < _canvasComponents.length; i++) {
      for (int j = i + 1; j < _canvasComponents.length; j++) {
        final comp1 = _canvasComponents[i];
        final comp2 = _canvasComponents[j];
        
        totalVerticalSpan += (comp1.y - comp2.y).abs();
        totalHorizontalSpan += (comp1.x - comp2.x).abs();
      }
    }
    
    return totalVerticalSpan > totalHorizontalSpan;
  }

  void _alignComponentsInColumn() {
    _canvasComponents.sort((a, b) => a.y.compareTo(b.y));
    
    const double spacing = 15.0;
    double currentY = 20.0;
    final centerX = canvasWidth / 2;
    
    for (final component in _canvasComponents) {
      setState(() {
        component.x = centerX - (component.width / 2);
        component.y = currentY;
      });
      currentY += component.height + spacing;
    }
  }

  void _alignComponentsInRow() {
    _canvasComponents.sort((a, b) => a.x.compareTo(b.x));
    
    const double spacing = 15.0;
    double currentX = 20.0;
    final centerY = canvasHeight / 2;
    
    for (final component in _canvasComponents) {
      setState(() {
        component.x = currentX;
        component.y = centerY - (component.height / 2);
      });
      currentX += component.width + spacing;
    }
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