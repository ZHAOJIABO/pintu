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

  test('preserves a rare foreground white within a finite color limit', () {
    PaletteEntry entry(String ref, int red, int green, int blue) =>
        PaletteEntry(
          name: ref,
          ref: ref,
          symbol: ref,
          color: BeadColor.fromInt(red, green, blue, 255),
          prefix: 'T',
        );
    final white = entry('W', 255, 255, 255);
    final colors = [
      entry('A', 0, 0, 0),
      entry('B', 255, 0, 0),
      entry('C', 0, 255, 0),
      entry('D', 0, 0, 255),
      entry('E', 255, 255, 0),
      entry('F', 255, 0, 255),
      entry('G', 0, 255, 255),
      entry('H', 128, 0, 0),
    ];
    final pixels = <int>[];
    for (var index = 0; index < colors.length; index++) {
      for (var count = 0; count < colors.length - index; count++) {
        final color = colors[index].color;
        pixels.addAll([color.rInt, color.gInt, color.bInt, 255]);
      }
    }
    pixels.addAll([255, 255, 255, 255]);
    pixels.addAll([128, 0, 0, 255]);

    final withoutPreservedWhite = service.applyImageAwareColorLimit(
      palette: Palette(name: 'test', entries: [white, ...colors]),
      limit: ColorLimit.eight,
      pixels: Uint8List.fromList(pixels),
      matching: EuclideanMatching(),
    );

    final result = service.applyImageAwareColorLimit(
      palette: Palette(name: 'test', entries: [white, ...colors]),
      limit: ColorLimit.eight,
      pixels: Uint8List.fromList(pixels),
      matching: EuclideanMatching(),
      preserveWhite: true,
    );

    expect(result.entries, hasLength(8));
    expect(
      withoutPreservedWhite.entries.map((entry) => entry.ref),
      isNot(contains('W')),
    );
    expect(result.entries.map((entry) => entry.ref), contains('W'));
  });

  test('does not reserve a transparent white background pixel', () {
    final colors = [
      for (var value = 0; value < 8; value++)
        PaletteEntry(
          name: 'C$value',
          ref: 'C$value',
          symbol: '$value',
          color: BeadColor.fromInt(value * 30, 0, 0, 255),
          prefix: 'T',
        ),
    ];
    final white = PaletteEntry(
      name: 'White',
      ref: 'W',
      symbol: 'W',
      color: BeadColor.fromInt(255, 255, 255, 255),
      prefix: 'T',
    );
    final pixels = <int>[255, 255, 255, 0];
    for (final entry in colors) {
      final color = entry.color;
      pixels.addAll([color.rInt, color.gInt, color.bInt, 255]);
    }

    final result = service.applyImageAwareColorLimit(
      palette: Palette(name: 'test', entries: [white, ...colors]),
      limit: ColorLimit.eight,
      pixels: Uint8List.fromList(pixels),
      matching: EuclideanMatching(),
      preserveWhite: true,
    );

    expect(result.entries.map((entry) => entry.ref), isNot(contains('W')));
  });
}
