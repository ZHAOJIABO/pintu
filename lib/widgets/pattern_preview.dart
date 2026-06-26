import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/palette.dart';
import '../models/pattern_chart.dart';
import '../models/project.dart';
import '../rendering/bead_painter.dart';
import '../rendering/pattern_chart_painter.dart';

enum PatternPreviewMode { beads, chart }

class PatternPreview extends StatelessWidget {
  final Uint8List pixels;
  final int width;
  final int height;
  final bool showGrid;
  final PatternPreviewMode mode;
  final List<PaletteEntry> paletteEntries;

  const PatternPreview({
    super.key,
    required this.pixels,
    required this.width,
    required this.height,
    this.showGrid = false,
    this.mode = PatternPreviewMode.beads,
    this.paletteEntries = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (mode == PatternPreviewMode.chart) {
          return _buildChartPreview(constraints);
        }

        return _buildBeadPreview(constraints);
      },
    );
  }

  Widget _buildBeadPreview(BoxConstraints constraints) {
    final fitBeadSize = (constraints.maxWidth / width).clamp(
      1.0,
      constraints.maxHeight / height,
    );
    final canvasWidth = width * fitBeadSize;
    final canvasHeight = height * fitBeadSize;

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 12,
      child: Center(
        child: CustomPaint(
          size: Size(canvasWidth, canvasHeight),
          painter: BeadPainter(
            pixels: pixels,
            imageWidth: width,
            imageHeight: height,
            beadSize: fitBeadSize,
            project: Project(),
            showGrid: showGrid,
          ),
        ),
      ),
    );
  }

  Widget _buildChartPreview(BoxConstraints constraints) {
    final chart = PatternChartData.fromPixels(
      pixels: pixels,
      width: width,
      height: height,
      paletteEntries: paletteEntries,
    );
    const chartCellSize = 22.0;
    final chartSize = PatternChartPainter.chartSize(
      chart: chart,
      cellSize: chartCellSize,
      showCoordinates: false,
    );

    return ColoredBox(
      color: Colors.white,
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(80),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
