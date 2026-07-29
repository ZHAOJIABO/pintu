import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Paints a server-provided, transparent watermark PNG over an export canvas.
class ExportWatermarkRenderer {
  const ExportWatermarkRenderer._();

  /// Covers the exported image without distorting the watermark artwork.
  static Future<void> drawCover(
    ui.Canvas canvas,
    ui.Size canvasSize,
    Uint8List watermarkPngBytes,
  ) async {
    final codec = await ui.instantiateImageCodec(watermarkPngBytes);
    try {
      final watermark = (await codec.getNextFrame()).image;
      try {
        final sourceSize = ui.Size(
          watermark.width.toDouble(),
          watermark.height.toDouble(),
        );
        final scale = math.max(
          canvasSize.width / sourceSize.width,
          canvasSize.height / sourceSize.height,
        );
        final destinationSize = ui.Size(
          sourceSize.width * scale,
          sourceSize.height * scale,
        );
        final destination = ui.Rect.fromCenter(
          center: ui.Offset(canvasSize.width / 2, canvasSize.height / 2),
          width: destinationSize.width,
          height: destinationSize.height,
        );
        canvas.drawImageRect(
          watermark,
          ui.Offset.zero & sourceSize,
          destination,
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
      } finally {
        watermark.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
