import 'dart:collection';
import 'dart:typed_data';

import 'pattern_edit_service.dart';

class EditorHistoryService {
  final int maxDepth;
  final Queue<List<CellChange>> _undoStack = Queue<List<CellChange>>();
  final Queue<List<CellChange>> _redoStack = Queue<List<CellChange>>();

  EditorHistoryService({this.maxDepth = 50});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void record(List<CellChange> changes) {
    if (changes.isEmpty) return;
    _undoStack.addLast(changes);
    while (_undoStack.length > maxDepth) {
      _undoStack.removeFirst();
    }
    _redoStack.clear();
  }

  void undo(Uint8List pixels, int width) {
    if (!canUndo) return;
    final changes = _undoStack.removeLast();
    for (final change in changes) {
      final offset = (change.y * width + change.x) * 4;
      pixels[offset] = change.before.rInt;
      pixels[offset + 1] = change.before.gInt;
      pixels[offset + 2] = change.before.bInt;
      pixels[offset + 3] = change.before.aInt;
    }
    _redoStack.addLast(changes);
  }

  void redo(Uint8List pixels, int width) {
    if (!canRedo) return;
    final changes = _redoStack.removeLast();
    for (final change in changes) {
      final offset = (change.y * width + change.x) * 4;
      pixels[offset] = change.after.rInt;
      pixels[offset + 1] = change.after.gInt;
      pixels[offset + 2] = change.after.bInt;
      pixels[offset + 3] = change.after.aInt;
    }
    _undoStack.addLast(changes);
  }
}
