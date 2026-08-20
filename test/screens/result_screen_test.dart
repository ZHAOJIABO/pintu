import 'dart:convert';
import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/rendering/pattern_chart_painter.dart';
import 'package:bobobeads/screens/result_screen.dart';
import 'package:bobobeads/screens/upload_screen.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:bobobeads/services/pattern_export_service.dart';
import 'package:bobobeads/widgets/bead_board_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final viewport in const [Size(375, 667), Size(430, 932)]) {
    testWidgets('ResultScreen renders Figma drawing layout on $viewport', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(home: ResultScreen(pattern: _pattern())),
      );

      expect(find.text('图纸'), findsOneWidget);
      expect(find.text('共计2个颜色'), findsOneWidget);
      expect(find.text('4颗豆子'), findsOneWidget);
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('H7'), findsOneWidget);
      expect(find.text('立即开拼'), findsOneWidget);
      expect(find.text('编辑'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('official template shows its author below the chart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          pattern: _pattern(),
          template: _template(authorName: '土豆颠婆'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('result-pattern-author')), findsOneWidget);
    expect(find.text('by土豆颠婆'), findsOneWidget);
  });

  testWidgets('bead color references use SemiBold-Round text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    final colorRef = tester.widget<Text>(find.text('R1'));

    expect(colorRef.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('drawing back returns directly to the home route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const homeKey = ValueKey('navigation-test-home');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: GestureDetector(
              key: homeKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ResultScreen(pattern: _pattern()),
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

    expect(find.byType(UploadScreen), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);
    expect(find.text('图纸'), findsNothing);
  });

  testWidgets('drawing navigation bar and actions are 44pt tall', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    final navigationBars = find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.height == 44,
    );

    expect(navigationBars, findsNWidgets(3));
  });

  testWidgets('drawing chart keeps 20pt margins inside image area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    final areaRect = tester.getRect(
      find.byKey(const ValueKey('result-chart-area')),
    );
    final frameRect = tester.getRect(
      find.byKey(const ValueKey('result-chart-frame')),
    );

    expect(frameRect.left - areaRect.left, 20);
    expect(areaRect.right - frameRect.right, 20);
    expect(frameRect.top - areaRect.top, 20);
    expect(areaRect.bottom - frameRect.bottom, 20);
    expect(frameRect.width, 350);
    expect(frameRect.height, 350);
  });

  testWidgets('drawing chart uses result page grid colors', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    final chartPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<PatternChartPainter>()
        .single;

    expect(
      chartPainter.minorGridColor,
      PatternChartPainter.defaultMinorGridColor,
    );
    expect(
      chartPainter.majorGridColor,
      PatternChartPainter.defaultMajorGridColor,
    );
    expect(chartPainter.showBorderCoordinates, isTrue);
    expect(chartPainter.borderColor, PatternChartPainter.defaultBorderColor);
    expect(chartPainter.showCellLabels, isTrue);
  });

  testWidgets('exported PNG uses a high resolution canvas', (tester) async {
    final imageSize = const PatternExportService().exportChartPngPixelSize(
      _pattern(),
    );

    expect(imageSize.width, greaterThanOrEqualTo(1200));
  });

  testWidgets('printer action saves image and shows success toast', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var saved = false;
    Uint8List? savedWatermark;
    final watermark = Uint8List.fromList([1, 2, 3]);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          pattern: _pattern(),
          exportService: _FakePatternExportService(
            onSave: (_, value) async {
              saved = true;
              savedWatermark = value;
            },
          ),
          loadWatermarkPngBytes: () async => watermark,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('result-save-image-button')));
    await tester.pump();

    expect(saved, isTrue);
    expect(savedWatermark, watermark);
    expect(find.text('图纸已保存'), findsOneWidget);
  });

  testWidgets('does not save the original chart when watermark loading fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          pattern: _pattern(),
          exportService: _FakePatternExportService(
            onSave: (pattern, watermark) async => saved = true,
          ),
          loadWatermarkPngBytes: () async => throw StateError('offline'),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('result-save-image-button')));
    await tester.pump();

    expect(saved, isFalse);
    expect(find.text('水印加载失败，请重试'), findsOneWidget);
  });

  testWidgets('edit action opens the pattern editor', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pattern-editor-screen')), findsOneWidget);
  });

  testWidgets('pending submission keeps the work viewable but locks editing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(pattern: _pattern(), isEditingLocked: true),
      ),
    );

    expect(find.text('审核中'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('result-secondary-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pattern-editor-screen')), findsNothing);
    expect(find.text('投稿审核中，审核完成后即可修改'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('立即开拼'));
    await tester.pumpAndSettle();

    expect(find.byType(BeadBoardPreview), findsOneWidget);
    expect(find.byKey(const ValueKey('bead-mode-edit-button')), findsNothing);
  });

  testWidgets('a pending submission cannot be deleted', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var deletedWorkId = '';
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        final body = switch ((request.method, request.url.path)) {
          ('POST', '/api/v1/auth/guest') => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
          ('DELETE', '/api/v1/works/64') => const <String, Object?>{},
          _ => throw StateError(
            'Unexpected request: ${request.method} ${request.url}',
          ),
        };
        final header = request.method == 'DELETE'
            ? const {'code': 2006, 'message': 'work is under review'}
            : const {'code': 0, 'message': 'success'};
        return http.Response(jsonEncode({'header': header, ...body}), 200);
      }),
    );

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: MaterialApp(
          home: ResultScreen(
            pattern: _pattern(),
            workId: '64',
            onWorkDeleted: (workId) => deletedWorkId = workId,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('result-delete-work-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('result-delete-work-confirm')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(deletedWorkId, isEmpty);
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('投稿审核中，暂时无法删除'), findsOneWidget);
  });

  testWidgets('官方模板图纸仅提供开拼和收藏，并可切换收藏状态', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final requests = <http.Request>[];
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
          '/api/v1/templates/template-001/favorite' => {
            'isFavorited': request.method == 'POST',
            'favoriteCount': request.method == 'POST' ? 1 : 0,
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            ...body,
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: MaterialApp(
          home: ResultScreen(pattern: _pattern(), template: _template()),
        ),
      ),
    );

    expect(find.text('编辑'), findsNothing);
    expect(find.text('立即开拼'), findsOneWidget);
    final favoriteButton = find.byKey(
      const ValueKey('result-secondary-action'),
    );
    expect(
      find.descendant(of: favoriteButton, matching: find.text('收藏')),
      findsOneWidget,
    );

    await tester.tap(favoriteButton);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(
      requests.where(
        (request) =>
            request.url.path == '/api/v1/templates/template-001/favorite',
      ),
      hasLength(1),
    );
    expect(
      find.descendant(of: favoriteButton, matching: find.text('已收藏')),
      findsOneWidget,
    );
    expect(find.text('已保存至“我的-收藏”'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('patterns-hint-dialog-favorites-illustration')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('patterns-hint-dialog-confirm')),
    );
    await tester.pumpAndSettle();

    await tester.tap(favoriteButton);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(
      requests
          .where(
            (request) =>
                request.url.path == '/api/v1/templates/template-001/favorite',
          )
          .map((request) => request.method),
      ['POST', 'DELETE'],
    );
    expect(
      find.descendant(of: favoriteButton, matching: find.text('收藏')),
      findsOneWidget,
    );
  });

  testWidgets('官方模板开拼页不提供编辑图纸入口', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(pattern: _pattern(), template: _template()),
      ),
    );

    await tester.tap(find.text('立即开拼'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bead-mode-edit-button')), findsNothing);
  });

  for (final viewport in const [Size(375, 667), Size(430, 932)]) {
    testWidgets(
      'generated result shows Figma patterns hint dialog on $viewport',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ResultScreen(pattern: _pattern(), showGeneratedHint: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('图纸也可以在“我的-图纸”中查看哦～'), findsOneWidget);
        expect(find.text('我知道啦！'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('patterns-hint-dialog')),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('patterns-hint-dialog'))),
          const Size(330, 305),
        );
        expect(
          tester.getSize(
            find.byKey(const ValueKey('patterns-hint-dialog-confirm')),
          ),
          const Size(260, 52),
        );

        await tester.tap(
          find.byKey(const ValueKey('patterns-hint-dialog-confirm')),
        );
        await tester.pumpAndSettle();

        expect(find.text('图纸也可以在“我的-图纸”中查看哦～'), findsNothing);
      },
    );
  }

  testWidgets('immediate start opens bead mode', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    await tester.tap(find.text('立即开拼'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bead-mode-edit-button')), findsOneWidget);
    expect(find.byType(BeadBoardPreview), findsOneWidget);
    expect(find.text('全部'), findsNothing);
    expect(find.text('H7'), findsOneWidget);

    final boardPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BeadBoardPainter>()
        .single;
    expect(boardPainter.boardWidth, 50);
    expect(boardPainter.boardHeight, 50);
    expect(boardPainter.showColorRefs, isFalse);
    expect(boardPainter.selectedRef, isNull);
  });

  testWidgets('bead mode and editor retain charts larger than 50 by 50', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _patternWithSize(80, 72))),
    );

    await tester.tap(find.text('立即开拼'));
    await tester.pumpAndSettle();

    BeadBoardPainter boardPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BeadBoardPainter>()
        .single;
    expect(boardPainter.boardWidth, 80);
    expect(boardPainter.boardHeight, 72);

    await tester.tap(find.byKey(const ValueKey('bead-mode-edit-button')));
    await tester.pumpAndSettle();

    boardPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BeadBoardPainter>()
        .single;
    expect(boardPainter.boardWidth, 80);
    expect(boardPainter.boardHeight, 72);
  });

  testWidgets('bead mode filters board by selected color ref', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    await tester.tap(find.text('立即开拼'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('R1'));
    await tester.pump();

    BeadBoardPainter boardPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BeadBoardPainter>()
        .single;
    expect(boardPainter.selectedRef, 'R1');
    expect(
      tester
          .widget<BeadModeUsageStrip>(find.byType(BeadModeUsageStrip))
          .selectedRef,
      'R1',
    );

    await tester.tap(find.text('R1'));
    await tester.pump();

    boardPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BeadBoardPainter>()
        .single;
    expect(boardPainter.selectedRef, isNull);
  });
}

