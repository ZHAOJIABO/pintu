import 'package:flutter/material.dart';

import '../models/draft_project.dart';
import '../services/image_service.dart';
import '../services/palette_service.dart';
import '../services/pattern_generation_service.dart';
import '../services/project_storage_service.dart';
import 'result_screen.dart';

class GenerationScreen extends StatefulWidget {
  final DraftProject draft;

  const GenerationScreen({super.key, required this.draft});

  @override
  State<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends State<GenerationScreen> {
  final PaletteService _paletteService = PaletteService();
  final ProjectStorageService _projectStorageService = ProjectStorageService();
  late final PatternGenerationService _generationService =
      PatternGenerationService(imageService: ImageService());

  bool _failed = false;
  Object? _error;
  int _generationToken = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _failed = false;
      _error = null;
      _generationToken++;
    });
    final token = _generationToken;
    try {
      final palette = await _paletteService.loadByName(
        widget.draft.paletteBrandId!,
      );
      final pattern = await _generationService.generate(
        draft: widget.draft,
        palette: palette,
      );
      await _projectStorageService.saveGeneratedPattern(pattern);
      if (!mounted || token != _generationToken) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(pattern: pattern, showGeneratedHint: true),
        ),
      );
    } catch (error) {
      if (!mounted || token != _generationToken) return;
      setState(() {
        _failed = true;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(title: const Text('图纸生成中')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text('生成失败：$_error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _generate, child: const Text('重试')),
                  ],
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在生成拼豆图纸...'),
                  ],
                ),
        ),
      ),
    );
  }
}
