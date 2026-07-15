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
import 'admin_preview_exporter.dart';

class BoboBeadsAdminApp extends StatelessWidget {
  const BoboBeadsAdminApp({super.key});

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
      home: const _AdminPortal(),
    );
  }
}

class _AdminPortal extends StatefulWidget {
  const _AdminPortal();

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

  final _api = AdminApi();
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
  String _paletteId = 'hama';
  ColorLimit _colorLimit = ColorLimit.twentyFour;
  int? _categoryId;
  int _difficulty = 1;
  bool _smoothing = true;
  bool _loggingIn = false;
  bool _generating = false;
  bool _publishing = false;
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
      final previewBytes = await _previewExporter.exportChartPng(pattern);
      final templateId = await _api.publishTemplate(
        idempotencyKey: 'admin-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        description: _descriptionController.text.trim(),
        categoryId: categoryId,
        tags: _tagsController.text.trim(),
        difficulty: _difficulty,
        patternData: PatternData.fromGeneratedPattern(pattern),
        previewBytes: previewBytes,
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

  void _logout() {
    setState(() {
      _api.logout();
      _categories = const [];
      _categoryId = null;
      _pattern = null;
      _sourceImage = null;
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBFC),
        surfaceTintColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandMark(compact: true),
            SizedBox(width: 12),
            Text('模板发布工作台'),
          ],
        ),
        actions: [
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
      body: LayoutBuilder(
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
      ),
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
        DropdownButtonFormField<int>(
          initialValue: _categoryId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '客户端分类 *'),
          hint: const Text('请选择分类'),
          items: _categories
              .map(
                (category) => DropdownMenuItem(
                  value: category.id,
                  child: Text('${category.name}（${category.templateCount}）'),
                ),
              )
              .toList(),
          onChanged: _isBusy
              ? null
              : (value) => setState(() => _categoryId = value),
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
