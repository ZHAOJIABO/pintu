import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api/api_models.dart';

const _designWidth = 390.0;
const _sheetDesignHeight = 480.0;
const _dialogEntranceDuration = Duration(milliseconds: 280);
const _dialogExitDuration = Duration(milliseconds: 200);
const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];

/// Displays the Figma-designed filter sheet for the home gallery.
Future<void> showHomeFilterDialog(
  BuildContext context, {
  Future<List<TemplateCategory>> Function()? loadCategories,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '关闭筛选弹窗',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) =>
        HomeFilterDialog(loadCategories: loadCategories),
  );
}

class HomeFilterDialog extends StatefulWidget {
  final Future<List<TemplateCategory>> Function()? loadCategories;

  const HomeFilterDialog({this.loadCategories, super.key});

  @override
  State<HomeFilterDialog> createState() => _HomeFilterDialogState();
}

class _HomeFilterDialogState extends State<HomeFilterDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _backdropOpacity;
  late final Animation<double> _sheetOpacity;
  late final Animation<double> _sheetScale;
  late final Animation<Offset> _sheetOffset;
  List<TemplateCategory> _categories = const [];
  bool _loading = false;
  bool _loadFailed = false;
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
    _sheetOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    _sheetScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _sheetOffset =
        Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _loadCategories();
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

  void _handleSystemDismiss(bool didPop, Object? _) {
    if (!didPop) _dismiss();
  }

  Future<void> _loadCategories() async {
    final loader = widget.loadCategories;
    if (loader == null) return;

    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final categories = await loader();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: _handleSystemDismiss,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                key: const ValueKey('home-filter-dialog-backdrop-transition'),
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
                final scale = math.min(1, constraints.maxWidth / _designWidth);

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: SlideTransition(
                    key: const ValueKey('home-filter-dialog-sheet-transition'),
                    position: _sheetOffset,
                    child: ScaleTransition(
                      key: const ValueKey('home-filter-dialog-sheet-scale'),
                      scale: _sheetScale,
                      child: FadeTransition(
                        key: const ValueKey('home-filter-dialog-sheet-fade'),
                        opacity: _sheetOpacity,
                        child: SizedBox(
                          key: const ValueKey('home-filter-dialog-boundary'),
                          width: _designWidth * scale,
                          height: _sheetDesignHeight * scale,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              width: _designWidth,
                              height: _sheetDesignHeight,
                              child: _HomeFilterSheet(
                                categories: _categories,
                                loading: _loading,
                                loadFailed: _loadFailed,
                                onRetry: widget.loadCategories == null
                                    ? null
                                    : _loadCategories,
                                onDismiss: _dismiss,
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

class _HomeFilterSheet extends StatelessWidget {
  final List<TemplateCategory> categories;
  final bool loading;
  final bool loadFailed;
  final VoidCallback? onRetry;
  final Future<void> Function() onDismiss;

  const _HomeFilterSheet({
    required this.categories,
    required this.loading,
    required this.loadFailed,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('home-filter-dialog'),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16).copyWith(top: 20, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '筛选',
                    style: TextStyle(
                      color: Colors.black,
                      fontFamily: _roundFontFamily,
                      fontFamilyFallback: _fontFallbacks,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '关闭筛选弹窗',
                    child: GestureDetector(
                      key: const ValueKey('home-filter-dialog-close'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onDismiss,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: SvgPicture.asset(
                          'assets/figma_home/blind_box/close.svg',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _FilterCategoryContent(
                categories: categories,
                loading: loading,
                loadFailed: loadFailed,
                onRetry: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterCategoryContent extends StatelessWidget {
  final List<TemplateCategory> categories;
  final bool loading;
  final bool loadFailed;
  final VoidCallback? onRetry;

  const _FilterCategoryContent({
    required this.categories,
    required this.loading,
    required this.loadFailed,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final displayCategories = categories
        .where((category) => category.name.trim().isNotEmpty)
        .toList(growable: false);
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (loadFailed) {
      return Center(
        child: Semantics(
          button: onRetry != null,
          label: '重新加载筛选分类',
          child: GestureDetector(
            key: const ValueKey('home-filter-dialog-retry'),
            onTap: onRetry,
            child: const Text('分类加载失败，点击重试'),
          ),
        ),
      );
    }
    if (displayCategories.isEmpty) {
      return const Center(child: Text('暂无筛选分类'));
    }

    return GridView.builder(
      key: const ValueKey('home-filter-category-list'),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 48,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: displayCategories.length,
      itemBuilder: (context, index) {
        final category = displayCategories[index];
        return _FilterTile(
          key: ValueKey('home-filter-category-${category.categoryId}'),
          label: category.name,
        );
      },
    );
  }
}

class _FilterTile extends StatelessWidget {
  final String label;

  const _FilterTile({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEEF0F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontFamily: _roundFontFamily,
              fontFamilyFallback: _fontFallbacks,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 16 / 14,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
