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
import 'admin_pattern_editor.dart';
import 'admin_preview_exporter.dart';
import 'admin_template_editor.dart';

enum _AdminSection { publish, library }

enum _AdminMenuAction { publish, library, logout }

/// Internal admin portal for publishing official bead templates.
class BoboBeadsAdminApp extends StatelessWidget {
  /// Test and preview injection point; production uses [AdminApi] by default.
  final AdminApi? api;

  const BoboBeadsAdminApp({super.key, this.api});

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
      home: _AdminPortal(api: api),
    );
  }
}

class _AdminPortal extends StatefulWidget {
  final AdminApi? api;

  const _AdminPortal({this.api});

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
  final _imageService = ImageService();
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
  bool _smoothing = true;
  bool _removeBackground = true;
  bool _loggingIn = false;
  bool _generating = false;
  bool _publishing = false;
  bool _loadingTemplates = false;
  bool _creatingCategory = false;
  bool _hasLoadedTemplates = false;
  String? _unpublishingTemplateId;
  String? _error;
  String? _success;

  bool get _isBusy => _loggingIn || _generating || _publishing;

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
      });
    } catch (error) {
      _setError('发布失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _editPattern() async {
    final pattern = _pattern;
    if (pattern == null || _isBusy) return;
    final edited = await Navigator.of(context).push<GeneratedPattern>(
      MaterialPageRoute(
        builder: (_) => AdminPatternEditorPage(pattern: pattern),
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

  Future<void> _openTemplateEditor(AdminTemplate template) async {
    if (_isBusy || _unpublishingTemplateId != null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminTemplateEditorPage(
          api: _api,
          template: template,
          categories: _categories,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    try {
      final categories = await _api.listCategories();
      final templates = await _api.listTemplates();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _templates = templates;
        _success = '模板修改已保存';
        _error = null;
      });
    } catch (error) {
      _setError('模板已保存，但刷新列表失败：${_errorMessage(error)}');
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
      _categoryId = null;
      _pattern = null;
      _sourceImage = null;
      _section = _AdminSection.publish;
      _hasLoadedTemplates = false;
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
                      _Notice(message: _error!, isError: true),
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
            ? Text(_section == _AdminSection.publish ? '发布模板' : '模板库')
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandMark(compact: true),
                  const SizedBox(width: 12),
                  Text(_section == _AdminSection.publish ? '模板发布工作台' : '官方模板库'),
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
                      case _AdminMenuAction.library:
                        _selectSection(_AdminSection.library);
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
                      value: _AdminMenuAction.library,
                      child: ListTile(
                        leading: Icon(Icons.view_module_outlined),
                        title: Text('模板库'),
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
                  icon: Icons.view_module_outlined,
                  label: '模板库',
                  selected: _section == _AdminSection.library,
                  onTap: () => _selectSection(_AdminSection.library),
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
      body: _section == _AdminSection.library
          ? _buildTemplateLibrary(context)
          : _buildPublishWorkspace(context),
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
                child: _Notice(
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
        _SectionLabel(label: '素材图片'),
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
        _SectionLabel(label: '图纸规格'),
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
          onChanged: _isBusy
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
          onChanged: _isBusy
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
          onChanged: _isBusy
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
          onChanged: _isBusy
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
          onChanged: _isBusy
              ? null
              : (value) => setState(() {
                  _smoothing = value;
                  _pattern = null;
                }),
          title: const Text('平滑过渡'),
          subtitle: const Text('保留现有客户端的抖动算法'),
        ),
        FilledButton.icon(
          onPressed: _isBusy ? null : _generatePattern,
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
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _editPattern,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('进入拼豆模式编辑'),
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Divider(),
        ),
        _SectionLabel(label: '发布信息'),
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
    return _Panel(
      child: compact ? contents : SingleChildScrollView(child: contents),
    );
  }

  Widget _buildPreview(BuildContext context, {required bool compact}) {
    final pattern = _pattern;
    return _Panel(
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
            _Notice(message: _error ?? _success!, isError: _error != null),
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

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE3EA)),
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
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
            Text(
              template.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
                    label: const Text('编辑'),
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

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

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

class _Notice extends StatelessWidget {
  final String message;
  final bool isError;

  const _Notice({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFC6284A) : const Color(0xFF257550);
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
