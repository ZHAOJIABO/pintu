import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/color_limit.dart';
import '../models/draft_project.dart';
import '../models/product_template.dart';
import '../services/api/api_scope.dart';
import '../services/image_service.dart';
import '../services/palette_service.dart';
import '../services/pattern_generation_service.dart';
import '../services/project_storage_service.dart';
import 'result_screen.dart';

const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _pageBackground = Color(0xFFEEF0F6);
const _controlBackground = Color(0xFFEEF0F6);
const _switchTrack = Color(0xFFDEE2ED);
const _loadingRabbitIconAsset = 'assets/figma_style/loading_rabbit_icon.png';
const _brandUnlimitedValue = '__unlimited__';
const _saturationMin = 0;
const _saturationMax = 100;

const _sizeOptions = <ProductTemplate>[
  ProductTemplate(
    id: 'figma_small_charm',
    name: '小鼻嘎',
    subtitle: '10',
    physicalSizeCm: null,
    beadWidth: 10,
    beadHeight: 10,
    defaultAspectRatio: CropAspectRatio.square,
  ),
  ProductTemplate(
    id: 'figma_keychain',
    name: '钥匙扣',
    subtitle: '30',
    physicalSizeCm: null,
    beadWidth: 30,
    beadHeight: 30,
    defaultAspectRatio: CropAspectRatio.square,
  ),
  ProductTemplate(
    id: 'figma_card_holder',
    name: '卡套',
    subtitle: '50',
    physicalSizeCm: null,
    beadWidth: 50,
    beadHeight: 50,
    defaultAspectRatio: CropAspectRatio.square,
  ),
  ProductTemplate(
    id: 'figma_custom',
    name: '自定义',
    subtitle: 'X',
    physicalSizeCm: null,
    beadWidth: 150,
    beadHeight: 150,
    defaultAspectRatio: CropAspectRatio.freeform,
    custom: true,
  ),
];

const _colorLimitOptions = <ColorLimit>[
  ColorLimit.eight,
  ColorLimit.sixteen,
  ColorLimit.twentyFour,
  ColorLimit.thirtyTwo,
  ColorLimit.unlimited,
];

class ParameterConfigScreen extends StatefulWidget {
  final DraftProject draft;

  const ParameterConfigScreen({super.key, required this.draft});

  @override
  State<ParameterConfigScreen> createState() => _ParameterConfigScreenState();
}

class _ParameterConfigScreenState extends State<ParameterConfigScreen> {
  final PaletteService _paletteService = PaletteService();
  final ProjectStorageService _projectStorageService = ProjectStorageService();
  late final PatternGenerationService _generationService =
      PatternGenerationService(imageService: ImageService());

  late final Uint8List _previewImage = widget.draft.imageForGeneration;
  late final double _previewAspectRatio = _decodeImageAspectRatio(
    _previewImage,
  );
  late ProductTemplate _selectedTemplate = _initialTemplate();
  late int _customSize = _initialCustomSize();
  late String? _brandId = widget.draft.paletteBrandId;
  late ColorLimit _limit = widget.draft.colorLimit;
  late bool _smoothing = widget.draft.smoothingEnabled;
  bool _removeBackground = true;
  bool _denoise = false;
  int _saturation = 100;
  bool _generating = false;
  bool _serverAttemptStarted = false;

  ProductTemplate get _customTemplate =>
      _sizeOptions.firstWhere((template) => template.custom);

  int get _customWidth => _customSize;

  int get _customHeight => _customSize;

  bool get _customValid =>
      ProductTemplateCatalog.isValidCustomDimension(_customSize);

  String? get _effectiveBrandId {
    if (_brandId != null) return _brandId;
    final palettes = _paletteService.availablePalettes;
    return palettes.isEmpty ? null : palettes.first.id;
  }

  bool get _canGenerate =>
      !_generating &&
      (!_selectedTemplate.custom || _customValid) &&
      _effectiveBrandId != null;

