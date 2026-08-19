import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/color_limit.dart';
import '../models/draft_project.dart';
import '../models/generated_pattern.dart';
import '../models/product_template.dart';
import '../services/api/api_models.dart';
import '../services/image_service.dart';
import '../services/palette_service.dart';
import '../services/pattern_generation_service.dart';
import '../widgets/pattern_preview.dart';
import 'admin_api.dart';
import 'admin_chart_import.dart';
import 'admin_pattern_editor.dart';
import 'admin_preview_exporter.dart';
import 'admin_submission_review.dart';
import 'admin_template_editor.dart';
import 'admin_widgets.dart';

enum _AdminSection { publish, chartImport, submissions, library, drafts }

enum _AdminMenuAction {
  publish,
  chartImport,
  submissions,
  library,
  drafts,
  logout,
}

/// Internal admin portal for publishing official bead templates.
class BoboBeadsAdminApp extends StatelessWidget {
  /// Test and preview injection point; production uses [AdminApi] by default.
  final AdminApi? api;

  /// Test injection point so a widget test can feed in a synthesized chart
  /// instead of going through the platform image picker.
  final ImageService? imageService;

  const BoboBeadsAdminApp({super.key, this.api, this.imageService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BoboBeads 模板后台',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Alimama FangYuanTi VF',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5E82),
          brightness: Brightness.light,
          surface: const Color(0xFFFFFBFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F2F7),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFE7DEE6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFE7DEE6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFFF6A8B), width: 1.5),
          ),
        ),
      ),
      home: _AdminPortal(api: api, imageService: imageService),
    );
  }
}

class _AdminPortal extends StatefulWidget {
  final AdminApi? api;
  final ImageService? imageService;

  const _AdminPortal({this.api, this.imageService});

  @override
  State<_AdminPortal> createState() => _AdminPortalState();
}

class _AdminPortalState extends State<_AdminPortal> {
  static const _colorLimits = <ColorLimit>[
    ColorLimit.eight,
    ColorLimit.sixteen,
    ColorLimit.twentyFour,
    ColorLimit.thirtyTwo,
    ColorLimit.unlimited,
  ];

  late final _api = widget.api ?? AdminApi();
  late final _imageService = widget.imageService ?? ImageService();
  final _paletteService = PaletteService();
  final _generator = PatternGenerationService(imageService: ImageService());
  final _previewExporter = const AdminPreviewExporter();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  Uint8List? _sourceImage;
  GeneratedPattern? _pattern;
  List<AdminCategory> _categories = const [];
  ProductTemplate _product = ProductTemplateCatalog.defaultTemplate;
  String _paletteId = 'mard221';
  ColorLimit _colorLimit = ColorLimit.twentyFour;
  int? _categoryId;
  int _difficulty = 1;
  _AdminSection _section = _AdminSection.publish;
  List<AdminTemplate> _templates = const [];
  List<AdminSubmission> _submissions = const [];
  List<AdminTemplateDraft> _drafts = const [];
  AdminSubmissionStatus? _submissionFilter = AdminSubmissionStatus.pending;
  int _submissionPage = 1;
  int _submissionTotal = 0;
  bool _submissionHasMore = false;
  bool _smoothing = true;
  bool _removeBackground = true;
  bool _patternFromImport = false;
  bool _loggingIn = false;
  bool _generating = false;
  bool _publishing = false;
  bool _savingDraft = false;
  bool _loadingTemplates = false;
  bool _loadingSubmissions = false;
  bool _loadingDrafts = false;
  bool _creatingCategory = false;
  bool _hasLoadedTemplates = false;
  bool _hasLoadedSubmissions = false;
  bool _hasLoadedDrafts = false;
  String? _unpublishingTemplateId;
  String? _reviewingSubmissionId;
  String? _busyDraftId;

  /// The draft backing the publish workspace, so repeated saves update one draft
  /// instead of filling the draft box with near-identical copies.
  String? _workspaceDraftId;
  String _workspaceDraftUpdatedAt = '';
  String? _error;
  String? _success;

  bool get _isBusy => _loggingIn || _generating || _publishing || _savingDraft;

  // An imported chart has no source photo behind it, so every generation
  // setting is meaningless for it — and each one nulls out `_pattern`, which
  // would silently discard the import.
  bool get _generationLocked => _isBusy || _patternFromImport;

