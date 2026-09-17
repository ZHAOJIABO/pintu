import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api/api_models.dart';
import 'pattern_display_placeholder.dart';

const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const galleryFallbackThumbnailUrl = patternDisplayPlaceholderAsset;

/// 可显示在共用图库中的缩略图数据。
///
/// 首页使用 [TemplateItem]；“我的图纸”则用用户作品列表映射为该模型，
/// 从而保持两处的分类标题和网格样式一致。
class PatternGalleryItem {
  final String id;
  final String thumbnailUrl;
  final List<String> alternateThumbnailUrls;
  final bool isPendingReview;

  const PatternGalleryItem({
    required this.id,
    required this.thumbnailUrl,
    this.alternateThumbnailUrls = const [],
    this.isPendingReview = false,
  });
}

/// 首页与“我的图纸”页共用的图纸分类标题和缩略图网格。
class HomePatternGallery extends StatelessWidget {
  final List<TemplateItem> templates;
  final List<PatternGalleryItem>? items;
  final String categoryName;
  final VoidCallback onFilter;
  final bool showFilter;
  final Widget? header;
  final Widget? footer;
  final ValueChanged<String>? onTemplateTap;
  final ValueChanged<String>? onItemTap;
  final double gridSpacing;
  final double tileSize;
  final double tileSpacing;
  final double thumbnailPadding;
  final bool showTemplateAuthors;
  final bool showTemplateDetails;
  final ValueChanged<TemplateItem>? onFavorite;

  const HomePatternGallery({
    super.key,
    required this.templates,
    this.items,
    required this.categoryName,
    required this.onFilter,
    this.showFilter = true,
    this.header,
    this.footer,
    this.onTemplateTap,
    this.onItemTap,
    this.gridSpacing = 12,
    this.tileSize = 119.33,
    this.tileSpacing = 4,
    this.thumbnailPadding = 0,
    this.showTemplateAuthors = true,
    this.showTemplateDetails = false,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 366,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            header!
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _GalleryTitle(
                categoryName: categoryName,
                onFilter: onFilter,
                showFilter: showFilter,
              ),
            ),
            SizedBox(height: gridSpacing),
          ],
          _GalleryGrid(
            templates: templates,
            items: items,
            onTemplateTap: onTemplateTap,
            onItemTap: onItemTap,
            tileSize: tileSize,
            tileSpacing: tileSpacing,
            thumbnailPadding: thumbnailPadding,
            showTemplateAuthors: showTemplateAuthors,
            showTemplateDetails: showTemplateDetails,
            onFavorite: onFavorite,
          ),
          if (footer != null) footer!,
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
  final double thumbnailPadding;
  final bool showTemplateAuthors;
  final bool showTemplateDetails;
  final ValueChanged<TemplateItem>? onFavorite;

  const _GalleryGrid({
    required this.templates,
    required this.items,
    required this.onTemplateTap,
    required this.onItemTap,
    required this.tileSize,
    required this.tileSpacing,
    required this.thumbnailPadding,
    required this.showTemplateAuthors,
    required this.showTemplateDetails,
    required this.onFavorite,
  });

