import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/color.dart';
import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../models/pattern_chart.dart';
import '../rendering/pattern_chart_painter.dart';
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

class ResultScreen extends StatefulWidget {
  final GeneratedPattern pattern;
  final bool showGeneratedHint;
  final PatternExportService exportService;

  const ResultScreen({
    super.key,
    required this.pattern,
    this.showGeneratedHint = false,
    this.exportService = const PatternExportService(),
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final PatternExportService _exportService = widget.exportService;
  late GeneratedPattern _pattern = widget.pattern;
  bool _exporting = false;

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
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => BeadModeScreen(pattern: _pattern)),
    );
  }

  Future<void> _openEditor() async {
    final editedPattern = await Navigator.push<GeneratedPattern>(
      context,
      MaterialPageRoute(builder: (_) => PatternEditorScreen(pattern: _pattern)),
    );
    if (!mounted || editedPattern == null) return;

    setState(() => _pattern = editedPattern);
  }

  Future<void> _saveImage() async {
    if (_exporting) return;

    setState(() => _exporting = true);
    try {
      await _exportService.saveChartPngToPhotoLibrary(_pattern);
      if (!mounted) return;
      _showToast('图纸已保存');
    } catch (error) {
      if (!mounted) return;
      _showToast('保存失败：$error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
            _DrawingHeader(pattern: _pattern, onSaveImage: _saveImage),
            Expanded(child: _MaterialSummary(pattern: _pattern)),
            _BottomActionBar(onStart: _openBeadMode, onEdit: _openEditor),
          ],
        ),
      ),
    );
  }
}

class _DrawingHeader extends StatelessWidget {
  final GeneratedPattern pattern;
  final VoidCallback onSaveImage;

  const _DrawingHeader({required this.pattern, required this.onSaveImage});

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
              _ResultNavigationBar(onSaveImage: onSaveImage),
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

  const _ResultNavigationBar({required this.onSaveImage});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 24,
                height: 44,
                child: Icon(Icons.chevron_left, color: Colors.black, size: 30),
              ),
            ),
            const Expanded(
              child: Text(
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
            ),
            GestureDetector(
              key: const ValueKey('result-save-image-button'),
              behavior: HitTestBehavior.opaque,
              onTap: onSaveImage,
              child: const SizedBox(
                width: 24,
                height: 44,
                child: Center(child: _PixelPrinterIcon()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PixelPrinterIcon extends StatelessWidget {
  const _PixelPrinterIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _PixelPrinterPainter(),
    );
  }
}

class _PixelPrinterPainter extends CustomPainter {
  const _PixelPrinterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final dot = 1.538 * scale;
    final paint = Paint()..color = Colors.black;

    void draw(double x, double y, [double width = 1, double height = 1]) {
      canvas.drawRect(
        Rect.fromLTWH(x * scale, y * scale, dot * width, dot * height),
        paint,
      );
    }

    for (var x = 6.62; x <= 15.86; x += 1.538) {
      draw(x, 2);
      draw(x, 20.46);
    }
    for (final y in [3.54, 5.08, 18.92]) {
      draw(6.62, y);
      draw(15.86, y);
    }
    for (var x = 3.54; x <= 18.93; x += 1.538) {
      draw(x, 6.62);
    }
    for (final y in [8.15, 9.69, 11.23, 12.77, 14.31, 15.85]) {
      draw(2, y);
      draw(20.46, y);
    }
    for (var x = 6.62; x <= 15.86; x += 1.538) {
      draw(x, 14.31);
    }
    for (final x in [6.62, 15.86]) {
      draw(x, 15.85);
      draw(x, 17.38);
    }
    for (final x in [3.54, 5.08, 17.38, 18.93]) {
      draw(x, 17.38);
    }
    draw(11.23, 10.33, 4, 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  const _MaterialSummary({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('result-material-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
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
  final VoidCallback onEdit;

  const _BottomActionBar({required this.onStart, required this.onEdit});

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
                  label: '编辑',
                  onTap: onEdit,
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
  final bool filled;

  const _ResultActionButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = filled ? Colors.white : Colors.black;
    final backgroundColor = filled ? Colors.black : Colors.white;

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
                color: onTap == null
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
