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

enum PatternsHintDestination { patterns, favorites, drafts }

/// Shows the Figma-designed hint that explains where saved patterns are kept.
Future<void> showPatternsHintDialog(
  BuildContext context, {
  PatternsHintDestination destination = PatternsHintDestination.patterns,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭图纸查看提示',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) =>
        PatternsHintDialog(destination: destination),
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
  final PatternsHintDestination destination;

  const PatternsHintDialog({
    super.key,
    this.destination = PatternsHintDestination.patterns,
  });

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
                        destination: destination,
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
  final PatternsHintDestination destination;

  const _PatternsHintDialogContent({
    required this.onDismiss,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final isFavorites = destination == PatternsHintDestination.favorites;
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
                children: [
                  _HintTitle(destination: destination),
                  const SizedBox(height: 24),
                  SizedBox(
                    key: ValueKey(
                      isFavorites
                          ? 'patterns-hint-dialog-favorites-illustration'
                          : 'patterns-hint-dialog-illustration',
                    ),
                    width: 282,
                    height: 201,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      child: Image(
                        image: AssetImage(
                          isFavorites
                              ? 'assets/figma_my/favorites_hint.png'
                              : 'assets/figma_my/patterns_hint.png',
                        ),
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
  final PatternsHintDestination destination;

  const _HintTitle({required this.destination});

  @override
  Widget build(BuildContext context) {
    final isFavorites = destination == PatternsHintDestination.favorites;
    final title = switch (destination) {
      PatternsHintDestination.patterns => '图纸也可以在“我的-图纸”中查看哦～',
      PatternsHintDestination.favorites => '已保存至“我的-收藏”',
      PatternsHintDestination.drafts => '草稿将保存在“我的-我的图纸”中',
    };
    final underline = switch (destination) {
      PatternsHintDestination.patterns => (left: 119.0, width: 57.0),
      PatternsHintDestination.favorites => (left: 67.0, width: 76.0),
      PatternsHintDestination.drafts => (left: 81.0, width: 92.0),
    };
    return SizedBox(
      width: 282,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 6,
            left: 0,
            child: Text(
              title,
              style: const TextStyle(
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
            left: underline.left,
            bottom: 1,
            width: underline.width,
            height: 3,
            child: CustomPaint(
              painter: _HintUnderlinePainter(
                color: isFavorites
                    ? const Color(0xFFFFC62D)
                    : const Color(0xFFFF55BD),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintUnderlinePainter extends CustomPainter {
  final Color color;

  const _HintUnderlinePainter({required this.color});

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
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HintUnderlinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
