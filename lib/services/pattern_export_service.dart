import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/generated_pattern.dart';
import '../models/pattern_chart.dart';
import '../rendering/pattern_chart_painter.dart';
import 'export_watermark_renderer.dart';

class PatternExportService {
  static const double pngCellSize = 20;
  static const double thumbnailMaxPixelSize = 300;
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

  Future<void> saveChartPngToPhotoLibrary(
    GeneratedPattern pattern, {
    Uint8List? watermarkPngBytes,
  }) async {
    final bytes = await exportChartPngBytes(
      pattern,
      watermarkPngBytes: watermarkPngBytes,
    );
    await saveImageBytesToPhotoLibrary(bytes);
  }

  /// Saves an already-rendered image, such as an AI style-transfer result.
  Future<void> saveImageBytesToPhotoLibrary(Uint8List bytes) async {
    if (bytes.isEmpty) throw ArgumentError.value(bytes, 'bytes');
    await _photoLibraryChannel.invokeMethod<void>('savePng', bytes);
  }

  Future<File> exportChartPng(
    GeneratedPattern pattern, {
    Uint8List? watermarkPngBytes,
  }) async {
    final bytes = await exportChartPngBytes(
      pattern,
      watermarkPngBytes: watermarkPngBytes,
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/bobobeads_pattern_chart_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List> exportChartPngBytes(
    GeneratedPattern pattern, {
    Uint8List? watermarkPngBytes,
  }) async {
    final painter = _buildPagePainter(pattern);
    final size = painter.pageSize;
    return _renderPng(
      painter,
      size,
      pixelRatio: _exportPixelRatio(size),
      watermarkPngBytes: watermarkPngBytes,
    );
  }

  /// Renders only the pattern's color blocks for gallery lists.
  ///
  /// The thumbnail intentionally omits chart coordinates, the red border,
  /// grid lines, titles, and color legend from the printable preview.
  Future<Uint8List> exportChartThumbnailPngBytes(
    GeneratedPattern pattern,
  ) async {
    if (pattern.width <= 0 || pattern.height <= 0) {
      throw ArgumentError.value(
        '${pattern.width}x${pattern.height}',
        'pattern',
        '图纸尺寸必须为正数',
      );
    }
    final expectedLength = pattern.width * pattern.height * 4;
    if (pattern.pixels.length != expectedLength) {
      throw ArgumentError.value(
        pattern.pixels.length,
        'pattern.pixels',
        '像素数据长度与图纸尺寸不一致',
      );
    }

    final longestSide = math.max(pattern.width, pattern.height);
    final scale = thumbnailMaxPixelSize / longestSide;
    final imageWidth = math.max(1, (pattern.width * scale).round());
    final imageHeight = math.max(1, (pattern.height * scale).round());
    final image = img.Image(
      width: imageWidth,
      height: imageHeight,
      numChannels: 4,
    )..clear(img.ColorUint8.rgba(255, 255, 255, 255));

    for (var y = 0; y < pattern.height; y++) {
      for (var x = 0; x < pattern.width; x++) {
        final offset = (y * pattern.width + x) * 4;
        final alpha = pattern.pixels[offset + 3];
        if (alpha == 0) continue;

        final left = x * imageWidth ~/ pattern.width;
        final right = (x + 1) * imageWidth ~/ pattern.width;
        final top = y * imageHeight ~/ pattern.height;
        final bottom = (y + 1) * imageHeight ~/ pattern.height;
        for (var targetY = top; targetY < bottom; targetY++) {
          for (var targetX = left; targetX < right; targetX++) {
            image.setPixelRgba(
              targetX,
              targetY,
              pattern.pixels[offset],
              pattern.pixels[offset + 1],
              pattern.pixels[offset + 2],
              alpha,
            );
          }
        }
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  Future<Uint8List> _renderPng(
    CustomPainter painter,
    ui.Size size, {
    double pixelRatio = 1,
    Uint8List? watermarkPngBytes,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.scale(pixelRatio);
    painter.paint(canvas, size);
    if (watermarkPngBytes != null) {
      await ExportWatermarkRenderer.drawCover(canvas, size, watermarkPngBytes);
    }

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
