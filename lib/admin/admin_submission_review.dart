import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/generated_pattern.dart';
import '../services/api/api_models.dart';
import '../services/image_service.dart';
import '../widgets/pattern_preview.dart';
import 'admin_api.dart';
import 'admin_preview_exporter.dart';

enum AdminSubmissionReviewOutcome { approved, rejected }

class AdminSubmissionReviewResult {
  final AdminSubmissionReviewOutcome outcome;
  final String templateId;

  const AdminSubmissionReviewResult({
    required this.outcome,
    this.templateId = '',
  });
}

/// Reviews a single user submission: the operator inspects the pattern, polishes
/// the metadata, then either publishes it as an official template or rejects it.
class AdminSubmissionReviewPage extends StatefulWidget {
  final AdminApi api;
  final AdminSubmission submission;
  final List<AdminCategory> categories;

  const AdminSubmissionReviewPage({
    super.key,
    required this.api,
    required this.submission,
    required this.categories,
  });

  @override
  State<AdminSubmissionReviewPage> createState() =>
      _AdminSubmissionReviewPageState();
}

class _AdminSubmissionReviewPageState extends State<AdminSubmissionReviewPage> {
  final _previewExporter = const AdminPreviewExporter();
  final _imageService = ImageService();
  late final _titleController = TextEditingController(
    text: widget.submission.title,
  );
  late final _descriptionController = TextEditingController(
    text: widget.submission.description,
  );
  final _tagsController = TextEditingController();
  // Owned by the page rather than the dialog: the dialog's dismiss animation
  // keeps rebuilding the reason field for a few frames after it pops.
  final _rejectReasonController = TextEditingController();

  AdminSubmissionDetail? _detail;
  GeneratedPattern? _pattern;
  Uint8List? _replacementPreview;
  int? _categoryId;
  int _difficulty = 1;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  AdminSubmission get _submission => _detail?.submission ?? widget.submission;

