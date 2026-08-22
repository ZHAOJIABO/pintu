import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/draft_project.dart';
import '../services/api/api_models.dart';
import '../services/api/api_scope.dart';
import '../services/image_service.dart';
import '../widgets/blind_box_dialog.dart';
import '../widgets/home_filter_dialog.dart';
import '../widgets/home_pattern_gallery.dart';
import '../widgets/pattern_display_placeholder.dart';
import 'crop_screen.dart';
import 'my_screen.dart';
import 'result_screen.dart';

const _pixelFontFamily = 'Z Labs RoundPix 12px M CN';
const _roundFontFamily = 'Alimama FangYuanTi VF';
const _scriptFontFamily = 'Taprom';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _designWidth = 390.0;
const _designContentHeight = 1162.0;
const _bottomNavDesignHeight = 80.0;
const _compactBottomNavDesignHeight = 60.0;
const _compactHeightBreakpoint = 700.0;
const _homeBackgroundColor = Color(0xFFF0F0F4);
const _scrollBottomPadding = 12.0;
const _galleryColumnCount = 3;
const _galleryPageSize = 20;
const _homeGalleryTop = 525.0;
const _homeGalleryTitleAndSpacingHeight = 32.0;
const _homeGalleryTileSize = 119.33;
const _homeGalleryTileSpacing = 4.0;
const _homeGalleryAuthorHeight = 21.2;

double _homeContentHeightForTemplateCount(int templateCount) {
  final rowCount =
      (templateCount + _galleryColumnCount - 1) ~/ _galleryColumnCount;
  if (rowCount == 0) return _designContentHeight;

  final galleryHeight =
      rowCount * (_homeGalleryTileSize + _homeGalleryAuthorHeight) +
      (rowCount - 1) * _homeGalleryTileSpacing;
  return math.max(
    _designContentHeight,
    _homeGalleryTop + _homeGalleryTitleAndSpacingHeight + galleryHeight + 12,
  );
}

class _HomeLayoutMetrics {
  final double pageWidth;
  final double scale;
  final double designContentHeight;
  final double scaledDesignHeight;
  final double bottomNavDesignHeight;
  final double bottomNavTotalHeight;

  _HomeLayoutMetrics({
    required BoxConstraints constraints,
    required this.designContentHeight,
  }) : pageWidth = math.min(constraints.maxWidth, _designWidth),
       scale = math.min(constraints.maxWidth, _designWidth) / _designWidth,
       scaledDesignHeight =
           designContentHeight *
           (math.min(constraints.maxWidth, _designWidth) / _designWidth),
       bottomNavDesignHeight = constraints.maxHeight <= _compactHeightBreakpoint
           ? _compactBottomNavDesignHeight
           : _bottomNavDesignHeight,
       bottomNavTotalHeight =
           (constraints.maxHeight <= _compactHeightBreakpoint
               ? _compactBottomNavDesignHeight
               : _bottomNavDesignHeight) *
           (math.min(constraints.maxWidth, _designWidth) / _designWidth);
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  static const _blindBoxRewards = [
    BlindBoxReward(
      patternAsset: patternDisplayPlaceholderAsset,
      rarity: BlindBoxRarity.superRare,
      titleIconAsset: 'assets/figma_home/blind_box/union.png',
      patternBadgeAsset: 'assets/figma_home/blind_box/badge.png',
    ),
  ];

  final ImageService _imageService = ImageService();
  BackendServices? _backendServices;
  List<TemplateItem> _galleryTemplates = const [];
  String _galleryCategoryName = '全部';
  int? _galleryCategoryId;
  int _galleryRequestVersion = 0;
  int _galleryPage = 1;
  bool _galleryHasMore = false;
  bool _galleryLoadingMore = false;
  bool _picking = false;
  bool _openingBlindBox = false;
  bool _loadingBlindBoxQuota = false;
  BlindBoxQuota? _blindBoxQuota;
  bool _showingMyPage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = BackendScope.maybeOf(context);
    if (identical(services, _backendServices)) return;

