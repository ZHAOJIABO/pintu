import 'package:flutter/material.dart';

import '../models/generated_pattern.dart';
import '../services/api/api_models.dart';
import '../widgets/pattern_preview.dart';
import 'admin_api.dart';
import 'admin_pattern_editor.dart';
import 'admin_preview_exporter.dart';

/// Edits an existing official template and republishes its preview and data in
/// one atomic operator action.
class AdminTemplateEditorPage extends StatefulWidget {
  final AdminApi api;
  final AdminTemplate template;
  final List<AdminCategory> categories;

  const AdminTemplateEditorPage({
    super.key,
    required this.api,
    required this.template,
    required this.categories,
  });

  @override
  State<AdminTemplateEditorPage> createState() =>
      _AdminTemplateEditorPageState();
}

class _AdminTemplateEditorPageState extends State<AdminTemplateEditorPage> {
  final _previewExporter = const AdminPreviewExporter();
  late final _titleController = TextEditingController(
    text: widget.template.title,
  );
  late final _descriptionController = TextEditingController(
    text: widget.template.description,
  );
  late final _tagsController = TextEditingController(
    text: widget.template.tags.join(', '),
  );

  AdminTemplateDetail? _detail;
  GeneratedPattern? _pattern;
  int? _categoryId;
  int _difficulty = 1;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.template.categoryId > 0
        ? widget.template.categoryId
        : null;
    _difficulty = widget.template.difficulty > 0
        ? widget.template.difficulty
        : 1;
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await widget.api.getTemplate(widget.template.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _pattern = detail.patternData.toGeneratedPattern();
        _titleController.text = detail.template.title;
        _descriptionController.text = detail.template.description;
        _tagsController.text = detail.template.tags.join(', ');
        _categoryId = detail.template.categoryId > 0
            ? detail.template.categoryId
            : _categoryId;
        _difficulty = detail.template.difficulty > 0
            ? detail.template.difficulty
            : _difficulty;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editPattern() async {
    final pattern = _pattern;
    if (pattern == null || _saving) return;
    final edited = await Navigator.of(context).push<GeneratedPattern>(
      MaterialPageRoute(
        builder: (_) => AdminPatternEditorPage(pattern: pattern),
      ),
    );
    if (!mounted || edited == null) return;
    setState(() => _pattern = edited);
  }

  Future<void> _save() async {
    final pattern = _pattern;
    final detail = _detail;
    final title = _titleController.text.trim();
    final categoryId = _categoryId;
    if (pattern == null || detail == null) return;
    if (title.isEmpty) {
      setState(() => _error = '请填写模板标题');
      return;
    }
    if (categoryId == null) {
      setState(() => _error = '请选择客户端分类');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final thumbnail = await _previewExporter.exportGalleryThumbnailPng(
        pattern,
      );
      await widget.api.updateTemplate(
        templateId: widget.template.id,
        title: title,
        description: _descriptionController.text.trim(),
        categoryId: categoryId,
        tags: _tagsController.text.trim(),
        difficulty: _difficulty,
        patternData: PatternData.fromGeneratedPattern(
          pattern,
          boardSpec: detail.patternData.boardSpec,
        ),
        thumbnailBytes: thumbnail,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _pattern == null
        ? _TemplateEditError(error: _error, onRetry: _load)
        : _EditorWorkspace(
            pattern: _pattern!,
            titleController: _titleController,
            descriptionController: _descriptionController,
            tagsController: _tagsController,
            categories: widget.categories,
            categoryId: _categoryId,
            difficulty: _difficulty,
            saving: _saving,
            error: _error,
            onCategoryChanged: (value) => setState(() => _categoryId = value),
            onDifficultyChanged: (value) => setState(() => _difficulty = value),
            onEditPattern: _editPattern,
            onSave: _save,
          );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBFC),
        surfaceTintColor: Colors.transparent,
        title: const Text('编辑官方模板'),
      ),
      body: body,
    );
  }
}

class _EditorWorkspace extends StatelessWidget {
  final GeneratedPattern pattern;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController tagsController;
  final List<AdminCategory> categories;
  final int? categoryId;
  final int difficulty;
  final bool saving;
  final String? error;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int> onDifficultyChanged;
  final VoidCallback onEditPattern;
  final VoidCallback onSave;

