import 'package:flutter/material.dart';

import '../services/api/api_models.dart';

/// The gallery already supplies the design's 12-point horizontal margin.
class HomeCategoryTabs extends StatelessWidget {
  final List<TemplateCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<TemplateCategory?> onSelected;

  const HomeCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('home-category-tabs'),
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tab(null),
            for (final category in categories) ...[
              const SizedBox(width: 4),
              _tab(category),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tab(TemplateCategory? category) {
    final selected = selectedCategoryId == category?.categoryId;
    return Semantics(
      key: ValueKey('home-category-tab-${category?.categoryId ?? 'all'}'),
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(category),
        child: SizedBox(
          height: 56,
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                category?.name ?? '全部',
                style: TextStyle(
                  fontFamily: 'Alimama FangYuanTi VF',
                  fontFamilyFallback: const [
                    'PingFang SC',
                    'Heiti SC',
                    'Microsoft YaHei',
                  ],
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: selected ? Colors.black : const Color(0x66000000),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
