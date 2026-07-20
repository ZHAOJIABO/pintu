import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/screens/pattern_editor_screen.dart';
import 'package:bobobeads/widgets/bead_board_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final viewport in const [Size(375, 667), Size(430, 932)]) {
    testWidgets('pattern editor fits the Figma layout on $viewport', (
      tester,
    ) async {
      _setViewport(tester, viewport);

      await tester.pumpWidget(
        MaterialApp(
          home: PatternEditorScreen(pattern: _pattern(), showBrushGuide: false),
        ),
      );

      expect(
        find.byKey(const ValueKey('pattern-editor-screen')),
        findsOneWidget,
      );
      expect(find.text('画笔'), findsNWidgets(2));
      expect(find.text('色板'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('当前'), findsOneWidget);
      expect(find.text('取色器'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'brush guide reveals each instruction and toolbar target in order',
    (tester) async {
      _setViewport(tester, const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(home: PatternEditorScreen(pattern: _pattern())),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const ValueKey('brush-mode-guide-card'))),
        const Size(330, 297),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('brush-mode-guide-title'))),
        const Size(150, 48),
      );
      expect(_guideStepOpacity(tester, 0), 0);
      expect(
        find.byKey(const ValueKey('brush-mode-guide-underline-currentColor')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('brush-mode-guide-panel-tabs')),
        findsOneWidget,
      );
      final guideScrim = find.byKey(const ValueKey('brush-mode-guide-scrim'));
      expect(
        tester.widget<ColoredBox>(guideScrim).color,
        const Color(0x80000000),
      );
      expect(
        find.byKey(const ValueKey('brush-mode-guide-toolbar-clip')),
        findsOneWidget,
      );
      final toolbarMask = find.byKey(
        const ValueKey('brush-mode-guide-toolbar-mask'),
      );
      expect(tester.getSize(toolbarMask), const Size(390, 106));
      expect(
        tester.widget<ColoredBox>(toolbarMask).color,
        const Color(0x99000000),
      );
      expect(
        find.byKey(
          const ValueKey('brush-mode-guide-toolbar-target-currentColor'),
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey('brush-mode-guide-skip')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('brush-mode-guide-toolbar-target-currentColor'),
        ),
        findsOneWidget,
      );
      expect(_guideStepOpacity(tester, 0), 1);
      expect(_guideStepOpacity(tester, 1), 0);

      await tester.pump(const Duration(milliseconds: 850));
      await tester.pump(const Duration(milliseconds: 300));

      expect(_guideStepOpacity(tester, 1), 1);
      expect(
        find.byKey(const ValueKey('brush-mode-guide-toolbar-target-brush')),
        findsOneWidget,
      );

      for (final (index, target) in <(int, String)>[
        (2, 'picker'),
        (3, 'eraser'),
      ]) {
        await tester.pump(const Duration(milliseconds: 850));
        await tester.pump(const Duration(milliseconds: 300));

        expect(_guideStepOpacity(tester, index), 1);
        expect(
          find.byKey(ValueKey('brush-mode-guide-toolbar-target-$target')),
          findsOneWidget,
        );
      }

      expect(
        tester.getSize(
          find.byKey(const ValueKey('brush-mode-guide-completion')),
        ),
        const Size(260, 52),
      );

      await tester.tap(
        find.byKey(const ValueKey('brush-mode-guide-completion')),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('brush-mode-guide-skip')), findsNothing);
      expect(find.text('画笔'), findsNWidgets(2));
    },
  );

  testWidgets('does not show the brush guide after completion', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'brush_mode_guide_completed': true,
    });
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(home: PatternEditorScreen(pattern: _pattern())),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('brush-mode-guide-skip')), findsNothing);
  });

  for (final viewport in const [Size(375, 667), Size(430, 932)]) {
    testWidgets('brush guide fits $viewport after all steps appear', (
      tester,
    ) async {
      _setViewport(tester, viewport);

      await tester.pumpWidget(
        MaterialApp(home: PatternEditorScreen(pattern: _pattern())),
      );
      await tester.pump();
      for (var step = 0; step < 3; step++) {
        await tester.pump(const Duration(milliseconds: 850));
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(_guideStepOpacity(tester, 3), 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('canvas painting can be undone', (tester) async {
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        home: PatternEditorScreen(pattern: _pattern(), showBrushGuide: false),
      ),
    );

    final canvas = find.byKey(const ValueKey('pattern-editor-canvas'));
    final painter = _editorPainter(tester);
    final firstCellCenter = Offset(
      painter.labelBand + 24.5 * painter.cellSize,
      painter.labelBand + 24.5 * painter.cellSize,
    );
    await tester.tapAt(tester.getTopLeft(canvas) + firstCellCenter);
    await tester.pump();

    expect(_editorPainter(tester).pixels.take(4), [233, 0, 48, 255]);

    await tester.tap(find.text('上一步'));
    await tester.pump();

    expect(_editorPainter(tester).pixels.take(4), [0, 0, 0, 255]);
  });

  testWidgets('editor uses the bead-mode board without rulers or a cursor', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        home: PatternEditorScreen(pattern: _pattern(), showBrushGuide: false),
      ),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final painter = _editorPainter(tester);
    expect(viewer.scaleEnabled, isTrue);
    expect(painter.selectedRef, isNull);
    expect(find.byKey(const ValueKey('bead-mode-pinned-rulers')), findsNothing);

    viewer.transformationController!.value = Matrix4.diagonal3Values(3, 3, 1)
      ..setTranslationRaw(-180, -240, 0);
    await tester.pump();

    expect(find.byKey(const ValueKey('bead-mode-pinned-rulers')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deselecting the active tool enables board panning', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        home: PatternEditorScreen(pattern: _pattern(), showBrushGuide: false),
      ),
    );

    final viewer = find.byType(InteractiveViewer);
    expect(tester.widget<InteractiveViewer>(viewer).panEnabled, isFalse);

    await tester.tap(find.text('画笔').last);
    await tester.pump();

    expect(tester.widget<InteractiveViewer>(viewer).panEnabled, isTrue);
    expect(tester.widget<InteractiveViewer>(viewer).scaleEnabled, isTrue);
  });

  testWidgets('palette undo and redo align with the brush toolbar', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: PatternEditorScreen(
          pattern: _colorPickerPattern(),
          showBrushGuide: false,
        ),
      ),
    );

    final historyControls = find.byKey(
      const ValueKey('editor-history-controls'),
    );
    final brushHistoryControls = tester.getRect(historyControls);

    await tester.tap(find.text('色板'));
    await tester.pump();

    expect(tester.getRect(historyControls), brushHistoryControls);
    final historyMask = find.descendant(
      of: historyControls,
      matching: find.byType(ColoredBox),
    );
    expect(tester.widget<ColoredBox>(historyMask).color, Colors.white);
    final historyMaskRect = tester.getRect(historyMask);
    expect(historyMaskRect.left, brushHistoryControls.left - 15);
    expect(historyMaskRect.top, brushHistoryControls.top - 4);
    expect(historyMaskRect.height, 66);
  });

  testWidgets('palette colour tiles match the brush current-colour tile', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: PatternEditorScreen(
          pattern: _colorPickerPattern(),
          showBrushGuide: false,
        ),
      ),
    );

    final currentColorTile = find.byKey(
      const ValueKey('editor-current-color-button'),
    );
    final brushTileRect = tester.getRect(currentColorTile);

    await tester.tap(find.text('色板'));
    await tester.pump();

    expect(
      tester.widget<ListView>(find.byType(ListView)).clipBehavior,
      Clip.none,
    );
    expect(
      tester.getRect(
        find.byKey(const ValueKey('editor-palette-usage-option-A2')),
      ),
      brushTileRect,
    );
  });

  testWidgets(
    'current colour defaults to the most-used and picker sorts used codes',
    (tester) async {
      _setViewport(tester, const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          home: PatternEditorScreen(
            pattern: _colorPickerPattern(),
            showBrushGuide: false,
          ),
        ),
      );

      final currentColor = find.byKey(
        const ValueKey('editor-current-color-button'),
      );
      expect(
        find.descendant(of: currentColor, matching: find.text('A2')),
        findsOneWidget,
      );

      await tester.tap(currentColor);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('editor-current-color-picker')),
        findsOneWidget,
      );
      final a2 = find.byKey(const ValueKey('editor-current-color-option-A2'));
      final b1 = find.byKey(const ValueKey('editor-current-color-option-B1'));
      final d6 = find.byKey(const ValueKey('editor-current-color-option-D6'));
      expect(a2, findsOneWidget);
      expect(b1, findsOneWidget);
      expect(d6, findsOneWidget);
      expect(
        find.byKey(const ValueKey('editor-current-color-option-Z9')),
        findsNothing,
      );
      expect(tester.getTopLeft(a2).dx, lessThan(tester.getTopLeft(b1).dx));
      expect(tester.getTopLeft(b1).dx, lessThan(tester.getTopLeft(d6).dx));

      await tester.tap(d6);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: currentColor, matching: find.text('D6')),
        findsOneWidget,
      );
    },
  );

  testWidgets('palette replaces all beads of a selected colour in one step', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: PatternEditorScreen(
          pattern: _colorPickerPattern(),
          showBrushGuide: false,
        ),
      ),
    );

    await tester.tap(find.text('色板'));
    await tester.pump();

    final a2 = find.byKey(const ValueKey('editor-palette-usage-option-A2'));
    expect(a2, findsOneWidget);
    expect(find.descendant(of: a2, matching: find.text('3')), findsOneWidget);

    await tester.tap(a2);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('editor-color-replacement-sheet')),
      findsOneWidget,
    );
    expect(find.text('相近颜色'), findsOneWidget);
    expect(find.text('所有颜色'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('editor-color-replacement-all-option-B1')),
    );
    await tester.pumpAndSettle();

    final blue = [33, 150, 243, 255];
    expect(_editorPainter(tester).pixels.sublist(0, 12), [
      ...blue,
      ...blue,
      ...blue,
    ]);

    await tester.tap(find.text('上一步'));
    await tester.pump();
    final green = [76, 175, 80, 255];
    expect(_editorPainter(tester).pixels.sublist(0, 12), [
      ...green,
      ...green,
      ...green,
    ]);

    await tester.tap(find.text('下一步'));
    await tester.pump();
    expect(_editorPainter(tester).pixels.sublist(0, 12), [
      ...blue,
      ...blue,
      ...blue,
    ]);
  });

  testWidgets('palette replaces only the tapped bead on the board', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: PatternEditorScreen(
          pattern: _colorPickerPattern(),
          showBrushGuide: false,
        ),
      ),
    );

    await tester.tap(find.text('色板'));
    await tester.pump();

    final canvas = find.byKey(const ValueKey('pattern-editor-canvas'));
    final painter = _editorPainter(tester);
    final firstCellCenter = Offset(
      painter.labelBand + 23.5 * painter.cellSize,
      painter.labelBand + 24.5 * painter.cellSize,
    );
    await tester.tapAt(tester.getTopLeft(canvas) + firstCellCenter);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('editor-color-replacement-all-option-D6')),
    );
    await tester.pumpAndSettle();

    expect(_editorPainter(tester).pixels.sublist(0, 4), [244, 67, 54, 255]);
    expect(_editorPainter(tester).pixels.sublist(4, 8), [76, 175, 80, 255]);
  });

  for (final viewport in const [Size(375, 667), Size(430, 932)]) {
    testWidgets('palette replacement sheet fits $viewport', (tester) async {
      _setViewport(tester, viewport);
      await tester.pumpWidget(
        MaterialApp(
          home: PatternEditorScreen(
            pattern: _colorPickerPattern(),
            showBrushGuide: false,
          ),
        ),
      );

      await tester.tap(find.text('色板'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('editor-palette-usage-option-A2')),
      );
      await tester.pumpAndSettle();

      final sheet = find.byKey(
        const ValueKey('editor-color-replacement-sheet'),
      );
      expect(sheet, findsOneWidget);
      expect(tester.getSize(sheet).height, 480);
      expect(find.text('相近颜色'), findsOneWidget);
      expect(find.text('所有颜色'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('editor-color-replacement-nearby-option-D6')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('editor-color-replacement-all-option-D6')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('editing pixels does not recenter the board layout', () {
    final layoutPixels = Uint8List.fromList([
      233,
      0,
      48,
      255,
      233,
      0,
      48,
      255,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);
    final editedPixels = Uint8List.fromList(layoutPixels)
      ..setRange(32, 36, [91, 119, 36, 255]);

    final painter = BeadBoardPainter(
      pixels: editedPixels,
      layoutPixels: layoutPixels,
      patternWidth: 2,
      patternHeight: 5,
      boardWidth: 50,
      boardHeight: 50,
      cellSize: 8,
      labelBand: 10,
    );

    expect(painter.patternCellOffset, const Offset(24, 24));
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

BeadBoardPainter _editorPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<BeadBoardPainter>()
      .single;
}

double _guideStepOpacity(WidgetTester tester, int index) {
  final opacity = find.descendant(
    of: find.byKey(ValueKey('brush-mode-guide-step-$index')),
    matching: find.byType(AnimatedOpacity),
  );
  return tester.widget<AnimatedOpacity>(opacity).opacity;
}

GeneratedPattern _pattern() {
  final black = PaletteEntry(
    name: '黑色',
    ref: 'H7',
    symbol: 'H',
    color: BeadColor.fromInt(0, 0, 0, 255),
    prefix: 'MARD',
  );
  final red = PaletteEntry(
    name: '红色',
    ref: 'F5',
    symbol: 'F',
    color: BeadColor.fromInt(233, 0, 48, 255),
    prefix: 'MARD',
  );

  return GeneratedPattern(
    pixels: Uint8List.fromList([
      0,
      0,
      0,
      255,
      233,
      0,
      48,
      255,
      233,
      0,
      48,
      255,
      233,
      0,
      48,
      255,
    ]),
    width: 2,
    height: 2,
    usage: const {'H7': 1, 'F5': 3},
    paletteEntries: [black, red],
    draft: DraftProject(originalImageBytes: Uint8List(0)),
  );
}

GeneratedPattern _colorPickerPattern() {
  final a2 = PaletteEntry(
    name: '绿色',
    ref: 'A2',
    symbol: 'A',
    color: BeadColor.fromInt(76, 175, 80, 255),
    prefix: 'MARD',
  );
  final b1 = PaletteEntry(
    name: '蓝色',
    ref: 'B1',
    symbol: 'B',
    color: BeadColor.fromInt(33, 150, 243, 255),
    prefix: 'MARD',
  );
  final d6 = PaletteEntry(
    name: '红色',
    ref: 'D6',
    symbol: 'D',
    color: BeadColor.fromInt(244, 67, 54, 255),
    prefix: 'MARD',
  );
  final z9 = PaletteEntry(
    name: '未使用',
    ref: 'Z9',
    symbol: 'Z',
    color: BeadColor.fromInt(255, 193, 7, 255),
    prefix: 'MARD',
  );

  return GeneratedPattern(
    pixels: Uint8List.fromList([
      a2.color.rInt,
      a2.color.gInt,
      a2.color.bInt,
      a2.color.aInt,
      a2.color.rInt,
      a2.color.gInt,
      a2.color.bInt,
      a2.color.aInt,
      a2.color.rInt,
      a2.color.gInt,
      a2.color.bInt,
      a2.color.aInt,
      b1.color.rInt,
      b1.color.gInt,
      b1.color.bInt,
      b1.color.aInt,
      d6.color.rInt,
      d6.color.gInt,
      d6.color.bInt,
      d6.color.aInt,
      d6.color.rInt,
      d6.color.gInt,
      d6.color.bInt,
      d6.color.aInt,
    ]),
    width: 3,
    height: 2,
    usage: const {'A2': 3, 'B1': 1, 'D6': 2},
    paletteEntries: [d6, z9, b1, a2],
    draft: DraftProject(originalImageBytes: Uint8List(0)),
  );
}
