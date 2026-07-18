import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/palette.dart';

class BeadBoardPreview extends StatefulWidget {
  static const int defaultBoardSize = 50;
  static const double colorRefMinEffectiveCellSize = 20;

  final Uint8List pixels;
  final Uint8List? layoutPixels;
  final int width;
  final int height;
  final int boardWidth;
  final int boardHeight;
  final List<PaletteEntry> paletteEntries;
  final String? selectedRef;
  final bool showRulers;
  final bool mirrorHorizontally;
  final bool interactionLocked;
  final int revision;
  final void Function(int x, int y)? onCellStart;
  final void Function(int x, int y)? onCellChanged;
  final VoidCallback? onCellEnd;

  const BeadBoardPreview({
    super.key,
    required this.pixels,
    this.layoutPixels,
    required this.width,
    required this.height,
    this.boardWidth = defaultBoardSize,
    this.boardHeight = defaultBoardSize,
    this.paletteEntries = const [],
    this.selectedRef,
    this.showRulers = true,
    this.mirrorHorizontally = false,
    this.interactionLocked = false,
    this.revision = 0,
    this.onCellStart,
    this.onCellChanged,
    this.onCellEnd,
  });

  @override
  State<BeadBoardPreview> createState() => _BeadBoardPreviewState();
}

class _BeadBoardPreviewState extends State<BeadBoardPreview> {
  late final TransformationController _transformationController;
  final Set<int> _activePointerIds = <int>{};
  double _scale = 1;
  int? _editingPointerId;
  _BoardCell? _pendingEditCell;
  bool _strokeStarted = false;

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
        final canEdit = widget.onCellStart != null;

