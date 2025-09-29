import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'color_picker_dialog.dart';

// Helper function for HSV color picker
Future<Color?> _showHSVColorPicker(
  BuildContext context,
  Color currentColor,
  String title,
) async {
  Color selectedColor = currentColor;
  
  return await showDialog<Color>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: currentColor,
          onColorChanged: (color) => selectedColor = color,
          pickerAreaHeightPercent: 0.8,
          enableAlpha: false,
          displayThumbColor: true,
          paletteType: PaletteType.hsv,
          labelTypes: const [],
          pickerAreaBorderRadius: BorderRadius.circular(8),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(selectedColor),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Select'),
        ),
      ],
    ),
  );
}

// Helper function to get Google Fonts TextStyle
TextStyle _getGoogleFontStyle(String fontFamily) {
  try {
    switch (fontFamily.toLowerCase()) {
      case 'roboto':
        return GoogleFonts.roboto();
      case 'poppins':
        return GoogleFonts.poppins();
      case 'lato':
        return GoogleFonts.lato();
      case 'nunito':
        return GoogleFonts.nunito();
      case 'montserrat':
        return GoogleFonts.montserrat();
      case 'open sans':
        return GoogleFonts.openSans();
      case 'merriweather':
        return GoogleFonts.merriweather();
      case 'default':
      default:
        return GoogleFonts.roboto();
    }
  } catch (e) {
    // Fallback to system font if Google Fonts fails
    return const TextStyle();
  }
}

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
  gradientDivider,
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
      case 'gradientDivider':
        return GradientDividerComponent.fromJson(json);
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
            'fontFamily': 'Default',
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
    final fontFamily = properties['fontFamily'] ?? 'Default';
    
    // Text shadow properties
    final hasShadow = properties['hasShadow'] == true;
    final shadowColor = Color(properties['shadowColor'] ?? 0xFF000000);
    final shadowOffsetX = properties['shadowOffsetX']?.toDouble() ?? 1.0;
    final shadowOffsetY = properties['shadowOffsetY']?.toDouble() ?? 1.0;
    final shadowBlurRadius = properties['shadowBlurRadius']?.toDouble() ?? 2.0;

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
        style: _getGoogleFontStyle(fontFamily).copyWith(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
          shadows: hasShadow
              ? [
                  Shadow(
                    color: shadowColor,
                    offset: Offset(shadowOffsetX, shadowOffsetY),
                    blurRadius: shadowBlurRadius,
                  ),
                ]
              : null,
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
            'fontFamily': 'Default',
            'fontWeight': 'normal',
            'textAlign': 'left',
            'borderWidth': 1.0,
            'borderRadius': 8.0,
            'lineHeight': 1.4,
            'letterSpacing': 0.0,
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
    final String fontFamily = properties['fontFamily'] ?? 'Default';
    final String fontWeightKey = properties['fontWeight'] ?? 'normal';
    final String textAlignKey = properties['textAlign'] ?? 'left';
    final double borderWidth = properties['borderWidth']?.toDouble() ?? 1.0;
    final double borderRadius = properties['borderRadius']?.toDouble() ?? 8.0;
    final double lineHeight = properties['lineHeight']?.toDouble() ?? 1.4;
    final double letterSpacing = properties['letterSpacing']?.toDouble() ?? 0.0;
    
    // Text shadow properties
    final hasShadow = properties['hasShadow'] == true;
    final shadowColor = Color(properties['shadowColor'] ?? 0xFF000000);
    final shadowOffsetX = properties['shadowOffsetX']?.toDouble() ?? 1.0;
    final shadowOffsetY = properties['shadowOffsetY']?.toDouble() ?? 1.0;
    final shadowBlurRadius = properties['shadowBlurRadius']?.toDouble() ?? 2.0;

    FontWeight fontWeight;
    switch (fontWeightKey) {
      case 'bold':
        fontWeight = FontWeight.bold;
        break;
      case 'semiBold':
        fontWeight = FontWeight.w600;
        break;
      case 'light':
        fontWeight = FontWeight.w300;
        break;
      default:
        fontWeight = FontWeight.normal;
    }

    TextAlign textAlign;
    switch (textAlignKey) {
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
      default:
        textAlign = TextAlign.left;
    }

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: SingleChildScrollView(
        child: Text(
          text,
          style: _getGoogleFontStyle(fontFamily).copyWith(
            fontSize: fontSize,
            color: textColor,
            fontWeight: fontWeight,
            height: lineHeight,
            letterSpacing: letterSpacing,
            shadows: hasShadow
                ? [
                    Shadow(
                      color: shadowColor,
                      offset: Offset(shadowOffsetX, shadowOffsetY),
                      blurRadius: shadowBlurRadius,
                    ),
                  ]
                : null,
          ),
          textAlign: textAlign,
        ),
      ),
    );
  }

  @override
  Widget buildEditDialog(BuildContext context, Function(Map<String, dynamic>) onUpdate) {
    final textController = TextEditingController(text: properties['text'] ?? '');
    double fontSize = properties['fontSize']?.toDouble() ?? 14.0;
    double padding = properties['padding']?.toDouble() ?? 12.0;
    double borderWidth = properties['borderWidth']?.toDouble() ?? 1.0;
    double borderRadius = properties['borderRadius']?.toDouble() ?? 8.0;
    double lineHeight = properties['lineHeight']?.toDouble() ?? 1.4;
    double letterSpacing = properties['letterSpacing']?.toDouble() ?? 0.0;
    String fontFamily = properties['fontFamily'] ?? 'Default';
    String fontWeight = properties['fontWeight'] ?? 'normal';
    String textAlign = properties['textAlign'] ?? 'left';
    Color textColor = Color(properties['textColor'] ?? Colors.black87.value);
    Color backgroundColor = Color(properties['backgroundColor'] ?? Colors.white.value);
    Color borderColor = Color(properties['borderColor'] ?? Colors.grey.value);

    const fontFamilies = [
      'Default',
      'Roboto',
      'Poppins',
      'Montserrat',
      'Lato',
      'Raleway',
      'Georgia',
      'Courier New',
    ];

    final fontWeights = <Map<String, dynamic>>[
      {'label': 'Light', 'value': 'light'},
      {'label': 'Normal', 'value': 'normal'},
      {'label': 'Semi Bold', 'value': 'semiBold'},
      {'label': 'Bold', 'value': 'bold'},
    ];

    final alignmentOptions = <Map<String, dynamic>>[
      {'label': 'Left', 'value': 'left', 'icon': Icons.format_align_left},
      {'label': 'Center', 'value': 'center', 'icon': Icons.format_align_center},
      {'label': 'Right', 'value': 'right', 'icon': Icons.format_align_right},
      {'label': 'Justify', 'value': 'justify', 'icon': Icons.format_align_justify},
    ];

    Widget buildColorSelector(String label, Color color, ValueChanged<Color> onChanged) {
      return Row(
        children: [
          Expanded(child: Text(label)),
          GestureDetector(
            onTap: () async {
              final result = await showColorPickerDialog(
                context: context,
                initialColor: color,
                title: label,
              );
              if (result != null) {
                onChanged(result);
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
            ),
          ),
        ],
      );
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 400,
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
                        'Edit Text Box',
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
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Text Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(color: borderColor, width: borderWidth),
                  ),
                  child: Text(
                    textController.text.isEmpty ? 'Sample preview content' : textController.text,
                    textAlign: () {
                      switch (textAlign) {
                        case 'center':
                          return TextAlign.center;
                        case 'right':
                          return TextAlign.right;
                        case 'justify':
                          return TextAlign.justify;
                        default:
                          return TextAlign.left;
                      }
                    }(),
                    style: _getGoogleFontStyle(fontFamily).copyWith(
                      fontSize: fontSize,
                      color: textColor,
                      height: lineHeight,
                      letterSpacing: letterSpacing,
                      fontWeight: () {
                        switch (fontWeight) {
                          case 'light':
                            return FontWeight.w300;
                          case 'semiBold':
                            return FontWeight.w600;
                          case 'bold':
                            return FontWeight.bold;
                          default:
                            return FontWeight.normal;
                        }
                      }(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Typography', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    const Text('Font Size'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 10,
                        max: 36,
                        divisions: 26,
                        label: fontSize.toStringAsFixed(0),
                        onChanged: (value) => setState(() => fontSize = value),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(fontSize.toStringAsFixed(0), textAlign: TextAlign.right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: fontFamily,
                  decoration: const InputDecoration(
                    labelText: 'Font Family',
                    border: OutlineInputBorder(),
                  ),
                  items: fontFamilies
                      .map((family) => DropdownMenuItem(
                            value: family,
                            child: Text(family),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => fontFamily = value ?? 'Default'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: fontWeight,
                  decoration: const InputDecoration(
                    labelText: 'Font Weight',
                    border: OutlineInputBorder(),
                  ),
                  items: fontWeights
                      .map((option) => DropdownMenuItem(
                            value: option['value'] as String,
                            child: Text(option['label'] as String),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => fontWeight = value ?? 'normal'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Line Height'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: lineHeight,
                        min: 1.0,
                        max: 2.0,
                        divisions: 20,
                        label: lineHeight.toStringAsFixed(1),
                        onChanged: (value) => setState(() => lineHeight = value),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(lineHeight.toStringAsFixed(1), textAlign: TextAlign.right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Letter Spacing'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: letterSpacing,
                        min: -1.0,
                        max: 4.0,
                        divisions: 50,
                        label: letterSpacing.toStringAsFixed(1),
                        onChanged: (value) => setState(() => letterSpacing = value),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(letterSpacing.toStringAsFixed(1), textAlign: TextAlign.right),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Alignment', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: alignmentOptions.map((option) {
                    final isSelected = textAlign == option['value'];
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(option['icon'] as IconData, size: 18),
                          const SizedBox(width: 4),
                          Text(option['label'] as String),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) => setState(() => textAlign = option['value'] as String),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Colors', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                buildColorSelector('Text Color', textColor, (color) => setState(() => textColor = color)),
                const SizedBox(height: 12),
                buildColorSelector('Background Color', backgroundColor, (color) => setState(() => backgroundColor = color)),
                const SizedBox(height: 12),
                buildColorSelector('Border Color', borderColor, (color) => setState(() => borderColor = color)),
                const SizedBox(height: 16),
                const Text('Layout', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    const Text('Padding'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: padding,
                        min: 0,
                        max: 40,
                        divisions: 40,
                        label: padding.toStringAsFixed(0),
                        onChanged: (value) => setState(() => padding = value),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(padding.toStringAsFixed(0), textAlign: TextAlign.right),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Border Width'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: borderWidth,
                        min: 0,
                        max: 8,
                        divisions: 32,
                        label: borderWidth.toStringAsFixed(1),
                        onChanged: (value) => setState(() => borderWidth = value),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(borderWidth.toStringAsFixed(1), textAlign: TextAlign.right),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Border Radius'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: borderRadius,
                        min: 0,
                        max: 40,
                        divisions: 40,
                        label: borderRadius.toStringAsFixed(0),
                        onChanged: (value) => setState(() => borderRadius = value),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(borderRadius.toStringAsFixed(0), textAlign: TextAlign.right),
                    ),
                  ],
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
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          onUpdate({
                            'text': textController.text,
                            'fontSize': fontSize,
                            'padding': padding,
                            'borderWidth': borderWidth,
                            'borderRadius': borderRadius,
                            'lineHeight': lineHeight,
                            'letterSpacing': letterSpacing,
                            'fontFamily': fontFamily,
                            'fontWeight': fontWeight,
                            'textAlign': textAlign,
                            'textColor': textColor.value,
                            'backgroundColor': backgroundColor.value,
                            'borderColor': borderColor.value,
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Update'),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
              ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade600,
            foregroundColor: Colors.white,
          ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
              ),
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

class GradientDividerComponent extends DraggableComponent {
  GradientDividerComponent({
    required String id,
    required double x,
    required double y,
    Map<String, dynamic>? properties,
  }) : super(
          id: id, 
          x: x, 
          y: y, 
          width: 200, 
          height: 4, 
          properties: properties ?? {
            'color1': 0xFF6366F1, // Modern indigo
            'color2': 0xFF8B5CF6, // Modern purple
            'height': 4.0,
            'width': 200.0,
            'cornerRadius': 2.0,
            'padding': 0.0, // No padding
          }, 
          type: ComponentType.gradientDivider,
        );

  @override
  ComponentType get type => ComponentType.gradientDivider;

  @override
  Widget buildWidget() {
    List<Color> gradientColors = [
      Color(properties['color1'] ?? 0xFF2196F3),
      Color(properties['color2'] ?? 0xFF21CBF3),
    ];
    double dividerHeight = properties['height']?.toDouble() ?? 4.0;
    double dividerWidth = properties['width']?.toDouble() ?? width;
    double cornerRadius = properties['cornerRadius']?.toDouble() ?? 2.0;
    
    return Container(
      width: dividerWidth,
      height: dividerHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  @override
  Widget buildEditDialog(
    BuildContext context,
    Function(Map<String, dynamic>) onUpdate,
  ) {
    Color color1 = Color(properties['color1'] ?? 0xFF2196F3);
    Color color2 = Color(properties['color2'] ?? 0xFF21CBF3);
    double dividerHeight = properties['height']?.toDouble() ?? 4.0;
    double dividerWidth = properties['width']?.toDouble() ?? 200.0;
    double cornerRadius = properties['cornerRadius']?.toDouble() ?? 2.0;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Edit Gradient Divider'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Width: '),
                    Expanded(
                      child: Slider(
                        value: dividerWidth,
                        min: 50,
                        max: 400,
                        divisions: 35,
                        label: dividerWidth.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            dividerWidth = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Height: '),
                    Expanded(
                      child: Slider(
                        value: dividerHeight,
                        min: 1,
                        max: 20,
                        divisions: 19,
                        label: dividerHeight.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            dividerHeight = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Corner Radius: '),
                    Expanded(
                      child: Slider(
                        value: cornerRadius,
                        min: 0,
                        max: 10,
                        divisions: 20,
                        label: cornerRadius.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            cornerRadius = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const Text('Start Color'),
                        const SizedBox(height: 8),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color1,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final newColor = await _showHSVColorPicker(
                                  context,
                                  color1,
                                  'Select Start Color',
                                );
                                if (newColor != null) {
                                  setState(() {
                                    color1 = newColor;
                                  });
                                }
                              },
                              child: Container(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('End Color'),
                        const SizedBox(height: 8),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color2,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final newColor = await _showHSVColorPicker(
                                  context,
                                  color2,
                                  'Select End Color',
                                );
                                if (newColor != null) {
                                  setState(() {
                                    color2 = newColor;
                                  });
                                }
                              },
                              child: Container(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: dividerWidth * 0.8,
                  height: dividerHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cornerRadius),
                    gradient: LinearGradient(
                      colors: [color1, color2],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
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
                  'color1': color1.value,
                  'color2': color2.value,
                  'height': dividerHeight,
                  'width': dividerWidth,
                  'cornerRadius': cornerRadius,
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
              ),
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
      'type': 'gradientDivider',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': properties,
    };
  }

  factory GradientDividerComponent.fromJson(Map<String, dynamic> json) {
    return GradientDividerComponent(
      id: json['id'],
      x: json['x']?.toDouble() ?? 0,
      y: json['y']?.toDouble() ?? 0,
      properties: json['properties'],
    );
  }
}

