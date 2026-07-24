import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _dialogWidth = 330.0;
const _dialogCardHeight = 305.0;
const _dialogActionHeight = 52.0;
const _dialogActionWidth = 260.0;
const _dialogTotalHeight = _dialogCardHeight + 16 + _dialogActionHeight;
const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];

/// Shows the Figma-designed hint that explains where saved patterns are kept.
Future<void> showPatternsHintDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭图纸查看提示',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => const PatternsHintDialog(),
    transitionBuilder: (context, animation, _, child) {
      final opacity = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: opacity, child: child);
    },
  );
}

class PatternsHintDialog extends StatelessWidget {
  const PatternsHintDialog({super.key});

  void _dismiss(BuildContext context) => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _dismiss(context),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: const ColoredBox(color: Color(0x99000000)),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = math.max(0.0, constraints.maxWidth - 40);
              final availableHeight = math.max(0.0, constraints.maxHeight - 48);
              final scale = math.min(
                1,
                math.min(
                  availableWidth / _dialogWidth,
                  availableHeight / _dialogTotalHeight,
                ),
              );

              return Center(
                child: SizedBox(
                  width: _dialogWidth * scale,
                  height: _dialogTotalHeight * scale,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _dialogWidth,
                      height: _dialogTotalHeight,
                      child: _PatternsHintDialogContent(
                        onDismiss: () => _dismiss(context),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PatternsHintDialogContent extends StatelessWidget {
  final VoidCallback onDismiss;

  const _PatternsHintDialogContent({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: const ValueKey('patterns-hint-dialog'),
          width: _dialogWidth,
          height: _dialogCardHeight,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _HintTitle(),
                  SizedBox(height: 24),
                  SizedBox(
                    key: ValueKey('patterns-hint-dialog-illustration'),
                    width: 282,
                    height: 201,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      child: Image(
                        image: AssetImage('assets/figma_my/patterns_hint.png'),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: '我知道啦',
          child: GestureDetector(
            key: const ValueKey('patterns-hint-dialog-confirm'),
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.all(
                  Radius.circular(_dialogActionHeight / 2),
                ),
              ),
              child: SizedBox(
                width: _dialogActionWidth,
                height: _dialogActionHeight,
                child: Center(
                  child: Text(
                    '我知道啦！',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: _roundFontFamily,
                      fontFamilyFallback: _fontFallbacks,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HintTitle extends StatelessWidget {
  const _HintTitle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 282,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 6,
            left: 0,
            child: Text(
              '图纸也可以在“我的-图纸”中查看哦～',
              style: TextStyle(
                color: Colors.black,
                fontFamily: _roundFontFamily,
                fontFamilyFallback: _fontFallbacks,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          Positioned(
            left: 119,
            bottom: 1,
            width: 57,
            height: 3,
            child: CustomPaint(painter: _PinkUnderlinePainter()),
          ),
        ],
      ),
    );
  }
}

class _PinkUnderlinePainter extends CustomPainter {
  const _PinkUnderlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height / 2);
    const waves = 7;
    final waveWidth = size.width / waves;

    for (var index = 0; index < waves; index++) {
      final start = index * waveWidth;
      path.quadraticBezierTo(
        start + waveWidth * 0.25,
        size.height,
        start + waveWidth * 0.5,
        size.height / 2,
      );
      path.quadraticBezierTo(
        start + waveWidth * 0.75,
        0,
        start + waveWidth,
        size.height / 2,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF55BD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PinkUnderlinePainter oldDelegate) => false;
}
