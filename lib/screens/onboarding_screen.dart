import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/blind_box_dialog.dart';

const onboardingCompletedPreferenceKey = 'onboarding_completed_v1';

const _designWidth = 390.0;
const _pixelFontFamily = 'Z Labs RoundPix 12px M CN';
const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _onboardingArtworkAssets = <_ArtworkAsset>[
  _ArtworkAsset('assets/onboarding/upload_original.png', 258),
  _ArtworkAsset('assets/onboarding/upload_illustration.png', 258),
  _ArtworkAsset('assets/onboarding/upload_pattern.png', 258),
  _ArtworkAsset('assets/onboarding/upload_rabbit.png', 100),
  _ArtworkAsset('assets/onboarding/blind_box_pattern.png', 270),
  _ArtworkAsset('assets/onboarding/blind_box_pattern_rabbit.png', 80),
  _ArtworkAsset('assets/onboarding/finished_product_top_left.png', 180),
  _ArtworkAsset('assets/onboarding/finished_product_bottom_left.png', 150),
  _ArtworkAsset('assets/onboarding/finished_product_bottom_right.png', 160),
  _ArtworkAsset('assets/onboarding/editor_animation_original.png', 258),
  _ArtworkAsset('assets/onboarding/editor_animation_final.png', 258),
  _ArtworkAsset('assets/onboarding/editor_preview_background.png', 258),
  _ArtworkAsset('assets/onboarding/editor_preview_comb.png', 146),
  _ArtworkAsset('assets/onboarding/editor_preview_swatch.png', 54),
  _ArtworkAsset('assets/onboarding/page_4_2.png', 281),
];

class _ArtworkAsset {
  final String path;
  final double logicalWidth;

  const _ArtworkAsset(this.path, this.logicalWidth);
}

