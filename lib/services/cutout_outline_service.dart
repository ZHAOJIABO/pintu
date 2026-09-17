import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Adds an opaque black contour immediately outside a transparent cutout.
///
/// The original foreground pixels (including Vision's anti-aliased edge) are
/// never replaced. Only fully transparent pixels within [radius] of the
/// foreground receive the outline, so the result remains a transparent PNG.
class CutoutOutlineService {
  static const _foregroundAlphaThreshold = 16;
  static const defaultCleanup = 36.0;

  /// Removes the translucent fringe commonly left by foreground extraction.
  /// This follows the reference cleanup curve exactly: values at or below the
  /// threshold become transparent; remaining alpha is stretched to 0–255.
  Uint8List refineAlpha(
    Uint8List imageBytes, {
    double cleanup = defaultCleanup,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Image could not be decoded');
    }
    final cutout = img.bakeOrientation(decoded);
    final threshold = (cleanup * 1.45).round().clamp(0, 116).toInt();
    final range = math.max(1, 255 - threshold);
    for (var y = 0; y < cutout.height; y++) {
      for (var x = 0; x < cutout.width; x++) {
        final pixel = cutout.getPixel(x, y);
        final alpha = pixel.a.toInt();
        final refinedAlpha = alpha <= threshold
            ? 0
            : (255 * (alpha - threshold) / range).round();
        cutout.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          refinedAlpha,
        );
      }
    }
    return Uint8List.fromList(img.encodePng(cutout));
  }

  Uint8List addBlackOutline(Uint8List imageBytes, {int? radius}) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Image could not be decoded');
    }
    final cutout = img.bakeOrientation(decoded);
    final pixelCount = cutout.width * cutout.height;
    final alpha = Uint8List(pixelCount);
    var hasTransparentPixel = false;
    var hasForegroundPixel = false;

    for (var y = 0; y < cutout.height; y++) {
      for (var x = 0; x < cutout.width; x++) {
        final value = cutout.getPixel(x, y).a.toInt();
        final index = y * cutout.width + x;
        alpha[index] = value;
        hasTransparentPixel |= value < _foregroundAlphaThreshold;
        hasForegroundPixel |= value >= _foregroundAlphaThreshold;
      }
    }
    if (!hasTransparentPixel || !hasForegroundPixel) return imageBytes;

    final longestSide = math.max(cutout.width, cutout.height);
    final outlineRadius =
        radius ?? (longestSide * 0.02).round().clamp(2, longestSide).toInt();
    final offsets = _circularOffsets(outlineRadius);
    final outline = Uint8List(pixelCount);

    for (var y = 0; y < cutout.height; y++) {
      for (var x = 0; x < cutout.width; x++) {
        final index = y * cutout.width + x;
        if (alpha[index] < _foregroundAlphaThreshold ||
            !_isBoundary(alpha, cutout.width, cutout.height, x, y)) {
          continue;
        }
        for (final offset in offsets) {
          final targetX = x + offset.$1;
          final targetY = y + offset.$2;
          if (targetX < 0 ||
              targetY < 0 ||
              targetX >= cutout.width ||
              targetY >= cutout.height) {
            continue;
          }
          final targetIndex = targetY * cutout.width + targetX;
          if (alpha[targetIndex] < _foregroundAlphaThreshold) {
            outline[targetIndex] = 1;
          }
        }
      }
    }

    for (var y = 0; y < cutout.height; y++) {
      for (var x = 0; x < cutout.width; x++) {
        if (outline[y * cutout.width + x] == 1) {
          cutout.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }
    return Uint8List.fromList(img.encodePng(cutout));
  }

  bool _isBoundary(Uint8List alpha, int width, int height, int x, int y) {
    for (var offsetY = -1; offsetY <= 1; offsetY++) {
      for (var offsetX = -1; offsetX <= 1; offsetX++) {
        if (offsetX == 0 && offsetY == 0) continue;
        final neighborX = x + offsetX;
        final neighborY = y + offsetY;
        if (neighborX < 0 ||
            neighborY < 0 ||
            neighborX >= width ||
            neighborY >= height ||
            alpha[neighborY * width + neighborX] < _foregroundAlphaThreshold) {
          return true;
        }
      }
    }
    return false;
  }

  List<(int, int)> _circularOffsets(int radius) {
    final offsets = <(int, int)>[];
    final radiusSquared = radius * radius;
    for (var y = -radius; y <= radius; y++) {
      for (var x = -radius; x <= radius; x++) {
        if (x * x + y * y <= radiusSquared) offsets.add((x, y));
      }
    }
    return offsets;
  }
}