  void _clearImportedPattern() {
    setState(() {
      _pattern = null;
      _patternFromImport = false;
      _error = null;
      _success = null;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _setError('请输入管理员账号和密码');
      return;
    }
    setState(() {
      _loggingIn = true;
      _error = null;
      _success = null;
    });
    try {
      await _api.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      final categories = await _api.listCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryId = categories.isEmpty ? null : categories.first.id;
        _section = _AdminSection.publish;
        _success = '已进入模板发布工作台';
      });
    } catch (error) {
      _setError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imageService.pickImage();
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _sourceImage = bytes;
        _pattern = null;
        _patternFromImport = false;
        // A new source photo is a new piece of work, so later draft saves must
        // not overwrite the draft the previous photo produced.
        _workspaceDraftId = null;
        _workspaceDraftUpdatedAt = '';
        _error = null;
        _success = null;
      });
    } catch (error) {
      _setError('选择图片失败：${_errorMessage(error)}');
    }
  }

  Future<void> _generatePattern() async {
    final sourceImage = _sourceImage;
    if (sourceImage == null) {
      _setError('请先选择一张素材图片');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
      _success = null;
    });
    try {
      final palette = await _paletteService.loadByName(_paletteId);
      final draft = DraftProject(
        originalImageBytes: sourceImage,
        croppedImageBytes: sourceImage,
        selectedTemplate: _product,
        paletteBrandId: _paletteId,
        colorLimit: _colorLimit,
        smoothingEnabled: _smoothing,
        removeBackground: _removeBackground,
      );
      final pattern = await _generator.generate(draft: draft, palette: palette);
      if (!mounted) return;
      setState(() {
        _pattern = pattern;
        _success = '图纸已生成，请确认后发布。';
      });
    } catch (error) {
      _setError('生成失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _publish() async {
    final pattern = _pattern;
    final categoryId = _categoryId;
    final title = _titleController.text.trim();
    if (pattern == null) {
      _setError('请先生成图纸');
      return;
    }
    if (categoryId == null) {
      _setError('请先在服务端创建至少一个模板分类');
      return;
    }
    if (title.isEmpty) {
      _setError('请填写模板标题');
      return;
    }
    setState(() {
      _publishing = true;
      _error = null;
      _success = null;
    });
    try {
      final thumbnailBytes = await _previewExporter.exportGalleryThumbnailPng(
        pattern,
      );
      final templateId = await _api.publishTemplate(
        idempotencyKey: 'admin-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        description: _descriptionController.text.trim(),
        categoryId: categoryId,
        tags: _tagsController.text.trim(),
        difficulty: _difficulty,
        patternData: PatternData.fromGeneratedPattern(pattern),
        thumbnailBytes: thumbnailBytes,
      );
      if (!mounted) return;
      setState(() {
        _success = '发布成功：模板 ID $templateId';
        // The draft was consumed by the publish, so a later save must start a
        // new one.
        _workspaceDraftId = null;
        _workspaceDraftUpdatedAt = '';
        _hasLoadedTemplates = false;
        _hasLoadedDrafts = false;
      });
    } catch (error) {
      _setError('发布失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// Parks the workspace pattern in the draft box.
  ///
  /// Only the pattern is required: the draft endpoints accept a blank title,
  /// category and difficulty on purpose, and the 358×358 thumbnail is skipped
  /// entirely so saving does not re-upload a PNG every time. Both are validated
  /// and generated at publish time instead.
  Future<void> _saveWorkspaceDraft() async {
    final pattern = _pattern;
    if (pattern == null) {
      _setError('请先生成图纸');
      return;
    }
    setState(() {
      _savingDraft = true;
      _error = null;
      _success = null;
    });
    try {
      final patternData = PatternData.fromGeneratedPattern(pattern);
      // The draft box can only show an uploaded thumbnail: the list response
      // omits patternData, so a draft saved without one renders blank.
      final thumbnail = await _previewExporter.exportGalleryThumbnailPng(
        pattern,
      );
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final tags = _tagsController.text.trim();
      final draftId = _workspaceDraftId;
      if (draftId == null) {
        final saved = await _api.createDraft(
          idempotencyKey: 'admin-draft-${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          description: description,
          categoryId: _categoryId ?? 0,
          tags: tags,
          difficulty: _difficulty,
          patternData: patternData,
          thumbnailBytes: thumbnail,
        );
        if (!mounted) return;
        setState(() {
          _workspaceDraftId = saved.draftId;
          _workspaceDraftUpdatedAt = saved.updatedAt;
        });
      } else {
        final updatedAt = await _api.updateDraft(
          draftId: draftId,
          baseUpdatedAt: _workspaceDraftUpdatedAt,
          title: title,
          description: description,
          categoryId: _categoryId ?? 0,
          tags: tags,
          difficulty: _difficulty,
          patternData: patternData,
          thumbnailBytes: thumbnail,
        );
        if (!mounted) return;
        setState(() => _workspaceDraftUpdatedAt = updatedAt);
      }
      if (!mounted) return;
      setState(() {
        _success = '已存入草稿箱，可在「草稿箱」继续编辑。';
        _hasLoadedDrafts = false;
      });
    } catch (error) {
      if (error is ApiException &&
          error.code == AdminDraftErrorCode.notFound &&
          _workspaceDraftId != null) {
        // Another operator published or deleted this draft; start a new one so
        // the operator's work is not stuck against a dead id.
        setState(() {
          _workspaceDraftId = null;
          _workspaceDraftUpdatedAt = '';
        });
        _setError('原草稿已被其他管理员处理，请再点一次「存入草稿箱」新建一份。');
        return;
      }
      _setError('保存草稿失败：${_draftErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  String _draftErrorMessage(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        AdminDraftErrorCode.conflict => '这份草稿已被其他管理员修改，请到草稿箱重新打开。',
        AdminDraftErrorCode.boxFull => '草稿箱已满（上限 200 份），请先清理再保存。',
        AdminDraftErrorCode.notPublishable => error.message,
        _ => error.message,
      };
    }
    return _errorMessage(error);
  }

  Future<void> _editPattern([
    AdminPatternEditingMode initialMode = AdminPatternEditingMode.brush,
  ]) async {
    final pattern = _pattern;
    if (pattern == null || _isBusy) return;
    final edited = await Navigator.of(context).push<GeneratedPattern>(
      MaterialPageRoute(
        builder: (_) =>
            AdminPatternEditorPage(pattern: pattern, initialMode: initialMode),
      ),
    );
    if (!mounted || edited == null) return;
    setState(() {
      _pattern = edited;
      _error = null;
      _success = '图纸编辑已保存，发布时会使用最新版本。';
    });
  }

  void _selectSection(_AdminSection section) {
    if (_section == section) return;
    setState(() {
      _section = section;
      _error = null;
      _success = null;
    });
    if (section == _AdminSection.library && !_hasLoadedTemplates) {
      _loadTemplates();
    }
    if (section == _AdminSection.submissions && !_hasLoadedSubmissions) {
      _loadSubmissions();
    }
    if (section == _AdminSection.drafts && !_hasLoadedDrafts) {
      _loadDrafts();
    }
  }

  Future<void> _loadDrafts() async {
    if (_loadingDrafts) return;
    setState(() {
      _loadingDrafts = true;
      _error = null;
    });
    try {
      final result = await _api.listDrafts();
      if (!mounted) return;
      setState(() {
        _drafts = result.drafts;
        _hasLoadedDrafts = true;
      });
    } catch (error) {
      _setError('加载草稿箱失败：${_draftErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _loadingDrafts = false);
    }
  }

  Future<void> _loadTemplates() async {
    if (_loadingTemplates) return;
    setState(() {
      _loadingTemplates = true;
      _error = null;
    });
    try {
      final templates = await _api.listTemplates();
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _hasLoadedTemplates = true;
      });
    } catch (error) {
      _setError('加载模板失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  /// Loads the review queue one page at a time; [append] backs the "load more"
  /// button so the archived tabs do not have to be fetched in full.
  Future<void> _loadSubmissions({bool append = false}) async {
    if (_loadingSubmissions) return;
    final page = append ? _submissionPage + 1 : 1;
    setState(() {
      _loadingSubmissions = true;
      _error = null;
    });
    try {
      final result = await _api.listSubmissions(
        status: _submissionFilter,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _submissions = append
            ? [..._submissions, ...result.submissions]
            : result.submissions;
        _submissionPage = page;
        _submissionTotal = result.total;
        _submissionHasMore = result.hasMore;
        _hasLoadedSubmissions = true;
      });
    } catch (error) {
      _setError('加载投稿失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _loadingSubmissions = false);
    }
  }

  void _selectSubmissionFilter(AdminSubmissionStatus? status) {
    if (_submissionFilter == status || _loadingSubmissions) return;
    setState(() {
      _submissionFilter = status;
      _submissions = const [];
      _submissionHasMore = false;
      _submissionTotal = 0;
      _error = null;
      _success = null;
    });
    _loadSubmissions();
  }

  Future<void> _openSubmissionReview(AdminSubmission submission) async {
    if (_isBusy || _reviewingSubmissionId != null) return;
    setState(() => _reviewingSubmissionId = submission.id);
    final result = await Navigator.of(context)
        .push<AdminSubmissionReviewResult>(
          MaterialPageRoute(
            builder: (_) => AdminSubmissionReviewPage(
              api: _api,
              submission: submission,
              categories: _categories,
            ),
          ),
        );
    if (!mounted) return;
    setState(() {
      _reviewingSubmissionId = null;
      if (result == null) return;
      _error = null;
      _success = switch (result.outcome) {
        AdminSubmissionReviewOutcome.approved =>
          '已通过「${submission.title}」，生成模板 ID ${result.templateId}',
        AdminSubmissionReviewOutcome.rejected => '已驳回「${submission.title}」',
      };
      // An approval adds an official template, so the library has to be
      // refetched the next time the operator opens it.
      if (result.outcome == AdminSubmissionReviewOutcome.approved) {
        _hasLoadedTemplates = false;
      }
    });
    if (result != null) await _loadSubmissions();
  }

  Future<void> _unpublishTemplate(AdminTemplate template) async {
    if (_unpublishingTemplateId != null) return;
    final reason = await _askUnpublishReason(template);
    if (!mounted || reason == null) return;
    setState(() {
      _unpublishingTemplateId = template.id;
      _error = null;
      _success = null;
    });
    try {
      await _api.unpublishTemplate(templateId: template.id, reason: reason);
      if (!mounted) return;
      setState(() {
        _templates = _templates
            .where((item) => item.id != template.id)
            .toList();
        _success = '已下架「${template.title}」';
      });
    } catch (error) {
      _setError('下架失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _unpublishingTemplateId = null);
    }
  }

  /// Opens the editor for a published template.
  ///
  /// When the template already has a draft the editor is pointed at that draft:
  /// `PUT /admin/templates/{id}` does not know about drafts, so editing the
  /// template directly would be silently overwritten the moment someone
  /// published the pending revision.
  Future<void> _openTemplateEditor(AdminTemplate template) async {
    if (_isBusy || _unpublishingTemplateId != null) return;
    await _openEditor(
      template: template,
      draftId: template.hasDraft && template.draftId.isNotEmpty
          ? template.draftId
          : null,
    );
  }

  Future<void> _openDraftEditor(AdminTemplateDraft draft) async {
    if (_isBusy || _busyDraftId != null) return;
    await _openEditor(draftId: draft.draftId);
  }

  Future<void> _openEditor({AdminTemplate? template, String? draftId}) async {
    final result = await Navigator.of(context).push<AdminTemplateEditorResult>(
      MaterialPageRoute(
        builder: (_) => AdminTemplateEditorPage(
          api: _api,
          template: template,
          draftId: draftId,
          categories: _categories,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _error = null;
      _success = switch (result.outcome) {
        AdminTemplateEditorOutcome.draftSaved => '已保存到草稿箱，线上版本未改动。',
        AdminTemplateEditorOutcome.published => '已发布：模板 ID ${result.templateId}',
        AdminTemplateEditorOutcome.draftDiscarded => '草稿已丢弃。',
        AdminTemplateEditorOutcome.draftMissing => '这份草稿已不存在，可能已被其他管理员发布或删除。',
      };
    });
    await _refreshAfterDraftChange();
  }

  /// Reloads both lists after a draft action, since publishing a draft changes
  /// the library and every draft action changes the `hasDraft` badges.
  Future<void> _refreshAfterDraftChange() async {
    try {
      final drafts = await _api.listDrafts();
      final templates = await _api.listTemplates();
      if (!mounted) return;
      setState(() {
        _drafts = drafts.drafts;
        _templates = templates;
        _hasLoadedDrafts = true;
        _hasLoadedTemplates = true;
      });
    } catch (error) {
      _setError('操作已完成，但刷新列表失败：${_draftErrorMessage(error)}');
    }
  }

  /// Publishes a draft straight from its card.
  ///
  /// The listing omits `patternData`, so the detail has to be fetched to build
  /// the 358×358 thumbnail the publish endpoint requires.
  Future<void> _publishDraft(AdminTemplateDraft draft) async {
    if (_isBusy || _busyDraftId != null) return;
    setState(() {
      _busyDraftId = draft.draftId;
      _error = null;
      _success = null;
    });
    try {
      final detail = await _api.getDraft(draft.draftId);
      final thumbnail = await _previewExporter.exportGalleryThumbnailPng(
        detail.patternData.toGeneratedPattern(),
      );
      final templateId = await _api.publishDraft(
        draftId: draft.draftId,
        idempotencyKey: 'admin-publish-${DateTime.now().microsecondsSinceEpoch}',
        baseUpdatedAt: detail.draft.updatedAt,
        thumbnailBytes: thumbnail,
      );
      if (!mounted) return;
      setState(() => _success = '已发布「${draft.displayTitle}」：模板 ID $templateId');
      await _refreshAfterDraftChange();
    } catch (error) {
      _setError('发布草稿失败：${_draftErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _busyDraftId = null);
    }
  }

  Future<void> _discardDraft(AdminTemplateDraft draft) async {
    if (_isBusy || _busyDraftId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('丢弃「${draft.displayTitle}」？'),
        content: Text(
          draft.isRevision ? '只会删除这份未发布的修订，线上模板保持不变。' : '草稿中的图纸和信息会被删除，无法恢复。',
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
      _busyDraftId = draft.draftId;
      _error = null;
      _success = null;
    });
    try {
      await _api.deleteDraft(draft.draftId);
      if (!mounted) return;
      setState(() {
        _drafts = _drafts
            .where((item) => item.draftId != draft.draftId)
            .toList();
        _success = '已丢弃「${draft.displayTitle}」';
        // The badge on the related template card is now stale.
        _hasLoadedTemplates = false;
      });
    } catch (error) {
      _setError('丢弃草稿失败：${_draftErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _busyDraftId = null);
    }
  }

  Future<void> _createCategory() async {
    if (_creatingCategory || _isBusy) return;
    final name = await _askCategoryName();
    if (!mounted || name == null) return;
    setState(() {
      _creatingCategory = true;
      _error = null;
      _success = null;
    });
    try {
      final category = await _api.createCategory(name: name);
      if (!mounted) return;
      setState(() {
        _categories = [..._categories, category];
        _categoryId = category.id;
        _success = '已创建分类「${category.name}」';
      });
    } catch (error) {
      _setError('创建分类失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _creatingCategory = false);
    }
  }

  Future<String?> _askCategoryName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建模板分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            final next = value.trim();
            if (next.isNotEmpty) Navigator.pop(context, next);
          },
          decoration: const InputDecoration(
            labelText: '分类名称',
            hintText: '例如：节日',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final next = controller.text.trim();
              if (next.isNotEmpty) Navigator.pop(context, next);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<String?> _askUnpublishReason(AdminTemplate template) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下架官方模板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「${template.title}」下架后将不再对客户端展示。'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '下架原因（可选）',
                hintText: '例如：内容需要修订',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC6284A),
            ),
            child: const Text('确认下架'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  void _logout() {
    setState(() {
      _api.logout();
      _categories = const [];
      _templates = const [];
      _submissions = const [];
      _submissionFilter = AdminSubmissionStatus.pending;
      _submissionPage = 1;
      _submissionTotal = 0;
      _submissionHasMore = false;
      _categoryId = null;
      _pattern = null;
      _patternFromImport = false;
      _sourceImage = null;
      _section = _AdminSection.publish;
      _hasLoadedTemplates = false;
      _hasLoadedSubmissions = false;
      _creatingCategory = false;
      _error = null;
      _success = null;
      _passwordController.clear();
    });
  }

  void _setError(String value) {
    if (!mounted) return;
    setState(() {
      _error = value;
      _success = null;
    });
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return _api.isAuthenticated
        ? _buildWorkspace(context)
        : _buildLogin(context);
  }

  Widget _buildLogin(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBFC),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x180E0A13),
                    blurRadius: 40,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: 30),
                    Text(
                      '官方模板发布后台',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text('仅供获授权的运营人员使用。'),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: '管理员账号'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      onSubmitted: (_) => _loggingIn ? null : _login(),
                      decoration: const InputDecoration(labelText: '密码'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      AdminNotice(message: _error!, isError: true),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loggingIn ? null : _login,
                      icon: _loggingIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(_loggingIn ? '正在验证…' : '进入工作台'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspace(BuildContext context) {
    final compactNavigation = MediaQuery.sizeOf(context).width < 800;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBFC),
        surfaceTintColor: Colors.transparent,
        title: compactNavigation
            ? Text(_sectionShortTitle)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandMark(compact: true),
                  const SizedBox(width: 12),
                  Text(_sectionTitle),
                ],
              ),
        actions: compactNavigation
            ? [
                PopupMenuButton<_AdminMenuAction>(
                  tooltip: '后台菜单',
                  onSelected: (action) {
                    switch (action) {
                      case _AdminMenuAction.publish:
                        _selectSection(_AdminSection.publish);
                      case _AdminMenuAction.chartImport:
                        _selectSection(_AdminSection.chartImport);
                      case _AdminMenuAction.submissions:
                        _selectSection(_AdminSection.submissions);
                      case _AdminMenuAction.library:
                        _selectSection(_AdminSection.library);
                      case _AdminMenuAction.drafts:
                        _selectSection(_AdminSection.drafts);
                      case _AdminMenuAction.logout:
                        _logout();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _AdminMenuAction.publish,
                      child: ListTile(
                        leading: Icon(Icons.publish_outlined),
                        title: Text('发布模板'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _AdminMenuAction.chartImport,
                      child: ListTile(
                        leading: Icon(Icons.grid_on_outlined),
                        title: Text('图纸导入'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _AdminMenuAction.submissions,
                      child: ListTile(
                        leading: Icon(Icons.fact_check_outlined),
                        title: Text('投稿审核'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _AdminMenuAction.library,
                      child: ListTile(
                        leading: Icon(Icons.view_module_outlined),
                        title: Text('模板库'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _AdminMenuAction.drafts,
                      child: ListTile(
                        leading: Icon(Icons.bookmarks_outlined),
                        title: Text('草稿箱'),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: _AdminMenuAction.logout,
                      child: ListTile(
                        leading: Icon(Icons.logout_rounded),
                        title: Text('退出登录'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
              ]
            : [
                _WorkspaceTab(
                  icon: Icons.publish_outlined,
                  label: '发布模板',
                  selected: _section == _AdminSection.publish,
                  onTap: () => _selectSection(_AdminSection.publish),
                ),
                _WorkspaceTab(
                  icon: Icons.grid_on_outlined,
                  label: '图纸导入',
                  selected: _section == _AdminSection.chartImport,
                  onTap: () => _selectSection(_AdminSection.chartImport),
                ),
                _WorkspaceTab(
                  icon: Icons.fact_check_outlined,
                  label: '投稿审核',
                  selected: _section == _AdminSection.submissions,
                  onTap: () => _selectSection(_AdminSection.submissions),
                ),
                _WorkspaceTab(
                  icon: Icons.view_module_outlined,
                  label: '模板库',
                  selected: _section == _AdminSection.library,
                  onTap: () => _selectSection(_AdminSection.library),
                ),
                _WorkspaceTab(
                  icon: Icons.bookmarks_outlined,
                  label: '草稿箱',
                  selected: _section == _AdminSection.drafts,
                  onTap: () => _selectSection(_AdminSection.drafts),
                ),
                const _ModeChip(),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _isBusy ? null : _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('退出'),
                ),
                const SizedBox(width: 12),
              ],
      ),
      body: switch (_section) {
        _AdminSection.publish => _buildPublishWorkspace(context),
        _AdminSection.chartImport => _buildChartImportWorkspace(context),
        _AdminSection.submissions => _buildSubmissionQueue(context),
        _AdminSection.library => _buildTemplateLibrary(context),
        _AdminSection.drafts => _buildDraftBox(context),
      },
    );
  }

  String get _sectionTitle => switch (_section) {
    _AdminSection.publish => '模板发布工作台',
    _AdminSection.chartImport => '现成图纸导入',
    _AdminSection.submissions => '用户投稿审核',
    _AdminSection.library => '官方模板库',
    _AdminSection.drafts => '草稿箱',
  };

  String get _sectionShortTitle => switch (_section) {
    _AdminSection.publish => '发布模板',
    _AdminSection.chartImport => '图纸导入',
    _AdminSection.submissions => '投稿审核',
    _AdminSection.library => '模板库',
    _AdminSection.drafts => '草稿箱',
  };

  Widget _buildChartImportWorkspace(BuildContext context) {
    return AdminChartImportPanel(
      imageService: _imageService,
      paletteService: _paletteService,
      onUse: (pattern) {
        setState(() {
          _pattern = pattern;
          _patternFromImport = true;
          _section = _AdminSection.publish;
          _error = null;
          _success = '图纸已导入，请填写信息后发布。';
        });
      },
    );
  }

  Widget _buildPublishWorkspace(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1000;
        final editor = _buildEditor(context, compact: compact);
        final preview = _buildPreview(context, compact: compact);
        return Column(
          children: [
            if (_error != null || _success != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AdminNotice(
                  message: _error ?? _success!,
                  isError: _error != null,
                ),
              ),
            Expanded(
              child: compact
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [editor, const SizedBox(height: 20), preview],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 350, child: editor),
                          const SizedBox(width: 20),
                          Expanded(child: preview),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditor(BuildContext context, {required bool compact}) {
    final contents = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '制作设置',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('上传素材，生成图纸，再发布为客户端官方模板。'),
        const SizedBox(height: 20),
        if (_patternFromImport && _pattern != null) ...[
          InputChip(
            key: const ValueKey('admin-import-badge'),
            avatar: const Icon(Icons.grid_on_outlined, size: 18),
            label: Text('来自图纸导入 · ${_pattern!.width}×${_pattern!.height}'),
            deleteIcon: const Icon(Icons.close_rounded, size: 18),
            deleteButtonTooltipMessage: '清除导入的图纸',
            onDeleted: _isBusy ? null : _clearImportedPattern,
            onPressed: null,
          ),
          const SizedBox(height: 6),
          const Text(
            '导入的图纸不需要重新生成，下方生成参数已锁定。清除后可恢复照片生成流程。',
            style: TextStyle(fontSize: 12, color: Color(0xFF8A6C79)),
          ),
          const SizedBox(height: 16),
        ],
        AdminSectionLabel(label: '素材图片'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isBusy ? null : _pickImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_sourceImage == null ? '选择图片' : '更换图片'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
        if (_sourceImage != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(_sourceImage!, fit: BoxFit.contain),
            ),
          ),
        ],
        const SizedBox(height: 20),
        AdminSectionLabel(label: '图纸规格'),
        const SizedBox(height: 8),
        DropdownButtonFormField<ProductTemplate>(
          initialValue: _product,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '成品规格'),
          items: ProductTemplateCatalog.templates
              .where((template) => !template.custom)
              .map(
                (template) => DropdownMenuItem(
                  value: template,
                  child: Text(
                    '${template.name} · ${template.beadWidth}×${template.beadHeight}',
                  ),
                ),
              )
              .toList(),
          onChanged: _generationLocked
              ? null
              : (value) => setState(() {
                  _product = value ?? _product;
                  _pattern = null;
                }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _paletteId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '拼豆色卡'),
          items: _paletteService.availablePalettes
              .map(
                (palette) => DropdownMenuItem(
                  value: palette.id,
                  child: Text(palette.displayName),
                ),
              )
              .toList(),
          onChanged: _generationLocked
              ? null
              : (value) => setState(() {
                  _paletteId = value ?? _paletteId;
                  _pattern = null;
                }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ColorLimit>(
          initialValue: _colorLimit,
          decoration: const InputDecoration(labelText: '颜色数量上限'),
          items: _colorLimits
              .map(
                (limit) => DropdownMenuItem(
                  value: limit,
                  child: Text(
                    limit == ColorLimit.unlimited ? '不限颜色' : '${limit.label} 色',
                  ),
                ),
              )
              .toList(),
          onChanged: _generationLocked
              ? null
              : (value) => setState(() {
                  _colorLimit = value ?? _colorLimit;
                  _pattern = null;
                }),
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          key: const ValueKey('admin-remove-background-toggle'),
          contentPadding: EdgeInsets.zero,
          value: _removeBackground,
          onChanged: _generationLocked
              ? null
              : (value) => setState(() {
                  _removeBackground = value;
                  _pattern = null;
                }),
          title: const Text('去背景'),
          subtitle: const Text('生成图纸时移除图片背景，保留主体轮廓'),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _smoothing,
          onChanged: _generationLocked
              ? null
              : (value) => setState(() {
                  _smoothing = value;
                  _pattern = null;
                }),
          title: const Text('平滑过渡'),
          subtitle: const Text('保留现有客户端的抖动算法'),
        ),
        FilledButton.icon(
          onPressed: _generationLocked ? null : _generatePattern,
          icon: _generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_generating ? '正在生成…' : '生成拼豆图纸'),
        ),
        if (_pattern != null) ...[
          const SizedBox(height: 14),
          Text(
            '图纸编辑',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('admin-open-brush-editor'),
                onPressed: _isBusy
                    ? null
                    : () => _editPattern(AdminPatternEditingMode.brush),
                icon: const Icon(Icons.brush_outlined),
                label: const Text('画笔模式'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('admin-open-palette-editor'),
                onPressed: _isBusy
                    ? null
                    : () => _editPattern(AdminPatternEditingMode.palette),
                icon: const Icon(Icons.palette_outlined),
                label: const Text('色板模式'),
              ),
            ],
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Divider(),
        ),
        AdminSectionLabel(label: '发布信息'),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          enabled: !_isBusy,
          maxLength: 80,
          decoration: const InputDecoration(labelText: '模板标题 *'),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '客户端分类 *'),
                hint: const Text('请选择分类'),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          '${category.name}（${category.templateCount}）',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isBusy
                    ? null
                    : (value) => setState(() => _categoryId = value),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _creatingCategory || _isBusy
                    ? null
                    : _createCategory,
                child: _creatingCategory
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _difficulty,
          decoration: const InputDecoration(labelText: '难度'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('入门')),
            DropdownMenuItem(value: 2, child: Text('进阶')),
            DropdownMenuItem(value: 3, child: Text('挑战')),
          ],
          onChanged: _isBusy
              ? null
              : (value) => setState(() => _difficulty = value ?? 1),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tagsController,
          enabled: !_isBusy,
          decoration: const InputDecoration(
            labelText: '标签',
            hintText: '例如：动物, 礼物, 入门',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          enabled: !_isBusy,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(labelText: '模板说明'),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          key: const ValueKey('admin-save-draft'),
          onPressed: _isBusy ? null : _saveWorkspaceDraft,
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
                : _workspaceDraftId == null
                ? '存入草稿箱'
                : '更新草稿箱中的这份',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _isBusy ? null : _publish,
          icon: _publishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.publish_rounded),
          label: Text(_publishing ? '正在发布…' : '发布为官方模板'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF4F79),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
    return AdminPanel(
      child: compact ? contents : SingleChildScrollView(child: contents),
    );
  }

  Widget _buildPreview(BuildContext context, {required bool compact}) {
    final pattern = _pattern;
    return AdminPanel(
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
                    Text(pattern == null ? '先选择图片并生成图纸' : '可缩放检查每颗豆子的编号和颜色'),
                  ],
                ),
              ),
              if (pattern != null)
                _StatPill(label: '${pattern.width}×${pattern.height}'),
            ],
          ),
          const SizedBox(height: 18),
          if (pattern == null)
            _PreviewArea(
              compact: compact,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 56,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 12),
                    const Text('生成后的拼豆图纸会显示在这里'),
                  ],
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatPill(label: '${pattern.totalBeads} 颗豆子'),
                _StatPill(label: '${pattern.usage.length} 种颜色'),
                _StatPill(label: _product.name),
              ],
            ),
            const SizedBox(height: 14),
            _PreviewArea(
              compact: compact,
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
            const SizedBox(height: 12),
            const Text(
              '发布后，客户端展示的预览图和实际数据均来自同一份图纸结构。',
              style: TextStyle(color: Color(0xFF6A6470)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmissionQueue(BuildContext context) {
    if (_loadingSubmissions && !_hasLoadedSubmissions) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadSubmissions,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '用户投稿',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _submissionTotal > 0
                          ? '共 $_submissionTotal 条投稿，通过后会生成官方模板。'
                          : '通过后会生成官方模板，驳回需要填写原因。',
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loadingSubmissions ? null : _loadSubmissions,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const <AdminSubmissionStatus?>[
                AdminSubmissionStatus.pending,
                AdminSubmissionStatus.approved,
                AdminSubmissionStatus.rejected,
                null,
              ])
                ChoiceChip(
                  key: ValueKey(
                    'submission-filter-${option?.wireName ?? 'all'}',
                  ),
                  label: Text(option?.label ?? '全部'),
                  selected: _submissionFilter == option,
                  onSelected: _loadingSubmissions
                      ? null
                      : (_) => _selectSubmissionFilter(option),
                ),
            ],
          ),
          if (_error != null || _success != null) ...[
            const SizedBox(height: 16),
            AdminNotice(message: _error ?? _success!, isError: _error != null),
          ],
          const SizedBox(height: 20),
          if (_submissions.isEmpty)
            const _EmptySubmissionQueue()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 1080
                    ? 3
                    : constraints.maxWidth >= 720
                    ? 2
                    : 1;
                final width = (constraints.maxWidth - (count - 1) * 16) / count;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final submission in _submissions)
                      SizedBox(
                        width: width,
                        child: _SubmissionCard(
                          submission: submission,
                          isOpening: _reviewingSubmissionId == submission.id,
                          onReview: () => _openSubmissionReview(submission),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (_submissionHasMore) ...[
            const SizedBox(height: 20),
            Center(
              child: OutlinedButton.icon(
                onPressed: _loadingSubmissions
                    ? null
                    : () => _loadSubmissions(append: true),
                icon: _loadingSubmissions
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(_loadingSubmissions ? '加载中…' : '加载更多'),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTemplateLibrary(BuildContext context) {
    if (_loadingTemplates && !_hasLoadedTemplates) {
      return const Center(child: CircularProgressIndicator());
    }

    final groups = _templateGroups();
    return RefreshIndicator(
      onRefresh: _loadTemplates,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已发布模板',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('共 ${_templates.length} 个模板，按客户端分类展示。'),
                  ],
                ),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loadingTemplates ? null : _loadTemplates,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _creatingCategory || _isBusy
                    ? null
                    : _createCategory,
                icon: _creatingCategory
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.create_new_folder_outlined),
                label: const Text('新建分类'),
              ),
            ],
          ),
          if (_error != null || _success != null) ...[
            const SizedBox(height: 16),
            AdminNotice(message: _error ?? _success!, isError: _error != null),
          ],
          const SizedBox(height: 20),
          if (groups.isEmpty)
            const _EmptyTemplateLibrary()
          else
            for (final group in groups) ...[
              _LibrarySectionHeader(group: group),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final count = constraints.maxWidth >= 1080
                      ? 3
                      : constraints.maxWidth >= 720
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (count - 1) * 16) / count;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final template in group.templates)
                        SizedBox(
                          width: width,
                          child: _TemplateLibraryCard(
                            template: template,
                            isUnpublishing:
                                _unpublishingTemplateId == template.id,
                            onEdit: () => _openTemplateEditor(template),
                            onUnpublish: () => _unpublishTemplate(template),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
            ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDraftBox(BuildContext context) {
    if (_loadingDrafts && !_hasLoadedDrafts) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadDrafts,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '草稿箱',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('共 ${_drafts.length} 份草稿，全部管理员可见可编辑，未发布不影响用户端。'),
                  ],
                ),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loadingDrafts ? null : _loadDrafts,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_error != null || _success != null) ...[
            const SizedBox(height: 16),
            AdminNotice(message: _error ?? _success!, isError: _error != null),
          ],
          const SizedBox(height: 20),
          if (_drafts.isEmpty)
            const _EmptyDraftBox()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 1080
                    ? 3
                    : constraints.maxWidth >= 720
                    ? 2
                    : 1;
                final width = (constraints.maxWidth - (count - 1) * 16) / count;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final draft in _drafts)
                      SizedBox(
                        width: width,
                        child: _DraftCard(
                          api: _api,
                          draft: draft,
                          isBusy: _busyDraftId == draft.draftId,
                          onEdit: () => _openDraftEditor(draft),
                          onPublish: () => _publishDraft(draft),
                          onDiscard: () => _discardDraft(draft),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<_TemplateGroup> _templateGroups() {
    final groups = <_TemplateGroup>[];
    final assignedIds = <String>{};
    for (final category in _categories) {
      final templates = _templates
          .where((template) => template.categoryId == category.id)
          .toList();
      if (templates.isEmpty) continue;
      assignedIds.addAll(templates.map((template) => template.id));
      groups.add(_TemplateGroup(name: category.name, templates: templates));
    }
    final remaining = _templates
        .where((template) => !assignedIds.contains(template.id))
        .toList();
    final byName = <String, List<AdminTemplate>>{};
    for (final template in remaining) {
      final name = template.categoryName.isNotEmpty
          ? template.categoryName
          : '未分类';
      byName.putIfAbsent(name, () => []).add(template);
    }
    byName.forEach((name, templates) {
      groups.add(_TemplateGroup(name: name, templates: templates));
    });
    return groups;
  }
}

class _PreviewArea extends StatelessWidget {
  final bool compact;
  final Widget child;

  const _PreviewArea({required this.compact, required this.child});

  @override
  Widget build(BuildContext context) {
    return compact
        ? SizedBox(height: 460, child: child)
        : Expanded(child: child);
  }
}

class _WorkspaceTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? const Color(0xFF8C3450)
              : const Color(0xFF6A6470),
          backgroundColor: selected ? const Color(0xFFF7EAF0) : null,
        ),
      ),
    );
  }
}

class _TemplateGroup {
  final String name;
  final List<AdminTemplate> templates;

  const _TemplateGroup({required this.name, required this.templates});
}

class _LibrarySectionHeader extends StatelessWidget {
  final _TemplateGroup group;

  const _LibrarySectionHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          group.name,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        _StatPill(label: '${group.templates.length} 个'),
      ],
    );
  }
}

class _EmptyTemplateLibrary extends StatelessWidget {
  const _EmptyTemplateLibrary();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        border: Border.all(color: const Color(0xFFECE3EA)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 72, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFB7AEB7)),
            SizedBox(height: 12),
            Text('暂时没有已发布模板'),
            SizedBox(height: 4),
            Text('完成发布后会按客户端分类显示在这里。'),
          ],
        ),
      ),
    );
  }
}

