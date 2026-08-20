import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/color.dart';
import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../models/pattern_chart.dart';
import '../navigation/home_navigation.dart';
import '../rendering/pattern_chart_painter.dart';
import '../services/api/api_models.dart';
import '../services/api/api_scope.dart';
import '../services/export_watermark_service.dart';
import '../services/pattern_export_service.dart';
import '../widgets/patterns_hint_dialog.dart';
import 'bead_mode_screen.dart';
import 'pattern_editor_screen.dart';

const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _pageBackground = Color(0xFFEEF0F6);
const _chartBorder = PatternChartPainter.defaultBorderColor;
const _chartMinorGrid = PatternChartPainter.defaultMinorGridColor;
const _chartMajorGrid = PatternChartPainter.defaultMajorGridColor;
const _patternSaveIconAsset = 'assets/pin_icon/pattern_save.svg';

typedef WatermarkPngBytesLoader = Future<Uint8List?> Function();

class ResultScreen extends StatefulWidget {
  final GeneratedPattern pattern;
  final TemplateItem? template;
  final String? workId;
  final String? boardSpec;
  final bool isEditingLocked;
  final bool showGeneratedHint;
  final ValueChanged<String>? onWorkDeleted;
  final PatternExportService exportService;
  final WatermarkPngBytesLoader? loadWatermarkPngBytes;

  const ResultScreen({
    super.key,
    required this.pattern,
    this.template,
    this.workId,
    this.boardSpec,
    this.isEditingLocked = false,
    this.showGeneratedHint = false,
    this.onWorkDeleted,
    this.exportService = const PatternExportService(),
    this.loadWatermarkPngBytes,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final PatternExportService _exportService = widget.exportService;
  late GeneratedPattern _pattern = widget.pattern;
  late TemplateItem? _template = widget.template;
  bool _exporting = false;
  bool _updatingFavorite = false;
  bool _deletingWork = false;

  bool get _editingEnabled => _template == null && !widget.isEditingLocked;
  bool get _canDeleteWork =>
      _template == null &&
      widget.workId?.isNotEmpty == true &&
      widget.onWorkDeleted != null;

  @override
  void initState() {
    super.initState();
    if (widget.showGeneratedHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGeneratedHintDialog();
      });
    }
  }

  Future<void> _openBeadMode() async {
    final editedPattern = await Navigator.push<GeneratedPattern>(
      context,
      MaterialPageRoute(
        builder: (_) => BeadModeScreen(
          pattern: _pattern,
          editingEnabled: _editingEnabled,
          workId: widget.workId,
          boardSpec: widget.boardSpec,
        ),
      ),
    );
    if (!mounted || editedPattern == null) return;
    setState(() => _pattern = editedPattern);
  }

  Future<void> _openEditor() async {
    final editedPattern = await Navigator.push<GeneratedPattern>(
      context,
      MaterialPageRoute(
        builder: (_) => PatternEditorScreen(
          pattern: _pattern,
          workId: widget.workId,
          boardSpec: widget.boardSpec,
        ),
      ),
    );
    if (!mounted || editedPattern == null) return;

    setState(() => _pattern = editedPattern);
  }

  void _showEditingLockedMessage() {
    _showToast('投稿审核中，审核完成后即可修改');
  }

  Future<void> _toggleTemplateFavorite() async {
    final template = _template;
    final services = BackendScope.maybeOf(context);
    if (template == null ||
        template.templateId.isEmpty ||
        services == null ||
        _updatingFavorite) {
      return;
    }

    setState(() => _updatingFavorite = true);
    try {
      final result = template.isFavorited
          ? await services.templates.unfavorite(template.templateId)
          : await services.templates.favorite(template.templateId);
      if (!mounted) return;
      setState(
        () => _template = template.copyWith(
          isFavorited: result.isFavorited,
          favoriteCount: result.favoriteCount,
        ),
      );
      if (result.isFavorited) {
        await showPatternsHintDialog(
          context,
          destination: PatternsHintDestination.favorites,
        );
      }
    } catch (_) {
      if (mounted) _showToast('收藏失败，请重试');
    } finally {
      if (mounted) setState(() => _updatingFavorite = false);
    }
  }

