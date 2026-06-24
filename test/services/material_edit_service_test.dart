import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/services/material_edit_service.dart';

void main() {
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

  GeneratedPattern pattern() {
    final pixels = Uint8List.fromList([
      255,
      0,
      0,
      255,
      255,
      0,
      0,
      255,
      0,
      0,
      255,
      255,
      0,
      0,
      255,
      255,
    ]);
    return GeneratedPattern(
      pixels: pixels,
      width: 2,
      height: 2,
      usage: const {'R': 2, 'B': 2},
      paletteEntries: [red, blue],
      draft: DraftProject(originalImageBytes: Uint8List(0)),
    );
  }

  test('replaceColor changes matching pixels and recomputes usage', () {
    final result = MaterialEditService().replaceColor(
      pattern: pattern(),
      from: red,
      to: blue,
    );

    expect(result.usage['R'], isNull);
    expect(result.usage['B'], 4);
  });

  test('deleteColor clears matching pixels and recomputes usage', () {
    final result = MaterialEditService().deleteColor(
      pattern: pattern(),
      entry: red,
    );

    expect(result.usage['R'], isNull);
    expect(result.usage['B'], 2);
    expect(result.totalBeads, 2);
  });

  test('requiresDeleteConfirmation only for colors over five percent', () {
    final service = MaterialEditService();

    expect(service.requiresDeleteConfirmation(pattern(), 'R'), isTrue);
    expect(service.requiresDeleteConfirmation(pattern(), 'missing'), isFalse);
  });
}
