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
    'admin API uploads the gallery thumbnail before publishing pattern data',
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
        thumbnailBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(id, 'template-001');
      expect(calls, [
        'POST api.example.test/api/v1/admin/login',
        'POST api.example.test/api/v1/admin/media/upload',
        'POST api.example.test/api/v1/admin/templates',
      ]);
    },
  );

  test(
    'admin API loads all template pages and unpublishes a template',
    () async {
      final calls = <String>[];
      final client = AdminApi(
        baseUrl: 'http://api.example.test',
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          switch (request.url.path) {
            case '/api/v1/admin/login':
              return _jsonResponse({'accessToken': 'admin-token'});
            case '/api/v1/admin/templates':
              expect(request.headers['authorization'], 'Bearer admin-token');
              final page = request.url.queryParameters['page.page'];
              expect(request.url.queryParameters['page.pageSize'], '100');
              if (page == '1') {
                return _jsonResponse({
                  'templates': [
                    {
                      'templateId': 'template-001',
                      'title': '小狐狸',
                      'categoryId': 7,
                      'categoryName': '动物',
                      'previewUrl': 'https://cdn.example.test/fox.png',
                      'tags': ['动物', '入门'],
                      'difficulty': 1,
                      'width': 29,
                      'height': 29,
                      'colorCount': 8,
                    },
                  ],
                  'page': {'hasMore': true},
                });
              }
              expect(page, '2');
              return _jsonResponse({
                'templates': [
                  {
                    'templateId': 'template-002',
                    'title': '小兔子',
                    'categoryId': 7,
                    'tags': '动物,礼物',
                  },
                ],
                'page': {'hasMore': false},
              });
            case '/api/v1/admin/templates/template-001/unpublish':
              expect(request.headers['authorization'], 'Bearer admin-token');
              expect(jsonDecode(request.body), {'reason': '需要修订'});
              return _jsonResponse({});
            default:
              throw StateError('Unexpected request: ${request.url}');
          }
        }),
      );

      await client.login(username: 'operator', password: 'secret');
      final templates = await client.listTemplates();
      await client.unpublishTemplate(
        templateId: 'template-001',
        reason: '需要修订',
      );

      expect(templates, hasLength(2));
      expect(templates.first.categoryName, '动物');
      expect(templates.last.tags, ['动物', '礼物']);
      expect(calls, [
        'POST /api/v1/admin/login',
        'GET /api/v1/admin/templates',
        'GET /api/v1/admin/templates',
        'POST /api/v1/admin/templates/template-001/unpublish',
      ]);
    },
  );

  test(
    'admin API creates categories and updates an editable template',
    () async {
      final calls = <String>[];
      final client = AdminApi(
        baseUrl: 'http://api.example.test',
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          switch (request.url.path) {
            case '/api/v1/admin/login':
              return _jsonResponse({'accessToken': 'admin-token'});
            case '/api/v1/admin/template-categories':
              expect(request.method, 'POST');
              expect(jsonDecode(request.body), {'name': '节日'});
              return _jsonResponse({
                'category': {'categoryId': 9, 'name': '节日', 'templateCount': 0},
              });
            case '/api/v1/admin/templates/template-001':
              if (request.method == 'GET') {
                return _jsonResponse({
                  'template': {
                    'templateId': 'template-001',
                    'title': '小狐狸',
                    'categoryId': 7,
                    'previewFileUrl': 'https://cdn.example.test/fox.png',
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
              }
              expect(request.method, 'PUT');
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['title'], '更新的小狐狸');
              expect(body['categoryId'], 9);
              expect(body['previewFileKey'], 'admin_preview/updated.png');
              expect(body['patternData']['boardSpec'], '2x2');
              return _jsonResponse({});
            case '/api/v1/admin/media/upload':
              expect(request.method, 'POST');
              expect(request.bodyBytes, Uint8List.fromList([4, 5, 6]));
              return _jsonResponse({'fileKey': 'admin_preview/updated.png'});
            default:
              throw StateError('Unexpected request: ${request.url}');
          }
        }),
      );

      await client.login(username: 'operator', password: 'secret');
      final category = await client.createCategory(name: '节日');
      final detail = await client.getTemplate('template-001');
      await client.updateTemplate(
        templateId: 'template-001',
        title: '更新的小狐狸',
        description: '更新说明',
        categoryId: category.id,
        tags: '节日,动物',
        difficulty: 2,
        patternData: detail.patternData,
        thumbnailBytes: Uint8List.fromList([4, 5, 6]),
      );

      expect(category.id, 9);
      expect(detail.template.imageUrl, 'https://cdn.example.test/fox.png');
      expect(detail.patternData.width, 2);
      expect(calls, [
        'POST /api/v1/admin/login',
        'POST /api/v1/admin/template-categories',
        'GET /api/v1/admin/templates/template-001',
        'POST /api/v1/admin/media/upload',
        'PUT /api/v1/admin/templates/template-001',
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