        final childOffset = Offset(
          (maxWidth - boardSize.width) / 2,
          (maxHeight - boardSize.height) / 2,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(96),
                minScale: 0.8,
                maxScale: 18,
                panEnabled: !widget.interactionLocked && !canEdit,
                scaleEnabled: !widget.interactionLocked,
                child: Center(
                  child: Listener(
                    key: const ValueKey('pattern-editor-canvas'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: canEdit
                        ? (event) => _handlePointerDown(
                            event,
                            cellSize: cellSize,
                            labelBand: labelBand,
                          )
                        : null,
                    onPointerMove: canEdit
                        ? (event) => _handlePointerMove(
                            event,
                            cellSize: cellSize,
                            labelBand: labelBand,
                          )
                        : null,
                    onPointerUp: canEdit ? _handlePointerEnd : null,
                    onPointerCancel: canEdit ? _handlePointerEnd : null,
                    child: CustomPaint(
                      size: boardSize,
                      painter: BeadBoardPainter(
                        pixels: widget.pixels,
                        layoutPixels: widget.layoutPixels,
                        patternWidth: widget.width,
                        patternHeight: widget.height,
                        boardWidth: widget.boardWidth,
                        boardHeight: widget.boardHeight,
                        cellSize: cellSize,
                        labelBand: labelBand,
                        colorRefsByRgb: _colorRefsByRgb(widget.paletteEntries),
                        showColorRefs: showColorRefs,
                        selectedRef: widget.selectedRef,
                        showRulers: false,
                        mirrorHorizontally: widget.mirrorHorizontally,
                        revision: widget.revision,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showRulers)
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<Matrix4>(
                    valueListenable: _transformationController,
                    builder: (context, transform, child) => CustomPaint(
                      key: const ValueKey('bead-mode-pinned-rulers'),
                      painter: _PinnedBoardRulerPainter(
                        transform: transform,
                        boardWidth: widget.boardWidth,
                        boardHeight: widget.boardHeight,
                        cellSize: cellSize,
                        labelBand: labelBand,
                        childOffset: childOffset,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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

  _BoardCell? _cellAt(
    Offset localPosition, {
    required double cellSize,
    required double labelBand,
  }) {
    final boardX = ((localPosition.dx - labelBand) / cellSize).floor();
    final boardY = ((localPosition.dy - labelBand) / cellSize).floor();
    if (boardX < 0 ||
        boardX >= widget.boardWidth ||
        boardY < 0 ||
        boardY >= widget.boardHeight) {
      return null;
    }

    final bounds = _findActiveBounds(
      pixels: widget.layoutPixels ?? widget.pixels,
      width: widget.width,
      height: widget.height,
    );
    final activeLeft = bounds?.left ?? 0;
    final activeTop = bounds?.top ?? 0;
    final activeRight = bounds?.right ?? widget.width - 1;
    final activeBottom = bounds?.bottom ?? widget.height - 1;
    final activeWidth = activeRight - activeLeft + 1;
    final activeHeight = activeBottom - activeTop + 1;
    final originX = (widget.boardWidth - activeWidth) ~/ 2 - activeLeft;
    final originY = (widget.boardHeight - activeHeight) ~/ 2 - activeTop;
    var patternX = boardX - originX;
    final patternY = boardY - originY;

    if (widget.mirrorHorizontally) {
      patternX = activeLeft + activeRight - patternX;
    }
    if (patternX < 0 ||
        patternX >= widget.width ||
        patternY < 0 ||
        patternY >= widget.height) {
      return null;
    }
    return _BoardCell(patternX, patternY);
  }

  void _handlePointerDown(
    PointerDownEvent event, {
    required double cellSize,
    required double labelBand,
  }) {
    _activePointerIds.add(event.pointer);
    if (_activePointerIds.length != 1) {
      _cancelEditingStroke();
      return;
    }
    _editingPointerId = event.pointer;
    _pendingEditCell = _cellAt(
      event.localPosition,
      cellSize: cellSize,
      labelBand: labelBand,
    );
  }

  void _handlePointerMove(
    PointerEvent event, {
    required double cellSize,
    required double labelBand,
  }) {
    if (_activePointerIds.length != 1 || event.pointer != _editingPointerId) {
      return;
    }
    final cell = _cellAt(
      event.localPosition,
      cellSize: cellSize,
      labelBand: labelBand,
    );
    if (cell == null) return;

    if (!_strokeStarted) {
      final startCell = _pendingEditCell ?? cell;
      widget.onCellStart!(startCell.x, startCell.y);
      _pendingEditCell = null;
      _strokeStarted = true;
    }
    widget.onCellChanged?.call(cell.x, cell.y);
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointerIds.remove(event.pointer);
    if (event.pointer != _editingPointerId) return;

    if (_strokeStarted) {
      widget.onCellEnd?.call();
    } else {
      final cell = _pendingEditCell;
      if (cell != null) {
        widget.onCellStart!(cell.x, cell.y);
        widget.onCellEnd?.call();
      }
    }
    _clearEditingStroke();
  }

  void _cancelEditingStroke() {
    if (_strokeStarted) widget.onCellEnd?.call();
    _clearEditingStroke();
  }

  void _clearEditingStroke() {
    _editingPointerId = null;
    _pendingEditCell = null;
    _strokeStarted = false;
  }
}

class _BoardCell {
  final int x;
  final int y;

  const _BoardCell(this.x, this.y);
}

_PixelBounds? _findActiveBounds({
  required Uint8List pixels,
  required int width,
  required int height,
}) {
  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final alpha = pixels[(y * width + x) * 4 + 3];
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

class BeadBoardPainter extends CustomPainter {
  /// Returns the cropped pattern's translation in board-cell units.
  ///
  /// Centering is intentionally rounded to a whole cell. Grid lines are
  /// anchored to board cells, so a fractional translation would make them
  /// run through the middle of rendered beads.
  @visibleForTesting
  static Offset centeredPatternCellOffset({
    required int boardWidth,
    required int boardHeight,
    required int activeLeft,
    required int activeTop,
    required int activeRight,
    required int activeBottom,
  }) {
    final activeWidth = activeRight - activeLeft + 1;
    final activeHeight = activeBottom - activeTop + 1;
    return Offset(
      ((boardWidth - activeWidth) ~/ 2 - activeLeft).toDouble(),
      ((boardHeight - activeHeight) ~/ 2 - activeTop).toDouble(),
    );
  }

  final Uint8List pixels;
  final Uint8List? layoutPixels;
  final int patternWidth;
  final int patternHeight;
  final int boardWidth;
  final int boardHeight;
  final double cellSize;
  final double labelBand;
  final Map<int, String> colorRefsByRgb;
  final bool showColorRefs;
  final String? selectedRef;
  final bool showRulers;
  final bool mirrorHorizontally;
  final int revision;

  const BeadBoardPainter({
    required this.pixels,
    this.layoutPixels,
    required this.patternWidth,
    required this.patternHeight,
    required this.boardWidth,
    required this.boardHeight,
    required this.cellSize,
    required this.labelBand,
    this.colorRefsByRgb = const {},
    this.showColorRefs = false,
    this.selectedRef,
    this.showRulers = true,
    this.mirrorHorizontally = false,
    this.revision = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Rect.fromLTWH(
      labelBand,
      labelBand,
      boardWidth * cellSize,
      boardHeight * cellSize,
    );

    if (showRulers) _drawNumberBands(canvas, boardRect);
    _drawBoardBackground(canvas, boardRect);
    final bounds = _activeBounds();
    final patternOrigin = bounds == null
        ? null
        : _patternOrigin(boardRect, bounds);
    if (bounds != null) {
      _drawPattern(canvas, boardRect, bounds, patternOrigin!);
    }
    _drawFineGrid(canvas, boardRect);
    _drawMajorGrid(canvas, boardRect);
    if (bounds != null) {
      _drawPatternDetails(canvas, boardRect, bounds, patternOrigin!);
    }
    if (showRulers) _drawNumbers(canvas, boardRect);
  }

  void _drawNumberBands(Canvas canvas, Rect boardRect) {
    final labelPaint = Paint()..color = const Color(0x99000000);
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
    final lightPaint = Paint()..color = const Color(0xFFF9FAFC);
    final dotPaint = Paint()..color = const Color(0xFFE2E7EE);
    canvas.drawRect(boardRect, lightPaint);

    for (var y = 0; y < boardHeight; y++) {
      for (var x = 0; x < boardWidth; x++) {
        canvas.drawCircle(
          Offset(
            boardRect.left + (x + 0.5) * cellSize,
            boardRect.top + (y + 0.5) * cellSize,
          ),
          math.max(0.4, cellSize * 0.10),
          dotPaint,
        );
      }
    }
  }

  void _drawPattern(
    Canvas canvas,
    Rect boardRect,
    _PixelBounds bounds,
    Offset patternOrigin,
  ) {
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
          patternOrigin.dx + _displayX(x, bounds) * cellSize,
          patternOrigin.dy + y * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(beadRect, beadPaint);
      }
    }
    canvas.restore();
  }

  void _drawPatternDetails(
    Canvas canvas,
    Rect boardRect,
    _PixelBounds bounds,
    Offset patternOrigin,
  ) {
    if (!showColorRefs && selectedRef == null) return;

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
          patternOrigin.dx + _displayX(x, bounds) * cellSize,
          patternOrigin.dy + y * cellSize,
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
      ..color = const Color(0xFFFF0000)
      ..strokeWidth = cellSize.clamp(7.0, 14.0) * 0.06
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
      fontFamily: 'Alimama FangYuanTi VF',
      fontFamilyFallback: const ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'],
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

  int _displayX(int x, _PixelBounds bounds) {
    if (!mirrorHorizontally) return x;
    return bounds.left + bounds.right - x;
  }

  Offset _patternOrigin(Rect boardRect, _PixelBounds bounds) {
    final cellOffset = centeredPatternCellOffset(
      boardWidth: boardWidth,
      boardHeight: boardHeight,
      activeLeft: bounds.left,
      activeTop: bounds.top,
      activeRight: bounds.right,
      activeBottom: bounds.bottom,
    );
    return Offset(
      boardRect.left + cellOffset.dx * cellSize,
      boardRect.top + cellOffset.dy * cellSize,
    );
  }

  _PixelBounds? _activeBounds() {
    return _findActiveBounds(
      pixels: layoutPixels ?? pixels,
      width: patternWidth,
      height: patternHeight,
    );
  }

  @visibleForTesting
  Offset? get patternCellOffset {
    final bounds = _activeBounds();
    if (bounds == null) return null;
    return centeredPatternCellOffset(
      boardWidth: boardWidth,
      boardHeight: boardHeight,
      activeLeft: bounds.left,
      activeTop: bounds.top,
      activeRight: bounds.right,
      activeBottom: bounds.bottom,
    );
  }

  @override
  bool shouldRepaint(covariant BeadBoardPainter oldDelegate) {
    return oldDelegate.pixels != pixels ||
        oldDelegate.layoutPixels != layoutPixels ||
        oldDelegate.patternWidth != patternWidth ||
        oldDelegate.patternHeight != patternHeight ||
        oldDelegate.boardWidth != boardWidth ||
        oldDelegate.boardHeight != boardHeight ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.labelBand != labelBand ||
        oldDelegate.colorRefsByRgb != colorRefsByRgb ||
        oldDelegate.showColorRefs != showColorRefs ||
        oldDelegate.selectedRef != selectedRef ||
        oldDelegate.showRulers != showRulers ||
        oldDelegate.mirrorHorizontally != mirrorHorizontally ||
        oldDelegate.revision != revision;
  }
}

/// The visible ruler bands for a transformed bead board.
///
/// Each band follows the board while there is room to show it directly above
/// or to the left of the grid. Once that edge reaches the viewport, the band
/// sticks to the matching viewport edge instead.
@immutable
class BoardRulerPlacement {
  final Rect horizontalRuler;
  final Rect verticalRuler;

  const BoardRulerPlacement({
    required this.horizontalRuler,
    required this.verticalRuler,
  });

  factory BoardRulerPlacement.resolve({
    required Matrix4 transform,
    required int boardWidth,
    required int boardHeight,
    required double cellSize,
    required double labelBand,
    required Offset childOffset,
    double? rulerBandSize,
  }) {
    final boardTopLeft = MatrixUtils.transformPoint(transform, childOffset);
    final gridTopLeft = MatrixUtils.transformPoint(
      transform,
      childOffset + Offset(labelBand, labelBand),
    );
    final gridBottomRight = MatrixUtils.transformPoint(
      transform,
      childOffset +
          Offset(
            labelBand + boardWidth * cellSize,
            labelBand + boardHeight * cellSize,
          ),
    );
    final scale = transform.getMaxScaleOnAxis();
    final bandSize = rulerBandSize ?? labelBand * scale;
    final topPinned = boardTopLeft.dy <= 0;
    final leftPinned = boardTopLeft.dx <= 0;
    final horizontalLeft = leftPinned ? 0.0 : gridTopLeft.dx;
    final horizontalTop = topPinned ? 0.0 : boardTopLeft.dy;
    final verticalLeft = leftPinned ? 0.0 : boardTopLeft.dx;
    final verticalTop = topPinned ? 0.0 : gridTopLeft.dy;

    return BoardRulerPlacement(
      horizontalRuler: Rect.fromLTRB(
        horizontalLeft,
        horizontalTop,
        math.max(horizontalLeft, gridBottomRight.dx),
        horizontalTop + bandSize,
      ),
      verticalRuler: Rect.fromLTRB(
        verticalLeft,
        verticalTop,
        verticalLeft + bandSize,
        math.max(verticalTop, gridBottomRight.dy),
      ),
    );
  }
}

class _PinnedBoardRulerPainter extends CustomPainter {
  final Matrix4 transform;
  final int boardWidth;
  final int boardHeight;
  final double cellSize;
  final double labelBand;
  final Offset childOffset;

  const _PinnedBoardRulerPainter({
    required this.transform,
    required this.boardWidth,
    required this.boardHeight,
    required this.cellSize,
    required this.labelBand,
    required this.childOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.getMaxScaleOnAxis();
    final bandSize = (labelBand * scale)
        .clamp(5.0, math.min(size.width, size.height) * 0.2)
        .toDouble();
    final placement = BoardRulerPlacement.resolve(
      transform: transform,
      boardWidth: boardWidth,
      boardHeight: boardHeight,
      cellSize: cellSize,
      labelBand: labelBand,
      childOffset: childOffset,
      rulerBandSize: bandSize,
    );
    final bandPaint = Paint()..color = const Color(0x99000000);
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: (math.min(labelBand * 0.62, cellSize * 0.72) * scale).clamp(
        5.0,
        36.0,
      ),
      fontFamily: 'Alimama FangYuanTi VF',
      fontFamilyFallback: const ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'],
      fontWeight: FontWeight.w800,
      height: 1,
    );

    canvas.drawRect(placement.horizontalRuler, bandPaint);
    canvas.drawRect(placement.verticalRuler, bandPaint);

    final boardOrigin = childOffset + Offset(labelBand, labelBand);
    _drawHorizontalLabels(
      canvas,
      size,
      boardOrigin,
      placement.horizontalRuler,
      textStyle,
    );
    _drawVerticalLabels(
      canvas,
      size,
      boardOrigin,
      placement.verticalRuler,
      textStyle,
    );
  }

  void _drawHorizontalLabels(
    Canvas canvas,
    Size size,
    Offset boardOrigin,
    Rect rulerRect,
    TextStyle textStyle,
  ) {
    canvas.save();
    canvas.clipRect(rulerRect.intersect(Offset.zero & size));
    for (var x = 0; x < boardWidth; x++) {
      final start = _toViewport(
        Offset(boardOrigin.dx + x * cellSize, boardOrigin.dy),
      );
      final end = _toViewport(
        Offset(boardOrigin.dx + (x + 1) * cellSize, boardOrigin.dy),
      );
      if (end.dx < rulerRect.left || start.dx > rulerRect.right) continue;

      final rect = Rect.fromCenter(
        center: Offset(
          (start.dx + end.dx) / 2,
          rulerRect.top + rulerRect.height / 2,
        ),
        width: (end.dx - start.dx).abs(),
        height: rulerRect.height,
      );
      _drawCenteredText(canvas, '${x + 1}', rect, textStyle);
    }
    canvas.restore();
  }

  void _drawVerticalLabels(
    Canvas canvas,
    Size size,
    Offset boardOrigin,
    Rect rulerRect,
    TextStyle textStyle,
  ) {
    canvas.save();
    canvas.clipRect(rulerRect.intersect(Offset.zero & size));
    for (var y = 0; y < boardHeight; y++) {
      final start = _toViewport(
        Offset(boardOrigin.dx, boardOrigin.dy + y * cellSize),
      );
      final end = _toViewport(
        Offset(boardOrigin.dx, boardOrigin.dy + (y + 1) * cellSize),
      );
      if (end.dy < rulerRect.top || start.dy > rulerRect.bottom) continue;

      final rect = Rect.fromCenter(
        center: Offset(
          rulerRect.left + rulerRect.width / 2,
          (start.dy + end.dy) / 2,
        ),
        width: rulerRect.width,
        height: (end.dy - start.dy).abs(),
      );
      _drawCenteredText(canvas, '${y + 1}', rect, textStyle);
    }
    canvas.restore();
  }

  Offset _toViewport(Offset point) =>
      MatrixUtils.transformPoint(transform, point);

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

  @override
  bool shouldRepaint(covariant _PinnedBoardRulerPainter oldDelegate) => true;
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
  final bool compact;
  final String? selectedRef;
  final ValueChanged<String?>? onSelected;

  const BeadModeUsageStrip({
    super.key,
    required this.usage,
    required this.entries,
    this.compact = false,
    this.selectedRef,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sortedUsage = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final strip = SizedBox(
      width: compact ? double.infinity : null,
      height: compact ? 106 : 118,
      child: ListView.separated(
        padding: compact
            ? const EdgeInsets.all(20)
            : const EdgeInsets.fromLTRB(20, 8, 20, 14),
        scrollDirection: Axis.horizontal,
        itemCount: compact ? sortedUsage.length : sortedUsage.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final _UsageTile tile;
          if (!compact && index == 0) {
            tile = _UsageTile(
              count: usage.values.fold(0, (sum, count) => sum + count),
              label: '全部',
              color: const Color(0xFF2D2D2D),
              compact: compact,
              selected: selectedRef == null,
              onTap: onSelected == null ? null : () => onSelected!(null),
            );
          } else {
            final item = sortedUsage[compact ? index : index - 1];
            final entry = _findEntry(item.key);
            final color = entry == null
                ? Colors.grey
                : Color.fromARGB(
                    255,
                    entry.color.rInt,
                    entry.color.gInt,
                    entry.color.bInt,
                  );
            tile = _UsageTile(
              count: item.value,
              label: item.key,
              color: color,
              compact: compact,
              selected: selectedRef == item.key,
              onTap: onSelected == null
                  ? null
                  : () => onSelected!(
                      compact && selectedRef == item.key ? null : item.key,
                    ),
            );
          }

          return compact ? Center(child: tile) : tile;
        },
      ),
    );

    if (!compact) return strip;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(color: Colors.white, child: strip),
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
  final bool compact;
  final bool selected;
  final VoidCallback? onTap;

  const _UsageTile({
    required this.count,
    required this.label,
    required this.color,
    required this.compact,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color.computeLuminance() > 0.55
        ? const Color(0xFF263241)
        : Colors.white;
    final cardPadding = compact
        ? EdgeInsets.all(selected ? 2 : 4)
        : const EdgeInsets.all(8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          key: ValueKey('bead-color-tile-$label'),
          width: compact ? 49 : 78,
          padding: cardPadding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.black
                  : compact
                  ? const Color(0x1F000000)
                  : Colors.transparent,
              width: selected
                  ? 2
                  : compact
                  ? 0.5
                  : 1,
            ),
            boxShadow: compact
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            children: [
              compact
                  ? SizedBox(
                      key: ValueKey('bead-color-swatch-$label'),
                      width: 40,
                      height: 40,
                      child: _ColorLabel(
                        label: label,
                        color: color,
                        textColor: textColor,
                        compact: true,
                      ),
                    )
                  : Expanded(
                      child: _ColorLabel(
                        label: '$count',
                        color: color,
                        textColor: textColor,
                        compact: false,
                      ),
                    ),
              SizedBox(height: compact ? 4 : 7),
              SizedBox(
                width: compact ? 36 : null,
                child: Text(
                  compact ? '$count' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: compact ? Colors.black : const Color(0xFF667085),
                    fontSize:
                        compact &&
                            label.length > 3 &&
                            count.toString().length >= 5
                        ? 11
                        : compact
                        ? 12
                        : 14,
                    fontFamily: 'Alimama FangYuanTi VF',
                    fontFamilyFallback: const [
                      'PingFang SC',
                      'Heiti SC',
                      'Microsoft YaHei',
                    ],
                    fontWeight: compact ? FontWeight.w500 : FontWeight.w700,
                    height: compact ? 13 / 12 : null,
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

class _ColorLabel extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool compact;

  const _ColorLabel({
    required this.label,
    required this.color,
    required this.textColor,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(compact ? 8 : 9),
        border: Border.all(
          color: compact ? const Color(0x4C878787) : const Color(0x14000000),
          width: compact ? 0.5 : 1,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: compact ? 14 : 20,
          fontFamily: 'Alimama FangYuanTi VF',
          fontFamilyFallback: const [
            'PingFang SC',
            'Heiti SC',
            'Microsoft YaHei',
          ],
          fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
          height: compact ? 16 / 14 : 1,
        ),
      ),
    );
  }
}
