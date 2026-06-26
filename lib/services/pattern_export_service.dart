import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../models/generated_pattern.dart';
import '../models/pattern_chart.dart';
import '../rendering/pattern_chart_painter.dart';

class PatternExportService {
  static const double pngCellSize = 20;

  const PatternExportService();

  Future<File> exportChartPng(GeneratedPattern pattern) async {
    final chart = PatternChartData.fromPattern(pattern);
    final painter = PatternChartPagePainter(
      chart: chart,
      usage: pattern.usage,
      paletteEntries: pattern.paletteEntries,
      title: '拼豆图纸',
      cellSize: pngCellSize,
    );
    final size = painter.pageSize;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.ceil(), size.height.ceil());
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('图纸导出失败');
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/bobobeads_pattern_chart_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return file;
  }
}
