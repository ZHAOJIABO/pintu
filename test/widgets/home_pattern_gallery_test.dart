import 'package:bobobeads/widgets/home_pattern_gallery.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

TemplateItem _template({required String id, String authorName = ''}) {
  return TemplateItem(
    templateId: id,
    title: '',
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
