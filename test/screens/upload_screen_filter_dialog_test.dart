import 'dart:async';

import 'package:bobobeads/main.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/widgets/home_filter_dialog.dart';
import 'package:flutter/material.dart';
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

  testWidgets('首页筛选按钮会打开符合设计稿尺寸的筛选弹窗', (tester) async {
    setViewport(tester);
    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('home-filter-dialog'));
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet), const Size(390, 480));
    expect(tester.getTopLeft(sheet).dy, 364);
    expect(find.text('筛选'), findsOneWidget);
    expect(find.text('暂无筛选分类'), findsOneWidget);
  });

  testWidgets('筛选弹窗可通过关闭按钮和遮罩关闭', (tester) async {
    setViewport(tester);
    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-filter-dialog-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-filter-dialog')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 120));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-filter-dialog')), findsNothing);
  });

  testWidgets('筛选弹窗以遮罩淡入和底部上滑出现与消失', (tester) async {
    setViewport(tester);
    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
    await tester.pump();
    await tester.pump();

    final fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('home-filter-dialog-backdrop-transition')),
    );
    final slide = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('home-filter-dialog-sheet-transition')),
    );
    final sheetFade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('home-filter-dialog-sheet-fade')),
    );
    final sheetScale = tester.widget<ScaleTransition>(
      find.byKey(const ValueKey('home-filter-dialog-sheet-scale')),
    );
    expect(fade.opacity.value, 0);
    expect(sheetFade.opacity.value, 0);
    expect(sheetScale.scale.value, closeTo(0.94, 0.001));
    expect(slide.position.value.dy, closeTo(0.035, 0.001));

    await tester.pump(const Duration(milliseconds: 140));
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    expect(sheetFade.opacity.value, greaterThan(0));
    expect(sheetFade.opacity.value, lessThan(1));
    expect(sheetScale.scale.value, greaterThan(0.94));
    expect(slide.position.value.dy, greaterThan(0));
    expect(slide.position.value.dy, lessThan(0.035));

    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
    expect(sheetFade.opacity.value, 1);
    expect(sheetScale.scale.value, 1);
    expect(slide.position.value.dy, 0);

    await tester.tap(find.byKey(const ValueKey('home-filter-dialog-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
    expect(sheetFade.opacity.value, greaterThan(0));
    expect(sheetFade.opacity.value, lessThan(1));
    expect(sheetScale.scale.value, lessThan(1));
    expect(slide.position.value.dy, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
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

  testWidgets('筛选弹窗可适配紧凑和大屏 iPhone', (tester) async {
    for (final config in const [
      (viewport: Size(375, 667), expectedSheetWidth: 375.0),
      (viewport: Size(430, 932), expectedSheetWidth: 390.0),
    ]) {
      tester.view.physicalSize = config.viewport;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(const BobobeadsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
      await tester.pumpAndSettle();

      expect(
        tester
            .getSize(find.byKey(const ValueKey('home-filter-dialog-boundary')))
            .width,
        closeTo(config.expectedSheetWidth, 0.01),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('home-filter-dialog-close')));
      await tester.pumpAndSettle();
    }
  });
}
