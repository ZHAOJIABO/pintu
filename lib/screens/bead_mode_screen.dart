import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/generated_pattern.dart';
import '../widgets/bead_board_preview.dart';
import 'pattern_editor_screen.dart';

const _pageBackground = Color(0xFFEEF0F6);

class BeadModeScreen extends StatefulWidget {
  final GeneratedPattern pattern;

  const BeadModeScreen({super.key, required this.pattern});

  @override
  State<BeadModeScreen> createState() => _BeadModeScreenState();
}

class _BeadModeScreenState extends State<BeadModeScreen> {
  late GeneratedPattern _pattern = widget.pattern;
  String? _selectedBeadRef;
  bool _toolbarCollapsed = false;
  bool _mirrored = false;
  bool _showColors = true;
  bool _showRulers = true;
  bool _interactionLocked = false;

  Future<void> _openEditor() async {
    final editedPattern = await Navigator.push<GeneratedPattern>(
      context,
      MaterialPageRoute(builder: (_) => PatternEditorScreen(pattern: _pattern)),
    );
    if (!mounted || editedPattern == null) return;

    setState(() => _pattern = editedPattern);
  }

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
          bottom: false,
          child: Column(
            children: [
              _BeadModeNavigationBar(onEdit: _openEditor),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: BeadBoardPreview(
                        key: const ValueKey('bead-mode-board'),
                        pixels: _pattern.pixels,
                        width: _pattern.width,
                        height: _pattern.height,
                        paletteEntries: _pattern.paletteEntries,
                        selectedRef: _selectedBeadRef,
                        showRulers: _showRulers,
                        mirrorHorizontally: _mirrored,
                        interactionLocked: _interactionLocked,
                      ),
                    ),
                    if (_showColors)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: BeadModeUsageStrip(
                          key: const ValueKey('bead-mode-color-strip'),
                          usage: _pattern.usage,
                          entries: _pattern.paletteEntries,
                          compact: true,
                          selectedRef: _selectedBeadRef,
                          onSelected: (ref) =>
                              setState(() => _selectedBeadRef = ref),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: _showColors ? 162 : 56,
                      child: _BeadModeToolbar(
                        key: const ValueKey('bead-mode-toolbar'),
                        collapsed: _toolbarCollapsed,
                        mirrored: _mirrored,
                        colorsVisible: _showColors,
                        rulersVisible: _showRulers,
                        interactionLocked: _interactionLocked,
                        onCollapse: () => setState(
                          () => _toolbarCollapsed = !_toolbarCollapsed,
                        ),
                        onMirror: () => setState(() => _mirrored = !_mirrored),
                        onColors: () =>
                            setState(() => _showColors = !_showColors),
                        onRulers: () =>
                            setState(() => _showRulers = !_showRulers),
                        onLock: () => setState(
                          () => _interactionLocked = !_interactionLocked,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeadModeNavigationBar extends StatelessWidget {
  final VoidCallback onEdit;

  const _BeadModeNavigationBar({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavigationAction(
              label: '返回',
              onTap: () => Navigator.pop(context),
              asset: 'assets/pin_icon/bead_back.svg',
            ),
            _NavigationAction(
              key: const ValueKey('bead-mode-edit-button'),
              label: '编辑图纸',
              onTap: onEdit,
              asset: 'assets/pin_icon/bead_edit.svg',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final String asset;

  const _NavigationAction({
    super.key,
    required this.label,
    required this.onTap,
    required this.asset,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: SvgPicture.asset(asset, width: 24, height: 24)),
        ),
      ),
    );
  }
}

class _BeadModeToolbar extends StatelessWidget {
  final bool collapsed;
  final bool mirrored;
  final bool colorsVisible;
  final bool rulersVisible;
  final bool interactionLocked;
  final VoidCallback onCollapse;
  final VoidCallback onMirror;
  final VoidCallback onColors;
  final VoidCallback onRulers;
  final VoidCallback onLock;

  const _BeadModeToolbar({
    super.key,
    required this.collapsed,
    required this.mirrored,
    required this.colorsVisible,
    required this.rulersVisible,
    required this.interactionLocked,
    required this.onCollapse,
    required this.onMirror,
    required this.onColors,
    required this.onRulers,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 52,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1E000000),
            blurRadius: 4,
            offset: Offset(-2, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: collapsed ? '展开工具栏' : '收起工具栏',
            child: GestureDetector(
              key: const ValueKey('bead-mode-tool-collapse'),
              behavior: HitTestBehavior.opaque,
              onTap: onCollapse,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Transform.rotate(
                    angle: collapsed ? math.pi : 0,
                    child: SvgPicture.asset(
                      'assets/pin_icon/toolbar_collapse.svg',
                      width: 36,
                      height: 36,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 16),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolbarButton(
                  key: const ValueKey('bead-mode-tool-mirror'),
                  label: '镜像',
                  asset: mirrored
                      ? 'assets/pin_icon/toolbar_mirror_selected.svg'
                      : 'assets/pin_icon/toolbar_mirror.svg',
                  iconKey: ValueKey(
                    mirrored
                        ? 'bead-mode-mirror-icon-selected'
                        : 'bead-mode-mirror-icon-default',
                  ),
                  iconSize: 18,
                  selected: mirrored,
                  onTap: onMirror,
                ),
                const SizedBox(height: 24),
                _ToolbarButton(
                  key: const ValueKey('bead-mode-tool-colors'),
                  label: '颜色',
                  asset: 'assets/pin_icon/toolbar_palette.svg',
                  iconKey: colorsVisible
                      ? const ValueKey('bead-mode-palette-icon-selected')
                      : null,
                  iconSize: 21.6,
                  icon: colorsVisible
                      ? null
                      : const _UnselectedPaletteIcon(
                          key: ValueKey('bead-mode-palette-icon-unselected'),
                        ),
                  selected: colorsVisible,
                  onTap: onColors,
                ),
                const SizedBox(height: 24),
                _ToolbarButton(
                  key: const ValueKey('bead-mode-tool-rulers'),
                  label: '标尺',
                  asset: rulersVisible
                      ? 'assets/pin_icon/toolbar_ruler.svg'
                      : 'assets/pin_icon/toolbar_ruler_unselected.svg',
                  iconSize: 21.6,
                  selected: rulersVisible,
                  onTap: onRulers,
                ),
                const SizedBox(height: 24),
                _ToolbarButton(
                  key: const ValueKey('bead-mode-tool-lock'),
                  label: '锁定',
                  asset: interactionLocked
                      ? 'assets/pin_icon/toolbar_lock.svg'
                      : 'assets/pin_icon/toolbar_lock_unselected.svg',
                  iconSize: 21.6,
                  selected: interactionLocked,
                  onTap: onLock,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final String asset;
  final Key? iconKey;
  final double iconSize;
  final Widget? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToolbarButton({
    super.key,
    required this.label,
    required this.asset,
    this.iconKey,
    required this.iconSize,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? Colors.white : Colors.black;

    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selected ? Colors.black : const Color(0xFFDEE2ED),
              shape: BoxShape.circle,
            ),
            child: Center(
              child:
                  icon ??
                  SvgPicture.asset(
                    asset,
                    key: iconKey,
                    width: iconSize,
                    height: iconSize,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnselectedPaletteIcon extends StatelessWidget {
  const _UnselectedPaletteIcon({super.key});

  @override
  Widget build(BuildContext context) {
    // The original palette SVG carries its dots as a compound path. Some
    // renderers omit that path, so the four swatches are intentionally drawn
    // as separate widgets above the Figma-provided outline.
    return SizedBox(
      width: 21.6,
      height: 21.6,
      child: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/pin_icon/toolbar_palette_unselected.svg',
              colorFilter: ColorFilter.mode(Colors.black, BlendMode.srcIn),
            ),
          ),
          const _PaletteDot(
            key: ValueKey('bead-mode-palette-dot-1'),
            left: 5.59,
            top: 11.27,
            size: 1.77,
          ),
          const _PaletteDot(
            key: ValueKey('bead-mode-palette-dot-2'),
            left: 5.55,
            top: 7.89,
            size: 1.98,
          ),
          const _PaletteDot(
            key: ValueKey('bead-mode-palette-dot-3'),
            left: 7.92,
            top: 5.36,
            size: 2.21,
          ),
          const _PaletteDot(
            key: ValueKey('bead-mode-palette-dot-4'),
            left: 11.39,
            top: 5.45,
            size: 2.44,
          ),
        ],
      ),
    );
  }
}

class _PaletteDot extends StatelessWidget {
  final double left;
  final double top;
  final double size;

  const _PaletteDot({
    super.key,
    required this.left,
    required this.top,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: size, height: size),
      ),
    );
  }
}
