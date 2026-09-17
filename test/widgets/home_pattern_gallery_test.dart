import 'package:bobobeads/widgets/home_pattern_gallery.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('heart tap calls favorite action without opening the template', (
    tester,
  ) async {
    var favorites = 0;
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePatternGallery(
            templates: [_template(id: 'tap-heart')],
            categoryName: '全部',
            onFilter: () {},
            showTemplateDetails: true,
            tileSize: 177,
            tileSpacing: 12,
            onFavorite: (template) {
              favorites++;
            },
            onTemplateTap: (_) {
              opens++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('gallery-heart-tap-heart')));
    expect(favorites, 1);
    expect(opens, 0);
  });

  testWidgets('template cards show titles, counts and both heart states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePatternGallery(
            templates: [
              _template(id: 'inactive'),
              _template(
                id: 'active',
              ).copyWith(isFavorited: true, favoriteCount: 445),
            ],
            categoryName: '全部',
            onFilter: () {},
            showTemplateDetails: true,
            tileSize: 177,
            tileSpacing: 12,
          ),
        ),
      ),
    );
    expect(find.text('445'), findsOneWidget);
    expect(find.text('by pintoo'), findsNothing);
    final title = tester.widget<Text>(
      find.byKey(const ValueKey('gallery-title-active')),
    );
    expect(title.overflow, TextOverflow.ellipsis);
    for (final state in ['active', 'inactive']) {
      final heart = tester.widget<Image>(
        find.byKey(ValueKey('gallery-heart-$state')),
      );
      expect(
        (heart.image as AssetImage).assetName,
        'assets/figma_home/template_heart_$state.png',
      );
      expect(
        tester.getSize(find.byKey(ValueKey('gallery-heart-$state'))),
        const Size(16, 16),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks a work with a pending submission as under review', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePatternGallery(
            templates: const [],
            items: const [
              PatternGalleryItem(
                id: 'work-001',
                thumbnailUrl: 'assets/figma_home/gallery_pattern_1.png',
                isPendingReview: true,
              ),
            ],
            categoryName: '全部',
            onFilter: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('gallery-review-pending-work-001')),
      findsOneWidget,
    );
    expect(find.text('审核中'), findsOneWidget);
  });

  testWidgets('shows template author and falls back to pintoo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePatternGallery(
            templates: [
              _template(id: 'with-author', authorName: '气态美式'),
              _template(id: 'without-author'),
            ],
            categoryName: '全部',
            onFilter: () {},
          ),
        ),
      ),
    );

    expect(find.text('by 气态美式'), findsOneWidget);
    expect(find.text('by pintoo'), findsOneWidget);

    final publicTemplateImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('gallery-thumbnail-with-author')),
        matching: find.byType(Image),
      ),
    );
    expect(publicTemplateImage.fit, BoxFit.fitHeight);
    expect(publicTemplateImage.alignment, Alignment.center);
  });

  testWidgets('uses a cached image widget for remote thumbnails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePatternGallery(
            templates: const [],
            items: const [
              PatternGalleryItem(
                id: 'remote-work',
                thumbnailUrl: 'https://example.com/thumbnail.png',
              ),
            ],
            categoryName: '全部',
            onFilter: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('can inset template thumbnails within their white tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePatternGallery(
            templates: [_template(id: 'inset-template')],
            categoryName: '全部',
            onFilter: () {},
            thumbnailPadding: 6,
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<Padding>(
            find.byKey(
              const ValueKey('gallery-thumbnail-padding-inset-template'),
            ),
          )
          .padding,
      const EdgeInsets.all(6),
    );
  });
}

TemplateItem _template({required String id, String authorName = ''}) {
  return TemplateItem(
    templateId: id,
    title: '这是一个需要省略显示的长图纸名称',
    authorName: authorName,
    previewUrl: 'assets/figma_home/gallery_pattern_1.png',
    thumbnailUrl: 'assets/figma_home/gallery_pattern_1.png',
    description: '',
    boardSpec: '',
    tags: const [],
    difficulty: 0,
    width: 0,
    height: 0,
    colorCount: 0,
    isFree: true,
    creditCost: 0,
    downloadCount: 0,
    favoriteCount: 0,
    isFavorited: false,
  );
}
