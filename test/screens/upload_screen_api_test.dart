import 'dart:convert';

import 'package:bobobeads/screens/upload_screen.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:bobobeads/services/api/vendor_identifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('首页图纸和筛选分类均从 API 加载', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
          '/api/v1/system/config' => <String, Object?>{},
          '/api/v1/system/board-specs' => {'specs': const []},
          '/api/v1/system/bead-colors' => {'brands': const []},
          '/api/v1/templates/categories' => {
            'categories': [
              {
                'categoryId': 7,
                'name': '动物',
                'iconUrl': '',
                'templateCount': 3,
              },
              {
                'categoryId': 9,
                'name': '节日',
                'iconUrl': '',
                'templateCount': 2,
              },
            ],
          },
          '/api/v1/templates' => {
            'templates': [
              {
                'templateId': 'template-001',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
              },
            ],
            'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          '/api/v1/templates/template-001' => {
            'template': {'templateId': 'template-001'},
            'patternData': {
              'width': 2,
              'height': 2,
              'boardSpec': '2x2',
              'pixels': [1, 2, 0, 1],
              'colorPalette': [
                {
                  'index': 1,
                  'hex': '#ff2850',
                  'brand': 'mard',
                  'code': 'A01',
                  'name': '红色',
                },
                {
                  'index': 2,
                  'hex': '#000000',
                  'brand': 'mard',
                  'code': 'A02',
                  'name': '黑色',
                },
              ],
            },
          },
          '/api/v1/templates/random/quota' => {
            'quota': {
              'dailyLimit': 1,
              'used': 0,
              'remaining': 1,
              'resetAt': '1755792000',
            },
          },
          '/api/v1/templates/random' => {
            'template': {
              'templateId': 'template-random',
              'title': '随机小熊',
              'previewUrl': 'https://example.test/random-preview.png',
              'thumbnailUrl': 'https://example.test/random-thumbnail.png',
            },
            'patternData': {
              'width': 2,
              'height': 2,
              'boardSpec': '2x2',
              'pixels': [1, 2, 0, 1],
              'colorPalette': [
                {
                  'index': 1,
                  'hex': '#ff2850',
                  'brand': 'mard',
                  'code': 'A01',
                  'name': '红色',
                },
                {
                  'index': 2,
                  'hex': '#000000',
                  'brand': 'mard',
                  'code': 'A02',
                  'name': '黑色',
                },
              ],
            },
            'quota': {
              'dailyLimit': 1,
              'used': 1,
              'remaining': 0,
              'resetAt': '1755792000',
            },
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'header': {'code': 0, 'message': 'success'},
              ...body,
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await services.loadHomeTemplates();

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: UploadScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('今日剩余 1 次'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-blind-box-card')));
    await tester.pump(const Duration(seconds: 2));

    final blindBoxRequest = requests.lastWhere(
      (request) => request.url.path == '/api/v1/templates/random',
    );
    expect(blindBoxRequest.method, 'GET');
    expect(jsonDecode(blindBoxRequest.body), {'header': {}});
    expect(find.byKey(const ValueKey('blind-box-dialog')), findsOneWidget);
    expect(find.textContaining('恢复'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('blind-box-template-preview')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('blind-box-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-filter-category-7')),
      findsOneWidget,
    );
    expect(find.text('节日'), findsOneWidget);
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/templates/categories',
      ),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('home-filter-category-7')));
    await tester.pumpAndSettle();

    final filteredTemplateRequest = requests.lastWhere(
      (request) =>
          request.url.path == '/api/v1/templates' &&
          request.url.queryParameters['categoryId'] == '7',
    );
    expect(filteredTemplateRequest.url.queryParameters['scene'], 'home');
    expect(find.byKey(const ValueKey('home-filter-dialog')), findsNothing);
    expect(find.byKey(const ValueKey('home-gallery-category')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-gallery-category')))
          .data,
      '动物',
    );

    await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-filter-category-7')),
      findsOneWidget,
    );
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/templates/categories',
      ),
      hasLength(1),
    );
    final selectedCategory = find.byKey(
      const ValueKey('home-filter-category-7'),
    );
    expect(
      tester.getSemantics(selectedCategory).hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );
    final templateRequestCountBeforeClearing = requests
        .where((request) => request.url.path == '/api/v1/templates')
        .length;
    await tester.tap(selectedCategory);
    await tester.pumpAndSettle();

    // The unfiltered home response is cached, so clearing a category reuses it
    // instead of issuing another category-specific request.
    expect(
      requests.where((request) => request.url.path == '/api/v1/templates'),
      hasLength(templateRequestCountBeforeClearing),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-gallery-category')))
          .data,
      '全部',
    );

    expect(
      find.byKey(const ValueKey('gallery-thumbnail-template-001')),
      findsOneWidget,
    );
    final galleryTile = find.ancestor(
      of: find.byKey(const ValueKey('gallery-thumbnail-template-001')).first,
      matching: find.byType(GestureDetector),
    );
    await tester.tap(galleryTile.first);
    await tester.pumpAndSettle();

    expect(
      requests.where((request) => request.url.path == '/api/v1/templates'),
      hasLength(2),
    );
    expect(
      requests.where((request) => request.url.path == '/api/v1/auth/guest'),
      hasLength(1),
    );
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/templates/template-001',
      ),
      hasLength(1),
    );
    expect(find.text('图纸'), findsOneWidget);
  });

  testWidgets('首页图纸滚动接近底部时追加加载下一页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final requests = <http.Request>[];
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        requests.add(request);
        final page =
            int.tryParse(request.url.queryParameters['page.page'] ?? '1') ?? 1;
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
          '/api/v1/templates' => {
            'templates': page == 1
                ? List.generate(
                    20,
                    (index) => {
                      'templateId': 'template-${index + 1}',
                      'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                    },
                  )
                : [
                    {
                      'templateId': 'template-21',
                      'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                    },
                  ],
            'page': {
              'total': 21,
              'page': page,
              'pageSize': 20,
              'hasMore': page == 1,
            },
          },
          '/api/v1/templates/random/quota' => {
            'quota': {
              'dailyLimit': 1,
              'used': 0,
              'remaining': 1,
              'resetAt': '1755792000',
            },
          },
          _ => <String, Object?>{},
        };
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'header': {'code': 0, 'message': 'success'},
              ...body,
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: UploadScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('gallery-thumbnail-template-20')),
      findsOneWidget,
    );
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(
      requests
          .where((request) => request.url.path == '/api/v1/templates')
          .map((request) => request.url.queryParameters['page.page']),
      containsAllInOrder(['1', '2']),
    );
    expect(
      find.byKey(const ValueKey('gallery-thumbnail-template-21')),
      findsOneWidget,
    );
  });

  testWidgets('盲盒 2007 显示中文次数用完提示且不重试抽取', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
          '/api/v1/templates' => {
            'templates': const [],
            'page': {'total': 0, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          '/api/v1/templates/random/quota' => {
            'quota': {
              'dailyLimit': 1,
              'used': 0,
              'remaining': 1,
              'resetAt': '1755792000',
            },
          },
          _ => <String, Object?>{},
        };
        final header = request.url.path == '/api/v1/templates/random'
            ? {
                'code': 2007,
                'message': 'daily blind box quota used up: limit 1',
              }
            : {'code': 0, 'message': 'success'};
        return http.Response.bytes(
          utf8.encode(jsonEncode({'header': header, ...body})),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await services.loadHomeTemplates();

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: UploadScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日剩余 1 次'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-blind-box-card')));
    await tester.pumpAndSettle();

    expect(find.text('今日盲盒次数已用完，明天再来吧'), findsOneWidget);
    expect(find.textContaining('今日剩余 0 次'), findsOneWidget);
    expect(find.textContaining('恢复'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-blind-box-card')));
    await tester.pump();
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/templates/random',
      ),
      hasLength(1),
    );
  });
}

class _MemoryApiSessionStore extends ApiSessionStore {
  AuthSession? _session;

  @override
  Future<DeviceInfo> readDeviceInfo() async => const DeviceInfo();

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