class _FakePatternExportService extends PatternExportService {
  final Future<void> Function(GeneratedPattern pattern, Uint8List? watermark)
  onSave;

  const _FakePatternExportService({required this.onSave});

  @override
  Future<void> saveChartPngToPhotoLibrary(
    GeneratedPattern pattern, {
    Uint8List? watermarkPngBytes,
  }) {
    return onSave(pattern, watermarkPngBytes);
  }
}

GeneratedPattern _pattern() {
  final red = PaletteEntry(
    name: 'Red',
    ref: 'R1',
    symbol: 'R',
    color: BeadColor.fromInt(255, 40, 80, 255),
    prefix: 'T',
  );
  final black = PaletteEntry(
    name: 'Black',
    ref: 'H7',
    symbol: 'H',
    color: BeadColor.fromInt(0, 0, 0, 255),
    prefix: 'T',
  );

  final pixels = Uint8List.fromList([
    255,
    40,
    80,
    255,
    0,
    0,
    0,
    255,
    0,
    0,
    0,
    255,
    255,
    40,
    80,
    255,
  ]);

  return GeneratedPattern(
    pixels: pixels,
    width: 2,
    height: 2,
    usage: const {'R1': 2, 'H7': 2},
    paletteEntries: [red, black],
    draft: DraftProject(originalImageBytes: Uint8List(0)),
  );
}

TemplateItem _template({bool isFavorited = false, String authorName = ''}) {
  return TemplateItem(
    templateId: 'template-001',
    title: '兔子模板',
    authorName: authorName,
    previewUrl: '',
    thumbnailUrl: '',
    description: '',
    boardSpec: '2x2',
    tags: const [],
    difficulty: 1,
    width: 2,
    height: 2,
    colorCount: 2,
    isFree: true,
    creditCost: 0,
    downloadCount: 0,
    favoriteCount: 0,
    isFavorited: isFavorited,
  );
}

class _MemoryApiSessionStore extends ApiSessionStore {
  AuthSession? _session;

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
}

GeneratedPattern _patternWithSize(int width, int height) {
  final base = _pattern();
  final pixels = Uint8List(width * height * 4);
  for (var offset = 0; offset < pixels.length; offset += 4) {
    final isRed = (offset ~/ 4).isEven;
    pixels[offset] = isRed ? 255 : 0;
    pixels[offset + 1] = 0;
    pixels[offset + 2] = 0;
    pixels[offset + 3] = 255;
  }

  return base.copyWith(
    pixels: pixels,
    width: width,
    height: height,
    usage: {'R1': width * height ~/ 2, 'H7': width * height ~/ 2},
  );
}
