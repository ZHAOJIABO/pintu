import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/generated_pattern.dart';
import '../widgets/bead_board_preview.dart';

const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _pageBackground = Color(0xFFEEF0F6);

class BeadModeScreen extends StatefulWidget {
  final GeneratedPattern pattern;

  const BeadModeScreen({super.key, required this.pattern});

  @override
  State<BeadModeScreen> createState() => _BeadModeScreenState();
}

class _BeadModeScreenState extends State<BeadModeScreen> {
  String? _selectedBeadRef;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: SafeArea(
          child: Column(
            children: [
              const _BeadModeNavigationBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: BeadBoardPreview(
                    pixels: widget.pattern.pixels,
                    width: widget.pattern.width,
                    height: widget.pattern.height,
                    paletteEntries: widget.pattern.paletteEntries,
                    selectedRef: _selectedBeadRef,
                  ),
                ),
              ),
              BeadModeUsageStrip(
                usage: widget.pattern.usage,
                entries: widget.pattern.paletteEntries,
                selectedRef: _selectedBeadRef,
                onSelected: (ref) => setState(() => _selectedBeadRef = ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeadModeNavigationBar extends StatelessWidget {
  const _BeadModeNavigationBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 24,
                height: 40,
                child: Icon(Icons.chevron_left, color: Colors.black, size: 30),
              ),
            ),
            const Expanded(
              child: Text(
                '拼豆模式',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontFamily: _roundFontFamily,
                  fontFamilyFallback: _fontFallbacks,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 24, height: 40),
          ],
        ),
      ),
    );
  }
}