  List<_GalleryPattern> get _patterns {
    final galleryItems = items;
    if (galleryItems != null) {
      final patterns = galleryItems
          .where((item) => item.id.isNotEmpty)
          .map(
            (item) => _GalleryPattern(
              id: item.id,
              actionId: item.id,
              thumbnailUrl: item.thumbnailUrl,
              alternateThumbnailUrls: item.alternateThumbnailUrls,
              isPendingReview: item.isPendingReview,
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
            authorName: showTemplateAuthors && !showTemplateDetails
                ? template.displayAuthorName
                : null,
            templateDetails: showTemplateDetails ? template : null,
          ),
        )
        .where((pattern) => pattern.id.isNotEmpty)
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
        runSpacing: showTemplateDetails ? 16 : tileSpacing,
        children: [
          for (final pattern in patterns)
            _GalleryTile(
              pattern: pattern,
              fallbackThumbnailUrl: galleryFallbackThumbnailUrl,
              onTap: _onPatternTap(pattern),
              tileSize: tileSize,
              thumbnailPadding: thumbnailPadding,
              fillHeight: items == null,
              onFavorite: onFavorite,
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
  final bool isPendingReview;
  final String? authorName;
  final TemplateItem? templateDetails;

  const _GalleryPattern({
    required this.id,
    this.actionId,
    required this.thumbnailUrl,
    this.alternateThumbnailUrls = const [],
    this.isPendingReview = false,
    this.authorName,
    this.templateDetails,
  });
}

class _GalleryTile extends StatelessWidget {
  final _GalleryPattern pattern;
  final String fallbackThumbnailUrl;
  final double tileSize;
  final double thumbnailPadding;
  final bool fillHeight;
  final ValueChanged<TemplateItem>? onFavorite;
  final VoidCallback? onTap;

  const _GalleryTile({
    required this.pattern,
    required this.fallbackThumbnailUrl,
    required this.tileSize,
    required this.thumbnailPadding,
    required this.fillHeight,
    this.onFavorite,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('gallery-tile-${pattern.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: tileSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: tileSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  pattern.templateDetails == null ? 12 : 20,
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.white),
                  child: _GalleryTilePreview(
                    pattern: pattern,
                    fallbackThumbnailUrl: fallbackThumbnailUrl,
                    fillHeight: fillHeight,
                    padding: thumbnailPadding,
                  ),
                ),
              ),
            ),
            if (pattern.templateDetails case final template?) ...[
              const SizedBox(height: 12),
              _TemplateDetails(template: template, onFavorite: onFavorite),
            ],
            if (pattern.authorName case final authorName?) ...[
              const SizedBox(height: 8),
              Text(
                'by $authorName',
                key: ValueKey('gallery-author-${pattern.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0x4D000000),
                  fontFamily: _roundFontFamily,
                  fontFamilyFallback: _fontFallbacks,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateDetails extends StatelessWidget {
  final TemplateItem template;

  final ValueChanged<TemplateItem>? onFavorite;

  const _TemplateDetails({required this.template, this.onFavorite});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: _roundFontFamily,
      fontFamilyFallback: _fontFallbacks,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 20 / 14,
      color: Colors.black,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              template.title,
              key: ValueKey('gallery-title-${template.templateId}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onFavorite == null ? null : () => onFavorite!(template),
            child: Semantics(
              button: onFavorite != null,
              label: template.isFavorited ? '取消喜欢' : '喜欢并复制',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    template.isFavorited
                        ? 'assets/figma_home/template_heart_active.png'
                        : 'assets/figma_home/template_heart_inactive.png',
                    key: ValueKey('gallery-heart-${template.templateId}'),
                    width: 16,
                    height: 16,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(template.favoriteCount),
                    style: style.copyWith(color: const Color(0x4D000000)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 10000) return '$count';
    return '${(count / 10000).toStringAsFixed(1)}万';
  }
}

class _GalleryTilePreview extends StatelessWidget {
  final _GalleryPattern pattern;
  final String fallbackThumbnailUrl;
  final bool fillHeight;
  final double padding;

  const _GalleryTilePreview({
    required this.pattern,
    required this.fallbackThumbnailUrl,
    required this.fillHeight,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final preview = Stack(
      children: [
        Positioned.fill(
          child: _GalleryThumbnail(
            key: ValueKey('gallery-thumbnail-${pattern.id}'),
            url: pattern.thumbnailUrl,
            fallbackUrl: fallbackThumbnailUrl,
            fit: fillHeight ? BoxFit.fitHeight : BoxFit.cover,
          ),
        ),
        const Positioned.fill(child: _GalleryFade()),
        if (pattern.isPendingReview)
          Positioned(
            top: 6,
            right: 6,
            child: _PendingReviewBadge(patternId: pattern.id),
          ),
      ],
    );
    if (padding == 0) return preview;

    return Padding(
      key: ValueKey('gallery-thumbnail-padding-${pattern.id}'),
      padding: EdgeInsets.all(padding),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: preview),
    );
  }
}

class _PendingReviewBadge extends StatelessWidget {
  final String patternId;

  const _PendingReviewBadge({required this.patternId});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '审核中',
      child: Container(
        key: ValueKey('gallery-review-pending-$patternId'),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xCC4B5563),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '审核中',
          style: TextStyle(
            color: Colors.white,
            fontFamily: _roundFontFamily,
            fontFamilyFallback: _fontFallbacks,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GalleryThumbnail extends StatelessWidget {
  final String url;
  final String fallbackUrl;
  final BoxFit fit;

  const _GalleryThumbnail({
    super.key,
    required this.url,
    required this.fallbackUrl,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    final isNetworkImage =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    if (!isNetworkImage) {
      if (url.isEmpty || url == fallbackUrl) {
        return const PatternDisplayPlaceholder();
      }
      return Image.asset(
        url,
        fit: fit,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const PatternDisplayPlaceholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      placeholder: (_, _) => const PatternDisplayPlaceholder(),
      errorWidget: (_, _, _) => const PatternDisplayPlaceholder(),
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