  const _EditorWorkspace({
    required this.pattern,
    required this.titleController,
    required this.descriptionController,
    required this.tagsController,
    required this.categories,
    required this.categoryId,
    required this.difficulty,
    required this.saving,
    required this.error,
    required this.onCategoryChanged,
    required this.onDifficultyChanged,
    required this.onEditPattern,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final form = _TemplateForm(
          titleController: titleController,
          descriptionController: descriptionController,
          tagsController: tagsController,
          categories: categories,
          categoryId: categoryId,
          difficulty: difficulty,
          saving: saving,
          error: error,
          onCategoryChanged: onCategoryChanged,
          onDifficultyChanged: onDifficultyChanged,
          onSave: onSave,
        );
        final preview = _TemplatePatternPreview(
          pattern: pattern,
          saving: saving,
          onEditPattern: onEditPattern,
        );
        return compact
            ? ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  form,
                  const SizedBox(height: 20),
                  SizedBox(height: 600, child: preview),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 360, child: form),
                    const SizedBox(width: 20),
                    Expanded(child: preview),
                  ],
                ),
              );
      },
    );
  }
}

class _TemplateForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController tagsController;
  final List<AdminCategory> categories;
  final int? categoryId;
  final int difficulty;
  final bool saving;
  final String? error;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int> onDifficultyChanged;
  final VoidCallback onSave;

  const _TemplateForm({
    required this.titleController,
    required this.descriptionController,
    required this.tagsController,
    required this.categories,
    required this.categoryId,
    required this.difficulty,
    required this.saving,
    required this.error,
    required this.onCategoryChanged,
    required this.onDifficultyChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCategoryId =
        categories.any((category) => category.id == categoryId)
        ? categoryId
        : null;
    return _TemplateEditPanel(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '模板信息',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('修改后会同步更新客户端图库缩略图和图纸数据。'),
            if (error != null) ...[
              const SizedBox(height: 16),
              _TemplateEditNotice(message: error!),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              enabled: !saving,
              maxLength: 80,
              decoration: const InputDecoration(labelText: '模板标题 *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('template-edit-category-$selectedCategoryId'),
              initialValue: selectedCategoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '客户端分类 *'),
              hint: const Text('请选择分类'),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: saving ? null : onCategoryChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('template-edit-difficulty-$difficulty'),
              initialValue: difficulty,
              decoration: const InputDecoration(labelText: '难度'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('入门')),
                DropdownMenuItem(value: 2, child: Text('进阶')),
                DropdownMenuItem(value: 3, child: Text('挑战')),
              ],
              onChanged: saving
                  ? null
                  : (value) => onDifficultyChanged(value ?? 1),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tagsController,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: '标签',
                hintText: '例如：动物, 礼物, 入门',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              enabled: !saving,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(labelText: '模板说明'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? '正在保存…' : '保存修改'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF4F79),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatePatternPreview extends StatelessWidget {
  final GeneratedPattern pattern;
  final bool saving;
  final VoidCallback onEditPattern;

  const _TemplatePatternPreview({
    required this.pattern,
    required this.saving,
    required this.onEditPattern,
  });

  @override
  Widget build(BuildContext context) {
    return _TemplateEditPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '图纸预览',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pattern.totalBeads} 颗拼豆 · ${pattern.usage.length} 种颜色',
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: saving ? null : onEditPattern,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('拼豆模式编辑'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFFF7F7FA)),
                child: PatternPreview(
                  pixels: pattern.pixels,
                  width: pattern.width,
                  height: pattern.height,
                  showGrid: true,
                  mode: PatternPreviewMode.chart,
                  paletteEntries: pattern.paletteEntries,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateEditError extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;

  const _TemplateEditError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: _TemplateEditPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFC6284A),
              ),
              const SizedBox(height: 12),
              const Text('模板详情加载失败'),
              const SizedBox(height: 6),
              Text(error ?? '请稍后重试', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateEditPanel extends StatelessWidget {
  final Widget child;

  const _TemplateEditPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        border: Border.all(color: const Color(0xFFECE3EA)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class _TemplateEditNotice extends StatelessWidget {
  final String message;

  const _TemplateEditNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFC6284A);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(message, style: const TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
