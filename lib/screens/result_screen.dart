import 'package:flutter/material.dart';

import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../services/material_edit_service.dart';
import '../services/project_storage_service.dart';
import '../widgets/material_usage_list.dart';
import '../widgets/pattern_preview.dart';
import 'pattern_editor_screen.dart';

class ResultScreen extends StatefulWidget {
  final GeneratedPattern pattern;

  const ResultScreen({super.key, required this.pattern});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final MaterialEditService _materialEditService = MaterialEditService();
  final ProjectStorageService _storageService = ProjectStorageService();
  late GeneratedPattern _pattern = widget.pattern;
  bool _saving = false;

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
      appBar: AppBar(title: const Text('图纸生成中')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    height: 360,
                    color: Colors.white,
                    child: PatternPreview(
                      pixels: _pattern.pixels,
                      width: _pattern.width,
                      height: _pattern.height,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        '用料清单',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
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
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _openEditor,
                      child: const Text('编辑'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? '保存中...' : '保存'),
                    ),
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
