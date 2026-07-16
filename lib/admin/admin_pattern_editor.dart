import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/color.dart';
import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../services/editor_history_service.dart';
import '../services/pattern_edit_service.dart';
import '../widgets/bead_board_preview.dart';

/// A publishing-time editor that deliberately shares the client bead-mode
/// board, color filtering and material summary with the operator workflow.
class AdminPatternEditorPage extends StatefulWidget {
  final GeneratedPattern pattern;

  const AdminPatternEditorPage({super.key, required this.pattern});

  @override
  State<AdminPatternEditorPage> createState() => _AdminPatternEditorPageState();
}

class _AdminPatternEditorPageState extends State<AdminPatternEditorPage> {
  final _editService = PatternEditService();
  final _history = EditorHistoryService();
  late final Uint8List _pixels = Uint8List.fromList(widget.pattern.pixels);
  late GeneratedPattern _pattern = widget.pattern;
  String? _selectedRef;

  PaletteEntry? get _selectedEntry {
    final ref = _selectedRef;
    if (ref == null) return null;
    for (final entry in _pattern.paletteEntries) {
      if (entry.ref == ref) return entry;
    }
    return null;
  }

  void _refreshPattern() {
    _pattern = _editService.applyEditedPixels(
      pattern: widget.pattern,
      pixels: _pixels,
    );
  }

  void _undo() {
    _history.undo(_pixels, _pattern.width);
    setState(_refreshPattern);
  }

  void _redo() {
    _history.redo(_pixels, _pattern.width);
    setState(_refreshPattern);
  }

  Future<void> _replaceSelected() async {
    final source = _selectedEntry;
    if (source == null) return;
    final target = await showModalBottomSheet<PaletteEntry>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ReplacementPalette(
        entries: _pattern.paletteEntries,
        selected: source,
      ),
    );
    if (!mounted || target == null || target.ref == source.ref) return;

    final changes = <CellChange>[];
    for (var y = 0; y < _pattern.height; y++) {
      for (var x = 0; x < _pattern.width; x++) {
        if (!_hasColorAt(x, y, source.color)) continue;
        changes.addAll(
          _editService.paint(
            pixels: _pixels,
            width: _pattern.width,
            height: _pattern.height,
            x: x,
            y: y,
            brushSize: 1,
            color: target.color,
          ),
        );
      }
    }
    _history.record(changes);
    setState(() {
      _refreshPattern();
      _selectedRef = target.ref;
    });
  }

  Future<void> _removeSelected() async {
    final source = _selectedEntry;
    if (source == null) return;
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除颜色'),
        content: Text('确定要从图纸中移除 ${source.ref} 吗？对应的拼豆格将变为空格。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC6284A),
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (!mounted || shouldRemove != true) return;

    final changes = <CellChange>[];
    for (var y = 0; y < _pattern.height; y++) {
      for (var x = 0; x < _pattern.width; x++) {
        if (!_hasColorAt(x, y, source.color)) continue;
        changes.addAll(
          _editService.erase(
            pixels: _pixels,
            width: _pattern.width,
            height: _pattern.height,
            x: x,
            y: y,
            brushSize: 1,
          ),
        );
      }
    }
    _history.record(changes);
    setState(() {
      _refreshPattern();
      _selectedRef = null;
    });
  }

  bool _hasColorAt(int x, int y, BeadColor color) {
    final offset = (y * _pattern.width + x) * 4;
    return _pixels[offset] == color.rInt &&
        _pixels[offset + 1] == color.gInt &&
        _pixels[offset + 2] == color.bInt &&
        _pixels[offset + 3] == color.aInt;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedEntry;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBFC),
        surfaceTintColor: Colors.transparent,
        title: const Text('拼豆模式编辑'),
        actions: [
          IconButton(
            tooltip: '撤销',
            onPressed: _history.canUndo ? _undo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: '恢复',
            onPressed: _history.canRedo ? _redo : null,
            icon: const Icon(Icons.redo_rounded),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: () => Navigator.pop(context, _pattern),
            child: const Text('保存编辑'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final board = _EditorBoard(
            pattern: _pattern,
            selectedRef: _selectedRef,
            onSelected: (ref) => setState(() => _selectedRef = ref),
          );
          final controls = _EditorControls(
            selected: selected,
            totalBeads: _pattern.totalBeads,
            colorCount: _pattern.usage.length,
            onReplace: selected == null ? null : _replaceSelected,
            onRemove: selected == null ? null : _removeSelected,
          );
          return compact
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    SizedBox(height: 460, child: board),
                    const SizedBox(height: 16),
                    controls,
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(child: board),
                      const SizedBox(width: 20),
                      SizedBox(width: 310, child: controls),
                    ],
                  ),
                );
        },
      ),
    );
  }
}

class _EditorBoard extends StatelessWidget {
  final GeneratedPattern pattern;
  final String? selectedRef;
  final ValueChanged<String?> onSelected;

  const _EditorBoard({
    required this.pattern,
    required this.selectedRef,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        border: Border.all(color: const Color(0xFFECE3EA)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 18, 22, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '图纸板',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: BeadBoardPreview(
                pixels: pattern.pixels,
                width: pattern.width,
                height: pattern.height,
                paletteEntries: pattern.paletteEntries,
                selectedRef: selectedRef,
              ),
            ),
          ),
          BeadModeUsageStrip(
            usage: pattern.usage,
            entries: pattern.paletteEntries,
            selectedRef: selectedRef,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _EditorControls extends StatelessWidget {
  final PaletteEntry? selected;
  final int totalBeads;
  final int colorCount;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;

  const _EditorControls({
    required this.selected,
    required this.totalBeads,
    required this.colorCount,
    required this.onReplace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected == null
        ? null
        : Color.fromARGB(
            255,
            selected!.color.rInt,
            selected!.color.gInt,
            selected!.color.bInt,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        border: Border.all(color: const Color(0xFFECE3EA)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '编辑颜色',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('在下方材料条点选颜色，图纸会高亮对应的所有拼豆。'),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF7EAF0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: selected == null
                    ? const Text('尚未选择颜色')
                    : Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${selected!.ref}\n${selected!.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onReplace,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('替换为其他颜色'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('移除所选颜色'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC6284A),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            Text(
              '$totalBeads 颗拼豆',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '$colorCount 种颜色',
              style: const TextStyle(color: Color(0xFF6A6470)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplacementPalette extends StatelessWidget {
  final List<PaletteEntry> entries;
  final PaletteEntry selected;

  const _ReplacementPalette({required this.entries, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '替换为',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('选择一项色卡颜色，整张图纸中的所选颜色会被替换。'),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final color = Color.fromARGB(
                    255,
                    entry.color.rInt,
                    entry.color.gInt,
                    entry.color.bInt,
                  );
                  return ListTile(
                    enabled: entry.ref != selected.ref,
                    leading: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                    title: Text(entry.ref),
                    subtitle: Text(entry.name),
                    onTap: () => Navigator.pop(context, entry),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
