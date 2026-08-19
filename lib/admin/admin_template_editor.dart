import 'package:flutter/material.dart';

import '../models/generated_pattern.dart';
import '../services/api/api_models.dart';
import '../widgets/pattern_preview.dart';
import 'admin_api.dart';
import 'admin_pattern_editor.dart';
import 'admin_preview_exporter.dart';

enum AdminTemplateEditorOutcome {
  /// Work was parked in the draft box; nothing user-facing changed.
  draftSaved,

  /// A draft or a direct edit went live.
  published,
  draftDiscarded,

  /// The draft vanished server-side, so the caller's list is stale.
  draftMissing,
}

class AdminTemplateEditorResult {
  final AdminTemplateEditorOutcome outcome;
  final String templateId;

  const AdminTemplateEditorResult(this.outcome, {this.templateId = ''});
}

/// Edits an official template or one of its drafts.
///
/// Three entry points share this page:
/// - [template] only: revising a published template that has no draft yet. It
///   can be pushed live directly or parked as a revision draft.
/// - [draftId] only: continuing a draft for a pattern that was never published.
/// - both: continuing a revision draft, where publishing overwrites [template].
///
/// Opening a template that already has a draft must pass that [draftId].
/// `PUT /admin/templates/{id}` is unaware of drafts, so editing the template
/// directly and then publishing the draft would silently discard the direct
/// edit without the server reporting a conflict.
class AdminTemplateEditorPage extends StatefulWidget {
  final AdminApi api;
  final List<AdminCategory> categories;
  final AdminTemplate? template;
  final String? draftId;

  const AdminTemplateEditorPage({
    super.key,
    required this.api,
    required this.categories,
    this.template,
    this.draftId,
  }) : assert(
         template != null || draftId != null,
         'The editor needs a template, a draft, or both.',
       );

  @override
  State<AdminTemplateEditorPage> createState() =>
      _AdminTemplateEditorPageState();
}

class _AdminTemplateEditorPageState extends State<AdminTemplateEditorPage> {
  final _previewExporter = const AdminPreviewExporter();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  GeneratedPattern? _pattern;
  String _boardSpec = '';
  int? _categoryId;
  int _difficulty = 1;

  String? _draftId;
  String _baseUpdatedAt = '';
  String _templateId = '';

  bool _loading = true;
  bool _savingDraft = false;
  bool _publishing = false;
  bool _discarding = false;
  String? _error;
  String? _notice;
  AdminTemplateEditorResult? _result;

  bool get _busy => _savingDraft || _publishing || _discarding;
  bool get _isDraft => _draftId != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _draftId = widget.draftId;
    _templateId = template?.id ?? '';
    if (template != null) {
      _titleController.text = template.title;
      _descriptionController.text = template.description;
      _tagsController.text = template.tags.join(', ');
      _categoryId = template.categoryId > 0 ? template.categoryId : null;
      _difficulty = template.difficulty > 0 ? template.difficulty : 1;
    }
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
      final draftId = _draftId;
      if (draftId != null) {
        _applyDraft(await widget.api.getDraft(draftId));
      } else {
        _applyTemplate(await widget.api.getTemplate(_templateId));
      }
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyTemplate(AdminTemplateDetail detail) {
    if (!mounted) return;
    setState(() {
      _pattern = detail.patternData.toGeneratedPattern();
      _boardSpec = detail.patternData.boardSpec;
      _titleController.text = detail.template.title;
      _descriptionController.text = detail.template.description;
      _tagsController.text = detail.template.tags.join(', ');
      if (detail.template.categoryId > 0) {
        _categoryId = detail.template.categoryId;
      }
      if (detail.template.difficulty > 0) {
        _difficulty = detail.template.difficulty;
      }
    });
  }

  void _applyDraft(AdminTemplateDraftDetail detail) {
    if (!mounted) return;
    setState(() {
      _pattern = detail.patternData.toGeneratedPattern();
      _boardSpec = detail.patternData.boardSpec;
      _titleController.text = detail.draft.title;
      _descriptionController.text = detail.description;
      _tagsController.text = detail.tags.join(', ');
      _categoryId = detail.draft.categoryId > 0 ? detail.draft.categoryId : null;
      _difficulty = detail.draft.difficulty > 0 ? detail.draft.difficulty : 1;
      // Stored verbatim: the server compares this string for exact equality.
      _baseUpdatedAt = detail.draft.updatedAt;
      if (detail.draft.templateId.isNotEmpty) {
        _templateId = detail.draft.templateId;
      }
    });
  }

