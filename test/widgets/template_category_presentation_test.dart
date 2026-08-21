import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/widgets/template_category_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const item = TemplateItem(
    templateId: 'template-1',
    categoryId: 9876,
    categoryName: '运营新分类',
    title: '新图纸',
    previewUrl: '',
    thumbnailUrl: '',
    description: '',
    boardSpec: '',
    tags: [],
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

  test('TemplateItem parses the new category fields', () {
    final parsed = TemplateItem.fromJson({
      'templateId': 'template-1',
      'categoryId': 9876,
      'categoryName': '运营新分类',
    });

    expect(parsed.categoryId, 9876);
    expect(parsed.categoryName, '运营新分类');
    expect(parsed.copyWith().categoryId, 9876);
    expect(parsed.copyWith().categoryName, '运营新分类');
    expect(parsed.copyWith(categoryId: 3).categoryId, 3);
    expect(parsed.copyWith(categoryName: '可爱').categoryName, '可爱');
  });

  test('unknown category uses the default rare treatment', () {
    final presentation = TemplateCategoryPresentations.resolve(item);

    expect(presentation.displayCopy(item.categoryName, fallback: '超稀有'), '超稀有');
    expect(presentation.patternAsset, isNull);
  });

  test('blind-box rarity category names use the approved copy', () {
    expect(
      TemplateCategoryPresentations.resolve(
        item.copyWith(categoryName: '稀有'),
      ).displayCopy('稀有', fallback: '盲盒图纸'),
      '超稀有',
    );
    expect(
      TemplateCategoryPresentations.resolve(
        item.copyWith(categoryName: '有趣'),
      ).displayCopy('有趣', fallback: '盲盒图纸'),
      '超有趣',
    );
    final fun = TemplateCategoryPresentations.resolve(
      item.copyWith(categoryName: '有趣'),
    );
    expect(
      fun.titleIconAsset,
      'assets/figma_home/blind_box/title_super_fun_icon.svg',
    );
    expect(fun.titleGradientEndColor, 0xFFFFE100);
    expect(fun.titleIconLeft, 213.35);
    expect(fun.badgeAsset, 'assets/figma_home/blind_box/badge_super_fun.svg');
    expect(fun.badgeAssetLeft, 16.18);
    expect(fun.badgeAssetTop, 0.96);
    final cute = TemplateCategoryPresentations.resolve(
      item.copyWith(categoryName: '可爱'),
    );
    expect(cute.displayCopy('可爱', fallback: '盲盒图纸'), '超可爱');
    expect(
      cute.titleIconAsset,
      'assets/figma_home/blind_box/title_super_cute_heart.png',
    );
    expect(
      cute.badgeHeartAsset,
      'assets/figma_home/blind_box/badge_super_cute_heart.png',
    );
    expect(cute.badgeOffsetY, 15);
    expect(cute.titleGradientEndColor, 0xFFFF7AC7);
    expect(cute.titleIconLeft, 198.0955);
    expect(cute.titleIconTop, 0.9305);
    expect(cute.titleIconAngleDegrees, 23.7);
    expect(cute.titleIconFill, isTrue);
    expect(cute.titleIconOutlineScale, 1.30);
    final abstract = TemplateCategoryPresentations.resolve(
      item.copyWith(categoryName: '抽象'),
    );
    expect(abstract.displayCopy('抽象', fallback: '盲盒图纸'), '超抽象');
    expect(
      abstract.badgeAsset,
      'assets/figma_home/blind_box/badge_super_abstract.svg',
    );
    expect(
      abstract.titleIconAsset,
      'assets/figma_home/blind_box/title_super_abstract_character.svg',
    );
    expect(abstract.titleGradientEndColor, 0xFF7AFFF4);
    expect(abstract.titleIconLeft, 210.217);
    expect(abstract.titleIconTop, -0.17);
    expect(abstract.titleIconFill, isTrue);
    expect(abstract.titleIconFlipX, isTrue);
  });

  test('empty category name also uses the default rare treatment', () {
    const unknown = TemplateItem(
      templateId: 'template-2',
      title: '未分类图纸',
      previewUrl: '',
      thumbnailUrl: '',
      description: '',
      boardSpec: '',
      tags: [],
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

    final presentation = TemplateCategoryPresentations.resolve(unknown);

    expect(
      presentation.displayCopy(unknown.categoryName, fallback: '超稀有'),
      '超稀有',
    );
  });
}
