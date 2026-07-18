import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/screens/bead_mode_screen.dart';
import 'package:bobobeads/widgets/bead_board_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cropped pattern placement stays on whole board cells', () {
    expect(
      BeadBoardPainter.centeredPatternCellOffset(
        boardWidth: 50,
        boardHeight: 50,
        activeLeft: 2,
        activeTop: 7,
        activeRight: 46,
        activeBottom: 49,
      ),
      const Offset(0, -4),
    );
  });

  test(
    'rulers follow the board until each matching viewport edge is reached',
    () {
      const childOffset = Offset(30, 200);

      final floating = BoardRulerPlacement.resolve(
        transform: Matrix4.identity(),
        boardWidth: 50,
        boardHeight: 50,
        cellSize: 5,
        labelBand: 10,
        childOffset: childOffset,
      );

      expect(floating.horizontalRuler, const Rect.fromLTWH(40, 200, 250, 10));
      expect(floating.verticalRuler, const Rect.fromLTWH(30, 210, 10, 250));

      final pinned = BoardRulerPlacement.resolve(
        transform: Matrix4.identity()..setTranslationRaw(-30, -200, 0),
        boardWidth: 50,
        boardHeight: 50,
        cellSize: 5,
        labelBand: 10,
        childOffset: childOffset,
      );

      expect(pinned.horizontalRuler.top, 0);
      expect(pinned.horizontalRuler.left, 0);
      expect(pinned.verticalRuler.left, 0);
      expect(pinned.verticalRuler.top, 0);
    },
  );

  test('rulers pin horizontally and vertically independently', () {
    const childOffset = Offset(30, 200);

    final leftPinned = BoardRulerPlacement.resolve(
      transform: Matrix4.identity()..setTranslationRaw(-30, 0, 0),
      boardWidth: 50,
      boardHeight: 50,
      cellSize: 5,
      labelBand: 10,
      childOffset: childOffset,
    );
    expect(leftPinned.horizontalRuler.left, 0);
    expect(leftPinned.horizontalRuler.top, 200);
    expect(leftPinned.verticalRuler.left, 0);
    expect(leftPinned.verticalRuler.top, 210);

    final topPinned = BoardRulerPlacement.resolve(
      transform: Matrix4.identity()..setTranslationRaw(0, -200, 0),
      boardWidth: 50,
      boardHeight: 50,
      cellSize: 5,
      labelBand: 10,
      childOffset: childOffset,
    );
    expect(topPinned.horizontalRuler.left, 40);
    expect(topPinned.horizontalRuler.top, 0);
    expect(topPinned.verticalRuler.left, 30);
    expect(topPinned.verticalRuler.top, 0);
  });

  for (final viewport in const [Size(375, 667), Size(430, 932)]) {
    testWidgets('bead mode fits Figma layout on $viewport', (tester) async {
      _setViewport(tester, viewport);

      await tester.pumpWidget(
        MaterialApp(home: BeadModeScreen(pattern: _pattern())),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('bead-mode-edit-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bead-mode-tool-collapse')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bead-mode-tool-mirror')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bead-mode-tool-colors')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bead-mode-tool-rulers')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('bead-mode-tool-lock')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bead-mode-color-strip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bead-mode-pinned-rulers')),
        findsOneWidget,
      );
      final colorStripFinder = find.byKey(
        const ValueKey('bead-mode-color-strip'),
      );
      expect(tester.getSize(colorStripFinder).height, 106);
      expect(tester.getSize(colorStripFinder).width, viewport.width);
      expect(tester.getTopLeft(colorStripFinder).dx, 0);
      expect(tester.getBottomLeft(colorStripFinder).dy, viewport.height);
      final toolbarFinder = find.byKey(const ValueKey('bead-mode-toolbar'));
      expect(tester.getSize(toolbarFinder), const Size(52, 286));
      expect(tester.getTopRight(toolbarFinder).dx, viewport.width);
      expect(
        tester.getBottomLeft(toolbarFinder).dy,
        tester.getTopLeft(colorStripFinder).dy - 56,
      );
      final colorStrip = tester.widget<BeadModeUsageStrip>(
        find.byType(BeadModeUsageStrip),
      );
      expect(colorStrip.compact, isTrue);
      expect(find.text('全部'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('bead-color-swatch-H7'))),
        const Size(40, 40),
      );
      final colorRef = tester.widget<Text>(find.text('H7'));
      expect(colorRef.style?.fontSize, 14);
      expect(colorRef.style?.fontWeight, FontWeight.w600);
      expect(colorRef.style?.height, 16 / 14);
      final count = tester.widget<Text>(find.text('2').first);
      expect(count.style?.fontSize, 12);
      expect(count.style?.fontWeight, FontWeight.w500);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('toolbar tools update only the board presentation', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(home: BeadModeScreen(pattern: _pattern())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bead-mode-tool-mirror')));
    await tester.pump();
    expect(_boardPainter(tester).mirrorHorizontally, isTrue);
    final mirrorButton = find.byKey(const ValueKey('bead-mode-tool-mirror'));
    final mirrorSurface = tester.widget<Ink>(
      find.descendant(of: mirrorButton, matching: find.byType(Ink)),
    );
    expect(
      tester.getSize(
        find.descendant(of: mirrorButton, matching: find.byType(Ink)),
      ),
      const Size(36, 36),
    );
    expect((mirrorSurface.decoration! as BoxDecoration).color, Colors.black);
    final mirrorIcon = tester.widget<SvgPicture>(
      find.descendant(of: mirrorButton, matching: find.byType(SvgPicture)),
    );
    expect(mirrorIcon.width, 18);
    expect(mirrorIcon.height, 18);
    expect(
      find.byKey(const ValueKey('bead-mode-mirror-icon-selected')),
      findsOneWidget,
    );
    expect(
      mirrorIcon.colorFilter,
      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );

    await tester.tap(find.byKey(const ValueKey('bead-mode-tool-colors')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bead-mode-color-strip')), findsNothing);
    final colorButton = find.byKey(const ValueKey('bead-mode-tool-colors'));
    final colorSurface = tester.widget<Ink>(
      find.descendant(of: colorButton, matching: find.byType(Ink)),
    );
    expect(
      tester.getSize(
        find.descendant(of: colorButton, matching: find.byType(Ink)),
      ),
      const Size(36, 36),
    );
    expect(
      (colorSurface.decoration! as BoxDecoration).color,
      const Color(0xFFDEE2ED),
    );
    final colorIconFinder = find.descendant(
      of: colorButton,
      matching: find.byType(SvgPicture),
    );
    final colorIcon = tester.widget<SvgPicture>(colorIconFinder);
    expect(tester.getSize(colorIconFinder), const Size(21.6, 21.6));
    expect(
      find.byKey(const ValueKey('bead-mode-palette-icon-unselected')),
      findsOneWidget,
    );
    for (var index = 1; index <= 4; index++) {
      expect(
        find.byKey(ValueKey('bead-mode-palette-dot-$index')),
        findsOneWidget,
      );
    }
    expect(
      colorIcon.colorFilter,
      const ColorFilter.mode(Colors.black, BlendMode.srcIn),
    );

    await tester.tap(find.byKey(const ValueKey('bead-mode-tool-rulers')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bead-mode-pinned-rulers')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bead-mode-tool-lock')));
    await tester.pump();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.panEnabled, isFalse);
    expect(viewer.scaleEnabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('bead-mode-tool-collapse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bead-mode-tool-mirror')), findsNothing);
  });

  testWidgets('color strip extends through the bottom safe area', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(bottom: 34)),
            child: BeadModeScreen(pattern: _pattern()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('bead-mode-color-strip')))
          .dy,
      844,
    );
  });

  testWidgets('top and left rulers stay pinned while the board zooms', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(home: BeadModeScreen(pattern: _pattern())),
    );
    await tester.pumpAndSettle();

    final rulers = find.byKey(const ValueKey('bead-mode-pinned-rulers'));
    final initialSize = tester.getSize(rulers);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );

    viewer.transformationController!.value = Matrix4.diagonal3Values(3, 3, 1)
      ..setTranslationRaw(-180, -240, 0);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('bead-mode-pinned-rulers')),
      findsOneWidget,
    );
    expect(tester.getSize(rulers), initialSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected palette color uses a black outline', (tester) async {
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(home: BeadModeScreen(pattern: _pattern())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bead-color-swatch-H7')));
    await tester.pump();

    final tile = tester.widget<Container>(
      find.byKey(const ValueKey('bead-color-tile-H7')),
    );
    final border = (tile.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, Colors.black);
    expect(border.top.width, 2);
  });

  testWidgets('top-right action opens the pattern editor', (tester) async {
    _setViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(home: BeadModeScreen(pattern: _pattern())),
    );

    await tester.tap(find.byKey(const ValueKey('bead-mode-edit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pattern-editor-screen')), findsOneWidget);
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

BeadBoardPainter _boardPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<BeadBoardPainter>()
      .single;
}

GeneratedPattern _pattern() {
  final black = PaletteEntry(
    name: 'Black',
    ref: 'H7',
    symbol: 'H',
    color: BeadColor.fromInt(0, 0, 0, 255),
    prefix: 'T',
  );
  final red = PaletteEntry(
    name: 'Red',
    ref: 'F5',
    symbol: 'F',
    color: BeadColor.fromInt(236, 54, 82, 255),
    prefix: 'T',
  );
  final pixels = Uint8List.fromList([
    0,
    0,
    0,
    255,
    236,
    54,
    82,
    255,
    236,
    54,
    82,
    255,
    0,
    0,
    0,
    255,
  ]);

  return GeneratedPattern(
    draft: DraftProject(originalImageBytes: Uint8List(0)),
    pixels: pixels,
    width: 2,
    height: 2,
    usage: const {'H7': 2, 'F5': 2},
    paletteEntries: [black, red],
  );
}
