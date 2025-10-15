import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DynamicFormBuilderEnhanced {
  /// Build grouped form fields with beautiful styling
  static List<Widget> buildGroupedFields({
    required List<Map<String, dynamic>> fields,
    required Map<String, TextEditingController> controllers,
  }) {
    // Group fields by their group property
    final Map<String, List<Map<String, dynamic>>> groupedFields = {};
    
    for (var field in fields) {
      final group = field['group'] as String? ?? 'General';
      if (!groupedFields.containsKey(group)) {
        groupedFields[group] = [];
      }
      groupedFields[group]!.add(field);
    }

    // Sort fields within each group by order
    groupedFields.forEach((key, fieldList) {
      fieldList.sort((a, b) {
        final orderA = a['order'] as int? ?? 0;
        final orderB = b['order'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });
    });

    // Build widgets for each group
    List<Widget> widgets = [];
    
    groupedFields.forEach((groupName, fieldList) {
      if (fieldList.isEmpty) return;
      
      final firstField = fieldList.first;
      final groupColor = firstField['groupColor'] as String? ?? 'blue';
      final groupIcon = firstField['groupIcon'] as String? ?? 'info';
      
      widgets.add(_buildGroupSection(
        groupName: groupName,
        fields: fieldList,
        controllers: controllers,
        color: groupColor,
        icon: groupIcon,
      ));
      
      widgets.add(const SizedBox(height: 20));
    });

    return widgets;
  }

  /// Build a single group section with gradient container
  static Widget _buildGroupSection({
    required String groupName,
    required List<Map<String, dynamic>> fields,
    required Map<String, TextEditingController> controllers,
    required String color,
    required String icon,
  }) {
    final colors = _getGradientColors(color);
    final iconData = _getIconData(icon);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    groupName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Fields
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: fields.map((field) {
                final name = field['name'] as String;
                final controller = controllers[name] ?? TextEditingController();
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildStyledField(
                    fieldConfig: field,
                    controller: controller,
                    accentColor: colors[0],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single field with styling
  static Widget _buildStyledField({
    required Map<String, dynamic> fieldConfig,
    required TextEditingController controller,
    required Color accentColor,
  }) {
    final String type = fieldConfig['type'] as String;
    final String label = fieldConfig['label'] as String;
    final bool required = fieldConfig['required'] as bool? ?? false;
    final String? placeholder = fieldConfig['placeholder'] as String?;
    final List<dynamic>? options = fieldConfig['options'] as List<dynamic>?;

    final decoration = InputDecoration(
      labelText: label + (required ? ' *' : ''),
      hintText: placeholder,
      labelStyle: TextStyle(
        color: Colors.grey.shade700,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accentColor, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2.5),
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(14),
        child: Icon(_getIconForType(type), color: accentColor, size: 24),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );

    switch (type) {
      case 'text':
      case 'email':
      case 'phone':
      case 'number':
        return TextFormField(
          controller: controller,
          decoration: decoration,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
          keyboardType: _getKeyboardType(type),
          validator: required ? (val) => val?.isEmpty == true ? '$label is required' : null : null,
        );

      case 'textarea':
        return TextFormField(
          controller: controller,
          decoration: decoration.copyWith(
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
            height: 1.5,
          ),
          maxLines: 5,
          validator: required ? (val) => val?.isEmpty == true ? '$label is required' : null : null,
        );

      case 'date':
        return _buildDateField(
          controller: controller,
          decoration: decoration,
          label: label,
          required: required,
          accentColor: accentColor,
        );

      case 'dropdown':
        if (options == null || options.isEmpty) {
          return const Text('No options provided for dropdown');
        }
        return DropdownButtonFormField<String>(
          value: controller.text.isEmpty ? null : controller.text,
          decoration: decoration,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
          dropdownColor: Colors.white,
          icon: Icon(Icons.arrow_drop_down_rounded, color: accentColor, size: 32),
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt.toString(),
              child: Text(opt.toString()),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) controller.text = value;
          },
          validator: required ? (val) => val == null ? '$label is required' : null : null,
        );

      case 'checkbox':
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: CheckboxListTile(
            title: Text(
              label + (required ? ' *' : ''),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            value: controller.text == 'true',
            onChanged: (value) {
              controller.text = value.toString();
            },
            activeColor: accentColor,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        );

      default:
        return Text('Unsupported field type: $type');
    }
  }

  /// Build date field with picker
  static Widget _buildDateField({
    required TextEditingController controller,
    required InputDecoration decoration,
    required String label,
    required bool required,
    required Color accentColor,
  }) {
    return Builder(
      builder: (BuildContext context) {
        return TextFormField(
          controller: controller,
          decoration: decoration.copyWith(
            suffixIcon: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(Icons.calendar_today_rounded, color: accentColor, size: 22),
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
          readOnly: true,
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: accentColor,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                    ),
                    dialogBackgroundColor: Colors.white,
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              controller.text = DateFormat('dd/MM/yyyy').format(picked);
            }
          },
          validator: required ? (val) => val?.isEmpty == true ? '$label is required' : null : null,
        );
      },
    );
  }

  /// Get gradient colors for a group
  static List<Color> _getGradientColors(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'blue':
        return [const Color(0xFF2196F3), const Color(0xFF1976D2)];
      case 'purple':
        return [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)];
      case 'green':
        return [const Color(0xFF4CAF50), const Color(0xFF388E3C)];
      case 'orange':
        return [const Color(0xFFFF9800), const Color(0xFFF57C00)];
      case 'red':
        return [const Color(0xFFF44336), const Color(0xFFD32F2F)];
      case 'teal':
        return [const Color(0xFF009688), const Color(0xFF00796B)];
      case 'pink':
        return [const Color(0xFFE91E63), const Color(0xFFC2185B)];
      default:
        return [const Color(0xFF2196F3), const Color(0xFF1976D2)];
    }
  }

  /// Get icon data for a group
  static IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'person':
        return Icons.person;
      case 'phone':
        return Icons.phone;
      case 'school':
        return Icons.school;
      case 'medical':
        return Icons.medical_services;
      case 'location':
        return Icons.location_on;
      case 'calendar':
        return Icons.calendar_today;
      case 'star':
        return Icons.star;
      default:
        return Icons.info;
    }
  }

  /// Get icon for field type
  static IconData _getIconForType(String type) {
    switch (type) {
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'number':
        return Icons.numbers;
      case 'date':
        return Icons.calendar_today;
      case 'dropdown':
        return Icons.arrow_drop_down_circle;
      case 'checkbox':
        return Icons.check_box;
      case 'textarea':
        return Icons.subject;
      default:
        return Icons.edit;
    }
  }

  /// Get keyboard type for field type
  static TextInputType _getKeyboardType(String type) {
    switch (type) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }
}
