import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Enum for component types
enum ComponentType {
  calendar,
  dateContainer,
  textLabel,
  textBox,
  woodenContainer,
  coloredContainer,
  imageContainer,
  iconContainer,
  gradientSeparator,
}

// Base class for all draggable components
abstract class DraggableComponent {
  final String id;
  final ComponentType type;
  double x;
  double y;
  double width;
  double height;
  Map<String, dynamic> properties;

  DraggableComponent({
    required this.id,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 150,
    this.height = 100,
    Map<String, dynamic>? properties,
  }) : properties = properties ?? {};

  Widget buildWidget();
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate);
  Map<String, dynamic> toJson();
  factory DraggableComponent.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'calendar':
        return CalendarComponent.fromJson(json);
      case 'dateContainer':
        return DateContainerComponent.fromJson(json);
      case 'textLabel':
        return TextLabelComponent.fromJson(json);
      case 'textBox':
        return TextBoxComponent.fromJson(json);
      case 'woodenContainer':
        return WoodenContainerComponent.fromJson(json);
      case 'coloredContainer':
        return ColoredContainerComponent.fromJson(json);
      case 'imageContainer':
        return ImageContainerComponent.fromJson(json);
      case 'iconContainer':
        return IconContainerComponent.fromJson(json);
      case 'gradientSeparator':
        return GradientSeparatorComponent.fromJson(json);
      default:
        throw Exception('Unknown component type: ${json['type']}');
    }
  }
}

// Calendar Component (from holiday templates)
class CalendarComponent extends DraggableComponent {
  CalendarComponent({
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? properties,
  }) : super(
          id: id,
          type: ComponentType.calendar,
          x: x,
          y: y,
          width: 120,
          height: 120,
          properties: properties ?? {
            'selectedDate': DateTime.now(),
            'primaryColor': const Color(0xFF42A5F5).value,
            'backgroundColor': Colors.white.value,
            'textColor': Colors.black87.value,
          },
        );

  @override
  Widget buildWidget() {
    try {
      final selectedDate = properties['selectedDate'] is int 
          ? DateTime.fromMillisecondsSinceEpoch(properties['selectedDate'])
          : DateTime.now();
      final primaryColor = Color(properties['primaryColor'] ?? const Color(0xFF42A5F5).value);
      final backgroundColor = Color(properties['backgroundColor'] ?? Colors.white.value);
      final textColor = Color(properties['textColor'] ?? Colors.black87.value);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Month/Year header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              DateFormat('MMM yyyy').format(selectedDate),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Date
          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selectedDate.day.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    DateFormat('EEEE').format(selectedDate),
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    } catch (e) {
      // Fallback widget if there's an error
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 24),
              SizedBox(height: 4),
              Text(
                'Calendar Error',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    DateTime selectedDate = DateTime.fromMillisecondsSinceEpoch(
        properties['selectedDate'] ?? DateTime.now().millisecondsSinceEpoch);
    Color primaryColor = Color(properties['primaryColor'] ?? const Color(0xFF42A5F5).value);

    return AlertDialog(
      title: const Text('Edit Calendar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Select Date'),
            subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                selectedDate = picked;
              }
            },
          ),
          const SizedBox(height: 16),
          const Text('Primary Color'),
          Container(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Color(0xFF42A5F5), // Blue
                  const Color(0xFF66BB6A), // Green
                  const Color(0xFFFF9800), // Orange
                  const Color(0xFFAB47BC), // Purple
                  const Color(0xFFEC407A), // Pink
                  const Color(0xFF26A69A), // Teal
                ].map((color) => GestureDetector(
                  onTap: () => primaryColor = color,
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor == color ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
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
            onUpdate({
              'selectedDate': selectedDate.millisecondsSinceEpoch,
              'primaryColor': primaryColor.value,
            });
            Navigator.pop(context);
          },
          child: const Text('Update'),
        ),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'calendar',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory CalendarComponent.fromJson(Map<String, dynamic> json) {
    return CalendarComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}

// Date Container Component (from PTM templates)
class DateContainerComponent extends DraggableComponent {
  DateContainerComponent({
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? properties,
  }) : super(
          id: id,
          type: ComponentType.dateContainer,
          x: x,
          y: y,
          width: 200,
          height: 80,
          properties: properties ?? {
            'date': DateTime.now().millisecondsSinceEpoch,
            'startTime': '4:00 PM',
            'endTime': '6:00 PM',
            'backgroundColor': const Color(0xFFF7E6D0).value,
            'textColor': const Color(0xFF2C3E50).value,
            'label': 'Event Date',
          },
        );