  Future<void> _saveImage() async {
    if (_exporting) return;

    setState(() => _exporting = true);
    try {
      Uint8List? watermarkPngBytes;
      try {
        watermarkPngBytes = await _loadWatermarkPngBytes();
      } catch (_) {
        if (mounted) _showToast('水印加载失败，请重试');
        return;
      }

      try {
        await _exportService.saveChartPngToPhotoLibrary(
          _pattern,
          watermarkPngBytes: watermarkPngBytes,
        );
        if (mounted) _showToast('图纸已保存');
      } catch (error) {
        if (mounted) _showToast('保存失败：$error');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteWork() async {
    final workId = widget.workId;
    final services = BackendScope.maybeOf(context);
    if (_deletingWork || workId == null || workId.isEmpty || services == null) {
      return;
    }

    setState(() => _deletingWork = true);
    try {
      await services.works.deleteWork(workId);
      if (!mounted) return;
      widget.onWorkDeleted?.call(workId);
      Navigator.of(context).pop<void>();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showToast(switch (error.code) {
        2006 => '投稿审核中，暂时无法删除',
        1101 => '图纸信息有误',
        _ => '删除失败，请稍后重试',
      });
    } catch (_) {
      if (mounted) _showToast('删除失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _deletingWork = false);
    }
  }

  Future<void> _confirmDeleteWork() async {
    if (_deletingWork) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确定删除图纸？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            key: const ValueKey('result-delete-work-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('result-delete-work-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _deleteWork();
  }

  Future<Uint8List?> _loadWatermarkPngBytes() {
    final loader = widget.loadWatermarkPngBytes;
    if (loader != null) return loader();

    final services = BackendScope.maybeOf(context);
    if (services == null) {
      return Future<Uint8List?>.error(StateError('无法获取导出水印配置'));
    }
    return ExportWatermarkService(
      system: services.system,
      client: services.client,
    ).loadWatermarkBytes();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _showGeneratedHintDialog() {
    return showPatternsHintDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: Column(
          children: [
            _DrawingHeader(
              pattern: _pattern,
              onSaveImage: _saveImage,
              onDeleteWork: _canDeleteWork && !_deletingWork
                  ? _confirmDeleteWork
                  : null,
            ),
            Expanded(
              child: _MaterialSummary(
                pattern: _pattern,
                authorName: _template?.displayAuthorName,
              ),
            ),
            _BottomActionBar(
              onStart: _openBeadMode,
              secondaryLabel: _template == null
                  ? (widget.isEditingLocked ? '审核中' : '编辑')
                  : (_template!.isFavorited ? '已收藏' : '收藏'),
              onSecondary: _template == null
                  ? (_editingEnabled ? _openEditor : _showEditingLockedMessage)
                  : (_updatingFavorite ? null : _toggleTemplateFavorite),
              secondaryEnabled: _template != null || _editingEnabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingHeader extends StatelessWidget {
  final GeneratedPattern pattern;
  final VoidCallback onSaveImage;
  final VoidCallback? onDeleteWork;

  const _DrawingHeader({
    required this.pattern,
    required this.onSaveImage,
    this.onDeleteWork,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _ResultNavigationBar(
                onSaveImage: onSaveImage,
                onDeleteWork: onDeleteWork,
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final chartAreaSize = constraints.maxWidth;
                  return SizedBox.square(
                    key: const ValueKey('result-chart-area'),
                    dimension: chartAreaSize,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _PatternChartFrame(pattern: pattern),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultNavigationBar extends StatelessWidget {
  final VoidCallback onSaveImage;
  final VoidCallback? onDeleteWork;

  const _ResultNavigationBar({required this.onSaveImage, this.onDeleteWork});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => returnToHome(context),
                child: const SizedBox(
                  width: 24,
                  height: 44,
                  child: Icon(
                    Icons.chevron_left,
                    color: Colors.black,
                    size: 30,
                  ),
                ),
              ),
            ),
            const Text(
              '图纸',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontFamily: _roundFontFamily,
                fontFamilyFallback: _fontFallbacks,
                fontWeight: FontWeight.w500,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDeleteWork != null)
                    GestureDetector(
                      key: const ValueKey('result-delete-work-button'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onDeleteWork,
                      child: const SizedBox(
                        width: 24,
                        height: 44,
                        child: Center(child: _DeleteWorkIcon()),
                      ),
                    ),
                  if (onDeleteWork != null) const SizedBox(width: 6),
                  GestureDetector(
                    key: const ValueKey('result-save-image-button'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onSaveImage,
                    child: const SizedBox(
                      width: 24,
                      height: 44,
                      child: Center(child: _PatternSaveIcon()),
                    ),
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

class _DeleteWorkIcon extends StatelessWidget {
  const _DeleteWorkIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18.6729,
      height: 18.666,
      child: CustomPaint(painter: _DeleteWorkIconPainter()),
    );
  }
}

class _DeleteWorkIconPainter extends CustomPainter {
  const _DeleteWorkIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const designWidth = 18.6729;
    const designHeight = 18.666;
    final scaleX = size.width / designWidth;
    final scaleY = size.height / designHeight;
    Rect rect(double left, double top, double width, double height) =>
        Rect.fromLTWH(
          left * scaleX,
          top * scaleY,
          width * scaleX,
          height * scaleY,
        );

    final black = Paint()..color = Colors.black;
    final gray = Paint()..color = const Color(0xFFBDBDBD);
    canvas.drawRect(rect(6.79, 0, 6.79, 2.7), black);
    canvas.drawRect(rect(0, 2.9, designWidth, 2.7), black);
    canvas.drawRect(rect(2.55, 8.09, 13.58, 10.58), black);

    canvas.drawRect(rect(5.09, 8.09, 2.55, 8.09), gray);
    canvas.drawRect(rect(7.64, 10.78, 2.55, 5.4), gray);
    canvas.drawRect(rect(10.19, 13.47, 2.55, 2.71), gray);
  }

  @override
  bool shouldRepaint(covariant _DeleteWorkIconPainter oldDelegate) => false;
}

class _PatternSaveIcon extends StatelessWidget {
  const _PatternSaveIcon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8 / 3),
      child: SvgPicture.asset(_patternSaveIconAsset),
    );
  }
}

class _PatternChartFrame extends StatelessWidget {
  final GeneratedPattern pattern;

  const _PatternChartFrame({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final chart = PatternChartData.fromPixels(
      pixels: pattern.pixels,
      width: pattern.width,
      height: pattern.height,
      paletteEntries: pattern.paletteEntries,
    );
    const chartCellSize = 22.0;
    final chartSize = PatternChartPainter.chartSize(
      chart: chart,
      cellSize: chartCellSize,
      showCoordinates: false,
      showBorderCoordinates: true,
    );

    return DecoratedBox(
      key: const ValueKey('result-chart-frame'),
      decoration: const BoxDecoration(color: Colors.white),
      child: ClipRect(
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(64),
          minScale: 1,
          maxScale: 16,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: chartSize.width,
                height: chartSize.height,
                child: CustomPaint(
                  size: chartSize,
                  painter: PatternChartPainter(
                    chart: chart,
                    cellSize: chartCellSize,
                    showCellLabels: true,
                    showBorderCoordinates: true,
                    minorGridColor: _chartMinorGrid,
                    majorGridColor: _chartMajorGrid,
                    borderColor: _chartBorder,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialSummary extends StatelessWidget {
  final GeneratedPattern pattern;
  final String? authorName;

  const _MaterialSummary({required this.pattern, this.authorName});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('result-material-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          if (authorName case final author?) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'by$author',
                key: const ValueKey('result-pattern-author'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _attributionTextStyle,
              ),
            ),
            const SizedBox(height: 20),
          ],
          _MaterialSummaryCounts(pattern: pattern),
          const SizedBox(height: 20),
          _MaterialUsageGrid(pattern: pattern),
        ],
      ),
    );
  }
}

class _MaterialSummaryCounts extends StatelessWidget {
  final GeneratedPattern pattern;

  const _MaterialSummaryCounts({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('共计${pattern.usage.length}个颜色', style: _summaryTextStyle),
        const SizedBox(width: 12),
        Text('${pattern.totalBeads}颗豆子', style: _summaryTextStyle),
      ],
    );
  }
}

const _summaryTextStyle = TextStyle(
  color: Color(0x99000000),
  fontSize: 12,
  fontFamily: _roundFontFamily,
  fontFamilyFallback: _fontFallbacks,
  fontWeight: FontWeight.w500,
);

const _attributionTextStyle = TextStyle(
  color: Color(0x4D000000),
  fontSize: 12,
  fontFamily: _roundFontFamily,
  fontFamilyFallback: _fontFallbacks,
  fontWeight: FontWeight.w500,
);

class _MaterialUsageGrid extends StatelessWidget {
  final GeneratedPattern pattern;

  const _MaterialUsageGrid({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final sortedUsage = pattern.usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / 3;

        return Wrap(
          key: const ValueKey('result-material-grid'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in sortedUsage)
              SizedBox(
                width: itemWidth,
                height: 52,
                child: _MaterialUsageTile(
                  entry: _findEntry(item.key),
                  ref: item.key,
                  count: item.value,
                ),
              ),
          ],
        );
      },
    );
  }

  PaletteEntry? _findEntry(String ref) {
    for (final entry in pattern.paletteEntries) {
      if (entry.ref == ref) return entry;
    }
    return null;
  }
}

class _MaterialUsageTile extends StatelessWidget {
  final PaletteEntry? entry;
  final String ref;
  final int count;

  const _MaterialUsageTile({
    required this.entry,
    required this.ref,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final beadColor = entry?.color;
    final color = beadColor == null
        ? const Color(0xFFB8BCC8)
        : Color.fromARGB(
            beadColor.aInt,
            beadColor.rInt,
            beadColor.gInt,
            beadColor.bInt,
          );
    final foreground = beadColor == null
        ? Colors.white
        : _toFlutterColor(foregroundColor(beadColor));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x4D878787), width: 0.5),
              ),
              alignment: Alignment.center,
              child: Text(
                ref,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  height: 16 / 14,
                  fontFamily: _roundFontFamily,
                  fontFamilyFallback: _fontFallbacks,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$count',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    height: 18 / 15,
                    fontFamily: _roundFontFamily,
                    fontFamilyFallback: _fontFallbacks,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _toFlutterColor(BeadColor color) {
    return Color.fromARGB(color.aInt, color.rInt, color.gInt, color.bInt);
  }
}

class _BottomActionBar extends StatelessWidget {
  final VoidCallback onStart;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryEnabled;

  const _BottomActionBar({
    required this.onStart,
    required this.secondaryLabel,
    required this.onSecondary,
    this.secondaryEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = math.max(
      32.0,
      MediaQuery.paddingOf(context).bottom + 8.0,
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
          child: Row(
            children: [
              Expanded(
                child: _ResultActionButton(
                  label: '立即开拼',
                  onTap: onStart,
                  filled: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultActionButton(
                  key: const ValueKey('result-secondary-action'),
                  label: secondaryLabel,
                  onTap: onSecondary,
                  enabled: secondaryEnabled,
                  filled: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool filled;

  const _ResultActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = filled ? Colors.white : Colors.black;
    final isEnabled = enabled && onTap != null;
    final backgroundColor = filled
        ? (isEnabled ? Colors.black : const Color(0xFF9EA3AE))
        : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(44),
            border: filled
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: !isEnabled
                    ? textColor.withValues(alpha: 0.55)
                    : textColor,
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
