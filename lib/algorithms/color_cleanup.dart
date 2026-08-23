import 'dart:typed_data';

import '../models/color.dart';
import '../models/denoise_strength.dart';
import 'matching.dart';

/// Smooths tiny color variations without averaging across a visible edge.
/// Only neighbors close to the center pixel contribute to its new color.
Uint8List denoiseRgbaPixels({
  required Uint8List pixels,
  required int width,
  required int height,
  required DenoiseStrength strength,
}) {
  if (pixels.lengthInBytes != width * height * 4) {
    throw ArgumentError('Pixel data does not match the supplied dimensions.');
  }

  final settings = _settingsFor(strength);
  final denoised = Uint8List.fromList(pixels);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = _offset(width, x, y);
      if (pixels[offset + 3] == 0) continue;

      final centerRed = pixels[offset];
      final centerGreen = pixels[offset + 1];
      final centerBlue = pixels[offset + 2];
      var redTotal = centerRed * settings.centerWeight;
      var greenTotal = centerGreen * settings.centerWeight;
      var blueTotal = centerBlue * settings.centerWeight;
      var weightTotal = settings.centerWeight;

      for (var neighborY = y - 1; neighborY <= y + 1; neighborY++) {
        for (var neighborX = x - 1; neighborX <= x + 1; neighborX++) {
          if (neighborX == x && neighborY == y ||
              neighborX < 0 ||
              neighborX >= width ||
              neighborY < 0 ||
              neighborY >= height) {
            continue;
          }
          final neighborOffset = _offset(width, neighborX, neighborY);
          if (pixels[neighborOffset + 3] == 0) continue;

          final redDifference = pixels[neighborOffset] - centerRed;
          final greenDifference = pixels[neighborOffset + 1] - centerGreen;
          final blueDifference = pixels[neighborOffset + 2] - centerBlue;
          final distanceSquared =
              redDifference * redDifference +
              greenDifference * greenDifference +
              blueDifference * blueDifference;
          if (distanceSquared > settings.maxNeighborDistanceSquared) continue;

          redTotal += pixels[neighborOffset];
          greenTotal += pixels[neighborOffset + 1];
          blueTotal += pixels[neighborOffset + 2];
          weightTotal++;
        }
      }

      denoised[offset] = redTotal ~/ weightTotal;
      denoised[offset + 1] = greenTotal ~/ weightTotal;
      denoised[offset + 2] = blueTotal ~/ weightTotal;
    }
  }
  return denoised;
}

/// Merges one- and two-bead islands only when the surrounding color is close
/// enough. It keeps high-contrast details, such as eyes and outlines, intact.
void mergeSmallSimilarColorIslands({
  required Uint8List pixels,
  required int width,
  required int height,
  required Matching matching,
  required DenoiseStrength strength,
}) {
  final settings = _settingsFor(strength);
  final totalCells = width * height;
  if (pixels.lengthInBytes != totalCells * 4) {
    throw ArgumentError('Pixel data does not match the supplied dimensions.');
  }

  final componentByCell = List<int>.filled(totalCells, -1);
  final components = <_ColorComponent>[];
  for (var start = 0; start < totalCells; start++) {
    if (componentByCell[start] != -1) continue;
    final startOffset = start * 4;
    if (pixels[startOffset + 3] == 0) {
      componentByCell[start] = -2;
      continue;
    }

    final colorKey = _rgbaKeyAt(pixels, startOffset);
    final cells = <int>[];
    final queue = <int>[start];
    final componentIndex = components.length;
    componentByCell[start] = componentIndex;
    for (var cursor = 0; cursor < queue.length; cursor++) {
      final cell = queue[cursor];
      cells.add(cell);
      final x = cell % width;
      final y = cell ~/ width;
      for (final neighbor in _fourNeighbors(x, y, width, height)) {
        if (componentByCell[neighbor] != -1) continue;
        final neighborOffset = neighbor * 4;
        if (pixels[neighborOffset + 3] == 0 ||
            _rgbaKeyAt(pixels, neighborOffset) != colorKey) {
          continue;
        }
        componentByCell[neighbor] = componentIndex;
        queue.add(neighbor);
      }
    }
    components.add(_ColorComponent(colorKey: colorKey, cells: cells));
  }

  final replacements = <int, int>{};
  for (
    var componentIndex = 0;
    componentIndex < components.length;
    componentIndex++
  ) {
    final component = components[componentIndex];
    if (component.cells.length > settings.maxIslandSize) continue;

    final borderCounts = <int, int>{};
    for (final cell in component.cells) {
      final x = cell % width;
      final y = cell ~/ width;
      for (final neighbor in _fourNeighbors(x, y, width, height)) {
        final neighborComponent = componentByCell[neighbor];
        if (neighborComponent < 0 || neighborComponent == componentIndex) {
          continue;
        }
        borderCounts[neighborComponent] =
            (borderCounts[neighborComponent] ?? 0) + 1;
      }
    }
    if (borderCounts.isEmpty) continue;

    final replacementComponent = borderCounts.entries
        .reduce(
          (best, candidate) => candidate.value > best.value ? candidate : best,
        )
        .key;
    final replacement = components[replacementComponent];
    if (replacement.cells.length <= component.cells.length ||
        matching.delta(
              _colorFromKey(component.colorKey),
              _colorFromKey(replacement.colorKey),
            ) >
            settings.maxMergeDelta) {
      continue;
    }
    for (final cell in component.cells) {
      replacements[cell] = replacement.colorKey;
    }
  }

  for (final replacement in replacements.entries) {
    final offset = replacement.key * 4;
    _setColorKeyAt(pixels, offset, replacement.value);
  }
}

