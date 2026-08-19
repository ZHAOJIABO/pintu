import 'dart:convert';

import 'package:bobobeads/screens/upload_screen.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

void main() {
  testWidgets('App 启动时预加载首张图纸与收藏缩略图', (tester) async {
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
          '/api/v1/works' => {
            'data': {
              'works': [
                {
                  'workId': 'work-1',
                  'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                },
              ],
              'page': {'page': 1, 'pageSize': 1, 'hasMore': false},
            },
          },
          '/api/v1/templates/favorites' => {
            'templates': [
              {
                'templateId': 'favorite-1',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_2.png',
              },
            ],
            'page': {'page': 1, 'pageSize': 1, 'hasMore': false},
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
        child: const MaterialApp(home: UploadScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(
      requests.where((request) => request.url.path == '/api/v1/works'),
      hasLength(1),
    );
    expect(
      requests
          .singleWhere((request) => request.url.path == '/api/v1/works')
          .url
          .queryParameters['page.pageSize'],
      '1',
    );
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/templates/favorites',
      ),
      hasLength(1),
    );
    expect(
      requests
          .singleWhere(
            (request) => request.url.path == '/api/v1/templates/favorites',
          )
          .url
          .queryParameters['page.pageSize'],
      '1',
    );
  });
}