    _backendServices = services;
    if (services != null) {
      _loadGalleryTemplates(services);
      _loadBlindBoxQuota(services);
    }
  }

  Future<void> _loadBlindBoxQuota(BackendServices services) async {
    if (mounted && identical(_backendServices, services)) {
      setState(() => _loadingBlindBoxQuota = true);
    }
    try {
      final quota = await services.templates.getRandomQuota();
      if (!mounted || !identical(_backendServices, services)) return;
      setState(() => _blindBoxQuota = quota);
    } catch (_) {
      // The card stays disabled until a server-authoritative allowance is
      // available; never infer the remaining count locally.
    } finally {
      if (mounted && identical(_backendServices, services)) {
        setState(() => _loadingBlindBoxQuota = false);
      }
    }
  }

  String _blindBoxQuotaText() {
    final quota = _blindBoxQuota;
    if (_loadingBlindBoxQuota) return '正在获取今日次数';
    if (quota == null) return '次数暂不可用';
    if (quota.canDraw) return '今日剩余 ${quota.remaining} 次';
    return '今日剩余 0 次 · ${_blindBoxResetText(quota.resetAt)}';
  }

  String _blindBoxResetText(int resetAt) {
    if (resetAt <= 0) return '明日 00:00 恢复';

    // The server fixes reset time to UTC+8. This label is presentation-only;
    // the server remains the sole authority for whether a draw is allowed.
    final reset = DateTime.fromMillisecondsSinceEpoch(
      resetAt * Duration.millisecondsPerSecond,
      isUtc: true,
    ).add(const Duration(hours: 8));
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final resetDate = DateTime(reset.year, reset.month, reset.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysUntilReset = resetDate.difference(today).inDays;
    if (daysUntilReset == 1) return '明日 00:00 恢复';
    if (daysUntilReset == 0) return '今日 00:00 恢复';
    return '${reset.month}月${reset.day}日 00:00 恢复';
  }

  Future<void> _loadGalleryTemplates(
    BackendServices services, {
    int? categoryId,
  }) async {
    final requestVersion = ++_galleryRequestVersion;
    if (mounted && identical(_backendServices, services)) {
      setState(() => _galleryLoadingMore = true);
    }
    try {
      final result = await services.loadHomeTemplates(
        categoryId: categoryId,
        pageSize: _galleryPageSize,
      );
      if (!mounted ||
          !identical(_backendServices, services) ||
          requestVersion != _galleryRequestVersion) {
        return;
      }
      setState(() {
        _galleryTemplates = result.items;
        _galleryPage = result.page.page;
        _galleryHasMore = result.page.hasMore;
        _galleryLoadingMore = false;
      });
    } catch (_) {
      if (mounted &&
          identical(_backendServices, services) &&
          requestVersion == _galleryRequestVersion) {
        setState(() => _galleryLoadingMore = false);
      }
      // Keep the existing local thumbnails when the gallery cannot load.
    }
  }

  Future<void> _loadMoreGalleryTemplates() async {
    final services = _backendServices;
    if (services == null ||
        !_galleryHasMore ||
        _galleryLoadingMore ||
        _showingMyPage) {
      return;
    }

    final requestVersion = _galleryRequestVersion;
    final nextPage = _galleryPage + 1;
    setState(() => _galleryLoadingMore = true);
    try {
      final result = await services.loadHomeTemplates(
        categoryId: _galleryCategoryId,
        page: nextPage,
        pageSize: _galleryPageSize,
      );
      if (!mounted ||
          !identical(_backendServices, services) ||
          requestVersion != _galleryRequestVersion ||
          _showingMyPage) {
        return;
      }

      final mergedTemplates = _mergeGalleryTemplates(
        _galleryTemplates,
        result.items,
      );
      final madeProgress = mergedTemplates.length > _galleryTemplates.length;
      final receivedExpectedPage = result.page.page == nextPage;
      setState(() {
        _galleryTemplates = mergedTemplates;
        _galleryPage = nextPage;
        _galleryHasMore =
            receivedExpectedPage && madeProgress && result.page.hasMore;
        _galleryLoadingMore = false;
      });
    } catch (_) {
      if (mounted &&
          identical(_backendServices, services) &&
          requestVersion == _galleryRequestVersion &&
          !_showingMyPage) {
        setState(() => _galleryLoadingMore = false);
      }
      // Keep the loaded templates visible; another trip to the bottom retries.
    }
  }

  List<TemplateItem> _mergeGalleryTemplates(
    List<TemplateItem> current,
    List<TemplateItem> incoming,
  ) {
    final templatesById = <String, TemplateItem>{
      for (final template in current) template.templateId: template,
    };
    for (final template in incoming) {
      templatesById[template.templateId] = template;
    }
    return templatesById.values.toList();
  }

  bool _onHomeScroll(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification is ScrollUpdateNotification &&
        notification.metrics.extentAfter <= 200) {
      unawaited(_loadMoreGalleryTemplates());
    }
    return false;
  }

  Future<void> _openTemplateDetail(String templateId) async {
    final services = _backendServices;
    if (services == null || templateId.isEmpty) return;

    try {
      final detail = await services.templates.getTemplate(templateId);
      if (!mounted || !identical(_backendServices, services)) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            pattern: detail.patternData.toGeneratedPattern(),
            template: detail.template,
          ),
        ),
      );
    } catch (_) {
      // Keep the gallery usable when the template cannot be opened.
    }
  }

  Future<void> _pickImage({
    required DraftImageSource imageSource,
    ImageSource source = ImageSource.gallery,
  }) async {
    setState(() => _picking = true);
    try {
      final file = await _imageService.pickImage(source: source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CropScreen(
            draft: DraftProject(
              originalImageBytes: bytes,
              imageSource: imageSource,
            ),
          ),
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

  Future<void> _openBlindBox() async {
    final services = _backendServices;
    final quota = _blindBoxQuota;
    if (services == null ||
        _openingBlindBox ||
        quota == null ||
        !quota.canDraw) {
      return;
    }
    final drawQuota = quota;

    setState(() => _openingBlindBox = true);
    try {
      final detail = await services.templates.getRandomTemplate();
      if (!mounted || !identical(_backendServices, services)) return;
      setState(() => _blindBoxQuota = detail.quota);
      await showBlindBoxDialog(
        context,
        rewards: _blindBoxRewards,
        template: detail.template,
        onOpenTemplate: () async {
          if (!mounted || !identical(_backendServices, services)) return;
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                pattern: detail.patternData.toGeneratedPattern(),
                template: detail.template,
              ),
            ),
          );
        },
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 2007) {
        setState(
          () => _blindBoxQuota = drawQuota.copyWith(
            remaining: 0,
            used: drawQuota.dailyLimit,
          ),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('今日盲盒次数已用完，明天再来吧')));
        return;
      }
      await _loadBlindBoxQuota(services);
      if (!mounted || !identical(_backendServices, services)) return;
      final message = error.code == 1002 ? '盲盒暂时没有可抽图纸，请稍后再试' : '盲盒加载失败，请重试';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      await _loadBlindBoxQuota(services);
      if (!mounted || !identical(_backendServices, services)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('盲盒加载失败，请重试')));
    } finally {
      if (mounted) setState(() => _openingBlindBox = false);
    }
  }

  Future<void> _openFilterDialog() async {
    final selection = await showHomeFilterDialog(
      context,
      loadCategories: _backendServices?.loadTemplateCategories,
      selectedCategoryId: _galleryCategoryId,
    );
    final services = _backendServices;
    if (selection != null && services != null) {
      setState(() {
        _galleryCategoryId = selection.isDefault
            ? null
            : selection.category.categoryId;
        _galleryCategoryName = selection.isDefault
            ? '全部'
            : selection.category.name;
      });
      await _loadGalleryTemplates(services, categoryId: _galleryCategoryId);
    }
  }

  void _showMyPage() {
    setState(() => _showingMyPage = true);
  }

  void _showHomePage() => setState(() => _showingMyPage = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _homeBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _HomeLayoutMetrics(
            constraints: constraints,
            designContentHeight: _homeContentHeightForTemplateCount(
              _galleryTemplates.length,
            ),
          );

          return Center(
            child: SizedBox(
              width: metrics.pageWidth,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: _homeBackgroundColor),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    bottom: metrics.bottomNavTotalHeight,
                    child: IndexedStack(
                      index: _showingMyPage ? 1 : 0,
                      sizing: StackFit.expand,
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: _onHomeScroll,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: SizedBox(
                              width: metrics.pageWidth,
                              height:
                                  metrics.scaledDesignHeight +
                                  _scrollBottomPadding,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: _ScaledDesignSurface(
                                  designWidth: _designWidth,
                                  designHeight: metrics.designContentHeight,
                                  scale: metrics.scale,
                                  child: _HomeDesignCanvas(
                                    designContentHeight:
                                        metrics.designContentHeight,
                                    picking: _picking,
                                    galleryTemplates: _galleryTemplates,
                                    galleryCategoryName: _galleryCategoryName,
                                    onGalleryTemplateTap: _openTemplateDetail,
                                    onPhotoStart: _picking
                                        ? null
                                        : () => _pickImage(
                                            imageSource: DraftImageSource.photo,
                                          ),
                                    onIllustrationStart: _picking
                                        ? null
                                        : () => _pickImage(
                                            imageSource:
                                                DraftImageSource.illustration,
                                          ),
                                    blindBoxQuotaText: _blindBoxQuotaText(),
                                    onBlindBox:
                                        _openingBlindBox ||
                                            _loadingBlindBoxQuota ||
                                            _blindBoxQuota?.canDraw != true
                                        ? null
                                        : _openBlindBox,
                                    onFilter: _openFilterDialog,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 即使用户仍停留在首页，也提前挂载“我的”页：其中的
                        // 首张图纸/收藏请求会在 App 启动时开始，切页无需等待。
                        const MyScreenContent(),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: metrics.bottomNavTotalHeight,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _ScaledDesignSurface(
                        designWidth: _designWidth,
                        designHeight: metrics.bottomNavDesignHeight,
                        scale: metrics.scale,
                        child: _showingMyPage
                            ? MyBottomNavigation(
                                height: metrics.bottomNavDesignHeight,
                                onMakeTap: _showHomePage,
                              )
                            : _BottomNavigation(
                                height: metrics.bottomNavDesignHeight,
                                onMyTap: _showMyPage,
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
    this.scale = 1,
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

class _HomeDesignCanvas extends StatelessWidget {
  final double designContentHeight;
  final bool picking;
  final List<TemplateItem> galleryTemplates;
  final String galleryCategoryName;
  final ValueChanged<String>? onGalleryTemplateTap;
  final VoidCallback? onPhotoStart;
  final VoidCallback? onIllustrationStart;
  final VoidCallback? onBlindBox;
  final String blindBoxQuotaText;
  final VoidCallback? onFilter;

  const _HomeDesignCanvas({
    required this.designContentHeight,
    required this.picking,
    required this.galleryTemplates,
    required this.galleryCategoryName,
    required this.onGalleryTemplateTap,
    required this.onPhotoStart,
    required this.onIllustrationStart,
    required this.onBlindBox,
    required this.blindBoxQuotaText,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _designWidth,
      height: designContentHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            top: 0,
            width: 390,
            height: 480,
            child: Image(
              image: AssetImage('assets/figma_home/home_header.png'),
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
                    Color(0x00F0F0F4),
                    Color(0x00F0F0F4),
                    _homeBackgroundColor,
                  ],
                  stops: [0, 0.48, 0.66],
                ),
              ),
            ),
          ),
          _HeroCard(picking: picking, onStart: onPhotoStart),
          Positioned(
            left: 12,
            top: 360.55,
            child: _FeatureCard(
              icon: 'assets/figma_home/feature_illustration_icon.png',
              textImage: 'assets/figma_home/feature_illustration_text.png',
              onTap: onIllustrationStart,
            ),
          ),
          Positioned(
            left: 201,
            top: 360.55,
            child: _FeatureCard(
              key: const ValueKey('home-blind-box-card'),
              icon: 'assets/figma_home/feature_blind_box_icon.png',
              textImage: 'assets/figma_home/feature_blind_box_text.png',
              footerText: blindBoxQuotaText,
              onTap: onBlindBox,
            ),
          ),
          Positioned(
            left: 12,
            top: 525,
            child: HomePatternGallery(
              templates: galleryTemplates,
              categoryName: galleryCategoryName,
              onFilter: onFilter ?? () {},
              onTemplateTap: onGalleryTemplateTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _LightPinkRing extends StatelessWidget {
  const _LightPinkRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16.17,
      height: 16.17,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F5F9),
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFFFD6EF), width: 4),
        ),
      ),
    );
  }
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
              const Positioned(left: -13, top: 12, child: _LeftHangerDeco()),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment(0.50, -0.00),
                      end: Alignment(0.50, 1.34),
                      colors: [Color(0xFFFFBCE5), Color(0xFFFF54BD)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3F000000),
                        offset: Offset(0, 2),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // const Positioned(
              //   left: 12.98,
              //   top: 12.42,
              //   child: _DecorativeImage(
              //     asset: 'assets/figma_home/card_hole_141.png',
              //     width: 17,
              //     height: 17,
              //   ),
              // ),
              // const Positioned(
              //   left: 2.52,
              //   top: 32.99,
              //   child: _DecorativeImage(
              //     asset: 'assets/figma_home/card_hole_137.png',
              //     width: 9,
              //     height: 9,
              //   ),
              // ),
              // const Positioned(
              //   left: 5,
              //   top: 33,
              //   child: _DecorativeImage(
              //     asset: 'assets/figma_home/card_hole_142.png',
              //     width: 9,
              //     height: 9,
              //   ),
              // ),
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
                  overlayGradient: false,
                ),
              ),
              const Positioned(
                left: 145.62,
                top: -77.67,
                child: _RotatedPhotoFrame(
                  image: 'assets/figma_home/bead_photo.png',
                  angle: 17.19,
                  outerWidth: 194.67,
                  outerHeight: 197.69,
                  imageWidth: 154.55,
                  imageHeight: 159.12,
                  radius: 15,
                  borderWidth: 1,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(left: 0, top: 46, child: const _HeroUnionLayer()),
              const Positioned(left: -8.59, top: 49.34, child: _TitleBadge()),
              Positioned(
                left: 13.71,
                top: 35.50,
                child: Transform.rotate(
                  angle: -2 * math.pi / 180,
                  child: Transform.scale(
                    scaleX: 1.08,
                    alignment: Alignment.centerLeft,
                    child: const _StickerText(label: '照片转图纸', fontSize: 24.88),
                  ),
                ),
              ),
              Positioned(
                left: -2,
                top: 35,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFE760),
                      width: 3,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 1,
                top: 35,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFBCE5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD62690),
                      width: 3,
                    ),
                  ),
                ),
              ),
              const Positioned(left: 9.98, top: 11.12, child: _LightPinkRing()),
              const Positioned(left: -11, top: 5.51, child: _PinkHangerDeco()),
              const Positioned(left: 18, top: 104, child: _StepPill()),
              Positioned(
                left: 263,
                top: 145,
                child: Transform.rotate(
                  angle: -7.56 * math.pi / 180,
                  child: _StartMakingLabel(label: picking ? '打开中...' : '开始制作'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartMakingLabel extends StatelessWidget {
  final String label;

  const _StartMakingLabel({required this.label});

  static const _style = TextStyle(
    color: Color(0xFF030303),
    fontFamily: _pixelFontFamily,
    fontFamilyFallback: _fontFallbacks,
    fontSize: 19.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.34,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 11, 16, 13),
      child: Stack(
        children: [
          Text(
            label,
            style: _style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 9.5
                ..strokeJoin = StrokeJoin.round
                ..strokeCap = StrokeCap.round
                ..color = const Color(0xFFFFF09A),
            ),
          ),
          Text(label, style: _style),
        ],
      ),
    );
  }
}

