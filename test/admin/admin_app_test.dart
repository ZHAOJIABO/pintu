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
