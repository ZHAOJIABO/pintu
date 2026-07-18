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

/// A compact undo payload for replacing one colour across a whole drawing.
///
/// Each changed cell only needs its linear index because every cell shares the
/// same before and after colour. This avoids retaining duplicate colour
/// objects for every bead in a large palette replacement.
class ColorReplacement {
  final Uint32List cellIndexes;
  final BeadColor before;
  final BeadColor after;

  const ColorReplacement({
    required this.cellIndexes,
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

  /// Replaces every bead matching [from] with [to].
  ///
  /// The returned changes can be recorded as one history entry, so a palette
  /// replacement is undone and redone atomically.
  List<CellChange> replaceColor({
    required Uint8List pixels,
    required int width,
    required int height,
    required BeadColor from,
    required BeadColor to,
  }) {
    if (from == to) return const <CellChange>[];

    final fromRed = from.rInt;
    final fromGreen = from.gInt;
    final fromBlue = from.bInt;
    final fromAlpha = from.aInt;
    final toRed = to.rInt;
    final toGreen = to.gInt;
    final toBlue = to.bInt;
    final toAlpha = to.aInt;
    final changes = <CellChange>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        if (pixels[offset] != fromRed ||
            pixels[offset + 1] != fromGreen ||
            pixels[offset + 2] != fromBlue ||
            pixels[offset + 3] != fromAlpha) {
          continue;
        }
        final before = BeadColor.fromInt(
          fromRed,
          fromGreen,
          fromBlue,
          fromAlpha,
        );
        final after = BeadColor.fromInt(toRed, toGreen, toBlue, toAlpha);
        pixels[offset] = toRed;
        pixels[offset + 1] = toGreen;
        pixels[offset + 2] = toBlue;
        pixels[offset + 3] = toAlpha;
        changes.add(CellChange(x: x, y: y, before: before, after: after));
      }
    }
    return changes;
  }

  /// Replaces a colour and returns an allocation-conscious history payload.
  ///
  /// Palette replacement can touch an entire 150 by 150 drawing. Keeping one
  /// index per changed cell is substantially smaller than retaining a full
  /// [CellChange] (and two colour objects) for every matching bead.
  ColorReplacement? replaceColorCompact({
    required Uint8List pixels,
    required BeadColor from,
    required BeadColor to,
  }) {
    if (from == to) return null;

    final fromRed = from.rInt;
    final fromGreen = from.gInt;
    final fromBlue = from.bInt;
    final fromAlpha = from.aInt;
    final toRed = to.rInt;
    final toGreen = to.gInt;
    final toBlue = to.bInt;
    final toAlpha = to.aInt;
    final cellIndexes = <int>[];

    for (var offset = 0; offset < pixels.length; offset += 4) {
      if (pixels[offset] != fromRed ||
          pixels[offset + 1] != fromGreen ||
          pixels[offset + 2] != fromBlue ||
          pixels[offset + 3] != fromAlpha) {
        continue;
      }
      cellIndexes.add(offset ~/ 4);
      pixels[offset] = toRed;
      pixels[offset + 1] = toGreen;
      pixels[offset + 2] = toBlue;
      pixels[offset + 3] = toAlpha;
    }
    if (cellIndexes.isEmpty) return null;

    return ColorReplacement(
      cellIndexes: Uint32List.fromList(cellIndexes),
      before: BeadColor.fromInt(fromRed, fromGreen, fromBlue, fromAlpha),
      after: BeadColor.fromInt(toRed, toGreen, toBlue, toAlpha),
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