  @override
  Widget buildWidget() {
    final date = DateTime.fromMillisecondsSinceEpoch(
        properties['date'] ?? DateTime.now().millisecondsSinceEpoch);
    final startTime = properties['startTime'] ?? '4:00 PM';
    final endTime = properties['endTime'] ?? '6:00 PM';
    final backgroundColor = Color(properties['backgroundColor'] ?? const Color(0xFFF7E6D0).value);
    final textColor = Color(properties['textColor'] ?? const Color(0xFF2C3E50).value);
    final label = properties['label'] ?? 'Event Date';

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM dd, yyyy').format(date),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$startTime - $endTime',
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(
        properties['date'] ?? DateTime.now().millisecondsSinceEpoch);
    TextEditingController startTimeController = TextEditingController(text: properties['startTime'] ?? '4:00 PM');
    TextEditingController endTimeController = TextEditingController(text: properties['endTime'] ?? '6:00 PM');
    TextEditingController labelController = TextEditingController(text: properties['label'] ?? 'Event Date');
    
    return AlertDialog(
      title: const Text('Edit Date Container'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Select Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  date = picked;
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: startTimeController,
              decoration: const InputDecoration(
                labelText: 'Start Time',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: endTimeController,
              decoration: const InputDecoration(
                labelText: 'End Time',
                border: OutlineInputBorder(),
              ),
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
            onUpdate({
              'date': date.millisecondsSinceEpoch,
              'startTime': startTimeController.text,
              'endTime': endTimeController.text,
              'label': labelController.text,
            });
            Navigator.pop(context);
          },
          child: const Text('Update'),
        ),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'dateContainer',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory DateContainerComponent.fromJson(Map<String, dynamic> json) {
    return DateContainerComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}

// Text Label Component
class TextLabelComponent extends DraggableComponent {
  TextLabelComponent({
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? properties,
  }) : super(
          id: id,
          type: ComponentType.textLabel,
          x: x,
          y: y,
          width: 150,
          height: 40,
          properties: properties ?? {
            'text': 'Sample Label',
            'fontSize': 16.0,
            'fontWeight': 'bold',
            'textColor': Colors.black87.value,
            'backgroundColor': Colors.transparent.value,
            'alignment': 'center',
          },
        );

  @override
  Widget buildWidget() {
    final text = properties['text'] ?? 'Sample Label';
    final fontSize = properties['fontSize']?.toDouble() ?? 16.0;
    final fontWeight = properties['fontWeight'] == 'bold' ? FontWeight.bold : FontWeight.normal;
    final textColor = Color(properties['textColor'] ?? Colors.black87.value);
    final backgroundColor = Color(properties['backgroundColor'] ?? Colors.transparent.value);
    final alignment = properties['alignment'] ?? 'center';

    TextAlign textAlign;
    switch (alignment) {
      case 'left':
        textAlign = TextAlign.left;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      default:
        textAlign = TextAlign.center;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
        ),
        textAlign: textAlign,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    TextEditingController textController = TextEditingController(text: properties['text'] ?? 'Sample Label');
    double fontSize = properties['fontSize']?.toDouble() ?? 16.0;
    String fontWeight = properties['fontWeight'] ?? 'normal';
    String alignment = properties['alignment'] ?? 'center';
    Color textColor = Color(properties['textColor'] ?? Colors.black87.value);

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Edit Text Label'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Text',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Font Size: '),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 10,
                        max: 32,
                        divisions: 22,
                        label: fontSize.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            fontSize = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Font Weight: '),
                    DropdownButton<String>(
                      value: fontWeight,
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'bold', child: Text('Bold')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          fontWeight = value ?? 'normal';
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Alignment: '),
                    DropdownButton<String>(
                      value: alignment,
                      items: const [
                        DropdownMenuItem(value: 'left', child: Text('Left')),
                        DropdownMenuItem(value: 'center', child: Text('Center')),
                        DropdownMenuItem(value: 'right', child: Text('Right')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          alignment = value ?? 'center';
                        });
                      },
                    ),
                  ],
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
                onUpdate({
                  'text': textController.text,
                  'fontSize': fontSize,
                  'fontWeight': fontWeight,
                  'alignment': alignment,
                  'textColor': textColor.value,
                });
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'textLabel',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory TextLabelComponent.fromJson(Map<String, dynamic> json) {
    return TextLabelComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}

// Text Box Component (larger text area)
class TextBoxComponent extends DraggableComponent {
  TextBoxComponent({
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? properties,
  }) : super(
          id: id,
          type: ComponentType.textBox,
          x: x,
          y: y,
          width: 200,
          height: 100,
          properties: properties ?? {
            'text': 'Sample text box content that can span multiple lines and contain longer descriptions.',
            'fontSize': 14.0,
            'textColor': Colors.black87.value,
            'backgroundColor': Colors.white.value,
            'borderColor': Colors.grey.value,
            'padding': 12.0,
          },
        );

  @override
  Widget buildWidget() {
    final text = properties['text'] ?? 'Sample text box';
    final fontSize = properties['fontSize']?.toDouble() ?? 14.0;
    final textColor = Color(properties['textColor'] ?? Colors.black87.value);
    final backgroundColor = Color(properties['backgroundColor'] ?? Colors.white.value);
    final borderColor = Color(properties['borderColor'] ?? Colors.grey.value);
    final padding = properties['padding']?.toDouble() ?? 12.0;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    TextEditingController textController = TextEditingController(text: properties['text'] ?? '');
    double fontSize = properties['fontSize']?.toDouble() ?? 14.0;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Edit Text Box'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Text Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Font Size: '),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 10,
                        max: 24,
                        divisions: 14,
                        label: fontSize.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            fontSize = value;
                          });
                        },
                      ),
                    ),
                  ],
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
                onUpdate({
                  'text': textController.text,
                  'fontSize': fontSize,
                });
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'textBox',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory TextBoxComponent.fromJson(Map<String, dynamic> json) {
    return TextBoxComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}