class _StartMakingBackgroundPainter extends CustomPainter {
  const _StartMakingBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(24, 3)
      ..lineTo(size.width - 20, 0)
      ..quadraticBezierTo(size.width - 2, 1, size.width - 1, 20)
      ..quadraticBezierTo(size.width + 2, 34, size.width - 13, 39)
      ..quadraticBezierTo(size.width - 18, 52, size.width - 36, 48)
      ..quadraticBezierTo(size.width - 50, 56, size.width - 65, 48)
      ..lineTo(29, 53)
      ..quadraticBezierTo(14, 57, 7, 44)
      ..quadraticBezierTo(-1, 34, 5, 23)
      ..quadraticBezierTo(2, 9, 24, 3)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFFFFF09A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RotatedPhotoFrame extends StatelessWidget {
  final String image;
  final double angle;
  final double outerWidth;
  final double outerHeight;
  final double imageWidth;
  final double imageHeight;
  final double radius;
  final double borderWidth;
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
    this.borderWidth = 4,
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
              border: Border.all(color: Colors.white, width: borderWidth),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - borderWidth),
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
                            Colors.black.withValues(alpha: 0.60),
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
    return SizedBox(
      width: 366,
      height: 151,
      child: ClipPath(
        clipBehavior: Clip.antiAlias,
        clipper: const _HeroPanelClipper(),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: CustomPaint(
            painter: const _HeroPanelPainter(),
            child: const Stack(
              children: [
                Positioned(
                  left: 19.24,
                  top: 109.96,
                  child: Text(
                    'Pinto',
                    style: TextStyle(
                      color: Color(0xFFE74AA6),
                      fontFamily: _scriptFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanelClipper extends CustomClipper<Path> {
  const _HeroPanelClipper();

  @override
  Path getClip(Size size) => _heroPanelPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HeroPanelPainter extends CustomPainter {
  const _HeroPanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _heroPanelPath(size);
    final bounds = Offset.zero & size;

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x4DFF96D8), Color(0x4DEB0081)],
          stops: [0, 0.706532],
        ).createShader(bounds),
    );

    _paintSparklePattern(canvas, size, path);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE8FFE2F4), Color(0x00FFFFFF)],
        ).createShader(bounds),
    );
  }

  void _paintSparklePattern(Canvas canvas, Size size, Path clipPath) {
    canvas.save();
    canvas.clipPath(clipPath);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(309.198 * size.width / 368.439, 0),
        Offset(5.9974 * size.width / 368.439, 146.027 * size.height / 151.173),
        [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0),
        ],
        [0, 0.388839, 1],
      )
      ..style = PaintingStyle.fill;

