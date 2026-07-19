import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, debugPrint, kIsWeb;

import '../algorithms/color_reducer.dart';
import '../models/draft_project.dart';
import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../models/project.dart';
import 'background_removal_service.dart';
import 'image_service.dart';
import 'palette_constraint_service.dart';

class PatternGenerationService {
  final ImageService imageService;
  final PaletteConstraintService paletteConstraintService;
  final BackgroundRemovalService backgroundRemovalService;

  const PatternGenerationService({
    required this.imageService,
    this.paletteConstraintService = const PaletteConstraintService(),
    this.backgroundRemovalService = const PlatformBackgroundRemovalService(),
  });

  Future<GeneratedPattern> generate({
    required DraftProject draft,
    required Palette palette,
  }) async {
    if (!draft.canGenerate) {
      throw StateError('Draft is not ready for pattern generation');
    }
    if (palette.entries.where((entry) => entry.enabled).isEmpty) {
      throw StateError('Palette has no enabled colors');
    }

    final width = draft.targetWidth;
    final height = draft.targetHeight;
    final imageBytes = draft.removeBackground
        ? await backgroundRemovalService.removeBackground(
            draft.imageForGeneration,
          )
        : draft.imageForGeneration;
    if (!draft.removeBackground) {
      debugPrint('[BackgroundRemoval] disabled by the generation parameter.');
    }
    final pixels = await imageService.resizeAndGetPixels(
      imageBytes,
      width,
      height,
      alphaThreshold: draft.removeBackground ? 128 : null,
    );
    if (draft.removeBackground) {
      final transparentCount = _countTransparentPixels(pixels);
      debugPrint(
        '[BackgroundRemoval] transparent grid cells: '
        '$transparentCount/${width * height}.',
      );
    }
    final matchingAlgorithm = MatchingAlgorithm.cie2000;
    final constrainedPalette = paletteConstraintService
        .applyImageAwareColorLimit(
          palette: palette,
          limit: draft.colorLimit,
          pixels: pixels,
          matching: matchingAlgorithm.matcher,
        );
    if (constrainedPalette.entries.isEmpty) {
      throw StateError('Palette color limit did not select any usable colors');
    }

    final params = _ReduceColorParams(
      pixels: pixels,
      width: width,
      height: height,
      palettes: [constrainedPalette],
      matchingAlgorithm: matchingAlgorithm,
      ditheringEnabled: draft.smoothingEnabled,
      ditheringHardness: 50,
      drawingPosition: ImagePosition(0, 0, width, height),
    );

    final result = kIsWeb
        ? _reduceColorIsolate(params)
        : await compute(_reduceColorIsolate, params);

    return GeneratedPattern(
      pixels: result.pixels,
      width: result.width,
      height: result.height,
      usage: result.usage,
      paletteEntries: constrainedPalette.entries,
      draft: draft,
    );
  }
}

int _countTransparentPixels(Uint8List pixels) {
  var count = 0;
  for (var offset = 3; offset < pixels.length; offset += 4) {
    if (pixels[offset] == 0) count++;
  }
  return count;
}

class _ReduceColorParams {
  final Uint8List pixels;
  final int width;
  final int height;
  final List<Palette> palettes;
  final MatchingAlgorithm matchingAlgorithm;
  final bool ditheringEnabled;
  final int ditheringHardness;
  final ImagePosition drawingPosition;

  const _ReduceColorParams({
    required this.pixels,
    required this.width,
    required this.height,
    required this.palettes,
    required this.matchingAlgorithm,
    required this.ditheringEnabled,
    required this.ditheringHardness,
    required this.drawingPosition,
  });
}

ColorReducerResult _reduceColorIsolate(_ReduceColorParams params) {
  return reduceColor(
    pixels: params.pixels,
    width: params.width,
    height: params.height,
    palettes: params.palettes,
    matching: params.matchingAlgorithm.matcher,
    ditheringEnabled: params.ditheringEnabled,
    ditheringHardness: params.ditheringHardness,
    drawingPosition: params.drawingPosition,
  );
}
