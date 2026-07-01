import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/palette.dart';

class BeadBoardPreview extends StatefulWidget {
  static const int defaultBoardSize = 50;
  static const double colorRefMinEffectiveCellSize = 20;

  final Uint8List pixels;
  final int width;
  final int height;
  final int boardWidth;
  final int boardHeight;
  final List<PaletteEntry> paletteEntries;
  final String? selectedRef;

  const BeadBoardPreview({
    super.key,
    required this.pixels,
    required this.width,
    required this.height,
    this.boardWidth = defaultBoardSize,
    this.boardHeight = defaultBoardSize,
    this.paletteEntries = const [],
    this.selectedRef,
  });

  @override
  State<BeadBoardPreview> createState() => _BeadBoardPreviewState();
}

class _BeadBoardPreviewState extends State<BeadBoardPreview> {
  late final TransformationController _transformationController;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController()
      ..addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final nextScale = _transformationController.value.getMaxScaleOnAxis();
    if ((nextScale - _scale).abs() < 0.05) return;
    setState(() => _scale = nextScale);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : widget.boardWidth * 8.0;
        final maxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.boardHeight * 8.0;
        const labelBandCells = 1.25;
        final cellSize = math
            .min(
              maxWidth / (widget.boardWidth + labelBandCells * 2),
              maxHeight / (widget.boardHeight + labelBandCells * 2),
            )
            .clamp(2.5, 18.0)
            .toDouble();
        final labelBand = cellSize * labelBandCells;
        final boardSize = Size(
          widget.boardWidth * cellSize + labelBand * 2,
          widget.boardHeight * cellSize + labelBand * 2,
        );
        final showColorRefs =
            cellSize * _scale >= BeadBoardPreview.colorRefMinEffectiveCellSize;

        return InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(96),
          minScale: 0.8,
          maxScale: 18,
          child: Center(
            child: CustomPaint(
              size: boardSize,
              painter: BeadBoardPainter(
                pixels: widget.pixels,
                patternWidth: widget.width,
                patternHeight: widget.height,
                boardWidth: widget.boardWidth,
                boardHeight: widget.boardHeight,
                cellSize: cellSize,
                labelBand: labelBand,
                colorRefsByRgb: _colorRefsByRgb(widget.paletteEntries),
                showColorRefs: showColorRefs,
                selectedRef: widget.selectedRef,
              ),
            ),
          ),
        );
      },
    );
  }

  Map<int, String> _colorRefsByRgb(List<PaletteEntry> entries) {
    return {
      for (final entry in entries)
        _rgbKey(entry.color.rInt, entry.color.gInt, entry.color.bInt):
            entry.ref,
    };
  }
}

class BeadBoardPainter extends CustomPainter {
  final Uint8List pixels;
  final int patternWidth;
  final int patternHeight;
  final int boardWidth;
  final int boardHeight;
  final double cellSize;
  final double labelBand;
  final Map<int, String> colorRefsByRgb;
  final bool showColorRefs;
  final String? selectedRef;

