import 'package:bobobeads/widgets/home_pattern_gallery.dart';
import 'package:bobobeads/widgets/pattern_display_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('图纸缩略图为空时显示统一 Figma 占位图', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePatternGallery(
            templates: const [],
            items: const [
              PatternGalleryItem(id: 'empty-work', thumbnailUrl: ''),
            ],
            categoryName: '我的图纸',
            onFilter: () {},
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('gallery-thumbnail-empty-work')),
        matching: find.byType(PatternDisplayPlaceholder),
      ),
      findsOneWidget,
    );
  });

  testWidgets('图纸缩略图可用时不在图片下方保留占位图', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePatternGallery(
            templates: const [],
            items: const [
              PatternGalleryItem(
                id: 'available-work',
                thumbnailUrl: 'assets/figma_home/gallery_pattern_1.png',
              ),
            ],
            categoryName: '我的图纸',
            onFilter: () {},
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('gallery-thumbnail-available-work')),
        matching: find.byType(PatternDisplayPlaceholder),
      ),
      findsNothing,
    );
  });
}
