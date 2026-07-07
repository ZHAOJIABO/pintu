import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/generated_pattern.dart';
import '../models/pattern_chart.dart';
import '../rendering/pattern_chart_painter.dart';

class PatternExportService {
  static const double pngCellSize = 20;
  static const double _preferredExportPixelRatio = 2;
  static const double _maxExportDimension = 6000;
  static const MethodChannel _photoLibraryChannel = MethodChannel(
    'bobobeads/photo_library',
  );

  const PatternExportService();

  @visibleForTesting
  ui.Size exportChartPngPixelSize(GeneratedPattern pattern) {
    final size = _buildPagePainter(pattern).pageSize;
    final pixelRatio = _exportPixelRatio(size);
    return ui.Size(
      (size.width * pixelRatio).ceilToDouble(),
      (size.height * pixelRatio).ceilToDouble(),
    );
  }

  Future<void> saveChartPngToPhotoLibrary(GeneratedPattern pattern) async {
    final bytes = await exportChartPngBytes(pattern);
    await _photoLibraryChannel.invokeMethod<void>('savePng', bytes);
  }

  Future<File> exportChartPng(GeneratedPattern pattern) async {
    final bytes = await exportChartPngBytes(pattern);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/bobobeads_pattern_chart_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List> exportChartPngBytes(GeneratedPattern pattern) async {
    final painter = _buildPagePainter(pattern);
    final size = painter.pageSize;
    final pixelRatio = _exportPixelRatio(size);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.scale(pixelRatio);
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).ceil(),
      (size.height * pixelRatio).ceil(),
    );
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('图纸导出失败');
    }

    return byteData.buffer.asUint8List();
  }

  PatternChartPagePainter _buildPagePainter(GeneratedPattern pattern) {
    final chart = PatternChartData.fromPattern(pattern);
    return PatternChartPagePainter(
      chart: chart,
      usage: pattern.usage,
      paletteEntries: pattern.paletteEntries,
      title: '拼豆图纸',
      cellSize: pngCellSize,
    );
  }

  double _exportPixelRatio(ui.Size size) {
    final largestDimension = math.max(size.width, size.height);
    if (largestDimension <= 0) return 1;

    return math
        .min(
          _preferredExportPixelRatio,
          math.max(1, _maxExportDimension / largestDimension),
        )
        .toDouble();
  }
}
