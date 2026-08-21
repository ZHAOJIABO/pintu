import '../services/api/api_models.dart';

/// A local visual/copy treatment for a server-side template category.
///
/// Keep category IDs in the environment-specific tables below. They are
/// database auto-increment values, so IDs must be confirmed independently for
/// each environment rather than copied from test to production.
class TemplateCategoryPresentation {
  final String? patternAsset;
  final String? copy;
  final String? titleIconAsset;
  final String? badgeAsset;
  final double? badgeAssetLeft;
  final double? badgeAssetTop;
  final double? badgeAssetWidth;
  final double? badgeAssetHeight;
  final String? badgeHeartAsset;
  final double badgeOffsetY;
  final int? titleGradientEndColor;
  final double? titleIconLeft;
  final double? titleIconTop;
  final double? titleIconWidth;
  final double? titleIconHeight;
  final double? titleIconAngleDegrees;
  final bool titleIconFill;
  final bool titleIconFlipX;
  final double titleIconOutlineScale;

  const TemplateCategoryPresentation({
    this.patternAsset,
    this.copy,
    this.titleIconAsset,
    this.badgeAsset,
    this.badgeAssetLeft,
    this.badgeAssetTop,
    this.badgeAssetWidth,
    this.badgeAssetHeight,
    this.badgeHeartAsset,
    this.badgeOffsetY = 0,
    this.titleGradientEndColor,
    this.titleIconLeft,
    this.titleIconTop,
    this.titleIconWidth,
    this.titleIconHeight,
    this.titleIconAngleDegrees,
    this.titleIconFill = false,
    this.titleIconFlipX = false,
    this.titleIconOutlineScale = 1,
  });

  String displayCopy(String categoryName, {required String fallback}) {
    final localCopy = copy?.trim() ?? '';
    if (localCopy.isNotEmpty) return localCopy;

    return fallback;
  }
}

/// Resolves an optional local asset and copy for template categories.
///
/// The tables intentionally start empty: no confirmed environment category IDs
/// are available in this client repository. Add entries only after the backend
/// or operations team confirms the IDs for that exact environment. Unknown
/// categories use the default rarity presentation.
class TemplateCategoryPresentations {
  static const _environment = String.fromEnvironment(
    'BOBOBEADS_APP_ENV',
    defaultValue: 'development',
  );

  static const Map<int, TemplateCategoryPresentation> _testById = {};
  static const Map<int, TemplateCategoryPresentation> _productionById = {};
  static const Map<String, TemplateCategoryPresentation> _byCategoryName = {
    '稀有': TemplateCategoryPresentation(copy: '超稀有'),
    '有趣': TemplateCategoryPresentation(
      copy: '超有趣',
      titleIconAsset: 'assets/figma_home/blind_box/title_super_fun_icon.svg',
      badgeAsset: 'assets/figma_home/blind_box/badge_super_fun.svg',
      badgeAssetLeft: 16.18,
      badgeAssetTop: 0.96,
      badgeAssetWidth: 37.6405,
      badgeAssetHeight: 38.0677,
      titleGradientEndColor: 0xFFFFE100,
      titleIconLeft: 213.35,
      titleIconTop: 7.5,
      titleIconWidth: 25.1262,
      titleIconHeight: 24.1858,
      titleIconFill: true,
    ),
    '可爱': TemplateCategoryPresentation(
      copy: '超可爱',
      titleIconAsset: 'assets/figma_home/blind_box/title_super_cute_heart.png',
      badgeHeartAsset: 'assets/figma_home/blind_box/badge_super_cute_heart.png',
      badgeOffsetY: 15,
      titleGradientEndColor: 0xFFFF7AC7,
      titleIconLeft: 198.0955,
      titleIconTop: 0.9305,
      titleIconWidth: 39.215,
      titleIconHeight: 35.37,
      titleIconAngleDegrees: 23.7,
      titleIconFill: true,
      titleIconOutlineScale: 1.30,
    ),
    '抽象': TemplateCategoryPresentation(
      copy: '超抽象',
      titleIconAsset:
          'assets/figma_home/blind_box/title_super_abstract_character.svg',
      badgeAsset: 'assets/figma_home/blind_box/badge_super_abstract.svg',
      titleGradientEndColor: 0xFF7AFFF4,
      titleIconLeft: 210.217,
      titleIconTop: -0.17,
      titleIconWidth: 31.0165,
      titleIconHeight: 55.8743,
      titleIconFill: true,
      titleIconFlipX: true,
    ),
  };

  static TemplateCategoryPresentation resolve(TemplateItem template) {
    final byId = switch (_environment) {
      'production' => _productionById,
      _ => _testById,
    };
    return byId[template.categoryId] ??
        _byCategoryName[template.categoryName.trim()] ??
        const TemplateCategoryPresentation();
  }
}
