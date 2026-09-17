import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

/// Renders a pattern as a heat-fused, physical perler-bead product.
///
/// The coloured cells form a continuous, soft-edged melted surface. A regular
/// pitted light mask is then applied over that surface to recreate the pressed
/// plastic texture visible on a real finished piece.
class FinishedProductPainter extends CustomPainter {
  final Uint8List pixels;
  final int imageWidth;
  final int imageHeight;

  const FinishedProductPainter({
    required this.pixels,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF1F4F8), BlendMode.src);
    if (imageWidth <= 0 || imageHeight <= 0) return;

    // Paint on the full preview canvas, then fit the actual product inside it.
    // This makes the fit independent of InteractiveViewer's child layout.
    final scale = math.min(size.width / imageWidth, size.height / imageHeight);
    final productSize = Size(imageWidth * scale, imageHeight * scale);
    canvas.save();
    canvas.translate(
      (size.width - productSize.width) / 2,
      (size.height - productSize.height) / 2,
    );
    _paintProduct(canvas, productSize);
    canvas.restore();
  }

  void _paintProduct(Canvas canvas, Size size) {
    final cellWidth = size.width / imageWidth;
    final cellHeight = size.height / imageHeight;
    final beadSize = cellWidth < cellHeight ? cellWidth : cellHeight;

    // Render cells directly instead of clipping a path containing thousands
    // of rounded rectangles. On iOS, that very complex clip can truncate a
    // large chart halfway through its rows.
    for (var y = 0; y < imageHeight; y++) {
      for (var x = 0; x < imageWidth; x++) {
        final color = _colorAt(x, y);
        if (color == null) continue;
        final meltedRect = _meltedCellRRect(
          x,
          y,
          cellWidth,
          cellHeight,
          beadSize,
        );
        if (_isExposedCell(x, y)) {
          canvas.drawRRect(
            meltedRect.shift(Offset(0, beadSize * 0.07)),
            Paint()..color = const Color(0x421B2735),
          );
        }
        // Do not put a square fill underneath. A square base would survive at
        // every convex corner and make the finished piece look pixel-perfect.
        // The overlapping rounded cells deliberately leave only fused curves
        // at colour transitions and on the outside silhouette.
        canvas.drawRRect(meltedRect, Paint()..color = color);
        // A very restrained highlight around the softened rim adds the glossy
        // plastic catch-light visible on a heat-pressed bead surface.
        canvas.drawRRect(
          meltedRect.shift(Offset(-beadSize * 0.016, -beadSize * 0.02)),
          Paint()
            ..color = const Color(0x16FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = beadSize * 0.075,
        );
      }
    }

    _drawPressedTexture(
      canvas,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      beadSize: beadSize,
    );
  }

  bool _isExposedCell(int x, int y) {
    return _colorAt(x - 1, y) == null ||
        _colorAt(x + 1, y) == null ||
        _colorAt(x, y - 1) == null ||
        _colorAt(x, y + 1) == null;
  }

  RRect _meltedCellRRect(
    int x,
    int y,
    double cellWidth,
    double cellHeight,
    double beadSize,
  ) {
    // Let adjacent cells overlap more than a normal rounded rectangle. This
    // makes the perimeter read like softened, fused plastic instead of a
    // precise pixel-grid outline.
    final inset = beadSize * -0.24;
    final rect = Rect.fromLTWH(
      x * cellWidth + inset,
      y * cellHeight + inset,
      cellWidth - inset * 2,
      cellHeight - inset * 2,
    );
    // This intentionally exceeds the radius that an unexpanded cell could
    // have; RRect clamps it to a broad semicircle across the expanded cell.
    // The result removes the remaining right-angle look from each bead edge.
    return RRect.fromRectAndRadius(rect, Radius.circular(beadSize * 0.9));
  }

  void _drawPressedTexture(
    Canvas canvas, {
    required double cellWidth,
    required double cellHeight,
    required double beadSize,
  }) {
    // The small, regular dimples are a light mask on top of the continuous
    // colour plane. They are intentionally much finer than the source cells,
    // so the surface reads as pressed plastic rather than a grid of buttons.
    final pits = <Offset>[];
    final glints = <Offset>[];
    final positions = imageWidth * imageHeight > 4096
        ? const [0.29, 0.71]
        : const [0.20, 0.50, 0.80];
    for (var y = 0; y < imageHeight; y++) {
      for (var x = 0; x < imageWidth; x++) {
        if (_colorAt(x, y) == null) continue;
        glints.add(
          Offset(
            x * cellWidth + cellWidth * 0.27,
            y * cellHeight + cellHeight * 0.25,
          ),
        );
        for (final dy in positions) {
          for (final dx in positions) {
            pits.add(
              Offset(
                x * cellWidth + cellWidth * dx,
                y * cellHeight + cellHeight * dy,
              ),
            );
          }
        }
      }
    }
    if (pits.isEmpty) return;

    final shadowPits = [
      for (final pit in pits) pit + Offset(beadSize * 0.038, beadSize * 0.044),
    ];
    canvas.drawPoints(
      PointMode.points,
      shadowPits,
      Paint()
        ..color = const Color(0x42000000)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = beadSize * 0.16,
    );
    final highlightPits = [
      for (final pit in pits) pit - Offset(beadSize * 0.038, beadSize * 0.044),
    ];
    canvas.drawPoints(
      PointMode.points,
      highlightPits,
      Paint()
        ..color = const Color(0x3AFFFFFF)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = beadSize * 0.11,
    );

    // One larger but translucent glint per source cell makes the texture read
    // as a single pressed-plastic surface under a light, not printed noise.
    canvas.drawPoints(
      PointMode.points,
      glints,
      Paint()
        ..color = const Color(0x1CFFFFFF)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = beadSize * 0.22,
    );
  }

  Color? _colorAt(int x, int y) {
    if (x < 0 || y < 0 || x >= imageWidth || y >= imageHeight) return null;
    final offset = (y * imageWidth + x) * 4;
    if (offset + 3 >= pixels.length || pixels[offset + 3] == 0) return null;
    return Color.fromARGB(
      pixels[offset + 3],
      pixels[offset],
      pixels[offset + 1],
      pixels[offset + 2],
    );
  }

  @override
  bool shouldRepaint(covariant FinishedProductPainter oldDelegate) {
    return oldDelegate.pixels != pixels ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
