import 'dart:convert';

import 'package:bobobeads/admin/admin_api.dart';
import 'package:bobobeads/admin/admin_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('后台生成设置提供并传达去背景开关', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      BoboBeadsAdminApp(
        api: AdminApi(
          baseUrl: 'http://api.example.test',
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/api/v1/admin/login':
                return _jsonResponse({'accessToken': 'admin-token'});
              case '/api/v1/admin/template-categories':
                return _jsonResponse({
                  'categories': [
                    {'categoryId': 1, 'name': '动物', 'templateCount': 0},
                  ],
                });
              default:
                throw StateError('Unexpected request: ${request.url}');
            }
          }),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'operator');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('进入工作台'));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('admin-remove-background-toggle'));
    expect(toggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(find.text('生成图纸时移除图片背景，保留主体轮廓'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets('盲盒奖池分区展示条目，停用只改条目状态', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final updateBodies = <String>[];
    var poolStatus = 1;

    await tester.pumpWidget(
      BoboBeadsAdminApp(
        api: AdminApi(
          baseUrl: 'http://api.example.test',
          httpClient: MockClient((request) async {
            if (request.url.path == '/api/v1/admin/blind-box-pool') {
              return _jsonResponse({
                'items': [
                  {
                    'itemId': '1',
                    'templateId': '12',
                    'title': '小猫咪',
                    'previewUrl': 'https://cdn.example.test/preview.png',
                    'thumbnailUrl': 'https://cdn.example.test/thumb.png',
                    'categoryId': 3,
                    'categoryName': '盲盒限定',
                    'weight': 10,
                    'sortOrder': 0,
                    'status': poolStatus,
                  },
                ],
                'page': {'total': 1, 'hasMore': false},
              });
            }
            if (request.url.path == '/api/v1/admin/blind-box-pool/1') {
              updateBodies.add(request.body);
              poolStatus = 0;
              return _jsonResponse({});
            }
            switch (request.url.path) {
              case '/api/v1/admin/login':
                return _jsonResponse({'accessToken': 'admin-token'});
              case '/api/v1/admin/template-categories':
                return _jsonResponse({'categories': const []});
              default:
                throw StateError('Unexpected request: ${request.url}');
            }
          }),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'operator');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('进入工作台'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('盲盒奖池'));
    await tester.pumpAndSettle();

    expect(find.text('小猫咪'), findsOneWidget);
    expect(find.text('权重 10'), findsOneWidget);
    expect(find.text('参与抽奖'), findsOneWidget);
    expect(find.text('共 1 张图纸，奖池内的图纸只能通过盲盒抽到。'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pool-toggle-1')));
    await tester.pumpAndSettle();

    expect(updateBodies, [
      jsonEncode({'status': 0}),
    ]);
    expect(find.text('已停用「小猫咪」，暂时不参与抽奖'), findsOneWidget);
    expect(find.text('已停用'), findsOneWidget);
    expect(find.text('启用'), findsOneWidget);
  });

  testWidgets('模板库可以按可见性筛选，并把普通图纸加入奖池', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final poolBodies = <String>[];
    var joined = false;

    await tester.pumpWidget(
      BoboBeadsAdminApp(
        api: AdminApi(
          baseUrl: 'http://api.example.test',
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/api/v1/admin/login':
                return _jsonResponse({'accessToken': 'admin-token'});
              case '/api/v1/admin/template-categories':
                return _jsonResponse({'categories': const []});
              case '/api/v1/admin/templates':
                return _jsonResponse({
                  'templates': [
                    {
                      'templateId': '12',
                      'title': '小猫咪',
                      'categoryId': 1,
                      'categoryName': '动物',
                      'visibility': joined ? 'blind_box' : 'public',
                    },
                    {
                      'templateId': '34',
                      'title': '小狐狸',
                      'categoryId': 1,
                      'categoryName': '动物',
                      'visibility': 'blind_box',
                    },
                  ],
                  'page': {'total': 2, 'hasMore': false},
                });
              case '/api/v1/admin/blind-box-pool':
                poolBodies.add(request.body);
                joined = true;
                return _jsonResponse({});
              default:
                throw StateError('Unexpected request: ${request.url}');
            }
          }),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'operator');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('进入工作台'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('模板库'));
    await tester.pumpAndSettle();

    expect(find.text('共 2 个模板，其中 1 张盲盒专属。'), findsOneWidget);
    // The filter chip shares its label with the card badge, so one badge = 2.
    expect(find.text('盲盒专属'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('template-join-pool-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('template-join-pool-34')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('template-visibility-blind_box')),
    );
    await tester.pumpAndSettle();
    expect(find.text('小狐狸'), findsOneWidget);
    expect(find.text('小猫咪'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('template-visibility-all')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('template-join-pool-12')));
    await tester.pumpAndSettle();
    expect(find.text('加入后这张图纸只能通过盲盒抽到，会从客户端普通列表消失。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('admin-pool-weight-field')),
      '10',
    );
    await tester.tap(find.text('加入奖池'));
    await tester.pumpAndSettle();

    expect(poolBodies, [
      jsonEncode({'templateId': '12', 'weight': 10, 'sortOrder': 0}),
    ]);
    expect(find.text('已把「小猫咪」加入盲盒奖池'), findsOneWidget);
    expect(find.byKey(const ValueKey('template-join-pool-12')), findsNothing);
    expect(find.text('盲盒专属'), findsNWidgets(3));
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
