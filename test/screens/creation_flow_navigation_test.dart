import 'dart:typed_data';

import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/screens/crop_screen.dart';
import 'package:bobobeads/screens/parameter_config_screen.dart';
import 'package:bobobeads/screens/style_conversion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  void useViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  void usePhoneViewport(WidgetTester tester) {
    useViewport(tester, const Size(390, 844));
  }

  Uint8List sampleImagePng({int width = 80, int height = 80}) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 80 + x, 120 + y, 180);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  Future<void> pumpCropScreen(
    WidgetTester tester,
    DraftImageSource source,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CropScreen(
          draft: DraftProject(
            originalImageBytes: sampleImagePng(),
            imageSource: source,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('photo flow enters style conversion after crop', (tester) async {
    usePhoneViewport(tester);
    await pumpCropScreen(tester, DraftImageSource.photo);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('转换风格'), findsAtLeastNWidgets(1));
    expect(find.text('确定参数'), findsNothing);
  });

  testWidgets('illustration flow skips style conversion after crop', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpCropScreen(tester, DraftImageSource.illustration);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('转换风格'), findsNothing);
    expect(find.text('确定参数'), findsOneWidget);
  });

  testWidgets('style conversion result enters parameter config from button', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final image = sampleImagePng();

    await tester.pumpWidget(
      MaterialApp(
        home: StyleConversionScreen(
          draft: DraftProject(
            originalImageBytes: image,
            croppedImageBytes: image,
            imageSource: DraftImageSource.photo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('style-generate-button')));
    await tester.pumpAndSettle();
    expect(find.text('确定参数'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('style-option-picture_book')));
    await tester.pump(const Duration(milliseconds: 120));

    final selectedStyle = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('style-option-picture_book')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final selectedDecoration = selectedStyle.decoration! as BoxDecoration;
    expect(selectedDecoration.border!.top.color, const Color(0xFFFF55BE));

    expect(find.text('风格转换中'), findsOneWidget);
    expect(find.text('转换中'), findsNothing);
    expect(find.text('生成图纸'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('转换风格'), findsAtLeastNWidgets(1));
    expect(find.text('确定参数'), findsNothing);
    expect(find.text('生成图纸'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('style-generate-button')));
    await tester.pumpAndSettle();

    expect(find.text('确定参数'), findsOneWidget);
    expect(find.text('选择大小'), findsOneWidget);
  });

  testWidgets('style tabs scroll tapped clipped option fully into view', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final image = sampleImagePng();

    await tester.pumpWidget(
      MaterialApp(
        home: StyleConversionScreen(
          draft: DraftProject(
            originalImageBytes: image,
            croppedImageBytes: image,
            imageSource: DraftImageSource.photo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fifthStyle = find.byKey(const ValueKey('style-option-pastel_pop'));
    final screenRect = tester.getRect(find.byType(Scaffold));
    final beforeTapRect = tester.getRect(fifthStyle);
    expect(beforeTapRect.right, greaterThan(screenRect.right));

    await tester.tapAt(Offset(screenRect.right - 8, beforeTapRect.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    final afterTapRect = tester.getRect(fifthStyle);
    expect(afterTapRect.right, lessThanOrEqualTo(screenRect.right + 0.5));
    await tester.pump(const Duration(milliseconds: 720));
  });

  for (final entry in {
    '16:9': sampleImagePng(width: 160, height: 90),
    '9:16': sampleImagePng(width: 90, height: 160),
  }.entries) {
    testWidgets('style image keeps at least 30pt margins for ${entry.key}', (
      tester,
    ) async {
      usePhoneViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: StyleConversionScreen(
            draft: DraftProject(
              originalImageBytes: entry.value,
              croppedImageBytes: entry.value,
              imageSource: DraftImageSource.photo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final frameRect = tester.getRect(
        find.byKey(const ValueKey('style-image-frame')),
      );
      final stageRect = tester.getRect(
        find.byKey(const ValueKey('style-image-stage')),
      );
      expect(frameRect.left - stageRect.left, greaterThanOrEqualTo(30));
      expect(stageRect.right - frameRect.right, greaterThanOrEqualTo(30));
      expect(frameRect.top - stageRect.top, greaterThanOrEqualTo(30));
      expect(stageRect.bottom - frameRect.bottom, greaterThanOrEqualTo(30));
    });
  }

  testWidgets('parameter config exposes generation parameters', (tester) async {
    usePhoneViewport(tester);
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
    await tester.pumpAndSettle();

    expect(find.text('确定参数'), findsOneWidget);
    expect(find.text('选择大小'), findsOneWidget);
    final previewRect = tester.getRect(
      find.byKey(const ValueKey('parameter-preview-frame')),
    );
    final previewBorder = tester.widget<Padding>(
      find.byKey(const ValueKey('parameter-preview-white-border')),
    );
    final previewScale = previewRect.width / 240;
    expect(
      (previewBorder.padding as EdgeInsets).left,
      closeTo(4.075 * previewScale, 0.01),
    );
    expect(
      find.byKey(const ValueKey('parameter-custom-size-slider')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('parameter-size-figma_custom')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('parameter-custom-size-slider')),
      findsOneWidget,
    );
    expect(find.text('150 ×150'), findsWidgets);
    final customSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('parameter-custom-size-slider-control')),
    );
    expect(customSlider.min, 8);
    expect(customSlider.max, 150);
    expect(customSlider.divisions, 142);
    customSlider.onChanged!(42);
    await tester.pumpAndSettle();
    expect(find.text('42 ×42'), findsWidgets);

    await tester.dragUntilVisible(
      find.text('色号限制'),
      find.byType(ListView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    expect(find.text('色号限制'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('parameter-color-limit-eight')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('parameter-color-limit-sixteen')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('parameter-color-limit-twentyFour')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('parameter-color-limit-thirtyTwo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('parameter-color-limit-unlimited')),
      findsOneWidget,
    );
    expect(find.text('生成图纸'), findsOneWidget);
  });

  testWidgets(
    'parameter local controls are tappable without generation params',
    (tester) async {
      usePhoneViewport(tester);
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
      await tester.pumpAndSettle();

      double switchLeft(String key) {
        final positioned = tester.widget<AnimatedPositioned>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(AnimatedPositioned),
          ),
        );
        return positioned.left!;
      }

      expect(switchLeft('parameter-remove-background-toggle'), 23);
      await tester.tap(
        find.byKey(const ValueKey('parameter-remove-background-toggle')),
      );
      await tester.pump(const Duration(milliseconds: 180));
      expect(switchLeft('parameter-remove-background-toggle'), 2);

      expect(switchLeft('parameter-denoise-toggle'), 2);
      await tester.tap(find.byKey(const ValueKey('parameter-denoise-toggle')));
      await tester.pump(const Duration(milliseconds: 180));
      expect(switchLeft('parameter-denoise-toggle'), 23);

      expect(find.text('100'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('parameter-saturation-increase')),
      );
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('parameter-saturation-value-input')),
        '75',
      );
      await tester.pumpAndSettle();
      expect(find.text('75'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('parameter-saturation-increase')),
      );
      await tester.pumpAndSettle();
      expect(find.text('85'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('parameter-saturation-value-input')),
        '150',
      );
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('parameter-saturation-decrease')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('parameter-saturation-decrease')),
      );
      await tester.pumpAndSettle();
      expect(find.text('80'), findsOneWidget);
    },
  );

  testWidgets('parameter brand selector keeps its selected menu item visible', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();
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
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('parameter-brand-selector'));
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.getCenter(selector).dy, lessThan(700));
    await tester.tap(selector);
    await tester.pumpAndSettle();

    final unlimitedOption = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('parameter-brand-option-__unlimited__')),
    );
    expect((unlimitedOption.decoration as BoxDecoration).color, Colors.black);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byKey(
          const ValueKey('parameter-brand-option-semantics-__unlimited__'),
        ),
      ),
      containsSemantics(label: '不限', hasSelectedState: true, isSelected: true),
    );

    await tester.tap(
      find.byKey(const ValueKey('parameter-brand-option-mard221')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mard 221'), findsOneWidget);

    await tester.tap(selector);
    await tester.pumpAndSettle();
    final mardOption = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('parameter-brand-option-mard221')),
    );
    expect((mardOption.decoration as BoxDecoration).color, Colors.black);

    await tester.tap(
      find.byKey(const ValueKey('parameter-brand-option-__unlimited__')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: selector, matching: find.text('不限')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('parameter brand selector preserves legacy brand selections', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final image = sampleImagePng();
    const legacyBrandId = 'legacy-brand-with-a-long-name';

    await tester.pumpWidget(
      MaterialApp(
        home: ParameterConfigScreen(
          draft: DraftProject(
            originalImageBytes: image,
            croppedImageBytes: image,
            imageSource: DraftImageSource.illustration,
            paletteBrandId: legacyBrandId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('parameter-brand-selector'));
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();

    final selectedLabel = find.descendant(
      of: selector,
      matching: find.text(legacyBrandId),
    );
    final arrow = find.descendant(
      of: selector,
      matching: find.byIcon(Icons.keyboard_arrow_down),
    );
    expect(
      tester.getRect(selectedLabel).right,
      lessThanOrEqualTo(tester.getRect(arrow).left),
    );

    await tester.tap(selector);
    await tester.pumpAndSettle();
    final legacyOption = tester.widget<DecoratedBox>(
      find.byKey(ValueKey('parameter-brand-option-$legacyBrandId')),
    );
    expect((legacyOption.decoration as BoxDecoration).color, Colors.black);
  });

  for (final entry in {
    'compact iPhone': const Size(375, 667),
    'large iPhone': const Size(430, 932),
  }.entries) {
    testWidgets('parameter config renders on ${entry.key}', (tester) async {
      useViewport(tester, entry.value);
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
      await tester.pumpAndSettle();

      expect(find.text('确定参数'), findsOneWidget);
      expect(find.text('选择大小'), findsOneWidget);
      expect(find.text('生成图纸'), findsOneWidget);
    });
  }

  for (final entry in {
    '16:9': sampleImagePng(width: 160, height: 90),
    '9:16': sampleImagePng(width: 90, height: 160),
  }.entries) {
    testWidgets(
      'parameter preview keeps source aspect ratio for ${entry.key}',
      (tester) async {
        usePhoneViewport(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: ParameterConfigScreen(
              draft: DraftProject(
                originalImageBytes: entry.value,
                croppedImageBytes: entry.value,
                styledImageBytes: entry.value,
                imageSource: DraftImageSource.photo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final previewRect = tester.getRect(
          find.byKey(const ValueKey('parameter-preview-frame')),
        );
        final expectedRatio = entry.key == '16:9' ? 16 / 9 : 9 / 16;
        expect(
          previewRect.width / previewRect.height,
          closeTo(expectedRatio, 0.01),
        );
      },
    );
  }
}