  bool get _isPending => _submission.status == AdminSubmissionStatus.pending;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.isEmpty ? null : widget.categories.first.id;
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.api.getSubmission(widget.submission.id);
      // A submission with unusable pattern data still has to be reviewable:
      // the operator needs the reject action precisely for cases like this.
      GeneratedPattern? pattern;
      try {
        pattern = detail.patternData.toGeneratedPattern();
      } catch (_) {
        pattern = null;
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _pattern = pattern;
        _titleController.text = detail.submission.title;
        _descriptionController.text = detail.submission.description;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickReplacementPreview() async {
    if (_submitting) return;
    try {
      final image = await _imageService.pickImage();
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _replacementPreview = bytes;
        _error = null;
      });
    } catch (error) {
      _setError('选择预览图失败：${_errorMessage(error)}');
    }
  }

  Future<void> _approve() async {
    final categoryId = _categoryId;
    if (categoryId == null) {
      _setError('请选择客户端分类');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final previewFileKey = await _resolvePreviewFileKey();
      final templateId = await widget.api.approveSubmission(
        submissionId: _submission.id,
        categoryId: categoryId,
        difficulty: _difficulty,
        tags: _tagsController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        previewFileKey: previewFileKey,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminSubmissionReviewResult(
          outcome: AdminSubmissionReviewOutcome.approved,
          templateId: templateId,
        ),
      );
    } catch (error) {
      _setError('审核通过失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Empty means "keep the preview the submitter uploaded". When the submission
  /// arrived without one the server refuses the approval, so the chart is
  /// rendered into a thumbnail to stand in for it.
  Future<String> _resolvePreviewFileKey() async {
    final replacement = _replacementPreview;
    if (replacement != null) {
      return widget.api.uploadPreviewImage(bytes: replacement);
    }
    if (_submission.imageUrl.isNotEmpty) return '';
    final pattern = _pattern;
    if (pattern == null) {
      throw const FormatException('投稿没有预览图且图纸数据不可用，请先上传一张预览图');
    }
    final bytes = await _previewExporter.exportGalleryThumbnailPng(pattern);
    return widget.api.uploadPreviewImage(
      bytes: bytes,
      contentType: 'image/png',
    );
  }

  Future<void> _reject() async {
    final reason = await _askRejectReason();
    if (!mounted || reason == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.rejectSubmission(
        submissionId: _submission.id,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        const AdminSubmissionReviewResult(
          outcome: AdminSubmissionReviewOutcome.rejected,
        ),
      );
    } catch (error) {
      _setError('驳回失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String?> _askRejectReason() async {
    final controller = _rejectReasonController..clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('驳回用户投稿'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「${_submission.title}」驳回后会向投稿人展示以下原因。'),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('submission-reject-reason'),
              controller: controller,
              autofocus: true,
              maxLength: 200,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '驳回原因 *',
                hintText: '例如：图案存在版权风险',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => FilledButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, value.text.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC6284A),
              ),
              child: const Text('确认驳回'),
            ),
          ),
        ],
      ),
    );
  }

  void _setError(String value) {
    if (!mounted) return;
    setState(() => _error = value);
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBFC),
        surfaceTintColor: Colors.transparent,
        title: const Text('审核用户投稿'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_detail == null) {
      return _ReviewLoadError(error: _error, onRetry: _load);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final form = _buildForm(context);
        final preview = _buildPatternPreview(context);
        return compact
            ? ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  form,
                  const SizedBox(height: 20),
                  SizedBox(height: 560, child: preview),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 380, child: form),
                    const SizedBox(width: 20),
                    Expanded(child: preview),
                  ],
                ),
              );
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final submission = _submission;
    final selectedCategoryId =
        widget.categories.any((category) => category.id == _categoryId)
        ? _categoryId
        : null;
    return _ReviewPanel(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '投稿信息',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AdminSubmissionStatusBadge(status: submission.status),
              ],
            ),
            const SizedBox(height: 10),
            _ReviewMetaRow(label: '投稿 ID', value: submission.id),
            _ReviewMetaRow(label: '投稿人 ID', value: submission.userId),
            _ReviewMetaRow(label: '作品 ID', value: submission.workId),
            _ReviewMetaRow(
              label: '投稿时间',
              value: formatAdminTimestamp(submission.createdAt),
            ),
            if (!_isPending) ...[
              _ReviewMetaRow(
                label: '审核人',
                value: submission.reviewerActor.isEmpty
                    ? '—'
                    : submission.reviewerActor,
              ),
              _ReviewMetaRow(
                label: '审核时间',
                value: formatAdminTimestamp(submission.reviewedAt),
              ),
              if (submission.reviewReason.isNotEmpty)
                _ReviewMetaRow(label: '审核意见', value: submission.reviewReason),
              if (submission.templateId.isNotEmpty)
                _ReviewMetaRow(label: '生成模板', value: submission.templateId),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ReviewNotice(message: _error!),
            ],
            const SizedBox(height: 18),
            _ReviewSectionLabel(label: '预览图'),
            const SizedBox(height: 8),
            _PreviewImageCard(
              replacement: _replacementPreview,
              imageUrl: submission.imageUrl,
              pattern: _pattern,
            ),
            const SizedBox(height: 8),
            if (_isPending) ...[
              OutlinedButton.icon(
                key: const ValueKey('submission-pick-preview'),
                onPressed: _submitting ? null : _pickReplacementPreview,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _replacementPreview == null ? '重新上传预览图' : '更换已选预览图',
                ),
              ),
              if (_replacementPreview != null)
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _replacementPreview = null),
                  child: const Text('恢复投稿自带预览图'),
                ),
              const SizedBox(height: 4),
              Text(
                submission.imageUrl.isEmpty
                    ? '该投稿没有自带预览图，通过时会用图纸自动生成一张。'
                    : '留空则沿用投稿人上传的预览图。',
                style: const TextStyle(color: Color(0xFF6A6470), fontSize: 12),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            _ReviewSectionLabel(label: '发布信息'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              enabled: _isPending && !_submitting,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '模板标题',
                helperText: '留空则沿用投稿标题',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('submission-category-$selectedCategoryId'),
              initialValue: selectedCategoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '客户端分类 *'),
              hint: const Text('请选择分类'),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: _isPending && !_submitting
                  ? (value) => setState(() => _categoryId = value)
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('submission-difficulty-$_difficulty'),
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: '难度'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('入门')),
                DropdownMenuItem(value: 2, child: Text('进阶')),
                DropdownMenuItem(value: 3, child: Text('挑战')),
              ],
              onChanged: _isPending && !_submitting
                  ? (value) => setState(() => _difficulty = value ?? 1)
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              enabled: _isPending && !_submitting,
              decoration: const InputDecoration(
                labelText: '标签',
                hintText: '例如：动物, 礼物, 入门',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              enabled: _isPending && !_submitting,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '模板说明',
                helperText: '留空则沿用投稿说明',
              ),
            ),
            const SizedBox(height: 8),
            if (_isPending) ...[
              FilledButton.icon(
                key: const ValueKey('submission-approve'),
                onPressed: _submitting ? null : _approve,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(_submitting ? '正在提交…' : '通过并发布为官方模板'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4F79),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('submission-reject'),
                onPressed: _submitting ? null : _reject,
                icon: const Icon(Icons.block_outlined),
                label: const Text('驳回投稿'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC6284A),
                  side: const BorderSide(color: Color(0xFFE4AFBA)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ] else
              _ReviewClosedHint(status: submission.status),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternPreview(BuildContext context) {
    final submission = _submission;
    final pattern = _pattern;
    return _ReviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '图纸预览',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (submission.width > 0 && submission.height > 0)
                _ReviewPill(label: '${submission.width}×${submission.height}'),
              if (submission.boardSpec.isNotEmpty)
                _ReviewPill(label: submission.boardSpec),
              if (submission.beadCount > 0)
                _ReviewPill(label: '${submission.beadCount} 颗豆子'),
              if (submission.colorCount > 0)
                _ReviewPill(label: '${submission.colorCount} 种颜色'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFFF7F7FA)),
                child: pattern == null
                    ? const Center(child: Text('图纸数据无法解析，建议驳回该投稿。'))
                    : PatternPreview(
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

/// Formats a second-precision admin timestamp for operator-facing labels.
String formatAdminTimestamp(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String pad(int component) => component.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} '
      '${pad(local.hour)}:${pad(local.minute)}';
}

class _PreviewImageCard extends StatelessWidget {
  final Uint8List? replacement;
  final String imageUrl;
  final GeneratedPattern? pattern;

  const _PreviewImageCard({
    required this.replacement,
    required this.imageUrl,
    required this.pattern,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: const Color(0xFFF7F7FA),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final bytes = replacement;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.contain);
    }
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        // Submission previews live on OSS; prefer the native image element so
        // they stay visible while the bucket CORS policy is being corrected.
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final data = pattern;
    if (data != null) {
      return PatternPreview(
        pixels: data.pixels,
        width: data.width,
        height: data.height,
        showGrid: false,
        mode: PatternPreviewMode.beads,
        paletteEntries: data.paletteEntries,
      );
    }
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 38,
        color: Color(0xFFB7AEB7),
      ),
    );
  }
}

