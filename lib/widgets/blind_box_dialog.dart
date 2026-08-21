import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api/api_models.dart';
import 'pattern_display_placeholder.dart';
import 'template_category_presentation.dart';

enum BlindBoxRarity {
  superRare('超稀有', Color(0xFFFF7AC7)),
  superCute('超可爱', Color(0xFFFF7AC7)),
  superFun('超有趣', Color(0xFFFFE100)),
  superAbstract('超抽象', Color(0xFF7AFFF4));

  final String label;
  final Color gradientEndColor;

  const BlindBoxRarity(this.label, this.gradientEndColor);

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Colors.white, gradientEndColor],
    stops: const [0, 0.89359],
  );
}

class BlindBoxReward {
  final String patternAsset;
  final BlindBoxRarity rarity;
  final String titleIconAsset;
  final String patternBadgeAsset;
  final Gradient? rarityGradient;

  const BlindBoxReward({
    required this.patternAsset,
    required this.rarity,
    required this.titleIconAsset,
    required this.patternBadgeAsset,
    this.rarityGradient,
  });

  String get rarityLabel => rarity.label;
  Gradient get resolvedRarityGradient => rarityGradient ?? rarity.gradient;

  BlindBoxReward copyWith({
    String? patternAsset,
    String? titleIconAsset,
    String? patternBadgeAsset,
  }) {
    return BlindBoxReward(
      patternAsset: patternAsset ?? this.patternAsset,
      rarity: rarity,
      titleIconAsset: titleIconAsset ?? this.titleIconAsset,
      patternBadgeAsset: patternBadgeAsset ?? this.patternBadgeAsset,
      rarityGradient: rarityGradient,
    );
  }
}

const _designWidth = 390.0;
const _designHeight = 680.0;
const _pixelFontFamily = 'Z Labs RoundPix 12px M CN';
const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _fallbackReward = BlindBoxReward(
  patternAsset: patternDisplayPlaceholderAsset,
  rarity: BlindBoxRarity.superRare,
  titleIconAsset: 'assets/figma_home/blind_box/union.png',
  patternBadgeAsset: 'assets/figma_home/blind_box/badge.png',
);
const _printerSlotTop = 188.0;
const _printerSlotHeight = 28.0;
const _printedPaperTop = _printerSlotTop + _printerSlotHeight / 2;
const _paperMaskTop = 0.0;
const _titleOutlineWidth = 13.075;
const _titleSkewDegrees = -10.0;
const _dialogEntranceDuration = Duration(milliseconds: 280);
const _dialogExitDuration = Duration(milliseconds: 200);
const _titleEntranceDelay = Duration(milliseconds: 120);
const _titleEntranceDuration = Duration(milliseconds: 160);
const _printStartDelay = Duration(milliseconds: 400);
const _badgeEntranceDuration = Duration(milliseconds: 160);

Future<void> showBlindBoxDialog(
  BuildContext context, {
  required List<BlindBoxReward> rewards,
  TemplateItem? template,
  Future<void> Function()? onOpenTemplate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '关闭盲盒弹窗',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => BlindBoxDialog(
      rewards: rewards,
      template: template,
      onOpenTemplate: onOpenTemplate,
    ),
  );
}

class BlindBoxDialog extends StatefulWidget {
  final List<BlindBoxReward> rewards;
  final TemplateItem? template;
  final Future<void> Function()? onOpenTemplate;

  const BlindBoxDialog({
    super.key,
    required this.rewards,
    this.template,
    this.onOpenTemplate,
  });

  @override
  State<BlindBoxDialog> createState() => _BlindBoxDialogState();
}

