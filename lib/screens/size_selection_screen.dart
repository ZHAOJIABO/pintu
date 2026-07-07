import 'package:flutter/material.dart';

import '../models/draft_project.dart';
import '../models/product_template.dart';
import '../widgets/pin_primary_button.dart';
import '../widgets/product_template_card.dart';
import 'color_selection_screen.dart';

class SizeSelectionScreen extends StatefulWidget {
  final DraftProject draft;

  const SizeSelectionScreen({super.key, required this.draft});

  @override
  State<SizeSelectionScreen> createState() => _SizeSelectionScreenState();
}

class _SizeSelectionScreenState extends State<SizeSelectionScreen> {
  late ProductTemplate _selected = ProductTemplateCatalog.defaultTemplate;
  int _customWidth = 64;
  int _customHeight = 64;

  bool get _customValid =>
      ProductTemplateCatalog.isValidCustomDimension(_customWidth) &&
      ProductTemplateCatalog.isValidCustomDimension(_customHeight);

  bool get _canContinue => !_selected.custom || _customValid;

  void _continue() {
    final nextDraft = widget.draft.copyWith(
      selectedTemplate: _selected,
      customBeadWidth: _selected.custom ? _customWidth : null,
      customBeadHeight: _selected.custom ? _customHeight : null,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ColorSelectionScreen(draft: nextDraft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image =
        widget.draft.croppedImageBytes ?? widget.draft.originalImageBytes;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(title: const Text('Step.1 选择大小')),
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
            GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 0.9,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                for (final template in ProductTemplateCatalog.templates)
                  ProductTemplateCard(
                    template: template,
                    selected: template.id == _selected.id,
                    onTap: () => setState(() => _selected = template),
                  ),
              ],
            ),
            if (_selected.custom) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_customWidth',
                      decoration: const InputDecoration(labelText: '宽度'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(
                        () => _customWidth = int.tryParse(value) ?? 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_customHeight',
                      decoration: const InputDecoration(labelText: '高度'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(
                        () => _customHeight = int.tryParse(value) ?? 0,
                      ),
                    ),
                  ),
                ],
              ),
              if (!_customValid)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('自定义尺寸需在 8 到 150 颗之间'),
                ),
            ],
            const SizedBox(height: 24),
            Text(
              '预计大约需要 ${_selected.custom ? _customWidth * _customHeight : _selected.estimatedBeads} 颗豆',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PinPrimaryButton(
              label: '选择颜色',
              onPressed: _canContinue ? _continue : null,
            ),
          ],
        ),
      ),
    );
  }
}
