import 'dart:collection';
import 'dart:typed_data';

import '../models/color.dart';
import 'pattern_edit_service.dart';

class EditorHistoryService {
  final int maxDepth;
  final Queue<_EditorHistoryEntry> _undoStack = Queue<_EditorHistoryEntry>();
  final Queue<_EditorHistoryEntry> _redoStack = Queue<_EditorHistoryEntry>();

  EditorHistoryService({this.maxDepth = 50});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void record(List<CellChange> changes) {
    if (changes.isEmpty) return;
    _record(_CellChangesHistoryEntry(changes));
  }

  void recordColorReplacement(ColorReplacement replacement) {
    if (replacement.cellIndexes.isEmpty) return;
    _record(_ColorReplacementHistoryEntry(replacement));
  }

  void _record(_EditorHistoryEntry entry) {
    _undoStack.addLast(entry);
    while (_undoStack.length > maxDepth) {
      _undoStack.removeFirst();
    }
    _redoStack.clear();
  }

  void undo(Uint8List pixels, int width) {
    if (!canUndo) return;
    final entry = _undoStack.removeLast();
    entry.undo(pixels, width);
    _redoStack.addLast(entry);
  }

  void redo(Uint8List pixels, int width) {
    if (!canRedo) return;
    final entry = _redoStack.removeLast();
    entry.redo(pixels, width);
    _undoStack.addLast(entry);
  }
}

abstract class _EditorHistoryEntry {
  const _EditorHistoryEntry();

  void undo(Uint8List pixels, int width);
  void redo(Uint8List pixels, int width);
}

class _CellChangesHistoryEntry extends _EditorHistoryEntry {
  final List<CellChange> changes;

  const _CellChangesHistoryEntry(this.changes);

  @override
  void undo(Uint8List pixels, int width) {
    for (final change in changes) {
      _writeColor(pixels, (change.y * width + change.x) * 4, change.before);
    }
  }

  @override
  void redo(Uint8List pixels, int width) {
    for (final change in changes) {
      _writeColor(pixels, (change.y * width + change.x) * 4, change.after);
    }
  }
}

class _ColorReplacementHistoryEntry extends _EditorHistoryEntry {
  final ColorReplacement replacement;

  const _ColorReplacementHistoryEntry(this.replacement);

  @override
  void undo(Uint8List pixels, int width) {
    for (final cellIndex in replacement.cellIndexes) {
      _writeColor(pixels, cellIndex * 4, replacement.before);
    }
  }

  @override
  void redo(Uint8List pixels, int width) {
    for (final cellIndex in replacement.cellIndexes) {
      _writeColor(pixels, cellIndex * 4, replacement.after);
    }
  }
}

void _writeColor(Uint8List pixels, int offset, BeadColor color) {
  pixels[offset] = color.rInt;
  pixels[offset + 1] = color.gInt;
  pixels[offset + 2] = color.bInt;
  pixels[offset + 3] = color.aInt;
}
