import 'dart:typed_data';

import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/screens/crop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List portraitImagePng() {
    final image = img.Image(width: 90, height: 120);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 40 + x, 120 + y ~/ 2, 150);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  const viewports = {
    'iPhone SE 3': Size(375, 667),
    'iPhone 12': Size(390, 844),
    'Large iPhone': Size(430, 932),
  };

  for (final entry in viewports.entries) {
    testWidgets('CropScreen renders on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CropScreen(
            draft: DraftProject(originalImageBytes: portraitImagePng()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('裁切'), findsOneWidget);
      expect(find.text('翻转'), findsOneWidget);
      expect(find.text('1:1'), findsOneWidget);
      expect(find.text('9:16'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
