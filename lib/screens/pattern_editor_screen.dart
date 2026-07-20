import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../algorithms/matching.dart';
import '../models/color.dart';
import '../models/editable_pattern.dart';
import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../services/editor_history_service.dart';
import '../services/pattern_edit_service.dart';
import '../widgets/bead_board_preview.dart';

const _editorBackground = Color(0xFFEEF0F6);
const _editorToolSurface = Color(0xFFDEE2ED);
const _brushGuideCompletedPreferenceKey = 'brush_mode_guide_completed';

enum _EditorPanel { brush, palette }

enum _BrushGuideTarget { currentColor, brush, picker, eraser }

class _BrushGuideStep {
  final _BrushGuideTarget target;
  final String text;
  final String? iconAsset;
  final double underlineLeft;
  final double underlineWidth;

  const _BrushGuideStep({
    required this.target,
    required this.text,
    required this.underlineLeft,
    required this.underlineWidth,
    this.iconAsset,
  });
}

const _brushGuideSteps = <_BrushGuideStep>[
  _BrushGuideStep(
    target: _BrushGuideTarget.currentColor,
    text: '色值是当前的画笔颜色',
    underlineLeft: 90,
    underlineWidth: 107,
  ),
  _BrushGuideStep(
    target: _BrushGuideTarget.brush,
    text: '画笔改变图纸中方块的颜色',
    iconAsset: 'assets/pin_icon/editor_brush_unselected.svg',
    underlineLeft: 72,
    underlineWidth: 32,
  ),
  _BrushGuideStep(
    target: _BrushGuideTarget.picker,
    text: '取色器吸取图纸中方块的颜色',
    iconAsset: 'assets/pin_icon/editor_picker_unselected.svg',
    underlineLeft: 105,
    underlineWidth: 32,
  ),
  _BrushGuideStep(
    target: _BrushGuideTarget.eraser,
    text: '橡皮擦去掉图纸中方块的颜色',
    iconAsset: 'assets/pin_icon/editor_eraser.svg',
    underlineLeft: 106,
    underlineWidth: 32,
  ),
];

class PatternEditorScreen extends StatefulWidget {
  final GeneratedPattern pattern;
  final bool showBrushGuide;

  const PatternEditorScreen({
    super.key,
    required this.pattern,
    this.showBrushGuide = true,
  });

  @override
  State<PatternEditorScreen> createState() => _PatternEditorScreenState();
}

class _PatternEditorScreenState extends State<PatternEditorScreen> {
  final PatternEditService _editService = PatternEditService();
  final EditorHistoryService _historyService = EditorHistoryService();
  late final Uint8List _pixels = Uint8List.fromList(widget.pattern.pixels);
  late BeadColor _selectedColor = _initialColor();
  EditorTool? _tool = EditorTool.brush;
  _EditorPanel _panel = _EditorPanel.brush;
  List<CellChange> _activeStroke = <CellChange>[];
  math.Point<int>? _lastEditedCell;
  int _revision = 0;
  Timer? _brushGuideStartTimer;
  Timer? _brushGuideTimer;
  Timer? _brushGuideCompletionTimer;
  late bool _showBrushGuide;
  bool _showBrushGuideCompletion = false;
  int _brushGuideStep = -1;

  @override
  void initState() {
    super.initState();
    _showBrushGuide = false;
    if (widget.showBrushGuide) unawaited(_showBrushGuideIfNeeded());
  }