  Future<void> _editPattern([
    AdminPatternEditingMode initialMode = AdminPatternEditingMode.brush,
  ]) async {
    final pattern = _pattern;
    if (pattern == null || _busy) return;
    final edited = await Navigator.of(context).push<GeneratedPattern>(
      MaterialPageRoute(
        builder: (_) =>
            AdminPatternEditorPage(pattern: pattern, initialMode: initialMode),
      ),
    );
    if (!mounted || edited == null) return;
    setState(() {
      _pattern = edited;
      _notice = '图纸已修改，记得保存草稿或发布。';
    });
  }

  PatternData? _currentPatternData() {
    final pattern = _pattern;
    if (pattern == null) return null;
    return PatternData.fromGeneratedPattern(
      pattern,
      boardSpec: _boardSpec.isEmpty ? null : _boardSpec,
    );
  }

  /// Parks the current state in the draft box without touching the live
  /// template. Title, category and difficulty may all still be blank here; the
  /// server only enforces them at publish time.
  Future<void> _saveDraft() async {
    final patternData = _currentPatternData();
    if (patternData == null || _busy) return;
    setState(() {
      _savingDraft = true;
      _error = null;
      _notice = null;
    });
    try {
      // Saved on every draft write, not just at publish: the draft box has no
      // pattern data to fall back on, so a draft without a preview is blank.
      final thumbnail = await _previewExporter.exportGalleryThumbnailPng(
        _pattern!,
      );
      final draftId = _draftId;
      if (draftId == null) {
        final saved = await widget.api.createDraft(
          idempotencyKey: 'admin-draft-${DateTime.now().microsecondsSinceEpoch}',
          templateId: _templateId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryId: _categoryId ?? 0,
          tags: _tagsController.text.trim(),
          difficulty: _difficulty,
          patternData: patternData,
          thumbnailBytes: thumbnail,
        );
        if (!mounted) return;
        setState(() {
          _draftId = saved.draftId;
          _baseUpdatedAt = saved.updatedAt;
        });
      } else {
        final updatedAt = await widget.api.updateDraft(
          draftId: draftId,
          baseUpdatedAt: _baseUpdatedAt,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryId: _categoryId ?? 0,
          tags: _tagsController.text.trim(),
          difficulty: _difficulty,
          patternData: patternData,
          thumbnailBytes: thumbnail,
        );
        if (!mounted) return;
        setState(() => _baseUpdatedAt = updatedAt);
      }
      if (!mounted) return;
      setState(() {
        _notice = '已保存到草稿箱，线上版本未改动。';
        _result = const AdminTemplateEditorResult(
          AdminTemplateEditorOutcome.draftSaved,
        );
      });
    } catch (error) {
      await _reportFailure(error);
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _publish() async {
    final patternData = _currentPatternData();
    if (patternData == null || _busy) return;
    final title = _titleController.text.trim();
    final categoryId = _categoryId;
    if (title.isEmpty) {
      setState(() => _error = '请填写模板标题');
      return;
    }
    if (categoryId == null) {
      setState(() => _error = '请选择客户端分类');
      return;
    }
    setState(() {
      _publishing = true;
      _error = null;
      _notice = null;
    });
    try {
      final thumbnail = await _previewExporter.exportGalleryThumbnailPng(
        _pattern!,
      );
      final draftId = _draftId;
      String templateId;
      if (draftId == null) {
        await widget.api.updateTemplate(
          templateId: _templateId,
          title: title,
          description: _descriptionController.text.trim(),
          categoryId: categoryId,
          tags: _tagsController.text.trim(),
          difficulty: _difficulty,
          patternData: patternData,
          thumbnailBytes: thumbnail,
        );
        templateId = _templateId;
      } else {
        // The draft has to carry the latest edits before it can go live: the
        // publish endpoint only takes the preview key and the lock baseline.
        final updatedAt = await widget.api.updateDraft(
          draftId: draftId,
          baseUpdatedAt: _baseUpdatedAt,
          title: title,
          description: _descriptionController.text.trim(),
          categoryId: categoryId,
          tags: _tagsController.text.trim(),
          difficulty: _difficulty,
          patternData: patternData,
          thumbnailBytes: thumbnail,
        );
        if (mounted) setState(() => _baseUpdatedAt = updatedAt);
        templateId = await widget.api.publishDraft(
          draftId: draftId,
          idempotencyKey:
              'admin-publish-${DateTime.now().microsecondsSinceEpoch}',
          baseUpdatedAt: updatedAt,
          thumbnailBytes: thumbnail,
        );
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminTemplateEditorResult(
          AdminTemplateEditorOutcome.published,
          templateId: templateId,
        ),
      );
    } catch (error) {
      await _reportFailure(error);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _discardDraft() async {
    final draftId = _draftId;
    if (draftId == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('丢弃这份草稿？'),
        content: Text(
          _templateId.isEmpty
              ? '草稿中的图纸和信息会被删除，无法恢复。'
              : '只会删除这份未发布的修订，线上模板保持不变。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC6284A),
            ),
            child: const Text('丢弃'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _discarding = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.api.deleteDraft(draftId);
      if (!mounted) return;
      Navigator.pop(
        context,
        const AdminTemplateEditorResult(
          AdminTemplateEditorOutcome.draftDiscarded,
        ),
      );
    } catch (error) {
      await _reportFailure(error);
    } finally {
      if (mounted) setState(() => _discarding = false);
    }
  }

  /// Turns a failed draft write into either the conflict recovery flow or a
  /// readable notice.
  Future<void> _reportFailure(Object error) async {
    if (!mounted) return;
    if (error is ApiException) {
      switch (error.code) {
        case AdminDraftErrorCode.conflict:
          await _resolveConflict();
          return;
        case AdminDraftErrorCode.notFound:
          Navigator.pop(
            context,
            const AdminTemplateEditorResult(
              AdminTemplateEditorOutcome.draftMissing,
            ),
          );
          return;
      }
    }
    setState(() => _error = _errorMessage(error));
  }

  /// Recovers from a `4001` conflict.
  ///
  /// The conflict message names the other operator for log triage only, so the
  /// name shown here comes from a fresh detail fetch instead of the message.
  Future<void> _resolveConflict() async {
    final draftId = _draftId;
    if (draftId == null) return;
    AdminTemplateDraftDetail? latest;
    try {
      latest = await widget.api.getDraft(draftId);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException &&
          error.code == AdminDraftErrorCode.notFound) {
        Navigator.pop(
          context,
          const AdminTemplateEditorResult(
            AdminTemplateEditorOutcome.draftMissing,
          ),
        );
        return;
      }
      setState(() => _error = '这份草稿已被其他管理员修改，且重新加载失败：${_errorMessage(error)}');
      return;
    }
    if (!mounted) return;
    final actor = latest.draft.updatedByActor;
    final message = actor.isEmpty
        ? '这份草稿已被其他管理员修改。'
        : '这份草稿已被 $actor 修改。';
    final reload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存被拒绝'),
        content: Text('$message\n\n重新加载会用服务端的最新版本覆盖你当前的改动。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留我的改动'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (reload == true) {
      _applyDraft(latest);
      setState(() {
        _error = null;
        _notice = '已加载最新版本。';
      });
      return;
    }
    setState(() => _error = '$message当前改动尚未保存，重新加载后再改，或复制内容后重试。');
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        AdminDraftErrorCode.boxFull => '草稿箱已满（上限 200 份），请先清理再保存。',
        AdminDraftErrorCode.notPublishable => '这份草稿还发不出去：${error.message}',
        AdminDraftErrorCode.missingPreview => '缺少图库缩略图，请重新发布。',
        _ => error.message,
      };
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  String get _pageTitle {
    if (!_isDraft) return '编辑官方模板';
    return _templateId.isEmpty ? '编辑草稿' : '编辑模板修订草稿';
  }

  @override
  Widget build(BuildContext context) {
    final pattern = _pattern;
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : pattern == null
        ? _TemplateEditError(error: _error, onRetry: _load)
        : _EditorWorkspace(
            pattern: pattern,
            titleController: _titleController,
            descriptionController: _descriptionController,
            tagsController: _tagsController,
            categories: widget.categories,
            categoryId: _categoryId,
            difficulty: _difficulty,
            busy: _busy,
            error: _error,
            notice: _notice,
            subtitle: _isDraft
                ? (_templateId.isEmpty
                      ? '草稿不会对用户生效，发布后才会新建官方模板。'
                      : '草稿不会对用户生效，发布后才会覆盖线上模板。')
                : '直接发布会立即覆盖客户端图库缩略图和图纸数据。',
            actions: _buildActions(),
            onCategoryChanged: (value) => setState(() => _categoryId = value),
            onDifficultyChanged: (value) => setState(() => _difficulty = value),
            onEditPattern: _editPattern,
          );
    return PopScope(
      // Parking a draft keeps the operator on this page, so the outcome has to
      // be handed back when they navigate away instead.
      canPop: _result == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _result);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFBFC),
          surfaceTintColor: Colors.transparent,
          title: Text(_pageTitle),
          actions: [
            if (_isDraft)
              IconButton(
                key: const ValueKey('template-discard-draft'),
                tooltip: '丢弃草稿',
                onPressed: _busy ? null : _discardDraft,
                icon: _discarding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: body,
      ),
    );
  }

  List<Widget> _buildActions() {
    return [
      OutlinedButton.icon(
        key: const ValueKey('template-save-draft'),
        onPressed: _busy ? null : _saveDraft,
        icon: _savingDraft
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.bookmark_add_outlined),
        label: Text(
          _savingDraft
              ? '正在保存…'
              : _isDraft
              ? '保存草稿'
              : '存为修订草稿',
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        key: const ValueKey('template-publish'),
        onPressed: _busy ? null : _publish,
        icon: _publishing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.publish_rounded),
        label: Text(
          _publishing
              ? '正在发布…'
              : _isDraft
              ? '发布草稿'
              : '直接发布修改',
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF4F79),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    ];
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
  final bool busy;
  final String? error;
  final String? notice;
  final String subtitle;
  final List<Widget> actions;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int> onDifficultyChanged;
  final ValueChanged<AdminPatternEditingMode> onEditPattern;

  const _EditorWorkspace({
    required this.pattern,
    required this.titleController,
    required this.descriptionController,
    required this.tagsController,
    required this.categories,
    required this.categoryId,
    required this.difficulty,
    required this.busy,
    required this.error,
    required this.notice,
    required this.subtitle,
    required this.actions,
    required this.onCategoryChanged,
    required this.onDifficultyChanged,
    required this.onEditPattern,
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
          busy: busy,
          error: error,
          notice: notice,
          subtitle: subtitle,
          actions: actions,
          onCategoryChanged: onCategoryChanged,
          onDifficultyChanged: onDifficultyChanged,
        );
        final preview = _TemplatePatternPreview(
          pattern: pattern,
          busy: busy,
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
  final bool busy;
  final String? error;
  final String? notice;
  final String subtitle;
  final List<Widget> actions;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int> onDifficultyChanged;

  const _TemplateForm({
    required this.titleController,
    required this.descriptionController,
    required this.tagsController,
    required this.categories,
    required this.categoryId,
    required this.difficulty,
    required this.busy,
    required this.error,
    required this.notice,
    required this.subtitle,
    required this.actions,
    required this.onCategoryChanged,
    required this.onDifficultyChanged,
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
            Text(subtitle),
            if (error != null) ...[
              const SizedBox(height: 16),
              _TemplateEditNotice(message: error!),
            ] else if (notice != null) ...[
              const SizedBox(height: 16),
              _TemplateEditNotice(message: notice!, isError: false),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              enabled: !busy,
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
              onChanged: busy ? null : onCategoryChanged,
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
              onChanged: busy ? null : (value) => onDifficultyChanged(value ?? 1),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tagsController,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: '标签',
                hintText: '例如：动物, 礼物, 入门',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              enabled: !busy,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(labelText: '模板说明'),
            ),
            const SizedBox(height: 12),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _TemplatePatternPreview extends StatelessWidget {
  final GeneratedPattern pattern;
  final bool busy;
  final ValueChanged<AdminPatternEditingMode> onEditPattern;

  const _TemplatePatternPreview({
    required this.pattern,
    required this.busy,
    required this.onEditPattern,
  });

  @override
  Widget build(BuildContext context) {
    final editorButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('template-open-brush-editor'),
          onPressed: busy
              ? null
              : () => onEditPattern(AdminPatternEditingMode.brush),
          icon: const Icon(Icons.brush_outlined),
          label: const Text('画笔模式'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('template-open-palette-editor'),
          onPressed: busy
              ? null
              : () => onEditPattern(AdminPatternEditingMode.palette),
          icon: const Icon(Icons.palette_outlined),
          label: const Text('色板模式'),
        ),
      ],
    );

    return _TemplateEditPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
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
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), editorButtons],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  editorButtons,
                ],
              );
            },
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
              const Text('图纸详情加载失败'),
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
  final bool isError;

  const _TemplateEditNotice({required this.message, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFC6284A) : const Color(0xFF2F7A4F);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(message, style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
