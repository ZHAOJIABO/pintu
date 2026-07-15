import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/generated_pattern.dart';
import '../models/pattern_chart.dart';
import '../rendering/pattern_chart_painter.dart';

/// Web-only friendly image exporter for the internal publishing portal.
///
/// The client-side export service also persists files to the device, which
/// imports `dart:io`.  Keeping this renderer in `lib/admin/` lets the Web
/// target reuse the same chart painter without affecting the iOS export flow.
class AdminPreviewExporter {
  static const double _cellSize = 20;
  static const double _preferredPixelRatio = 2;
  static const double _maxDimension = 6000;

  const AdminPreviewExporter();

  Future<Uint8List> exportChartPng(GeneratedPattern pattern) async {
    final painter = PatternChartPagePainter(
      chart: PatternChartData.fromPattern(pattern),
      usage: pattern.usage,
      paletteEntries: pattern.paletteEntries,
      title: '官方拼豆图纸',
      cellSize: _cellSize,
    );
    final size = painter.pageSize;
    final pixelRatio = _pixelRatio(size);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(pixelRatio);
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).ceil(),
      (size.height * pixelRatio).ceil(),
    );
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) throw StateError('预览图导出失败');
    return byteData.buffer.asUint8List();
  }

  double _pixelRatio(ui.Size size) {
    final largest = math.max(size.width, size.height);
    if (largest <= 0) return 1;
    return math
        .min(_preferredPixelRatio, math.max(1, _maxDimension / largest))
        .toDouble();
  }
}
