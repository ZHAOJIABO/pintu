import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/screens/result_screen.dart';
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
