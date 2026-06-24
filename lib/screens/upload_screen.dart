import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/draft_project.dart';
import '../services/image_service.dart';
import 'crop_screen.dart';

const _pixelFontFamily = 'Z Labs RoundPix 12px M CN';
const _roundFontFamily = 'Alimama FangYuanTi VF';
const _scriptFontFamily = 'Taprom';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _designWidth = 390.0;
const _designContentHeight = 1162.0;

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  static const _blindBoxPatterns = [
    'assets/figma_home/gallery_pattern_1.png',
    'assets/figma_home/gallery_pattern_2.png',
    'assets/figma_home/gallery_pattern_3.png',
  ];

  final ImageService _imageService = ImageService();
  bool _picking = false;

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    setState(() => _picking = true);
    try {
      final file = await _imageService.pickImage(source: source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CropScreen(draft: DraftProject(originalImageBytes: bytes)),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('照片读取失败：$error')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openBlindBox() {
    final pattern =
        _blindBoxPatterns[math.Random().nextInt(_blindBoxPatterns.length)];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BlindBoxSheet(pattern: pattern),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1F0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pageWidth = math.min(constraints.maxWidth, _designWidth);
          final scale = pageWidth / _designWidth;
          final scaledContentHeight = _designContentHeight * scale;
          final contentHeight = math.max(
            scaledContentHeight,
            constraints.maxHeight,
          );

          return Center(
            child: SizedBox(
              width: pageWidth,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFFF2F1F0)),
                  ),
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: pageWidth,
                      height: contentHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: _designWidth * scale,
                          height: scaledContentHeight,
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: _designWidth,
                              height: _designContentHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Positioned(
                                    left: 0,
                                    top: 0,
                                    width: 390,
                                    height: 480,
                                    child: Image(
                                      image: AssetImage(
                                        'assets/figma_home/home_header.png',
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0x00F2F1F0),
                                            Color(0x00F2F1F0),
                                            Color(0xFFF2F1F0),
                                          ],
                                          stops: [0, 0.48, 0.66],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    left: 0,
                                    top: 0,
                                    child: _PinStatusBar(),
                                  ),
                                  _HeroCard(
                                    picking: _picking,
                                    onStart: _picking ? null : _pickImage,
                                  ),
                                  const Positioned(
                                    left: 16,
                                    top: 175,
                                    child: _DecorativeImage(
                                      asset:
                                          'assets/figma_home/deco_curve_black.png',
                                      width: 9,
                                      height: 17,
                                    ),
                                  ),
                                  Positioned(
                                    left: 12,
                                    top: 360.55,
                                    child: _FeatureCard(
                                      icon:
                                          'assets/figma_home/feature_illustration_icon.png',
                                      textImage:
                                          'assets/figma_home/feature_illustration_text.png',
                                      onTap: _picking ? null : _pickImage,
                                    ),
                                  ),
                                  Positioned(
                                    left: 199,
                                    top: 360.55,
                                    child: _FeatureCard(
                                      icon:
                                          'assets/figma_home/feature_blind_box_icon.png',
                                      textImage:
                                          'assets/figma_home/feature_blind_box_text.png',
                                      onTap: _openBlindBox,
                                    ),
                                  ),
                                  Positioned(
                                    left: 20,
                                    top: 525,
                                    child: _GalleryTitle(
                                      onFilter: () =>
                                          _showComingSoon('筛选功能即将开放'),
                                    ),
                                  ),
                                  const Positioned(
                                    left: 12,
                                    top: 557,
                                    child: _GalleryGrid(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 80 * scale,
                    child: SizedBox(
                      width: pageWidth,
                      height: 80 * scale,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomCenter,
                        child: const SizedBox(
                          width: _designWidth,
                          height: 80,
                          child: _BottomNavigation(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BlindBoxSheet extends StatelessWidget {
  final String pattern;

  const _BlindBoxSheet({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '抽中图纸',
              style: TextStyle(
                color: Colors.black,
                fontFamily: _roundFontFamily,
                fontFamilyFallback: _fontFallbacks,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 180,
                height: 180,
                child: Image.asset(pattern, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '收下',
                  style: TextStyle(
                    fontFamily: _roundFontFamily,
                    fontFamilyFallback: _fontFallbacks,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinStatusBar extends StatelessWidget {
  const _PinStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 390,
      height: 44,
      child: Stack(
        children: const [
          Positioned(
            left: 21,
            top: 15.5,
            width: 54,
            child: Text(
              '9:41',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.28,
                height: 1,
              ),
            ),
          ),
          Positioned(right: 14, top: 14, child: _StatusIcons()),
        ],
      ),
    );
  }
}

class _StatusIcons extends StatelessWidget {
  const _StatusIcons();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 67,
      height: 14,
      child: CustomPaint(painter: _StatusIconPainter()),
    );
  }
}

class _StatusIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 4; i++) {
      final h = 3.0 + i * 2.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0 + i * 4.3, 11 - h, 3, h),
          const Radius.circular(1),
        ),
        paint,
      );
    }

    final wifiPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final center = const Offset(30, 11);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 9),
      -2.25,
      1.35,
      false,
      wifiPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 6),
      -2.18,
      1.22,
      false,
      wifiPaint,
    );
    canvas.drawCircle(const Offset(30, 10.8), 1.5, paint);

    final batteryRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(45, 3, 19, 9),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      batteryRect,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(47, 5, 14, 5),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(65, 6, 2, 4),
        const Radius.circular(1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroCard extends StatelessWidget {
  final bool picking;
  final VoidCallback? onStart;

  const _HeroCard({required this.picking, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      top: 154,
      child: GestureDetector(
        onTap: onStart,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 366,
          height: 197,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFBCE5), Color(0xFFFF55BD)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 2),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(painter: _HeroPatternPainter()),
                  ),
                ),
              ),
              const Positioned(
                left: 12.98,
                top: 12.42,
                child: _DecorativeImage(
                  asset: 'assets/figma_home/card_hole_141.png',
                  width: 17,
                  height: 17,
                ),
              ),
              const Positioned(
                left: 2.52,
                top: 32.99,
                child: _DecorativeImage(
                  asset: 'assets/figma_home/card_hole_137.png',
                  width: 9,
                  height: 9,
                ),
              ),
              const Positioned(
                left: 5,
                top: 33,
                child: _DecorativeImage(
                  asset: 'assets/figma_home/card_hole_142.png',
                  width: 9,
                  height: 9,
                ),
              ),
              const Positioned(
                left: 19.61,
                top: -79.55,
                child: _RotatedPhotoFrame(
                  image: 'assets/figma_home/girl.png',
                  angle: -18.2,
                  outerWidth: 176.03,
                  outerHeight: 176.03,
                  imageWidth: 139.46,
                  imageHeight: 139.46,
                  radius: 13,
                  overlayGradient: true,
                ),
              ),
              const Positioned(
                left: 148.62,
                top: -81.67,
                child: _RotatedPhotoFrame(
                  image: 'assets/figma_home/bead_photo.png',
                  angle: 17.19,
                  outerWidth: 194.67,
                  outerHeight: 197.69,
                  imageWidth: 154.55,
                  imageHeight: 159.12,
                  radius: 15,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                left: 0,
                top: 46,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(46),
                  child: const _HeroUnionLayer(),
                ),
              ),
              const Positioned(
                left: 9,
                top: 23.61,
                child: _DecorativeImage(
                  asset: 'assets/figma_home/deco_curve_pink.png',
                  width: 26,
                  height: 17,
                ),
              ),
              const Positioned(left: -21.59, top: 54.34, child: _TitleBadge()),
              const Positioned(
                left: 11.41,
                top: 38.77,
                child: _StickerText(label: '照片转图纸', fontSize: 27),
              ),
              const Positioned(left: 18, top: 104, child: _StepPill()),
              Positioned(
                right: -1,
                top: 163.94,
                child: Transform.rotate(
                  angle: -7.56 * math.pi / 180,
                  child: Text(
                    picking ? '打开中...' : '开始制作',
                    style: const TextStyle(
                      color: Color(0xFF030303),
                      fontFamily: _pixelFontFamily,
                      fontFamilyFallback: _fontFallbacks,
                      fontSize: 19.2,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.34,
                      height: 1,
                      shadows: [
                        Shadow(color: Color(0xFFFFF095), offset: Offset(2, 2)),
                        Shadow(color: Colors.white, offset: Offset(0.8, 0.8)),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 19.24,
                top: 155.96,
                child: Opacity(
                  opacity: 0.25,
                  child: Text(
                    'Pinto',
                    style: TextStyle(
                      color: Color(0xFFE84BA6),
                      fontFamily: _scriptFontFamily,
                      fontFamilyFallback: _fontFallbacks,
                      fontSize: 20,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RotatedPhotoFrame extends StatelessWidget {
  final String image;
  final double angle;
  final double outerWidth;
  final double outerHeight;
  final double imageWidth;
  final double imageHeight;
  final double radius;
  final BoxFit fit;
  final bool overlayGradient;

  const _RotatedPhotoFrame({
    required this.image,
    required this.angle,
    required this.outerWidth,
    required this.outerHeight,
    required this.imageWidth,
    required this.imageHeight,
    required this.radius,
    this.fit = BoxFit.cover,
    this.overlayGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: outerWidth,
      height: outerHeight,
      child: Center(
        child: Transform.rotate(
          angle: angle * math.pi / 180,
          child: Container(
            width: imageWidth,
            height: imageHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - 4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    image,
                    fit: fit,
                    alignment: Alignment.bottomCenter,
                  ),
                  if (overlayGradient)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.12),
                          ],
                          stops: const [0.29, 0.9],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroUnionLayer extends StatelessWidget {
  const _HeroUnionLayer();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99FFFFFF), Color(0xD9FFFFFF), Color(0xFFFFFFFF)],
          stops: [0, 0.36, 1],
        ).createShader(bounds);
      },
      child: Image.asset(
        'assets/figma_home/hero_union.png',
        width: 368.44,
        height: 151.17,
        fit: BoxFit.fill,
      ),
    );
  }
}

class _TitleBadge extends StatelessWidget {
  const _TitleBadge();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -14.92 * math.pi / 180,
      child: Image.asset(
        'assets/figma_home/title_badge.png',
        width: 48.8,
        height: 48.4,
      ),
    );
  }
}

class _DecorativeImage extends StatelessWidget {
  final String asset;
  final double width;
  final double height;

  const _DecorativeImage({
    required this.asset,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, width: width, height: height, fit: BoxFit.fill);
  }
}

class _StickerText extends StatelessWidget {
  final String label;
  final double fontSize;

  const _StickerText({required this.label, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.skewX(-0.16)..rotateZ(9.73 * math.pi / 180),
      child: _OutlinedText(
        label,
        fontSize: fontSize,
        fillColor: Colors.white,
        strokeColor: const Color(0xFF91145F),
        strokeWidth: 2.4,
        letterSpacing: 1.8,
        shadowOffset: const Offset(1.6, 1.6),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Step 1', '上传照片'),
      ('Step 2', '转为插画'),
      ('Step 3', '确定参数'),
      ('Step 4', '生成图纸'),
    ];

    return Container(
      width: 330,
      height: 43,
      padding: const EdgeInsets.fromLTRB(18, 7, 18, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE84BA6),
        border: Border.all(color: const Color(0xFFCD2E8A)),
        borderRadius: BorderRadius.circular(39),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 2,
            offset: Offset(1, 1),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final step in steps)
            SizedBox(
              width: 52.5,
              height: 26,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 52.5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontFamily: _roundFontFamily,
                          fontFamilyFallback: _fontFallbacks,
                          fontSize: 10,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        step.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: _roundFontFamily,
                          fontFamilyFallback: _fontFallbacks,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String icon;
  final String textImage;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.textImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 179,
        height: 132.9,
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            colors: [Color(0xFFFFF9C4), Colors.white],
            radius: 0.82,
          ),
          border: Border.all(color: Color(0xFFF2E59B)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFF2E59B),
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 61.5,
              top: 24,
              child: Image.asset(icon, width: 56, height: 56),
            ),
            Positioned(
              left: 48,
              top: 84,
              child: Image.asset(
                textImage,
                width: 83,
                height: 24.9,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTitle extends StatelessWidget {
  final VoidCallback onFilter;

  const _GalleryTitle({required this.onFilter});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 350,
      height: 16,
      child: Row(
        children: [
          Image.asset(
            'assets/figma_home/gallery_icon.png',
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 4),
          const Text(
            '兔子的图库',
            style: TextStyle(
              color: Colors.black,
              fontFamily: _roundFontFamily,
              fontFamilyFallback: _fontFallbacks,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onFilter,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CustomPaint(painter: _FilterIconPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterIconPainter extends CustomPainter {
  const _FilterIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 5), const Offset(12, 5), paint);
    canvas.drawLine(const Offset(6, 8), const Offset(12, 8), paint);
    canvas.drawLine(const Offset(8, 11), const Offset(12, 11), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid();

  static const _patterns = [
    'assets/figma_home/gallery_pattern_1.png',
    'assets/figma_home/gallery_pattern_2.png',
    'assets/figma_home/gallery_pattern_3.png',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 366,
      child: Column(
        children: [
          for (var row = 0; row < 5; row++) ...[
            Row(
              children: [
                for (var col = 0; col < 3; col++) ...[
                  _GalleryTile(asset: _patterns[col], variant: col),
                  if (col < 2) const SizedBox(width: 4),
                ],
              ],
            ),
            if (row < 4) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final String asset;
  final int variant;

  const _GalleryTile({required this.asset, required this.variant});

  @override
  Widget build(BuildContext context) {
    final rect = switch (variant) {
      0 => const Rect.fromLTWH(-7.62, -14.47, 126.57, 169.7),
      1 => const Rect.fromLTWH(8.51, 21.77, 102.31, 75.8),
      _ => const Rect.fromLTWH(7.03, 16.6, 92.23, 91.88),
    };

    return SizedBox(
      width: 119.33,
      height: 119.33,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Colors.white),
          child: Stack(
            children: [
              Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: Image.asset(asset, fit: BoxFit.cover),
              ),
              const Positioned.fill(child: _GalleryFade()),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryFade extends StatelessWidget {
  const _GalleryFade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0x00FFFFFF), Colors.white],
          radius: 0.78,
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 390,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                border: Border.all(color: Colors.white),
              ),
            ),
          ),
          Positioned(
            left: 83,
            top: 27,
            child: Transform.rotate(
              angle: -9 * math.pi / 180,
              child: const _NavLabel(label: '我的', selected: true),
            ),
          ),
          const Positioned(
            right: 83,
            top: 27,
            child: _NavLabel(label: '我的', selected: false),
          ),
        ],
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  final String label;
  final bool selected;

  const _NavLabel({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return _OutlinedText(
      label,
      fontSize: selected ? 19.2 : 16,
      fillColor: selected ? const Color(0xFFFF55BD) : Colors.black,
      strokeColor: Colors.white,
      strokeWidth: 3,
      letterSpacing: 0,
    );
  }
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final double letterSpacing;
  final Offset shadowOffset;

  const _OutlinedText(
    this.text, {
    required this.fontSize,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.letterSpacing,
    this.shadowOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: _pixelFontFamily,
      fontFamilyFallback: _fontFallbacks,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: 1,
    );

    return Stack(
      children: [
        if (shadowOffset != Offset.zero)
          Transform.translate(
            offset: shadowOffset,
            child: Text(
              text,
              style: baseStyle.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeWidth
                  ..color = strokeColor,
              ),
            ),
          ),
        Text(
          text,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        Text(text, style: baseStyle.copyWith(color: fillColor)),
      ],
    );
  }
}

class _HeroPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    for (var y = 8.0; y < size.height; y += 8) {
      for (var x = 8.0; x < size.width; x += 8) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }

    final overlayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 46, size.width, 94),
        const Radius.circular(46),
      ),
      overlayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
