import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/services/editor_history_service.dart';
import 'package:bobobeads/services/pattern_edit_service.dart';

void main() {
  test('brushSize is the footprint side length in beads', () {
    final editService = PatternEditService();
    final red = BeadColor.fromInt(255, 0, 0, 255);

    // Even sizes cannot be centred, so they extend right and down from (2, 2).
    const expectedCells = <int, List<(int, int)>>{
      1: [(2, 2)],
      2: [(2, 2), (3, 2), (2, 3), (3, 3)],
      3: [
        (1, 1),
        (2, 1),
        (3, 1),
        (1, 2),
        (2, 2),
        (3, 2),
        (1, 3),
        (2, 3),
        (3, 3),
      ],
    };

    for (final entry in expectedCells.entries) {
      final changes = editService.paint(
        pixels: Uint8List(5 * 5 * 4),
        width: 5,
        height: 5,
        x: 2,
        y: 2,
        brushSize: entry.key,
        color: red,
      );
      expect(
        changes.map((change) => (change.x, change.y)).toSet(),
        entry.value.toSet(),
        reason:
            'brushSize ${entry.key} should cover a '
            '${entry.key}x${entry.key} square',
      );
    }
  });

  test('brushSize clips the footprint to the chart bounds', () {
    final editService = PatternEditService();

    final changes = editService.paint(
      pixels: Uint8List(3 * 3 * 4),
      width: 3,
      height: 3,
      x: 0,
      y: 0,
      brushSize: 5,
      color: BeadColor.fromInt(255, 0, 0, 255),
    );

    expect(changes, hasLength(9));
  });

  test('paint changes a bead and history can undo and redo it', () {
    final pixels = Uint8List(2 * 2 * 4);
    final editService = PatternEditService();
    final history = EditorHistoryService();
    final red = BeadColor.fromInt(255, 0, 0, 255);

    final changes = editService.paint(
      pixels: pixels,
      width: 2,
      height: 2,
      x: 0,
      y: 0,
      brushSize: 1,
      color: red,
    );
    history.record(changes);

    expect(pixels[0], 255);
    expect(history.canUndo, isTrue);

    history.undo(pixels, 2);
    expect(pixels[0], 0);
    expect(history.canRedo, isTrue);

    history.redo(pixels, 2);
    expect(pixels[0], 255);
  });

  test('erase sets alpha to transparent', () {
    final pixels = Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);

    PatternEditService().erase(
      pixels: pixels,
      width: 2,
      height: 2,
      x: 0,
      y: 0,
      brushSize: 1,
    );

    expect(pixels[3], 0);
  });

  test('pick returns color at coordinate', () {
    final pixels = Uint8List.fromList([
      1,
      2,
      3,
      255,
      4,
      5,
      6,
      255,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);

    final color = PatternEditService().pick(
      pixels: pixels,
      width: 2,
      x: 1,
      y: 0,
    );

    expect(color.rInt, 4);
    expect(color.gInt, 5);
    expect(color.bInt, 6);
    expect(color.aInt, 255);
  });

  test('replaceColor returns changes for every matching bead', () {
    final red = BeadColor.fromInt(255, 0, 0, 255);
    final blue = BeadColor.fromInt(0, 0, 255, 255);
    final pixels = Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      255,
      0,
      255,
      255,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
    ]);

    final changes = PatternEditService().replaceColor(
      pixels: pixels,
      width: 2,
      height: 2,
      from: red,
      to: blue,
    );

    expect(changes, hasLength(2));
    expect(pixels, [
      0,
      0,
      255,
      255,
      0,
      255,
      0,
      255,
      0,
      0,
      255,
      255,
      0,
      0,
      0,
      0,
    ]);
  });

  test('compact replacement stores changed indexes for atomic history', () {
    final red = BeadColor.fromInt(255, 0, 0, 255);
    final blue = BeadColor.fromInt(0, 0, 255, 255);
    final pixels = Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      255,
      0,
      255,
      255,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
    ]);
    final history = EditorHistoryService();

    final replacement = PatternEditService().replaceColorCompact(
      pixels: pixels,
      from: red,
      to: blue,
    );

    expect(replacement, isNotNull);
    expect(replacement!.cellIndexes, [0, 2]);
    history.recordColorReplacement(replacement);
    history.undo(pixels, 2);
    expect(pixels, [
      255,
      0,
      0,
      255,
      0,
      255,
      0,
      255,
      255,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
    ]);
    history.redo(pixels, 2);
    expect(pixels, [
      0,
      0,
      255,
      255,
      0,
      255,
      0,
      255,
      0,
      0,
      255,
      255,
      0,
      0,
      0,
      0,
    ]);
  });
}
