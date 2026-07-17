import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _pixelFontFamily = 'Z Labs RoundPix 12px M CN';
const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _designWidth = 390.0;
const _contentDesignHeight = 764.0;
const _bottomNavigationDesignHeight = 80.0;
const _compactBottomNavigationDesignHeight = 60.0;
const _compactHeightBreakpoint = 700.0;
const _pageBackground = Color(0xFFF0F0F4);
const _mainContentVerticalOffset = 23.0;

/// Figma “我的”页面。
///
/// 成品区暂时展示设计稿中的加载占位状态；后续接入作品接口时可直接
/// 用真实缩略图替换 [_WorksPlaceholder]，无需改变页面布局。
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pageWidth = math.min(constraints.maxWidth, _designWidth);
          final scale = pageWidth / _designWidth;
          final compact = constraints.maxHeight <= _compactHeightBreakpoint;
          final navigationHeight = compact
              ? _compactBottomNavigationDesignHeight
              : _bottomNavigationDesignHeight;
          final navigationHeightPx = navigationHeight * scale;
          final contentViewportHeight = math.max(
            0.0,
            constraints.maxHeight - navigationHeightPx,
          );
          final scrollHeight = math.max(
            contentViewportHeight,
            _contentDesignHeight * scale,
          );

          return Center(
            child: SizedBox(
              width: pageWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: _pageBackground,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: pageWidth,
                          height: scrollHeight,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _ScaledDesignSurface(
                              designWidth: _designWidth,
                              designHeight: _contentDesignHeight,
                              scale: scale,
                              child: const _MyDesignCanvas(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: navigationHeightPx,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _ScaledDesignSurface(
                        designWidth: _designWidth,
                        designHeight: navigationHeight,
                        scale: scale,
                        child: _MyBottomNavigation(
                          height: navigationHeight,
                          onMakeTap: () => Navigator.of(context).maybePop(),
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

class _ScaledDesignSurface extends StatelessWidget {
  final double designWidth;
  final double designHeight;
  final double scale;
  final Widget child;

  const _ScaledDesignSurface({
    required this.designWidth,
    required this.designHeight,
    required this.scale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: designWidth * scale,
      height: designHeight * scale,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minWidth: designWidth,
        maxWidth: designWidth,
        minHeight: designHeight,
        maxHeight: designHeight,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: designWidth,
            height: designHeight,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MyDesignCanvas extends StatelessWidget {
  const _MyDesignCanvas();

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _designWidth,
      height: _contentDesignHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: 0,
            left: 0,
            width: 390,
            height: 480,
            child: Image(
              image: AssetImage('assets/figma_my/header.png'),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned(
            top: 70,
            right: 16,
            width: 24,
            height: 24,
            child: Semantics(
              button: true,
              label: '设置',
              child: InkResponse(
                onTap: () => _showComingSoon(context, '设置功能即将开放'),
                radius: 24,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/figma_my/settings_icon.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 120 + _mainContentVerticalOffset,
            left: 12,
            child: Row(
              children: [
                _ShortcutCard(
                  key: const ValueKey('my-patterns-shortcut'),
                  title: '我的图纸',
                  startColor: const Color(0xFFFFBCE5),
                  endColor: const Color(0xFFFF54BD),
                  titleEndColor: const Color(0xFFFFE5F4),
                  moreColor: const Color(0xFFF0D3E6),
                  ribbonAsset: 'assets/figma_my/card_ribbon_pink.svg',
                  onTap: () => _showComingSoon(context, '我的图纸即将开放'),
                ),
                const SizedBox(width: 12),
                _ShortcutCard(
                  key: const ValueKey('my-favorites-shortcut'),
                  title: '我的收藏',
                  startColor: const Color(0xFFFFF4BC),
                  endColor: const Color(0xFFFFEB7A),
                  titleEndColor: const Color(0xFFFFF8C7),
                  moreColor: const Color(0xFFFFFBE2),
                  ribbonAsset: 'assets/figma_my/card_ribbon_yellow.svg',
                  onTap: () => _showComingSoon(context, '我的收藏即将开放'),
                ),
              ],
            ),
          ),
          Positioned(
            top: 283 + _mainContentVerticalOffset,
            left: 12,
            child: _WorksSection(
              onRecordTap: () => _showComingSoon(context, '记录功能即将开放'),
              onMoreTap: () => _showComingSoon(context, '更多成品即将开放'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final String title;
  final Color startColor;
  final Color endColor;
  final Color titleEndColor;
  final Color moreColor;
  final String ribbonAsset;
  final VoidCallback onTap;

  const _ShortcutCard({
    super.key,
    required this.title,
    required this.startColor,
    required this.endColor,
    required this.titleEndColor,
    required this.moreColor,
    required this.ribbonAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 177,
          height: 131,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [startColor, endColor],
                      stops: const [0, 1],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 0.9),
                        blurRadius: 0.45,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 37.65,
                top: 25.77,
                child: Transform.rotate(
                  angle: 3.87 * math.pi / 180,
                  child: Opacity(
                    opacity: 0.52,
                    child: _PatternPreview(width: 115.74, height: 85.75),
                  ),
                ),
              ),
              const Positioned(
                left: 30.63,
                top: 30.58,
                child: Opacity(
                  opacity: 0.99,
                  child: _PatternPreview(width: 115.74, height: 85.75),
                ),
              ),
              Positioned(
                left: -2.72,
                bottom: -1.82,
                width: 182.45,
                height: 64.44,
                child: IgnorePointer(child: _FigmaRibbon(asset: ribbonAsset)),
              ),
              Positioned(
                top: -10,
                left: 16,
                child: _ShortcutTitle(title: title, endColor: titleEndColor),
              ),
              Positioned(
                left: 126.05,
                top: 106.26,
                child: Transform(
                  transform: Matrix4.skewX(-10 * math.pi / 180),
                  alignment: Alignment.center,
                  child: Text(
                    'More',
                    style: TextStyle(
                      color: moreColor,
                      fontFamily: _pixelFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2.4,
                      fontFamilyFallback: _fontFallbacks,
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

class _ShortcutTitle extends StatelessWidget {
  final String title;
  final Color endColor;

  const _ShortcutTitle({required this.title, required this.endColor});

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Colors.white,
      fontFamily: _pixelFontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.4,
      fontFamilyFallback: _fontFallbacks,
    );

    return Transform(
      transform: Matrix4.skewX(-10 * math.pi / 180),
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            title,
            style: baseStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 7
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.black,
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.white, endColor],
              stops: const [0.08, 1],
            ).createShader(bounds),
            child: Text(title, style: baseStyle),
          ),
        ],
      ),
    );
  }
}

class _FigmaRibbon extends StatelessWidget {
  final String asset;

  const _FigmaRibbon({required this.asset});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _RibbonClipper(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.45, sigmaY: 5.45),
            child: const SizedBox.expand(),
          ),
          SvgPicture.asset(asset, fit: BoxFit.fill),
        ],
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  const _RibbonClipper();

  @override
  Path getClip(Size size) {
    final x = size.width / 183;
    final y = size.height / 65;

    return Path()
      ..moveTo(11.8 * x, 4.08 * y)
      ..lineTo(67.58 * x, 4.08 * y)
      ..cubicTo(69.84 * x, 4.08 * y, 72.03 * x, 4.93 * y, 73.70 * x, 6.46 * y)
      ..lineTo(77.56 * x, 9.99 * y)
      ..cubicTo(
        79.23 * x,
        11.51 * y,
        81.42 * x,
        12.36 * y,
        83.68 * x,
        12.36 * y,
      )
      ..lineTo(98.76 * x, 12.36 * y)
      ..cubicTo(
        101.03 * x,
        12.36 * y,
        103.21 * x,
        11.51 * y,
        104.89 * x,
        9.99 * y,
      )
      ..lineTo(108.75 * x, 6.46 * y)
      ..cubicTo(
        110.42 * x,
        4.93 * y,
        112.60 * x,
        4.08 * y,
        114.87 * x,
        4.08 * y,
      )
      ..lineTo(170.65 * x, 4.08 * y)
      ..cubicTo(
        175.66 * x,
        4.08 * y,
        179.72 * x,
        8.15 * y,
        179.72 * x,
        13.16 * y,
      )
      ..lineTo(179.72 * x, 46.63 * y)
      ..cubicTo(
        179.72 * x,
        55.47 * y,
        172.56 * x,
        62.63 * y,
        163.72 * x,
        62.63 * y,
      )
      ..lineTo(18.72 * x, 62.63 * y)
      ..cubicTo(9.89 * x, 62.63 * y, 2.72 * x, 55.47 * y, 2.72 * x, 46.63 * y)
      ..lineTo(2.72 * x, 13.16 * y)
      ..cubicTo(2.72 * x, 8.15 * y, 6.79 * x, 4.08 * y, 11.8 * x, 4.08 * y)
      ..close();
  }

  @override
  bool shouldReclip(covariant _RibbonClipper oldClipper) => false;
}

class _PatternPreview extends StatelessWidget {
  final double width;
  final double height;

  const _PatternPreview({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1F000000), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            offset: Offset(2, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: -3.2,
              top: -7.5,
              width: width * 1.0521,
              height: height * 1.4827,
              child: Image.asset(
                'assets/figma_my/card_preview.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorksSection extends StatelessWidget {
  final VoidCallback onRecordTap;
  final VoidCallback onMoreTap;

  const _WorksSection({required this.onRecordTap, required this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 366,
      height: 466,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 0,
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(0, 1),
                  child: Image.asset(
                    'assets/figma_home/gallery_title_icon.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '我的成品',
                  style: TextStyle(
                    fontFamily: _roundFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: Colors.black,
                    fontFamilyFallback: _fontFallbacks,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Semantics(
              button: true,
              label: '更多成品',
              child: GestureDetector(
                onTap: onMoreTap,
                child: Row(
                  children: [
                    Text(
                      '更多',
                      style: TextStyle(
                        fontFamily: _roundFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        color: const Color(0x99000000),
                        fontFamilyFallback: _fontFallbacks,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0x99000000),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            top: 36,
            child: _WorksPlaceholder(key: ValueKey('my-works-placeholder')),
          ),
          const Positioned(top: 410, left: 163.875, child: _PageIndicator()),
          Positioned(
            top: 422,
            left: 103,
            child: _RecordButton(onTap: onRecordTap),
          ),
        ],
      ),
    );
  }
}

class _WorksPlaceholder extends StatelessWidget {
  const _WorksPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 366,
      height: 366,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(8),
      child: CustomPaint(
        painter: const _DashedRoundedRectPainter(),
        child: const SizedBox.expand(child: _PlaceholderDots()),
      ),
    );
  }
}

class _PlaceholderDots extends StatelessWidget {
  const _PlaceholderDots();

  @override
  Widget build(BuildContext context) {
    const dotCenters = [64.0, 175.0, 286.0];
    const rowCenters = [64.0, 175.0, 286.0];

    return Stack(
      children: [
        for (final y in rowCenters)
          for (final x in dotCenters)
            Positioned(
              left: x - 6,
              top: y - 6,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFD9D9D9),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 12, height: 12),
              ),
            ),
      ],
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(16);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    final paint = Paint()
      ..color = const Color(0x1F000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        const dashLength = 8.0;
        const dashGap = 6.0;
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dashLength, metric.length),
          ),
          paint,
        );
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) => false;
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 38.25,
      height: 4,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
            child: SizedBox(width: 18.25, height: 4),
          ),
          SizedBox(width: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x14000000),
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
            child: SizedBox(width: 6, height: 4),
          ),
          SizedBox(width: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x14000000),
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
            child: SizedBox(width: 6, height: 4),
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecordButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '记录一下',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 160,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
          child: Text(
            '记录一下',
            style: TextStyle(
              color: Colors.white,
              fontFamily: _roundFontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.1,
              fontFamilyFallback: _fontFallbacks,
            ),
          ),
        ),
      ),
    );
  }
}

class _MyBottomNavigation extends StatelessWidget {
  final double height;
  final VoidCallback onMakeTap;

  const _MyBottomNavigation({required this.height, required this.onMakeTap});

  @override
  Widget build(BuildContext context) {
    final labelTop = height <= _compactBottomNavigationDesignHeight
        ? 16.0
        : 26.0;

    return SizedBox(
      width: _designWidth,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: const ValueKey('my-bottom-nav-background'),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
          ),
          Positioned(
            left: 63,
            top: labelTop,
            width: 88,
            height: 28,
            child: Semantics(
              button: true,
              label: '制作',
              child: GestureDetector(
                key: const ValueKey('my-make-nav-item'),
                behavior: HitTestBehavior.opaque,
                onTap: onMakeTap,
                child: const Center(
                  child: _BottomNavText('制作', fontSize: 16, selected: false),
                ),
              ),
            ),
          ),
          Positioned(
            right: 55,
            top: labelTop - 9,
            width: 105,
            height: 38,
            child: Center(
              child: Transform.rotate(
                angle: -9 * math.pi / 180,
                child: const _BottomNavText(
                  '我的',
                  fontSize: 19.2,
                  selected: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavText extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool selected;

  const _BottomNavText(
    this.text, {
    required this.fontSize,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: _pixelFontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
      fontFamilyFallback: _fontFallbacks,
    );

    return Stack(
      children: [
        Text(
          text,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = selected ? 6.6 : 3
              ..strokeJoin = StrokeJoin.round
              ..strokeCap = StrokeCap.round
              ..color = selected ? const Color(0xFFFF55BE) : Colors.black,
          ),
        ),
        Text(text, style: baseStyle.copyWith(color: Colors.white)),
      ],
    );
  }
}
