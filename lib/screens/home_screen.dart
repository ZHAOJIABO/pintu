import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/palette.dart';
import '../models/project.dart';
import '../services/palette_service.dart';
import '../services/image_service.dart';
import '../algorithms/color_reducer.dart';
import 'preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PaletteService _paletteService = PaletteService();
  final ImageService _imageService = ImageService();
  final Project _project = Project();

  List<Palette> _allPalettes = [];
  List<int> _selectedPaletteIndices = [];
  Uint8List? _imageBytes;
  String? _imageName;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPalettes();
  }

  Future<void> _loadPalettes() async {
    setState(() => _loading = true);
    final palettes = await _paletteService.loadAll();
    setState(() {
      _allPalettes = palettes;
      if (palettes.isNotEmpty) _selectedPaletteIndices = [0];
      _loading = false;
    });
  }

  Future<void> _pickImage() async {
    final file = await _imageService.pickImage();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name;
    });
  }

  Future<void> _beadify() async {
    if (_imageBytes == null || _selectedPaletteIndices.isEmpty) return;

    setState(() => _loading = true);
    await Future.delayed(Duration.zero);

    try {
      final selectedPalettes = _selectedPaletteIndices
          .map((i) => _allPalettes[i])
          .toList();

      final pixels = await _imageService.resizeAndGetPixels(
        _imageBytes!,
        _project.canvasWidth,
        _project.canvasHeight,
      );

      final drawingPosition = ImagePosition(
        0,
        0,
        _project.canvasWidth,
        _project.canvasHeight,
      );

      final ColorReducerResult result;
      if (kIsWeb) {
        result = _reduceColorIsolate(
          _ReduceColorParams(
            pixels: pixels,
            width: _project.canvasWidth,
            height: _project.canvasHeight,
            palettes: selectedPalettes,
            matchingAlgorithm: _project.matchingAlgorithm,
            ditheringEnabled: _project.ditheringEnabled,
            ditheringHardness: _project.ditheringHardness,
            drawingPosition: drawingPosition,
          ),
        );
      } else {
        result = await compute(
          _reduceColorIsolate,
          _ReduceColorParams(
            pixels: pixels,
            width: _project.canvasWidth,
            height: _project.canvasHeight,
            palettes: selectedPalettes,
            matchingAlgorithm: _project.matchingAlgorithm,
            ditheringEnabled: _project.ditheringEnabled,
            ditheringHardness: _project.ditheringHardness,
            drawingPosition: drawingPosition,
          ),
        );
      }

      setState(() => _loading = false);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            result: result,
            project: _project,
            palettes: selectedPalettes,
          ),
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Processing failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('bobobeads')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageSection(),
                  const SizedBox(height: 16),
                  _buildBoardConfig(),
                  const SizedBox(height: 16),
                  _buildAlgorithmConfig(),
                  const SizedBox(height: 16),
                  _buildDitheringConfig(),
                  const SizedBox(height: 16),
                  _buildPaletteSection(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed:
                        _imageBytes != null &&
                            _selectedPaletteIndices.isNotEmpty
                        ? _beadify
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Beadify!',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Image',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _imageBytes!,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _imageName ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final file = await _imageService.pickImage(
                      source: ImageSource.camera,
                    );
                    if (file == null) return;
                    final bytes = await file.readAsBytes();
                    setState(() {
                      _imageBytes = bytes;
                      _imageName = file.name;
                    });
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Board',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<BoardType>(
              initialValue: _project.boardType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: BoardType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => _project.boardType = v!),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _project.boardsX.toString(),
                    decoration: const InputDecoration(labelText: 'Boards X'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _project.boardsX = int.tryParse(v) ?? 1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _project.boardsY.toString(),
                    decoration: const InputDecoration(labelText: 'Boards Y'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _project.boardsY = int.tryParse(v) ?? 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Output: ${_project.canvasWidth} x ${_project.canvasHeight} beads',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlgorithmConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Color Matching',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<MatchingAlgorithm>(
              initialValue: _project.matchingAlgorithm,
              items: MatchingAlgorithm.values
                  .map(
                    (a) =>
                        DropdownMenuItem(value: a, child: Text(a.matcher.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _project.matchingAlgorithm = v!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDitheringConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dithering',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: _project.ditheringEnabled,
                  onChanged: (v) =>
                      setState(() => _project.ditheringEnabled = v),
                ),
              ],
            ),
            if (_project.ditheringEnabled) ...[
              Slider(
                value: _project.ditheringHardness.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '${_project.ditheringHardness}%',
                onChanged: (v) =>
                    setState(() => _project.ditheringHardness = v.round()),
              ),
              Text('Hardness: ${_project.ditheringHardness}%'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaletteSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Palettes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_allPalettes.isEmpty)
              const Text('Loading palettes...')
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(_allPalettes.length, (i) {
                  final selected = _selectedPaletteIndices.contains(i);
                  return FilterChip(
                    label: Text(_allPalettes[i].name),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedPaletteIndices.add(i);
                        } else {
                          _selectedPaletteIndices.remove(i);
                        }
                      });
                    },
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReduceColorParams {
  final Uint8List pixels;
  final int width;
  final int height;
  final List<Palette> palettes;
  final MatchingAlgorithm matchingAlgorithm;
  final bool ditheringEnabled;
  final int ditheringHardness;
  final ImagePosition drawingPosition;

  _ReduceColorParams({
    required this.pixels,
    required this.width,
    required this.height,
    required this.palettes,
    required this.matchingAlgorithm,
    required this.ditheringEnabled,
    required this.ditheringHardness,
    required this.drawingPosition,
  });
}

ColorReducerResult _reduceColorIsolate(_ReduceColorParams params) {
  return reduceColor(
    pixels: params.pixels,
    width: params.width,
    height: params.height,
    palettes: params.palettes,
    matching: params.matchingAlgorithm.matcher,
    ditheringEnabled: params.ditheringEnabled,
    ditheringHardness: params.ditheringHardness,
    drawingPosition: params.drawingPosition,
  );
}
