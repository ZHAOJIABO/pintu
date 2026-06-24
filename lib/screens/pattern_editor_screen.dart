import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/color.dart';
import '../models/editable_pattern.dart';
import '../models/generated_pattern.dart';
import '../services/editor_history_service.dart';
import '../services/pattern_edit_service.dart';
import '../widgets/pattern_preview.dart';

class PatternEditorScreen extends StatefulWidget {
  final GeneratedPattern pattern;

  const PatternEditorScreen({super.key, required this.pattern});

  @override
  State<PatternEditorScreen> createState() => _PatternEditorScreenState();
}

class _PatternEditorScreenState extends State<PatternEditorScreen> {
  final PatternEditService _editService = PatternEditService();
  final EditorHistoryService _historyService = EditorHistoryService();
  late final Uint8List _pixels = Uint8List.fromList(widget.pattern.pixels);
  EditorTool _tool = EditorTool.brush;
  BeadColor _selectedColor = BeadColor.fromInt(0, 0, 0, 255);
  int _brushSize = 1;

  void _applyAtCenter() {
    final x = widget.pattern.width ~/ 2;
    final y = widget.pattern.height ~/ 2;
    if (_tool == EditorTool.picker) {
      setState(() {
        _selectedColor = _editService.pick(
          pixels: _pixels,
          width: widget.pattern.width,
          x: x,
          y: y,
        );
      });
      return;
    }

    final changes = _tool == EditorTool.eraser
        ? _editService.erase(
            pixels: _pixels,
            width: widget.pattern.width,
            height: widget.pattern.height,
            x: x,
            y: y,
            brushSize: _brushSize,
          )
        : _editService.paint(
            pixels: _pixels,
            width: widget.pattern.width,
            height: widget.pattern.height,
            x: x,
            y: y,
            brushSize: _brushSize,
            color: _selectedColor,
          );
    _historyService.record(changes);
    setState(() {});
  }

  void _undo() {
    _historyService.undo(_pixels, widget.pattern.width);
    setState(() {});
  }

  void _redo() {
    _historyService.redo(_pixels, widget.pattern.width);
    setState(() {});
  }

  void _confirm() {
    final edited = _editService.applyEditedPixels(
      pattern: widget.pattern,
      pixels: _pixels,
    );
    Navigator.pop(context, edited);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: const Text('图纸编辑'),
        actions: [
          TextButton(onPressed: _undo, child: const Text('撤销')),
          TextButton(onPressed: _redo, child: const Text('恢复')),
          FilledButton(onPressed: _confirm, child: const Text('OK啦')),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: PatternPreview(
                  pixels: _pixels,
                  width: widget.pattern.width,
                  height: widget.pattern.height,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<EditorTool>(
                    segments: const [
                      ButtonSegment(
                        value: EditorTool.picker,
                        label: Text('取色器'),
                      ),
                      ButtonSegment(value: EditorTool.brush, label: Text('画笔')),
                      ButtonSegment(
                        value: EditorTool.eraser,
                        label: Text('橡皮'),
                      ),
                    ],
                    selected: {_tool},
                    onSelectionChanged: (value) =>
                        setState(() => _tool = value.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('笔刷'),
                      Expanded(
                        child: Slider(
                          value: _brushSize.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '$_brushSize',
                          onChanged: (value) =>
                              setState(() => _brushSize = value.round()),
                        ),
                      ),
                      FilledButton(
                        onPressed: _applyAtCenter,
                        child: const Text('应用到中心点'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
