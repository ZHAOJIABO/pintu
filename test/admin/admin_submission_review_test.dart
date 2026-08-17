import 'dart:convert';

import 'package:bobobeads/admin/admin_api.dart';
import 'package:bobobeads/admin/admin_submission_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('审核通过为没有预览图的投稿自动生成一张预览图', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final calls = <String>[];
    Map<String, dynamic>? approveBody;
    final api = _api(
      calls,
      onApprove: (body) => approveBody = body,
      previewUrl: '',
    );
    AdminSubmissionReviewResult? result;

    await _pumpReviewPage(tester, api, (value) => result = value);

    await _tap(tester, const ValueKey('submission-approve'));

    expect(calls, [
      'GET /api/v1/admin/template-submissions/88',
      'POST /api/v1/admin/media/upload',
      'POST /api/v1/admin/template-submissions/88/approve',
    ]);
    expect(approveBody?['categoryId'], 7);
    expect(approveBody?['title'], '小猫');
    expect(approveBody?['previewFileKey'], 'admin_preview/generated.png');
    expect(result?.outcome, AdminSubmissionReviewOutcome.approved);
    expect(result?.templateId, 'template-900');
  });

  testWidgets('驳回投稿必须填写原因', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final calls = <String>[];
    Map<String, dynamic>? rejectBody;
    final api = _api(calls, onReject: (body) => rejectBody = body);
    AdminSubmissionReviewResult? result;

    await _pumpReviewPage(tester, api, (value) => result = value);

    await _tap(tester, const ValueKey('submission-reject'));

    final confirm = find.widgetWithText(FilledButton, '确认驳回');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('submission-reject-reason')),
      '图案存在版权风险',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(rejectBody, {'reason': '图案存在版权风险'});
    expect(calls, [
      'GET /api/v1/admin/template-submissions/88',
      'POST /api/v1/admin/template-submissions/88/reject',
    ]);
    expect(result?.outcome, AdminSubmissionReviewOutcome.rejected);
  });

  testWidgets('已通过的投稿不再展示审核操作', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = _api(<String>[], status: 1, templateId: 'template-900');
    await _pumpReviewPage(tester, api, (_) {});

    expect(find.byKey(const ValueKey('submission-approve')), findsNothing);
    expect(find.byKey(const ValueKey('submission-reject')), findsNothing);
    expect(find.text('该投稿已通过审核，如需撤回请到模板库下架对应模板。'), findsOneWidget);
  });
}

/// The review form lives in a scroll view, so the action buttons sit below the
/// fold even on a large test surface.
Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpReviewPage(
  WidgetTester tester,
  AdminApi api,
  ValueChanged<AdminSubmissionReviewResult?> onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final value = await Navigator.of(context)
                .push<AdminSubmissionReviewResult>(
                  MaterialPageRoute(
                    builder: (_) => AdminSubmissionReviewPage(
                      api: api,
                      submission: const AdminSubmission(
                        id: '88',
                        userId: '1024',
                        workId: '2048',
                        title: '小猫',
                        description: '第一次投稿',
                        status: AdminSubmissionStatus.pending,
                        reviewReason: '',
                        reviewerActor: '',
                        templateId: '',
                        boardSpec: '2x2',
                        width: 2,
                        height: 2,
                        beadCount: 4,
                        colorCount: 1,
                        previewUrl: '',
                        thumbnailUrl: '',
                      ),
                      categories: const [
                        AdminCategory(id: 7, name: '动物', templateCount: 3),
                      ],
                    ),
                  ),
                );
            onResult(value);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

AdminApi _api(
  List<String> calls, {
  ValueChanged<Map<String, dynamic>>? onApprove,
  ValueChanged<Map<String, dynamic>>? onReject,
  String previewUrl = '',
  int status = 0,
  String templateId = '',
}) {
  return AdminApi(
    baseUrl: 'http://api.example.test',
    httpClient: MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      switch (request.url.path) {
        case '/api/v1/admin/template-submissions/88':
          return _jsonResponse({
            'submission': {
              'submissionId': '88',
              'userId': '1024',
              'workId': '2048',
              'title': '小猫',
              'description': '第一次投稿',
              'status': status,
              'templateId': templateId,
              'boardSpec': '2x2',
              'width': 2,
              'height': 2,
              'beadCount': 4,
              'colorCount': 1,
              'previewUrl': previewUrl,
              'createdAt': 1755100000,
              'reviewedAt': status == 0 ? 0 : 1755200000,
            },
            'patternData': {
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
        case '/api/v1/admin/media/upload':
          expect(request.headers['content-type'], 'image/png');
          expect(request.bodyBytes, isNotEmpty);
          return _jsonResponse({'fileKey': 'admin_preview/generated.png'});
        case '/api/v1/admin/template-submissions/88/approve':
          onApprove?.call(jsonDecode(request.body) as Map<String, dynamic>);
          return _jsonResponse({'templateId': 'template-900'});
        case '/api/v1/admin/template-submissions/88/reject':
          onReject?.call(jsonDecode(request.body) as Map<String, dynamic>);
          return _jsonResponse({});
        default:
          throw StateError('Unexpected request: ${request.url}');
      }
    }),
  );
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
