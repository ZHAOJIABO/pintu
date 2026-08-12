import 'dart:convert';

import 'package:bobobeads/screens/my_screen.dart';
import 'package:bobobeads/screens/result_screen.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('pending submissions show a badge and lock the work editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final services = BackendServices(
      baseUrl: 'http://api.example.test',
      store: _MemoryApiSessionStore(),
      httpClient: MockClient((request) async {
        final body = switch (request.url.path) {
          '/api/v1/auth/guest' => {
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
          '/api/v1/works' => {
            'works': [
              {
                'workId': '64',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
              },
            ],
            'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          '/api/v1/template-submissions' => {
            'items': [
              {'submissionId': '9', 'workId': '64', 'status': 0},
            ],
            'nextCursor': '',
          },
          '/api/v1/ai/style-generations' => {
            'tasks': const [],
            'page': {'total': 0, 'page': 1, 'pageSize': 20, 'hasMore': false},
          },
          '/api/v1/works/64' => {
            'work': {'workId': '64'},
            'patternData': {
              'width': 2,
              'height': 2,
              'boardSpec': '29x29',
              'pixels': [1, 1, 1, 1],
              'colorPalette': [
                {'index': 1, 'hex': '#000000', 'brand': 'MARD', 'code': 'H7'},
              ],
              'schemaVersion': 1,
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
        child: const MaterialApp(home: MyPatternsScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('gallery-review-pending-64')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('gallery-tile-64')));
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('审核中'), findsOneWidget);
  });
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
