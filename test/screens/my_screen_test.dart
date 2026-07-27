import 'dart:convert';

import 'package:bobobeads/screens/my_screen.dart';
import 'package:bobobeads/screens/upload_screen.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:flutter/material.dart';
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
    await tester.drag(myScrollView, const Offset(0, -100));
    await tester.pumpAndSettle();
    final myScrollOffset = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(myScrollOffset, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('my-make-nav-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-my-nav-item')));
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      closeTo(myScrollOffset, 0.01),
    );
  });

  testWidgets('点击我的图纸会进入图纸页', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-patterns-shortcut')));
    await tester.pumpAndSettle();

    expect(find.byType(MyPatternsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('my-pattern-gallery')), findsOneWidget);
  });

  testWidgets('点击我的图纸会请求我的作品列表', (tester) async {
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
          '/api/v1/templates/favorites' => {
            'templates': [
              {
                'templateId': 'favorite-newest',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                'isFavorited': true,
              },
              {
                'templateId': 'favorite-older',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_2.png',
                'isFavorited': true,
              },
            ],
            'page': {'total': 2, 'page': 1, 'pageSize': 3, 'hasMore': false},
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
    await tester.pumpAndSettle();

    final worksRequest = requests.singleWhere(
      (request) => request.url.path == '/api/v1/works',
    );
    expect(worksRequest.method, 'GET');
    final recentFavoritesRequest = requests.singleWhere(
      (request) => request.url.path == '/api/v1/templates/favorites',
    );
    expect(recentFavoritesRequest.url.queryParameters, {
      'page.page': '1',
      'page.pageSize': '3',
    });
    final newestFavorite = find.byKey(
      const ValueKey('recent-favorite-preview-favorite-newest'),
    );
    final olderFavorite = find.byKey(
      const ValueKey('recent-favorite-preview-favorite-older'),
    );
    expect(newestFavorite, findsOneWidget);
    expect(olderFavorite, findsOneWidget);
    expect(
      tester.getTopLeft(newestFavorite).dx,
      lessThan(tester.getTopLeft(olderFavorite).dx),
    );
    expect(
      find.byKey(const ValueKey('gallery-thumbnail-work-001')),
      findsOneWidget,
    );
  });

  testWidgets('点击我的收藏会进入收藏页', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-favorites-shortcut')));
    await tester.pumpAndSettle();

    expect(find.byType(MyFavoritesScreen), findsOneWidget);
    expect(find.text('盲盒图纸'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-pattern-gallery')), findsOneWidget);
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

      expect(find.text('最近收藏'), findsOneWidget);
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
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> saveSession(AuthSession session) async {
    _session = session;
  }
}
