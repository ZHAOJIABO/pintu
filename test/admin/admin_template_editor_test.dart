import 'dart:convert';

import 'package:bobobeads/admin/admin_api.dart';
import 'package:bobobeads/admin/admin_template_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('保存草稿走 PUT，并把响应里的 updatedAt 原样用作下次基线', (tester) async {
    final bodies = <String, Map<String, dynamic>>{};
    final api = await _authenticatedApi((request) async {
      switch (request.url.path) {
        case '/api/v1/admin/media/upload':
          return _jsonResponse({'fileKey': 'admin_preview/draft.png'});
        case '/api/v1/admin/template-drafts/draft-1':
          if (request.method == 'GET') return _draftDetailResponse();
          bodies['put'] = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({
            'draft': {
              'draftId': 'draft-1',
              'updatedAt': '2026-08-19T10:07:31.456Z',
            },
          });
        default:
          throw StateError('Unexpected request: ${request.url}');
      }
    });

    await _pumpEditor(tester, api, draftId: 'draft-1');

    await tester.tap(find.byKey(const ValueKey('template-save-draft')));
    await tester.pumpAndSettle();

    expect(find.text('已保存到草稿箱，线上版本未改动。'), findsOneWidget);
    expect(bodies['put']!['baseUpdatedAt'], '2026-08-19T10:03:00.123Z');
    expect(bodies['put']!.containsKey('idempotencyKey'), isFalse);
    expect(bodies['put']!.containsKey('templateId'), isFalse);
    // Drafts carry a thumbnail so the draft box has something to show; the list
    // response has no patternData to render from.
    expect(bodies['put']!['previewFileKey'], 'admin_preview/draft.png');

    // A second save must use the baseline the first save returned, otherwise
    // the server rejects it as stale.
    await tester.tap(find.byKey(const ValueKey('template-save-draft')));
    await tester.pumpAndSettle();

    expect(bodies['put']!['baseUpdatedAt'], '2026-08-19T10:07:31.456Z');
  });

  testWidgets('发布草稿先提交改动，再用刚返回的 updatedAt 作为发布基线', (tester) async {
    final calls = <String>[];
    Map<String, dynamic>? publishBody;
    final api = await _authenticatedApi((request) async {
      calls.add('${request.method} ${request.url.path}');
      switch (request.url.path) {
        case '/api/v1/admin/template-drafts/draft-1':
          if (request.method == 'GET') return _draftDetailResponse();
          return _jsonResponse({
            'draft': {
              'draftId': 'draft-1',
              'updatedAt': '2026-08-19T10:09:00.900Z',
            },
          });
        case '/api/v1/admin/media/upload':
          return _jsonResponse({'fileKey': 'admin_preview/draft.png'});
        case '/api/v1/admin/template-drafts/draft-1/publish':
          publishBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({'templateId': 'template-001'});
        default:
          throw StateError('Unexpected request: ${request.url}');
      }
    });

    final result = await _pumpEditor(tester, api, draftId: 'draft-1');

    await tester.tap(find.byKey(const ValueKey('template-publish')));
    await tester.pumpAndSettle();

    expect(publishBody!.keys, {
      'idempotencyKey',
      'previewFileKey',
      'baseUpdatedAt',
    });
    expect(publishBody!['baseUpdatedAt'], '2026-08-19T10:09:00.900Z');
    expect(publishBody!['previewFileKey'], 'admin_preview/draft.png');
    expect(calls, [
      'GET /api/v1/admin/template-drafts/draft-1',
      // The draft keeps its own thumbnail, so a failed publish still leaves a
      // visible draft behind. Publishing then uploads the gallery preview.
      'POST /api/v1/admin/media/upload',
      'PUT /api/v1/admin/template-drafts/draft-1',
      'POST /api/v1/admin/media/upload',
      'POST /api/v1/admin/template-drafts/draft-1/publish',
    ]);
    expect(result.value?.outcome, AdminTemplateEditorOutcome.published);
    expect(result.value?.templateId, 'template-001');
  });

  testWidgets('4001 冲突时重新拉详情，用 updatedByActor 说明是谁改的', (tester) async {
    var detailFetches = 0;
    final api = await _authenticatedApi((request) async {
      if (request.url.path == '/api/v1/admin/media/upload') {
        return _jsonResponse({'fileKey': 'admin_preview/draft.png'});
      }
      if (request.url.path != '/api/v1/admin/template-drafts/draft-1') {
        throw StateError('Unexpected request: ${request.url}');
      }
      if (request.method == 'GET') {
        detailFetches += 1;
        return _draftDetailResponse(updatedByActor: 'operator-b');
      }
      return http.Response(
        jsonEncode({
          'header': {'code': 4001, 'message': 'conflict with admin 7'},
        }),
        409,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await _pumpEditor(tester, api, draftId: 'draft-1');

    await tester.tap(find.byKey(const ValueKey('template-save-draft')));
    // Not pumpAndSettle: the save button keeps spinning while the conflict
    // dialog waits for the operator, so the tree never goes quiet.
    await _pumpFrames(tester);

    expect(detailFetches, 2);
    expect(find.text('保存被拒绝'), findsOneWidget);
    expect(
      find.textContaining('这份草稿已被 operator-b 修改。'),
      findsOneWidget,
    );
    // The 4001 message names an administrator for log triage only, so it must
    // not leak into the operator-facing copy.
    expect(find.textContaining('admin 7'), findsNothing);

    await tester.tap(find.text('保留我的改动'));
    await tester.pumpAndSettle();

    expect(find.textContaining('当前改动尚未保存'), findsOneWidget);
  });
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<ValueNotifier<AdminTemplateEditorResult?>> _pumpEditor(
  WidgetTester tester,
  AdminApi api, {
  required String draftId,
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final result = ValueNotifier<AdminTemplateEditorResult?>(null);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                result.value = await Navigator.of(context)
                    .push<AdminTemplateEditorResult>(
                      MaterialPageRoute(
                        builder: (_) => AdminTemplateEditorPage(
                          api: api,
                          categories: const [
                            AdminCategory(id: 7, name: '动物', templateCount: 3),
                          ],
                          draftId: draftId,
                        ),
                      ),
                    );
              },
              child: const Text('打开编辑器'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('打开编辑器'));
  await tester.pumpAndSettle();
  return result;
}

Future<AdminApi> _authenticatedApi(MockClientHandler handler) async {
  final api = AdminApi(
    baseUrl: 'http://api.example.test',
    httpClient: MockClient((request) async {
      if (request.url.path == '/api/v1/admin/login') {
        return _jsonResponse({'accessToken': 'admin-token'});
      }
      return handler(request);
    }),
  );
  await api.login(username: 'operator', password: 'secret');
  return api;
}

http.Response _draftDetailResponse({String updatedByActor = 'operator'}) {
  return _jsonResponse({
    'draft': {
      'draftId': 'draft-1',
      'templateId': 'template-001',
      'title': '小狐狸',
      'description': '草稿说明',
      'categoryId': 7,
      'tags': ['动物', '入门'],
      'difficulty': 1,
      'previewFileKey': '',
      'updatedAt': '2026-08-19T10:03:00.123Z',
      'updatedByActor': updatedByActor,
    },
    'patternData': {
      'schemaVersion': 1,
      'width': 2,
      'height': 2,
      'boardSpec': '2x2',
      'pixels': [1, 0, 0, 1],
      'colorPalette': [
        {
          'index': 1,
          'hex': '#ff0000',
          'brand': 'hama',
          'code': 'H01',
          'name': '红',
        },
      ],
    },
  });
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(
    jsonEncode({
      'header': {'code': 0, 'message': 'success'},
      ...body,
    }),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
