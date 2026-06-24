import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/draft_project.dart';
import '../services/image_service.dart';
import 'crop_screen.dart';

const _pixelFontFamily = 'Z Labs RoundPix 12px M CN';
const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _designWidth = 390.0;
const _designHeight = 844.0;

const _pinHeroAsset = 'assets/pin_home/hero.png';
const _pinFeatureIllustrationAsset = 'assets/pin_home/feature-illustration.png';
const _pinFeatureBoxAsset = 'assets/pin_home/feature-box.png';
const _pinRabbitMarkAsset = 'assets/pin_home/rabbit-mark.png';
const _pinFilterAsset = 'assets/pin_home/filter.png';
const _pinTile1Asset = 'assets/pin_home/tile-1.png';
const _pinTile2Asset = 'assets/pin_home/tile-2.png';
const _pinTile3Asset = 'assets/pin_home/tile-3.png';
const _pinTile4Asset = 'assets/pin_home/tile-4.png';
const _pinTile5Asset = 'assets/pin_home/tile-5.png';
const _pinTile6Asset = 'assets/pin_home/tile-6.png';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  static const _blindBoxPatterns = [
    _pinTile1Asset,
    _pinTile2Asset,
    _pinTile3Asset,
    _pinTile4Asset,
    _pinTile5Asset,
    _pinTile6Asset,
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
          final pageHeight = math.min(
            _designHeight * scale,
            constraints.maxHeight,
          );
          final visibleDesignHeight = pageHeight / scale;

          return Center(
            child: SizedBox(
              width: pageWidth,
              height: pageHeight,
              child: ClipRect(
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: _designWidth,
                    height: visibleDesignHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: Color(0xFFF2F1F0)),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          width: 390,
                          height: 352,
                          child: _HeroCard(
                            onStart: _picking ? null : _pickImage,
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 361,
                          child: _FeatureCard(
                            asset: _pinFeatureIllustrationAsset,
                            label: '插画转图纸',
                            onTap: _picking ? null : _pickImage,
                          ),
                        ),
                        Positioned(
                          left: 199,
                          top: 361,
                          child: _FeatureCard(
                            asset: _pinFeatureBoxAsset,
                            label: '图纸盲盒',
                            onTap: _openBlindBox,
                          ),
                        ),
                        Positioned(
                          left: 24,
                          top: 523,
                          child: _GalleryTitle(
                            onFilter: () => _showComingSoon('筛选功能即将开放'),
                          ),
                        ),
                        const Positioned(
                          left: 12,
                          top: 583,
                          child: _GalleryGrid(),
                        ),
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 78,
                          child: _BottomNavigation(),
                        ),
                      ],
                    ),
                  ),
                ),
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

class _HeroCard extends StatelessWidget {
  final VoidCallback? onStart;

  const _HeroCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '照片转图纸制作流程',
      child: GestureDetector(
        onTap: onStart,
        behavior: HitTestBehavior.opaque,
        child: Image.asset(
          _pinHeroAsset,
          width: 390,
          height: 352,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String asset;
  final String label;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31),
          child: Image.asset(
            asset,
            width: 179,
            height: 133,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
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
      width: 342,
      height: 32,
      child: Row(
        children: [
          Image.asset(
            _pinRabbitMarkAsset,
            width: 23,
            height: 22,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 8),
          const Text(
            '兔子的图库',
            style: TextStyle(
              color: Colors.black,
              fontFamily: _roundFontFamily,
              fontFamilyFallback: _fontFallbacks,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: '筛选图库',
            child: GestureDetector(
              onTap: onFilter,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Image.asset(
                    _pinFilterAsset,
                    width: 21,
                    height: 21,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid();

  static const _tiles = [
    _pinTile1Asset,
    _pinTile2Asset,
    _pinTile3Asset,
    _pinTile1Asset,
    _pinTile2Asset,
    _pinTile3Asset,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 376,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final asset in _tiles) _GalleryTile(asset: asset)],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final String asset;

  const _GalleryTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.white,
        child: Image.asset(
          asset,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0xBFFFFFFF),
            offset: Offset(0, -10),
            blurRadius: 24,
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: Center(
              child: _NavLabel(
                label: '我的',
                strokeColor: Color(0xFFFF55BE),
                angle: -7,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _NavLabel(
                label: '我的',
                strokeColor: Colors.black,
                angle: -3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  final String label;
  final Color strokeColor;
  final double angle;

  const _NavLabel({
    required this.label,
    required this.strokeColor,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: _pixelFontFamily,
      fontFamilyFallback: _fontFallbacks,
      fontSize: 22,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: 0,
    );

    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            label,
            style: style.copyWith(
              color: Colors.white,
              shadows: [
                Shadow(color: strokeColor, offset: const Offset(2, 0)),
                Shadow(color: strokeColor, offset: const Offset(-2, 0)),
                Shadow(color: strokeColor, offset: const Offset(0, 2)),
                Shadow(color: strokeColor, offset: const Offset(0, -2)),
                Shadow(color: strokeColor, offset: const Offset(3, 3)),
              ],
            ),
          ),
          Text(
            label,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = strokeColor,
            ),
          ),
          Text(label, style: style.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
