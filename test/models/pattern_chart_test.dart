import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/models/pattern_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final red = PaletteEntry(
    name: 'Red',
    ref: 'R1',
    symbol: 'R',
    color: BeadColor.fromInt(255, 0, 0, 255),
    prefix: 'T',
  );
  final blue = PaletteEntry(
    name: 'Blue',
    ref: 'B2',
    symbol: 'B',
    color: BeadColor.fromInt(0, 0, 255, 255),
    prefix: 'T',
  );

  test('maps exact palette pixels to chart refs', () {
    final chart = PatternChartData.fromPixels(
      pixels: Uint8List.fromList([255, 0, 0, 255, 0, 0, 255, 255]),
      width: 2,
      height: 1,
      paletteEntries: [red, blue],
    );

    expect(chart.cellAt(0, 0)?.ref, 'R1');
    expect(chart.cellAt(1, 0)?.ref, 'B2');
  });

  test('keeps transparent pixels empty', () {
    final chart = PatternChartData.fromPixels(
      pixels: Uint8List.fromList([255, 0, 0, 0]),
      width: 1,
      height: 1,
      paletteEntries: [red],
    );

    expect(chart.cellAt(0, 0), isNull);
  });

  test('marks opaque pixels outside the palette as unmatched', () {
    final chart = PatternChartData.fromPixels(
      pixels: Uint8List.fromList([12, 34, 56, 255]),
      width: 1,
      height: 1,
      paletteEntries: [red],
    );

    final cell = chart.cellAt(0, 0);
    expect(cell?.ref, PatternChartData.unmatchedRef);
    expect(cell?.matchedPalette, isFalse);
    expect(cell?.color, BeadColor.fromInt(12, 34, 56, 255));
  });

  test('rejects pixel buffers that do not match chart dimensions', () {
    expect(
      () => PatternChartData.fromPixels(
        pixels: Uint8List(3),
        width: 1,
        height: 1,
        paletteEntries: [red],
      ),
      throwsArgumentError,
    );
  });
}
