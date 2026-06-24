import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/project.dart';

class BeadPainter extends CustomPainter {
  final Uint8List pixels;
  final int imageWidth;
  final int imageHeight;
  final double beadSize;
  final Project project;
  final bool showGrid;

  BeadPainter({
    required this.pixels,
    required this.imageWidth,
    required this.imageHeight,
    this.beadSize = 12.0,
    required this.project,
    this.showGrid = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFE5E5E5);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final beadPaint = Paint()..style = PaintingStyle.fill;
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE5E5E5);

    for (int y = 0; y < imageHeight; y++) {
      for (int x = 0; x < imageWidth; x++) {
        final offset = (y * imageWidth + x) * 4;
        final a = pixels[offset + 3];
        if (a == 0) continue;

        final r = pixels[offset];
        final g = pixels[offset + 1];
        final b = pixels[offset + 2];

        final cx = x * beadSize + beadSize / 2;
        final cy = y * beadSize + beadSize / 2;

        beadPaint.color = Color.fromARGB(255, r, g, b);
        canvas.drawCircle(Offset(cx, cy), beadSize / 2, beadPaint);
        canvas.drawCircle(Offset(cx, cy), beadSize / 6, centerPaint);
      }
    }

    if (showGrid) {
      _drawGrid(canvas);
    }
  }

  void _drawGrid(Canvas canvas) {
    final gridPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final boardBeads = project.boardType.beadsPerSide;
    for (int bx = 0; bx <= project.boardsX; bx++) {
      final x = bx * boardBeads * beadSize;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, imageHeight * beadSize),
        gridPaint,
      );
    }
    for (int by = 0; by <= project.boardsY; by++) {
      final y = by * boardBeads * beadSize;
      canvas.drawLine(
        Offset(0, y),
        Offset(imageWidth * beadSize, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BeadPainter oldDelegate) {
    return oldDelegate.pixels != pixels ||
        oldDelegate.beadSize != beadSize ||
        oldDelegate.showGrid != showGrid;
  }
}
