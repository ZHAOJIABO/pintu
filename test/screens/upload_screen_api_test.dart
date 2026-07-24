import 'dart:convert';

import 'package:bobobeads/screens/upload_screen.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:flutter/material.dart';
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

    await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
    await tester.pumpAndSettle();

    expect(find.text('动物'), findsOneWidget);
    expect(find.text('节日'), findsOneWidget);
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/templates/categories',
      ),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('home-filter-dialog-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-gallery-filter')));
    await tester.pumpAndSettle();
    expect(find.text('动物'), findsOneWidget);
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/templates/categories',
      ),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('home-filter-dialog-close')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('gallery-thumbnail-template-001')),
      findsNWidgets(15),
    );
    final galleryTile = find.ancestor(
      of: find.byKey(const ValueKey('gallery-thumbnail-template-001')).first,
      matching: find.byType(GestureDetector),
    );
    await tester.tap(galleryTile.first);
    await tester.pumpAndSettle();

    expect(
      requests.where((request) => request.url.path == '/api/v1/templates'),
      hasLength(1),
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