class _ColorComponent {
  final int colorKey;
  final List<int> cells;

  const _ColorComponent({required this.colorKey, required this.cells});
}

class _CleanupSettings {
  final int maxNeighborDistanceSquared;
  final int centerWeight;
  final int maxIslandSize;
  final double maxMergeDelta;

  const _CleanupSettings({
    required this.maxNeighborDistanceSquared,
    required this.centerWeight,
    required this.maxIslandSize,
    required this.maxMergeDelta,
  });
}

_CleanupSettings _settingsFor(DenoiseStrength strength) {
  switch (strength) {
    case DenoiseStrength.mild:
      return const _CleanupSettings(
        maxNeighborDistanceSquared: 26 * 26,
        centerWeight: 6,
        maxIslandSize: 1,
        maxMergeDelta: 8,
      );
    case DenoiseStrength.standard:
      return const _CleanupSettings(
        maxNeighborDistanceSquared: 36 * 36,
        centerWeight: 4,
        maxIslandSize: 2,
        maxMergeDelta: 12,
      );
    case DenoiseStrength.strong:
      return const _CleanupSettings(
        maxNeighborDistanceSquared: 50 * 50,
        centerWeight: 2,
        maxIslandSize: 4,
        maxMergeDelta: 16,
      );
  }
}

int _offset(int width, int x, int y) => (y * width + x) * 4;

Iterable<int> _fourNeighbors(int x, int y, int width, int height) sync* {
  if (x > 0) yield y * width + x - 1;
  if (x + 1 < width) yield y * width + x + 1;
  if (y > 0) yield (y - 1) * width + x;
  if (y + 1 < height) yield (y + 1) * width + x;
}

int _rgbaKeyAt(Uint8List pixels, int offset) =>
    (pixels[offset] << 24) |
    (pixels[offset + 1] << 16) |
    (pixels[offset + 2] << 8) |
    pixels[offset + 3];

void _setColorKeyAt(Uint8List pixels, int offset, int colorKey) {
  pixels[offset] = (colorKey >> 24) & 0xff;
  pixels[offset + 1] = (colorKey >> 16) & 0xff;
  pixels[offset + 2] = (colorKey >> 8) & 0xff;
  pixels[offset + 3] = colorKey & 0xff;
}

BeadColor _colorFromKey(int colorKey) => BeadColor.fromInt(
  (colorKey >> 24) & 0xff,
  (colorKey >> 16) & 0xff,
  (colorKey >> 8) & 0xff,
  colorKey & 0xff,
);
