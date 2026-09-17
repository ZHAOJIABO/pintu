import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bobobeads/main.dart';

void main() {
  testWidgets('switching home and my page preserves one scroll attachment', (
    tester,
  ) async {
    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    scroll.position.jumpTo(150);
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('制作').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final controller = tester
          .widget<SingleChildScrollView>(
            find
                .byWidgetPredicate(
                  (widget) =>
                      widget is SingleChildScrollView &&
                      widget.scrollDirection == Axis.vertical,
                )
                .first,
          )
          .controller!;
      expect(controller.positions.length, 1);
      expect(controller.offset, 150);
    }
  });

  const viewports = {
    'iPhone SE 3': Size(375, 667),
    'iPhone 12': Size(390, 844),
    'Large iPhone': Size(430, 932),
  };

  for (final entry in viewports.entries) {
    group(
      'UploadScreen on ${entry.key} (${entry.value.width}x${entry.value.height})',
      () {
        testWidgets(
          'tabs pin below the safe area and return when scrolling back',
          (tester) async {
            tester.view.physicalSize = const Size(375, 667);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = FakeViewPadding(top: 47);
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              tester.view.resetPadding();
            });
            await tester.pumpWidget(const BobobeadsApp());
            await tester.pumpAndSettle();
            final tabs = find.byKey(const ValueKey('home-category-tabs'));
            final initialTop = tester.getTopLeft(tabs).dy;
            final scroll = tester.state<ScrollableState>(
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  )
                  .first,
            );
            scroll.position.jumpTo(450);
            await tester.pumpAndSettle();
            expect(tester.getTopLeft(tabs).dy, closeTo(47, 0.01));
            scroll.position.jumpTo(500);
            await tester.pumpAndSettle();
            expect(tester.getTopLeft(tabs).dy, closeTo(47, 0.01));
            expect(tabs, findsOneWidget);
            scroll.position.jumpTo(0);
            await tester.pumpAndSettle();
            expect(tester.getTopLeft(tabs).dy, closeTo(initialTop, 0.01));
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets('renders without overflow', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(const BobobeadsApp());
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('key text widgets are present', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(const BobobeadsApp());
          await tester.pumpAndSettle();

          expect(find.text('照片转图纸'), findsAtLeastNWidgets(1));
          expect(find.text('上传照片'), findsOneWidget);
          expect(find.text('全部'), findsOneWidget);
          expect(find.text('制作'), findsAtLeastNWidgets(1));
          expect(find.text('我的'), findsAtLeastNWidgets(1));
        });

        testWidgets('bottom nav labels are visible', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(const BobobeadsApp());
          await tester.pumpAndSettle();

          final makeLabel = find.text('制作');
          final myLabel = find.text('我的');
          expect(makeLabel, findsAtLeastNWidgets(1));
          expect(myLabel, findsAtLeastNWidgets(1));
        });
      },
    );
  }

  testWidgets('short viewport can scroll to reveal gallery content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();

    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.vertical,
    );
    expect(scrollable, findsOneWidget);

    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('wide viewport caps page width at 390', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();

    final scrollView = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.vertical,
    );
    final scrollViewBox = tester.getSize(scrollView);
    expect(scrollViewBox.width, lessThanOrEqualTo(390));
  });

  testWidgets('wide viewport keeps bottom nav at design height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();

    final navBackground = find.byKey(const ValueKey('bottom-nav-background'));
    expect(navBackground, findsOneWidget);

    final navBackgroundBox = tester.getSize(navBackground);
    expect(navBackgroundBox.width, closeTo(390, 0.01));
    expect(navBackgroundBox.height, closeTo(80, 0.01));
  });

  testWidgets('short viewport uses compact bottom nav height', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const BobobeadsApp());
    await tester.pumpAndSettle();

    final navBackground = find.byKey(const ValueKey('bottom-nav-background'));
    expect(navBackground, findsOneWidget);

    final navBackgroundBox = tester.getSize(navBackground);
    expect(navBackgroundBox.width, closeTo(390, 0.01));
    expect(navBackgroundBox.height, closeTo(60, 0.01));
  });
}
