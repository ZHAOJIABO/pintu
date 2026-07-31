import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api/api_models.dart';

const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];

/// 可显示在共用图库中的缩略图数据。
///
/// 首页使用 [TemplateItem]；“我的图纸”则用用户作品列表映射为该模型，
/// 从而保持两处的分类标题和网格样式一致。
class PatternGalleryItem {
  final String id;
  final String thumbnailUrl;
  final List<String> alternateThumbnailUrls;

  const PatternGalleryItem({
    required this.id,
    required this.thumbnailUrl,
    this.alternateThumbnailUrls = const [],
  });
}

/// 首页与“我的图纸”页共用的图纸分类标题和缩略图网格。
class HomePatternGallery extends StatelessWidget {
  final List<TemplateItem> templates;
  final List<PatternGalleryItem>? items;
  final String categoryName;
  final VoidCallback onFilter;
  final bool showFilter;
  final ValueChanged<String>? onTemplateTap;
  final ValueChanged<String>? onItemTap;
  final double gridSpacing;
  final double tileSize;
  final double tileSpacing;

  const HomePatternGallery({
    super.key,
    required this.templates,
    this.items,
    required this.categoryName,
    required this.onFilter,
    this.showFilter = true,
    this.onTemplateTap,
    this.onItemTap,
    this.gridSpacing = 12,
    this.tileSize = 119.33,
    this.tileSpacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 366,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _GalleryTitle(
              categoryName: categoryName,
              onFilter: onFilter,
              showFilter: showFilter,
            ),
          ),
          SizedBox(height: gridSpacing),
          _GalleryGrid(
            templates: templates,
            items: items,
            onTemplateTap: onTemplateTap,
            onItemTap: onItemTap,
            tileSize: tileSize,
            tileSpacing: tileSpacing,
          ),
        ],
      ),
    );
  }
}

class _GalleryTitle extends StatelessWidget {
  final String categoryName;
  final VoidCallback onFilter;
  final bool showFilter;

  const _GalleryTitle({
    required this.categoryName,
    required this.onFilter,
    required this.showFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 350,
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _GalleryTitleLabel(categoryName: categoryName),
          const Spacer(),
          if (showFilter)
            Semantics(
              button: true,
              label: '筛选图纸分类',
              child: GestureDetector(
                key: const ValueKey('home-gallery-filter'),
                onTap: onFilter,
                child: Transform.translate(
                  offset: const Offset(0, 1),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: SvgPicture.asset(
                      'assets/figma_home/gallery_filter_grid.svg',
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

class _GalleryTitleLabel extends StatelessWidget {
  final String categoryName;

  const _GalleryTitleLabel({required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 18, height: 18, child: _GalleryRabbitIcon()),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Text(
            key: const ValueKey('home-gallery-category'),
            categoryName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontFamily: _roundFontFamily,
              fontFamilyFallback: _fontFallbacks,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryRabbitIcon extends StatelessWidget {
  const _GalleryRabbitIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 16,
        height: 16,
        child: SvgPicture.asset('assets/figma_home/gallery_title_rabbit.svg'),
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  final List<TemplateItem> templates;
  final List<PatternGalleryItem>? items;
  final ValueChanged<String>? onTemplateTap;
  final ValueChanged<String>? onItemTap;
  final double tileSize;
  final double tileSpacing;

  const _GalleryGrid({
    required this.templates,
    required this.items,
    required this.onTemplateTap,
    required this.onItemTap,
    required this.tileSize,
    required this.tileSpacing,
  });

  static const _fallbackThumbnailUrl =
      'assets/figma_home/gallery_pattern_1.png';

  List<_GalleryPattern> get _patterns {
    final galleryItems = items;
    if (galleryItems != null) {
      final patterns = galleryItems
          .where((item) => item.id.isNotEmpty && item.thumbnailUrl.isNotEmpty)
          .map(
            (item) => _GalleryPattern(
              id: item.id,
              actionId: item.id,
              thumbnailUrl: item.thumbnailUrl,
              alternateThumbnailUrls: item.alternateThumbnailUrls,
            ),
          )
          .toList();
      return patterns;
    }
    final remotePatterns = templates
        .map(
          (template) => _GalleryPattern(
            id: template.templateId,
            actionId: template.templateId,
            thumbnailUrl: template.thumbnailUrl.isNotEmpty
                ? template.thumbnailUrl
                : template.previewUrl,
          ),
        )
        .where(
          (pattern) => pattern.id.isNotEmpty && pattern.thumbnailUrl.isNotEmpty,
        )
        .toList();
    return remotePatterns;
  }

  @override
  Widget build(BuildContext context) {
    final patterns = _patterns;
    return SizedBox(
      width: 366,
      child: Wrap(
        spacing: tileSpacing,
        runSpacing: tileSpacing,
        children: [
          for (final pattern in patterns)
            _GalleryTile(
              pattern: pattern,
              fallbackThumbnailUrl: _fallbackThumbnailUrl,
              onTap: _onPatternTap(pattern),
              tileSize: tileSize,
            ),
        ],
      ),
    );
  }

  VoidCallback? _onPatternTap(_GalleryPattern pattern) {
    final callback = items == null ? onTemplateTap : onItemTap;
    final actionId = pattern.actionId;
    if (callback == null || actionId == null) return null;
    return () => callback(actionId);
  }
}

class _GalleryPattern {
  final String id;
  final String? actionId;
  final String thumbnailUrl;
  final List<String> alternateThumbnailUrls;

  const _GalleryPattern({
    required this.id,
    this.actionId,
    required this.thumbnailUrl,
    this.alternateThumbnailUrls = const [],
  });
}

class _GalleryTile extends StatelessWidget {
  final _GalleryPattern pattern;
  final String fallbackThumbnailUrl;
  final double tileSize;
  final VoidCallback? onTap;

  const _GalleryTile({
    required this.pattern,
    required this.fallbackThumbnailUrl,
    required this.tileSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: tileSize,
        height: tileSize,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _GalleryThumbnail(
                    key: ValueKey('gallery-thumbnail-${pattern.id}'),
                    url: pattern.thumbnailUrl,
                    alternateUrls: pattern.alternateThumbnailUrls,
                    fallbackUrl: fallbackThumbnailUrl,
                  ),
                ),
                const Positioned.fill(child: _GalleryFade()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryThumbnail extends StatelessWidget {
  final String url;
  final List<String> alternateUrls;
  final String fallbackUrl;

  const _GalleryThumbnail({
    super.key,
    required this.url,
    this.alternateUrls = const [],
    required this.fallbackUrl,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    final isNetworkImage =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    if (!isNetworkImage) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          fallbackUrl,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        ),
        Image.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox.expand();
          },
          errorBuilder: (context, error, stackTrace) {
            if (alternateUrls.isNotEmpty) {
              return _GalleryThumbnail(
                url: alternateUrls.first,
                alternateUrls: alternateUrls.skip(1).toList(),
                fallbackUrl: fallbackUrl,
              );
            }
            return const SizedBox.expand();
          },
        ),
      ],
    );
  }
}

class _GalleryFade extends StatelessWidget {
  const _GalleryFade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0x00FFFFFF), Color(0x00FFFFFF)],
          radius: 0.78,
        ),
      ),
    );
  }
}
