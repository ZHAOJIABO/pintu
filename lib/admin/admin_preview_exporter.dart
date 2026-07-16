import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/generated_pattern.dart';

/// Exports the display image stored with an official template.
///
/// The iOS gallery renders square 119.33pt cards.  Store a 3x image so the
/// same PNG remains crisp in the iOS gallery and in the Web admin portal.
/// This intentionally paints only the template pixels; the printable chart,
/// its border coordinates, and color references belong to the final export,
/// not to a gallery thumbnail.
class AdminPreviewExporter {
  static const int galleryThumbnailPixelSize = 358;

  const AdminPreviewExporter();

  Future<Uint8List> exportGalleryThumbnailPng(GeneratedPattern pattern) {
    _validatePattern(pattern);
    final image = img.Image(
      width: galleryThumbnailPixelSize,
      height: galleryThumbnailPixelSize,
      numChannels: 4,
    )..clear(img.ColorUint8.rgba(255, 255, 255, 255));

    for (var y = 0; y < pattern.height; y++) {
      for (var x = 0; x < pattern.width; x++) {
        final offset = (y * pattern.width + x) * 4;
        final alpha = pattern.pixels[offset + 3];
        if (alpha == 0) continue;

        final left = x * galleryThumbnailPixelSize ~/ pattern.width;
        final right = (x + 1) * galleryThumbnailPixelSize ~/ pattern.width;
        final top = y * galleryThumbnailPixelSize ~/ pattern.height;
        final bottom = (y + 1) * galleryThumbnailPixelSize ~/ pattern.height;
        for (var targetY = top; targetY < bottom; targetY++) {
          for (var targetX = left; targetX < right; targetX++) {
            image.setPixelRgba(
              targetX,
              targetY,
              pattern.pixels[offset],
              pattern.pixels[offset + 1],
              pattern.pixels[offset + 2],
              alpha,
            );
          }
        }
      }
    }
    return Future.value(Uint8List.fromList(img.encodePng(image)));
  }

  void _validatePattern(GeneratedPattern pattern) {
    if (pattern.width <= 0 || pattern.height <= 0) {
      throw ArgumentError.value(
        '${pattern.width}x${pattern.height}',
        'pattern',
        '模板尺寸必须为正数',
      );
    }
    final expectedLength = pattern.width * pattern.height * 4;
    if (pattern.pixels.length != expectedLength) {
      throw ArgumentError.value(
        pattern.pixels.length,
        'pattern.pixels',
        '像素数据长度与模板尺寸不一致',
      );
    }
  }
}