  const BeadBoardPainter({
    required this.pixels,
    required this.patternWidth,
    required this.patternHeight,
    required this.boardWidth,
    required this.boardHeight,
    required this.cellSize,
    required this.labelBand,
    this.colorRefsByRgb = const {},
    this.showColorRefs = false,
    this.selectedRef,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Rect.fromLTWH(
      labelBand,
      labelBand,
      boardWidth * cellSize,
      boardHeight * cellSize,
    );

    _drawNumberBands(canvas, boardRect);
    _drawBoardBackground(canvas, boardRect);
    _drawPattern(canvas, boardRect);
    _drawFineGrid(canvas, boardRect);
    _drawMajorGrid(canvas, boardRect);
    _drawPatternDetails(canvas, boardRect);
    _drawNumbers(canvas, boardRect);
  }

  void _drawNumberBands(Canvas canvas, Rect boardRect) {
    final labelPaint = Paint()..color = const Color(0xFFFF7FA2);
    canvas.drawRect(
      Rect.fromLTWH(boardRect.left, 0, boardRect.width, labelBand),
      labelPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        boardRect.left,
        boardRect.bottom,
        boardRect.width,
        labelBand,
      ),
      labelPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, boardRect.top, labelBand, boardRect.height),
      labelPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        boardRect.right,
        boardRect.top,
        labelBand,
        boardRect.height,
      ),
      labelPaint,
    );
  }

  void _drawBoardBackground(Canvas canvas, Rect boardRect) {
    final lightPaint = Paint()..color = const Color(0xFFFFFFFF);
    final shadePaint = Paint()..color = const Color(0xFFF1F7FC);
    canvas.drawRect(boardRect, lightPaint);

    for (var y = 0; y < boardHeight; y++) {
      for (var x = 0; x < boardWidth; x++) {
        if ((x + y).isEven) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            boardRect.left + x * cellSize,
            boardRect.top + y * cellSize,
            cellSize,
            cellSize,
          ),
          shadePaint,
        );
      }
    }
  }

  void _drawPattern(Canvas canvas, Rect boardRect) {
    final bounds = _activeBounds();
    if (bounds == null) return;

    final activeWidth = bounds.right - bounds.left + 1;
    final activeHeight = bounds.bottom - bounds.top + 1;
    final xOffset =
        boardRect.left +
        (boardWidth - activeWidth) * cellSize / 2 -
        bounds.left * cellSize;
    final yOffset =
        boardRect.top +
        (boardHeight - activeHeight) * cellSize / 2 -
        bounds.top * cellSize;
    final beadPaint = Paint()..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRect(boardRect);
    for (var y = 0; y < patternHeight; y++) {
      for (var x = 0; x < patternWidth; x++) {
        final offset = (y * patternWidth + x) * 4;
        final alpha = pixels[offset + 3];
        if (alpha == 0) continue;

        final colorKey = _rgbKey(
          pixels[offset],
          pixels[offset + 1],
          pixels[offset + 2],
        );
        final ref = colorRefsByRgb[colorKey];
        final originalColor = Color.fromARGB(
          alpha,
          pixels[offset],
          pixels[offset + 1],
          pixels[offset + 2],
        );
        final isDimmed = selectedRef != null && ref != selectedRef;
        beadPaint.color = isDimmed
            ? _dimmedColor(
                alpha,
                pixels[offset],
                pixels[offset + 1],
                pixels[offset + 2],
              )
            : originalColor;
        final beadRect = Rect.fromLTWH(
          xOffset + x * cellSize,
          yOffset + y * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(beadRect, beadPaint);
      }
    }
    canvas.restore();
  }

  void _drawPatternDetails(Canvas canvas, Rect boardRect) {
    if (!showColorRefs && selectedRef == null) return;

    final bounds = _activeBounds();
    if (bounds == null) return;

    final activeWidth = bounds.right - bounds.left + 1;
    final activeHeight = bounds.bottom - bounds.top + 1;
    final xOffset =
        boardRect.left +
        (boardWidth - activeWidth) * cellSize / 2 -
        bounds.left * cellSize;
    final yOffset =
        boardRect.top +
        (boardHeight - activeHeight) * cellSize / 2 -
        bounds.top * cellSize;

    canvas.save();
    canvas.clipRect(boardRect);
    for (var y = 0; y < patternHeight; y++) {
      for (var x = 0; x < patternWidth; x++) {
        final offset = (y * patternWidth + x) * 4;
        final alpha = pixels[offset + 3];
        if (alpha == 0) continue;

        final colorKey = _rgbKey(
          pixels[offset],
          pixels[offset + 1],
          pixels[offset + 2],
        );
        final ref = colorRefsByRgb[colorKey];
        final isHighlighted = selectedRef != null && ref == selectedRef;
        final isDimmed = selectedRef != null && ref != selectedRef;
        final beadColor = isDimmed
            ? _dimmedColor(
                alpha,
                pixels[offset],
                pixels[offset + 1],
                pixels[offset + 2],
              )
            : Color.fromARGB(
                alpha,
                pixels[offset],
                pixels[offset + 1],
                pixels[offset + 2],
              );
        final beadRect = Rect.fromLTWH(
          xOffset + x * cellSize,
          yOffset + y * cellSize,
          cellSize,
          cellSize,
        );

        if (isHighlighted) {
          _drawHighlightBorder(canvas, beadRect);
        }
        if (showColorRefs) {
          if (ref != null) {
            _drawColorRef(canvas, ref, beadRect, beadColor);
          }
        }
      }
    }
    canvas.restore();
  }

  void _drawFineGrid(Canvas canvas, Rect boardRect) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE0ECF5)
      ..strokeWidth = math.max(0.35, cellSize * 0.04);

    for (var x = 0; x <= boardWidth; x++) {
      final dx = boardRect.left + x * cellSize;
      canvas.drawLine(
        Offset(dx, boardRect.top),
        Offset(dx, boardRect.bottom),
        gridPaint,
      );
    }
    for (var y = 0; y <= boardHeight; y++) {
      final dy = boardRect.top + y * cellSize;
      canvas.drawLine(
        Offset(boardRect.left, dy),
        Offset(boardRect.right, dy),
        gridPaint,
      );
    }
  }

  void _drawMajorGrid(Canvas canvas, Rect boardRect) {
    final majorPaint = Paint()
      ..color = const Color(0xFFE63946)
      ..strokeWidth = cellSize.clamp(7.0, 14.0) * 0.22
      ..strokeCap = StrokeCap.square;

    for (var x = 0; x <= boardWidth; x += 10) {
      final dx = boardRect.left + x * cellSize;
      canvas.drawLine(
        Offset(dx, boardRect.top),
        Offset(dx, boardRect.bottom),
        majorPaint,
      );
    }
    if (boardWidth % 10 != 0) {
      canvas.drawLine(
        Offset(boardRect.right, boardRect.top),
        Offset(boardRect.right, boardRect.bottom),
        majorPaint,
      );
    }

    for (var y = 0; y <= boardHeight; y += 10) {
      final dy = boardRect.top + y * cellSize;
      canvas.drawLine(
        Offset(boardRect.left, dy),
        Offset(boardRect.right, dy),
        majorPaint,
      );
    }
    if (boardHeight % 10 != 0) {
      canvas.drawLine(
        Offset(boardRect.left, boardRect.bottom),
        Offset(boardRect.right, boardRect.bottom),
        majorPaint,
      );
    }
  }

  void _drawNumbers(Canvas canvas, Rect boardRect) {
    final style = TextStyle(
      color: Colors.white,
      fontSize: math.min(labelBand * 0.62, cellSize * 0.72),
      fontWeight: FontWeight.w800,
      height: 1,
    );

    for (var x = 0; x < boardWidth; x++) {
      final label = '${x + 1}';
      final left = boardRect.left + x * cellSize;
      _drawCenteredText(
        canvas,
        label,
        Rect.fromLTWH(left, 0, cellSize, labelBand),
        style,
      );
      _drawCenteredText(
        canvas,
        label,
        Rect.fromLTWH(left, boardRect.bottom, cellSize, labelBand),
        style,
      );
    }

    for (var y = 0; y < boardHeight; y++) {
      final label = '${y + 1}';
      final top = boardRect.top + y * cellSize;
      _drawCenteredText(
        canvas,
        label,
        Rect.fromLTWH(0, top, labelBand, cellSize),
        style,
      );
      _drawCenteredText(
        canvas,
        label,
        Rect.fromLTWH(boardRect.right, top, labelBand, cellSize),
        style,
      );
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  void _drawColorRef(Canvas canvas, String ref, Rect rect, Color beadColor) {
    final foreground = beadColor.computeLuminance() > 0.52
        ? const Color(0xFF111827)
        : Colors.white;
    final painter = TextPainter(
      text: TextSpan(
        text: ref,
        style: TextStyle(
          color: foreground,
          fontSize: cellSize * 0.28,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width);

    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  void _drawHighlightBorder(Canvas canvas, Rect rect) {
    final strokeWidth = math.max(0.45, cellSize * 0.005);
    final borderPaint = Paint()
      ..color = const Color(0xFFFF4B58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRect(rect.deflate(strokeWidth / 2), borderPaint);
  }

  _PixelBounds? _activeBounds() {
    var minX = patternWidth;
    var minY = patternHeight;
    var maxX = -1;
    var maxY = -1;

    for (var y = 0; y < patternHeight; y++) {
      for (var x = 0; x < patternWidth; x++) {
        final alpha = pixels[(y * patternWidth + x) * 4 + 3];
        if (alpha == 0) continue;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }

    if (maxX < 0 || maxY < 0) return null;
    return _PixelBounds(minX, minY, maxX, maxY);
  }

  @override
  bool shouldRepaint(covariant BeadBoardPainter oldDelegate) {
    return oldDelegate.pixels != pixels ||
        oldDelegate.patternWidth != patternWidth ||
        oldDelegate.patternHeight != patternHeight ||
        oldDelegate.boardWidth != boardWidth ||
        oldDelegate.boardHeight != boardHeight ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.labelBand != labelBand ||
        oldDelegate.colorRefsByRgb != colorRefsByRgb ||
        oldDelegate.showColorRefs != showColorRefs ||
        oldDelegate.selectedRef != selectedRef;
  }
}

int _rgbKey(int r, int g, int b) => (r << 16) | (g << 8) | b;

Color _dimmedColor(int alpha, int red, int green, int blue) {
  return Color.fromARGB(
    alpha,
    _blendTowardGray(red),
    _blendTowardGray(green),
    _blendTowardGray(blue),
  );
}

int _blendTowardGray(int value) {
  return (value + (199 - value) * 0.86).round().clamp(0, 255);
}

class _PixelBounds {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const _PixelBounds(this.left, this.top, this.right, this.bottom);
}

class BeadModeUsageStrip extends StatelessWidget {
  final Map<String, int> usage;
  final List<PaletteEntry> entries;
  final String? selectedRef;
  final ValueChanged<String?>? onSelected;

  const BeadModeUsageStrip({
    super.key,
    required this.usage,
    required this.entries,
    this.selectedRef,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sortedUsage = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 118,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        scrollDirection: Axis.horizontal,
        itemCount: sortedUsage.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _UsageTile(
              count: usage.values.fold(0, (sum, count) => sum + count),
              label: '全部',
              color: const Color(0xFF2D2D2D),
              selected: selectedRef == null,
              onTap: onSelected == null ? null : () => onSelected!(null),
            );
          }

          final item = sortedUsage[index - 1];
          final entry = _findEntry(item.key);
          final color = entry == null
              ? Colors.grey
              : Color.fromARGB(
                  255,
                  entry.color.rInt,
                  entry.color.gInt,
                  entry.color.bInt,
                );
          return _UsageTile(
            count: item.value,
            label: item.key,
            color: color,
            selected: selectedRef == item.key,
            onTap: onSelected == null ? null : () => onSelected!(item.key),
          );
        },
      ),
    );
  }

  PaletteEntry? _findEntry(String ref) {
    for (final entry in entries) {
      if (entry.ref == ref) return entry;
    }
    return null;
  }
}

class _UsageTile extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _UsageTile({
    required this.count,
    required this.label,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color.computeLuminance() > 0.55
        ? const Color(0xFF263241)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 78,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFFFF5C6C) : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0x14000000)),
                  ),
                  child: Text(
                    '$count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
