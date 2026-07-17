import 'package:bobobeads/main.dart';
import 'package:bobobeads/screens/my_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewports = [Size(375, 667), Size(390, 844), Size(430, 932)];

  for (final viewport in viewports) {
    testWidgets('我的页面在 $viewport 下无布局异常', (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: MyScreen()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('my-patterns-shortcut')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('my-favorites-shortcut')),
        findsOneWidget,
      );
      expect(find.text('我的成品'), findsOneWidget);
      expect(find.text('记录一下'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('my-works-placeholder')),
        findsOneWidget,
      );
      expect(find.text('制作'), findsAtLeastNWidgets(1));
      expect(find.text('我的'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('首页底部导航可进入并返回我的页面', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-my-nav-item')));
    await tester.pumpAndSettle();
    expect(find.byType(MyScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('my-make-nav-item')));
    await tester.pumpAndSettle();
    expect(find.byType(MyScreen), findsNothing);
  });
}
