import 'package:flutter/material.dart';

import '../models/color_limit.dart';
import '../models/draft_project.dart';
import '../services/palette_service.dart';
import '../widgets/pin_primary_button.dart';
import 'generation_screen.dart';

class ColorSelectionScreen extends StatefulWidget {
  final DraftProject draft;

  const ColorSelectionScreen({super.key, required this.draft});

  @override
  State<ColorSelectionScreen> createState() => _ColorSelectionScreenState();
}

class _ColorSelectionScreenState extends State<ColorSelectionScreen> {
  final PaletteService _paletteService = PaletteService();
  String? _brandId;
  ColorLimit _limit = ColorLimit.sixteen;
  bool _smoothing = true;

  @override
  void initState() {
    super.initState();
    _brandId = _paletteService.availablePalettes.first.id;
  }

  void _generate() {
    final nextDraft = widget.draft.copyWith(
      paletteBrandId: _brandId,
      colorLimit: _limit,
      smoothingEnabled: _smoothing,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GenerationScreen(draft: nextDraft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image =
        widget.draft.croppedImageBytes ?? widget.draft.originalImageBytes;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(title: const Text('Step.2 选择颜色')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(image, height: 200, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 24),
            const Text('限制颜色个数'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final limit in ColorLimit.values)
                  ChoiceChip(
                    label: Text(limit.label),
                    selected: _limit == limit,
                    onSelected: (_) => setState(() => _limit = limit),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('选择颜色品牌'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final definition in _paletteService.availablePalettes)
                  ChoiceChip(
                    label: Text(definition.displayName),
                    selected: _brandId == definition.id,
                    onSelected: (_) => setState(() => _brandId = definition.id),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('颜色平滑'),
              value: _smoothing,
              onChanged: (value) => setState(() => _smoothing = value),
            ),
            const SizedBox(height: 24),
            PinPrimaryButton(
              label: '生成图纸',
              onPressed: _brandId == null ? null : _generate,
            ),
          ],
        ),
      ),
    );
  }
}
