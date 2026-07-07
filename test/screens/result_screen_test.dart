import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/rendering/pattern_chart_painter.dart';
import 'package:bobobeads/screens/result_screen.dart';
import 'package:bobobeads/widgets/bead_board_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(find.text('保存相册'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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

    expect(find.text('拼豆模式'), findsOneWidget);
    expect(find.byType(BeadBoardPreview), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);

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

    await tester.tap(find.text('全部'));
    await tester.pump();

    boardPainter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<BeadBoardPainter>()
        .single;
    expect(boardPainter.selectedRef, isNull);
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
