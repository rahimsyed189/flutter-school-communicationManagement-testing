import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
    final templateName = templateData['name'] ?? 'Custom Template';

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
              print('Error creating component: $e');
              print('Component data: $componentData');
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

      print('Posting custom template with ${(widget.templateData['components'] as List).length} components');
      print('Template data: ${widget.templateData}');

      final docRef = await FirebaseFirestore.instance
          .collection('communications')
          .add(postData);
      
      print('Custom template posted successfully with ID: ${docRef.id}');

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

  @override
  Widget build(BuildContext context) {
    print('CustomAnnouncementRenderer building with template data: $templateData');
    
    final components = (templateData['components'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final canvasWidth = (templateData['canvasWidth'] is int) 
        ? (templateData['canvasWidth'] as int).toDouble()
        : templateData['canvasWidth']?.toDouble() ?? 350.0;
    final canvasHeight = (templateData['canvasHeight'] is int) 
        ? (templateData['canvasHeight'] as int).toDouble()
        : templateData['canvasHeight']?.toDouble() ?? 500.0;
    final templateName = templateData['name'] ?? 'Custom Template';
    
    print('Rendering custom template with ${components.length} components, canvas: ${canvasWidth}x${canvasHeight}');
    
    // Get announcement details
    final title = announcementData['title'] ?? templateName;
    final description = announcementData['description'] ?? '';
    final timestamp = announcementData['timestamp'] as Timestamp?;
    final postedBy = announcementData['postedBy'] ?? '';
    final reactions = announcementData['reactions'] as Map<String, dynamic>? ?? {};

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Announcement Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF673AB7), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.announcement,
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
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate()),
                              style: const TextStyle(
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
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Custom Template Content - Full Size, Exact Replica
          Container(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                width: canvasWidth,
                height: canvasHeight,
                decoration: BoxDecoration(
                  color: Color(templateData['canvasBackgroundColor'] ?? Colors.white.value),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: components.map<Widget>((componentData) {
                      try {
                        // Extract component data (same logic as preview)
                        final x = componentData['position']?['x']?.toDouble() ?? 0;
                        final y = componentData['position']?['y']?.toDouble() ?? 0;
                        final width = componentData['size']?['width']?.toDouble() ?? 120;
                        final height = componentData['size']?['height']?.toDouble() ?? 40;
                        final properties = componentData['properties'] ?? {};
                        final type = CustomAnnouncementRenderer._extractComponentType(componentData['type']);
                        
                        Widget componentWidget;
                        
                        switch (type) {
                          case 'textLabel':
                            componentWidget = Container(
                              width: width,
                              height: height,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Color(properties['backgroundColor'] ?? Colors.transparent.value),
                                borderRadius: BorderRadius.circular(properties['borderRadius']?.toDouble() ?? 0),
                                border: properties['showBorder'] == true 
                                  ? Border.all(
                                      color: Color(properties['borderColor'] ?? Colors.grey.value),
                                      width: properties['borderWidth']?.toDouble() ?? 1,
                                    )
                                  : null,
                              ),
                              child: Text(
                                properties['text'] ?? 'Text Label',
                                style: TextStyle(
                                  fontSize: properties['fontSize']?.toDouble() ?? 16,
                                  fontWeight: properties['isBold'] == true ? FontWeight.bold : FontWeight.normal,
                                  fontStyle: properties['isItalic'] == true ? FontStyle.italic : FontStyle.normal,
                                  color: Color(properties['textColor'] ?? Colors.black.value),
                                ),
                                textAlign: CustomAnnouncementRenderer._getTextAlignment(properties['textAlign'] ?? 'center'),
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
                                  fontSize: properties['fontSize']?.toDouble() ?? 14,
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
                        // Fallback for any component that fails to render
                        final x = componentData['position']?['x']?.toDouble() ?? 0;
                        final y = componentData['position']?['y']?.toDouble() ?? 0;
                        final width = componentData['size']?['width']?.toDouble() ?? 50;
                        final height = componentData['size']?['height']?.toDouble() ?? 50;
                        
                        return Positioned(
                          left: x,
                          top: y,
                          child: Container(
                            width: width,
                            height: height,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                            ),
                          ),
                        );
                      }
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          
          // Reactions and Footer
          if (reactions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: _buildReactionsRow(reactions),
            ),
        ],
      ),
    );
  }

  Widget _buildReactionsRow(Map<String, dynamic> reactions) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    
    // Count unique reactions
    final reactionCounts = <String, int>{};
    reactions.values.forEach((reaction) {
      if (reaction is String) {
        reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
      }
    });
    
    return Wrap(
      spacing: 8,
      children: reactionCounts.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.key,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
              Text(
                entry.value.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}