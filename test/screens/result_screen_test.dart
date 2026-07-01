import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/screens/result_screen.dart';
import 'package:bobobeads/widgets/bead_board_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final viewport in const [Size(375, 667), Size(430, 932)]) {
    testWidgets('ResultScreen renders chart layout on $viewport', (
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

      expect(find.text('拼豆图纸'), findsOneWidget);
      expect(find.text('用料清单'), findsOneWidget);
      expect(find.text('导出'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ResultScreen switches to bead board mode', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    await tester.tap(find.text('拼豆模式'));
    await tester.pumpAndSettle();

    expect(find.byType(BeadBoardPreview), findsOneWidget);
    final boardPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BeadBoardPainter>()
        .single;
    expect(boardPainter.boardWidth, 50);
    expect(boardPainter.boardHeight, 50);
    expect(boardPainter.showColorRefs, isFalse);
    expect(boardPainter.selectedRef, isNull);
    expect(find.text('全部'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ResultScreen filters bead board by selected color ref', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    await tester.tap(find.text('拼豆模式'));
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

    await tester.tap(find.text('全部'));
    await tester.pump();

    boardPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BeadBoardPainter>()
        .single;
    expect(boardPainter.selectedRef, isNull);
  });

  testWidgets('ResultScreen shows bead color refs after zooming in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(pattern: _pattern())),
    );

    await tester.tap(find.text('拼豆模式'));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(BeadBoardPreview));
    final firstFinger = await tester.createGesture(pointer: 1);
    final secondFinger = await tester.createGesture(pointer: 2);
    await firstFinger.down(center - const Offset(10, 0));
    await secondFinger.down(center + const Offset(10, 0));
    await tester.pump();
    await firstFinger.moveTo(center - const Offset(35, 0));
    await secondFinger.moveTo(center + const Offset(35, 0));
    await tester.pump();
    await firstFinger.up();
    await secondFinger.up();
    await tester.pump();

    final boardPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BeadBoardPainter>()
        .single;
    expect(boardPainter.showColorRefs, isTrue);
    expect(BeadBoardPreview.colorRefMinEffectiveCellSize, 20);
    expect(boardPainter.colorRefsByRgb, containsPair(0xFF2850, 'R1'));
    expect(boardPainter.colorRefsByRgb, containsPair(0x000000, 'H7'));
    expect(tester.takeException(), isNull);
  });
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
