import 'dart:typed_data';

import 'package:bobobeads/admin/admin_pattern_editor.dart';
import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bead-mode editor replaces a selected color before saving', (
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

    await tester.tap(find.text('R'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换为其他颜色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(find.text('1 种颜色'), findsOneWidget);
    await tester.tap(find.text('保存编辑'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.usage, {'B': 4});
  });
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
