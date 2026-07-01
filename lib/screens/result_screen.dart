import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../services/material_edit_service.dart';
import '../services/pattern_export_service.dart';
import '../services/project_storage_service.dart';
import '../widgets/bead_board_preview.dart';
import '../widgets/material_usage_list.dart';
import '../widgets/pattern_preview.dart';
import 'pattern_editor_screen.dart';

enum _ResultDisplayMode { chart, beads }

class ResultScreen extends StatefulWidget {
  final GeneratedPattern pattern;

  const ResultScreen({super.key, required this.pattern});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final MaterialEditService _materialEditService = MaterialEditService();
  final PatternExportService _exportService = const PatternExportService();
  final ProjectStorageService _storageService = ProjectStorageService();
  late GeneratedPattern _pattern = widget.pattern;
  _ResultDisplayMode _displayMode = _ResultDisplayMode.chart;
  String? _selectedBeadRef;
  bool _saving = false;
  bool _exporting = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _storageService.saveGeneratedPattern(_pattern);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEditor() async {
    final edited = await Navigator.push<GeneratedPattern>(
      context,
      MaterialPageRoute(builder: (_) => PatternEditorScreen(pattern: _pattern)),
    );
    if (edited != null) {
      setState(() => _pattern = edited);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await _exportService.exportChartPng(_pattern);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '拼豆图纸 ${_pattern.width}x${_pattern.height}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：$error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _deleteColor(PaletteEntry entry) async {
    final requiresConfirmation = _materialEditService
        .requiresDeleteConfirmation(_pattern, entry.ref);
    if (requiresConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除颜色？'),
          content: Text('颜色 ${entry.ref} 使用较多，删除后会重新计算用料。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      if (_selectedBeadRef == entry.ref) {
        _selectedBeadRef = null;
      }
      _pattern = _materialEditService.deleteColor(
        pattern: _pattern,
        entry: entry,
      );
    });
  }

  void _replaceColor(PaletteEntry entry) {
    final replacement = _pattern.paletteEntries.firstWhere(
      (candidate) => candidate.ref != entry.ref,
      orElse: () => entry,
    );
    if (replacement.ref == entry.ref) return;
    setState(() {
      if (_selectedBeadRef == entry.ref) {
        _selectedBeadRef = replacement.ref;
      }
      _pattern = _materialEditService.replaceColor(
        pattern: _pattern,
        from: entry,
        to: replacement,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entry.ref} 已替换为 ${replacement.ref}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(title: const Text('拼豆图纸')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: _buildModeSwitch(),
            ),
            Expanded(
              child: _displayMode == _ResultDisplayMode.chart
                  ? _buildChartMode()
                  : _buildBeadMode(),
            ),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitch() {
    return Align(
      alignment: Alignment.center,
      child: SegmentedButton<_ResultDisplayMode>(
        showSelectedIcon: false,
        selected: {_displayMode},
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFFF7FA2);
            }
            return Colors.white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xFF667085);
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: Colors.white, width: 2),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        segments: const [
          ButtonSegment(value: _ResultDisplayMode.chart, label: Text('图纸模式')),
          ButtonSegment(value: _ResultDisplayMode.beads, label: Text('拼豆模式')),
        ],
        onSelectionChanged: (selection) {
          setState(() => _displayMode = selection.first);
        },
      ),
    );
  }

  Widget _buildChartMode() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 360,
          color: Colors.white,
          child: PatternPreview(
            pixels: _pattern.pixels,
            width: _pattern.width,
            height: _pattern.height,
            mode: PatternPreviewMode.chart,
            paletteEntries: _pattern.paletteEntries,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              '用料清单',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text('共计${_pattern.totalBeads}颗'),
          ],
        ),
        const SizedBox(height: 12),
        MaterialUsageList(
          usage: _pattern.usage,
          entries: _pattern.paletteEntries,
          onTap: _replaceColor,
          onLongPress: _deleteColor,
        ),
        const SizedBox(height: 12),
        const Text('点击颜色可以更换 / 长按颜色可以删除'),
      ],
    );
  }

  Widget _buildBeadMode() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: BeadBoardPreview(
              pixels: _pattern.pixels,
              width: _pattern.width,
              height: _pattern.height,
              paletteEntries: _pattern.paletteEntries,
              selectedRef: _selectedBeadRef,
            ),
          ),
        ),
        BeadModeUsageStrip(
          usage: _pattern.usage,
          entries: _pattern.paletteEntries,
          selectedRef: _selectedBeadRef,
          onSelected: (ref) => setState(() => _selectedBeadRef = ref),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(onPressed: _openEditor, child: const Text('编辑')),
          ),
          Expanded(
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中...' : '保存'),
            ),
          ),
          Expanded(
            child: FilledButton.icon(
              onPressed: _exporting ? null : _export,
              icon: const Icon(Icons.ios_share, size: 18),
              label: Text(_exporting ? '导出中...' : '导出'),
            ),
          ),
        ],
      ),
    );
  }
}
