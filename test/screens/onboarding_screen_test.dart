import 'package:bobobeads/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('继续按钮按顺序展示四页引导并在最后完成', (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onCompleted: () async {
            completed = true;
          },
        ),
      ),
    );

    expect(find.text('上传照片'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('图纸盲盒'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('拼豆成果'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('图纸编辑'), findsOneWidget);
    expect(find.text('4/4'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(completed, isTrue);
  });

  testWidgets('首次完成引导后会进入首页且记录完成状态', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: FirstLaunchGate(child: Scaffold(body: Text('首页'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('上传照片'), findsOneWidget);

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();
    }

    expect(find.text('首页'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(onboardingCompletedPreferenceKey), isTrue);
  });

  testWidgets('已完成引导的安装会直接进入首页', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      onboardingCompletedPreferenceKey: true,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: FirstLaunchGate(child: Scaffold(body: Text('首页'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('上传照片'), findsNothing);
  });
}
