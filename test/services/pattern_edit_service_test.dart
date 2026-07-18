import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/services/editor_history_service.dart';
import 'package:bobobeads/services/pattern_edit_service.dart';

void main() {
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