    const spacing = 9.052;
    for (var y = 3.187; y < size.height + spacing; y += spacing) {
      for (var x = 3.187; x < size.width + spacing; x += spacing) {
        _paintSparkle(canvas, Offset(x, y), paint);
      }
    }
    canvas.restore();
  }

  void _paintSparkle(Canvas canvas, Offset center, Paint paint) {
    const outer = 3.8;
    const inner = 0.36;
    final path = Path()
      ..moveTo(center.dx, center.dy - outer)
      ..lineTo(center.dx + inner, center.dy - inner)
      ..lineTo(center.dx + outer, center.dy)
      ..lineTo(center.dx + inner, center.dy + inner)
      ..lineTo(center.dx, center.dy + outer)
      ..lineTo(center.dx - inner, center.dy + inner)
      ..lineTo(center.dx - outer, center.dy)
      ..lineTo(center.dx - inner, center.dy - inner)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Path _heroPanelPath(Size size) {
  final sx = size.width / 366;
  final sy = size.height / 151;

  double x(double value) => value * sx;
  double y(double value) => value * sy;

  return Path()
    ..moveTo(x(0), y(20))
    ..cubicTo(x(0), y(8.9543), x(8.9543), y(0), x(20), y(0))
    ..lineTo(x(131.208), y(0))
    ..cubicTo(x(135.148), y(0), x(139), y(1.1636), x(142.281), y(3.3448))
    ..lineTo(x(155.094), y(11.8629))
    ..cubicTo(
      x(158.375),
      y(14.0441),
      x(162.227),
      y(15.2077),
      x(166.167),
      y(15.2077),
    )
    ..lineTo(x(199.833), y(15.2077))
    ..cubicTo(
      x(203.773),
      y(15.2077),
      x(207.625),
      y(14.0441),
      x(210.906),
      y(11.8629),
    )
    ..lineTo(x(223.719), y(3.3448))
    ..cubicTo(x(227), y(1.1636), x(230.852), y(0), x(234.792), y(0))
    ..lineTo(x(346), y(0))
    ..cubicTo(x(357.046), y(0), x(366), y(8.9543), x(366), y(20))
    ..lineTo(x(366), y(131))
    ..cubicTo(x(366), y(142.046), x(357.046), y(151), x(346), y(151))
    ..lineTo(x(20), y(151))
    ..cubicTo(x(8.9543), y(151), x(0), y(142.046), x(0), y(131))
    ..close();
}

class _LeftHangerDeco extends StatelessWidget {
  const _LeftHangerDeco();

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1.0, -1.0, 1.0, 1.0),
      child: const SizedBox(
        width: 43,
        height: 43,
        child: CustomPaint(painter: _RightHangerPainter()),
      ),
    );
  }
}

