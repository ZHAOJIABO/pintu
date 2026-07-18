import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/screens/pattern_editor_screen.dart';
import 'package:bobobeads/widgets/bead_board_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final viewport in const [Size(375, 667), Size(430, 932)]) {
    testWidgets('pattern editor fits the Figma layout on $viewport', (
      tester,
    ) async {
      _setViewport(tester, viewport);

      await tester.pumpWidget(
        MaterialApp(home: PatternEditorScreen(pattern: _pattern())),
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

  testWidgets('canvas painting can be undone', (tester) async {
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(home: PatternEditorScreen(pattern: _pattern())),
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
      MaterialApp(home: PatternEditorScreen(pattern: _pattern())),
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
      MaterialApp(home: PatternEditorScreen(pattern: _pattern())),
    );

    final viewer = find.byType(InteractiveViewer);
    expect(tester.widget<InteractiveViewer>(viewer).panEnabled, isFalse);

    await tester.tap(find.text('画笔').last);
    await tester.pump();

    expect(tester.widget<InteractiveViewer>(viewer).panEnabled, isTrue);
    expect(tester.widget<InteractiveViewer>(viewer).scaleEnabled, isTrue);
  });

  testWidgets(
    'current colour defaults to the most-used and picker sorts used codes',
    (tester) async {
      _setViewport(tester, const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(home: PatternEditorScreen(pattern: _colorPickerPattern())),
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