int _cacheWidthFor(BuildContext context, double logicalWidth) =>
    (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round();

/// Shows onboarding only until the user has completed it once on this install.
class FirstLaunchGate extends StatefulWidget {
  final Widget child;

  const FirstLaunchGate({super.key, required this.child});

  @override
  State<FirstLaunchGate> createState() => _FirstLaunchGateState();
}

class _FirstLaunchGateState extends State<FirstLaunchGate> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _loadCompletionState();
  }

  Future<void> _loadCompletionState() async {
    var hasCompletedOnboarding = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      hasCompletedOnboarding =
          preferences.getBool(onboardingCompletedPreferenceKey) == true;
    } catch (_) {
      // Treat an unavailable local store as a first launch, so the core flow
      // remains accessible and completion can be retried later.
    }
    if (mounted) setState(() => _showOnboarding = !hasCompletedOnboarding);
  }

  Future<void> _completeOnboarding() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(onboardingCompletedPreferenceKey, true);
    } finally {
      if (mounted) setState(() => _showOnboarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOnboarding = _showOnboarding;
    if (showOnboarding == null) {
      return const ColoredBox(color: Colors.white);
    }
    if (!showOnboarding) return widget.child;
    return OnboardingScreen(onCompleted: _completeOnboarding);
  }
}

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onCompleted;

  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _finishing = false;
  bool _isTransitioning = false;
  bool _hasPrecachedArtwork = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasPrecachedArtwork) return;
    _hasPrecachedArtwork = true;
    _precacheArtwork();
  }

  Future<void> _precacheArtwork() async {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    await Future.wait(
      _onboardingArtworkAssets.map(
        (asset) => precacheImage(
          ResizeImage(
            AssetImage(asset.path),
            width: (asset.logicalWidth * pixelRatio).round(),
          ),
          context,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_finishing || _isTransitioning) return;
    if (_currentIndex < _onboardingPages.length - 1) {
      _isTransitioning = true;
      try {
        await _pageController.nextPage(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOutCubicEmphasized,
        );
      } finally {
        _isTransitioning = false;
      }
      return;
    }

    setState(() => _finishing = true);
    await widget.onCompleted();
    if (mounted) setState(() => _finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        body: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _onboardingPages.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) => RepaintBoundary(
            child: _OnboardingPage(
              page: _onboardingPages[index],
              pageIndex: index,
              isActive: index == _currentIndex,
              onContinue: _continue,
              isFinishing: _finishing,
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final _OnboardingArtwork artwork;
  final Color backgroundColor;
  final List<Color> backgroundGradient;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.artwork,
    required this.backgroundColor,
    required this.backgroundGradient,
  });
}

enum _OnboardingArtwork { upload, blindBox, finishedProducts, editor }

const _onboardingPages = [
  _OnboardingPageData(
    title: '上传照片',
    subtitle: '一键生成拼豆图纸',
    artwork: _OnboardingArtwork.upload,
    backgroundColor: Colors.white,
    backgroundGradient: [Color(0xFFFFDDF2), Colors.white],
  ),
  _OnboardingPageData(
    title: '图纸盲盒',
    subtitle: '不做选择，随缘开拼',
    artwork: _OnboardingArtwork.blindBox,
    backgroundColor: Colors.white,
    backgroundGradient: [Color(0xFFFFF0A6), Colors.white],
  ),
  _OnboardingPageData(
    title: '拼豆成果',
    subtitle: '咔嚓一下，帮你记录',
    artwork: _OnboardingArtwork.finishedProducts,
    backgroundColor: Color(0xFFF0F2F6),
    backgroundGradient: [Color(0xFFFFD5F2), Color(0xFFF0F2F6)],
  ),
  _OnboardingPageData(
    title: '图纸编辑',
    subtitle: '轻松修改生成效果',
    artwork: _OnboardingArtwork.editor,
    backgroundColor: Colors.white,
    backgroundGradient: [Color(0xFFFFF0A6), Colors.white],
  ),
];

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData page;
  final int pageIndex;
  final bool isActive;
  final VoidCallback onContinue;
  final bool isFinishing;

  const _OnboardingPage({
    required this.page,
    required this.pageIndex,
    required this.isActive,
    required this.onContinue,
    required this.isFinishing,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: page.backgroundColor,
        gradient: RadialGradient(
          center: const Alignment(0, -0.08),
          radius: 0.86,
          colors: page.backgroundGradient,
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = math.min(constraints.maxWidth, _designWidth);
            final scale = contentWidth / _designWidth;

            return Center(
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SparklePatternPainter(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 36 * scale,
                      left: 24 * scale,
                      right: 24 * scale,
                      child: _ProgressIndicator(pageIndex: pageIndex),
                    ),
                    Positioned(
                      top: 100 * scale,
                      left: 32 * scale,
                      right: 32 * scale,
                      child: _OnboardingTitle(
                        title: page.title,
                        subtitle: page.subtitle,
                      ),
                    ),
                    Positioned.fill(
                      top: 172 * scale,
                      bottom: 70 * scale,
                      child: _Artwork(
                        artwork: page.artwork,
                        scale: scale,
                        isActive: isActive,
                      ),
                    ),
                    Positioned(
                      left: 24 * scale,
                      right: 24 * scale,
                      bottom: math.max(21 * scale, 12),
                      height: 56 * scale,
                      child: FilledButton(
                        onPressed: isFinishing ? null : onContinue,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          disabledBackgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: const StadiumBorder(),
                        ),
                        child: isFinishing
                            ? SizedBox(
                                width: 22 * scale,
                                height: 22 * scale,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '继续',
                                style: TextStyle(
                                  fontFamily: _roundFontFamily,
                                  fontFamilyFallback: _fontFallbacks,
                                  fontSize: 20 * scale,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    if (pageIndex == 1)
                      Positioned(
                        left: 22 * scale,
                        bottom: math.max(21 * scale, 12) + 55 * scale,
                        width: 44 * scale,
                        height: 44 * scale,
                        child: IgnorePointer(
                          child: Image.asset(
                            'assets/onboarding/blind_box_pattern_rabbit.png',
                            fit: BoxFit.contain,
                            cacheWidth: _cacheWidthFor(context, 48 * scale),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int pageIndex;

  const _ProgressIndicator({required this.pageIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(
              _onboardingPages.length,
              (index) => Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                    right: index == _onboardingPages.length - 1 ? 0 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: index <= pageIndex
                        ? const Color(0xFFF9DC38)
                        : Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(36),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Text(
          '${pageIndex + 1}/4',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.6),
            fontFamily: _pixelFontFamily,
            fontFamilyFallback: _fontFallbacks,
            fontSize: 12,
            letterSpacing: 1.08,
          ),
        ),
      ],
    );
  }
}

class _OnboardingTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _OnboardingTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.black,
      fontFamily: _roundFontFamily,
      fontFamilyFallback: _fontFallbacks,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.3,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, textAlign: TextAlign.center, style: style),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: style),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  final _OnboardingArtwork artwork;
  final double scale;
  final bool isActive;

  const _Artwork({
    required this.artwork,
    required this.scale,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    switch (artwork) {
      case _OnboardingArtwork.upload:
        return _AnimatedUploadArtwork(scale: scale);
      case _OnboardingArtwork.blindBox:
        return _BlindBoxArtwork(scale: scale);
      case _OnboardingArtwork.finishedProducts:
        return _FinishedProductsArtwork(scale: scale, isActive: isActive);
      case _OnboardingArtwork.editor:
        return _AnimatedEditorArtwork(scale: scale);
    }
  }
}

class _AnimatedUploadArtwork extends StatefulWidget {
  final double scale;

  const _AnimatedUploadArtwork({required this.scale});

  @override
  State<_AnimatedUploadArtwork> createState() => _AnimatedUploadArtworkState();
}

class _AnimatedUploadArtworkState extends State<_AnimatedUploadArtwork> {
  static const _photoAssets = [
    'assets/onboarding/upload_original.png',
    'assets/onboarding/upload_illustration.png',
    'assets/onboarding/upload_pattern.png',
  ];

  Timer? _photoTimer;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _photoTimer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (mounted) {
        setState(() => _photoIndex = (_photoIndex + 1) % _photoAssets.length);
      }
    });
  }

  @override
  void dispose() {
    _photoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 48 * scale,
          left: 63 * scale,
          child: Transform.rotate(
            angle: 0.12,
            child: Container(
              width: 264 * scale,
              height: 330 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFFFFDF36),
                border: Border.all(color: Colors.white, width: 4 * scale),
                borderRadius: BorderRadius.circular(24 * scale),
              ),
            ),
          ),
        ),
        Positioned(
          top: 55 * scale,
          left: 66 * scale,
          child: _UploadPhotoFrame(
            asset: _photoAssets[_photoIndex],
            scale: scale,
          ),
        ),
        Positioned(
          top: 416 * scale,
          left: 276 * scale,
          width: 100 * scale,
          height: 100 * scale,
          child: Transform.rotate(
            // angle: -0.22,
            angle: -0.08,
            child: Image.asset(
              'assets/onboarding/upload_rabbit.png',
              width: 100 * scale,
              height: 100 * scale,
              cacheWidth: _cacheWidthFor(context, 100 * scale),
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadPhotoFrame extends StatelessWidget {
  final String asset;
  final double scale;

  const _UploadPhotoFrame({
    super.key,
    required this.asset,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final frameWidth = 257.6 * scale;
    final frameHeight = 320.8 * scale;
    final radius = BorderRadius.circular(25.6 * scale);

    return Container(
      width: frameWidth,
      height: frameHeight,
      padding: EdgeInsets.all(4 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            offset: Offset(4 * scale, 4 * scale),
            blurRadius: 8 * scale,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21.6 * scale),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [...previousChildren, ?currentChild],
          ),
          child: Image.asset(
            asset,
            key: ValueKey(asset),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            cacheWidth: _cacheWidthFor(context, 258 * scale),
          ),
        ),
      ),
    );
  }
}

class _AnimatedEditorArtwork extends StatefulWidget {
  final double scale;

  const _AnimatedEditorArtwork({required this.scale});

  @override
  State<_AnimatedEditorArtwork> createState() => _AnimatedEditorArtworkState();
}

class _AnimatedEditorArtworkState extends State<_AnimatedEditorArtwork> {
  Timer? _stageTimer;
  int _stageIndex = 0;

  @override
  void initState() {
    super.initState();
    _stageTimer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (mounted) setState(() => _stageIndex = (_stageIndex + 1) % 3);
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 48 * scale,
          left: 63 * scale,
          child: Transform.rotate(
            angle: 0.12,
            child: Container(
              width: 264 * scale,
              height: 330 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFFFFDF36),
                border: Border.all(color: Colors.white, width: 4 * scale),
                borderRadius: BorderRadius.circular(24 * scale),
              ),
            ),
          ),
        ),
        Positioned(
          top: 55 * scale,
          left: 66 * scale,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => SizedBox(
              width: 257.6 * scale,
              height: 320.8 * scale,
              child: Stack(children: [...previousChildren, ?currentChild]),
            ),
            child: switch (_stageIndex) {
              0 => _UploadPhotoFrame(
                key: const ValueKey('editor-original'),
                asset: 'assets/onboarding/editor_animation_original.png',
                scale: scale,
              ),
              1 => _EditorPreviewCard(
                key: const ValueKey('editor-preview'),
                scale: scale,
              ),
              _ => _UploadPhotoFrame(
                key: const ValueKey('editor-final'),
                asset: 'assets/onboarding/editor_animation_final.png',
                scale: scale,
              ),
            },
          ),
        ),
        Positioned(
          left: 22 * scale,
          bottom: 6 * scale,
          width: 44 * scale,
          height: 44 * scale,
          child: Image.asset(
            'assets/onboarding/blind_box_pattern_rabbit.png',
            fit: BoxFit.contain,
            cacheWidth: _cacheWidthFor(context, 48 * scale),
          ),
        ),
      ],
    );
  }
}

