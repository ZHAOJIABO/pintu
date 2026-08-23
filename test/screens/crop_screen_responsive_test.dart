import 'dart:typed_data';

import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/product_template.dart';
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

  Uint8List veryTallImagePng() {
    final image = img.Image(width: 40, height: 280);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 80, 100 + y ~/ 4, 160);
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

  testWidgets('photo crop starts freeform and toggles a fixed ratio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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

    final topLeftHandle = find.byKey(const ValueKey('crop-handle-topLeft'));
    expect(topLeftHandle, findsOneWidget);
    expect(tester.widget<Text>(find.text('1:1')).style?.color, Colors.black);

    final initialHandleCenter = tester.getCenter(topLeftHandle);
    final outerHitPoint =
        tester.getRect(topLeftHandle).topLeft + const Offset(4, 4);
    final resizeGesture = await tester.startGesture(outerHitPoint);
    await tester.pump();
    await resizeGesture.moveBy(const Offset(24, 36));
    await resizeGesture.up();
    await tester.pumpAndSettle();
    final resizedHandleCenter = tester.getCenter(topLeftHandle);
    expect(resizedHandleCenter.dx, greaterThan(initialHandleCenter.dx));
    expect(resizedHandleCenter.dy, greaterThan(initialHandleCenter.dy));

    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('crop-handle-topLeft')), findsNothing);
    expect(
      tester.widget<Text>(find.text('1:1')).style?.color,
      const Color(0xFFFF55BE),
    );

    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('crop-handle-topLeft')), findsOneWidget);
    expect(tester.widget<Text>(find.text('1:1')).style?.color, Colors.black);
  });

  testWidgets('超高图片的自由裁剪手柄保留顶部安全空间并扩大触控区', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CropScreen(
          draft: DraftProject(originalImageBytes: veryTallImagePng()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topHandle = find.byKey(const ValueKey('crop-handle-top'));
    expect(tester.getSize(topHandle), const Size(64, 64));
    expect(tester.getRect(topHandle).top, greaterThanOrEqualTo(40));
  });

  testWidgets('freeform export follows the moved crop frame', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Uint8List? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Uint8List>(
                MaterialPageRoute(
                  builder: (_) => CropScreen(
                    draft: DraftProject(originalImageBytes: portraitImagePng()),
                    returnCroppedImage: true,
                  ),
                ),
              );
            },
            child: const Text('open crop'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open crop'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('crop-handle-topLeft')),
      const Offset(24, 36),
    );
    await tester.pumpAndSettle();
    final cropTopLeft = tester.getCenter(
      find.byKey(const ValueKey('crop-handle-topLeft')),
    );
    final cropBottomRight = tester.getCenter(
      find.byKey(const ValueKey('crop-handle-bottomRight')),
    );
    final visibleImageRect = tester.getRect(
      find.byKey(const ValueKey('crop-visible-image')),
    );
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final decoded = img.decodePng(result!);
    expect(decoded, isNotNull);
    final decodedImage = decoded!;
    const scale = 330 / 90;
    final cropWidth = ((cropBottomRight.dx - cropTopLeft.dx) / scale).round();
    final cropHeight = ((cropBottomRight.dy - cropTopLeft.dy) / scale).round();
    final sourceLeft = 90 - cropWidth;
    final sourceTop = 120 - cropHeight;

    expect(decodedImage.width, cropWidth);
    expect(decodedImage.height, cropHeight);
    expect(visibleImageRect.bottom, greaterThanOrEqualTo(cropBottomRight.dy));
    expect(decodedImage.getPixel(0, 0).r.toInt(), 40 + sourceLeft);
    expect(decodedImage.getPixel(0, 0).g.toInt(), 120 + sourceTop ~/ 2);
  });

  testWidgets('finished product crop shows its focused guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CropScreen(
          draft: DraftProject(originalImageBytes: portraitImagePng()),
          returnCroppedImage: true,
          ratioOptions: const [CropAspectRatio.square],
          cropHint: '请保留拼豆成品周围的一点边缘',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('请保留拼豆成品周围的一点边缘'), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('9:16'), findsNothing);
    expect(find.byKey(const ValueKey('crop-handle-topLeft')), findsOneWidget);
  });
}
