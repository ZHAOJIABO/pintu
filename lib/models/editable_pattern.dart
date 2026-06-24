import 'dart:typed_data';

import '../models/color.dart';
import 'generated_pattern.dart';

enum EditorTool { picker, brush, eraser }

class EditablePattern {
  final Uint8List pixels;
  final int width;
  final int height;
  final BeadColor? selectedColor;
  final EditorTool activeTool;
  final int brushSize;

  const EditablePattern({
    required this.pixels,
    required this.width,
    required this.height,
    this.selectedColor,
    this.activeTool = EditorTool.brush,
    this.brushSize = 1,
  });

  factory EditablePattern.fromGenerated(GeneratedPattern pattern) {
    return EditablePattern(
      pixels: Uint8List.fromList(pattern.pixels),
      width: pattern.width,
      height: pattern.height,
    );
  }

  EditablePattern copyWith({
    Uint8List? pixels,
    BeadColor? selectedColor,
    EditorTool? activeTool,
    int? brushSize,
  }) {
    return EditablePattern(
      pixels: pixels ?? this.pixels,
      width: width,
      height: height,
      selectedColor: selectedColor ?? this.selectedColor,
      activeTool: activeTool ?? this.activeTool,
      brushSize: brushSize ?? this.brushSize,
    );
  }
}
