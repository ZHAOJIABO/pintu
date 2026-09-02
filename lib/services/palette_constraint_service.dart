import 'dart:typed_data';

import '../algorithms/matching.dart';
import '../models/color.dart';
import '../models/color_limit.dart';
import '../models/palette.dart';

class PaletteConstraintService {
  const PaletteConstraintService();

  Palette applyColorLimit(Palette palette, ColorLimit limit) {
    final enabledEntries = palette.entries
        .where((entry) => entry.enabled)
        .toList(growable: false);
    final maxColors = limit.value;
    if (maxColors == null || enabledEntries.length <= maxColors) {
      return Palette(name: palette.name, entries: enabledEntries);
    }
    return Palette(
      name: '${palette.name} (${limit.label})',
      entries: enabledEntries.take(maxColors).toList(growable: false),
    );
  }

  Palette applyImageAwareColorLimit({
    required Palette palette,
    required ColorLimit limit,
    required Uint8List pixels,
    required Matching matching,
    bool preserveWhite = false,
  }) {
    final enabledEntries = palette.entries
        .where((entry) => entry.enabled)
        .toList(growable: false);
    final maxColors = limit.value;
    if (maxColors == null || enabledEntries.length <= maxColors) {
      return Palette(name: palette.name, entries: enabledEntries);
    }

    final scores = <String, _PaletteScore>{
      for (final entry in enabledEntries) entry.ref: _PaletteScore(entry),
    };
    final labs = matching.usesLab
        ? {
            for (final entry in enabledEntries)
              entry.ref: colorToLab(entry.color),
          }
        : <String, Lab>{};

    for (int i = 0; i < pixels.length; i += 4) {
      final alpha = pixels[i + 3];
      if (alpha == 0) continue;

      final color = BeadColor.fromInt(
        pixels[i],
        pixels[i + 1],
        pixels[i + 2],
        alpha,
      );
      final pixelLab = matching.usesLab ? colorToLab(color) : null;

      PaletteEntry? bestEntry;
      double bestDelta = double.infinity;
      for (final entry in enabledEntries) {
        final delta = matching.usesLab
            ? matching.deltaLab(labs[entry.ref]!, pixelLab!)
            : matching.delta(entry.color, color);
        if (delta < bestDelta) {
          bestDelta = delta;
          bestEntry = entry;
        }
      }

      if (bestEntry != null) {
        scores[bestEntry.ref]!.add(bestDelta);
      }
    }

    final selectedScores =
        scores.values.where((score) => score.count > 0).toList()..sort((a, b) {
          final countCompare = b.count.compareTo(a.count);
          if (countCompare != 0) return countCompare;
          return a.averageDelta.compareTo(b.averageDelta);
        });

    final selectedEntries = selectedScores
        .take(maxColors)
        .map((score) => score.entry)
        .toList(growable: false);
    final whiteScore = preserveWhite
        ? _mostUsedForegroundWhite(selectedScores)
        : null;
    if (whiteScore != null &&
        !selectedEntries.any((entry) => entry.ref == whiteScore.entry.ref)) {
      return Palette(
        name: '${palette.name} (${limit.label})',
        entries: [whiteScore.entry, ...selectedEntries.take(maxColors - 1)],
      );
    }

    return Palette(
      name: '${palette.name} (${limit.label})',
      entries: selectedEntries,
    );
  }

  /// Finds white actually present in the opaque foreground. Transparent
  /// background pixels are skipped before scoring, so they cannot reserve a
  /// colour slot.
  _PaletteScore? _mostUsedForegroundWhite(List<_PaletteScore> scores) {
    for (final score in scores) {
      if (_isNeutralWhite(score.entry.color)) return score;
    }
    return null;
  }

  bool _isNeutralWhite(BeadColor color) {
    final red = color.rInt;
    final green = color.gInt;
    final blue = color.bInt;
    return red >= 245 &&
        green >= 245 &&
        blue >= 245 &&
        (red - green).abs() <= 16 &&
        (red - blue).abs() <= 16 &&
        (green - blue).abs() <= 16;
  }
}

class _PaletteScore {
  final PaletteEntry entry;
  int count = 0;
  double totalDelta = 0;

  _PaletteScore(this.entry);

  double get averageDelta => count == 0 ? double.infinity : totalDelta / count;

  void add(double delta) {
    count++;
    totalDelta += delta;
  }
}
