import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../rendering/bead_painter.dart';

class PatternPreview extends StatelessWidget {
  final Uint8List pixels;
  final int width;
  final int height;
  final bool showGrid;

  const PatternPreview({
    super.key,
    required this.pixels,
    required this.width,
    required this.height,
    this.showGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitBeadSize = (constraints.maxWidth / width).clamp(
          1.0,
          constraints.maxHeight / height,
        );
        final canvasWidth = width * fitBeadSize;
        final canvasHeight = height * fitBeadSize;

        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 12,
          child: Center(
            child: CustomPaint(
              size: Size(canvasWidth, canvasHeight),
              painter: BeadPainter(
                pixels: pixels,
                imageWidth: width,
                imageHeight: height,
                beadSize: fitBeadSize,
                project: Project(),
                showGrid: showGrid,
              ),
            ),
          ),
        );
      },
    );
  }
}
