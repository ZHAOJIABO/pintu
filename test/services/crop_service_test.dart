import 'dart:typed_data';

import 'package:bobobeads/models/product_template.dart';
import 'package:bobobeads/services/crop_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List gridPng() {
    final image = img.Image(width: 4, height: 4);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, x * 40, y * 40, 0);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  test('cropToAspectRatioWithTransform applies display offset', () async {
    final cropped = await CropService().cropToAspectRatioWithTransform(
      gridPng(),
      CropAspectRatio.square,
      renderScale: 10,
      displayOffsetX: 10,
      displayOffsetY: 0,
      cropDisplayWidth: 20,
      cropDisplayHeight: 20,
    );

    final decoded = img.decodePng(cropped)!;
    expect(decoded.width, 2);
    expect(decoded.height, 2);
    expect(decoded.getPixel(0, 0).r.toInt(), 0);
    expect(decoded.getPixel(1, 0).r.toInt(), 40);
    expect(decoded.getPixel(0, 0).g.toInt(), 40);
    expect(decoded.getPixel(0, 1).g.toInt(), 80);
  });

  test('cropToAspectRatioWithTransform mirrors flipped crops', () async {
    final cropped = await CropService().cropToAspectRatioWithTransform(
      gridPng(),
      CropAspectRatio.square,
      renderScale: 10,
      displayOffsetX: 0,
      displayOffsetY: 0,
      cropDisplayWidth: 20,
      cropDisplayHeight: 20,
      flipped: true,
    );

    final decoded = img.decodePng(cropped)!;
    expect(decoded.width, 2);
    expect(decoded.height, 2);
    expect(decoded.getPixel(0, 0).r.toInt(), 80);
    expect(decoded.getPixel(1, 0).r.toInt(), 40);
  });
}
