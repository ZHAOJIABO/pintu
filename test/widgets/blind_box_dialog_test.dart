import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/widgets/blind_box_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reward = BlindBoxReward(
    patternAsset: 'assets/figma_home/blind_box/rabbit_pattern.jpg',
    rarity: BlindBoxRarity.superRare,
    titleIconAsset: 'assets/figma_home/blind_box/union.png',
    patternBadgeAsset: 'assets/figma_home/blind_box/badge.png',
  );
  const rareTemplate = TemplateItem(
    templateId: 'rare-template',
    categoryName: '稀有',
    title: '稀有图纸',
    previewUrl: '',
    thumbnailUrl: '',
    description: '',
    boardSpec: '',
    tags: [],
    difficulty: 1,
    width: 20,
    height: 20,
    colorCount: 3,
    isFree: true,
    creditCost: 0,
    downloadCount: 0,
    favoriteCount: 0,
    isFavorited: false,
  );

  testWidgets('稀有盲盒标题避开 SSR 装饰并让按钮避开安全区', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: 34),
            disableAnimations: true,
          ),
          child: BlindBoxDialog(rewards: [reward], template: rareTemplate),
        ),
      ),
    );
    await tester.pump();

    final titleRect = tester.getRect(
      find.byKey(const ValueKey('blind-box-rarity-title')),
    );
    final iconRect = tester.getRect(
      find.byKey(const ValueKey('blind-box-title-icon')),
    );
    final acceptRect = tester.getRect(
      find.byKey(const ValueKey('blind-box-accept')),
    );

    expect(find.text('超稀有'), findsNWidgets(2));
    expect(titleRect.right, lessThanOrEqualTo(iconRect.left - 8));
    expect(acceptRect.bottom, lessThanOrEqualTo(810));
  });

  for (final categoryName in const ['稀有', '有趣', '可爱', '抽象']) {
    testWidgets('$categoryName 盲盒标题不会与分类装饰重叠', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlindBoxDialog(
              rewards: const [reward],
              template: rareTemplate.copyWith(categoryName: categoryName),
            ),
          ),
        ),
      );
      await tester.pump();

      final titleRect = tester.getRect(
        find.byKey(const ValueKey('blind-box-rarity-title')),
      );
      final iconRect = tester.getRect(
        find.byKey(const ValueKey('blind-box-title-icon')),
      );

      expect(titleRect.right, lessThanOrEqualTo(iconRect.left - 8));
    });
  }
}
