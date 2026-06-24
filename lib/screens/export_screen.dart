import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../algorithms/color_reducer.dart';
import '../models/palette.dart';
import '../models/project.dart';
import '../rendering/bead_painter.dart';

class ExportScreen extends StatelessWidget {
  final ColorReducerResult result;
  final Project project;
  final List<Palette> palettes;

  const ExportScreen({
    super.key,
    required this.result,
    required this.project,
    required this.palettes,
  });

  Future<void> _exportPng(BuildContext context) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final beadSize = 12.0;
    final size = Size(result.width * beadSize, result.height * beadSize);

    final painter = BeadPainter(
      pixels: result.pixels,
      imageWidth: result.width,
      imageHeight: result.height,
      beadSize: beadSize,
      project: project,
      showGrid: true,
    );
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bobobeads_pattern.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    final sortedUsage = result.usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalBeads = result.usage.values.fold(0, (sum, v) => sum + v);

    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Size: ${result.width} x ${result.height} beads'),
                    Text('Total beads: $totalBeads'),
                    Text('Colors used: ${sortedUsage.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _exportPng(context),
              icon: const Icon(Icons.image),
              label: const Text('Export as PNG'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bead Inventory',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: sortedUsage.length,
                itemBuilder: (_, i) {
                  final entry = sortedUsage[i];
                  final paletteEntry = _findEntry(entry.key);
                  return ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: paletteEntry != null
                            ? Color.fromARGB(
                                255,
                                paletteEntry.color.rInt,
                                paletteEntry.color.gInt,
                                paletteEntry.color.bInt,
                              )
                            : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                    ),
                    title: Text(paletteEntry?.name ?? entry.key),
                    subtitle: Text(entry.key),
                    trailing: Text(
                      '${entry.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PaletteEntry? _findEntry(String ref) {
    for (final palette in palettes) {
      for (final entry in palette.entries) {
        if (entry.ref == ref) return entry;
      }
    }
    return null;
  }
}
