import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/services/pattern_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renders the supplied watermark above the exported chart', () async {
    final watermark = await _solidPng(const ui.Color(0xFFFF0000));

    final bytes = await const PatternExportService().exportChartPngBytes(
      _pattern(),
      watermarkPngBytes: watermark,
    );
    final decoded = await ui.instantiateImageCodec(bytes);
    final image = (await decoded.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    expect(data, isNotNull);
    expect(data!.getUint8(0), 255);
    expect(data.getUint8(1), 0);
    expect(data.getUint8(2), 0);

    image.dispose();
    decoded.dispose();
  });
}

Future<Uint8List> _solidPng(ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
  ).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint()..color = color);
  final image = await recorder.endRecording().toImage(2, 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

GeneratedPattern _pattern() {
  final color = PaletteEntry(
    name: 'Red',
    ref: 'R1',
    symbol: 'R',
    color: BeadColor.fromInt(255, 40, 80, 255),
    prefix: 'T',
  );
  return GeneratedPattern(
    width: 2,
    height: 2,
    pixels: Uint8List.fromList([
      255,
      40,
      80,
      255,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      255,
      255,
      40,
      80,
      255,
    ]),
    paletteEntries: [color],
    usage: {'R1': 2},
    draft: DraftProject(originalImageBytes: Uint8List(0)),
  );
}
