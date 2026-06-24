import 'dart:typed_data';
import '../models/color.dart';
import '../models/palette.dart';
import 'matching.dart';

class ImagePosition {
  final int xStart;
  final int yStart;
  final int width;
  final int height;

  ImagePosition(this.xStart, this.yStart, this.width, this.height);

  bool contains(int x, int y) {
    if (x < xStart || x >= xStart + width) return false;
    if (y < yStart || y >= yStart + height) return false;
    return true;
  }
}

class ColorReducerResult {
  final Uint8List pixels;
  final int width;
  final int height;
  final Map<String, int> usage;

  ColorReducerResult({
    required this.pixels,
    required this.width,
    required this.height,
    required this.usage,
  });
}

BeadColor _getPixel(Uint8List data, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return BeadColor(
    data[offset].toDouble(),
    data[offset + 1].toDouble(),
    data[offset + 2].toDouble(),
    data[offset + 3].toDouble(),
  );
}

void _setPixel(Uint8List data, int width, int x, int y, BeadColor color) {
  final offset = (y * width + x) * 4;
  data[offset] = color.rInt;
  data[offset + 1] = color.gInt;
  data[offset + 2] = color.bInt;
  data[offset + 3] = color.aInt;
}

class _PaletteCache {
  final List<PaletteEntry> entries;
  final List<Lab> labs;

  _PaletteCache(this.entries, this.labs);
}

_PaletteCache _buildPaletteCache(List<Palette> palettes) {
  final entries = <PaletteEntry>[];
  final labs = <Lab>[];
  for (final palette in palettes) {
    for (final entry in palette.entries) {
      if (!entry.enabled) continue;
      entries.add(entry);
      labs.add(colorToLab(entry.color));
    }
  }
  return _PaletteCache(entries, labs);
}

PaletteEntry getClosestPaletteEntry(
  List<Palette> palettes,
  BeadColor color,
  Matching matching,
) {
  PaletteEntry? best;
  double bestDelta = double.infinity;

  for (final palette in palettes) {
    for (final entry in palette.entries) {
      if (!entry.enabled) continue;
      final d = matching.delta(entry.color, color);
      if (d < bestDelta) {
        bestDelta = d;
        best = entry;
      }
    }
  }
  return best!;
}

PaletteEntry _getClosestFromCache(
  _PaletteCache cache,
  BeadColor color,
  Matching matching,
) {
  if (matching.usesLab) {
    final pixelLab = colorToLab(color);
    int bestIdx = 0;
    double bestDelta = double.infinity;
    for (int i = 0; i < cache.entries.length; i++) {
      final d = matching.deltaLab(cache.labs[i], pixelLab);
      if (d < bestDelta) {
        bestDelta = d;
        bestIdx = i;
      }
    }
    return cache.entries[bestIdx];
  } else {
    int bestIdx = 0;
    double bestDelta = double.infinity;
    for (int i = 0; i < cache.entries.length; i++) {
      final d = matching.delta(cache.entries[i].color, color);
      if (d < bestDelta) {
        bestDelta = d;
        bestIdx = i;
      }
    }
    return cache.entries[bestIdx];
  }
}

ColorReducerResult reduceColor({
  required Uint8List pixels,
  required int width,
  required int height,
  required List<Palette> palettes,
  required Matching matching,
  required bool ditheringEnabled,
  required int ditheringHardness,
  required ImagePosition drawingPosition,
}) {
  final data = Uint8List.fromList(pixels);
  final cache = _buildPaletteCache(palettes);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final color = _getPixel(data, width, x, y);
      if (color.a == 0) continue;

      final closest = _getClosestFromCache(cache, color, matching);
      _setPixel(data, width, x, y, closest.color);

      if (ditheringEnabled) {
        final quantError = color.sub(closest.color);

        if (drawingPosition.contains(x + 1, y)) {
          final neighbor = _getPixel(data, width, x + 1, y);
          final errorMult = quantError.clone().mult(
            (ditheringHardness / 100) * 7 / 16,
          );
          _setPixel(data, width, x + 1, y, neighbor.add(errorMult));
        }
        if (drawingPosition.contains(x - 1, y + 1)) {
          final neighbor = _getPixel(data, width, x - 1, y + 1);
          final errorMult = quantError.clone().mult(
            (ditheringHardness / 100) * 3 / 16,
          );
          _setPixel(data, width, x - 1, y + 1, neighbor.add(errorMult));
        }
        if (drawingPosition.contains(x, y + 1)) {
          final neighbor = _getPixel(data, width, x, y + 1);
          final errorMult = quantError.clone().mult(
            (ditheringHardness / 100) * 5 / 16,
          );
          _setPixel(data, width, x, y + 1, neighbor.add(errorMult));
        }
        if (drawingPosition.contains(x + 1, y + 1)) {
          final neighbor = _getPixel(data, width, x + 1, y + 1);
          final errorMult = quantError.clone().mult(
            (ditheringHardness / 100) * 1 / 16,
          );
          _setPixel(data, width, x + 1, y + 1, neighbor.add(errorMult));
        }
      }
    }
  }

  final usage = computeUsage(data, width, height, palettes);
  return ColorReducerResult(
    pixels: data,
    width: width,
    height: height,
    usage: usage,
  );
}

Map<String, int> computeUsage(
  Uint8List pixels,
  int width,
  int height,
  List<Palette> palettes,
) {
  final usage = <String, int>{};
  final allEntries = palettes.expand((p) => p.entries).toList();

  for (int i = 0; i < pixels.length; i += 4) {
    final r = pixels[i];
    final g = pixels[i + 1];
    final b = pixels[i + 2];
    final a = pixels[i + 3];
    if (a == 0) continue;

    for (final entry in allEntries) {
      if (entry.color.rInt == r &&
          entry.color.gInt == g &&
          entry.color.bInt == b &&
          entry.color.aInt == a) {
        usage[entry.ref] = (usage[entry.ref] ?? 0) + 1;
        break;
      }
    }
  }
  return usage;
}
