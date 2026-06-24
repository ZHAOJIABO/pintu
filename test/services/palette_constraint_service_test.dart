import 'package:flutter_test/flutter_test.dart';
import 'package:bobobeads/algorithms/matching.dart';
import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/color_limit.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/services/palette_constraint_service.dart';
import 'dart:typed_data';

void main() {
  final service = PaletteConstraintService();

  Palette paletteWith(int count) {
    return Palette(
      name: 'test',
      entries: [
        for (int i = 0; i < count; i++)
          PaletteEntry(
            name: 'Color $i',
            ref: 'C$i',
            symbol: '$i',
            color: BeadColor.fromInt(i, i, i, 255),
            prefix: 'C',
          ),
      ],
    );
  }

  test('unlimited keeps all enabled entries', () {
    final result = service.applyColorLimit(
      paletteWith(40),
      ColorLimit.unlimited,
    );

    expect(result.entries, hasLength(40));
  });

  test('finite limit truncates enabled entries', () {
    final result = service.applyColorLimit(paletteWith(40), ColorLimit.eight);

    expect(result.entries, hasLength(8));
    expect(result.entries.last.ref, 'C7');
  });

  test('finite limit keeps shorter palettes intact', () {
    final result = service.applyColorLimit(paletteWith(3), ColorLimit.eight);

    expect(result.entries, hasLength(3));
  });

  test(
    'image aware limit selects colors used by the image, not first entries',
    () {
      final palette = Palette(
        name: 'test',
        entries: [
          PaletteEntry(
            name: 'Black',
            ref: 'K',
            symbol: 'K',
            color: BeadColor.fromInt(0, 0, 0, 255),
            prefix: 'T',
          ),
          PaletteEntry(
            name: 'White',
            ref: 'W',
            symbol: 'W',
            color: BeadColor.fromInt(255, 255, 255, 255),
            prefix: 'T',
          ),
          PaletteEntry(
            name: 'Red',
            ref: 'R',
            symbol: 'R',
            color: BeadColor.fromInt(255, 0, 0, 255),
            prefix: 'T',
          ),
        ],
      );
      final redPixels = Uint8List.fromList([
        255,
        0,
        0,
        255,
        255,
        0,
        0,
        255,
        255,
        0,
        0,
        255,
        255,
        0,
        0,
        255,
      ]);

      final result = service.applyImageAwareColorLimit(
        palette: palette,
        limit: ColorLimit.eight,
        pixels: redPixels,
        matching: CIE2000Matching(),
      );

      expect(result.entries.map((entry) => entry.ref), contains('R'));
    },
  );
}