// Wooden Container Component (from PTM templates)
class WoodenContainerComponent extends DraggableComponent {
  WoodenContainerComponent({
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? properties,
  }) : super(
          id: id,
          type: ComponentType.woodenContainer,
          x: x,
          y: y,
          width: 200,
          height: 100,
          properties: properties ?? {
            'woodColor1': const Color(0xFFF7E6D0).value,
            'woodColor2': const Color(0xFFF0CFA2).value,
            'innerBackgroundColor': Colors.white.value,
            'shadowColor': Colors.black26.value,
          },
        );

  @override
  Widget buildWidget() {
    final woodColor1 = Color(properties['woodColor1'] ?? const Color(0xFFF7E6D0).value);
    final woodColor2 = Color(properties['woodColor2'] ?? const Color(0xFFF0CFA2).value);
    final innerBackgroundColor = Color(properties['innerBackgroundColor'] ?? Colors.white.value);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [woodColor1, woodColor2],
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
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: innerBackgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Wooden Container',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    return AlertDialog(
      title: const Text('Edit Wooden Container'),
      content: const Text('Wooden container properties can be customized here.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Update'),
        ),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'woodenContainer',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory WoodenContainerComponent.fromJson(Map<String, dynamic> json) {
    return WoodenContainerComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}

// Colored Container Component
class ColoredContainerComponent extends DraggableComponent {
  ColoredContainerComponent({
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? properties,
  }) : super(
          id: id,
          type: ComponentType.coloredContainer,
          x: x,
          y: y,
          width: 150,
          height: 80,
          properties: properties ?? {
            'backgroundColor': const Color(0xFF42A5F5).value,
            'borderRadius': 12.0,
            'hasShadow': true,
          },
        );