class _PinkHangerDeco extends StatelessWidget {
  const _PinkHangerDeco();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 43,
      height: 43,
      child: CustomPaint(painter: _RightHangerPainter()),
    );
  }
}

class _LeftHangerPainter extends CustomPainter {
  const _LeftHangerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 12.0006, size.height / 20.0003);
    final path = Path()
      ..moveTo(10.5002, 17.4404)
      ..cubicTo(1.23128, 21.5984, -2.85883, 12.9443, 7.97565, 1.5);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF030303)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RightHangerPainter extends CustomPainter {
  const _RightHangerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 34, size.height / 36);
    _drawRightHanger(canvas);
    canvas.restore();
  }

  void _drawRightHanger(Canvas canvas) {
    canvas.save();
    canvas.translate(12, 11);
    canvas.scale(15.920249938964844 / 18.921, 19.285276412963867 / 22.2844);
    final path = Path()
      ..moveTo(11.2119, 1.5372)
      ..cubicTo(23.7119, 0.537121, 15.7294, 19.5144, 1.50009, 20.7843);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF030303)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawRing(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double strokeWidth,
    required Color color,
    Color? fill,
  }) {
    if (fill != null) {
      canvas.drawCircle(center, radius, Paint()..color = fill);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TitleBadge extends StatelessWidget {
  const _TitleBadge();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -13.92 * math.pi / 180,
      child: const SizedBox(
        width: 48.8,
        height: 48.4,
        child: CustomPaint(
          painter: _TitleRabbitPainter(
            accentColor: Color(0xFFFFC516),
            earColor: Color(0xFFFFD951),
            shadowColor: Color(0x21000000),
            shadowBlur: 2,
            accentOffset: Offset(1.46, 2.6),
          ),
        ),
      ),
    );
  }
}

