import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// Displays an HSV color picker dialog.
/// Returns the selected [Color] when the user taps "Select", or `null`
/// if they cancel the dialog.
Future<Color?> showColorPickerDialog({
  required BuildContext context,
  required Color initialColor,
  String title = 'Pick a Color',
  List<Color>? swatches, // Kept for compatibility but not used
}) async {
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
