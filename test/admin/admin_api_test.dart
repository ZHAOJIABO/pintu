import 'dart:convert';
import 'dart:typed_data';


import 'package:bobobeads/admin/admin_api.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('admin API logs in and uses its token for protected requests', () async {
    final client = AdminApi(
      baseUrl: 'http://api.example.test',
      httpClient: MockClient((request) async {
        expect(request.headers['x-platform'], 'web');
        if (request.url.path == '/api/v1/admin/login') {
          expect(request.headers['authorization'], isNull);
          expect(jsonDecode(request.body), {
            'username': 'operator',
            'password': 'secret',
          });
          return _jsonResponse({'accessToken': 'admin-token'});
        }
        expect(request.url.path, '/api/v1/admin/template-categories');
        expect(request.headers['authorization'], 'Bearer admin-token');
        return _jsonResponse({
          'categories': [
            {'categoryId': 7, 'name': '动物', 'templateCount': 3},
          ],
        });
      }),
    );

    await client.login(username: 'operator', password: 'secret');
    final categories = await client.listCategories();

    expect(client.isAuthenticated, isTrue);
    expect(categories, hasLength(1));
    expect(categories.single.name, '动物');
    expect(categories.single.id, 7);
  });

  test(
    'admin API uploads the rendered preview through the API before publishing pattern data',
    () async {
      final calls = <String>[];
      final client = AdminApi(
        baseUrl: 'http://api.example.test',
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.host}${request.url.path}');
          switch (request.url.path) {
            case '/api/v1/admin/login':
              return _jsonResponse({'accessToken': 'admin-token'});
            case '/api/v1/admin/media/upload':
              expect(request.headers['authorization'], 'Bearer admin-token');
              expect(request.headers['content-type'], 'image/png');
              expect(request.bodyBytes, Uint8List.fromList([1, 2, 3]));
              return _jsonResponse({
                'fileKey': 'admin_preview/preview.png',
                'fileUrl': 'https://cdn.example.test/admin_preview/preview.png',
              });
            case '/api/v1/admin/templates':
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['title'], '小狐狸');
              expect(body['patternData']['boardSpec'], '2x2');
              expect(body['previewFileKey'], 'admin_preview/preview.png');
              return _jsonResponse({'templateId': 'template-001'});
            default:
              throw StateError('Unexpected request: ${request.url}');
          }
        }),
      );

      await client.login(username: 'operator', password: 'secret');
      final id = await client.publishTemplate(
        idempotencyKey: 'request-001',
        title: '小狐狸',
        description: '测试模板',
        categoryId: 1,
        tags: '动物,入门',
        difficulty: 1,
        patternData: const PatternData(
          width: 2,
          height: 2,
          boardSpec: '2x2',
          pixels: [1, 0, 0, 1],
          colorPalette: [
            PatternPaletteColor(
              index: 1,
              hex: '#ff0000',
              brand: 'hama',
              code: 'H01',
              name: '红',
            ),
          ],
        ),
        previewBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(id, 'template-001');
      expect(calls, [
        'POST api.example.test/api/v1/admin/login',
        'POST api.example.test/api/v1/admin/media/upload',
        'POST api.example.test/api/v1/admin/templates',
      ]);
    },
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
