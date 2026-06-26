import 'dart:typed_data';

import 'color.dart';
import 'generated_pattern.dart';
import 'palette.dart';

class PatternChartCell {
  final String ref;
  final BeadColor color;
  final bool matchedPalette;

  const PatternChartCell({
    required this.ref,
    required this.color,
    required this.matchedPalette,
  });
}

class PatternChartData {
  static const unmatchedRef = '?';

  final int width;
  final int height;
  final List<PatternChartCell?> cells;

  const PatternChartData({
    required this.width,
    required this.height,
    required this.cells,
  });

  factory PatternChartData.fromPattern(GeneratedPattern pattern) {
    return PatternChartData.fromPixels(
      pixels: pattern.pixels,
      width: pattern.width,
      height: pattern.height,
      paletteEntries: pattern.paletteEntries,
    );
  }

  factory PatternChartData.fromPixels({
    required Uint8List pixels,
    required int width,
    required int height,
    required List<PaletteEntry> paletteEntries,
  }) {
    final expectedLength = width * height * 4;
    if (pixels.length != expectedLength) {
      throw ArgumentError(
        'Pixel buffer length ${pixels.length} does not match $width x $height',
      );
    }

    final paletteByColor = <int, PaletteEntry>{};
    for (final entry in paletteEntries) {
      paletteByColor.putIfAbsent(_rgbaKeyFromColor(entry.color), () => entry);
    }

    final cells = List<PatternChartCell?>.filled(width * height, null);
    for (int i = 0; i < pixels.length; i += 4) {
      final alpha = pixels[i + 3];
      if (alpha == 0) continue;

      final key = _rgbaKey(
        pixels[i],
        pixels[i + 1],
        pixels[i + 2],
        pixels[i + 3],
      );
      final entry = paletteByColor[key];
      final color =
          entry?.color ??
          BeadColor.fromInt(
            pixels[i],
            pixels[i + 1],
            pixels[i + 2],
            pixels[i + 3],
          );

      cells[i ~/ 4] = PatternChartCell(
        ref: entry?.ref ?? unmatchedRef,
        color: color,
        matchedPalette: entry != null,
      );
    }

    return PatternChartData(width: width, height: height, cells: cells);
  }

  PatternChartCell? cellAt(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return null;
    return cells[y * width + x];
  }

  static int _rgbaKeyFromColor(BeadColor color) {
    return _rgbaKey(color.rInt, color.gInt, color.bInt, color.aInt);
  }

  static int _rgbaKey(int r, int g, int b, int a) {
    return (r << 24) | (g << 16) | (b << 8) | a;
  }
}
