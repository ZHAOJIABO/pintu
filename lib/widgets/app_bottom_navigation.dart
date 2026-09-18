import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_toast.dart';

class AppBottomNavigation extends StatelessWidget {
  final double height;
  final int selectedIndex;
  final VoidCallback onLibraryTap;
  final VoidCallback? onMyTap;
  final VoidCallback? onBeadTap;

  const AppBottomNavigation({
    super.key,
    required this.height,
    required this.selectedIndex,
    required this.onLibraryTap,
    this.onMyTap,
    this.onBeadTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(
        selectedIndex == 2
            ? 'my-bottom-nav-background'
            : 'bottom-nav-background',
      ),
      width: 390,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          for (final (index, label) in ['图库', '拼豆', '我的'].indexed)
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: height <= 60 ? 8 : 12),
                  child: Semantics(
                    button: true,
                    selected: selectedIndex == index,
                    label: label,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: ValueKey(
                        index == 0
                            ? 'my-make-nav-item'
                            : index == 1
                            ? 'bottom-bead-nav-item'
                            : 'home-my-nav-item',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTap: switch (index) {
                        0 => onLibraryTap,
                        1 => onBeadTap ?? () => showAppToast(context, '即将上线'),
                        _ => onMyTap,
                      },
                      child: SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: Center(
                          child: _Label(
                            label: label,
                            selected: selectedIndex == index,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  final bool selected;

  const _Label({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Z Labs RoundPix 12px M CN',
      fontSize: selected ? 19.2 : 16,
      height: 1,
      fontWeight: FontWeight.w900,
    );
    return Transform.rotate(
      angle: selected ? -9 * math.pi / 180 : 0,
      child: Stack(
        children: [
          Text(
            label,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = selected ? 4 : 3
                ..strokeJoin = StrokeJoin.round
                ..color = selected ? Colors.black : const Color(0xFFB8B8C2),
            ),
          ),
          Text(label, style: style.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