class _EditorPreviewCard extends StatelessWidget {
  final double scale;

  const _EditorPreviewCard({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(25.6 * scale);
    return Container(
      width: 257.6 * scale,
      height: 320.8 * scale,
      padding: EdgeInsets.all(4 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            offset: Offset(4 * scale, 4 * scale),
            blurRadius: 8 * scale,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21.6 * scale),
        child: Stack(
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 15 * scale,
                  sigmaY: 15 * scale,
                ),
                child: Image.asset(
                  'assets/onboarding/editor_preview_background.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: Color(0x99000000))),
            Positioned(
              left: 55.93 * scale,
              top: 30 * scale,
              width: 145.276 * scale,
              height: 135.809 * scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 13 * scale,
                      sigmaY: 13 * scale,
                    ),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFFFD928),
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/onboarding/editor_preview_comb.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/onboarding/editor_preview_comb.png',
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 34.07 * scale,
              top: 193.11 * scale,
              width: 189 * scale,
              height: 72 * scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5 * scale,
                  ),
                  borderRadius: BorderRadius.circular(15 * scale),
                ),
                child: Padding(
                  padding: EdgeInsets.all(9 * scale),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 54 * scale,
                        height: 54 * scale,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC2E3FC),
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(12 * scale),
                        ),
                      ),
                      SvgPicture.asset(
                        'assets/onboarding/editor_preview_swap.svg',
                        width: 24 * scale,
                        height: 24 * scale,
                      ),
                      SizedBox(
                        width: 54 * scale,
                        height: 54 * scale,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12 * scale),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/onboarding/editor_preview_swatch.png',
                                fit: BoxFit.cover,
                              ),
                              const ColoredBox(color: Color(0x66FEBCDC)),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _PatternCard extends StatelessWidget {
  final String asset;
  final double scale;

  const _PatternCard({required this.asset, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: Offset(0, 22 * scale),
        child: SizedBox(
          width: 281 * scale,
          height: 351 * scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: 0.12,
                child: Container(
                  width: 264 * scale,
                  height: 330 * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDF36),
                    borderRadius: BorderRadius.circular(24 * scale),
                  ),
                ),
              ),
              Image.asset(
                asset,
                width: 281 * scale,
                height: 351 * scale,
                cacheWidth: _cacheWidthFor(context, 281 * scale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlindBoxArtwork extends StatelessWidget {
  final double scale;

  const _BlindBoxArtwork({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -40 * scale),
      child: SizedBox(
        width: 390 * scale,
        height: 500 * scale,
        child: BlindBoxRewardReveal(
          patternAsset: 'assets/onboarding/blind_box_pattern.png',
          titleIconAsset: 'assets/figma_home/blind_box/union.png',
          patternBadgeAsset: 'assets/figma_home/blind_box/badge.png',
        ),
      ),
    );
  }
}

class _FinishedProductsArtwork extends StatefulWidget {
  final double scale;
  final bool isActive;

  const _FinishedProductsArtwork({required this.scale, required this.isActive});

  @override
  State<_FinishedProductsArtwork> createState() =>
      _FinishedProductsArtworkState();
}

class _FinishedProductsArtworkState extends State<_FinishedProductsArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _topLeftAnimation;
  late final Animation<double> _topRightAnimation;
  late final Animation<double> _bottomLeftAnimation;
  late final Animation<double> _bottomRightAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _topLeftAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.23, curve: Curves.easeOutCubic),
    );
    _topRightAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.27, 0.5, curve: Curves.easeOutCubic),
    );
    _bottomLeftAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.54, 0.77, curve: Curves.easeOutCubic),
    );
    _bottomRightAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.81, 1, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _playIfActive());
  }

  @override
  void didUpdateWidget(covariant _FinishedProductsArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _playIfActive();
    } else if (!widget.isActive && oldWidget.isActive) {
      _entranceController.reset();
    }
  }

  void _playIfActive() {
    if (!mounted || !widget.isActive) return;
    if (MediaQuery.of(context).disableAnimations) {
      _entranceController.value = 1;
    } else {
      _entranceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 34 * scale,
          left: 27 * scale,
          width: 168 * scale,
          height: 224 * scale,
          child: _ArtworkEntrance(
            animation: _topLeftAnimation,
            alignment: Alignment.topLeft,
            child: Transform.rotate(
              angle: -9.25 * math.pi / 180,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/onboarding/finished_product_top_left.png',
                fit: BoxFit.contain,
                alignment: Alignment.topLeft,
                cacheWidth: _cacheWidthFor(context, 180 * scale),
              ),
            ),
          ),
        ),
        Positioned(
          top: 113 * scale,
          right: 57 * scale,
          width: 126 * scale * 1.18,
          height: 44 * scale * 1.18,

          child: _ArtworkEntrance(
            animation: _topRightAnimation,
            alignment: Alignment.topRight,
            child: Transform.rotate(
              angle: 28.3 * math.pi / 180,
              alignment: Alignment.center,
              child: _StaticRecordButton(scale: scale * 1.18),
            ),
          ),
        ),
        Positioned(
          top: 249 * scale,
          left: 63 * scale,
          width: 138 * scale,
          height: 140 * scale,
          child: _ArtworkEntrance(
            animation: _bottomLeftAnimation,
            alignment: Alignment.bottomLeft,
            child: Transform.rotate(
              angle: 11.87 * math.pi / 180,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/onboarding/finished_product_bottom_left.png',
                fit: BoxFit.contain,
                cacheWidth: _cacheWidthFor(context, 150 * scale),
              ),
            ),
          ),
        ),
        Positioned(
          top: 179 * scale,
          right: 19 * scale,
          width: 178 * scale,
          height: 178 * scale,
          child: _ArtworkEntrance(
            animation: _bottomRightAnimation,
            alignment: Alignment.bottomRight,
            child: Transform.rotate(
              angle: 11.04 * math.pi / 180,
              alignment: Alignment.center,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  1,
                  0,
                  0,
                  0,
                  48,
                  0,
                  1,
                  0,
                  0,
                  48,
                  0,
                  0,
                  1,
                  0,
                  48,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Image.asset(
                  'assets/onboarding/finished_product_bottom_right.png',
                  fit: BoxFit.contain,
                  cacheWidth: _cacheWidthFor(context, 180 * scale),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtworkEntrance extends StatelessWidget {
  final Animation<double> animation;
  final Alignment alignment;
  final Widget child;

  const _ArtworkEntrance({
    required this.animation,
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
        alignment: alignment,
        child: child,
      ),
    );
  }
}

class _StaticRecordButton extends StatelessWidget {
  final double scale;

  const _StaticRecordButton({required this.scale});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 126 * scale,
        height: 44 * scale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8 * scale,
              top: -8 * scale,
              child: Transform(
                transform: Matrix4.diagonal3Values(-1, 1, 1),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/pin_icon/my_camera_button_icon.svg',
                  width: 28.8395 * scale,
                  height: 26.3962 * scale,
                ),
              ),
            ),
            Positioned(
              left: 30 * scale,
              top: 8 * scale,
              child: Transform.rotate(
                angle: -7.56 * math.pi / 180,
                alignment: Alignment.center,
                child: Stack(
                  children: [
                    Text(
                      '咔嚓一下',
                      style: TextStyle(
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 13 * scale
                          ..strokeJoin = StrokeJoin.round
                          ..strokeCap = StrokeCap.round
                          ..color = const Color(0xFFFFF09A),
                        fontFamily: _pixelFontFamily,
                        fontSize: 19.2 * scale,
                        letterSpacing: 1.344 * scale,
                        height: 1,
                        fontFamilyFallback: _fontFallbacks,
                      ),
                    ),
                    Text(
                      '咔嚓一下',
                      style: TextStyle(
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 0.6 * scale
                          ..strokeJoin = StrokeJoin.round
                          ..color = const Color(0xFF030303),
                        fontFamily: _pixelFontFamily,
                        fontSize: 19.2 * scale,
                        letterSpacing: 1.344 * scale,
                        height: 1,
                        fontFamilyFallback: _fontFallbacks,
                      ),
                    ),
                    Text(
                      '咔嚓一下',
                      style: TextStyle(
                        color: const Color(0xFF030303),
                        fontFamily: _pixelFontFamily,
                        fontSize: 19.2 * scale,
                        letterSpacing: 1.344 * scale,
                        height: 1,
                        fontFamilyFallback: _fontFallbacks,
                      ),
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

class _SparklePatternPainter extends CustomPainter {
  final Color color;

  const _SparklePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 38.0;
    for (var y = 156.0; y < size.height - 82; y += spacing) {
      for (var x = 6.0; x < size.width; x += spacing) {
        final offsetX = ((y / spacing).round().isEven ? 0.0 : spacing / 2) + x;
        _drawSparkle(canvas, Offset(offsetX, y), paint);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - 8)
      ..lineTo(center.dx + 2.2, center.dy - 2.2)
      ..lineTo(center.dx + 8, center.dy)
      ..lineTo(center.dx + 2.2, center.dy + 2.2)
      ..lineTo(center.dx, center.dy + 8)
      ..lineTo(center.dx - 2.2, center.dy + 2.2)
      ..lineTo(center.dx - 8, center.dy)
      ..lineTo(center.dx - 2.2, center.dy - 2.2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
