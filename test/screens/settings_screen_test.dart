import 'dart:convert';

import 'package:bobobeads/screens/settings_screen.dart';
import 'package:bobobeads/screens/upload_pattern_screen.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const viewports = [Size(375, 667), Size(390, 844), Size(430, 932)];

  testWidgets('settings displays the upload-pattern entry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('我要传图纸'), findsOneWidget);
    expect(
      tester.getCenter(find.text('我要传图纸')).dy,
      greaterThan(tester.getCenter(find.text('当前版本')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping rate requests an in-app review', (tester) async {
    var reviewRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          requestAppReview: () async {
            reviewRequested = true;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('settings-rate-app')));
    await tester.pump();

    expect(reviewRequested, isTrue);
  });

  testWidgets('clearing cache requires confirmation and invokes cleaner', (
    tester,
  ) async {
    var clearCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          clearAppCache: (_) async {
            clearCount += 1;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('settings-clear-cache')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('清除缓存'),
      ),
      findsOneWidget,
    );
    expect(clearCount, 0);

    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();

    expect(clearCount, 1);
    expect(find.text('缓存已清除'), findsOneWidget);
  });

  testWidgets('tapping privacy policy opens appbobo website', (tester) async {
    Uri? openedUrl;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          launchExternalUrl: (url) async {
            openedUrl = url;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('settings-privacy-policy')));
    await tester.pump();

    expect(openedUrl, Uri.parse('https://appbobo.cn/privacy'));
  });

  testWidgets('tapping terms and about opens their appbobo pages', (
    tester,
  ) async {
    final openedUrls = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          launchExternalUrl: (url) async {
            openedUrls.add(url);
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('settings-user-agreement')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-about')));
    await tester.pump();

    expect(openedUrls, [
      Uri.parse('https://appbobo.cn/terms'),
      Uri.parse('https://appbobo.cn/about'),
    ]);
  });

  testWidgets('upload-pattern page loads works and pending submissions', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final store = _MemoryApiSessionStore();
    await store.saveSession(
      AuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresIn: 3600,
        accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: ApiUser(
          userId: 'guest-1',
          nickname: '',
          avatarUrl: '',
          phone: '',
          isVip: false,
        ),
      ),
    );
    final services = BackendServices(
      baseUrl: 'http://example.test',
      store: store,
      httpClient: MockClient((request) async {
        requests.add(request);
        final Map<String, dynamic> body;
        if (request.url.path == '/api/v1/works') {
          body = {
            'works': [
              {
                'workId': 'work-1',
                'title': '我的小兔',
                'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
              },
            ],
            'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
          };
        } else if (request.url.path == '/api/v1/template-submissions') {
          body = request.method == 'POST'
              ? {
                  'item': {
                    'submissionId': 'submission-2',
                    'workId': 'work-1',
                    'title': '我的小兔',
                    'status': 0,
                    'thumbnailUrl': 'assets/figma_home/gallery_pattern_1.png',
                    'createdAt': 1790000100,
                  },
                }
              : {
                  'items': [
                    {
                      'submissionId': 'submission-1',
                      'workId': 'older-work',
                      'title': '待审核图纸',
                      'status': 0,
                      'thumbnailUrl': 'assets/figma_home/gallery_pattern_2.png',
                      'createdAt': 1790000000,
                    },
                  ],
                  'nextCursor': '',
                };
        } else {
          throw StateError('Unexpected request: ${request.url}');
        }
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
    await services.works.listWorks();
    requests.clear();

    await tester.pumpWidget(
      BackendScope(
        services: services,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('settings-upload-pattern')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(UploadPatternScreen), findsOneWidget);
    expect(find.text('确定上传'), findsOneWidget);
    expect(
      requests.where((request) => request.url.path == '/api/v1/works'),
      hasLength(1),
    );
    expect(
      requests.where(
        (request) =>
            request.url.path == '/api/v1/template-submissions' &&
            request.method == 'GET',
      ),
      hasLength(1),
    );
    expect(
      find.byKey(const ValueKey('upload-pattern-work-work-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('upload-pattern-empty-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('upload-pattern-empty-8')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('upload-pattern-grid-card'))),
      const Size(350, 350),
    );
    expect(
      find.byKey(const ValueKey('upload-pattern-pending-review')),
      findsOneWidget,
    );
    expect(find.text('努力审核中'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('upload-pattern-work-work-1')));
    await tester.pump();
    final selectedTile = tester.widget<Container>(
      find.byKey(const ValueKey('upload-pattern-work-work-1')),
    );
    final selectedBorder =
        (selectedTile.foregroundDecoration as BoxDecoration).border! as Border;
    expect(selectedBorder.top.color, Colors.black);
    expect(selectedBorder.top.width, 2);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('upload-pattern-confirm')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('upload-pattern-confirm')));
    await tester.pump();
    await tester.pump();
    final submissionRequest = requests.singleWhere(
      (request) =>
          request.url.path == '/api/v1/template-submissions' &&
          request.method == 'POST',
    );
    final submissionBody =
        jsonDecode(submissionRequest.body) as Map<String, dynamic>;
    expect(submissionBody['workId'], 'work-1');
    expect(submissionBody['title'], '我的小兔');
    expect(submissionBody['description'], '');
    expect(submissionBody['clientRequestId'], isNotEmpty);
    expect(find.text('已提交，等待审核'), findsOneWidget);
  });

  for (final viewport in viewports) {
    testWidgets('upload-pattern page renders at $viewport', (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: UploadPatternScreen()));
      await tester.pumpAndSettle();

      expect(find.text('确定上传'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('upload-pattern-confirm')),
            )
            .onPressed,
        isNull,
      );
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
