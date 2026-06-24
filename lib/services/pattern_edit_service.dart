import 'dart:math';
import 'dart:typed_data';

import '../algorithms/color_reducer.dart';
import '../models/color.dart';
import '../models/generated_pattern.dart';
import '../models/palette.dart';

class CellChange {
  final int x;
  final int y;
  final BeadColor before;
  final BeadColor after;

  const CellChange({
    required this.x,
    required this.y,
    required this.before,
    required this.after,
  });
}

class PatternEditService {
  List<CellChange> paint({
    required Uint8List pixels,
    required int width,
    required int height,
    required int x,
    required int y,
    required int brushSize,
    required BeadColor color,
  }) {
    return _apply(
      pixels: pixels,
      width: width,
      height: height,
      x: x,
      y: y,
      brushSize: brushSize,
      color: color,
    );
  }

  List<CellChange> erase({
    required Uint8List pixels,
    required int width,
    required int height,
    required int x,
    required int y,
    required int brushSize,
  }) {
    return _apply(
      pixels: pixels,
      width: width,
      height: height,
      x: x,
      y: y,
      brushSize: brushSize,
      color: BeadColor.fromInt(0, 0, 0, 0),
    );
  }

  BeadColor pick({
    required Uint8List pixels,
    required int width,
    required int x,
    required int y,
  }) {
    final offset = (y * width + x) * 4;
    return BeadColor.fromInt(
      pixels[offset],
      pixels[offset + 1],
      pixels[offset + 2],
      pixels[offset + 3],
    );
  }

  GeneratedPattern applyEditedPixels({
    required GeneratedPattern pattern,
    required Uint8List pixels,
  }) {
    final palette = Palette(name: 'active', entries: pattern.paletteEntries);
    return pattern.copyWith(
      pixels: Uint8List.fromList(pixels),
      usage: computeUsage(pixels, pattern.width, pattern.height, [palette]),
    );
  }

  List<CellChange> _apply({
    required Uint8List pixels,
    required int width,
    required int height,
    required int x,
    required int y,
    required int brushSize,
    required BeadColor color,
  }) {
    final changes = <CellChange>[];
    final radius = max(0, brushSize - 1);
    for (int cy = y - radius; cy <= y + radius; cy++) {
      for (int cx = x - radius; cx <= x + radius; cx++) {
        if (cx < 0 || cy < 0 || cx >= width || cy >= height) continue;
        final offset = (cy * width + cx) * 4;
        final before = BeadColor.fromInt(
          pixels[offset],
          pixels[offset + 1],
          pixels[offset + 2],
          pixels[offset + 3],
        );
        final after = color.clone();
        if (before == after) continue;
        pixels[offset] = after.rInt;
        pixels[offset + 1] = after.gInt;
        pixels[offset + 2] = after.bInt;
        pixels[offset + 3] = after.aInt;
        changes.add(CellChange(x: cx, y: cy, before: before, after: after));
      }
    }
    return changes;
  }
}