  Future<void> _showBrushGuideIfNeeded() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted ||
          preferences.getBool(_brushGuideCompletedPreferenceKey) == true) {
        return;
      }
    } catch (_) {
      if (!mounted) return;
    }

    _startBrushGuide();
  }

  void _startBrushGuide() {
    if (!mounted) return;
    setState(() {
      _showBrushGuide = true;
      _showBrushGuideCompletion = false;
      _brushGuideStep = -1;
    });
    _brushGuideStartTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || !_showBrushGuide) return;

      setState(() => _brushGuideStep = 0);
      _brushGuideTimer = Timer.periodic(const Duration(milliseconds: 850), (
        timer,
      ) {
        if (!mounted || _brushGuideStep == _brushGuideSteps.length - 1) {
          timer.cancel();
          return;
        }
        final nextStep = _brushGuideStep + 1;
        setState(() => _brushGuideStep = nextStep);
        if (nextStep == _brushGuideSteps.length - 1) {
          timer.cancel();
          _brushGuideCompletionTimer = Timer(
            const Duration(milliseconds: 320),
            () {
              if (mounted && _showBrushGuide) {
                setState(() => _showBrushGuideCompletion = true);
              }
            },
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _brushGuideStartTimer?.cancel();
    _brushGuideTimer?.cancel();
    _brushGuideCompletionTimer?.cancel();
    super.dispose();
  }

  BeadColor _initialColor() {
    final colors = _usedPaletteEntries();
    if (colors.isNotEmpty) return colors.first.entry.color.clone();

    final fallback = widget.pattern.paletteEntries.firstOrNull;
    return fallback?.color.clone() ?? BeadColor.fromInt(233, 0, 48, 255);
  }

  /// Only shows colours that are actually present in the current drawing.
  /// Entries are kept separate from the pixel data so their material code
  /// remains available for display and sorting.
  List<_UsedPaletteEntry> _usedPaletteEntries() {
    final countByColor = <int, int>{};
    for (var offset = 0; offset < _pixels.length; offset += 4) {
      if (_pixels[offset + 3] == 0) continue;
      final key = _rgbaKey(
        _pixels[offset],
        _pixels[offset + 1],
        _pixels[offset + 2],
        _pixels[offset + 3],
      );
      countByColor.update(key, (count) => count + 1, ifAbsent: () => 1);
    }

    final usedEntries = <_UsedPaletteEntry>[];
    for (final entry in widget.pattern.paletteEntries) {
      final count =
          countByColor[_rgbaKey(
            entry.color.rInt,
            entry.color.gInt,
            entry.color.bInt,
            entry.color.aInt,
          )];
      if (count != null && count > 0) {
        usedEntries.add(_UsedPaletteEntry(entry: entry, count: count));
      }
    }

    if (usedEntries.isEmpty) {
      usedEntries.addAll(
        widget.pattern.paletteEntries.map(
          (entry) => _UsedPaletteEntry(entry: entry, count: 0),
        ),
      );
    }

    usedEntries.sort((left, right) {
      final byCount = right.count.compareTo(left.count);
      return byCount != 0
          ? byCount
          : _compareColorCodes(left.entry.ref, right.entry.ref);
    });
    return usedEntries;
  }

  static int _rgbaKey(int red, int green, int blue, int alpha) =>
      (red << 24) | (green << 16) | (blue << 8) | alpha;

  void _startStroke(int x, int y) {
    _activeStroke = <CellChange>[];
    _lastEditedCell = null;
    _editCell(x, y);
  }

  void _continueStroke(int x, int y) => _editCell(x, y);

  void _editCell(int x, int y) {
    final cell = math.Point<int>(x, y);
    if (_lastEditedCell == cell) return;
    _lastEditedCell = cell;

    if (_tool == EditorTool.picker) {
      setState(() {
        _selectedColor = _editService.pick(
          pixels: _pixels,
          width: widget.pattern.width,
          x: x,
          y: y,
        );
      });
      return;
    }

    final changes = _tool == EditorTool.eraser
        ? _editService.erase(
            pixels: _pixels,
            width: widget.pattern.width,
            height: widget.pattern.height,
            x: x,
            y: y,
            brushSize: 1,
          )
        : _editService.paint(
            pixels: _pixels,
            width: widget.pattern.width,
            height: widget.pattern.height,
            x: x,
            y: y,
            brushSize: 1,
            color: _selectedColor,
          );
    if (changes.isEmpty) return;

    setState(() {
      _activeStroke.addAll(changes);
      _revision++;
    });
  }

  void _finishStroke() {
    _historyService.record(_activeStroke);
    _activeStroke = <CellChange>[];
    _lastEditedCell = null;
  }

  void _undo() {
    if (!_historyService.canUndo) return;
    setState(() {
      _historyService.undo(_pixels, widget.pattern.width);
      _revision++;
    });
  }

  void _redo() {
    if (!_historyService.canRedo) return;
    setState(() {
      _historyService.redo(_pixels, widget.pattern.width);
      _revision++;
    });
  }

  void _selectPaletteColor(BeadColor color) {
    setState(() {
      _selectedColor = color.clone();
      _tool = EditorTool.brush;
      _panel = _EditorPanel.brush;
    });
  }

  void _replacePaletteCell(int x, int y) {
    final source = _editService.pick(
      pixels: _pixels,
      width: widget.pattern.width,
      x: x,
      y: y,
    );
    if (source.aInt == 0) return;
    _showColorReplacement(
      source: source,
      sourceRef: _colorRefFor(source),
      cell: math.Point<int>(x, y),
    );
  }

  Future<void> _showColorReplacement({
    required BeadColor source,
    required String sourceRef,
    math.Point<int>? cell,
  }) async {
    final replacementEntries =
        widget.pattern.paletteEntries
            .where((entry) => entry.color != source)
            .toList()
          ..sort((left, right) => _compareColorCodes(left.ref, right.ref));
    final colorMatcher = CIE2000Matching();
    final closestEntries = List<PaletteEntry>.from(replacementEntries)
      ..sort((left, right) {
        final byDistance = colorMatcher
            .delta(left.color, source)
            .compareTo(colorMatcher.delta(right.color, source));
        return byDistance != 0
            ? byDistance
            : _compareColorCodes(left.ref, right.ref);
      });
    final replacement = await showModalBottomSheet<BeadColor>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ColorReplacementSheet(
        source: source,
        sourceRef: sourceRef,
        nearbyEntries: closestEntries.take(8).toList(growable: false),
        allEntries: replacementEntries,
      ),
    );
    if (!mounted || replacement == null) return;

    if (cell == null) {
      final colorReplacement = _editService.replaceColorCompact(
        pixels: _pixels,
        from: source,
        to: replacement,
      );
      if (colorReplacement == null) return;
      setState(() {
        _historyService.recordColorReplacement(colorReplacement);
        _revision++;
      });
      return;
    }

    final changes = _editService.paint(
      pixels: _pixels,
      width: widget.pattern.width,
      height: widget.pattern.height,
      x: cell.x,
      y: cell.y,
      brushSize: 1,
      color: replacement,
    );
    if (changes.isEmpty) return;

    setState(() {
      _historyService.record(changes);
      _revision++;
    });
  }

  String _colorRefFor(BeadColor color) {
    for (final entry in widget.pattern.paletteEntries) {
      if (entry.color == color) return entry.ref;
    }
    return color.toHex().replaceFirst('#', '').toUpperCase();
  }

  void _selectTool(EditorTool tool) {
    setState(() => _tool = _tool == tool ? null : tool);
  }

  Future<void> _showCurrentColorPicker() async {
    final color = await showModalBottomSheet<BeadColor>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CurrentColorPickerSheet(
        entries: _usedPaletteEntries()
          ..sort(
            (left, right) =>
                _compareColorCodes(left.entry.ref, right.entry.ref),
          ),
        selectedColor: _selectedColor,
      ),
    );
    if (!mounted || color == null) return;
    _selectPaletteColor(color);
  }

  void _confirm() {
    final edited = _editService.applyEditedPixels(
      pattern: widget.pattern,
      pixels: _pixels,
    );
    Navigator.pop(context, edited);
  }

  String get _selectedColorRef => _colorRefFor(_selectedColor);

  void _dismissBrushGuide() {
    _brushGuideStartTimer?.cancel();
    _brushGuideTimer?.cancel();
    _brushGuideCompletionTimer?.cancel();
    setState(() => _showBrushGuide = false);
    unawaited(_markBrushGuideCompleted());
  }

  Future<void> _markBrushGuideCompleted() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_brushGuideCompletedPreferenceKey, true);
    } catch (_) {
      // The guide remains usable when local persistence is temporarily unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPalettePanel = _panel == _EditorPanel.palette;
    final canPaint = !isPalettePanel && _tool != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        key: const ValueKey('pattern-editor-screen'),
        backgroundColor: _editorBackground,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _EditorNavigationBar(
                    panel: _panel,
                    onBack: () => Navigator.maybePop(context),
                    onPanelChanged: (panel) => setState(() => _panel = panel),
                    onSave: _confirm,
                  ),
                  Expanded(
                    child: BeadBoardPreview(
                      pixels: _pixels,
                      layoutPixels: widget.pattern.pixels,
                      width: widget.pattern.width,
                      height: widget.pattern.height,
                      revision: _revision,
                      paletteEntries: widget.pattern.paletteEntries,
                      showRulers: false,
                      onCellStart: isPalettePanel
                          ? _replacePaletteCell
                          : canPaint
                          ? _startStroke
                          : null,
                      onCellChanged: canPaint ? _continueStroke : null,
                      onCellEnd: canPaint ? _finishStroke : null,
                    ),
                  ),
                  _panel == _EditorPanel.brush
                      ? _EditorToolbar(
                          selectedColor: _selectedColor,
                          selectedColorRef: _selectedColorRef,
                          activeTool: _tool,
                          canUndo: _historyService.canUndo,
                          canRedo: _historyService.canRedo,
                          onToolSelected: _selectTool,
                          onCurrentColorPressed: _showCurrentColorPicker,
                          onUndo: _undo,
                          onRedo: _redo,
                        )
                      : _PaletteToolbar(
                          entries: _usedPaletteEntries(),
                          canUndo: _historyService.canUndo,
                          canRedo: _historyService.canRedo,
                          onColorSelected: (item) => _showColorReplacement(
                            source: item.entry.color,
                            sourceRef: item.entry.ref,
                          ),
                          onUndo: _undo,
                          onRedo: _redo,
                        ),
                ],
              ),
            ),
            if (_showBrushGuide)
              Positioned.fill(
                child: _BrushModeGuide(
                  currentStep: _brushGuideStep,
                  showCompletion: _showBrushGuideCompletion,
                  panel: _panel,
                  selectedColor: _selectedColor,
                  selectedColorRef: _selectedColorRef,
                  onSkip: _dismissBrushGuide,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorNavigationBar extends StatelessWidget {
  final _EditorPanel panel;
  final VoidCallback onBack;
  final ValueChanged<_EditorPanel> onPanelChanged;
  final VoidCallback onSave;

  const _EditorNavigationBar({
    required this.panel,
    required this.onBack,
    required this.onPanelChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: '返回',
                child: IconButton(
                  onPressed: onBack,
                  icon: SvgPicture.asset(
                    'assets/pin_icon/editor_back.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
            _EditorSegmentedControl(value: panel, onChanged: onPanelChanged),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: '保存',
                child: TextButton(
                  onPressed: onSave,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                      fontFamily: 'Alimama FangYuanTi VF',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSegmentedControl extends StatelessWidget {
  final _EditorPanel value;
  final ValueChanged<_EditorPanel> onChanged;

  const _EditorSegmentedControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentButton(
            label: '画笔',
            selected: value == _EditorPanel.brush,
            onPressed: () => onChanged(_EditorPanel.brush),
          ),
          _SegmentButton(
            label: '色板',
            selected: value == _EditorPanel.palette,
            onPressed: () => onChanged(_EditorPanel.palette),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.black : Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(57)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: const BorderRadius.all(Radius.circular(57)),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.black.withValues(alpha: 0.6),
              fontFamily: 'Alimama FangYuanTi VF',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrushModeGuide extends StatelessWidget {
  final int currentStep;
  final bool showCompletion;
  final _EditorPanel panel;
  final BeadColor selectedColor;
  final String selectedColorRef;
  final VoidCallback onSkip;

  const _BrushModeGuide({
    required this.currentStep,
    required this.showCompletion,
    required this.panel,
    required this.selectedColor,
    required this.selectedColorRef,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final guideTarget = currentStep < 0
        ? null
        : _brushGuideSteps[currentStep].target;
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: const ColoredBox(
                  key: ValueKey('brush-mode-guide-scrim'),
                  color: Color(0x80000000),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 6,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: KeyedSubtree(
                key: const ValueKey('brush-mode-guide-panel-tabs'),
                child: Center(
                  child: _EditorSegmentedControl(
                    value: panel,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.1),
            child: Transform.translate(
              offset: const Offset(0, -36),
              child: _BrushModeGuideCard(
                currentStep: currentStep,
                selectedColor: selectedColor,
                selectedColorRef: selectedColorRef,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.1),
            child: Transform.translate(
              offset: const Offset(0, 187),
              child: IgnorePointer(
                ignoring: !showCompletion,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: showCompletion ? Offset.zero : const Offset(0, 0.12),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: showCompletion ? 1 : 0,
                    child: _BrushModeGuideCompletionButton(onPressed: onSkip),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _EditorToolbar(
                selectedColor: selectedColor,
                selectedColorRef: selectedColorRef,
                activeTool: null,
                canUndo: false,
                canRedo: false,
                onToolSelected: (_) {},
                onCurrentColorPressed: () {},
                onUndo: () {},
                onRedo: () {},
                guideTarget: guideTarget,
                isBrushGuide: true,
              ),
            ),
          ),
          Positioned(
            top: topInset + 12,
            right: 12,
            child: Semantics(
              button: true,
              label: '跳过画笔模式引导',
              child: TextButton(
                key: const ValueKey('brush-mode-guide-skip'),
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontFamily: 'Alimama FangYuanTi VF',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('跳过'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrushModeGuideCompletionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BrushModeGuideCompletionButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 52,
      child: Material(
        color: Colors.black,
        borderRadius: const BorderRadius.all(Radius.circular(44)),
        child: InkWell(
          key: const ValueKey('brush-mode-guide-completion'),
          onTap: onPressed,
          borderRadius: const BorderRadius.all(Radius.circular(44)),
          child: const Center(
            child: Text(
              '我知道啦！',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'Alimama FangYuanTi VF',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrushModeGuideCard extends StatelessWidget {
  final int currentStep;
  final BeadColor selectedColor;
  final String selectedColorRef;

  const _BrushModeGuideCard({
    required this.currentStep,
    required this.selectedColor,
    required this.selectedColorRef,
  });

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 48;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.min(330, availableWidth)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            key: const ValueKey('brush-mode-guide-card'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '可以修改“单个色块”的颜色',
                  style: TextStyle(
                    color: Color(0x99000000),
                    fontFamily: 'Alimama FangYuanTi VF',
                    fontSize: 14,
                    height: 17 / 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                for (var index = 0; index < _brushGuideSteps.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _brushGuideSteps.length - 1 ? 0 : 24,
                    ),
                    child: _BrushModeGuideStepRow(
                      key: ValueKey('brush-mode-guide-step-$index'),
                      step: _brushGuideSteps[index],
                      color: selectedColor,
                      colorRef: selectedColorRef,
                      visible: currentStep >= index,
                    ),
                  ),
              ],
            ),
          ),
          const Positioned(left: -2, top: -38, child: _BrushModeGuideTitle()),
        ],
      ),
    );
  }
}

class _BrushModeGuideTitle extends StatelessWidget {
  const _BrushModeGuideTitle();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('brush-mode-guide-title'),
      width: 150,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 49.8,
            top: 14.93,
            child: _BrushModeGuideTitleLabel(),
          ),
          Transform.translate(
            offset: const Offset(3, 3),
            child: Transform.scale(
              scale: 0.86,
              alignment: Alignment.center,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned(
                      left: 13.8,
                      top: 11.93,
                      child: _BrushModeGuideTitleIcon(),
                    ),
                    for (final pixel in _brushModeGuideTitlePixels)
                      Positioned(
                        left: pixel.left,
                        top: pixel.top,
                        child: SizedBox(
                          width: pixel.width,
                          height: pixel.height,
                          child: const ColoredBox(color: Colors.black),
                        ),
                      ),
                    Positioned(
                      left: 1.21,
                      top: 8.44,
                      child: SvgPicture.asset(
                        'assets/pin_icon/editor_brush_mode_spark_long.svg',
                        width: 14.15,
                        height: 13.58,
                      ),
                    ),
                    Positioned(
                      left: 16.46,
                      top: 4.79,
                      child: Transform.rotate(
                        angle: 34.17 * math.pi / 180,
                        child: SvgPicture.asset(
                          'assets/pin_icon/editor_brush_mode_spark_short.svg',
                          width: 10.71,
                          height: 10.53,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrushModeGuideTitlePixel {
  final double left;
  final double top;
  final double width;
  final double height;

  const _BrushModeGuideTitlePixel(this.left, this.top, this.width, this.height);
}

const _brushModeGuideTitlePixels = <_BrushModeGuideTitlePixel>[
  _BrushModeGuideTitlePixel(41.91, 14.23, 2.59, 0.37),
  _BrushModeGuideTitlePixel(36.30, 13.22, 2.59, 1.19),
  _BrushModeGuideTitlePixel(20.90, 24.18, 4.54, 3.57),
  _BrushModeGuideTitlePixel(26.28, 27.87, 2.34, 1.66),
  _BrushModeGuideTitlePixel(25.82, 26.21, 2.34, 1.66),
  _BrushModeGuideTitlePixel(30.15, 30.62, 2.34, 1.66),
  _BrushModeGuideTitlePixel(27.48, 28.96, 2.39, 1.66),
  _BrushModeGuideTitlePixel(28.62, 30.21, 2.63, 1.66),
  _BrushModeGuideTitlePixel(29.87, 31.87, 3.76, 1.66),
  _BrushModeGuideTitlePixel(33.63, 32.96, 1.77, 5.93),
  _BrushModeGuideTitlePixel(11.13, 36.39, 4.81, 4.93),
  _BrushModeGuideTitlePixel(20.77, 42.51, 4.81, 3.05),
  _BrushModeGuideTitlePixel(33.00, 11.23, 8.91, 3.00),
  _BrushModeGuideTitlePixel(40.55, 26.71, 6.59, 5.63),
];

class _BrushModeGuideTitleLabel extends StatelessWidget {
  const _BrushModeGuideTitleLabel();

  @override
  Widget build(BuildContext context) {
    const fillStyle = TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontFamily: 'Z Labs RoundPix 12px M CN',
      fontWeight: FontWeight.w400,
    );
    final outlineStyle = fillStyle.copyWith(
      foreground: Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = false,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text('画笔模式', style: outlineStyle),
        const Text('画笔模式', style: fillStyle),
      ],
    );
  }
}

class _BrushModeGuideTitleIcon extends StatelessWidget {
  const _BrushModeGuideTitleIcon();

  @override
  Widget build(BuildContext context) {
    const shadowOffsets = <Offset>[
      Offset(4, 4),
      Offset(4, -3),
      Offset(-5, -3),
      Offset(4, -4),
      Offset(-4, 4),
    ];

    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final offset in shadowOffsets)
            Positioned(
              left: offset.dx,
              top: offset.dy,
              child: Image.asset(
                'assets/pin_icon/editor_brush_mode_title.png',
                width: 32,
                height: 32,
                color: Colors.black,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          Image.asset(
            'assets/pin_icon/editor_brush_mode_title.png',
            width: 32,
            height: 32,
          ),
        ],
      ),
    );
  }
}

class _BrushModeGuideStepRow extends StatelessWidget {
  final _BrushGuideStep step;
  final BeadColor color;
  final String colorRef;
  final bool visible;

  const _BrushModeGuideStepRow({
    super.key,
    required this.step,
    required this.color,
    required this.colorRef,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    final underlineColor = Color.fromARGB(
      color.aInt,
      color.rInt,
      color.gInt,
      color.bInt,
    );
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(-0.16, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        opacity: visible ? 1 : 0,
        child: SizedBox(
          height: 32,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BrushModeGuideStepIcon(
                    iconAsset: step.iconAsset,
                    color: color,
                    colorRef: colorRef,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    step.text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Alimama FangYuanTi VF',
                      fontSize: 16,
                      height: 19 / 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Positioned(
                left: step.underlineLeft,
                bottom: 0,
                child: _GuideUnderline(
                  key: ValueKey(
                    'brush-mode-guide-underline-${step.target.name}',
                  ),
                  width: step.underlineWidth,
                  color: underlineColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideUnderline extends StatelessWidget {
  final double width;
  final Color color;

  const _GuideUnderline({super.key, required this.width, required this.color});

  @override
  Widget build(BuildContext context) {
    final isLong = width > 32;
    return CustomPaint(
      size: Size(width, 4),
      painter: _GuideUnderlinePainter(color: color, isLong: isLong),
    );
  }
}

class _GuideUnderlinePainter extends CustomPainter {
  final Color color;
  final bool isLong;

  const _GuideUnderlinePainter({required this.color, required this.isLong});

  @override
  void paint(Canvas canvas, Size size) {
    final sourceWidth = isLong ? 108.0 : 33.0;
    canvas.save();
    canvas.scale(size.width / sourceWidth, size.height / 4);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true;
    for (final offset in isLong ? const [0.0, 25.0, 50.0, 75.0] : const [0.0]) {
      _drawWave(canvas, paint, offset);
    }
    canvas.restore();
  }

  void _drawWave(Canvas canvas, Paint paint, double offset) {
    final path = Path()
      ..moveTo(offset + 0.447266, 2.37573)
      ..lineTo(offset + 2.4269, 1.38592)
      ..cubicTo(
        offset + 3.66511,
        0.766809,
        offset + 5.14684,
        0.900417,
        offset + 6.25434,
        1.73104,
      )
      ..lineTo(offset + 6.44727, 1.87573)
      ..cubicTo(
        offset + 7.63245,
        2.76462,
        offset + 9.26208,
        2.76462,
        offset + 10.4473,
        1.87573,
      )
      ..cubicTo(
        offset + 11.6325,
        0.986843,
        offset + 13.2621,
        0.986843,
        offset + 14.4473,
        1.87573,
      )
      ..cubicTo(
        offset + 15.6325,
        2.76462,
        offset + 17.2621,
        2.76462,
        offset + 18.4473,
        1.87573,
      )
      ..cubicTo(
        offset + 19.6325,
        0.986843,
        offset + 21.2621,
        0.986843,
        offset + 22.4473,
        1.87573,
      )
      ..cubicTo(
        offset + 23.6325,
        2.76462,
        offset + 25.2621,
        2.76462,
        offset + 26.4473,
        1.87573,
      )
      ..lineTo(offset + 26.6402, 1.73104)
      ..cubicTo(
        offset + 27.7477,
        0.900417,
        offset + 29.2294,
        0.766809,
        offset + 30.4676,
        1.38592,
      )
      ..lineTo(offset + 32.4473, 2.37573);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GuideUnderlinePainter oldDelegate) {
    return color != oldDelegate.color || isLong != oldDelegate.isLong;
  }
}

class _BrushModeGuideStepIcon extends StatelessWidget {
  final String? iconAsset;
  final BeadColor color;
  final String colorRef;

  const _BrushModeGuideStepIcon({
    required this.iconAsset,
    required this.color,
    required this.colorRef,
  });

  @override
  Widget build(BuildContext context) {
    if (iconAsset == null) {
      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color.fromARGB(color.aInt, color.rInt, color.gInt, color.bInt),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Text(
          colorRef,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _foregroundColor(color),
            fontFamily: 'Alimama FangYuanTi VF',
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _editorToolSurface,
        borderRadius: BorderRadius.all(Radius.circular(99)),
      ),
      child: SvgPicture.asset(iconAsset!, width: 16, height: 16),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  final BeadColor selectedColor;
  final String selectedColorRef;
  final EditorTool? activeTool;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<EditorTool> onToolSelected;
  final VoidCallback onCurrentColorPressed;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final _BrushGuideTarget? guideTarget;
  final bool isBrushGuide;

  const _EditorToolbar({
    required this.selectedColor,
    required this.selectedColorRef,
    required this.activeTool,
    required this.canUndo,
    required this.canRedo,
    required this.onToolSelected,
    required this.onCurrentColorPressed,
    required this.onUndo,
    required this.onRedo,
    this.guideTarget,
    this.isBrushGuide = false,
  });

  Widget _guideHighlight(
    _BrushGuideTarget target,
    Widget child, {
    _BrushGuideTarget? highlightedTarget,
    required bool isGuideHighlightLayer,
  }) {
    if (!isGuideHighlightLayer) return child;

    final isActiveTarget = highlightedTarget == target;
    final highlightedChild = isActiveTarget
        ? KeyedSubtree(
            key: ValueKey('brush-mode-guide-toolbar-target-${target.name}'),
            child: child,
          )
        : child;
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scale: isActiveTarget ? 1 : 0.92,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        opacity: isActiveTarget ? 1 : 0,
        child: highlightedChild,
      ),
    );
  }

  Widget _buildToolbarRow({
    _BrushGuideTarget? highlightedTarget,
    bool isGuideHighlightLayer = false,
  }) {
    Widget passive(Widget child) {
      if (!isGuideHighlightLayer) return child;
      return Opacity(opacity: 0, child: child);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideHighlight(
          _BrushGuideTarget.currentColor,
          Transform.translate(
            offset: const Offset(0, -4),
            child: _CurrentColorTile(
              color: selectedColor,
              label: selectedColorRef,
              onPressed: onCurrentColorPressed,
            ),
          ),
          highlightedTarget: highlightedTarget,
          isGuideHighlightLayer: isGuideHighlightLayer,
        ),
        passive(const SizedBox(width: 12)),
        passive(const _DashedDivider()),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              _guideHighlight(
                _BrushGuideTarget.brush,
                _EditorToolButton(
                  label: '画笔',
                  asset: 'assets/pin_icon/editor_brush_unselected.svg',
                  selectedAsset: 'assets/pin_icon/editor_brush_selected.svg',
                  selected: activeTool == EditorTool.brush,
                  onPressed: () => onToolSelected(EditorTool.brush),
                ),
                highlightedTarget: highlightedTarget,
                isGuideHighlightLayer: isGuideHighlightLayer,
              ),
              const Spacer(),
              _guideHighlight(
                _BrushGuideTarget.picker,
                _EditorToolButton(
                  label: '取色器',
                  asset: 'assets/pin_icon/editor_picker_unselected.svg',
                  selectedAsset: 'assets/pin_icon/editor_picker_selected.svg',
                  selected: activeTool == EditorTool.picker,
                  onPressed: () => onToolSelected(EditorTool.picker),
                ),
                highlightedTarget: highlightedTarget,
                isGuideHighlightLayer: isGuideHighlightLayer,
              ),
              const Spacer(),
              _guideHighlight(
                _BrushGuideTarget.eraser,
                _EditorToolButton(
                  label: '橡皮擦',
                  asset: 'assets/pin_icon/editor_eraser.svg',
                  selectedAsset: 'assets/pin_icon/editor_eraser_selected.svg',
                  selected: activeTool == EditorTool.eraser,
                  onPressed: () => onToolSelected(EditorTool.eraser),
                ),
                highlightedTarget: highlightedTarget,
                isGuideHighlightLayer: isGuideHighlightLayer,
              ),
              const Spacer(),
              passive(const _DashedDivider()),
              passive(const SizedBox(width: 14)),
              passive(
                _HistoryControls(
                  canUndo: canUndo,
                  canRedo: canRedo,
                  onUndo: onUndo,
                  onRedo: onRedo,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = _EditorBottomSheet(child: _buildToolbarRow());
    if (!isBrushGuide) return toolbar;

    return ClipRRect(
      key: const ValueKey('brush-mode-guide-toolbar-clip'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        children: [
          toolbar,
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                key: ValueKey('brush-mode-guide-toolbar-mask'),
                color: Color(0x99000000),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: _buildToolbarRow(
                  highlightedTarget: guideTarget,
                  isGuideHighlightLayer: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteToolbar extends StatelessWidget {
  final List<_UsedPaletteEntry> entries;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<_UsedPaletteEntry> onColorSelected;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const _PaletteToolbar({
    required this.entries,
    required this.canUndo,
    required this.canRedo,
    required this.onColorSelected,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return _EditorBottomSheet(
      child: SizedBox(
        height: 66,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = entries[index];
                  return Transform.translate(
                    offset: const Offset(0, -4),
                    child: _PaletteUsageTile(
                      item: item,
                      onPressed: () => onColorSelected(item),
                    ),
                  );
                },
              ),
            ),
            _HistoryControls(
              canUndo: canUndo,
              canRedo: canRedo,
              onUndo: onUndo,
              onRedo: onRedo,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryControls extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const _HistoryControls({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('editor-history-controls'),
      width: 97.6,
      height: 51,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: -15,
            top: -4,
            width: 112.6,
            height: 66,
            child: IgnorePointer(child: ColoredBox(color: Colors.white)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _EditorToolButton(
                label: '上一步',
                asset: 'assets/pin_icon/editor_undo_black.svg',
                preserveAssetColor: true,
                enabled: canUndo,
                onPressed: onUndo,
              ),
              _EditorToolButton(
                label: '下一步',
                asset: 'assets/pin_icon/editor_redo_black.svg',
                preserveAssetColor: true,
                enabled: canRedo,
                onPressed: onRedo,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorBottomSheet extends StatelessWidget {
  final Widget child;

  const _EditorBottomSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: child,
    );
  }
}

class _CurrentColorTile extends StatelessWidget {
  final BeadColor color;
  final String label;
  final VoidCallback onPressed;

  const _CurrentColorTile({
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '选择当前颜色',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('editor-current-color-button'),
          onTap: onPressed,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          child: Container(
            width: 48,
            height: 66,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.12),
                width: 0.5,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(
                      color.aInt,
                      color.rInt,
                      color.gInt,
                      color.bInt,
                    ),
                    border: Border.all(
                      color: const Color(0x4D878787),
                      width: 0.5,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _foregroundColor(color),
                      fontFamily: 'Alimama FangYuanTi VF',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '当前',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'Alimama FangYuanTi VF',
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorToolButton extends StatelessWidget {
  final String label;
  final String asset;
  final String? selectedAsset;
  final bool preserveAssetColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  const _EditorToolButton({
    required this.label,
    required this.asset,
    required this.onPressed,
    this.selectedAsset,
    this.preserveAssetColor = false,
    this.selected = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? Colors.white : Colors.black;
    final background = selected ? Colors.black : _editorToolSurface;
    final opacity = enabled ? 1.0 : 0.45;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: opacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: SizedBox(
              width: 42,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: const BorderRadius.all(Radius.circular(99)),
                    ),
                    child: SvgPicture.asset(
                      selected ? selectedAsset ?? asset : asset,
                      width: 18,
                      height: 18,
                      colorFilter: preserveAssetColor
                          ? null
                          : ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Alimama FangYuanTi VF',
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteUsageTile extends StatelessWidget {
  final _UsedPaletteEntry item;
  final VoidCallback onPressed;

  const _PaletteUsageTile({required this.item, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final color = entry.color;
    return Semantics(
      button: true,
      label: '替换 ${entry.ref}，共 ${item.count} 颗',
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: InkWell(
          key: ValueKey('editor-palette-usage-option-${entry.ref}'),
          onTap: onPressed,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          child: Container(
            width: 48,
            height: 66,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.12),
                width: 0.5,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(
                      color.aInt,
                      color.rInt,
                      color.gInt,
                      color.bInt,
                    ),
                    border: Border.all(
                      color: const Color(0x4D878787),
                      width: 0.5,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(
                    entry.ref,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _foregroundColor(color),
                      fontFamily: 'Alimama FangYuanTi VF',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.count}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'Alimama FangYuanTi VF',
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorReplacementSheet extends StatelessWidget {
  final BeadColor source;
  final String sourceRef;
  final List<PaletteEntry> nearbyEntries;
  final List<PaletteEntry> allEntries;

  const _ColorReplacementSheet({
    required this.source,
    required this.sourceRef,
    required this.nearbyEntries,
    required this.allEntries,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = math.min(
      480.0,
      mediaQuery.size.height - mediaQuery.padding.top,
    );
    return Container(
      key: const ValueKey('editor-color-replacement-sheet'),
      width: double.infinity,
      height: height,
      padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + mediaQuery.padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '颜色替换',
                    style: TextStyle(
                      color: Colors.black,
                      fontFamily: 'Alimama FangYuanTi VF',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '关闭颜色替换',
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        key: const ValueKey('editor-color-replacement-close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DashedReplacementCard(source: source, sourceRef: sourceRef),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ReplacementColorSectionTitle('相近颜色'),
                      const SizedBox(height: 12),
                      _ReplacementColorGrid(
                        entries: nearbyEntries,
                        sectionKey: 'nearby',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: _PaletteSectionDivider(),
                      ),
                      const _ReplacementColorSectionTitle('所有颜色'),
                      const SizedBox(height: 12),
                      _ReplacementColorGrid(
                        entries: allEntries,
                        sectionKey: 'all',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedReplacementCard extends StatelessWidget {
  final BeadColor source;
  final String sourceRef;

  const _DashedReplacementCard({required this.source, required this.sourceRef});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedBorderPainter(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ReplacementColorPreview(color: source, label: sourceRef),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 32,
              color: Color(0xFFE5E5E5),
            ),
            const _ReplacementColorPreview(),
          ],
        ),
      ),
    );
  }
}

class _ReplacementColorPreview extends StatelessWidget {
  final BeadColor? color;
  final String? label;

  const _ReplacementColorPreview({this.color, this.label});

  @override
  Widget build(BuildContext context) {
    final previewColor = color == null
        ? Colors.white
        : Color.fromARGB(color!.aInt, color!.rInt, color!.gInt, color!.bInt);
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: previewColor,
        border: Border.all(
          color: color == null
              ? const Color(0xFFE5E5E5)
              : const Color(0x4D878787),
          width: color == null ? 1.5 : 0.5,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: color == null
          ? const CustomPaint(painter: _TransparentPreviewPainter())
          : Text(
              label!,
              style: TextStyle(
                color: _foregroundColor(color!),
                fontFamily: 'Alimama FangYuanTi VF',
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class _ReplacementColorOption extends StatelessWidget {
  final PaletteEntry entry;
  final String sectionKey;
  final VoidCallback onPressed;

  const _ReplacementColorOption({
    required this.entry,
    required this.sectionKey,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry.color;
    return Semantics(
      button: true,
      label: '替换为 ${entry.ref}',
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          key: ValueKey(
            'editor-color-replacement-$sectionKey-option-${entry.ref}',
          ),
          onTap: onPressed,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.fromARGB(
                color.aInt,
                color.rInt,
                color.gInt,
                color.bInt,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Text(
              entry.ref,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _foregroundColor(color),
                fontFamily: 'Alimama FangYuanTi VF',
                fontSize: 14,
                height: 16 / 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplacementColorGrid extends StatelessWidget {
  final List<PaletteEntry> entries;
  final String sectionKey;

  const _ReplacementColorGrid({
    required this.entries,
    required this.sectionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        for (final entry in entries)
          _ReplacementColorOption(
            entry: entry,
            sectionKey: sectionKey,
            onPressed: () => Navigator.pop(context, entry.color),
          ),
      ],
    );
  }
}

class _ReplacementColorSectionTitle extends StatelessWidget {
  final String title;

  const _ReplacementColorSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0x99000000),
        fontFamily: 'Alimama FangYuanTi VF',
        fontSize: 14,
        height: 16 / 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PaletteSectionDivider extends StatelessWidget {
  const _PaletteSectionDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: 1,
      child: CustomPaint(painter: _PaletteSectionDividerPainter()),
    );
  }
}

class _TransparentPreviewPainter extends CustomPainter {
  const _TransparentPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 12.0;
    final light = Paint()..color = const Color(0xFFF5F5F5);
    final dark = Paint()..color = const Color(0xFFE5E5E5);
    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isDark = ((x / cellSize).floor() + (y / cellSize).floor()).isOdd;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isDark ? dark : light,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaletteSectionDividerPainter extends CustomPainter {
  const _PaletteSectionDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDEE2ED)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 2, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedRoundedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Offset(1, 1) & Size(size.width - 2, size.height - 2),
          const Radius.circular(19),
        ),
      );
    final paint = Paint()
      ..color = const Color(0x1A000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 11) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 7, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CurrentColorPickerSheet extends StatelessWidget {
  final List<_UsedPaletteEntry> entries;
  final BeadColor selectedColor;

  const _CurrentColorPickerSheet({
    required this.entries,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('editor-current-color-picker'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0x1F000000),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '选择当前颜色',
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Alimama FangYuanTi VF',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: math.min(
              320,
              96.0 * math.max(1, (entries.length + 4) ~/ 5),
            ),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final item = entries[index];
                return _CurrentColorOption(
                  entry: item.entry,
                  selected: item.entry.color == selectedColor,
                  onPressed: () => Navigator.pop(context, item.entry.color),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentColorOption extends StatelessWidget {
  final PaletteEntry entry;
  final bool selected;
  final VoidCallback onPressed;

  const _CurrentColorOption({
    required this.entry,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry.color;
    return Semantics(
      button: true,
      selected: selected,
      label: entry.ref,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('editor-current-color-option-${entry.ref}'),
          onTap: onPressed,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? Colors.black : const Color(0x1F000000),
                width: selected ? 1.5 : 0.5,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(
                          color.aInt,
                          color.rInt,
                          color.gInt,
                          color.bInt,
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          entry.ref,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _foregroundColor(color),
                            fontFamily: 'Alimama FangYuanTi VF',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.ref,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'Alimama FangYuanTi VF',
                      fontSize: 11,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UsedPaletteEntry {
  final PaletteEntry entry;
  final int count;

  const _UsedPaletteEntry({required this.entry, required this.count});
}

int _compareColorCodes(String left, String right) {
  final leftParts = RegExp(
    r'\d+|\D+',
  ).allMatches(left.toUpperCase()).map((match) => match.group(0)!).toList();
  final rightParts = RegExp(
    r'\d+|\D+',
  ).allMatches(right.toUpperCase()).map((match) => match.group(0)!).toList();
  final length = math.min(leftParts.length, rightParts.length);

  for (var index = 0; index < length; index++) {
    final leftPart = leftParts[index];
    final rightPart = rightParts[index];
    final leftNumber = int.tryParse(leftPart);
    final rightNumber = int.tryParse(rightPart);
    final comparison = leftNumber != null && rightNumber != null
        ? leftNumber.compareTo(rightNumber)
        : leftPart.compareTo(rightPart);
    if (comparison != 0) return comparison;
  }

  return leftParts.length == rightParts.length
      ? left.compareTo(right)
      : leftParts.length.compareTo(rightParts.length);
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(2, 48),
      painter: _DashedDividerPainter(),
    );
  }
}

class _DashedDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _editorToolSurface
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(1, y), Offset(1, y + 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _foregroundColor(BeadColor color) {
  final brightness =
      0.299 * color.rInt + 0.587 * color.gInt + 0.114 * color.bInt;
  return brightness > 127.5 ? Colors.black : Colors.white;
}
