import 'dart:typed_data';

import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/screens/parameter_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List sampleImagePng() {
    final image = img.Image(width: 80, height: 80);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 80 + x, 120 + y, 180);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  testWidgets('大小和色号变更会更新低清拼豆预览', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final image = sampleImagePng();
    await tester.pumpWidget(
      MaterialApp(
        home: ParameterConfigScreen(
          draft: DraftProject(
            originalImageBytes: image,
            croppedImageBytes: image,
            imageSource: DraftImageSource.illustration,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('parameter-pattern-preview')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('parameter-size-figma_small_charm')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.text('10 × 10 预览'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('parameter-color-limit-eight')),
      find.byType(ListView),
      const Offset(0, -180),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('parameter-color-limit-eight')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.text('10 × 10 · 8 色预览'), findsOneWidget);
  });
}
