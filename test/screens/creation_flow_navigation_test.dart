import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/navigation/home_navigation.dart';
import 'package:bobobeads/screens/crop_screen.dart';
import 'package:bobobeads/screens/parameter_config_screen.dart';
import 'package:bobobeads/screens/style_conversion_screen.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:bobobeads/services/style_thumbnail_cache.dart';
import 'package:bobobeads/widgets/patterns_hint_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  Future<BackendServices> createStyleBackend(Uint8List outputImage) async {
    final styles = List.generate(
      5,
      (index) => {
        'styleId': '${index + 1}',
        'styleKey': const [
          'picture_book',
          'bold_line',
          'soft_daily',
          'playful_doodle',
          'pastel_pop',
        ][index],
        'name': '风格 ${index + 1}',
        'coverUrl': 'https://image.example.test/style-$index.png',
        'costCredits': 1,
      },
    );
    final services = BackendServices(
      baseUrl: 'http://api.example.test',
      store: _MemoryApiSessionStore(),
      styleThumbnails: StyleThumbnailCache(
        httpClient: MockClient(
          (_) async => http.Response.bytes(outputImage, 200),
        ),
        directoryProvider: () async => Directory.systemTemp,
      ),
      httpClient: MockClient((request) async {
        if (request.url.host == 'image.example.test' ||
            request.url.host == 'storage.example.test') {
          return http.Response.bytes(outputImage, 200);
        }
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'token',
            'refreshToken': 'refresh',
            'expiresIn': 3600,
            'user': {'userId': 'guest'},
          },
          '/api/v1/ai/styles' => {'styles': styles},
          '/api/v1/media/upload-token' => {
            'uploadUrl': 'https://storage.example.test/style-input.png',
            'fileKey': 'style_input/style-input.png',
            'headers': {'Content-Type': 'image/png'},
            'uploadMethod': 'PUT',
            'maxFileSize': 20 * 1024 * 1024,
          },
          '/api/v1/media/report-upload' => const <String, Object?>{},
          '/api/v1/ai/style-generations' => {
            'taskId': 'task-1',
            'status': 0,
            'creditsDeducted': 1,
            'remainingBalance': 9,
            'duplicated': false,
          },
          '/api/v1/ai/style-generations/task-1' => {
            'task': {
              'taskId': 'task-1',
              'styleId': '1',
              'status': 2,
              'outputImageUrl': 'https://image.example.test/output.png',
            },
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'header': {'code': 0, 'message': 'success'},
              ...body,
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await services.loadAiStyles();
    return services;
  }

  Future<void> pumpStyleScreen(WidgetTester tester, Uint8List image) async {
    final backend = await createStyleBackend(image);
    await tester.pumpWidget(
      BackendScope(
        services: backend,
        child: MaterialApp(
          home: StyleConversionScreen(
            draft: DraftProject(
              originalImageBytes: image,
              croppedImageBytes: image,
              imageSource: DraftImageSource.photo,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('photo flow enters style conversion after crop', (tester) async {
    usePhoneViewport(tester);
    await pumpCropScreen(tester, DraftImageSource.photo);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

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

  testWidgets(
    'style conversion lets the original image enter parameter config',
    (tester) async {
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
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('style-generate-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('确定参数'), findsOneWidget);
      expect(find.text('选择大小'), findsOneWidget);
    },
  );

  testWidgets(
    'style conversion confirms before submitting and then enters parameters',
    (tester) async {
      usePhoneViewport(tester);
      final image = sampleImagePng();

      await pumpStyleScreen(tester, image);

      await tester.tap(find.byKey(const ValueKey('style-option-picture_book')));
      await tester.pump();
      expect(find.text('是否要转换'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(find.text('是否要转换'), findsNothing);
      expect(find.text('参数选择'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('style-option-picture_book')));
      await tester.pump();
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      final selectedStyle = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('style-option-picture_book')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final selectedDecoration = selectedStyle.decoration! as BoxDecoration;
      expect(selectedDecoration.border!.top.color, const Color(0xFFFF55BE));

      expect(find.text('参数选择'), findsOneWidget);

      expect(find.text('转换风格'), findsAtLeastNWidgets(1));
      expect(find.text('确定参数'), findsNothing);
      expect(find.text('参数选择'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('style-generate-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('确定参数'), findsOneWidget);
      expect(find.text('选择大小'), findsOneWidget);
    },
  );

  testWidgets('style conversion back returns directly to the home route', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final image = sampleImagePng();
    const homeKey = ValueKey('navigation-test-home');

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [appNavigatorObserver],
        home: Builder(
          builder: (context) => Scaffold(
            body: GestureDetector(
              key: homeKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StyleConversionScreen(
                    draft: DraftProject(
                      originalImageBytes: image,
                      croppedImageBytes: image,
                      imageSource: DraftImageSource.photo,
                    ),
                  ),
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(homeKey));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(homeKey), findsOneWidget);
    expect(find.text('转换风格'), findsNothing);
  });

  testWidgets('draft hint uses the style conversion return copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PatternsHintDialog(destination: PatternsHintDestination.drafts),
      ),
    );

    expect(find.text('草稿将保存在“我的-我的图纸”中'), findsOneWidget);
  });

  testWidgets('style conversion loading copy rotates while generation runs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: StyleConversionLoadingCopy())),
      ),
    );

    expect(find.text('风格转换中'), findsOneWidget);
    expect(find.text('完成后可在“我的”中查看'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('风格转换中'), findsNothing);
    expect(find.text('完成后可在“我的”中查看'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('风格转换中'), findsOneWidget);
    expect(find.text('完成后可在“我的”中查看'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('style tabs scroll tapped clipped option fully into view', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final image = sampleImagePng();

    await pumpStyleScreen(tester, image);

    final fifthStyle = find.byKey(const ValueKey('style-option-pastel_pop'));
    final screenRect = tester.getRect(find.byType(Scaffold));
    final beforeTapRect = tester.getRect(fifthStyle);
    expect(beforeTapRect.right, greaterThan(screenRect.right));

    await tester.tapAt(Offset(screenRect.right - 8, beforeTapRect.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    final afterTapRect = tester.getRect(fifthStyle);
    expect(afterTapRect.right, lessThanOrEqualTo(screenRect.right + 0.5));
    await tester.pump();
  });

  for (final entry in {
    '16:9': sampleImagePng(width: 160, height: 90),
    '9:16': sampleImagePng(width: 90, height: 160),
  }.entries) {
    testWidgets('style image keeps at least 30pt margins for ${entry.key}', (
      tester,
    ) async {
      usePhoneViewport(tester);

      await pumpStyleScreen(tester, entry.value);

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

  testWidgets('parameter config back returns directly to the home route', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final image = sampleImagePng();
    const homeKey = ValueKey('navigation-test-home');

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [appNavigatorObserver],
        home: Builder(
          builder: (context) => Scaffold(
            body: GestureDetector(
              key: homeKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ParameterConfigScreen(
                    draft: DraftProject(
                      originalImageBytes: image,
                      croppedImageBytes: image,
                      imageSource: DraftImageSource.illustration,
                    ),
                  ),
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(homeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.byKey(homeKey), findsOneWidget);
    expect(find.text('确定参数'), findsNothing);
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

      Color switchTrackColor(String key) {
        final track = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (track.decoration as BoxDecoration).color!;
      }

      expect(switchLeft('parameter-remove-background-toggle'), 23);
      expect(
        switchTrackColor('parameter-remove-background-toggle'),
        const Color(0xFFFF55BE),
      );
      await tester.tap(
        find.byKey(const ValueKey('parameter-remove-background-toggle')),
      );
      await tester.pump(const Duration(milliseconds: 180));
      expect(switchLeft('parameter-remove-background-toggle'), 2);
      expect(
        switchTrackColor('parameter-remove-background-toggle'),
        const Color(0xFFDEE2ED),
      );

      expect(switchLeft('parameter-denoise-toggle'), 2);
      expect(
        switchTrackColor('parameter-denoise-toggle'),
        const Color(0xFFDEE2ED),
      );
      await tester.tap(find.byKey(const ValueKey('parameter-denoise-toggle')));
      await tester.pump(const Duration(milliseconds: 180));
      expect(switchLeft('parameter-denoise-toggle'), 23);
      expect(
        switchTrackColor('parameter-denoise-toggle'),
        const Color(0xFFFF55BE),
      );

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
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('parameter-preview-frame')),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
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

class _MemoryApiSessionStore extends ApiSessionStore {
  AuthSession? _session;
  String? _pendingStyleRequestId;

  @override
  Future<String> readOrCreateDeviceId() async => 'device-1';

  @override
  Future<String> readOrCreateGuestCredential() async => 'guest-credential';

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> saveSession(AuthSession session) async {
    _session = session;
  }

  @override
  Future<String> readOrCreatePendingStyleClientRequestId() async {
    return _pendingStyleRequestId ??= 'style-request-1';
  }

  @override
  Future<void> clearPendingStyleClientRequestId() async {
    _pendingStyleRequestId = null;
  }
}
