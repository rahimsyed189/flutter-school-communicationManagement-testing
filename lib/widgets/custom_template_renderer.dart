import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'draggable_template_components.dart';

class CustomTemplateRenderer extends StatelessWidget {
  final Map<String, dynamic> templateData;
  final VoidCallback? onTap;
  final Function(String)? onReaction;

  const CustomTemplateRenderer({
    Key? key,
    required this.templateData,
    this.onTap,
    this.onReaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final components = (templateData['components'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final canvasWidth = (templateData['canvasWidth'] is int) 
        ? (templateData['canvasWidth'] as int).toDouble()
        : templateData['canvasWidth']?.toDouble() ?? 350.0;
    final canvasHeight = (templateData['canvasHeight'] is int) 
        ? (templateData['canvasHeight'] as int).toDouble()
        : templateData['canvasHeight']?.toDouble() ?? 500.0;
    final templateName = templateData['name'] ?? templateData['templateName'] ?? 'Custom Template';
    
    // Canvas styling properties
    final canvasBackgroundColor = Color(templateData['canvasBackgroundColor'] ?? 0xFFFFFFFF);
    final canvasBackgroundMode = templateData['canvasBackgroundMode'] ?? 'solid';
    final canvasBackgroundGradient = templateData['canvasBackgroundGradient'];
    
    // Canvas border properties - Always show border with proper defaults
    final canvasBorderColor = Color(templateData['canvasBorderColor'] ?? 0xFF9CA3AF); // Gray-400 for visibility
    final canvasBorderWidth = (templateData['canvasBorderWidth'] as num?)?.toDouble() ?? 2.0; // More visible 2px default
    final canvasBorderRadius = (templateData['canvasBorderRadius'] as num?)?.toDouble() ?? 12.0; // Rounded corners
    
    // Debug log
    print('🎨 Canvas Border Values: color=0x${canvasBorderColor.value.toRadixString(16)}, width=$canvasBorderWidth, radius=$canvasBorderRadius');

    // Create canvas decoration
    Decoration canvasDecoration;
    if (canvasBackgroundMode == 'gradient' && canvasBackgroundGradient != null) {
      // Gradient background
      final gradientData = canvasBackgroundGradient as Map<String, dynamic>;
      final colors = (gradientData['colors'] as List<dynamic>?)
          ?.map((color) => Color(color as int))
          .toList() ?? [canvasBackgroundColor, canvasBackgroundColor];
      final begin = gradientData['begin'] as Map<String, dynamic>?;
      final end = gradientData['end'] as Map<String, dynamic>?;
      
      canvasDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: begin != null 
              ? Alignment(begin['x']?.toDouble() ?? -1.0, begin['y']?.toDouble() ?? -1.0)
              : Alignment.centerLeft,
          end: end != null 
              ? Alignment(end['x']?.toDouble() ?? 1.0, end['y']?.toDouble() ?? 1.0)
              : Alignment.centerRight,
          stops: gradientData['stops'] != null 
              ? (gradientData['stops'] as List<dynamic>).map((s) => (s as num).toDouble()).toList()
              : null,
        ),
        borderRadius: BorderRadius.circular(canvasBorderRadius),
        border: canvasBorderWidth > 0 
            ? Border.all(color: canvasBorderColor, width: canvasBorderWidth)
            : null,
      );
    } else {
      // Solid background
      canvasDecoration = BoxDecoration(
        color: canvasBackgroundColor,
        borderRadius: BorderRadius.circular(canvasBorderRadius),
        border: canvasBorderWidth > 0 
            ? Border.all(color: canvasBorderColor, width: canvasBorderWidth)
            : null,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Template Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF673AB7), Color(0xFF9C27B0)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.build_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            templateName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Custom Template',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'CUSTOM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Template Content
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Template Preview (scaled down)
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Transform.scale(
                          scale: 0.6, // Scale down the template for preview
                          child: Container(
                            width: canvasWidth,
                            height: canvasHeight,
                            decoration: canvasDecoration,
                            child: Stack(
                              children: components.map<Widget>((componentData) {
                                try {
                                  final component = DraggableComponent.fromJson(componentData);
                                  return Positioned(
                                    left: component.x,
                                    top: component.y,
                                    child: component.buildWidget(),
                                  );
                                } catch (e) {
                                  // If there's an error rendering a component, show a placeholder
                                  return Positioned(
                                    left: componentData['x']?.toDouble() ?? 0,
                                    top: componentData['y']?.toDouble() ?? 0,
                                    child: Container(
                                      width: componentData['width']?.toDouble() ?? 50,
                                      height: componentData['height']?.toDouble() ?? 50,
                                      color: Colors.red.withOpacity(0.3),
                                      child: const Icon(Icons.error, color: Colors.red),
                                    ),
                                  );
                                }
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Template Info
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Components: ${components.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (templateData['createdAt'] != null)
                                Text(
                                  'Created: ${DateFormat('MMM dd, yyyy').format((templateData['createdAt'] as Timestamp).toDate())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Action buttons could be added here
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Template Post Widget - for posting custom templates
class CustomTemplatePost extends StatefulWidget {
  final Map<String, dynamic> templateData;
  final String currentUserId;
  final String currentUserRole;

  const CustomTemplatePost({
    Key? key,
    required this.templateData,
    required this.currentUserId,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  State<CustomTemplatePost> createState() => _CustomTemplatePostState();
}

class _CustomTemplatePostState extends State<CustomTemplatePost> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.templateData['name'] ?? 'Custom Announcement';
  }

  String _extractComponentType(String typeString) {
    // Handle ComponentType.enumName format
    if (typeString.startsWith('ComponentType.')) {
      return typeString.substring('ComponentType.'.length);
    }
    return typeString;
  }

  TextAlign _getTextAlignment(String alignment) {
    switch (alignment) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Template Preview
          _buildTemplatePreview(),
          const SizedBox(height: 20),
          // Post Form
          _buildPostForm(),
          const SizedBox(height: 20),
          // Post Button
          _buildPostButton(),
        ],
      ),
    );
  }

  Widget _buildTemplatePreview() {
    final components = (widget.templateData['components'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final canvasWidth = (widget.templateData['canvasWidth'] is int) 
        ? (widget.templateData['canvasWidth'] as int).toDouble()
        : widget.templateData['canvasWidth']?.toDouble() ?? 350.0;
    final canvasHeight = (widget.templateData['canvasHeight'] is int) 
        ? (widget.templateData['canvasHeight'] as int).toDouble()
        : widget.templateData['canvasHeight']?.toDouble() ?? 500.0;

    // Show the exact canvas as it appears in the builder - no extra headers or containers
    return Container(
      width: canvasWidth,
      height: canvasHeight,
      decoration: BoxDecoration(
        color: Color(widget.templateData['canvasBackgroundColor'] ?? Colors.white.value),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: components.map<Widget>((componentData) {
            try {
              // Extract component data with safe type casting
              final x = (componentData['position']?['x'] is int) 
                  ? (componentData['position']['x'] as int).toDouble()
                  : componentData['position']?['x']?.toDouble() ?? 0.0;
              final y = (componentData['position']?['y'] is int) 
                  ? (componentData['position']['y'] as int).toDouble()
                  : componentData['position']?['y']?.toDouble() ?? 0.0;
              final width = (componentData['size']?['width'] is int) 
                  ? (componentData['size']['width'] as int).toDouble()
                  : componentData['size']?['width']?.toDouble() ?? 120.0;
              final height = (componentData['size']?['height'] is int) 
                  ? (componentData['size']['height'] as int).toDouble()
                  : componentData['size']?['height']?.toDouble() ?? 40.0;
              final properties = componentData['properties'] ?? {};
              final type = _extractComponentType(componentData['type']);
              
              // Build component widget directly based on type
              Widget componentWidget;
              
              switch (type) {
                case 'textLabel':
                  componentWidget = Container(
                    width: width,
                    height: height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(properties['backgroundColor'] ?? Colors.transparent.value),
                      borderRadius: BorderRadius.circular(
                        (properties['borderRadius'] is int) 
                          ? (properties['borderRadius'] as int).toDouble()
                          : properties['borderRadius']?.toDouble() ?? 0.0
                      ),
                      border: properties['showBorder'] == true 
                        ? Border.all(
                            color: Color(properties['borderColor'] ?? Colors.grey.value),
                            width: (properties['borderWidth'] is int) 
                              ? (properties['borderWidth'] as int).toDouble()
                              : properties['borderWidth']?.toDouble() ?? 1.0,
                          )
                        : null,
                    ),
                    child: Text(
                      properties['text'] ?? 'Text Label',
                      style: TextStyle(
                        fontSize: (properties['fontSize'] is int) 
                          ? (properties['fontSize'] as int).toDouble()
                          : properties['fontSize']?.toDouble() ?? 16.0,
                        fontWeight: properties['isBold'] == true ? FontWeight.bold : FontWeight.normal,
                        fontStyle: properties['isItalic'] == true ? FontStyle.italic : FontStyle.normal,
                        color: Color(properties['textColor'] ?? Colors.black.value),
                      ),
                      textAlign: _getTextAlignment(properties['textAlign'] ?? 'center'),
                      overflow: TextOverflow.ellipsis,
                      maxLines: properties['maxLines'] ?? 1,
                    ),
                  );
                  break;
                  
                case 'dateField':
                  componentWidget = Container(
                    width: width,
                    height: height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(properties['backgroundColor'] ?? Colors.blue.shade50.value),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Text(
                      properties['selectedDate'] ?? 'Select Date',
                      style: TextStyle(
                        fontSize: (properties['fontSize'] is int) 
                          ? (properties['fontSize'] as int).toDouble()
                          : properties['fontSize']?.toDouble() ?? 14.0,
                        color: Color(properties['textColor'] ?? Colors.blue.shade800.value),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                  break;
                  
                default:
                  componentWidget = Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Center(
                      child: Text(
                        type.toUpperCase(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  );
              }
              
              return Positioned(
                left: x,
                top: y,
                child: componentWidget,
              );
            } catch (e) {
              // Fallback rendering for failed components with safe type casting
              final x = (componentData['position']?['x'] is int) 
                  ? (componentData['position']['x'] as int).toDouble()
                  : componentData['position']?['x']?.toDouble() ?? 0.0;
              final y = (componentData['position']?['y'] is int) 
                  ? (componentData['position']['y'] as int).toDouble()
                  : componentData['position']?['y']?.toDouble() ?? 0.0;
              final width = (componentData['size']?['width'] is int) 
                  ? (componentData['size']['width'] as int).toDouble()
                  : componentData['size']?['width']?.toDouble() ?? 50.0;
              final height = (componentData['size']?['height'] is int) 
                  ? (componentData['size']['height'] as int).toDouble()
                  : componentData['size']?['height']?.toDouble() ?? 50.0;
              
              return Positioned(
                left: x,
                top: y,
                child: Container(
                  width: width,
                  height: height,
                  color: Colors.red.withOpacity(0.3),
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.red, size: 16),
                  ),
                ),
              );
            }
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPostForm() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Post Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Announcement Title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.description),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildPostButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _postTemplate,
        icon: _isLoading 
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
              )
            : const Icon(Icons.send),
        label: Text(_isLoading ? 'Posting...' : 'Post Announcement'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF673AB7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _postTemplate() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate template data before posting
      if (widget.templateData['components'] == null || 
          (widget.templateData['components'] as List).isEmpty) {
        throw Exception('Template has no components to display');
      }

      final postData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'templateType': 'custom',
        'templateData': widget.templateData,
        'postedBy': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isActive': true,
        'reactions': {},
        'viewCount': 0,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('communications')
          .add(postData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom template posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form after posting
      _titleController.clear();
      _descriptionController.clear();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting template: $e'),
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

// Custom Template Renderer for Announcements Page
class CustomAnnouncementRenderer extends StatelessWidget {
  final Map<String, dynamic> templateData;
  final Map<String, dynamic> announcementData;
  final Function(String)? onReaction;

  const CustomAnnouncementRenderer({
    Key? key,
    required this.templateData,
    required this.announcementData,
    this.onReaction,
  }) : super(key: key);

  static String _extractComponentType(String typeString) {
    // Handle ComponentType.enumName format
    if (typeString.startsWith('ComponentType.')) {
      return typeString.substring('ComponentType.'.length);
    }
    return typeString;
  }

  static TextAlign _getTextAlignment(String alignment) {
    switch (alignment) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }

  // Helper method to build TextStyle with Google Fonts support
  static TextStyle _buildTextStyle({
    required double fontSize,
    String? fontFamily,
    required bool isBold,
    required bool isItalic,
    required bool isUnderline,
    required Color color,
  }) {
    // Map of supported Google Fonts
    final supportedFonts = {
      'Roboto': GoogleFonts.roboto,
      'Poppins': GoogleFonts.poppins,
      'Lato': GoogleFonts.lato,
      'Nunito': GoogleFonts.nunito,
      'Montserrat': GoogleFonts.montserrat,
      'Open Sans': GoogleFonts.openSans,
      'Merriweather': GoogleFonts.merriweather,
    };

    // Get the font function or use default
    final fontFunction = supportedFonts[fontFamily];
    
    if (fontFunction != null) {
      // Use Google Fonts
      return fontFunction(
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
        color: color,
      );
    } else {
      // Fallback to regular TextStyle with fontFamily string
      return TextStyle(
        fontSize: fontSize,
        fontFamily: fontFamily,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
        color: color,
      );
    }
  }

  static TextAlign _parseTextAlign(String? alignment) {
    switch (alignment?.toLowerCase()) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
        return TextAlign.center;
      case 'justify':
        return TextAlign.justify;
      case 'start':
        return TextAlign.start;
      case 'end':
        return TextAlign.end;
      default:
        return TextAlign.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawComponents = (templateData['components'] as List<dynamic>?) ?? const [];
    final components = rawComponents.whereType<Map<String, dynamic>>().toList();
    final double canvasWidth = _asDouble(templateData['canvasWidth'], 350.0);
    final double canvasHeight = _asDouble(templateData['canvasHeight'], 500.0);
    final templateName = templateData['name'] ?? templateData['templateName'] ?? 'Custom Template';
    final canvasColor = Color(_tryColor(templateData['canvasBackgroundColor']) ?? Colors.white.value);
    final canvasBackgroundMode = templateData['canvasBackgroundMode'] ?? 'solid';
    final canvasBackgroundGradient = templateData['canvasBackgroundGradient'] as Map<String, dynamic>?;
    
    // Canvas border properties
    final canvasBorderColor = Color(_tryColor(templateData['canvasBorderColor']) ?? 0xFF9CA3AF);
    final canvasBorderWidth = _asDouble(templateData['canvasBorderWidth'], 2.0);
    final canvasBorderRadius = _asDouble(templateData['canvasBorderRadius'], 12.0);
    
    // Debug log for announcements rendering
    print('🎨 Announcement Canvas Border: color=0x${canvasBorderColor.value.toRadixString(16)}, width=$canvasBorderWidth, radius=$canvasBorderRadius');
    
    // Create canvas decoration with gradient support
    BoxDecoration canvasDecoration;
    if (canvasBackgroundMode == 'gradient' && canvasBackgroundGradient != null) {
      // Build gradient from saved data
      LinearGradient? gradient;
      try {
        final colors = (canvasBackgroundGradient['colors'] as List<dynamic>?)?.map((c) => Color(_tryColor(c) ?? Colors.white.value)).toList();
        final beginData = canvasBackgroundGradient['begin'] as Map<String, dynamic>?;
        final endData = canvasBackgroundGradient['end'] as Map<String, dynamic>?;
        
        if (colors != null && colors.length >= 2) {
          final begin = beginData != null ? Alignment(beginData['x']?.toDouble() ?? -1.0, beginData['y']?.toDouble() ?? -1.0) : Alignment.centerLeft;
          final end = endData != null ? Alignment(endData['x']?.toDouble() ?? 1.0, endData['y']?.toDouble() ?? 1.0) : Alignment.centerRight;
          final stops = (canvasBackgroundGradient['stops'] as List<dynamic>?)?.map((s) => s?.toDouble() ?? 0.0).toList()?.cast<double>();
          
          gradient = LinearGradient(
            colors: colors,
            begin: begin,
            end: end,
            stops: stops,
          );
        }
      } catch (e) {
        // Error creating canvas gradient
      }
      
      canvasDecoration = BoxDecoration(
        gradient: gradient,
        color: gradient == null ? canvasColor : null,
        borderRadius: BorderRadius.circular(canvasBorderRadius),
        border: canvasBorderWidth > 0 
            ? Border.all(color: canvasBorderColor, width: canvasBorderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );
    } else {
      canvasDecoration = BoxDecoration(
        color: canvasColor,
        borderRadius: BorderRadius.circular(canvasBorderRadius),
        border: canvasBorderWidth > 0 
            ? Border.all(color: canvasBorderColor, width: canvasBorderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Container(
          width: canvasWidth,
          height: canvasHeight,
          decoration: canvasDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: components.isEmpty
                  ? [
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            'Template has no components',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ]
                  : components.map(_buildComponentWidget).toList(),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildComponentWidget(Map<String, dynamic> componentData) {
    try {
      final position = componentData['position'] as Map<String, dynamic>?;
      final size = componentData['size'] as Map<String, dynamic>?;
      final properties = componentData['properties'] as Map<String, dynamic>?;
      final type = componentData['type']?.toString() ?? '';
      
      // Handle BOTH data structures:
      // 1. _postTemplate format: position: {'dx': x, 'dy': y}, properties spread directly
      // 2. _saveTemplate format: position: {'x': x, 'y': y}, properties: {...}
      
      final double x = _asDouble(
        position?['dx'] ?? position?['x'] ?? componentData['x'], 0);
      final double y = _asDouble(
        position?['dy'] ?? position?['y'] ?? componentData['y'], 0);
      final double width = _asDouble(
        size?['width'] ?? componentData['width'], 100);
      final double height = _asDouble(
        size?['height'] ?? componentData['height'], 50);

      // Create unified data structure by merging properties
      final unifiedData = Map<String, dynamic>.from(componentData);
      if (properties != null) {
        // If properties are nested, merge them into the main data
        unifiedData.addAll(properties);
      }

      Widget componentWidget;

      // Direct component type matching based on actual saved types
      if (type == 'ComponentType.textBox' || type.contains('textBox')) {
        componentWidget = _buildTextBoxWidget(unifiedData, width, height);
      } else if (type == 'ComponentType.textLabel' || type.contains('textLabel')) {
        componentWidget = _buildTextLabelWidget(unifiedData, width, height);
      } else if (type == 'ComponentType.image' || type.contains('image')) {
        componentWidget = _buildImageWidget(unifiedData, width, height);
      } else if (type == 'ComponentType.gradientDivider' || type.contains('gradientDivider') || type.contains('divider')) {
        componentWidget = _buildGradientDividerWidget(unifiedData, width, height);
      } else if (type == 'ComponentType.multipleChoice' || type.contains('multipleChoice')) {
        componentWidget = _buildMultipleChoiceWidget(unifiedData, width, height);
      } else if (type == 'ComponentType.shape' || type.contains('shape')) {
        componentWidget = _buildShapeWidget(unifiedData, width, height);
      } else if (type == 'ComponentType.container' || type.contains('container')) {
        componentWidget = _buildContainerWidget(unifiedData, width, height);
      } else {
        // Universal fallback - try to render any component with its formatting
        componentWidget = _buildUniversalWidget(unifiedData, width, height, type);
      }

      return Positioned(
        left: x,
        top: y,
        child: componentWidget,
      );
    } catch (e) {
      // Extract basic positioning even from malformed data
      final position = componentData['position'] as Map<String, dynamic>?;
      final size = componentData['size'] as Map<String, dynamic>?;
      final properties = componentData['properties'] as Map<String, dynamic>?;
      
      final double x = _asDouble(
        position?['dx'] ?? position?['x'] ?? componentData['x'], 0);
      final double y = _asDouble(
        position?['dy'] ?? position?['y'] ?? componentData['y'], 0);
      final double width = _asDouble(
        size?['width'] ?? componentData['width'], 100);
      final double height = _asDouble(
        size?['height'] ?? componentData['height'], 50);
      
      // Try to show text even from error data
      final text = componentData['text']?.toString() ?? 
                   properties?['text']?.toString() ?? 
                   'Error';

      return Positioned(
        left: x,
        top: y,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              Text(
                text,
                style: const TextStyle(fontSize: 8, color: Colors.red),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
  }

  static Widget _buildTextBoxWidget(Map<String, dynamic> data, double width, double height) {
    // Extract text content with multiple fallbacks
    final text = data['text']?.toString() ?? '';
    
    // Extract styling properties with fallbacks for both data structures
    final fontSize = _asDouble(data['fontSize'], 16);
    final fontFamily = data['fontFamily']?.toString();
    final isBold = _tryBool(data['isBold']) ?? false;
    final isItalic = _tryBool(data['isItalic']) ?? false;
    final isUnderline = _tryBool(data['isUnderline']) ?? false;
    final textColor = Color(_tryColor(data['textColor']) ?? Colors.black.value);
    
    // Handle backgroundColor properly - check for null, 0, or valid color values
    Color backgroundColor = Colors.white;
    final bgColorValue = data['backgroundColor'];
    if (bgColorValue != null) {
      if (bgColorValue == 0) {
        backgroundColor = Colors.transparent;
      } else {
        backgroundColor = Color(_tryColor(bgColorValue) ?? Colors.white.value);
      }
    }
    
    // Handle gradient background
    LinearGradient? gradient;
    final useGradient = data['useGradient'] == true;
    if (useGradient) {
      final gradientStart = data['gradientStart'];
      final gradientEnd = data['gradientEnd'];
      if (gradientStart != null && gradientEnd != null) {
        try {
          final startColor = Color(_tryColor(gradientStart) ?? backgroundColor.value);
          final endColor = Color(_tryColor(gradientEnd) ?? backgroundColor.value);
          gradient = LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } catch (e) {
          // Error creating gradient, fallback to solid color
        }
      }
    }
    
    final borderColor = Color(_tryColor(data['borderColor']) ?? Colors.grey.value);
    final borderWidth = _asDouble(data['borderWidth'], 1);
    final borderRadius = _asDouble(data['borderRadius'], 8);
    final showBorder = _tryBool(data['showBorder']) ?? false;
    final padding = _asDouble(data['padding'], 8);
    final textAlign = _parseTextAlign(data['textAlign']?.toString() ?? 'center');

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: gradient == null ? backgroundColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: borderColor, width: borderWidth) : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Align(
          alignment: _getAlignment(textAlign),
          child: Text(
            text,
            style: _buildTextStyle(
              fontSize: fontSize,
              fontFamily: fontFamily,
              isBold: isBold,
              isItalic: isItalic,
              isUnderline: isUnderline,
              color: textColor,
            ),
            textAlign: textAlign,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }

  static Widget _buildTextLabelWidget(Map<String, dynamic> data, double width, double height) {
    // Extract text content
    final text = data['text']?.toString() ?? '';
    
    // Extract styling properties
    final fontSize = _asDouble(data['fontSize'], 14);
    final fontFamily = data['fontFamily']?.toString();
    final isBold = _tryBool(data['isBold']) ?? false;
    final isItalic = _tryBool(data['isItalic']) ?? false;
    final isUnderline = _tryBool(data['isUnderline']) ?? false;
    final textColor = Color(_tryColor(data['textColor']) ?? Colors.black.value);
    
    // Handle backgroundColor properly - check for null, 0, or valid color values
    Color backgroundColor = Colors.transparent;
    final bgColorValue = data['backgroundColor'];
    if (bgColorValue != null) {
      if (bgColorValue == 0) {
        backgroundColor = Colors.transparent;
      } else {
        backgroundColor = Color(_tryColor(bgColorValue) ?? Colors.transparent.value);
      }
    }
    
    // Handle gradient background
    LinearGradient? gradient;
    final useGradient = data['useGradient'] == true;
    if (useGradient) {
      final gradientStart = data['gradientStart'];
      final gradientEnd = data['gradientEnd'];
      if (gradientStart != null && gradientEnd != null) {
        try {
          final startColor = Color(_tryColor(gradientStart) ?? backgroundColor.value);
          final endColor = Color(_tryColor(gradientEnd) ?? backgroundColor.value);
          gradient = LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } catch (e) {
          // Error creating gradient, fallback to solid color
        }
      }
    }
    
    final padding = _asDouble(data['padding'], 8);
    final textAlign = _parseTextAlign(data['textAlign']?.toString() ?? 'left');

    return Container(
      width: width,
      height: height,
      decoration: gradient != null || backgroundColor != Colors.transparent 
        ? BoxDecoration(
            color: gradient == null ? backgroundColor : null,
            gradient: gradient,
          )
        : null,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Align(
          alignment: _getAlignment(textAlign),
          child: Text(
            text,
            style: _buildTextStyle(
              fontSize: fontSize,
              fontFamily: fontFamily,
              isBold: isBold,
              isItalic: isItalic,
              isUnderline: isUnderline,
              color: textColor,
            ),
            textAlign: textAlign,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }

  static Widget _buildImageWidget(Map<String, dynamic> data, double width, double height) {
    final imagePath = data['imagePath']?.toString() ?? '';
    final borderRadius = _asDouble(data['borderRadius'], 8);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey.shade200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imagePath.isNotEmpty
            ? Image.network(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              )
            : const Center(
                child: Icon(Icons.image, color: Colors.grey),
              ),
      ),
    );
  }

  static Widget _buildGradientDividerWidget(Map<String, dynamic> data, double width, double height) {
    final gradientColors = data['gradientColors'] as List<dynamic>?;
    final useGradient = data['useGradient'] == true;
    final gradientStart = data['gradientStart']; // Color value
    final gradientEnd = data['gradientEnd']; // Color value
    final color1 = data['color1']; // New format
    final color2 = data['color2']; // New format
    final color = Color(_tryColor(data['color'] ?? data['backgroundColor']) ?? Colors.grey.value);
    final borderRadius = _asDouble(data['borderRadius'] ?? data['cornerRadius'], 0);
    final dividerHeight = _asDouble(data['height'], height); // Use height property or component height
    
    // Create gradient from colors if available
    LinearGradient? gradient;
    
    // Try gradientColors array first (new format)
    if (gradientColors != null && gradientColors.length >= 2) {
      try {
        final colors = gradientColors.map((c) => Color(_tryColor(c) ?? Colors.grey.value)).toList();
        gradient = LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      } catch (e) {
        // Error creating gradient from gradientColors
      }
    }
    // Try color1/color2 format (current format)
    else if (color1 != null && color2 != null) {
      try {
        final startColor = Color(_tryColor(color1) ?? Colors.grey.value);
        final endColor = Color(_tryColor(color2) ?? Colors.grey.value);
        gradient = LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      } catch (e) {
        // Error creating gradient from color1/color2
      }
    }
    // Try gradientStart/gradientEnd format (saved format)
    else if (useGradient && gradientStart != null && gradientEnd != null) {
      try {
        final startColor = Color(_tryColor(gradientStart) ?? Colors.grey.value);
        final endColor = Color(_tryColor(gradientEnd) ?? Colors.grey.value);
        gradient = LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      } catch (e) {
        // Error creating gradient from gradientStart/gradientEnd
      }
    }

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      child: Container(
        width: width,
        height: dividerHeight,
        decoration: BoxDecoration(
          color: gradient == null ? color : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  static Widget _buildShapeWidget(Map<String, dynamic> data, double width, double height) {
    final shapeType = data['shapeType']?.toString() ?? 'rectangle';
    
    // Handle backgroundColor properly - same as textBox
    Color backgroundColor = Colors.grey;
    final bgColorValue = data['backgroundColor'] ?? data['color'];
    if (bgColorValue != null) {
      if (bgColorValue == 0) {
        backgroundColor = Colors.transparent;
      } else {
        backgroundColor = Color(_tryColor(bgColorValue) ?? Colors.grey.value);
      }
    }
    
    // Handle gradient background
    LinearGradient? gradient;
    final useGradient = data['useGradient'] == true;
    if (useGradient) {
      final gradientStart = data['gradientStart'];
      final gradientEnd = data['gradientEnd'];
      if (gradientStart != null && gradientEnd != null) {
        try {
          final startColor = Color(_tryColor(gradientStart) ?? backgroundColor.value);
          final endColor = Color(_tryColor(gradientEnd) ?? backgroundColor.value);
          gradient = LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } catch (e) {
          // Error creating gradient, fallback to solid color
        }
      }
    }
    
    final borderColor = Color(_tryColor(data['borderColor']) ?? Colors.transparent.value);
    final borderWidth = _asDouble(data['borderWidth'], 0);
    final borderRadius = _asDouble(data['borderRadius'], 0);

    BoxDecoration decoration;
    
    switch (shapeType.toLowerCase()) {
      case 'circle':
        decoration = BoxDecoration(
          color: gradient == null ? backgroundColor : null,
          gradient: gradient,
          shape: BoxShape.circle,
          border: borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth) : null,
        );
        break;
      case 'rectangle':
      default:
        decoration = BoxDecoration(
          color: gradient == null ? backgroundColor : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth) : null,
        );
        break;
    }

    return Container(
      width: width,
      height: height,
      decoration: decoration,
    );
  }

  static Widget _buildContainerWidget(Map<String, dynamic> data, double width, double height) {
    // Handle backgroundColor properly - same as textBox
    Color backgroundColor = Colors.transparent;
    final bgColorValue = data['backgroundColor'] ?? data['color'];
    if (bgColorValue != null) {
      if (bgColorValue == 0) {
        backgroundColor = Colors.transparent;
      } else {
        backgroundColor = Color(_tryColor(bgColorValue) ?? Colors.transparent.value);
      }
    }
    
    // Handle gradient background
    LinearGradient? gradient;
    final useGradient = data['useGradient'] == true;
    if (useGradient) {
      final gradientStart = data['gradientStart'];
      final gradientEnd = data['gradientEnd'];
      if (gradientStart != null && gradientEnd != null) {
        try {
          final startColor = Color(_tryColor(gradientStart) ?? backgroundColor.value);
          final endColor = Color(_tryColor(gradientEnd) ?? backgroundColor.value);
          gradient = LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } catch (e) {
          // Error creating gradient, fallback to solid color
        }
      }
    }
    
    final borderColor = Color(_tryColor(data['borderColor']) ?? Colors.transparent.value);
    final borderWidth = _asDouble(data['borderWidth'], 0);
    final borderRadius = _asDouble(data['borderRadius'], 0);
    final padding = _asDouble(data['padding'], 0);

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth) : null,
      ),
      // If it has text content, show it
      child: data.containsKey('text') ? 
        Center(
          child: Text(
            data['text']?.toString() ?? '',
            style: TextStyle(
              fontSize: _asDouble(data['fontSize'], 14),
              color: Color(_tryColor(data['textColor']) ?? Colors.black.value),
              fontWeight: _tryBool(data['isBold']) == true ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: _parseTextAlign(data['textAlign']?.toString() ?? 'center'),
          ),
        ) : null,
    );
  }

  static Widget _buildMultipleChoiceWidget(Map<String, dynamic> data, double width, double height) {
    // Extract properties
    final question = data['question']?.toString() ?? 'Sample Question';
    final options = (data['options'] as List<dynamic>?)?.cast<String>() ?? ['Option 1', 'Option 2'];
    final fontSize = _asDouble(data['fontSize'], 14);
    final textColor = Color(_tryColor(data['textColor']) ?? Colors.black.value);
    final questionColor = Color(_tryColor(data['questionColor']) ?? Colors.blue.value);
    final fontFamily = data['fontFamily']?.toString() ?? 'Roboto';
    final padding = _asDouble(data['padding'], 12);
    final borderRadius = _asDouble(data['borderRadius'], 8);
    final backgroundColor = Color(_tryColor(data['backgroundColor']) ?? Colors.grey.shade50.value);
    final showBorder = _tryBool(data['showBorder']) ?? true;
    final borderColor = Color(_tryColor(data['borderColor']) ?? Colors.grey.value);
    final borderWidth = _asDouble(data['borderWidth'], 1);
    final checkboxSize = _asDouble(data['checkboxSize'], 20);
    final spacing = _asDouble(data['spacing'], 8);

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: borderColor, width: borderWidth) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Question text
          Text(
            question,
            style: GoogleFonts.getFont(
              fontFamily,
              fontSize: fontSize + 2,
              fontWeight: FontWeight.w600,
              color: questionColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: spacing),
          // Options in row layout (horizontal)
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: spacing * 2,
                runSpacing: spacing,
                children: options.take(4).map((option) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: checkboxSize,
                        height: checkboxSize,
                        decoration: BoxDecoration(
                          border: Border.all(color: textColor, width: 1.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      SizedBox(width: spacing / 2),
                      Text(
                        option,
                        style: GoogleFonts.getFont(
                          fontFamily,
                          fontSize: fontSize,
                          color: textColor,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildUniversalWidget(Map<String, dynamic> data, double width, double height, String type) {
    // Extract basic styling
    // Handle backgroundColor properly - same as textBox
    Color backgroundColor = Colors.grey.shade100;
    final bgColorValue = data['backgroundColor'] ?? data['color'];
    if (bgColorValue != null) {
      if (bgColorValue == 0) {
        backgroundColor = Colors.transparent;
      } else {
        backgroundColor = Color(_tryColor(bgColorValue) ?? Colors.grey.shade100.value);
      }
    }
    
    // Handle gradient background
    LinearGradient? gradient;
    final useGradient = data['useGradient'] == true;
    if (useGradient) {
      final gradientStart = data['gradientStart'];
      final gradientEnd = data['gradientEnd'];
      if (gradientStart != null && gradientEnd != null) {
        try {
          final startColor = Color(_tryColor(gradientStart) ?? backgroundColor.value);
          final endColor = Color(_tryColor(gradientEnd) ?? backgroundColor.value);
          gradient = LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
        } catch (e) {
          // Error creating gradient, fallback to solid color
        }
      }
    }
    
    final borderColor = Color(_tryColor(data['borderColor']) ?? Colors.grey.value);
    final borderWidth = _asDouble(data['borderWidth'], 0);
    final borderRadius = _asDouble(data['borderRadius'], 4);
    final padding = _asDouble(data['padding'], 4);
    
    // Check if it has text content
    final text = data['text']?.toString() ?? '';
    final hasText = text.isNotEmpty;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: gradient == null ? backgroundColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth) : null,
      ),
      child: hasText ? 
        Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: _asDouble(data['fontSize'], 12),
              color: Color(_tryColor(data['textColor']) ?? Colors.black.value),
              fontWeight: _tryBool(data['isBold']) == true ? FontWeight.bold : FontWeight.normal,
              fontStyle: _tryBool(data['isItalic']) == true ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: _parseTextAlign(data['textAlign']?.toString() ?? 'center'),
            overflow: TextOverflow.visible,
          ),
        ) : 
        // Show a minimal indicator for non-text components
        Center(
          child: Container(
            width: width * 0.8,
            height: height * 0.8,
            decoration: BoxDecoration(
              color: gradient == null ? backgroundColor.withOpacity(0.3) : null,
              gradient: gradient != null ? LinearGradient(
                colors: gradient.colors.map((c) => c.withOpacity(0.3)).toList(),
                begin: gradient.begin,
                end: gradient.end,
              ) : null,
              borderRadius: BorderRadius.circular(borderRadius * 0.5),
            ),
          ),
        ),
    );
  }

  static Alignment _getAlignment(TextAlign textAlign) {
    switch (textAlign) {
      case TextAlign.left:
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.center:
      default:
        return Alignment.center;
    }
  }

  static Map<String, dynamic> _normalizeComponent(Map<String, dynamic> component) {
    final position = component['position'];
    final size = component['size'];
    final type = _extractComponentType(component['type']?.toString() ?? '');
    final properties = component['properties'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(component['properties'] as Map<String, dynamic>)
        : <String, dynamic>{};

    return {
      'id': component['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'x': _asDouble(position is Map ? position['x'] : component['x'], 0),
      'y': _asDouble(position is Map ? position['y'] : component['y'], 0),
      'width': _asDouble(size is Map ? size['width'] : component['width'], _defaultWidthForType(type)),
      'height': _asDouble(size is Map ? size['height'] : component['height'], _defaultHeightForType(type)),
      'properties': _normalizeProperties(type, properties),
    };
  }

  static Map<String, dynamic> _normalizeProperties(String type, Map<String, dynamic> properties) {
    const doubleKeys = {
      'fontSize',
      'borderRadius',
      'borderWidth',
      'iconSize',
      'padding',
      'lineHeight',
      'letterSpacing',
      'shadowBlur',
      'shadowSpread',
      'shadowOffsetX',
      'shadowOffsetY',
      'strokeWidth',
    };

    for (final key in doubleKeys) {
      if (properties.containsKey(key)) {
        final normalized = _tryDouble(properties[key]);
        if (normalized != null) {
          properties[key] = normalized;
        }
      }
    }

    const intKeys = {'maxLines', 'minLines'};
    for (final key in intKeys) {
      if (properties.containsKey(key)) {
        final normalized = _tryInt(properties[key]);
        if (normalized != null) {
          properties[key] = normalized;
        }
      }
    }

    const boolKeys = {'isBold', 'isItalic', 'showBorder', 'useGradient', 'useShadow'};
    for (final key in boolKeys) {
      if (properties.containsKey(key)) {
        final normalized = _tryBool(properties[key]);
        if (normalized != null) {
          properties[key] = normalized;
        }
      }
    }

    const colorKeys = {
      'backgroundColor',
      'textColor',
      'borderColor',
      'secondaryTextColor',
      'primaryColor',
      'shadowColor',
      'woodColor1',
      'woodColor2',
      'innerBackgroundColor',
      'iconColor',
      'accentColor',
    };
    for (final key in colorKeys) {
      if (properties.containsKey(key)) {
        final normalized = _tryColor(properties[key]);
        if (normalized != null) {
          properties[key] = normalized;
        }
      }
    }

    return properties;
  }

  static double _defaultWidthForType(String type) {
    switch (type) {
      case 'textLabel':
        return 150.0;
      case 'textBox':
        return 220.0;
      case 'imageContainer':
        return 200.0;
      case 'iconContainer':
        return 60.0;
      case 'dateContainer':
        return 180.0;
      case 'calendar':
        return 140.0;
      case 'coloredContainer':
      case 'woodenContainer':
        return 220.0;
      default:
        return 160.0;
    }
  }

  static double _defaultHeightForType(String type) {
    switch (type) {
      case 'textLabel':
        return 40.0;
      case 'textBox':
        return 120.0;
      case 'imageContainer':
        return 150.0;
      case 'iconContainer':
        return 60.0;
      case 'dateContainer':
        return 110.0;
      case 'calendar':
        return 140.0;
      case 'coloredContainer':
      case 'woodenContainer':
        return 140.0;
      default:
        return 100.0;
    }
  }

  static double _asDouble(dynamic value, double fallback) => _tryDouble(value) ?? fallback;

  static double? _tryDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _tryInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _tryBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lowered = value.toLowerCase();
      if (lowered == 'true') return true;
      if (lowered == 'false') return false;
    }
    return null;
  }

  static int? _tryColor(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is Color) return value.value;
    if (value is String) {
      final cleaned = value.trim();
      if (cleaned.startsWith('0x')) {
        return int.tryParse(cleaned.substring(2), radix: 16);
      }
      if (cleaned.startsWith('#')) {
        final hex = cleaned.substring(1);
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) {
          // If only RGB provided, assume fully opaque
          if (hex.length <= 6) {
            return 0xFF000000 | parsed;
          }
          return parsed;
        }
      }
      return int.tryParse(cleaned);
    }
    return null;
  }

  /// Renders a template in full size for detailed viewing
  static Widget buildFullSizeTemplate({
    required Map<String, dynamic> templateData,
    double? maxWidth,
    double? maxHeight,
  }) {
    final components = (templateData['components'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final canvasWidth = (templateData['canvasWidth'] is int) 
        ? (templateData['canvasWidth'] as int).toDouble()
        : templateData['canvasWidth']?.toDouble() ?? 350.0;
    final canvasHeight = (templateData['canvasHeight'] is int) 
        ? (templateData['canvasHeight'] as int).toDouble()
        : templateData['canvasHeight']?.toDouble() ?? 500.0;
    
    // Canvas styling properties
    final canvasBackgroundColor = Color(templateData['canvasBackgroundColor'] ?? 0xFFFFFFFF);
    final canvasBackgroundMode = templateData['canvasBackgroundMode'] ?? 'solid';
    final canvasBackgroundGradient = templateData['canvasBackgroundGradient'];
    
    // Canvas border properties - Always show border with proper defaults
    final canvasBorderColor = Color(templateData['canvasBorderColor'] ?? 0xFF9CA3AF); // Gray-400 for visibility
    final canvasBorderWidth = (templateData['canvasBorderWidth'] as num?)?.toDouble() ?? 2.0; // More visible 2px default
    final canvasBorderRadius = (templateData['canvasBorderRadius'] as num?)?.toDouble() ?? 12.0; // Rounded corners

    // Create canvas decoration
    Decoration canvasDecoration;
    if (canvasBackgroundMode == 'gradient' && canvasBackgroundGradient != null) {
      // Gradient background
      final gradientData = canvasBackgroundGradient as Map<String, dynamic>;
      final colors = (gradientData['colors'] as List<dynamic>?)
          ?.map((color) => Color(color as int))
          .toList() ?? [canvasBackgroundColor, canvasBackgroundColor];
      final begin = gradientData['begin'] as Map<String, dynamic>?;
      final end = gradientData['end'] as Map<String, dynamic>?;
      
      canvasDecoration = BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: begin != null 
              ? Alignment(begin['x']?.toDouble() ?? -1.0, begin['y']?.toDouble() ?? -1.0)
              : Alignment.centerLeft,
          end: end != null 
              ? Alignment(end['x']?.toDouble() ?? 1.0, end['y']?.toDouble() ?? 1.0)
              : Alignment.centerRight,
          stops: gradientData['stops'] != null 
              ? (gradientData['stops'] as List<dynamic>).map((s) => (s as num).toDouble()).toList()
              : null,
        ),
        borderRadius: BorderRadius.circular(canvasBorderRadius),
        border: canvasBorderWidth > 0 
            ? Border.all(color: canvasBorderColor, width: canvasBorderWidth)
            : null,
      );
    } else {
      // Solid background
      canvasDecoration = BoxDecoration(
        color: canvasBackgroundColor,
        borderRadius: BorderRadius.circular(canvasBorderRadius),
        border: canvasBorderWidth > 0 
            ? Border.all(color: canvasBorderColor, width: canvasBorderWidth)
            : null,
      );
    }

    return Container(
      width: maxWidth ?? canvasWidth,
      height: maxHeight ?? canvasHeight,
      decoration: canvasDecoration,
      child: Stack(
        children: components.map<Widget>((componentData) {
          try {
            final component = DraggableComponent.fromJson(componentData);
            return Positioned(
              left: component.x,
              top: component.y,
              child: component.buildWidget(),
            );
          } catch (e) {
            // If there's an error rendering a component, show a placeholder
            return Positioned(
              left: componentData['x']?.toDouble() ?? 0,
              top: componentData['y']?.toDouble() ?? 0,
              child: Container(
                width: componentData['width']?.toDouble() ?? 50,
                height: componentData['height']?.toDouble() ?? 50,
                color: Colors.red.withOpacity(0.3),
                child: const Icon(Icons.error, color: Colors.red),
              ),
            );
          }
        }).toList(),
      ),
    );
  }
}