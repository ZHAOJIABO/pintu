import 'dart:convert';

import 'package:bobobeads/screens/my_screen.dart';
import 'package:bobobeads/screens/settings_screen.dart';
import 'package:bobobeads/screens/style_conversion_screen.dart';
import 'package:bobobeads/screens/upload_screen.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:bobobeads/widgets/pattern_display_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _NavigationObserver extends NavigatorObserver {
  int pushCount = 0;
  int popCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
  }

  void reset() {
    pushCount = 0;
    popCount = 0;
  }
}

void main() {
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return '/tmp/bobobeads_test_image_cache';
        });
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

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
      expect(find.bySemanticsLabel('更多成品'), findsNothing);
      expect(
        find.byKey(const ValueKey('my-finished-products-title-icon')),
        findsOneWidget,
      );
      expect(find.text('咔嚓一下'), findsNWidgets(3));
      expect(
        find.byKey(const ValueKey('my-works-placeholder')),
        findsOneWidget,
      );
      expect(find.text('制作'), findsAtLeastNWidgets(1));
      expect(find.text('我的'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in viewports) {
    testWidgets('首页底部导航在 $viewport 原地切换我的内容', (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final navigatorObserver = _NavigationObserver();
      await tester.pumpWidget(
        MaterialApp(
          home: const UploadScreen(),
          navigatorObservers: [navigatorObserver],
        ),
      );
      await tester.pumpAndSettle();
      navigatorObserver.reset();

      final homeNavigationRect = tester.getRect(
        find.byKey(const ValueKey('bottom-nav-background')),
      );

      await tester.tap(find.byKey(const ValueKey('home-my-nav-item')));
      await tester.pump();
      expect(navigatorObserver.pushCount, 0);
      expect(navigatorObserver.popCount, 0);
      await tester.pumpAndSettle();
      expect(find.byType(MyScreen), findsNothing);
      expect(
        find.byKey(const ValueKey('my-patterns-shortcut')),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('my-bottom-nav-background'))),
        homeNavigationRect,
      );

      await tester.tap(find.byKey(const ValueKey('my-make-nav-item')));
      await tester.pump();
      expect(navigatorObserver.pushCount, 0);
      expect(navigatorObserver.popCount, 0);
      await tester.pumpAndSettle();
      expect(find.byType(MyScreen), findsNothing);
      expect(find.text('照片转图纸'), findsAtLeastNWidgets(1));
    });
  }

  testWidgets('页签切换保留我的页面滚动位置', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: UploadScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-my-nav-item')));
    await tester.pumpAndSettle();

    final myScrollView = find.byType(SingleChildScrollView);
    final myScrollable = find.descendant(
      of: myScrollView,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.drag(myScrollView, const Offset(0, -100));
    await tester.pumpAndSettle();
    final myScrollOffset = tester
        .state<ScrollableState>(myScrollable)
        .position
        .pixels;
    expect(myScrollOffset, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('my-make-nav-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-my-nav-item')));
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(myScrollable).position.pixels,
      closeTo(myScrollOffset, 0.01),
    );
  });

  testWidgets('点击设置会进入设置页并显示当前用户的 ID', (tester) async {
    final store = _MemoryApiSessionStore();
    await store.saveSession(
      const AuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresIn: 3600,
        user: ApiUser(
          userId: 'current-user-42',
          nickname: '',
          avatarUrl: '',
          phone: '',
          isVip: false,
        ),
      ),
    );
    final services = BackendServices(
      store: store,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/finished-products');
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            'items': const [],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: MyScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('设置'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('current-user-42'), findsOneWidget);
    expect(find.text('分享有礼'), findsNothing);
  });

  testWidgets('点击我的图纸会进入图纸页', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-patterns-shortcut')));
    await tester.pumpAndSettle();

    expect(find.byType(MyPatternsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('my-pattern-gallery')), findsOneWidget);
  });

  testWidgets('点击我的图纸会请求作品和全部最近创作任务', (tester) async {
    final requests = <http.Request>[];
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'cdn.example.test') {
          final image = await rootBundle.load(
            'assets/figma_home/gallery_pattern_1.png',
          );
          return http.Response.bytes(
            image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes),
            200,
            headers: const {'content-type': 'image/png'},
          );
        }
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
          '/api/v1/finished-products' => {'items': const []},
          '/api/v1/works' => {
            'data': {
              'works': [
                {
                  'workId': 'work-001',
                  'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                },
              ],
              'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
            },
          },
          '/api/v1/ai/style-generations'
              when request.url.queryParameters['page.page'] == '2' =>
            {
              'tasks': [
                {
                  'taskId': 'creation-older',
                  'status': 2,
                  'outputImageUrl': 'assets/figma_home/gallery_pattern_1.png',
                },
              ],
              'page': {'total': 3, 'page': 2, 'pageSize': 50, 'hasMore': false},
            },
          '/api/v1/ai/style-generations' => {
            'tasks': [
              {
                'taskId': 'creation-complete',
                'status': 2,
                'inputImageUrl': 'assets/figma_home/gallery_pattern_1.png',
                'outputImageUrl': 'assets/figma_home/gallery_pattern_2.png',
              },
              {
                'taskId': 'creation-running',
                'status': 1,
                'progress': 52,
                'startedAt': '1785209431',
                'inputImageUrl': 'assets/figma_home/gallery_pattern_3.png',
              },
            ],
            'page': {'total': 3, 'page': 1, 'pageSize': 50, 'hasMore': true},
          },
          '/api/v1/ai/style-generations/creation-running' => {
            'task': {
              'taskId': 'creation-running',
              'status': 2,
              'progress': 100,
              'startedAt': '1785209431',
              'outputImageUrl': 'https://cdn.example.test/creation-running.png',
              'completedAt': '1785209432',
            },
          },
          '/api/v1/templates' => {
            'templates': const [],
            'page': {'total': 0, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            ...body,
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: MyScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-patterns-shortcut')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    final worksRequest = requests.singleWhere(
      (request) => request.url.path == '/api/v1/works',
    );
    expect(worksRequest.method, 'GET');
    final recentCreationsRequests = requests
        .where((request) => request.url.path == '/api/v1/ai/style-generations')
        .toList();
    expect(
      recentCreationsRequests.map((request) => request.url.queryParameters),
      [
        {'page.page': '1', 'page.pageSize': '20'},
        {'page.page': '2', 'page.pageSize': '20'},
      ],
    );
    final completeCreation = find.byKey(
      const ValueKey('recent-creation-preview-creation-complete'),
    );
    final runningCreation = find.byKey(
      const ValueKey('recent-creation-preview-creation-running'),
    );
    expect(completeCreation, findsOneWidget);
    expect(runningCreation, findsOneWidget);
    expect(
      tester.getTopLeft(completeCreation).dx,
      lessThan(tester.getTopLeft(runningCreation).dx),
    );
    expect(
      find.byKey(const ValueKey('recent-creation-progress-creation-running')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('正在创作'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) =>
            request.url.path == '/api/v1/ai/style-generations/creation-running',
      ),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('recent-creation-progress-creation-running')),
      findsNothing,
    );
    expect(find.bySemanticsLabel('已完成创作'), findsWidgets);
    final newBadge = find.byKey(
      const ValueKey('recent-creation-new-badge-creation-running'),
    );
    expect(newBadge, findsOneWidget);
    expect(
      find.byKey(const ValueKey('gallery-thumbnail-work-001')),
      findsOneWidget,
    );
    await tester.tap(runningCreation);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(newBadge, findsNothing);
    expect(find.byType(StyleConversionScreen), findsOneWidget);
    expect(find.text('参数选择'), findsOneWidget);
    final styleScreen = tester.widget<StyleConversionScreen>(
      find.byType(StyleConversionScreen),
    );
    expect(styleScreen.initialConvertedImage, isNotEmpty);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.byType(MyPatternsScreen), findsOneWidget);
  });

  testWidgets('最近创作使用统一 Figma 图纸底图', (tester) async {
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
          '/api/v1/finished-products' => {'items': const []},
          '/api/v1/works' => {
            'data': {
              'works': const [],
              'page': {'total': 0, 'page': 1, 'pageSize': 20, 'hasMore': false},
            },
          },
          '/api/v1/ai/style-generations' => {
            'tasks': [
              {
                'taskId': 'network-creation',
                'status': AIGenerationItem.succeeded,
                'outputImageUrl': 'https://cdn.example.test/result.png',
              },
              {
                'taskId': 'empty-creation',
                'status': AIGenerationItem.failed,
                'inputImageUrl': '',
              },
            ],
            'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            ...body,
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: MyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('my-patterns-shortcut')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    for (final taskId in ['network-creation', 'empty-creation']) {
      final preview = find.byKey(ValueKey('recent-creation-preview-$taskId'));
      expect(
        find.descendant(
          of: preview,
          matching: find.byType(PatternDisplayPlaceholder),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('图纸列表滚动到底部时按每页二十条继续加载', (tester) async {
    final requests = <http.Request>[];
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        requests.add(request);
        final worksPage = request.url.queryParameters['page.page'] ?? '1';
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
          '/api/v1/finished-products' => {'items': const []},
          '/api/v1/works' when worksPage == '1' => {
            'data': {
              'works': List.generate(
                20,
                (index) => {
                  'workId': 'work-${index + 1}',
                  'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                },
              ),
              'page': {'total': 21, 'page': 1, 'pageSize': 20, 'hasMore': true},
            },
          },
          '/api/v1/works' when worksPage == '2' => {
            'data': {
              'works': [
                {
                  'workId': 'work-21',
                  'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                },
              ],
              'page': {
                'total': 21,
                'page': 2,
                'pageSize': 20,
                'hasMore': false,
              },
            },
          },
          '/api/v1/ai/style-generations' => {
            'tasks': const [],
            'page': {'total': 0, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            ...body,
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: MyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('my-patterns-shortcut')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    final workRequests = requests
        .where((request) => request.url.path == '/api/v1/works')
        .toList();
    expect(workRequests.map((request) => request.url.queryParameters), [
      {'page.page': '1', 'page.pageSize': '20'},
      {'page.page': '2', 'page.pageSize': '20'},
    ]);
    expect(
      find.byKey(const ValueKey('gallery-thumbnail-work-21')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('gallery-thumbnail-work-1')),
      findsOneWidget,
    );
  });

  testWidgets('重试创作失败后仍会重新加载最近创作任务', (tester) async {
    final requests = <http.Request>[];
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path ==
            '/api/v1/ai/style-generations/failed-creation/retry') {
          return http.Response(
            jsonEncode({
              'header': {'code': 9001, 'message': 'retry failed'},
            }),
            200,
          );
        }
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'user-1'},
          },
          '/api/v1/finished-products' => {'items': const []},
          '/api/v1/works' => {
            'data': {
              'works': const [],
              'page': {'total': 0, 'page': 1, 'pageSize': 20, 'hasMore': false},
            },
          },
          '/api/v1/ai/style-generations' => {
            'tasks': [
              {
                'taskId': 'failed-creation',
                'status': AIGenerationItem.failed,
                'inputImageUrl': '',
              },
            ],
            'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            ...body,
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: MyScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-patterns-shortcut')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('recent-creation-retry-failed-creation')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '重新生成'));
    await tester.pumpAndSettle();

    final listRequests = requests
        .where((request) => request.url.path == '/api/v1/ai/style-generations')
        .toList();
    expect(listRequests, hasLength(2));
    expect(
      listRequests.map((request) => request.url.queryParameters),
      everyElement({'page.page': '1', 'page.pageSize': '20'}),
    );
  });

  testWidgets('重试成功后立即用新任务替换失败创作', (tester) async {
    var retrySubmitted = false;
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        if (request.url.path ==
            '/api/v1/ai/style-generations/failed-creation/retry') {
          retrySubmitted = true;
          return http.Response(
            jsonEncode({
              'header': {'code': 0, 'message': 'success'},
              'taskId': 'retried-creation',
              'status': AIGenerationItem.running,
              'creditsDeducted': 1,
              'remainingBalance': 9,
              'duplicated': false,
            }),
            200,
          );
        }
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'user-1'},
          },
          '/api/v1/finished-products' => {'items': const []},
          '/api/v1/works' => {
            'data': {
              'works': const [],
              'page': {'total': 0, 'page': 1, 'pageSize': 20, 'hasMore': false},
            },
          },
          '/api/v1/ai/style-generations' => {
            'tasks': retrySubmitted
                ? [
                    {
                      'taskId': 'retried-creation',
                      'status': AIGenerationItem.running,
                      'inputImageUrl': '',
                    },
                  ]
                : [
                    {
                      'taskId': 'failed-creation',
                      'status': AIGenerationItem.failed,
                      'inputImageUrl': '',
                    },
                  ],
            'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          '/api/v1/ai/style-generations/retried-creation' => {
            'task': {
              'taskId': 'retried-creation',
              'status': AIGenerationItem.running,
              'inputImageUrl': '',
            },
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            ...body,
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: MyScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-patterns-shortcut')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('recent-creation-retry-failed-creation')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '重新生成'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('recent-creation-preview-failed-creation')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('recent-creation-preview-retried-creation')),
      findsOneWidget,
    );
  });

  testWidgets('点击我的收藏会进入收藏页', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-favorites-shortcut')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MyFavoritesScreen), findsOneWidget);
    expect(find.text('盲盒图纸'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-pattern-gallery')), findsOneWidget);
  });

  testWidgets('图纸与收藏在详情页左右互换且内容随标签切换', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyPatternsScreen()));
    await tester.pumpAndSettle();

    final patternsTab = find.text('我的图纸').first;
    final favoritesTab = find.text('我的收藏').first;
    expect(
      tester.getTopLeft(patternsTab).dx,
      lessThan(tester.getTopLeft(favoritesTab).dx),
    );
    expect(find.text('最近创作'), findsOneWidget);

    await tester.tap(favoritesTab);
    await tester.pumpAndSettle();

    expect(find.text('盲盒图纸'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-pattern-gallery')), findsOneWidget);
  });

  testWidgets('我的图纸页不显示分类筛选按钮', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyPatternsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('全部'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-gallery-filter')), findsNothing);
  });

  testWidgets('点击我的收藏会请求收藏模板和盲盒历史列表', (tester) async {
    final requests = <http.Request>[];
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
          '/api/v1/finished-products' => {'items': const []},
          '/api/v1/templates/favorites' => {
            'templates': [
              {
                'templateId': 'favorite-template-001',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                'isFavorited': true,
              },
            ],
            'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          '/api/v1/templates/random/history' => {
            'templates': [
              {
                'templateId': 'blind-box-newest',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
              },
              {
                'templateId': 'blind-box-older',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_2.png',
              },
            ],
            'page': {'total': 2, 'page': 1, 'pageSize': 3, 'hasMore': false},
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            ...body,
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: MyScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-favorites-shortcut')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    final favoritesRequest = requests.singleWhere(
      (request) => request.url.path == '/api/v1/templates/favorites',
    );
    expect(favoritesRequest.method, 'GET');
    expect(favoritesRequest.url.queryParameters, {
      'page.page': '1',
      'page.pageSize': '20',
    });
    final blindBoxHistoryRequest = requests.singleWhere(
      (request) => request.url.path == '/api/v1/templates/random/history',
    );
    expect(blindBoxHistoryRequest.method, 'GET');
    expect(blindBoxHistoryRequest.url.queryParameters, {
      'page.page': '1',
      'page.pageSize': '3',
    });
    final newestBlindBox = find.byKey(
      const ValueKey('blind-box-history-preview-blind-box-newest'),
    );
    final olderBlindBox = find.byKey(
      const ValueKey('blind-box-history-preview-blind-box-older'),
    );
    expect(newestBlindBox, findsOneWidget);
    expect(olderBlindBox, findsOneWidget);
    expect(
      tester.getTopLeft(newestBlindBox).dx,
      lessThan(tester.getTopLeft(olderBlindBox).dx),
    );
    expect(
      find.byKey(const ValueKey('gallery-thumbnail-favorite-template-001')),
      findsOneWidget,
    );
  });

  testWidgets('我的收藏可按收藏分类筛选', (tester) async {
    final requests = <http.Request>[];
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
          '/api/v1/templates/favorites/categories' => {
            'categories': [
              {
                'categoryId': 1,
                'name': '动物',
                'iconUrl': '',
                'templateCount': 1,
              },
            ],
          },
          '/api/v1/templates/favorites' => {
            'templates': [
              {
                'templateId': request.url.queryParameters['categoryId'] == '1'
                    ? 'favorite-animal-001'
                    : 'favorite-template-001',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                'isFavorited': true,
              },
            ],
            'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          '/api/v1/templates/random/history' => {
            'templates': const [],
            'page': {'total': 0, 'page': 1, 'pageSize': 3, 'hasMore': false},
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            ...body,
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: MyFavoritesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-filter-category-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('home-filter-category-1')));
    await tester.pumpAndSettle();

    final filteredRequest = requests.lastWhere(
      (request) =>
          request.url.path == '/api/v1/templates/favorites' &&
          request.url.queryParameters['categoryId'] == '1',
    );
    expect(filteredRequest.url.queryParameters, {
      'categoryId': '1',
      'page.page': '1',
      'page.pageSize': '20',
    });
    expect(
      find.byKey(const ValueKey('gallery-thumbnail-favorite-animal-001')),
      findsOneWidget,
    );
  });

  for (final viewport in viewports) {
    testWidgets('我的图纸页在 $viewport 下可滚动且无布局异常', (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: MyPatternsScreen()));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('最近创作'), findsOneWidget);
      expect(find.byKey(const ValueKey('my-pattern-gallery')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _MemoryApiSessionStore extends ApiSessionStore {
  AuthSession? _session;

  @override
  Future<String> readOrCreateDeviceId() async => 'device-1';

  @override
  Future<String> readOrCreateGuestCredential() async => 'guest-credential';

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> saveSession(AuthSession session) async {
    _session = session;
  }
}
