import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/color.dart';
import '../models/editable_pattern.dart';
import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../services/editor_history_service.dart';
import '../services/pattern_edit_service.dart';
import '../widgets/bead_board_preview.dart';

const _editorBackground = Color(0xFFEEF0F6);
const _editorToolSurface = Color(0xFFDEE2ED);

enum _EditorPanel { brush, palette }

class PatternEditorScreen extends StatefulWidget {
  final GeneratedPattern pattern;

  const PatternEditorScreen({super.key, required this.pattern});

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

  String get _selectedColorRef {
    for (final entry in widget.pattern.paletteEntries) {
      if (entry.color == _selectedColor) return entry.ref;
    }
    return _selectedColor.toHex().replaceFirst('#', '').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        key: const ValueKey('pattern-editor-screen'),
        backgroundColor: _editorBackground,
        body: SafeArea(
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
                  onCellStart: _tool == null ? null : _startStroke,
                  onCellChanged: _tool == null ? null : _continueStroke,
                  onCellEnd: _tool == null ? null : _finishStroke,
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
                      entries: widget.pattern.paletteEntries,
                      selectedColor: _selectedColor,
                      onColorSelected: _selectPaletteColor,
                    ),
            ],
          ),
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
  });

  @override
  Widget build(BuildContext context) {
    return _EditorBottomSheet(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -4),
            child: _CurrentColorTile(
              color: selectedColor,
              label: selectedColorRef,
              onPressed: onCurrentColorPressed,
            ),
          ),
          const SizedBox(width: 12),
          const _DashedDivider(),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _EditorToolButton(
                  label: '画笔',
                  asset: 'assets/pin_icon/editor_brush_unselected.svg',
                  selectedAsset: 'assets/pin_icon/editor_brush_selected.svg',
                  selected: activeTool == EditorTool.brush,
                  onPressed: () => onToolSelected(EditorTool.brush),
                ),
                _EditorToolButton(
                  label: '取色器',
                  asset: 'assets/pin_icon/editor_picker_unselected.svg',
                  selectedAsset: 'assets/pin_icon/editor_picker_selected.svg',
                  selected: activeTool == EditorTool.picker,
                  onPressed: () => onToolSelected(EditorTool.picker),
                ),
                _EditorToolButton(
                  label: '橡皮擦',
                  asset: 'assets/pin_icon/editor_eraser.svg',
                  selectedAsset: 'assets/pin_icon/editor_eraser_selected.svg',
                  selected: activeTool == EditorTool.eraser,
                  onPressed: () => onToolSelected(EditorTool.eraser),
                ),
                const _DashedDivider(),
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
          ),
        ],
      ),
    );
  }
}

class _PaletteToolbar extends StatelessWidget {
  final List<PaletteEntry> entries;
  final BeadColor selectedColor;
  final ValueChanged<BeadColor> onColorSelected;

  const _PaletteToolbar({
    required this.entries,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = entries.isEmpty
        ? <PaletteEntry>[
            PaletteEntry(
              name: '当前颜色',
              ref: '当前',
              symbol: '',
              color: selectedColor,
              prefix: '',
            ),
          ]
        : entries;

    return _EditorBottomSheet(
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: colors.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final entry = colors[index];
            return _PaletteColorTile(
              entry: entry,
              selected: entry.color == selectedColor,
              onPressed: () => onColorSelected(entry.color),
            );
          },
        ),
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

class _PaletteColorTile extends StatelessWidget {
  final PaletteEntry entry;
  final bool selected;
  final VoidCallback onPressed;

  const _PaletteColorTile({
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
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Colors.black
                  : Colors.black.withValues(alpha: 0.12),
              width: selected ? 1.5 : 0.5,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.fromARGB(
                    color.aInt,
                    color.rInt,
                    color.gInt,
                    color.bInt,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
    );
  }
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
