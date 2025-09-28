import 'package:flutter/material.dart';

/// Displays a simple color picker dialog based on a curated palette.
/// Returns the selected [Color] when the user taps "Select", or `null`
/// if they cancel the dialog.
Future<Color?> showColorPickerDialog({
  required BuildContext context,
  required Color initialColor,
  String title = 'Pick a Color',
  List<Color>? swatches,
}) async {
  final palette = swatches ?? _defaultPalette;
  Color selectedColor = initialColor;

  return showDialog<Color>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#${selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                      style: TextStyle(
                        color: selectedColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: palette.length,
                      itemBuilder: (context, index) {
                        final color = palette[index];
                        final isSelected = color.value == selectedColor.value;
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.black26,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.45),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 26)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, selectedColor),
                child: const Text('Select'),
              ),
            ],
          );
        },
      );
    },
  );
}

const List<Color> _defaultPalette = [
  Colors.white,
  Color(0xFFF5F5F5),
  Color(0xFFEEEEEE),
  Color(0xFF424242),
  Color(0xFF1E1E1E),
  Color(0xFF000000),
  Color(0xFFB71C1C),
  Color(0xFFD50000),
  Color(0xFFF06292),
  Color(0xFF9C27B0),
  Color(0xFF673AB7),
  Color(0xFF3F51B5),
  Color(0xFF2196F3),
  Color(0xFF03A9F4),
  Color(0xFF00BCD4),
  Color(0xFF009688),
  Color(0xFF4CAF50),
  Color(0xFF8BC34A),
  Color(0xFFCDDC39),
  Color(0xFFFFEB3B),
  Color(0xFFFFC107),
  Color(0xFFFF9800),
  Color(0xFFFF5722),
  Color(0xFF795548),
  Color(0xFF607D8B),
  const Color(0xFFB0BEC5),
  const Color(0xFFFFCDD2),
  const Color(0xFFFFF9C4),
];
