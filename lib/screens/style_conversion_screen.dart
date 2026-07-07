import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/draft_project.dart';
import 'parameter_config_screen.dart';

const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _pageBackground = Color(0xFFEEF0F6);
const _styleAccentColor = Color(0xFFFF55BE);
const _loadingRabbitIconAsset = 'assets/figma_style/loading_rabbit_icon.png';

class StyleConversionScreen extends StatefulWidget {
  final DraftProject draft;

  const StyleConversionScreen({super.key, required this.draft});

  @override
  State<StyleConversionScreen> createState() => _StyleConversionScreenState();
}

class _StyleConversionScreenState extends State<StyleConversionScreen> {
  static const _styles = [
    _StyleOption(
      id: 'picture_book',
      asset: 'assets/figma_style/style_thumb_1.png',
    ),
    _StyleOption(
      id: 'bold_line',
      asset: 'assets/figma_style/style_thumb_2.png',
    ),
    _StyleOption(
      id: 'soft_daily',
      asset: 'assets/figma_style/style_thumb_3.png',
    ),
    _StyleOption(
      id: 'playful_doodle',
      asset: 'assets/figma_style/style_thumb_4.png',
    ),
    _StyleOption(
      id: 'pastel_pop',
      asset: 'assets/figma_style/style_thumb_5.png',
    ),
  ];

  late final Uint8List _sourceImage =
      widget.draft.croppedImageBytes ?? widget.draft.originalImageBytes;
  late final double _imageAspectRatio = _decodeImageAspectRatio(_sourceImage);

  String? _selectedStyleId;
  Uint8List? _convertedImage;
  bool _converting = false;
  final _styleScrollController = ScrollController();

  Uint8List get _displayImage => _convertedImage ?? _sourceImage;
  bool get _canGenerate => _convertedImage != null && !_converting;

  double _decodeImageAspectRatio(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.height == 0) return 1;
    return decoded.width / decoded.height;
  }

  Future<void> _startConversion(_StyleOption style) async {
    if (_converting) return;

    setState(() {
      _selectedStyleId = style.id;
      _converting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (!mounted) return;

    setState(() {
      _convertedImage = _sourceImage;
      _converting = false;
    });
  }

  Future<void> _continueToParameters() async {
    final convertedImage = _convertedImage;
    if (convertedImage == null || _converting) return;

    final nextDraft = widget.draft.copyWith(styledImageBytes: convertedImage);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParameterConfigScreen(draft: nextDraft),
      ),
    );
  }

  @override
  void dispose() {
    _styleScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _DotPainter())),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const _StyleNavigationBar(),
                  Expanded(
                    child: _ImageStage(
                      imageBytes: _displayImage,
                      aspectRatio: _imageAspectRatio,
                      loading: _converting,
                    ),
                  ),
                  _BottomStylePanel(
                    bottomInset: bottomInset,
                    scrollController: _styleScrollController,
                    styles: _styles,
                    selectedStyleId: _selectedStyleId,
                    canGenerate: _canGenerate,
                    onStyleTap: _startConversion,
                    onGenerate: _continueToParameters,
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

class _StyleNavigationBar extends StatelessWidget {
  const _StyleNavigationBar();

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
                '转换风格',
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

class _ImageStage extends StatelessWidget {
  static const _minimumOuterMargin = 30.0;
  static const _imageBorderWidth = 4.075;

  final Uint8List imageBytes;
  final double aspectRatio;
  final bool loading;

  const _ImageStage({
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

        return SizedBox.expand(
          key: const ValueKey('style-image-stage'),
          child: Center(
            child: SizedBox(
              key: const ValueKey('style-image-frame'),
              width: frameSize.width,
              height: frameSize.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.298),
                  border: Border.all(
                    color: Colors.white,
                    width: _imageBorderWidth,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_imageBorderWidth),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          imageBytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                        if (loading) const _LoadingOverlay(),
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

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20.373, sigmaY: 20.373),
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.12),
          child: const Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.72,
                    colors: [
                      Color(0x26FFFFFF),
                      Color(0x10FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [0, 0.58, 1],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x1FFFFFFF),
                      Color(0x05FFFFFF),
                      Color(0x14FFFFFF),
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
              ),
              Center(child: _LoadingBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingBadge extends StatelessWidget {
  const _LoadingBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 39,
            child: Image.asset(
              _loadingRabbitIconAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '风格转换中',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontFamily: 'Z Labs RoundPix 12px M CN',
              fontFamilyFallback: _fontFallbacks,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomStylePanel extends StatelessWidget {
  static const _thumbnailWidth = 74.0;
  static const _thumbnailGap = 8.0;

  final double bottomInset;
  final ScrollController scrollController;
  final List<_StyleOption> styles;
  final String? selectedStyleId;
  final bool canGenerate;
  final ValueChanged<_StyleOption> onStyleTap;
  final VoidCallback onGenerate;

  const _BottomStylePanel({
    required this.bottomInset,
    required this.scrollController,
    required this.styles,
    required this.selectedStyleId,
    required this.canGenerate,
    required this.onStyleTap,
    required this.onGenerate,
  });

  void _scrollStyleIntoView(int index, double viewportWidth) {
    if (!scrollController.hasClients) return;

    final itemStart = index * (_thumbnailWidth + _thumbnailGap);
    final itemEnd = itemStart + _thumbnailWidth;
    final visibleStart = scrollController.offset;
    final visibleEnd = visibleStart + viewportWidth;
    double? targetOffset;

    if (itemEnd > visibleEnd) {
      targetOffset = itemEnd - viewportWidth;
    } else if (itemStart < visibleStart) {
      targetOffset = itemStart;
    }

    if (targetOffset == null) return;

    final position = scrollController.position;
    final clampedOffset = targetOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((clampedOffset - scrollController.offset).abs() < 0.5) return;

    scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 0, bottomInset + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Text(
                '转换风格',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: _roundFontFamily,
                  fontFamilyFallback: _fontFallbacks,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 88,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ListView.separated(
                    controller: scrollController,
                    clipBehavior: Clip.none,
                    scrollDirection: Axis.horizontal,
                    itemCount: styles.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: _thumbnailGap),
                    itemBuilder: (context, index) {
                      final style = styles[index];
                      return _StyleThumbnail(
                        style: style,
                        selected: style.id == selectedStyleId,
                        onTap: () {
                          _scrollStyleIntoView(index, constraints.maxWidth);
                          onStyleTap(style);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: _GenerateButton(enabled: canGenerate, onTap: onGenerate),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleThumbnail extends StatelessWidget {
  final _StyleOption style;
  final bool selected;
  final VoidCallback onTap;

  const _StyleThumbnail({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('style-option-${style.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 74,
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xFFC6E0EF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _styleAccentColor : Colors.transparent,
            width: selected ? 2 : 0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(selected ? 6 : 8),
          child: Stack(
            fit: StackFit.expand,
            children: [Image.asset(style.asset, fit: BoxFit.cover)],
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
      key: const ValueKey('style-generate-button'),
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

class _StyleOption {
  final String id;
  final String asset;

  const _StyleOption({required this.id, required this.asset});
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
