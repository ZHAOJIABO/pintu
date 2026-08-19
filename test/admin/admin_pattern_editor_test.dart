import 'dart:typed_data';

import 'package:bobobeads/admin/admin_pattern_editor.dart';
import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/widgets/bead_board_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('web backend uses the client editor and saves palette edits', (
    tester,
  ) async {
    GeneratedPattern? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  saved = await Navigator.of(context).push<GeneratedPattern>(
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminPatternEditorPage(pattern: _pattern()),
                    ),
                  );
                },
                child: const Text('打开编辑器'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();

    expect(find.text('画笔'), findsNWidgets(2));
    expect(find.text('色板'), findsOneWidget);
    expect(find.text('取色器'), findsOneWidget);
    expect(find.byKey(const ValueKey('brush-mode-guide-scrim')), findsNothing);

    await tester.tap(find.text('色板'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('editor-palette-usage-option-R')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('editor-color-replacement-all-option-B')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.usage, {'B': 4});
  });

  testWidgets('palette entry opens the color replacement panel directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPatternEditorPage(
          pattern: _pattern(),
          initialMode: AdminPatternEditingMode.palette,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('画笔'), findsOneWidget);
    expect(find.text('色板'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('editor-palette-usage-option-R')),
      findsOneWidget,
    );
    expect(find.text('取色器'), findsNothing);
  });

  testWidgets('brush size options are offered on the web backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminPatternEditorPage(pattern: _pattern())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('editor-brush-size-selector')),
      findsOneWidget,
    );
    expect(find.text('画笔大小'), findsOneWidget);
    expect(find.text('1x1'), findsOneWidget);
    expect(find.text('3x3'), findsOneWidget);
    expect(find.text('5x5'), findsOneWidget);
    expect(_chipBackground(tester, 1), Colors.black);
    expect(_chipBackground(tester, 2), isNot(Colors.black));
  });

  testWidgets('brush and eraser share the selected size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminPatternEditorPage(pattern: _pattern())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor-brush-size-option-2')));
    await tester.pump();
    expect(_chipBackground(tester, 2), Colors.black);

    // A 3x3 footprint centred on the top-left bead covers the whole 2x2 chart.
    await _tapFirstCell(tester);
    final painted = _patternCells(tester);
    expect(painted.toSet(), hasLength(1));
    expect(painted.first.endsWith(',255'), isTrue);

    await tester.tap(find.text('橡皮擦'));
    await tester.pump();
    expect(_chipBackground(tester, 2), Colors.black);

    await _tapFirstCell(tester);
    expect(_patternCells(tester), everyElement('0,0,0,0'));
  });
}

BeadBoardPainter _editorPainter(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<BeadBoardPainter>()
      .single;
}

Color _chipBackground(WidgetTester tester, int size) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byKey(ValueKey('editor-brush-size-option-$size')),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration as BoxDecoration).color!;
}

/// The 2x2 chart is centred on a 50x50 board, so its first bead lands on board
/// cell 24.
Future<void> _tapFirstCell(WidgetTester tester) async {
  final canvas = find.byKey(const ValueKey('pattern-editor-canvas'));
  final painter = _editorPainter(tester);
  final firstCellCenter = Offset(
    painter.labelBand + 24.5 * painter.cellSize,
    painter.labelBand + 24.5 * painter.cellSize,
  );
  await tester.tapAt(tester.getTopLeft(canvas) + firstCellCenter);
  await tester.pump();
}

List<String> _patternCells(WidgetTester tester) {
  final pixels = _editorPainter(tester).pixels;
  return [
    for (var offset = 0; offset < 16; offset += 4)
      pixels.sublist(offset, offset + 4).join(','),
  ];
}

GeneratedPattern _pattern() {
  final red = PaletteEntry(
    name: 'Red',
    ref: 'R',
    symbol: 'R',
    color: BeadColor.fromInt(255, 0, 0, 255),
    prefix: 'T',
  );
  final blue = PaletteEntry(
    name: 'Blue',
    ref: 'B',
    symbol: 'B',
    color: BeadColor.fromInt(0, 0, 255, 255),
    prefix: 'T',
  );
  return GeneratedPattern(
    pixels: Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      0,
      255,
      255,
      255,
      0,
      0,
      255,
      0,
      0,
      255,
      255,
    ]),
    width: 2,
    height: 2,
    usage: const {'R': 2, 'B': 2},
    paletteEntries: [red, blue],
    draft: DraftProject(originalImageBytes: Uint8List(0)),
  );
}
