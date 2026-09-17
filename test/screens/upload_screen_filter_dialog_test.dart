import 'dart:async';

import 'package:bobobeads/main.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/widgets/home_filter_dialog.dart';
import 'package:bobobeads/widgets/home_category_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(390, 844);

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('首页直接显示分类 Tab，不再显示筛选入口', (tester) async {
    setViewport(tester);
    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-category-tab-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-gallery-filter')), findsNothing);
    expect(find.byKey(const ValueKey('home-filter-dialog')), findsNothing);
  });

  testWidgets('分类加载失败后可重试并显示接口返回结果', (tester) async {
    setViewport(tester);
    var loadCount = 0;
    Future<List<TemplateCategory>> loadCategories() async {
      loadCount += 1;
      if (loadCount == 1) throw StateError('network unavailable');
      return const [
        TemplateCategory(
          categoryId: 7,
          name: '动物',
          iconUrl: '',
          templateCount: 3,
        ),
      ];
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showHomeFilterDialog(context, loadCategories: loadCategories),
            child: const Text('打开筛选'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开筛选'));
    await tester.pumpAndSettle();
    expect(find.text('分类加载失败，点击重试'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-filter-dialog-retry')));
    await tester.pumpAndSettle();
    expect(find.text('动物'), findsOneWidget);
    expect(loadCount, 2);
  });

  testWidgets('分类加载中显示加载状态，空接口结果显示空状态', (tester) async {
    setViewport(tester);
    final categories = Completer<List<TemplateCategory>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showHomeFilterDialog(
              context,
              loadCategories: () => categories.future,
            ),
            child: const Text('打开筛选'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开筛选'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    categories.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('暂无筛选分类'), findsOneWidget);
  });

  testWidgets('选择未选中分类后返回所选分类', (tester) async {
    setViewport(tester);
    HomeFilterSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selection = await showHomeFilterDialog(
                context,
                loadCategories: () async => const [
                  TemplateCategory(
                    categoryId: 7,
                    name: '动物',
                    iconUrl: '',
                    templateCount: 3,
                  ),
                ],
              );
            },
            child: const Text('打开筛选'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-filter-category-7')));
    await tester.pumpAndSettle();

    expect(selection?.category.categoryId, 7);
    expect(selection?.category.name, '动物');
    expect(selection?.isDefault, isFalse);
    expect(find.byKey(const ValueKey('home-filter-dialog')), findsNothing);
  });

  testWidgets('已选分类显示选中态，再次点击会清空筛选', (tester) async {
    setViewport(tester);
    HomeFilterSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selection = await showHomeFilterDialog(
                context,
                selectedCategoryId: 7,
                loadCategories: () async => const [
                  TemplateCategory(
                    categoryId: 7,
                    name: '动物',
                    iconUrl: '',
                    templateCount: 3,
                  ),
                ],
              );
            },
            child: const Text('打开筛选'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开筛选'));
    await tester.pumpAndSettle();

    final category = find.byKey(const ValueKey('home-filter-category-7'));
    expect(
      tester.getSemantics(category).hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );

    await tester.tap(category);
    await tester.pumpAndSettle();

    expect(selection?.isDefault, isTrue);
  });

  testWidgets('长分类名称会在标签内单行省略', (tester) async {
    setViewport(tester);
    const name = '这是一个超过筛选标签宽度的很长很长分类名称';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showHomeFilterDialog(
              context,
              loadCategories: () async => const [
                TemplateCategory(
                  categoryId: 7,
                  name: name,
                  iconUrl: '',
                  templateCount: 1,
                ),
              ],
            ),
            child: const Text('打开筛选'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开筛选'));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text(name));
    expect(label.maxLines, 1);
    expect(label.softWrap, isFalse);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分类 Tab 在紧凑和大屏上可横向滚动至末项并切换', (tester) async {
    for (final width in [320.0, 430.0]) {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      int? selected;
      final categories = [
        for (final (index, name) in [
          '可爱',
          '动漫',
          '抽象',
          '艺术',
          '实用',
          '游戏',
          '万能配饰',
        ].indexed)
          TemplateCategory(
            categoryId: index + 1,
            name: name,
            iconUrl: '',
            templateCount: 0,
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: HomeCategoryTabs(
                categories: categories,
                selectedCategoryId: null,
                onSelected: (category) => selected = category?.categoryId,
              ),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey('home-category-tabs')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('万能配饰'));
      expect(selected, 7);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