class _TitleRabbitPainter extends CustomPainter {
  final Color accentColor;
  final Color earColor;
  final Color shadowColor;
  final double shadowBlur;
  final Offset accentOffset;

  const _TitleRabbitPainter({
    this.accentColor = const Color(0xFFFFC516),
    this.earColor = const Color(0xFFFFD951),
    this.shadowColor = const Color(0x21000000),
    this.shadowBlur = 2,
    this.accentOffset = const Offset(1.46, 2.6),
  });

  static const _viewBoxWidth = 50.3428;
  static const _viewBoxHeight = 49.7651;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBoxWidth, size.height / _viewBoxHeight);

    final body = _bodyPath();

    final shadowPaint = Paint()..color = shadowColor;
    if (shadowBlur > 0) {
      shadowPaint.maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        shadowBlur,
      );
    }

    canvas.save();
    canvas.translate(3, 4);
    canvas.drawPath(body, shadowPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(accentOffset.dx, accentOffset.dy);
    canvas.drawPath(
      body,
      Paint()
        ..color = accentColor
        ..isAntiAlias = true,
    );
    canvas.restore();

    canvas.drawPath(body, Paint()..color = Colors.white);
    canvas.drawPath(
      body,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.34381
        ..strokeJoin = StrokeJoin.round,
    );

    _drawEar(
      canvas,
      center: const Offset(18.0945, 14.4226),
      rx: 10.3724,
      ry: 3.97903,
      angle: -51.0867,
      color: earColor,
    );
    _drawEar(
      canvas,
      center: const Offset(30.6094, 14.4384),
      rx: 10.9392,
      ry: 4.7409,
      angle: -51.7846,
      color: earColor,
    );

    final eyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.12508
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(11.1024, 27.823),
      const Offset(9.98579, 30.8446),
      eyePaint,
    );
    canvas.drawLine(
      const Offset(19.5079, 28.2136),
      const Offset(18.3912, 31.2352),
      eyePaint,
    );

    canvas.restore();
  }

  Path _bodyPath() {
    return Path()
      ..moveTo(28.7267, 3.75298)
      ..cubicTo(32.8613, 0.983631, 37.1774, 0.301665, 39.8437, 2.41398)
      ..cubicTo(43.7275, 5.49078, 42.6406, 13.3311, 37.416, 19.9262)
      ..cubicTo(35.3438, 22.5418, 32.9302, 24.5663, 30.5318, 25.8681)
      ..cubicTo(31.8716, 27.3218, 32.6414, 29.0166, 32.6414, 30.8273)
      ..cubicTo(32.6414, 36.2209, 25.8206, 40.5932, 17.4067, 40.5932)
      ..cubicTo(8.99274, 40.5932, 2.1719, 36.2209, 2.1719, 30.8273)
      ..cubicTo(2.1719, 27.9753, 4.07907, 25.4089, 7.12045, 23.6235)
      ..cubicTo(6.22066, 19.8209, 7.83138, 14.3633, 11.6326, 9.5652)
      ..cubicTo(16.8574, 2.97039, 24.241, 0.118557, 28.1247, 3.19525)
      ..cubicTo(28.3409, 3.36654, 28.5411, 3.5532, 28.7267, 3.75298)
      ..close();
  }

  void _drawEar(
    Canvas canvas, {
    required Offset center,
    required double rx,
    required double ry,
    required double angle,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TitleRabbitPainter oldDelegate) => true;
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
      transform: Matrix4.skewX(-10 * math.pi / 180)
        ..rotateZ(0.17)
        ..scaleByDouble(1.0, 0.98, 1.0, 1.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _StickerTextLayer(
            label: label,
            fontSize: fontSize,
            color: const Color(0xFF91145F),
            strokeWidth: 5.5,
            letterSpacing: 1.88,
            fontWeight: FontWeight.w700,
            offset: const Offset(4, 5),
          ),
          _StickerTextLayer(
            label: label,
            fontSize: fontSize,
            color: const Color(0xFFD62690),
            strokeWidth: 10,
            letterSpacing: 1.88,
            fontWeight: FontWeight.w700,
          ),
          _StickerTextLayer(
            label: label,
            fontSize: fontSize,
            color: Colors.white,
            letterSpacing: 1.88,
            fontWeight: FontWeight.w700,
            fill: true,
          ),
        ],
      ),
    );
  }
}

