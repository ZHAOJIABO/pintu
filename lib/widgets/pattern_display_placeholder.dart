import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const patternDisplayPlaceholderAsset =
    'assets/figma_common/pattern_display_placeholder.svg';

/// 图纸、收藏、盲盒与作品在没有可展示图片时共用的 Figma 占位图。
class PatternDisplayPlaceholder extends StatelessWidget {
  final BoxFit fit;

  const PatternDisplayPlaceholder({super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox.expand(
        child: SvgPicture.asset(patternDisplayPlaceholderAsset, fit: fit),
      ),
    );
  }
}