class _BlindBoxDialogState extends State<BlindBoxDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _backdropOpacity;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _panelScale;
  late final Animation<Offset> _panelOffset;
  bool _reduceMotion = false;
  bool _isDismissing = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: _dialogEntranceDuration,
      reverseDuration: _dialogExitDuration,
    );
    _backdropOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _panelOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    _panelScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _panelOffset =
        Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _entranceController.value = 1;
    } else if (!_isDismissing && _entranceController.isDismissed) {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;

    if (_reduceMotion) {
      _entranceController.value = 0;
    } else {
      await _entranceController.reverse();
    }

    if (!mounted) return;
    _allowPop = true;
    Navigator.of(context).pop();
  }

  Future<bool> _handleSystemDismiss() async {
    if (_allowPop) return true;
    await _dismiss();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleSystemDismiss,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: _backdropOpacity,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismiss,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const ColoredBox(color: Color(0x99000000)),
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = math.min(
                  1,
                  math.min(
                    constraints.maxWidth / _designWidth,
                    constraints.maxHeight / _designHeight,
                  ),
                );

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: SlideTransition(
                    position: _panelOffset,
                    child: ScaleTransition(
                      scale: _panelScale,
                      child: FadeTransition(
                        opacity: _panelOpacity,
                        child: SizedBox(
                          width: _designWidth * scale,
                          height: _designHeight * scale,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              width: _designWidth,
                              height: _designHeight,
                              child: _BlindBoxSheet(
                                rewards: widget.rewards,
                                template: widget.template,
                                onDismiss: _dismiss,
                                onOpenTemplate: widget.onOpenTemplate,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BlindBoxSheet extends StatefulWidget {
  final List<BlindBoxReward> rewards;
  final TemplateItem? template;
  final Future<void> Function() onDismiss;
  final Future<void> Function()? onOpenTemplate;

  const _BlindBoxSheet({
    required this.rewards,
    this.template,
    required this.onDismiss,
    this.onOpenTemplate,
  });

  @override
  State<_BlindBoxSheet> createState() => _BlindBoxSheetState();
}

class _BlindBoxSheetState extends State<_BlindBoxSheet>
    with TickerProviderStateMixin {
  final math.Random _random = math.Random();
  late final AnimationController _printController;
  late final AnimationController _titleController;
  late final AnimationController _badgeController;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleScale;
  late final Animation<double> _badgeOpacity;
  bool _hasStartedEntrance = false;
  bool _reduceMotion = false;
  bool _isDrawingAgain = false;
  late BlindBoxReward _reward;

  @override
  void initState() {
    super.initState();
    _reward = _nextReward();
    _printController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _titleController = AnimationController(
      vsync: this,
      duration: _titleEntranceDuration,
    );
    _badgeController = AnimationController(
      vsync: this,
      duration: _badgeEntranceDuration,
    );
    _titleOpacity = CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOutCubic,
    );
    _titleScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutBack),
    );
    _badgeOpacity = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStartedEntrance) return;

    _hasStartedEntrance = true;
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _titleController.value = 1;
      _printController.value = 1;
      _badgeController.value = 1;
    } else {
      _playEntrance();
    }
  }

  @override
  void dispose() {
    _printController.dispose();
    _titleController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  Future<void> _playEntrance() async {
    await Future<void>.delayed(_titleEntranceDelay);
    if (!mounted) return;
    _titleController.forward();

    await Future<void>.delayed(_printStartDelay - _titleEntranceDelay);
    if (!mounted) return;
    await _printController.forward();
    if (!mounted) return;
    _badgeController.forward();
  }

  BlindBoxReward _nextReward({BlindBoxReward? excluding}) {
    if (widget.rewards.isEmpty) return _fallbackReward;
    if (widget.rewards.length == 1) return widget.rewards.single;

    BlindBoxReward reward;
    do {
      reward = widget.rewards[_random.nextInt(widget.rewards.length)];
    } while (identical(reward, excluding));
    return reward;
  }

  Future<void> _drawAgain() async {
    if (_isDrawingAgain) return;
    _isDrawingAgain = true;
    _badgeController.value = 0;
    setState(() => _reward = _nextReward(excluding: _reward));

    if (_reduceMotion) {
      _printController.value = 1;
      _badgeController.value = 1;
    } else {
      await _printController.forward(from: 0);
      if (mounted) _badgeController.forward();
    }
    _isDrawingAgain = false;
  }

  Future<void> _openTemplate() async {
    await widget.onDismiss();
    await widget.onOpenTemplate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final categoryPresentation = template == null
        ? const TemplateCategoryPresentation()
        : TemplateCategoryPresentations.resolve(template);
    final reward = _reward.copyWith(
      patternAsset: categoryPresentation.patternAsset,
      titleIconAsset: categoryPresentation.titleIconAsset,
    );
    final titleGradientEndColor = categoryPresentation.titleGradientEndColor;
    final titleGradient = titleGradientEndColor == null
        ? reward.resolvedRarityGradient
        : LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.white, Color(titleGradientEndColor)],
            stops: const [0, 0.89359],
          );
    final previewUrl = template == null
        ? ''
        : template.previewUrl.trim().isNotEmpty
        ? template.previewUrl
        : template.thumbnailUrl;

    return ClipRRect(
      key: const ValueKey('blind-box-dialog'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: Colors.white,
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              width: 390,
              height: 500,
              child: Image(
                image: AssetImage('assets/figma_home/blind_box/background.png'),
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: 61.5,
              top: 80,
              width: 267,
              height: 68,
              child: FadeTransition(
                opacity: _titleOpacity,
                child: ScaleTransition(
                  scale: _titleScale,
                  child: _BlindBoxTitle(
                    rarityLabel: categoryPresentation.displayCopy(
                      template?.categoryName ?? '',
                      fallback: reward.rarityLabel,
                    ),
                    rarityGradient: titleGradient,
                    titleIconAsset: reward.titleIconAsset,
                    titleIconLeft: categoryPresentation.titleIconLeft,
                    titleIconTop: categoryPresentation.titleIconTop,
                    titleIconWidth: categoryPresentation.titleIconWidth,
                    titleIconHeight: categoryPresentation.titleIconHeight,
                    titleIconAngleDegrees:
                        categoryPresentation.titleIconAngleDegrees,
                    titleIconFill: categoryPresentation.titleIconFill,
                    titleIconFlipX: categoryPresentation.titleIconFlipX,
                    titleIconOutlineScale:
                        categoryPresentation.titleIconOutlineScale,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 10,
              child: Semantics(
                button: true,
                label: '关闭盲盒弹窗',
                child: GestureDetector(
                  key: const ValueKey('blind-box-close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onDismiss(),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: SvgPicture.asset(
                        'assets/figma_home/blind_box/close.svg',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 30,
              top: _printerSlotTop,
              width: 330,
              height: _printerSlotHeight,
              child: DecoratedBox(
                key: ValueKey('blind-box-printer-slot'),
                decoration: ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.5, 0),
                    end: Alignment(0.5, 1),
                    colors: [
                      Color(0xFFFFD557),
                      Color(0xFFFFEF1C),
                      Color(0xFFFFE91A),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(width: 3, color: Colors.white),
                    borderRadius: BorderRadius.all(Radius.circular(106)),
                  ),
                ),
              ),
            ),
            _PrintingPattern(
              pattern: reward.patternAsset,
              imageUrl: previewUrl,
              progress: CurvedAnimation(
                parent: _printController,
                curve: Curves.easeOutCubic,
              ),
            ),
            Positioned(
              right: 20,
              top: 470 + categoryPresentation.badgeOffsetY,
              width: 70,
              height: 40,
              child: FadeTransition(
                opacity: _badgeOpacity,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(),
                  child: _BlindBoxBadge(
                    fallbackAsset: reward.patternBadgeAsset,
                    badgeAsset: categoryPresentation.badgeAsset,
                    badgeAssetLeft: categoryPresentation.badgeAssetLeft,
                    badgeAssetTop: categoryPresentation.badgeAssetTop,
                    badgeAssetWidth: categoryPresentation.badgeAssetWidth,
                    badgeAssetHeight: categoryPresentation.badgeAssetHeight,
                    heartAsset: categoryPresentation.badgeHeartAsset,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 150,
              top: 532,
              width: 90,
              height: 36,
              child: Semantics(
                button: true,
                label: '再抽一次',
                child: GestureDetector(
                  key: const ValueKey('blind-box-retry'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _drawAgain(),
                  child: const Center(
                    child: Text(
                      '再抽一次',
                      style: TextStyle(
                        color: Color(0x99000000),
                        decoration: TextDecoration.underline,
                        fontFamily: _roundFontFamily,
                        fontFamilyFallback: _fontFallbacks,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 18 / 14,
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
              height: 100,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BlindBoxActionButton(
                          key: const ValueKey('blind-box-open-now'),
                          label: '立即开拼',
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          borderColor: const Color(0x1F000000),
                          onTap: _openTemplate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BlindBoxActionButton(
                          key: const ValueKey('blind-box-accept'),
                          label: '开心收下',
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black,
                          onTap: () => widget.onDismiss(),
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

class _BlindBoxTitle extends StatelessWidget {
  final String rarityLabel;
  final Gradient rarityGradient;
  final String titleIconAsset;
  final double? titleIconLeft;
  final double? titleIconTop;
  final double? titleIconWidth;
  final double? titleIconHeight;
  final double? titleIconAngleDegrees;
  final bool titleIconFill;
  final bool titleIconFlipX;
  final double titleIconOutlineScale;

  const _BlindBoxTitle({
    required this.rarityLabel,
    required this.rarityGradient,
    required this.titleIconAsset,
    this.titleIconLeft,
    this.titleIconTop,
    this.titleIconWidth,
    this.titleIconHeight,
    this.titleIconAngleDegrees,
    this.titleIconFill = false,
    this.titleIconFlipX = false,
    this.titleIconOutlineScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -1.58,
          top: 35.73,
          width: 17.641,
          height: 13.657,
          child: _TitleSpark(
            assetPath: 'assets/figma_home/blind_box/title_spark_primary.png',
            angleDegrees: -9.59,
            width: 16.008,
            height: 11.145,
            padding: EdgeInsets.fromLTRB(1.383, 0.832, 0.626, 0.335),
          ),
        ),
        Positioned(
          left: 1.56,
          top: 45.65,
          width: 13.976,
          height: 11.576,
          child: _TitleSpark(
            assetPath: 'assets/figma_home/blind_box/title_spark_secondary.png',
            angleDegrees: 0,
            width: 11.977,
            height: 7.751,
            padding: EdgeInsets.fromLTRB(0.368, 0.827, 0.284, 0.233),
          ),
        ),
        const Positioned(
          left: 8.88,
          top: 7.5,
          child: _OutlinedTitleText(
            '恭喜你！',
            fillGradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.white, Color(0xFFFFFAE0)],
              stops: [0, 0.89359],
            ),
            style: TextStyle(
              color: Colors.white,
              fontSize: 21.25,
              fontFamily: _pixelFontFamily,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 4.25,
            ),
          ),
        ),
        Positioned(
          left: 102,
          top: 25,
          child: _OutlinedTitleText(
            rarityLabel,
            fillGradient: rarityGradient,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32.875,
              fontFamily: _pixelFontFamily,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 3.1875,
            ),
          ),
        ),
        const Positioned(
          left: 26,
          top: 37,
          child: _OutlinedTitleText(
            '拆出了',
            style: TextStyle(
              color: Color(0xFFFFFEFA),
              fontSize: 21.25,
              fontFamily: _pixelFontFamily,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 3.19,
            ),
          ),
        ),
        Positioned(
          left: titleIconLeft ?? 205,
          top: titleIconTop ?? 13,
          width: titleIconWidth ?? 61,
          height: titleIconHeight ?? 26,
          child: Transform.rotate(
            angle: (titleIconAngleDegrees ?? 0) * math.pi / 180,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(titleIconFlipX ? -1 : 1, 1, 1),
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  if (titleIconOutlineScale > 1)
                    Transform.scale(
                      scale: titleIconOutlineScale,
                      child: _BlindBoxAsset(
                        assetPath: titleIconAsset,
                        fit: titleIconFill ? BoxFit.fill : BoxFit.contain,
                        tintColor: Colors.black,
                      ),
                    ),
                  _BlindBoxAsset(
                    assetPath: titleIconAsset,
                    fit: titleIconFill ? BoxFit.fill : BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 209,
          top: 39,
          child: _OutlinedTitleText(
            '图纸',
            style: TextStyle(
              color: Color(0xFFFFF8D3),
              fontSize: 21.25,
              fontFamily: _pixelFontFamily,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 3.19,
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleSpark extends StatelessWidget {
  final String assetPath;
  final double angleDegrees;
  final double width;
  final double height;
  final EdgeInsets padding;

  const _TitleSpark({
    required this.assetPath,
    required this.angleDegrees,
    required this.width,
    required this.height,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: angleDegrees * math.pi / 180,
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: padding,
            child: Image.asset(assetPath, fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }
}

class _BlindBoxAsset extends StatelessWidget {
  final String assetPath;
  final BoxFit fit;
  final Color? tintColor;

  const _BlindBoxAsset({
    required this.assetPath,
    required this.fit,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final Widget asset;
    if (assetPath.toLowerCase().endsWith('.svg')) {
      asset = SvgPicture.asset(assetPath, fit: fit);
    } else {
      asset = Image.asset(assetPath, fit: fit);
    }

    final color = tintColor;
    if (color == null) return asset;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: asset,
    );
  }
}

/// The Figma “超可爱” badge is two overlapping hearts, while other rarities
/// retain their existing bitmap badge.
class _BlindBoxBadge extends StatelessWidget {
  final String fallbackAsset;
  final String? badgeAsset;
  final double? badgeAssetLeft;
  final double? badgeAssetTop;
  final double? badgeAssetWidth;
  final double? badgeAssetHeight;
  final String? heartAsset;

  const _BlindBoxBadge({
    required this.fallbackAsset,
    this.badgeAsset,
    this.badgeAssetLeft,
    this.badgeAssetTop,
    this.badgeAssetWidth,
    this.badgeAssetHeight,
    this.heartAsset,
  });

  @override
  Widget build(BuildContext context) {
    final configuredBadgeAsset = badgeAsset;
    if (configuredBadgeAsset != null && configuredBadgeAsset.isNotEmpty) {
      final left = badgeAssetLeft;
      final top = badgeAssetTop;
      final width = badgeAssetWidth;
      final height = badgeAssetHeight;
      if (left != null && top != null && width != null && height != null) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              height: height,
              child: _BlindBoxAsset(
                assetPath: configuredBadgeAsset,
                fit: BoxFit.fill,
              ),
            ),
          ],
        );
      }

      return _BlindBoxAsset(
        assetPath: configuredBadgeAsset,
        fit: BoxFit.contain,
      );
    }

    final asset = heartAsset;
    if (asset == null || asset.isEmpty) {
      return _BlindBoxAsset(assetPath: fallbackAsset, fit: BoxFit.contain);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _FigmaBadgeHeart(assetPath: asset, left: -3.78, top: -1.04),
        _FigmaBadgeHeart(assetPath: asset, left: 24.34, top: -4.89),
      ],
    );
  }
}

class _FigmaBadgeHeart extends StatelessWidget {
  final String assetPath;
  final double left;
  final double top;

  const _FigmaBadgeHeart({
    required this.assetPath,
    required this.left,
    required this.top,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: 45.14,
      height: 42.536,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2.35,
            top: 3.44,
            width: 37.928,
            height: 36.444,
            child: Center(
              child: Transform.rotate(
                angle: -23.33 * math.pi / 180,
                child: SizedBox(
                  width: 35.2546,
                  height: 32.412,
                  child: SvgPicture.asset(
                    'assets/figma_home/blind_box/badge_super_cute_heart_edge_outer.svg',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0.51,
            top: 3.84,
            width: 35.502,
            height: 32.065,
            child: Center(
              child: Transform.rotate(
                angle: 0.38 * math.pi / 180,
                child: SizedBox(
                  width: 35.293,
                  height: 31.833,
                  child: Image.asset(assetPath, fit: BoxFit.fill),
                ),
              ),
            ),
          ),
          Positioned(
            left: 2.35,
            top: 3.44,
            width: 37.928,
            height: 36.444,
            child: Center(
              child: Transform.rotate(
                angle: -23.33 * math.pi / 180,
                child: SizedBox(
                  width: 29.7158,
                  height: 26.8735,
                  child: SvgPicture.asset(
                    'assets/figma_home/blind_box/badge_super_cute_heart_edge_inner.svg',
                    fit: BoxFit.fill,
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

class _OutlinedTitleText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient? fillGradient;

  const _OutlinedTitleText(this.text, {required this.style, this.fillGradient});

  @override
  Widget build(BuildContext context) {
    final outlineStyle = style.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _titleOutlineWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = Colors.black,
    );

    final fill = Text(text, style: style);
    final fillWidget = fillGradient == null
        ? fill
        : ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: fillGradient!.createShader,
            child: fill,
          );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(_titleSkewDegrees * math.pi / 180),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(text, style: outlineStyle),
          fillWidget,
        ],
      ),
    );
  }
}

class _PrintingPattern extends StatelessWidget {
  final String pattern;
  final String imageUrl;
  final Animation<double> progress;

  const _PrintingPattern({
    required this.pattern,
    required this.imageUrl,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 45,
      top: _printedPaperTop,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          return SizedBox(
            key: const ValueKey('blind-box-printed-paper'),
            width: 300,
            height: 300 * progress.value,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x51F9C43C),
                          offset: Offset(3, 4),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
                ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: 300,
                    maxWidth: 300,
                    minHeight: 300,
                    maxHeight: 300,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl.isEmpty &&
                            pattern != patternDisplayPlaceholderAsset)
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              const PatternDisplayPlaceholder(),
                              Image.asset(
                                pattern,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.expand(),
                              ),
                            ],
                          )
                        else
                          const PatternDisplayPlaceholder(),
                        if (imageUrl.isNotEmpty)
                          Image.network(
                            imageUrl,
                            key: const ValueKey('blind-box-template-preview'),
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, _, _) => const SizedBox.expand(),
                          ),
                        const Positioned(
                          left: 0,
                          top: _paperMaskTop,
                          width: 300,
                          height: 14,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(0.5, 0),
                                end: Alignment(0.5, 1),
                                colors: [Color(0x99FAC239), Color(0x00FAC239)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BlindBoxActionButton extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _BlindBoxActionButton({
    super.key,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(44),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                offset: Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontFamily: _roundFontFamily,
                fontFamilyFallback: _fontFallbacks,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
