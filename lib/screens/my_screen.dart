import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api/api_models.dart';
import '../services/api/api_scope.dart';
import '../services/api/api_session_store.dart';
import '../services/camera_permission_service.dart';
import '../services/crop_service.dart';
import '../widgets/home_filter_dialog.dart';
import '../widgets/home_pattern_gallery.dart';
import '../models/draft_project.dart';
import 'finished_product_camera_screen.dart';
import 'parameter_config_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
import 'upload_screen.dart';

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
const _patternsContentDesignHeight = 700.0;
const _galleryColumnCount = 3;
const _myGalleryTileSize = 350 / _galleryColumnCount;
const _myGalleryTileSpacing = 8.0;

double _patternsContentHeightForItemCount(int itemCount) {
  final rowCount = (itemCount + _galleryColumnCount - 1) ~/ _galleryColumnCount;
  if (rowCount == 0) return _patternsContentDesignHeight;

  final galleryHeight =
      rowCount * _myGalleryTileSize + (rowCount - 1) * _myGalleryTileSpacing;
  const contentBeforeGallery = 4 + 46 + 22 + 194 + 32 + 20 + 12;
  return math.max(
    _patternsContentDesignHeight,
    contentBeforeGallery + galleryHeight + 20,
  );
}

/// Figma “我的”页面。
///
/// 成品区支持展示、加载失败重试和记录拼豆成品。
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

          return Center(
            child: SizedBox(
              width: pageWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Expanded(child: const MyScreenContent()),
                  SizedBox(
                    height: navigationHeightPx,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _ScaledDesignSurface(
                        designWidth: _designWidth,
                        designHeight: navigationHeight,
                        scale: scale,
                        child: MyBottomNavigation(
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

/// “我的”页中位于固定底部导航栏上方的可滚动内容区。
///
/// 该组件同时供独立页面和首页页签切换使用，避免首页切换时推入新路由。
class MyScreenContent extends StatelessWidget {
  const MyScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = math.min(constraints.maxWidth, _designWidth);
        final scale = pageWidth / _designWidth;
        final scrollHeight = math.max(
          constraints.maxHeight,
          _contentDesignHeight * scale,
        );

        return Center(
          child: SizedBox(
            width: pageWidth,
            height: constraints.maxHeight,
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
        );
      },
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

class _MyDesignCanvas extends StatefulWidget {
  const _MyDesignCanvas();

  @override
  State<_MyDesignCanvas> createState() => _MyDesignCanvasState();
}

class _MyDesignCanvasState extends State<_MyDesignCanvas> {
  final CropService _cropService = CropService();
  final CameraPermissionService _cameraPermission =
      const CameraPermissionService();
  BackendServices? _services;
  List<FinishedProductItem> _finishedProducts = const [];
  bool _loadingFinishedProducts = false;
  bool _recording = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = BackendScope.maybeOf(context);
    if (identical(services, _services)) return;
    _services = services;
    if (services != null) {
      _loadFinishedProducts(services);
    }
  }

  Future<void> _loadFinishedProducts(BackendServices services) async {
    setState(() => _loadingFinishedProducts = true);
    try {
      final page = await services.finishedProducts.listFinishedProducts();
      if (!mounted || !identical(_services, services)) return;
      setState(() => _finishedProducts = page.items);
    } catch (_) {
      if (!mounted || !identical(_services, services)) return;
    } finally {
      if (mounted && identical(_services, services)) {
        setState(() => _loadingFinishedProducts = false);
      }
    }
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _recordFinishedProduct() async {
    final services = _services;
    if (services == null || _recording) {
      if (services == null) _showMessage('服务暂未连接，请稍后重试');
      return;
    }

    setState(() => _recording = true);
    try {
      final permission = await _cameraPermission.requestCameraPermission();
      if (!mounted) return;
      if (permission != CameraPermissionResult.granted) {
        final permanentlyDenied =
            permission == CameraPermissionResult.permanentlyDenied;
        _showMessage(
          permanentlyDenied ? '请在系统设置中允许相机权限后再记录成品' : '需要相机权限才能记录成品',
          action: permanentlyDenied
              ? SnackBarAction(
                  label: '去设置',
                  onPressed: () => _cameraPermission.openSettings(),
                )
              : null,
        );
        return;
      }

      final backgroundRemovedPhoto = await Navigator.of(context)
          .push<Uint8List>(
            MaterialPageRoute(
              builder: (_) => const FinishedProductCameraScreen(),
            ),
          );
      if (backgroundRemovedPhoto == null || !mounted) return;

      final export = await _cropService.exportFinishedProduct(
        backgroundRemovedPhoto,
      );
      final requestId = 'finished-${DateTime.now().microsecondsSinceEpoch}';
      final item = await services.finishedProducts.uploadAndCreate(
        bytes: export,
        clientRequestId: requestId,
      );
      if (!mounted || !identical(_services, services)) return;
      setState(() => _finishedProducts = [item, ..._finishedProducts]);
      _showMessage('已记录到我的成品');
    } on ArgumentError {
      if (mounted) _showMessage('照片文件过大，请调整裁切区域后重试');
    } catch (_) {
      if (mounted) _showMessage('记录失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _recording = false);
    }
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
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                radius: 24,
                child: Center(
                  child: Image.asset(
                    'assets/figma_my/settings_icon_frame.png',
                    width: 24,
                    height: 24,
                    filterQuality: FilterQuality.medium,
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
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const MyPatternsScreen()),
                  ),
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
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const MyFavoritesScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 283 + _mainContentVerticalOffset,
            left: 12,
            child: _WorksSection(
              items: _finishedProducts,
              loading: _loadingFinishedProducts,
              recording: _recording,
              onRecordTap: _recordFinishedProduct,
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma “我的图纸”页。
///
/// 下方分类和缩略图网格直接复用首页图库组件，确保图标、筛选和卡片
/// 状态始终一致；后端数据到达前仍保持首页同样的本地图纸占位内容。
class MyPatternsScreen extends StatelessWidget {
  const MyPatternsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MyLibraryScreen(initialTab: _LibraryTab.patterns);
  }
}

/// Figma “我的收藏”页。
class MyFavoritesScreen extends StatelessWidget {
  const MyFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MyLibraryScreen(initialTab: _LibraryTab.favorites);
  }
}

enum _LibraryTab { patterns, favorites }

class _MyLibraryScreen extends StatefulWidget {
  final _LibraryTab initialTab;

  const _MyLibraryScreen({required this.initialTab});

  @override
  State<_MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<_MyLibraryScreen> {
  static const _taskPollingInterval = Duration(seconds: 1);
  static const _recentCreationsPageSize = 20;

  BackendServices? _backendServices;
  List<TemplateItem> _templates = const [];
  List<TemplateItem> _blindBoxHistory = const [];
  List<AIGenerationItem> _recentCreations = const [];
  Set<String> _newCreationIds = const {};
  Set<String> _seenCreationIds = const {};
  Set<String> _retryingCreationIds = const {};
  final Map<String, String> _retryClientRequestIds = {};
  List<WorkItem> _works = const [];
  String _categoryName = '全部';
  int _requestVersion = 0;
  int _blindBoxHistoryRequestVersion = 0;
  int _recentCreationsRequestVersion = 0;
  int _worksRequestVersion = 0;
  Timer? _taskPollingTimer;
  bool _taskPollInFlight = false;
  late _LibraryTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void dispose() {
    _taskPollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = BackendScope.maybeOf(context);
    if (identical(services, _backendServices)) return;

    _backendServices = services;
    if (services != null) {
      if (_selectedTab == _LibraryTab.patterns) {
        _loadWorks(services);
        _loadRecentCreations(services);
      } else {
        _loadFavorites(services);
        _loadBlindBoxHistory(services);
      }
    }
  }

  Future<void> _loadFavorites(BackendServices services) async {
    final requestVersion = ++_requestVersion;
    try {
      final result = await services.templates.listFavorites();
      if (!mounted ||
          !identical(services, _backendServices) ||
          requestVersion != _requestVersion) {
        return;
      }
      setState(() => _templates = result.items);
    } catch (_) {
      // 与首页保持一致：网络不可用时继续展示本地图纸占位内容。
    }
  }

  Future<void> _loadRecentCreations(BackendServices services) async {
    final requestVersion = ++_recentCreationsRequestVersion;
    try {
      final firstPage = await services.aiGenerations.listStyleGenerations(
        pageSize: _recentCreationsPageSize,
      );
      if (!mounted ||
          !identical(services, _backendServices) ||
          requestVersion != _recentCreationsRequestVersion ||
          _selectedTab != _LibraryTab.patterns) {
        return;
      }
      setState(() => _recentCreations = firstPage.items);
      unawaited(_loadNewCreationIds(services));
      _syncTaskPolling();
      if (firstPage.page.hasMore) {
        unawaited(
          _loadRemainingRecentCreations(
            services,
            requestVersion: requestVersion,
            firstPage: firstPage,
          ),
        );
      }
    } catch (_) {
      // 网络不可用时保留设计稿占位内容，后续进入页面或切换页签时可重试。
    }
  }

  Future<void> _loadRemainingRecentCreations(
    BackendServices services, {
    required int requestVersion,
    required PagedResult<AIGenerationItem> firstPage,
  }) async {
    var page = firstPage.page.page;
    var hasMore = firstPage.page.hasMore;
    try {
      while (hasMore) {
        final nextPage = await services.aiGenerations.listStyleGenerations(
          page: ++page,
          pageSize: _recentCreationsPageSize,
        );
        if (!mounted ||
            !identical(services, _backendServices) ||
            requestVersion != _recentCreationsRequestVersion ||
            _selectedTab != _LibraryTab.patterns) {
          return;
        }
        setState(() {
          _recentCreations = _mergeRecentCreations(
            _recentCreations,
            nextPage.items,
          );
        });
        unawaited(_loadNewCreationIds(services));
        _syncTaskPolling();
        hasMore = nextPage.page.hasMore;
      }
    } catch (_) {
      // 首屏已可用；后台续页失败不影响当前已展示的最近创作。
    }
  }

  List<AIGenerationItem> _mergeRecentCreations(
    List<AIGenerationItem> current,
    List<AIGenerationItem> incoming,
  ) {
    final tasksById = <String, AIGenerationItem>{
      for (final task in current) task.taskId: task,
    };
    for (final task in incoming) {
      tasksById[task.taskId] = task;
    }
    return tasksById.values.toList();
  }

  Future<void> _loadNewCreationIds(BackendServices services) async {
    final unseenIds = await services.store.readUnseenAiTaskIds();
    if (!mounted || !identical(services, _backendServices)) return;
    setState(() {
      final succeededTaskIds = _recentCreations
          .where((task) => task.isSucceeded)
          .map((task) => task.taskId)
          .toSet();
      _newCreationIds = {
        ..._newCreationIds.where(succeededTaskIds.contains),
        ...succeededTaskIds.where((taskId) => unseenIds.contains(taskId)),
      }..removeAll(_seenCreationIds);
    });
  }

  void _syncTaskPolling() {
    final hasProcessingTask = _recentCreations.any((task) => task.isProcessing);
    if (!hasProcessingTask) {
      _taskPollingTimer?.cancel();
      _taskPollingTimer = null;
      return;
    }
    _taskPollingTimer ??= Timer.periodic(_taskPollingInterval, (_) {
      unawaited(_pollProcessingTasks());
    });
  }

  Future<void> _pollProcessingTasks() async {
    if (_taskPollInFlight) return;
    final services = _backendServices;
    if (services == null) return;
    final processingTasks = _recentCreations
        .where((task) => task.isProcessing && task.taskId.isNotEmpty)
        .toList();
    if (processingTasks.isEmpty) {
      _syncTaskPolling();
      return;
    }

    _taskPollInFlight = true;
    try {
      final updates = await Future.wait(
        processingTasks.map((task) async {
          try {
            final updatedTask = await services.aiGenerations.getStyleGeneration(
              task.taskId,
            );
            if (kDebugMode) {
              debugPrint(
                '[AI progress] taskId=${updatedTask.taskId} '
                'status=${updatedTask.status} '
                'progress=${updatedTask.progress}% '
                'startedAt=${updatedTask.startedAt}',
              );
            }
            return MapEntry(task.taskId, updatedTask);
          } catch (error) {
            if (kDebugMode) {
              debugPrint(
                '[AI progress] taskId=${task.taskId} polling failed: $error',
              );
            }
            // Keep the existing task visible and retry it at the next tick.
            return null;
          }
        }),
      );
      if (!mounted || !identical(services, _backendServices)) return;
      final tasksById = <String, AIGenerationItem>{
        for (final update in updates)
          if (update != null) update.key: update.value,
      };
      if (tasksById.isEmpty) return;
      setState(() {
        _recentCreations = _recentCreations
            .map((task) => tasksById[task.taskId] ?? task)
            .toList();
        _newCreationIds = {
          ..._newCreationIds,
          for (final task in tasksById.values)
            if (task.isSucceeded) task.taskId,
        };
        _seenCreationIds = {..._seenCreationIds}
          ..removeAll(
            tasksById.values
                .where((task) => task.isSucceeded)
                .map((task) => task.taskId),
          );
      });
      for (final task in tasksById.values.where((task) => task.isSucceeded)) {
        unawaited(services.store.markAiTaskUnseen(task.taskId));
      }
      _syncTaskPolling();
    } finally {
      _taskPollInFlight = false;
    }
  }

  Future<void> _loadBlindBoxHistory(BackendServices services) async {
    final requestVersion = ++_blindBoxHistoryRequestVersion;
    try {
      // 盲盒历史接口已保证按开箱时间倒序返回，只展示前三条。
      final result = await services.templates.listRandomHistory(pageSize: 3);
      if (!mounted ||
          !identical(services, _backendServices) ||
          requestVersion != _blindBoxHistoryRequestVersion) {
        return;
      }
      setState(() => _blindBoxHistory = result.items.take(3).toList());
    } catch (_) {
      // 网络不可用时保留设计稿占位内容，后续进入页面或切换页签时可重试。
    }
  }

  Future<void> _loadTemplates(
    BackendServices services, {
    int? categoryId,
  }) async {
    final requestVersion = ++_requestVersion;
    try {
      final result = await services.loadHomeTemplates(categoryId: categoryId);
      if (!mounted ||
          !identical(services, _backendServices) ||
          requestVersion != _requestVersion) {
        return;
      }
      setState(() => _templates = result.items);
    } catch (_) {
      // 与首页保持一致：网络不可用时继续展示本地图纸占位内容。
    }
  }

  Future<void> _openFilterDialog() async {
    if (_selectedTab == _LibraryTab.favorites) return;

    final selection = await showHomeFilterDialog(
      context,
      loadCategories: _backendServices?.loadTemplateCategories,
    );
    final services = _backendServices;
    if (selection == null || services == null) return;

    setState(() {
      _categoryName = selection.isDefault ? '全部' : selection.category.name;
    });
    await _loadTemplates(services, categoryId: selection.category.categoryId);
  }

  Future<void> _loadWorks(BackendServices services) async {
    final requestVersion = ++_worksRequestVersion;
    try {
      final result = await services.works.listWorks();
      if (!mounted ||
          !identical(services, _backendServices) ||
          requestVersion != _worksRequestVersion) {
        return;
      }
      setState(() => _works = result.items);
    } catch (_) {
      // 保留既有界面，后续进入页面或切换页签时可再次尝试加载。
    }
  }

  Future<void> _openTemplate(String templateId) async {
    final services = _backendServices;
    if (services == null || templateId.isEmpty) return;

    try {
      final detail = await services.templates.getTemplate(templateId);
      if (!mounted || !identical(services, _backendServices)) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            pattern: detail.patternData.toGeneratedPattern(),
            template: detail.template,
          ),
        ),
      );
    } catch (_) {
      // 详情加载失败时留在图纸页，避免打断现有浏览位置。
    }
  }

  Future<void> _openWork(String workId) async {
    final services = _backendServices;
    if (services == null || workId.isEmpty) return;

    try {
      final detail = await services.works.getWork(workId);
      if (!mounted || !identical(services, _backendServices)) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            pattern: detail.patternData.toGeneratedPattern(),
            workId: detail.work.workId,
          ),
        ),
      );
    } catch (_) {
      // 作品详情加载失败时保留在当前页面，避免打断浏览。
    }
  }

  Future<void> _openCreationTask(AIGenerationItem task) async {
    final services = _backendServices;
    if (services == null || !task.isSucceeded || task.outputImageUrl.isEmpty) {
      return;
    }

    setState(() {
      _newCreationIds = {..._newCreationIds}..remove(task.taskId);
      _seenCreationIds = {..._seenCreationIds, task.taskId};
    });
    unawaited(services.store.markAiTaskSeen(task.taskId));

    try {
      final outputImage = await services.media.downloadBytes(
        task.outputImageUrl,
      );
      if (!mounted || !identical(services, _backendServices)) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ParameterConfigScreen(
            popToPreviousOnBack: true,
            showAiImageSaveAction: true,
            draft: DraftProject(
              originalImageBytes: outputImage,
              croppedImageBytes: outputImage,
              styledImageBytes: outputImage,
            ),
          ),
        ),
      );
    } catch (_) {
      // The read marker remains cleared even if the image cannot be reloaded.
    }
  }

  Future<void> _retryCreationTask(AIGenerationItem task) async {
    if (!task.isRetryable || _retryingCreationIds.contains(task.taskId)) return;
    if (task.hasSourceReadFailure) {
      _showMessage('原图读取失败，请重新选择图片');
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const UploadScreen()));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新生成'),
        content: const Text('重新生成会再次扣除积分，原失败任务的积分已退回。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final services = _backendServices;
    if (services == null) return;
    final clientRequestId = _retryClientRequestIds.putIfAbsent(
      task.taskId,
      RequestId.generate,
    );
    setState(() {
      _retryingCreationIds = {..._retryingCreationIds, task.taskId};
    });
    unawaited(_loadRecentCreations(services));

    try {
      final created = await services.aiGenerations.retryStyleGeneration(
        task.taskId,
        clientRequestId: clientRequestId,
      );
      if (created.taskId.isEmpty) {
        throw const FormatException('重新生成响应缺少 taskId');
      }
      if (!mounted || !identical(services, _backendServices)) return;

      final retriedTask = AIGenerationItem(
        taskId: created.taskId,
        styleId: task.styleId,
        styleName: task.styleName,
        inputImageUrl: task.inputImageUrl,
        outputImageUrl: '',
        status: created.status,
        creditsDeducted: created.creditsDeducted,
        errorMessage: '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        completedAt: 0,
      );
      setState(() {
        _recentCreations = [
          retriedTask,
          ..._recentCreations.where(
            (existingTask) => existingTask.taskId != retriedTask.taskId,
          ),
        ];
        _retryClientRequestIds.remove(task.taskId);
      });
      _syncTaskPolling();
      _showMessage(
        created.duplicated
            ? '重新生成已提交，正在继续处理'
            : '已重新生成，已扣除 ${created.creditsDeducted} 积分',
      );
    } on ApiException catch (error) {
      if (mounted && identical(services, _backendServices)) {
        _showMessage(error.message.isEmpty ? '重新生成失败，请稍后重试' : error.message);
      }
    } catch (_) {
      if (mounted && identical(services, _backendServices)) {
        _showMessage('重新生成失败，请稍后重试');
      }
    } finally {
      if (mounted && identical(services, _backendServices)) {
        setState(() {
          _retryingCreationIds = {..._retryingCreationIds}..remove(task.taskId);
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectTab(_LibraryTab tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
    final services = _backendServices;
    if (services != null) {
      if (tab == _LibraryTab.patterns) {
        _loadWorks(services);
        _loadRecentCreations(services);
      } else {
        _recentCreationsRequestVersion++;
        _taskPollingTimer?.cancel();
        _taskPollingTimer = null;
        _loadFavorites(services);
        _loadBlindBoxHistory(services);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 370,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _selectedTab == _LibraryTab.favorites
                        ? const Color(0xFFFFF2AC)
                        : const Color(0xFFFFB7E3),
                    _pageBackground,
                  ],
                  stops: [
                    0,
                    _selectedTab == _LibraryTab.favorites ? 0.332 : 0.56,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      label: '返回',
                      child: IconButton(
                        key: const ValueKey('my-patterns-back'),
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: SvgPicture.asset(
                          'assets/figma_my/back_icon.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final pageWidth = math.min(
                        constraints.maxWidth,
                        _designWidth,
                      );
                      final scale = pageWidth / _designWidth;
                      final galleryItemCount =
                          _selectedTab == _LibraryTab.patterns
                          ? _works.length
                          : _templates.length;
                      final contentDesignHeight =
                          _patternsContentHeightForItemCount(galleryItemCount);

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Center(
                          child: SizedBox(
                            width: pageWidth,
                            height: contentDesignHeight * scale,
                            child: _ScaledDesignSurface(
                              designWidth: _designWidth,
                              designHeight: contentDesignHeight,
                              scale: scale,
                              child: _MyPatternsContent(
                                templates: _templates,
                                blindBoxHistory: _blindBoxHistory,
                                recentCreations: _recentCreations,
                                newCreationIds: _newCreationIds,
                                retryingCreationIds: _retryingCreationIds,
                                works: _works,
                                categoryName: _categoryName,
                                onFilter: _openFilterDialog,
                                onTemplateTap: _openTemplate,
                                onBlindBoxHistoryTap: _openTemplate,
                                onWorkTap: _openWork,
                                onCreationTap: _openCreationTask,
                                onCreationRetry: _retryCreationTask,
                                selectedTab: _selectedTab,
                                onTabSelected: _selectTab,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPatternsContent extends StatelessWidget {
  final List<TemplateItem> templates;
  final List<TemplateItem> blindBoxHistory;
  final List<AIGenerationItem> recentCreations;
  final Set<String> newCreationIds;
  final Set<String> retryingCreationIds;
  final List<WorkItem> works;
  final String categoryName;
  final VoidCallback onFilter;
  final ValueChanged<String> onTemplateTap;
  final ValueChanged<String> onBlindBoxHistoryTap;
  final ValueChanged<String> onWorkTap;
  final ValueChanged<AIGenerationItem> onCreationTap;
  final ValueChanged<AIGenerationItem> onCreationRetry;
  final _LibraryTab selectedTab;
  final ValueChanged<_LibraryTab> onTabSelected;

  const _MyPatternsContent({
    required this.templates,
    required this.blindBoxHistory,
    required this.recentCreations,
    required this.newCreationIds,
    required this.retryingCreationIds,
    required this.works,
    required this.categoryName,
    required this.onFilter,
    required this.onTemplateTap,
    required this.onBlindBoxHistoryTap,
    required this.onWorkTap,
    required this.onCreationTap,
    required this.onCreationRetry,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: _PatternsSegmentedControl(
              selectedTab: selectedTab,
              onTabSelected: onTabSelected,
            ),
          ),
          const SizedBox(height: 22),
          _LibraryPreviewCard(
            selectedTab: selectedTab,
            blindBoxHistory: blindBoxHistory,
            recentCreations: recentCreations,
            newCreationIds: newCreationIds,
            retryingCreationIds: retryingCreationIds,
            onBlindBoxHistoryTap: onBlindBoxHistoryTap,
            onCreationTap: onCreationTap,
            onCreationRetry: onCreationRetry,
          ),
          const SizedBox(height: 32),
          HomePatternGallery(
            key: const ValueKey('my-pattern-gallery'),
            templates: templates,
            items: selectedTab == _LibraryTab.patterns
                ? works
                      .map(
                        (work) => PatternGalleryItem(
                          id: work.workId,
                          thumbnailUrl: work.thumbnailUrl.isNotEmpty
                              ? work.thumbnailUrl
                              : work.patternImageUrl.isNotEmpty
                              ? work.patternImageUrl
                              : work.originalImageUrl,
                          alternateThumbnailUrls: [
                            if (work.patternImageUrl.isNotEmpty &&
                                work.patternImageUrl != work.thumbnailUrl)
                              work.patternImageUrl,
                            if (work.originalImageUrl.isNotEmpty &&
                                work.originalImageUrl != work.thumbnailUrl &&
                                work.originalImageUrl != work.patternImageUrl)
                              work.originalImageUrl,
                          ],
                        ),
                      )
                      .toList()
                : null,
            categoryName: categoryName,
            onFilter: onFilter,
            showFilter: selectedTab != _LibraryTab.patterns,
            onTemplateTap: onTemplateTap,
            onItemTap: onWorkTap,
            gridSpacing: 12,
            tileSize: _myGalleryTileSize,
            tileSpacing: _myGalleryTileSpacing,
          ),
        ],
      ),
    );
  }
}

class _PatternsSegmentedControl extends StatelessWidget {
  final _LibraryTab selectedTab;
  final ValueChanged<_LibraryTab> onTabSelected;

  const _PatternsSegmentedControl({
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 334,
      height: 46,
      padding: const EdgeInsets.fromLTRB(3, 4.6, 3, 4.6),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedTabButton(
              label: '我的图纸',
              selected: selectedTab == _LibraryTab.patterns,
              selectedColors: const [Color(0xFFFF76CA), Color(0xFFFFB9E4)],
              onTap: () => onTabSelected(_LibraryTab.patterns),
            ),
          ),
          Expanded(
            child: _SegmentedTabButton(
              label: '我的收藏',
              selected: selectedTab == _LibraryTab.favorites,
              selectedColors: const [Color(0xFFFFE774), Color(0xFFFFF4B7)],
              onTap: () => onTabSelected(_LibraryTab.favorites),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final List<Color> selectedColors;
  final VoidCallback onTap;

  const _SegmentedTabButton({
    required this.label,
    required this.selected,
    required this.selectedColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: DecoratedBox(
            decoration: selected
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: selectedColors,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(57)),
                  )
                : const BoxDecoration(),
            child: _PatternTab(label: label, selected: selected),
          ),
        ),
      ),
    );
  }
}

class _PatternTab extends StatelessWidget {
  final String label;
  final bool selected;

  const _PatternTab({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return Align(
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0x99000000),
            fontFamily: _roundFontFamily,
            fontFamilyFallback: _fontFallbacks,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      );
    }

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontFamily: _pixelFontFamily,
      fontWeight: FontWeight.w800,
      letterSpacing: 2.40,
    );

    return Transform(
      transform: Matrix4.skewX(-10 * math.pi / 180),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            label,
            style: textStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 6
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.black,
            ),
          ),
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}

class _LibraryPreviewCard extends StatelessWidget {
  final _LibraryTab selectedTab;
  final List<TemplateItem> blindBoxHistory;
  final List<AIGenerationItem> recentCreations;
  final Set<String> newCreationIds;
  final Set<String> retryingCreationIds;
  final ValueChanged<String> onBlindBoxHistoryTap;
  final ValueChanged<AIGenerationItem> onCreationTap;
  final ValueChanged<AIGenerationItem> onCreationRetry;

  const _LibraryPreviewCard({
    required this.selectedTab,
    required this.blindBoxHistory,
    required this.recentCreations,
    required this.newCreationIds,
    required this.retryingCreationIds,
    required this.onBlindBoxHistoryTap,
    required this.onCreationTap,
    required this.onCreationRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isFavorites = selectedTab == _LibraryTab.favorites;
    final previewTemplates = blindBoxHistory;
    return Container(
      width: 366,
      height: 194,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFavorites
              ? const Color(0xFFFFE775)
              : const Color(0xFFFE73C9),
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                isFavorites
                    ? 'assets/figma_my/blind_box_group.svg'
                    : 'assets/figma_my/recent_favorites_icon.svg',
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 4),
              Text(
                isFavorites ? '盲盒图纸' : '最近创作',
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: _roundFontFamily,
                  fontFamilyFallback: _fontFallbacks,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: isFavorites
                  ? (previewTemplates.isEmpty ? 3 : previewTemplates.length)
                  : (recentCreations.isEmpty ? 3 : recentCreations.length),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (!isFavorites && recentCreations.isNotEmpty) {
                  final task = recentCreations[index];
                  return _RecentCreationPreview(
                    task: task,
                    isNew: newCreationIds.contains(task.taskId),
                    isRetrying: retryingCreationIds.contains(task.taskId),
                    onTap: () => onCreationTap(task),
                    onRetry: () => onCreationRetry(task),
                  );
                }
                if (previewTemplates.isEmpty) {
                  return const _RecentPatternPreview();
                }
                return _RecentPatternPreview(
                  template: previewTemplates[index],
                  keyPrefix: 'blind-box-history-preview',
                  onTap: onBlindBoxHistoryTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPatternPreview extends StatelessWidget {
  final TemplateItem? template;
  final String keyPrefix;
  final ValueChanged<String>? onTap;

  const _RecentPatternPreview({
    this.template,
    this.keyPrefix = 'recent-favorite-preview',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = template;
    final thumbnailUrl = item?.thumbnailUrl.isNotEmpty == true
        ? item!.thumbnailUrl
        : item?.previewUrl ?? 'assets/figma_home/gallery_pattern_3.png';
    final uri = Uri.tryParse(thumbnailUrl);
    final isNetworkImage =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    return GestureDetector(
      key: item == null ? null : ValueKey('$keyPrefix-${item.templateId}'),
      onTap: item == null || onTap == null
          ? null
          : () => onTap!(item.templateId),
      child: SizedBox(
        width: 130,
        height: 130,
        child: ClipRect(
          child: isNetworkImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/figma_home/gallery_pattern_3.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                    Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
                  ],
                )
              : Image.asset(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
        ),
      ),
    );
  }
}

/// A task in the user's creation history. Running tasks mirror the Figma
/// treatment: a dimmed source image with a small, centered progress bar.
class _RecentCreationPreview extends StatelessWidget {
  final AIGenerationItem task;
  final bool isNew;
  final bool isRetrying;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const _RecentCreationPreview({
    required this.task,
    this.isNew = false,
    this.isRetrying = false,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = task.isSucceeded
        ? task.outputImageUrl
        : task.inputImageUrl;
    final isProcessing = task.isProcessing;
    final isRetryable = task.isRetryable;

    return Semantics(
      button: task.isSucceeded || (isRetryable && onRetry != null),
      label: _taskSemanticLabel(task),
      child: GestureDetector(
        onTap: task.isSucceeded ? onTap : null,
        child: SizedBox(
          key: ValueKey('recent-creation-preview-${task.taskId}'),
          width: 130,
          height: 130,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFD1D1D1)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CreationTaskImage(imageUrl: imageUrl),
                if (isProcessing) ...[
                  const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x66000000)),
                  ),
                  Center(
                    child: _CreationProgressBar(
                      key: ValueKey('recent-creation-progress-${task.taskId}'),
                      progress: _processingProgress(task),
                    ),
                  ),
                ],
                if (isRetryable)
                  _FailedCreationOverlay(
                    taskId: task.taskId,
                    isSourceReadFailure: task.hasSourceReadFailure,
                    isRetrying: isRetrying,
                    onRetry: onRetry,
                  ),
                if (isNew)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _NewCreationBadge(taskId: task.taskId),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FailedCreationOverlay extends StatelessWidget {
  final String taskId;
  final bool isSourceReadFailure;
  final bool isRetrying;
  final VoidCallback? onRetry;

  const _FailedCreationOverlay({
    required this.taskId,
    required this.isSourceReadFailure,
    required this.isRetrying,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Color(0x66000000)),
      child: Center(
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSourceReadFailure ? '原图读取失败' : '生成失败',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: _roundFontFamily,
                  fontFamilyFallback: _fontFallbacks,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
              SizedBox(height: 8),
              GestureDetector(
                key: ValueKey('recent-creation-retry-$taskId'),
                onTap: isRetrying ? null : onRetry,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(17)),
                  ),
                  child: SizedBox(
                    width: 58,
                    height: 24,
                    child: Center(
                      child: Text(
                        isRetrying
                            ? '提交中'
                            : (isSourceReadFailure ? '重新选图' : '重试'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontFamily: _roundFontFamily,
                          fontFamilyFallback: _fontFallbacks,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
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

class _NewCreationBadge extends StatelessWidget {
  final String taskId;

  const _NewCreationBadge({required this.taskId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('recent-creation-new-badge-$taskId'),
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4.85,
            top: 4.96,
            child: Transform.rotate(
              angle: 0.22986,
              child: SvgPicture.asset(
                'assets/pin_icon/recent_creation_new_star.svg',
                width: 20.3,
                height: 20.08,
              ),
            ),
          ),
          Positioned(
            left: 1.5,
            top: 8,
            child: Transform.rotate(
              angle: 0.00986,
              child: const _NewCreationTextGraphic(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewCreationTextGraphic extends StatelessWidget {
  static const _width = 25.813;
  static const _height = 12.35;

  const _NewCreationTextGraphic();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _width,
      height: _height,
      child: _NewCreationTextAsset(),
    );
  }
}

class _NewCreationTextAsset extends StatelessWidget {
  const _NewCreationTextAsset();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/pin_icon/recent_creation_new_text.png',
      width: _NewCreationTextGraphic._width,
      height: _NewCreationTextGraphic._height,
      fit: BoxFit.fill,
    );
  }
}

String _taskSemanticLabel(AIGenerationItem task) {
  if (task.isProcessing) return '正在创作';
  return switch (task.status) {
    AIGenerationItem.succeeded => '已完成创作',
    AIGenerationItem.failed => '创作失败',
    AIGenerationItem.cancelled => '已取消创作',
    AIGenerationItem.expired => '创作已超时',
    _ => '创作已结束',
  };
}

double _processingProgress(AIGenerationItem task) {
  return (task.progress.clamp(0, 100) / 100).toDouble();
}

class _CreationTaskImage extends StatelessWidget {
  final String imageUrl;

  const _CreationTaskImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const SizedBox.expand();
    final uri = Uri.tryParse(imageUrl);
    final isNetworkImage =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    const fallback = 'assets/figma_home/gallery_pattern_3.png';
    final thumbnailCacheSize = math.max(
      1,
      (130 * MediaQuery.devicePixelRatioOf(context)).round(),
    );

    if (!isNetworkImage) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Image.asset(fallback, fit: BoxFit.cover),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(fallback, fit: BoxFit.cover),
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          memCacheWidth: thumbnailCacheSize,
          memCacheHeight: thumbnailCacheSize,
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (_, _) => const SizedBox.expand(),
          errorWidget: (_, _, _) => const SizedBox.expand(),
        ),
      ],
    );
  }
}

class _CreationProgressBar extends StatelessWidget {
  final double progress;

  const _CreationProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 50,
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(63),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: 50 * progress,
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFE73C9),
                  borderRadius: BorderRadius.circular(63),
                ),
              ),
            ),
          ],
        ),
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
  final List<FinishedProductItem> items;
  final bool loading;
  final bool recording;
  final VoidCallback onRecordTap;

  const _WorksSection({
    required this.items,
    required this.loading,
    required this.recording,
    required this.onRecordTap,
  });

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
                  child: SvgPicture.asset(
                    'assets/pin_icon/my_finished_products.svg',
                    key: const ValueKey('my-finished-products-title-icon'),
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
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
            top: 36,
            child: _FinishedProductGallery(items: items, loading: loading),
          ),
          Positioned(
            top: 422,
            left: 103,
            child: _RecordButton(onTap: onRecordTap, loading: recording),
          ),
        ],
      ),
    );
  }
}

class _FinishedProductGallery extends StatefulWidget {
  final List<FinishedProductItem> items;
  final bool loading;

  const _FinishedProductGallery({required this.items, required this.loading});

  @override
  State<_FinishedProductGallery> createState() =>
      _FinishedProductGalleryState();
}

class _FinishedProductGalleryState extends State<_FinishedProductGallery> {
  static const _itemsPerPage = 9;
  final PageController _pageController = PageController();
  var _currentPage = 0;

  int get _pageCount => widget.items.length ~/ _itemsPerPage + 1;

  @override
  void didUpdateWidget(covariant _FinishedProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastPage = _pageCount - 1;
    if (_currentPage <= lastPage) return;
    _currentPage = lastPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(lastPage);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.loading && widget.items.isEmpty ? '正在加载我的成品' : '我的成品列表',
      child: SizedBox(
        key: const ValueKey('my-works-placeholder'),
        width: 366,
        height: 366,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _pageCount,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, page) => _FinishedProductBoard(
                items: widget.items,
                page: page,
                itemsPerPage: _itemsPerPage,
              ),
            ),
            if (_pageCount > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Center(
                  child: _PageIndicator(
                    pageCount: _pageCount,
                    currentPage: _currentPage,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FinishedProductBoard extends StatelessWidget {
  final List<FinishedProductItem> items;
  final int page;
  final int itemsPerPage;

  const _FinishedProductBoard({
    required this.items,
    required this.page,
    required this.itemsPerPage,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CustomPaint(
          painter: const _DashedRoundedRectPainter(),
          child: Stack(
            children: [
              for (var index = 0; index < itemsPerPage; index++)
                _FinishedProductSlot(
                  item: page * itemsPerPage + index < items.length
                      ? items[page * itemsPerPage + index]
                      : null,
                  index: index,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishedProductSlot extends StatelessWidget {
  final FinishedProductItem? item;
  final int index;

  const _FinishedProductSlot({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final product = item;
    const centers = [64.0, 175.0, 286.0];
    final row = index ~/ 3;
    final column = index % 3;
    return Positioned(
      left: centers[column] - 48,
      top: centers[row] - 48,
      width: 96,
      height: 96,
      child: product == null
          ? const Center(child: _FinishedProductEmptySlot())
          : Image.network(
              product.displayUrl,
              key: ValueKey('finished-product-${product.finishedProductId}'),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Center(child: _FinishedProductEmptySlot()),
            ),
    );
  }
}

class _FinishedProductEmptySlot extends StatelessWidget {
  const _FinishedProductEmptySlot();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFD9D9D9),
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(dimension: 12),
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
  final int pageCount;
  final int currentPage;

  const _PageIndicator({required this.pageCount, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '第 ${currentPage + 1} 页，共 $pageCount 页',
      child: Row(
        key: const ValueKey('finished-product-page-indicator'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var page = 0; page < pageCount; page++) ...[
            if (page > 0) const SizedBox(width: 4),
            _PageMarker(selected: page == currentPage),
          ],
        ],
      ),
    );
  }
}

class _PageMarker extends StatelessWidget {
  final bool selected;

  const _PageMarker({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: selected ? 18 : 6,
      height: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0x1F000000),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;

  const _RecordButton({this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !loading,
      label: '记录一下',
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: 160,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
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

class MyBottomNavigation extends StatelessWidget {
  final double height;
  final VoidCallback onMakeTap;

  const MyBottomNavigation({
    super.key,
    required this.height,
    required this.onMakeTap,
  });

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