  double _decodeImageAspectRatio(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.height == 0) return 1;
    return decoded.width / decoded.height;
  }

  int _initialCustomSize() {
    final value =
        widget.draft.customBeadWidth ??
        widget.draft.customBeadHeight ??
        _customTemplate.beadWidth;
    return value
        .clamp(
          ProductTemplateCatalog.minCustomBeads,
          ProductTemplateCatalog.maxCustomBeads,
        )
        .toInt();
  }

  int _clampSaturation(int value) =>
      value.clamp(_saturationMin, _saturationMax).toInt();

  ProductTemplate _initialTemplate() {
    final selected = widget.draft.selectedTemplate;
    if (selected?.custom == true) return _customTemplate;
    if (selected == null) {
      return _sizeOptions.firstWhere((template) => template.name == '钥匙扣');
    }

    return _sizeOptions.firstWhere(
      (template) =>
          template.name == selected.name || template.id == selected.id,
      orElse: () =>
          _sizeOptions.firstWhere((template) => template.name == '钥匙扣'),
    );
  }

  Future<void> _generate() async {
    if (_generating) return;
    final brandId = _effectiveBrandId;
    if (brandId == null) return;

    final nextDraft = widget.draft.copyWith(
      selectedTemplate: _selectedTemplate,
      customBeadWidth: _selectedTemplate.custom ? _customWidth : null,
      customBeadHeight: _selectedTemplate.custom ? _customHeight : null,
      paletteBrandId: brandId,
      colorLimit: _limit,
      smoothingEnabled: _smoothing,
    );

    setState(() => _generating = true);

    try {
      final backendServices = BackendScope.maybeOf(context);
      if (backendServices != null && !_serverAttemptStarted) {
        await backendServices.generationCompletion.startNewAttempt();
        _serverAttemptStarted = true;
      }
      if (!mounted) return;
      final palette = await _paletteService.loadByName(brandId);
      final pattern = await _generationService.generate(
        draft: nextDraft,
        palette: palette,
      );
      await _projectStorageService.saveGeneratedPattern(pattern);
      if (!mounted) return;
      if (backendServices != null) {
        await backendServices.generationCompletion.completeGeneratedPattern(
          pattern,
        );
      }
      if (!mounted) return;

      setState(() => _generating = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(pattern: pattern, showGeneratedHint: true),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _generating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('生成失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _DotPainter())),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stageHeight = math.min(
                    280.0,
                    math.max(210.0, constraints.maxHeight * 0.35),
                  );

                  return Column(
                    children: [
                      const _ParameterNavigationBar(),
                      SizedBox(
                        height: stageHeight,
                        child: _ImagePreviewStage(
                          imageBytes: _previewImage,
                          aspectRatio: _previewAspectRatio,
                          loading: _generating,
                        ),
                      ),
                      Expanded(
                        child: _ParameterPanel(
                          bottomInset: bottomInset,
                          selectedTemplate: _selectedTemplate,
                          customSize: _customSize,
                          colorLimit: _limit,
                          smoothing: _smoothing,
                          removeBackground: _removeBackground,
                          denoise: _denoise,
                          saturation: _saturation,
                          canGenerate: _canGenerate,
                          brandLabel: _brandLabel,
                          palettes: _paletteService.availablePalettes,
                          onTemplateSelected: (template) {
                            setState(() {
                              _selectedTemplate = template;
                              _serverAttemptStarted = false;
                            });
                          },
                          onCustomSizeChanged: (value) {
                            setState(() {
                              _customSize = value;
                              _serverAttemptStarted = false;
                            });
                          },
                          onSmoothingChanged: () {
                            setState(() {
                              _smoothing = !_smoothing;
                              _serverAttemptStarted = false;
                            });
                          },
                          onRemoveBackgroundChanged: () {
                            setState(
                              () => _removeBackground = !_removeBackground,
                            );
                          },
                          onDenoiseChanged: () {
                            setState(() => _denoise = !_denoise);
                          },
                          onSaturationDecrease: () {
                            setState(
                              () => _saturation = _clampSaturation(
                                _saturation - 10,
                              ),
                            );
                          },
                          onSaturationIncrease: () {
                            setState(
                              () => _saturation = _clampSaturation(
                                _saturation + 10,
                              ),
                            );
                          },
                          onSaturationChanged: (value) {
                            setState(
                              () => _saturation = _clampSaturation(value),
                            );
                          },
                          onBrandSelected: (value) {
                            setState(() {
                              _brandId = value == _brandUnlimitedValue
                                  ? null
                                  : value;
                              _serverAttemptStarted = false;
                            });
                          },
                          onColorLimitSelected: (limit) {
                            setState(() {
                              _limit = limit;
                              _serverAttemptStarted = false;
                            });
                          },
                          onGenerate: _generate,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _brandLabel {
    final brandId = _brandId;
    if (brandId == null) return '不限';

    for (final definition in _paletteService.availablePalettes) {
      if (definition.id == brandId) return definition.displayName;
    }
    return brandId;
  }
}

class _ParameterNavigationBar extends StatelessWidget {
  const _ParameterNavigationBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 24,
                height: 40,
                child: Icon(Icons.chevron_left, color: Colors.black, size: 30),
              ),
            ),
            const Expanded(
              child: Text(
                '确定参数',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontFamily: _roundFontFamily,
                  fontFamilyFallback: _fontFallbacks,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 24, height: 40),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewStage extends StatelessWidget {
  static const _minimumOuterMargin = 30.0;
  static const _styleConversionReferenceWidth = 240.0;
  static const _imageBorderWidth = 4.075;
  static const _outerRadius = 16.298;
  static const _innerRadius = 12.2;

  final Uint8List imageBytes;
  final double aspectRatio;
  final bool loading;

  const _ImagePreviewStage({
    required this.imageBytes,
    required this.aspectRatio,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxImageWidth = math.max(
          1.0,
          constraints.maxWidth - _minimumOuterMargin * 2,
        );
        final maxImageHeight = math.max(
          1.0,
          constraints.maxHeight - _minimumOuterMargin * 2,
        );
        final frameSize = _fitAspectRatio(
          aspectRatio,
          Size(maxImageWidth, maxImageHeight),
        );
        final frameScale = _fitFrameScale(frameSize);
        final borderWidth = _imageBorderWidth * frameScale;
        final outerRadius = _outerRadius * frameScale;
        final innerRadius = _innerRadius * frameScale;

        return SizedBox.expand(
          child: Center(
            child: SizedBox(
              key: const ValueKey('parameter-preview-frame'),
              width: frameSize.width,
              height: frameSize.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(outerRadius),
                  border: Border.all(color: Colors.white, width: borderWidth),
                ),
                child: Padding(
                  key: const ValueKey('parameter-preview-white-border'),
                  padding: EdgeInsets.all(borderWidth),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(innerRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          imageBytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                        if (loading) const _ParameterLoadingOverlay(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _fitFrameScale(Size frameSize) {
    return math.max(0.01, frameSize.width / _styleConversionReferenceWidth);
  }

  Size _fitAspectRatio(double aspectRatio, Size bounds) {
    final normalizedRatio = aspectRatio <= 0 ? 1.0 : aspectRatio;
    var width = bounds.width;
    var height = width / normalizedRatio;
    if (height > bounds.height) {
      height = bounds.height;
      width = height * normalizedRatio;
    }
    return Size(width, height);
  }
}

class _ParameterLoadingOverlay extends StatelessWidget {
  const _ParameterLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('parameter-preview-loading-overlay'),
      color: Colors.black.withValues(alpha: 0.60),
      child: Center(
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 32,
                child: Image.asset(
                  _loadingRabbitIconAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '参数应用中',
                maxLines: 1,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'Z Labs RoundPix 12px M CN',
                  fontFamilyFallback: _fontFallbacks,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParameterPanel extends StatelessWidget {
  final double bottomInset;
  final ProductTemplate selectedTemplate;
  final int customSize;
  final ColorLimit colorLimit;
  final bool smoothing;
  final bool removeBackground;
  final bool denoise;
  final int saturation;
  final bool canGenerate;
  final String brandLabel;
  final List<PaletteDefinition> palettes;
  final ValueChanged<ProductTemplate> onTemplateSelected;
  final ValueChanged<int> onCustomSizeChanged;
  final VoidCallback onSmoothingChanged;
  final VoidCallback onRemoveBackgroundChanged;
  final VoidCallback onDenoiseChanged;
  final VoidCallback onSaturationDecrease;
  final VoidCallback onSaturationIncrease;
  final ValueChanged<int> onSaturationChanged;
  final ValueChanged<String> onBrandSelected;
  final ValueChanged<ColorLimit> onColorLimitSelected;
  final VoidCallback onGenerate;

  const _ParameterPanel({
    required this.bottomInset,
    required this.selectedTemplate,
    required this.customSize,
    required this.colorLimit,
    required this.smoothing,
    required this.removeBackground,
    required this.denoise,
    required this.saturation,
    required this.canGenerate,
    required this.brandLabel,
    required this.palettes,
    required this.onTemplateSelected,
    required this.onCustomSizeChanged,
    required this.onSmoothingChanged,
    required this.onRemoveBackgroundChanged,
    required this.onDenoiseChanged,
    required this.onSaturationDecrease,
    required this.onSaturationIncrease,
    required this.onSaturationChanged,
    required this.onBrandSelected,
    required this.onColorLimitSelected,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = math.max(32.0, bottomInset + 16.0);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('parameter-config-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                children: [
                  _SizeSelector(
                    selectedTemplate: selectedTemplate,
                    customSize: customSize,
                    onSelected: onTemplateSelected,
                    onCustomSizeChanged: onCustomSizeChanged,
                  ),
                  const SizedBox(height: 32),
                  _ParameterRows(
                    colorLimit: colorLimit,
                    smoothing: smoothing,
                    removeBackground: removeBackground,
                    denoise: denoise,
                    saturation: saturation,
                    brandLabel: brandLabel,
                    palettes: palettes,
                    onSmoothingChanged: onSmoothingChanged,
                    onRemoveBackgroundChanged: onRemoveBackgroundChanged,
                    onDenoiseChanged: onDenoiseChanged,
                    onSaturationDecrease: onSaturationDecrease,
                    onSaturationIncrease: onSaturationIncrease,
                    onSaturationChanged: onSaturationChanged,
                    onBrandSelected: onBrandSelected,
                    onColorLimitSelected: onColorLimitSelected,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
              child: _GenerateButton(enabled: canGenerate, onTap: onGenerate),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeSelector extends StatelessWidget {
  final ProductTemplate selectedTemplate;
  final int customSize;
  final ValueChanged<ProductTemplate> onSelected;
  final ValueChanged<int> onCustomSizeChanged;

  const _SizeSelector({
    required this.selectedTemplate,
    required this.customSize,
    required this.onSelected,
    required this.onCustomSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择大小',
          style: TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontFamily: _roundFontFamily,
            fontFamilyFallback: _fontFallbacks,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var index = 0; index < _sizeOptions.length; index++) ...[
                Expanded(
                  child: _SizeOptionTile(
                    template: _sizeOptions[index],
                    customSize: customSize,
                    selected: _sizeOptions[index].id == selectedTemplate.id,
                    onTap: () => onSelected(_sizeOptions[index]),
                  ),
                ),
                if (index != _sizeOptions.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (selectedTemplate.custom) ...[
          const SizedBox(height: 32),
          _CustomSizeSlider(value: customSize, onChanged: onCustomSizeChanged),
        ],
      ],
    );
  }
}

class _SizeOptionTile extends StatelessWidget {
  final ProductTemplate template;
  final int customSize;
  final bool selected;
  final VoidCallback onTap;

  const _SizeOptionTile({
    required this.template,
    required this.customSize,
    required this.selected,
    required this.onTap,
  });

  String get _dimensionLabel => template.custom
      ? '$customSize ×$customSize'
      : '${template.beadWidth} × ${template.beadHeight}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('parameter-size-${template.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.black : _controlBackground,
          borderRadius: BorderRadius.circular(selected ? 8 : 10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              template.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 14,
                fontFamily: _roundFontFamily,
                fontFamilyFallback: _fontFallbacks,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _dimensionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.60)
                    : Colors.black.withValues(alpha: 0.60),
                fontSize: 12,
                fontFamily: _roundFontFamily,
                fontFamilyFallback: _fontFallbacks,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomSizeSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _CustomSizeSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final min = ProductTemplateCatalog.minCustomBeads;
    final max = ProductTemplateCatalog.maxCustomBeads;
    final clampedValue = value.clamp(min, max).toInt();

    return Row(
      key: const ValueKey('parameter-custom-size-slider'),
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFE9EBF3),
              inactiveTrackColor: const Color(0xFFE9EBF3),
              trackHeight: 10,
              thumbShape: const _CustomSliderThumbShape(),
              overlayShape: SliderComponentShape.noOverlay,
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              key: const ValueKey('parameter-custom-size-slider-control'),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              value: clampedValue.toDouble(),
              onChanged: (next) => onChanged(next.round()),
            ),
          ),
        ),
        const SizedBox(width: 32),
        SizedBox(
          width: 62,
          child: Text(
            '$clampedValue ×$clampedValue',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: _roundFontFamily,
              fontFamilyFallback: _fontFallbacks,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomSliderThumbShape extends SliderComponentShape {
  static const _thumbWidth = 10.667;
  static const _thumbHeight = 16.0;

  const _CustomSliderThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(_thumbWidth, _thumbHeight);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(
      center: center,
      width: _thumbWidth,
      height: _thumbHeight,
    );
    final thumb = RRect.fromRectAndRadius(rect, const Radius.circular(19.111));

    canvas.drawRRect(
      thumb.shift(const Offset(-0.444, 0)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.444),
    );
    canvas.drawRRect(thumb, Paint()..color = Colors.black);
    canvas.drawRRect(
      thumb,
      Paint()
        ..color = const Color(0xFF4C4C4C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.227,
    );
  }
}

class _ParameterRows extends StatelessWidget {
  final ColorLimit colorLimit;
  final bool smoothing;
  final bool removeBackground;
  final bool denoise;
  final int saturation;
  final String brandLabel;
  final List<PaletteDefinition> palettes;
  final VoidCallback onSmoothingChanged;
  final VoidCallback onRemoveBackgroundChanged;
  final VoidCallback onDenoiseChanged;
  final VoidCallback onSaturationDecrease;
  final VoidCallback onSaturationIncrease;
  final ValueChanged<int> onSaturationChanged;
  final ValueChanged<String> onBrandSelected;
  final ValueChanged<ColorLimit> onColorLimitSelected;

  const _ParameterRows({
    required this.colorLimit,
    required this.smoothing,
    required this.removeBackground,
    required this.denoise,
    required this.saturation,
    required this.brandLabel,
    required this.palettes,
    required this.onSmoothingChanged,
    required this.onRemoveBackgroundChanged,
    required this.onDenoiseChanged,
    required this.onSaturationDecrease,
    required this.onSaturationIncrease,
    required this.onSaturationChanged,
    required this.onBrandSelected,
    required this.onColorLimitSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ParameterRow(
          label: '去背景',
          height: 28,
          trailing: GestureDetector(
            key: const ValueKey('parameter-remove-background-toggle'),
            behavior: HitTestBehavior.opaque,
            onTap: onRemoveBackgroundChanged,
            child: _ControlSwitch(value: removeBackground),
          ),
        ),
        const SizedBox(height: 32),
        _ParameterRow(
          label: '去杂色',
          height: 28,
          trailing: GestureDetector(
            key: const ValueKey('parameter-denoise-toggle'),
            behavior: HitTestBehavior.opaque,
            onTap: onDenoiseChanged,
            child: _ControlSwitch(value: denoise),
          ),
        ),
        const SizedBox(height: 32),
        _ParameterRow(
          label: '平滑边缘',
          height: 28,
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSmoothingChanged,
            child: _ControlSwitch(value: smoothing),
          ),
        ),
        const SizedBox(height: 32),
        _ParameterRow(
          label: '饱和度',
          height: 40,
          trailing: _SaturationControl(
            value: saturation,
            onDecrease: onSaturationDecrease,
            onIncrease: onSaturationIncrease,
            onChanged: onSaturationChanged,
          ),
        ),
        const SizedBox(height: 32),
        _ParameterRow(
          label: '颜色品牌',
          height: 40,
          trailing: _BrandSelector(
            label: brandLabel,
            palettes: palettes,
            onSelected: onBrandSelected,
          ),
        ),
        const SizedBox(height: 32),
        _ColorLimitSelector(
          selected: colorLimit,
          onSelected: onColorLimitSelected,
        ),
      ],
    );
  }
}

class _ParameterRow extends StatelessWidget {
  final String label;
  final double height;
  final Widget trailing;

  const _ParameterRow({
    required this.label,
    required this.height,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontFamily: _roundFontFamily,
              fontFamilyFallback: _fontFallbacks,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _ControlSwitch extends StatelessWidget {
  final bool value;

  const _ControlSwitch({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 61,
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _switchTrack,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              top: 2,
              left: value ? 23 : 2,
              child: Container(
                width: 36,
                height: 24,
                decoration: BoxDecoration(
                  color: value ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(43),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      offset: const Offset(-1, 0),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaturationControl extends StatelessWidget {
  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<int> onChanged;

  const _SaturationControl({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SquareTextButton(
          key: const ValueKey('parameter-saturation-decrease'),
          label: '-',
          onTap: onDecrease,
        ),
        const SizedBox(width: 4),
        _SaturationValueInput(value: value, onChanged: onChanged),
        const SizedBox(width: 4),
        _SquareTextButton(
          key: const ValueKey('parameter-saturation-increase'),
          label: '+',
          onTap: onIncrease,
        ),
      ],
    );
  }
}

class _SquareTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SquareTextButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _controlBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontFamily: _roundFontFamily,
                fontFamilyFallback: _fontFallbacks,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaturationValueInput extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _SaturationValueInput({required this.value, required this.onChanged});

  @override
  State<_SaturationValueInput> createState() => _SaturationValueInputState();
}

class _SaturationValueInputState extends State<_SaturationValueInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _SaturationValueInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = '${widget.value}';
    if (_controller.text != nextText &&
        int.tryParse(_controller.text) != widget.value) {
      _controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _handleChanged(String text) {
    final parsed = int.tryParse(text);
    if (parsed == null) return;
    final clamped = parsed.clamp(_saturationMin, _saturationMax).toInt();
    widget.onChanged(clamped);
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text) ?? widget.value;
    final clamped = parsed.clamp(_saturationMin, _saturationMax).toInt();
    widget.onChanged(clamped);
    final nextText = '$clamped';
    if (_controller.text != nextText) {
      _controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _controlBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: TextField(
            key: const ValueKey('parameter-saturation-value-input'),
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLines: 1,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            onTap: () => _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            ),
            onChanged: _handleChanged,
            onSubmitted: (_) => _commit(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: _roundFontFamily,
              fontFamilyFallback: _fontFallbacks,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandSelector extends StatelessWidget {
  final String label;
  final List<PaletteDefinition> palettes;
  final ValueChanged<String> onSelected;

  const _BrandSelector({
    required this.label,
    required this.palettes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: '',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: _brandUnlimitedValue,
          child: Text('不限'),
        ),
        for (final definition in palettes)
          PopupMenuItem<String>(
            value: definition.id,
            child: Text(definition.displayName),
          ),
      ],
      child: SizedBox(
        width: 124,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _controlBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: _roundFontFamily,
                      fontFamilyFallback: _fontFallbacks,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.black,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorLimitSelector extends StatelessWidget {
  final ColorLimit selected;
  final ValueChanged<ColorLimit> onSelected;

  const _ColorLimitSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '色号限制',
          style: TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontFamily: _roundFontFamily,
            fontFamilyFallback: _fontFallbacks,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              for (
                var index = 0;
                index < _colorLimitOptions.length;
                index++
              ) ...[
                Expanded(
                  child: _ColorLimitTile(
                    limit: _colorLimitOptions[index],
                    selected: _colorLimitOptions[index] == selected,
                    onTap: () => onSelected(_colorLimitOptions[index]),
                  ),
                ),
                if (index != _colorLimitOptions.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorLimitTile extends StatelessWidget {
  final ColorLimit limit;
  final bool selected;
  final VoidCallback onTap;

  const _ColorLimitTile({
    required this.limit,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('parameter-color-limit-${limit.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? Colors.black : _controlBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            limit.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.black.withValues(alpha: 0.60),
              fontSize: 14,
              fontFamily: _roundFontFamily,
              fontFamilyFallback: _fontFallbacks,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _GenerateButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('parameter-generate-button'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(44),
          ),
          child: Center(
            child: Text(
              '生成图纸',
              style: TextStyle(
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.40),
                fontSize: 18,
                fontFamily: _roundFontFamily,
                fontFamilyFallback: _fontFallbacks,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  static const _spacing = 8.0;

  const _DotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x4DCDD4E2);
    for (var y = 2.0; y < size.height; y += _spacing) {
      for (var x = 2.0; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 0.72, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
