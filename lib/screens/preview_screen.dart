import 'package:flutter/material.dart';
import '../algorithms/color_reducer.dart';
import '../models/palette.dart';
import '../models/project.dart';
import '../rendering/bead_painter.dart';
import 'export_screen.dart';

class PreviewScreen extends StatefulWidget {
  final ColorReducerResult result;
  final Project project;
  final List<Palette> palettes;

  const PreviewScreen({
    super.key,
    required this.result,
    required this.project,
    required this.palettes,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _showGrid = true;

  int get _totalBeads =>
      widget.result.usage.values.fold(0, (sum, v) => sum + v);

  double _fitBeadSize(double viewWidth, double viewHeight) {
    final scaleX = viewWidth / widget.result.width;
    final scaleY = viewHeight / widget.result.height;
    return scaleX < scaleY ? scaleX : scaleY;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [
          IconButton(
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExportScreen(
                  result: widget.result,
                  project: widget.project,
                  palettes: widget.palettes,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fitBeadSize = _fitBeadSize(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final canvasWidth = widget.result.width * fitBeadSize;
                final canvasHeight = widget.result.height * fitBeadSize;

                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 10.0,
                  child: Center(
                    child: CustomPaint(
                      size: Size(canvasWidth, canvasHeight),
                      painter: BeadPainter(
                        pixels: widget.result.pixels,
                        imageWidth: widget.result.width,
                        imageHeight: widget.result.height,
                        beadSize: fitBeadSize,
                        project: widget.project,
                        showGrid: _showGrid,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildUsageBar(),
        ],
      ),
    );
  }

  Widget _buildUsageBar() {
    final sortedUsage = widget.result.usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total: $_totalBeads beads, ${sortedUsage.length} colors',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedUsage.length,
              itemBuilder: (_, i) {
                final entry = sortedUsage[i];
                final paletteEntry = _findEntry(entry.key);
                return Container(
                  width: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
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
                        ),
                      ),
                      Text(
                        entry.key,
                        style: const TextStyle(fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PaletteEntry? _findEntry(String ref) {
    for (final palette in widget.palettes) {
      for (final entry in palette.entries) {
        if (entry.ref == ref) return entry;
      }
    }
    return null;
  }
}
