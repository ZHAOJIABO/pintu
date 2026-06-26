import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/color.dart';
import '../models/palette.dart';
import '../models/pattern_chart.dart';

class PatternChartPainter extends CustomPainter {
  static const double minReadableCellSize = 7;

  final PatternChartData chart;
  final double cellSize;
  final bool showCellLabels;
  final bool showCoordinates;

  PatternChartPainter({
    required this.chart,
    required this.cellSize,
    this.showCellLabels = true,
    this.showCoordinates = false,
  });

  static double coordinateGutter({
    required double cellSize,
    required bool showCoordinates,
  }) {
    if (!showCoordinates) return 0;
    return (cellSize * 1.25).clamp(18.0, 32.0).toDouble();
  }

  static Size chartSize({
    required PatternChartData chart,
    required double cellSize,
    required bool showCoordinates,
  }) {
    final gutter = coordinateGutter(
      cellSize: cellSize,
      showCoordinates: showCoordinates,
    );
    return Size(
      gutter + chart.width * cellSize,
      gutter + chart.height * cellSize,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gutter = coordinateGutter(
      cellSize: cellSize,
      showCoordinates: showCoordinates,
    );
    final origin = Offset(gutter, gutter);
    final gridWidth = chart.width * cellSize;
    final gridHeight = chart.height * cellSize;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawRect(
      origin & Size(gridWidth, gridHeight),
      Paint()..color = const Color(0xFFFDFDFD),
    );

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final textCache = <_TextCacheKey, TextPainter>{};
    final shouldDrawLabels = showCellLabels && cellSize >= minReadableCellSize;

    for (int y = 0; y < chart.height; y++) {
      for (int x = 0; x < chart.width; x++) {
        final cell = chart.cellAt(x, y);
        final rect = Rect.fromLTWH(
          origin.dx + x * cellSize,
          origin.dy + y * cellSize,
          cellSize,
          cellSize,
        );

        if (cell == null) {
          fillPaint.color = const Color(0xFFFFFFFF);
          canvas.drawRect(rect, fillPaint);
          continue;
        }

        fillPaint.color = _toFlutterColor(cell.color);
        canvas.drawRect(rect, fillPaint);

        if (shouldDrawLabels) {
          final labelColor = _labelColorFor(cell);
          final painter = textCache.putIfAbsent(
            _TextCacheKey(cell.ref, labelColor, cellSize),
            () => _buildCellLabel(cell.ref, labelColor),
          );
          painter.paint(
            canvas,
            Offset(
              rect.center.dx - painter.width / 2,
              rect.center.dy - painter.height / 2,
            ),
          );
        }
      }
    }

    _drawGrid(canvas, origin, gridWidth, gridHeight);
    if (showCoordinates) {
      _drawCoordinates(canvas, origin);
    }
  }

  void _drawGrid(Canvas canvas, Offset origin, double width, double height) {
    final minorPaint = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = math.max(0.4, cellSize * 0.025);
    final majorPaint = Paint()
      ..color = const Color(0x665C54D8)
      ..strokeWidth = math.max(0.8, cellSize * 0.055);

    for (int x = 0; x <= chart.width; x++) {
      final paint = x % 5 == 0 ? majorPaint : minorPaint;
      final dx = origin.dx + x * cellSize;
      canvas.drawLine(
        Offset(dx, origin.dy),
        Offset(dx, origin.dy + height),
        paint,
      );
    }
    for (int y = 0; y <= chart.height; y++) {
      final paint = y % 5 == 0 ? majorPaint : minorPaint;
      final dy = origin.dy + y * cellSize;
      canvas.drawLine(
        Offset(origin.dx, dy),
        Offset(origin.dx + width, dy),
        paint,
      );
    }
  }

  void _drawCoordinates(Canvas canvas, Offset origin) {
    final style = TextStyle(
      color: const Color(0xFF8D8C96),
      fontSize: (cellSize * 0.36).clamp(7.0, 10.0).toDouble(),
      fontWeight: FontWeight.w500,
    );
    final cache = <String, TextPainter>{};

    TextPainter label(String text) {
      return cache.putIfAbsent(
        text,
        () => TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
    }

    for (int x = 0; x < chart.width; x++) {
      final text = '${x + 1}';
      final painter = label(text);
      final dx = origin.dx + x * cellSize + cellSize / 2 - painter.width / 2;
      painter.paint(canvas, Offset(dx, origin.dy - painter.height - 4));
    }
    for (int y = 0; y < chart.height; y++) {
      final text = '${y + 1}';
      final painter = label(text);
      final dy = origin.dy + y * cellSize + cellSize / 2 - painter.height / 2;
      painter.paint(canvas, Offset(origin.dx - painter.width - 6, dy));
    }
  }

  TextPainter _buildCellLabel(String ref, Color color) {
    final fontSize = (cellSize * 0.42).clamp(3.0, 10.0).toDouble();
    return TextPainter(
      text: TextSpan(
        text: ref,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: cellSize);
  }

  Color _labelColorFor(PatternChartCell cell) {
    final color = foregroundColor(cell.color);
    return _toFlutterColor(color);
  }

  Color _toFlutterColor(BeadColor color) {
    return Color.fromARGB(color.aInt, color.rInt, color.gInt, color.bInt);
  }

  @override
  bool shouldRepaint(covariant PatternChartPainter oldDelegate) {
    return oldDelegate.chart != chart ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.showCellLabels != showCellLabels ||
        oldDelegate.showCoordinates != showCoordinates;
  }
}

class PatternChartPagePainter extends CustomPainter {
  static const double pageMargin = 32;
  static const double headerHeight = 88;
  static const double legendTopPadding = 28;
  static const double legendItemWidth = 88;
  static const double legendItemHeight = 82;

  final PatternChartData chart;
  final Map<String, int> usage;
  final List<PaletteEntry> paletteEntries;
  final String title;
  final double cellSize;

  PatternChartPagePainter({
    required this.chart,
    required this.usage,
    required this.paletteEntries,
    required this.title,
    required this.cellSize,
  });

  Size get pageSize {
    final chartSize = PatternChartPainter.chartSize(
      chart: chart,
      cellSize: cellSize,
      showCoordinates: true,
    );
    final width = math.max(680.0, chartSize.width + pageMargin * 2);
    final legendRows = math.max(
      1,
      (_legendItems.length / _itemsPerRow(width)).ceil(),
    );
    final legendHeight = legendTopPadding + legendRows * legendItemHeight + 18;
    return Size(
      width,
      pageMargin + headerHeight + chartSize.height + legendHeight + pageMargin,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );

    _drawHeader(canvas, size);

    final chartOrigin = Offset(pageMargin, pageMargin + headerHeight);
    final chartPainter = PatternChartPainter(
      chart: chart,
      cellSize: cellSize,
      showCoordinates: true,
    );
    canvas.save();
    canvas.translate(chartOrigin.dx, chartOrigin.dy);
    chartPainter.paint(
      canvas,
      PatternChartPainter.chartSize(
        chart: chart,
        cellSize: cellSize,
        showCoordinates: true,
      ),
    );
    canvas.restore();

    final chartSize = PatternChartPainter.chartSize(
      chart: chart,
      cellSize: cellSize,
      showCoordinates: true,
    );
    _drawLegend(
      canvas,
      Offset(pageMargin, chartOrigin.dy + chartSize.height + legendTopPadding),
      size.width,
    );
  }

  void _drawHeader(Canvas canvas, Size size) {
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - pageMargin * 2);
    titlePainter.paint(canvas, Offset(pageMargin, pageMargin));

    final totalBeads = usage.values.fold<int>(0, (sum, count) => sum + count);
    final summaryPainter = TextPainter(
      text: TextSpan(
        text:
            '${chart.width} x ${chart.height}  |  $totalBeads颗豆子  |  ${usage.length}色',
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 20,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - pageMargin * 2);
    summaryPainter.paint(canvas, Offset(pageMargin, pageMargin + 46));
  }

  void _drawLegend(Canvas canvas, Offset origin, double pageWidth) {
    final items = _legendItems;
    final itemsPerRow = _itemsPerRow(pageWidth);
    final swatchPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final col = i % itemsPerRow;
      final row = i ~/ itemsPerRow;
      final x = origin.dx + col * legendItemWidth;
      final y = origin.dy + row * legendItemHeight;
      final swatchRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 4, y, 52, 52),
        const Radius.circular(8),
      );

      swatchPaint.color = Color.fromARGB(
        item.entry.color.aInt,
        item.entry.color.rInt,
        item.entry.color.gInt,
        item.entry.color.bInt,
      );
      canvas.drawRRect(swatchRect, swatchPaint);

      final refColor = foregroundColor(item.entry.color);
      final refPainter = TextPainter(
        text: TextSpan(
          text: item.entry.ref,
          style: TextStyle(
            color: Color.fromARGB(
              refColor.aInt,
              refColor.rInt,
              refColor.gInt,
              refColor.bInt,
            ),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 52);
      refPainter.paint(
        canvas,
        Offset(
          x + 4 + 26 - refPainter.width / 2,
          y + 26 - refPainter.height / 2,
        ),
      );

      final countPainter = TextPainter(
        text: TextSpan(
          text: 'x${item.count}',
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: legendItemWidth);
      countPainter.paint(canvas, Offset(x + 4, y + 62));
    }
  }

  int _itemsPerRow(double pageWidth) {
    final available = pageWidth - pageMargin * 2;
    return math.max(1, (available / legendItemWidth).floor());
  }

  List<_LegendItem> get _legendItems {
    final items = <_LegendItem>[];
    final usedRefs = <String>{};
    for (final entry in paletteEntries) {
      final count = usage[entry.ref];
      if (count == null || count == 0) continue;
      items.add(_LegendItem(entry: entry, count: count));
      usedRefs.add(entry.ref);
    }

    for (final item in usage.entries) {
      if (usedRefs.contains(item.key)) continue;
      final fallback = PaletteEntry(
        name: item.key,
        ref: item.key,
        symbol: item.key,
        color: BeadColor.fromInt(180, 180, 180, 255),
        prefix: '',
      );
      items.add(_LegendItem(entry: fallback, count: item.value));
    }
    return items;
  }

  @override
  bool shouldRepaint(covariant PatternChartPagePainter oldDelegate) {
    return oldDelegate.chart != chart ||
        oldDelegate.usage != usage ||
        oldDelegate.paletteEntries != paletteEntries ||
        oldDelegate.title != title ||
        oldDelegate.cellSize != cellSize;
  }
}

class _LegendItem {
  final PaletteEntry entry;
  final int count;

  const _LegendItem({required this.entry, required this.count});
}

class _TextCacheKey {
  final String ref;
  final Color color;
  final double cellSize;

  const _TextCacheKey(this.ref, this.color, this.cellSize);

  @override
  bool operator ==(Object other) {
    return other is _TextCacheKey &&
        other.ref == ref &&
        other.color == color &&
        other.cellSize == cellSize;
  }

  @override
  int get hashCode => Object.hash(ref, color, cellSize);
}