class _EmptyDraftBox extends StatelessWidget {
  const _EmptyDraftBox();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        border: Border.all(color: const Color(0xFFECE3EA)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 72, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.bookmarks_outlined, size: 48, color: Color(0xFFB7AEB7)),
            SizedBox(height: 12),
            Text('草稿箱是空的'),
            SizedBox(height: 4),
            Text('在发布工作台或模板库里保存草稿，就会出现在这里。'),
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final AdminApi api;
  final AdminTemplateDraft draft;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onDiscard;

  const _DraftCard({
    required this.api,
    required this.draft,
    required this.isBusy,
    required this.onEdit,
    required this.onPublish,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        border: Border.all(color: const Color(0xFFECE3EA)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isBusy ? null : onEdit,
                borderRadius: BorderRadius.circular(12),
                child: _DraftThumbnail(api: api, draft: draft),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    draft.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _DraftKindBadge(isRevision: draft.isRevision),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (draft.width > 0 && draft.height > 0)
                  _CardMeta(label: '${draft.width}×${draft.height}'),
                if (draft.colorCount > 0)
                  _CardMeta(label: '${draft.colorCount} 色'),
                if (draft.categoryName.isNotEmpty)
                  _CardMeta(label: draft.categoryName),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _lastEditedLine(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6A6470), fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('继续编辑'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onPublish,
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.publish_outlined, size: 18),
                    label: Text(isBusy ? '处理中…' : '发布'),
                  ),
                ),
                IconButton(
                  onPressed: isBusy ? null : onDiscard,
                  tooltip: '丢弃草稿',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: const Color(0xFFC6284A),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _lastEditedLine() {
    final actor = draft.updatedByActor.isEmpty ? '未知管理员' : draft.updatedByActor;
    final at = formatAdminTimestamp(DateTime.tryParse(draft.updatedAt));
    return '$actor 于 $at 修改';
  }
}

/// Shows the draft's uploaded thumbnail, falling back to a local render.
///
/// The fallback costs one detail request per card, so it only runs for drafts
/// saved before the thumbnail upload existed: the list response omits
/// `patternData`, and fetching it for every card would restore exactly the
/// payload the endpoint drops.
class _DraftThumbnail extends StatefulWidget {
  final AdminApi api;
  final AdminTemplateDraft draft;

  const _DraftThumbnail({required this.api, required this.draft});

  @override
  State<_DraftThumbnail> createState() => _DraftThumbnailState();
}

class _DraftThumbnailState extends State<_DraftThumbnail> {
  PatternData? _patternData;

  @override
  void initState() {
    super.initState();
    if (widget.draft.thumbnailUrl.isEmpty) _loadPattern();
  }

  Future<void> _loadPattern() async {
    try {
      final detail = await widget.api.getDraft(widget.draft.draftId);
      if (!mounted) return;
      setState(() => _patternData = detail.patternData);
    } catch (_) {
      // The placeholder already communicates that there is no preview.
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TemplatePreview(
      url: widget.draft.thumbnailUrl,
      patternData: _patternData,
    );
  }
}

class _DraftPendingBadge extends StatelessWidget {
  const _DraftPendingBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2DC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          '有草稿',
          style: TextStyle(
            color: Color(0xFF8A5A11),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DraftKindBadge extends StatelessWidget {
  final bool isRevision;

  const _DraftKindBadge({required this.isRevision});

  @override
  Widget build(BuildContext context) {
    final color = isRevision ? const Color(0xFF8C3450) : const Color(0xFF2F6E4F);
    final background = isRevision
        ? const Color(0xFFF7EAF0)
        : const Color(0xFFE6F3EB);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          isRevision ? '模板修订' : '新图纸',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptySubmissionQueue extends StatelessWidget {
  const _EmptySubmissionQueue();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        border: Border.all(color: const Color(0xFFECE3EA)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 72, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.fact_check_outlined, size: 48, color: Color(0xFFB7AEB7)),
            SizedBox(height: 12),
            Text('当前筛选条件下没有投稿'),
            SizedBox(height: 4),
            Text('用户把作品投稿为模板后会出现在这里。'),
          ],
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final AdminSubmission submission;
  final bool isOpening;
  final VoidCallback onReview;

  const _SubmissionCard({
    required this.submission,
    required this.isOpening,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = submission.status == AdminSubmissionStatus.pending;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        border: Border.all(color: const Color(0xFFECE3EA)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isOpening ? null : onReview,
                borderRadius: BorderRadius.circular(12),
                child: _SubmissionPreview(url: submission.imageUrl),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    submission.title.isEmpty ? '未命名投稿' : submission.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AdminSubmissionStatusBadge(status: submission.status),
              ],
            ),
            if (submission.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                submission.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6A6470)),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (submission.width > 0 && submission.height > 0)
                  _CardMeta(label: '${submission.width}×${submission.height}'),
                if (submission.beadCount > 0)
                  _CardMeta(label: '${submission.beadCount} 颗'),
                if (submission.colorCount > 0)
                  _CardMeta(label: '${submission.colorCount} 色'),
                _CardMeta(label: formatAdminTimestamp(submission.createdAt)),
              ],
            ),
            if (submission.reviewReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '审核意见：${submission.reviewReason}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFC6284A), fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: isOpening ? null : onReview,
              icon: isOpening
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isPending
                          ? Icons.rate_review_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
              label: Text(isPending ? '审核' : '查看详情'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionPreview extends StatelessWidget {
  final String url;

  const _SubmissionPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFFF7F7FA),
          child: url.isEmpty
              ? const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 38,
                    color: Color(0xFFB7AEB7),
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  // Submission previews live on OSS. Prefer a native HTML image
                  // on Web so previews remain visible while the bucket CORS
                  // policy is being corrected.
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 38,
                      color: Color(0xFFB7AEB7),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TemplateLibraryCard extends StatelessWidget {
  final AdminTemplate template;
  final bool isUnpublishing;
  final VoidCallback onEdit;
  final VoidCallback onUnpublish;

  const _TemplateLibraryCard({
    required this.template,
    required this.isUnpublishing,
    required this.onEdit,
    required this.onUnpublish,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        border: Border.all(color: const Color(0xFFECE3EA)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isUnpublishing ? null : onEdit,
                borderRadius: BorderRadius.circular(12),
                child: _TemplatePreview(
                  url: template.imageUrl,
                  patternData: template.patternData,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (template.hasDraft) ...[
                  const SizedBox(width: 8),
                  const _DraftPendingBadge(),
                ],
              ],
            ),
            if (template.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                template.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6A6470)),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (template.width > 0 && template.height > 0)
                  _CardMeta(label: '${template.width}×${template.height}'),
                if (template.colorCount > 0)
                  _CardMeta(label: '${template.colorCount} 色'),
                if (template.difficulty > 0)
                  _CardMeta(label: _difficultyLabel(template.difficulty)),
                for (final tag in template.tags.take(2)) _CardMeta(label: tag),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isUnpublishing ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(template.hasDraft ? '编辑草稿' : '编辑'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUnpublishing ? null : onUnpublish,
                    icon: isUnpublishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.remove_circle_outline, size: 18),
                    label: Text(isUnpublishing ? '下架中…' : '下架'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC6284A),
                      side: const BorderSide(color: Color(0xFFE4AFBA)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _difficultyLabel(int difficulty) {
    return switch (difficulty) {
      1 => '入门',
      2 => '进阶',
      3 => '挑战',
      _ => '难度 $difficulty',
    };
  }
}

class _TemplatePreview extends StatelessWidget {
  final String url;
  final PatternData? patternData;

  const _TemplatePreview({required this.url, this.patternData});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFFF7F7FA),
          child: url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.contain,
                  // Official previews live on OSS. Prefer a native HTML image
                  // on Web so previews remain visible while the bucket CORS
                  // policy is being corrected.
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 38,
                      color: Color(0xFFB7AEB7),
                    ),
                  ),
                )
              : _chartFallback(),
        ),
      ),
    );
  }

  Widget _chartFallback() {
    final data = patternData;
    if (data != null) {
      try {
        final pattern = data.toGeneratedPattern();
        return PatternPreview(
          pixels: pattern.pixels,
          width: pattern.width,
          height: pattern.height,
          showGrid: false,
          mode: PatternPreviewMode.beads,
          paletteEntries: pattern.paletteEntries,
        );
      } catch (_) {
        // A malformed optional list payload should not hide the template card.
      }
    }
    return const Center(
      child: Icon(Icons.grid_view_rounded, size: 42, color: Color(0xFFB7AEB7)),
    );
  }
}

class _CardMeta extends StatelessWidget {
  final String label;

  const _CardMeta({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7EAF0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8C3450),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;

  const _StatPill({required this.label});

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

class _ModeChip extends StatelessWidget {
  const _ModeChip();

  @override
  Widget build(BuildContext context) {
    return const _StatPill(label: '管理员');
  }
}

class _BrandMark extends StatelessWidget {
  final bool compact;

  const _BrandMark({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 30 : 42,
          height: compact ? 30 : 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF4F79),
            borderRadius: BorderRadius.circular(compact ? 9 : 13),
          ),
          child: Text(
            'B',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Z Labs RoundPix 12px M CN',
              fontSize: compact ? 19 : 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          const Text(
            'BoboBeads',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ],
    );
  }
}