class _StickerTextLayer extends StatelessWidget {
  final String label;
  final double fontSize;
  final Color color;
  final double strokeWidth;
  final double letterSpacing;
  final FontWeight fontWeight;
  final Offset offset;
  final bool fill;

  const _StickerTextLayer({
    required this.label,
    required this.fontSize,
    required this.color,
    required this.letterSpacing,
    this.strokeWidth = 0,
    this.fontWeight = FontWeight.w400,
    this.offset = Offset.zero,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: _pixelFontFamily,
      fontFamilyFallback: _fontFallbacks,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
    final text = Text(
      label,
      style: fill
          ? style.copyWith(color: color)
          : style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..color = color,
            ),
    );

    if (offset == Offset.zero) return text;
    return Transform.translate(offset: offset, child: text);
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Step 1', '上传照片'),
      ('Step 2', '转换风格'),
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
  final String? footerText;
  final VoidCallback? onTap;

  const _FeatureCard({
    super.key,
    required this.icon,
    required this.textImage,
    this.footerText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Container(
            width: 177,
            height: 132,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment.center,
                colors: [Color(0xFFFFF9C4), Colors.white],
                radius: 0.57,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(icon, width: 56, height: 56),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        height: 24,
                        child: Image.asset(
                          textImage,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ],
                  ),
                ),
                if (footerText != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 5,
                    child: Text(
                      footerText!,
                      key: const ValueKey('home-blind-box-quota'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0x99000000),
                        fontFamily: _roundFontFamily,
                        fontFamilyFallback: _fontFallbacks,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final double height;
  final VoidCallback? onMyTap;

  const _BottomNavigation({this.height = _bottomNavDesignHeight, this.onMyTap});

  @override
  Widget build(BuildContext context) {
    final labelTop = height <= _compactBottomNavDesignHeight ? 20.0 : 27.0;

    return SizedBox(
      width: 390,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: const ValueKey('bottom-nav-background'),
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
            top: labelTop,
            child: const _NavLabel(label: '制作', selected: true),
          ),
          Positioned(
            right: 83,
            top: labelTop,
            child: GestureDetector(
              key: const ValueKey('home-my-nav-item'),
              behavior: HitTestBehavior.opaque,
              onTap: onMyTap,
              child: const SizedBox(
                width: 48,
                height: 28,
                child: Center(child: _NavLabel(label: '我的', selected: false)),
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
  final bool selected;

  const _NavLabel({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final child = _OutlinedText(
      label,
      fontSize: selected ? 19.2 : 16,
      fillColor: selected ? Colors.white : Colors.white,
      strokeColor: selected ? const Color(0xFFFF55BE) : Colors.black,
      strokeWidth: selected ? 6.6 : 3,
      letterSpacing: 0,
    );
    if (selected) {
      return Transform.rotate(angle: -9 * math.pi / 180, child: child);
    }
    return child;
  }
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final double letterSpacing;

  const _OutlinedText(
    this.text, {
    required this.fontSize,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.letterSpacing,
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
        Text(
          text,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..strokeCap = StrokeCap.round
              ..color = strokeColor,
          ),
        ),
        Text(text, style: baseStyle.copyWith(color: fillColor)),
      ],
    );
  }
}
