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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick color options including transparent
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Options',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Transparent option
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop(Colors.transparent);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.grey.shade400, width: 2),
                            ),
                            child: Icon(
                              Icons.clear,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                        ),
                        // Common colors
                        ...[
                          Colors.white,
                          Colors.black,
                          Colors.red,
                          Colors.blue,
                          Colors.green,
                          Colors.orange,
                          Colors.purple,
                          Colors.grey,
                        ].map((color) => GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop(color);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: color == Colors.white ? Colors.grey.shade400 : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        )).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Advanced color picker
              SizedBox(
                width: 300,
                height: 350,
                child: ColorPicker(
                  pickerColor: selectedColor,
                  onColorChanged: (Color color) {
                    selectedColor = color;
                  },
                  displayThumbColor: true,
                  enableAlpha: true, // Enable transparency/alpha support
                  pickerAreaHeightPercent: 0.7,
                  labelTypes: const [],
                  paletteType: PaletteType.hsv,
                ),
              ),
            ],
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
