import 'dart:typed_data';

import 'package:bobobeads/services/cutout_outline_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List cutoutPng() {
    final image = img.Image(width: 7, height: 7, numChannels: 4);
    for (var y = 2; y <= 4; y++) {
      for (var x = 2; x <= 4; x++) {
        image.setPixelRgba(x, y, 240, 100, 40, 255);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  test('adds a black contour outside the transparent cutout only', () {
    final outlined = CutoutOutlineService().addBlackOutline(
      cutoutPng(),
      radius: 2,
    );
    final image = img.decodePng(outlined)!;

    final foreground = image.getPixel(3, 3);
    expect(
      (foreground.r, foreground.g, foreground.b, foreground.a),
      (240, 100, 40, 255),
    );
    final contour = image.getPixel(1, 3);
    expect((contour.r, contour.g, contour.b, contour.a), (0, 0, 0, 255));
    expect(image.getPixel(0, 0).a.toInt(), 0);
  });

  test(
    'refines translucent cutout edges using the cleanup threshold curve',
    () {
      final image = img.Image(width: 3, height: 1, numChannels: 4);
      image.setPixelRgba(0, 0, 10, 20, 30, 52);
      image.setPixelRgba(1, 0, 10, 20, 30, 53);
      image.setPixelRgba(2, 0, 10, 20, 30, 255);

      final refined = CutoutOutlineService().refineAlpha(
        Uint8List.fromList(img.encodePng(image)),
        cleanup: 36,
      );
      final decoded = img.decodePng(refined)!;

      expect(decoded.getPixel(0, 0).a.toInt(), 0);
      expect(decoded.getPixel(1, 0).a.toInt(), 1);
      expect(decoded.getPixel(2, 0).a.toInt(), 255);
    },
  );

  test('caps cleanup threshold at 116', () {
    final image = img.Image(width: 1, height: 1, numChannels: 4)
      ..setPixelRgba(0, 0, 10, 20, 30, 117);

    final refined = CutoutOutlineService().refineAlpha(
      Uint8List.fromList(img.encodePng(image)),
      cleanup: 100,
    );

    expect(img.decodePng(refined)!.getPixel(0, 0).a.toInt(), 2);
  });

  test('leaves an image without transparency unchanged', () {
    final image = img.Image(width: 3, height: 3);
    final bytes = Uint8List.fromList(img.encodePng(image));

    expect(CutoutOutlineService().addBlackOutline(bytes), bytes);
  });
}