class AdminSubmissionStatusBadge extends StatelessWidget {
  final AdminSubmissionStatus status;

  const AdminSubmissionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AdminSubmissionStatus.pending => const Color(0xFFB2751C),
      AdminSubmissionStatus.approved => const Color(0xFF257550),
      AdminSubmissionStatus.rejected => const Color(0xFFC6284A),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        child: Text(
          status.label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ReviewClosedHint extends StatelessWidget {
  final AdminSubmissionStatus status;

  const _ReviewClosedHint({required this.status});

  @override
  Widget build(BuildContext context) {
    final message = status == AdminSubmissionStatus.approved
        ? '该投稿已通过审核，如需撤回请到模板库下架对应模板。'
        : '该投稿已被驳回，无法再次审核。';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7EAF0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(message, style: const TextStyle(color: Color(0xFF6A4B59))),
      ),
    );
  }
}

class _ReviewMetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewMetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6A6470), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewLoadError extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;

  const _ReviewLoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: _ReviewPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFC6284A),
              ),
              const SizedBox(height: 12),
              const Text('投稿详情加载失败'),
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

class _ReviewPanel extends StatelessWidget {
  final Widget child;

  const _ReviewPanel({required this.child});

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

class _ReviewNotice extends StatelessWidget {
  final String message;

  const _ReviewNotice({required this.message});

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

class _ReviewSectionLabel extends StatelessWidget {
  final String label;

  const _ReviewSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: const Color(0xFF6A4B59),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ReviewPill extends StatelessWidget {
  final String label;

  const _ReviewPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7EAF0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8C3450),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
