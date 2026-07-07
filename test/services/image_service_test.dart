import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/models/product_template.dart';
import 'package:bobobeads/services/image_service.dart';
import 'package:bobobeads/services/pattern_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List redLandscapePng() {
    final image = img.Image(width: 4, height: 3);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 255, 0, 0);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  test('resizeAndGetPixels keeps letterboxed rows transparent', () async {
    final pixels = await ImageService().resizeAndGetPixels(
      redLandscapePng(),
      8,
      8,
    );

    int alphaAt(int x, int y) => pixels[(y * 8 + x) * 4 + 3];

    for (var x = 0; x < 8; x++) {
      expect(alphaAt(x, 0), 0);
      expect(alphaAt(x, 7), 0);
    }
    expect(alphaAt(0, 1), 255);
    expect(alphaAt(7, 6), 255);
  });

  test('pattern generation ignores transparent letterbox areas', () async {
    final red = PaletteEntry(
      name: 'Red',
      ref: 'R',
      symbol: 'R',
      color: BeadColor.fromInt(255, 0, 0, 255),
      prefix: 'T',
    );
    final black = PaletteEntry(
      name: 'Black',
      ref: 'K',
      symbol: 'K',
      color: BeadColor.fromInt(0, 0, 0, 255),
      prefix: 'T',
    );
    const template = ProductTemplate(
      id: 'test_custom',
      name: '测试',
      subtitle: 'X',
      physicalSizeCm: null,
      beadWidth: 8,
      beadHeight: 8,
      defaultAspectRatio: CropAspectRatio.freeform,
      custom: true,
    );
    final draft = DraftProject(
      originalImageBytes: redLandscapePng(),
      croppedImageBytes: redLandscapePng(),
      selectedTemplate: template,
      customBeadWidth: 8,
      customBeadHeight: 8,
      paletteBrandId: 'test',
      smoothingEnabled: false,
    );

    final pattern = await PatternGenerationService(imageService: ImageService())
        .generate(
          draft: draft,
          palette: Palette(name: 'test', entries: [black, red]),
        );

    expect(pattern.usage, containsPair('R', 48));
    expect(pattern.usage, isNot(contains('K')));

    int alphaAt(int x, int y) => pattern.pixels[(y * 8 + x) * 4 + 3];
    expect(alphaAt(0, 0), 0);
    expect(alphaAt(7, 7), 0);
  });
}