  @override
  Widget buildWidget() {
    final backgroundColor = Color(properties['backgroundColor'] ?? const Color(0xFF42A5F5).value);
    final borderRadius = properties['borderRadius']?.toDouble() ?? 12.0;
    final hasShadow = properties['hasShadow'] ?? true;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: const Center(
        child: Text(
          'Container',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    Color backgroundColor = Color(properties['backgroundColor'] ?? const Color(0xFF42A5F5).value);
    double borderRadius = properties['borderRadius']?.toDouble() ?? 12.0;
    bool hasShadow = properties['hasShadow'] ?? true;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Edit Colored Container'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Background Color'),
              Container(
                height: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Color(0xFF42A5F5), // Blue
                      const Color(0xFF66BB6A), // Green
                      const Color(0xFFFF9800), // Orange
                      const Color(0xFFAB47BC), // Purple
                      const Color(0xFFEC407A), // Pink
                      const Color(0xFF26A69A), // Teal
                      const Color(0xFFEF5350), // Red
                    ].map((color) => GestureDetector(
                      onTap: () => setState(() => backgroundColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: backgroundColor == color ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Border Radius: '),
                  Expanded(
                    child: Slider(
                      value: borderRadius,
                      min: 0,
                      max: 50,
                      divisions: 10,
                      label: borderRadius.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          borderRadius = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text('Drop Shadow'),
                value: hasShadow,
                onChanged: (value) {
                  setState(() {
                    hasShadow = value ?? true;
                  });
                },
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
                onUpdate({
                  'backgroundColor': backgroundColor.value,
                  'borderRadius': borderRadius,
                  'hasShadow': hasShadow,
                });
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'coloredContainer',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory ColoredContainerComponent.fromJson(Map<String, dynamic> json) {
    return ColoredContainerComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}

// Image Container Component (placeholder for images)
class ImageContainerComponent extends DraggableComponent {
  ImageContainerComponent({
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? properties,
  }) : super(
          id: id,
          type: ComponentType.imageContainer,
          x: x,
          y: y,
          width: 120,
          height: 120,
          properties: properties ?? {
            'imageUrl': '',
            'placeholder': 'Add Image',
            'borderRadius': 8.0,
            'fit': 'cover',
          },
        );

  @override
  Widget buildWidget() {
    final imageUrl = properties['imageUrl'] ?? '';
    final placeholder = properties['placeholder'] ?? 'Add Image';
    final borderRadius = properties['borderRadius']?.toDouble() ?? 8.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey.shade100,
      ),
      child: imageUrl.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image,
                  size: 32,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 4),
                Text(
                  placeholder,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, size: 32);
                },
              ),
            ),
    );
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    TextEditingController imageUrlController = TextEditingController(text: properties['imageUrl'] ?? '');
    TextEditingController placeholderController = TextEditingController(text: properties['placeholder'] ?? 'Add Image');
    
    return AlertDialog(
      title: const Text('Edit Image Container'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: imageUrlController,
            decoration: const InputDecoration(
              labelText: 'Image URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: placeholderController,
            decoration: const InputDecoration(
              labelText: 'Placeholder Text',
              border: OutlineInputBorder(),
            ),
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
            onUpdate({
              'imageUrl': imageUrlController.text,
              'placeholder': placeholderController.text,
            });
            Navigator.pop(context);
          },
          child: const Text('Update'),
        ),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'imageContainer',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory ImageContainerComponent.fromJson(Map<String, dynamic> json) {
    return ImageContainerComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}

// Icon Container Component
class IconContainerComponent extends DraggableComponent {
  IconContainerComponent({
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? properties,
  }) : super(
          id: id,
          type: ComponentType.iconContainer,
          x: x,
          y: y,
          width: 60,
          height: 60,
          properties: properties ?? {
            'icon': Icons.star.codePoint,
            'iconSize': 32.0,
            'iconColor': Colors.blue.value,
            'backgroundColor': Colors.transparent.value,
            'label': '',
          },
        );

  @override
  Widget buildWidget() {
    final iconData = IconData(properties['icon'] ?? Icons.star.codePoint, fontFamily: 'MaterialIcons');
    final iconSize = properties['iconSize']?.toDouble() ?? 32.0;
    final iconColor = Color(properties['iconColor'] ?? Colors.blue.value);
    final backgroundColor = Color(properties['backgroundColor'] ?? Colors.transparent.value);
    final label = properties['label'] ?? '';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconData,
            size: iconSize,
            color: iconColor,
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    final commonIcons = [
      Icons.star,
      Icons.favorite,
      Icons.home,
      Icons.school,
      Icons.notifications,
      Icons.calendar_today,
      Icons.location_on,
      Icons.phone,
      Icons.email,
      Icons.info,
      Icons.warning,
      Icons.check_circle,
    ];
    
    IconData selectedIcon = IconData(properties['icon'] ?? Icons.star.codePoint, fontFamily: 'MaterialIcons');
    double iconSize = properties['iconSize']?.toDouble() ?? 32.0;
    Color iconColor = Color(properties['iconColor'] ?? Colors.blue.value);
    TextEditingController labelController = TextEditingController(text: properties['label'] ?? '');

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Edit Icon Container'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Select Icon'),
                Container(
                  height: 100,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: commonIcons.length,
                    itemBuilder: (context, index) {
                      final icon = commonIcons[index];
                      final isSelected = selectedIcon.codePoint == icon.codePoint;
                      return GestureDetector(
                        onTap: () => setState(() => selectedIcon = icon),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Icon Size: '),
                    Expanded(
                      child: Slider(
                        value: iconSize,
                        min: 16,
                        max: 64,
                        divisions: 12,
                        label: iconSize.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            iconSize = value;
                          });
                        },
                      ),
                    ),
                  ],
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
                onUpdate({
                  'icon': selectedIcon.codePoint,
                  'iconSize': iconSize,
                  'iconColor': iconColor.value,
                  'label': labelController.text,
                });
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'iconContainer',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory IconContainerComponent.fromJson(Map<String, dynamic> json) {
    return IconContainerComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}

class GradientSeparatorComponent extends DraggableComponent {
  GradientSeparatorComponent({
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? properties,
  }) : super(
          id: id,
          type: ComponentType.gradientSeparator,
          x: x,
          y: y,
          width: 320,
          height: 28,
          properties: properties ?? {
            'startColor': const Color(0xFFFF8A65).value,
            'endColor': const Color(0xFFF06292).value,
            'thickness': 8.0,
            'cornerRadius': 20.0,
            'showShadow': true,
            'shadowOpacity': 0.25,
          },
        );

  @override
  Widget buildWidget() {
    final startColor = Color(properties['startColor'] ?? const Color(0xFFFF8A65).value);
    final endColor = Color(properties['endColor'] ?? const Color(0xFFF06292).value);
    final thickness = (properties['thickness'] ?? 8.0).toDouble().clamp(2.0, 36.0);
    final cornerRadius = (properties['cornerRadius'] ?? 20.0).toDouble().clamp(0.0, 60.0);
    final showShadow = properties['showShadow'] != false;
    final shadowOpacity = (properties['shadowOpacity'] ?? 0.25).toDouble().clamp(0.0, 1.0);

    final double containerHeight = thickness + 8;

    return SizedBox(
      width: width,
      height: containerHeight,
      child: Center(
        child: Container(
          width: width,
          height: thickness,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [startColor, endColor],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(cornerRadius),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: endColor.withOpacity(shadowOpacity),
                      blurRadius: cornerRadius,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
        ),
      ),
    );
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    Color startColor = Color(properties['startColor'] ?? const Color(0xFFFF8A65).value);
    Color endColor = Color(properties['endColor'] ?? const Color(0xFFF06292).value);
    double thickness = (properties['thickness'] ?? 8.0).toDouble();
    double cornerRadius = (properties['cornerRadius'] ?? 20.0).toDouble();
    bool showShadow = properties['showShadow'] != false;
    double shadowOpacity = (properties['shadowOpacity'] ?? 0.25).toDouble();

  thickness = thickness.clamp(2.0, 36.0).toDouble();
  cornerRadius = cornerRadius.clamp(0.0, 60.0).toDouble();
  shadowOpacity = shadowOpacity.clamp(0.0, 1.0).toDouble();

    final gradientPresets = <List<Color>>[
      [const Color(0xFFFF8A65), const Color(0xFFF06292)],
      [const Color(0xFF7C4DFF), const Color(0xFF536DFE)],
      [const Color(0xFF26C6DA), const Color(0xFF00ACC1)],
      [const Color(0xFFFFD54F), const Color(0xFFFF8F00)],
      [const Color(0xFFAB47BC), const Color(0xFF8E24AA)],
      [const Color(0xFF29B6F6), const Color(0xFF0288D1)],
    ];

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Edit Gradient Divider'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gradient Presets',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: gradientPresets.map((preset) {
                    final isSelected = startColor.value == preset[0].value && endColor.value == preset[1].value;
                    return GestureDetector(
                      onTap: () => setState(() {
                        startColor = preset[0];
                        endColor = preset[1];
                      }),
                      child: Container(
                        width: 64,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: preset,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF673AB7) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Thickness'),
                    Expanded(
                      child: Slider(
                        value: thickness,
                        min: 2,
                        max: 36,
                        divisions: 34,
                        label: '${thickness.toStringAsFixed(0)} px',
                        onChanged: (value) => setState(() => thickness = value),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Corner radius'),
                    Expanded(
                      child: Slider(
                        value: cornerRadius,
                        min: 0,
                        max: 60,
                        divisions: 30,
                        label: '${cornerRadius.toStringAsFixed(0)} px',
                        onChanged: (value) => setState(() => cornerRadius = value),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Glow shadow'),
                  value: showShadow,
                  onChanged: (value) => setState(() => showShadow = value),
                ),
                if (showShadow) Row(
                  children: [
                    const Text('Shadow strength'),
                    Expanded(
                      child: Slider(
                        value: shadowOpacity,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        label: shadowOpacity.toStringAsFixed(2),
                        onChanged: (value) => setState(() => shadowOpacity = value),
                      ),
                    ),
                  ],
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
                onUpdate({
                  'startColor': startColor.value,
                  'endColor': endColor.value,
                  'thickness': thickness,
                  'cornerRadius': cornerRadius,
                  'showShadow': showShadow,
                  'shadowOpacity': shadowOpacity,
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

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'gradientSeparator',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory GradientSeparatorComponent.fromJson(Map<String, dynamic> json) {
    return GradientSeparatorComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}