import 'dart:typed_data';

import 'package:bobobeads/admin/admin_preview_exporter.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'exports a square gallery thumbnail made only from template pixels',
    () async {
      final bytes = await const AdminPreviewExporter()
          .exportGalleryThumbnailPng(
            GeneratedPattern(
              pixels: Uint8List.fromList([
                255,
                0,
                0,
                255,
                0,
                255,
                0,
                255,
                0,
                0,
                255,
                255,
                255,
                255,
                0,
                255,
              ]),
              width: 2,
              height: 2,
              usage: const {},
              paletteEntries: const [],
              draft: DraftProject(originalImageBytes: Uint8List(0)),
            ),
          );

      final image = img.decodePng(bytes);
      expect(image, isNotNull);
      final decoded = image!;

      expect(decoded.width, AdminPreviewExporter.galleryThumbnailPixelSize);
      expect(decoded.height, AdminPreviewExporter.galleryThumbnailPixelSize);

      expect(_pixelAt(decoded, 40, 40), [255, 0, 0, 255]);
      expect(_pixelAt(decoded, 310, 40), [0, 255, 0, 255]);
      expect(_pixelAt(decoded, 40, 310), [0, 0, 255, 255]);
      // The center of each block must remain the source color: no color code
      // or other chart text is drawn over the template image.
      expect(_pixelAt(decoded, 310, 310), [255, 255, 0, 255]);
    },
  );
}

List<int> _pixelAt(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), pixel.a.toInt()];
}
