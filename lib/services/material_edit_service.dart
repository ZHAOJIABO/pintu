import 'dart:typed_data';

import '../algorithms/color_reducer.dart';
import '../models/color.dart';
import '../models/generated_pattern.dart';
import '../models/palette.dart';

class MaterialEditService {
  GeneratedPattern replaceColor({
    required GeneratedPattern pattern,
    required PaletteEntry from,
    required PaletteEntry to,
  }) {
    final pixels = Uint8List.fromList(pattern.pixels);
    for (int i = 0; i < pixels.length; i += 4) {
      if (_matches(pixels, i, from.color)) {
        _set(pixels, i, to.color);
      }
    }
    return _withUsage(pattern, pixels);
  }

  GeneratedPattern deleteColor({
    required GeneratedPattern pattern,
    required PaletteEntry entry,
  }) {
    final pixels = Uint8List.fromList(pattern.pixels);
    for (int i = 0; i < pixels.length; i += 4) {
      if (_matches(pixels, i, entry.color)) {
        pixels[i + 3] = 0;
      }
    }
    return _withUsage(pattern, pixels);
  }

  bool requiresDeleteConfirmation(GeneratedPattern pattern, String ref) {
    final count = pattern.usage[ref] ?? 0;
    if (pattern.totalBeads == 0) return false;
    return count / pattern.totalBeads > 0.05;
  }

  GeneratedPattern _withUsage(GeneratedPattern pattern, Uint8List pixels) {
    final palette = Palette(name: 'active', entries: pattern.paletteEntries);
    return pattern.copyWith(
      pixels: pixels,
      usage: computeUsage(pixels, pattern.width, pattern.height, [palette]),
    );
  }

  bool _matches(Uint8List pixels, int offset, BeadColor color) {
    return pixels[offset] == color.rInt &&
        pixels[offset + 1] == color.gInt &&
        pixels[offset + 2] == color.bInt &&
        pixels[offset + 3] == color.aInt;
  }

  void _set(Uint8List pixels, int offset, BeadColor color) {
    pixels[offset] = color.rInt;
    pixels[offset + 1] = color.gInt;
    pixels[offset + 2] = color.bInt;
    pixels[offset + 3] = color.aInt;
  }
}
