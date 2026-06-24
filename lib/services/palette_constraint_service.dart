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

    return Palette(
      name: '${palette.name} (${limit.label})',
      entries: selectedScores
          .take(maxColors)
          .map((score) => score.entry)
          .toList(growable: false),
    );
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
