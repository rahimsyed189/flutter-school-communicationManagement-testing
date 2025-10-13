import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DynamicFormBuilder {
  /// Build a form field widget from configuration
  static Widget buildField({
    required Map<String, dynamic> fieldConfig,
    required TextEditingController controller,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    dynamic value,
  }) {
    final String type = fieldConfig['type'] as String;
    final String label = fieldConfig['label'] as String;
    final bool required = fieldConfig['required'] as bool? ?? false;
    final String? placeholder = fieldConfig['placeholder'] as String?;
    final List<dynamic>? options = fieldConfig['options'] as List<dynamic>?;

    switch (type) {
      case 'text':
      case 'email':
      case 'phone':
      case 'number':
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label + (required ? ' *' : ''),
            hintText: placeholder,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(_getIconForType(type)),
          ),
          keyboardType: _getKeyboardType(type),
          validator: validator ?? (required ? (val) => val?.isEmpty == true ? '$label is required' : null : null),
          onChanged: onChanged,
        );

      case 'textarea':
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label + (required ? ' *' : ''),
            hintText: placeholder,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.subject),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          validator: validator ?? (required ? (val) => val?.isEmpty == true ? '$label is required' : null : null),
          onChanged: onChanged,
        );

      case 'dropdown':
        return DropdownButtonFormField<String>(
          value: value as String?,
          decoration: InputDecoration(
            labelText: label + (required ? ' *' : ''),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.arrow_drop_down_circle),
          ),
          items: (options ?? []).map((option) {
            return DropdownMenuItem<String>(
              value: option.toString(),
              child: Text(option.toString()),
            );
          }).toList(),
          validator: validator ?? (required ? (val) => val?.isEmpty == true ? 'Please select $label' : null : null),
          onChanged: (newValue) {
            controller.text = newValue ?? '';
            if (onChanged != null) onChanged(newValue ?? '');
          },
        );

      case 'date':
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label + (required ? ' *' : ''),
            hintText: placeholder ?? 'Select date',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.calendar_today),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          readOnly: true,
          validator: validator ?? (required ? (val) => val?.isEmpty == true ? '$label is required' : null : null),
          onTap: () async {
            final context = controller.text.isNotEmpty ? null : null; // We need context from parent
            // This will be handled by the parent widget
          },
        );

      case 'checkbox':
        return CheckboxListTile(
          title: Text(label),
          value: value as bool? ?? false,
          onChanged: (newValue) {
            controller.text = newValue.toString();
            if (onChanged != null) onChanged(newValue.toString());
          },
          controlAffinity: ListTileControlAffinity.leading,
        );

      default:
        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label + (required ? ' *' : ''),
            hintText: placeholder,
            border: const OutlineInputBorder(),
          ),
          validator: validator ?? (required ? (val) => val?.isEmpty == true ? '$label is required' : null : null),
          onChanged: onChanged,
        );
    }
  }

  /// Build a date field with date picker
  static Widget buildDateField({
    required BuildContext context,
    required Map<String, dynamic> fieldConfig,
    required TextEditingController controller,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    final String label = fieldConfig['label'] as String;
    final bool required = fieldConfig['required'] as bool? ?? false;
    final String? placeholder = fieldConfig['placeholder'] as String?;

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        hintText: placeholder ?? 'Tap to select date',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      readOnly: true,
      validator: validator ?? (required ? (val) => val?.isEmpty == true ? '$label is required' : null : null),
      onTap: onTap,
    );
  }

  /// Get keyboard type based on field type
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

  /// Get icon based on field type
  static IconData _getIconForType(String type) {
    switch (type) {
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'number':
        return Icons.numbers;
      case 'text':
        return Icons.text_fields;
      default:
        return Icons.input;
    }
  }

  /// Show date picker and format result
  static Future<String?> showDatePickerDialog({
    required BuildContext context,
    DateTime? initialDate,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      return DateFormat('dd/MM/yyyy').format(picked);
    }
    return null;
  }

  /// Parse date string to DateTime
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateFormat('dd/MM/yyyy').parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Format DateTime to display string
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
