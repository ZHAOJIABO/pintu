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

  test('admin API replaces its token only when a response rotates it', () async {
    var protectedRequestCount = 0;
    final client = AdminApi(
      baseUrl: 'http://api.example.test',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/admin/login') {
          return _jsonResponse({'accessToken': 'original-token'});
        }

        protectedRequestCount += 1;
        expect(
          request.headers['authorization'],
          'Bearer ${protectedRequestCount == 1 ? 'original-token' : 'rotated-token'}',
        );
        if (protectedRequestCount == 1) {
          return _jsonResponse(
            {'categories': <Object?>[]},
            headers: const {'x-admin-access-token': 'rotated-token'},
          );
        }
        return _jsonResponse({'categories': <Object?>[]});
      }),
    );

    await client.login(username: 'operator', password: 'secret');
    await client.listCategories();
    await client.listCategories();

    expect(protectedRequestCount, 2);
    expect(client.isAuthenticated, isTrue);
  });

  test('admin API clears its session on 401 without retrying', () async {
    var protectedRequestCount = 0;
    final client = AdminApi(
      baseUrl: 'http://api.example.test',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/admin/login') {
          return _jsonResponse({'accessToken': 'admin-token'});
        }
        protectedRequestCount += 1;
        return http.Response(
          jsonEncode({
            'header': {
              'code': 1101,
              'message': 'administrator authentication required',
            },
          }),
          401,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    await client.login(username: 'operator', password: 'secret');

    await expectLater(client.listCategories(), throwsA(isA<ApiException>()));

    expect(protectedRequestCount, 1);
    expect(client.isAuthenticated, isFalse);
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

  test('admin API pages the review queue and filters by status', () async {
    final calls = <String>[];
    final client = AdminApi(
      baseUrl: 'http://api.example.test',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/v1/admin/login') {
          return _jsonResponse({'accessToken': 'admin-token'});
        }
        expect(request.url.path, '/api/v1/admin/template-submissions');
        expect(request.headers['authorization'], 'Bearer admin-token');
        expect(request.url.queryParameters['page.pageSize'], '50');
        if (request.url.queryParameters['page.page'] == '1') {
          expect(request.url.queryParameters['status'], 'pending');
          return _jsonResponse({
            'submissions': [
              {
                'submissionId': '88',
                'userId': '1024',
                'workId': '2048',
                'title': '小猫',
                'description': '第一次投稿',
                'status': 0,
                'boardSpec': '29x29',
                'width': 29,
                'height': 29,
                'beadCount': 512,
                'colorCount': 8,
                'thumbnailUrl': 'https://cdn.example.test/cat.webp',
                'createdAt': 1755100000,
                'reviewedAt': 0,
              },
            ],
            'page': {'total': 2, 'hasMore': true},
          });
        }
        expect(request.url.queryParameters['page.page'], '2');
        return _jsonResponse({
          'submissions': [
            {
              'submissionId': '89',
              'status': 2,
              'reviewReason': '版权风险',
              'reviewerActor': 'operator',
              'reviewedAt': 1755200000,
            },
          ],
          'page': {'total': 2, 'hasMore': false},
        });
      }),
    );

    await client.login(username: 'operator', password: 'secret');
    final first = await client.listSubmissions(
      status: AdminSubmissionStatus.pending,
    );
    final second = await client.listSubmissions(page: 2);

    expect(first.total, 2);
    expect(first.hasMore, isTrue);
    final pending = first.submissions.single;
    expect(pending.userId, '1024');
    expect(pending.beadCount, 512);
    expect(pending.status, AdminSubmissionStatus.pending);
    expect(pending.imageUrl, 'https://cdn.example.test/cat.webp');
    expect(
      pending.createdAt,
      DateTime.fromMillisecondsSinceEpoch(1755100000 * 1000),
    );
    expect(pending.reviewedAt, isNull);
    expect(second.hasMore, isFalse);
    expect(second.submissions.single.status, AdminSubmissionStatus.rejected);
    expect(calls, [
      'POST /api/v1/admin/login',
      'GET /api/v1/admin/template-submissions',
      'GET /api/v1/admin/template-submissions',
    ]);
  });

  test('admin API approves a submission and omits blank fields', () async {
    final calls = <String>[];
    Map<String, dynamic>? approveBody;
    final client = AdminApi(
      baseUrl: 'http://api.example.test',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        switch (request.url.path) {
          case '/api/v1/admin/login':
            return _jsonResponse({'accessToken': 'admin-token'});
          case '/api/v1/admin/template-submissions/88':
            return _jsonResponse({
              'submission': {'submissionId': '88', 'title': '小猫', 'status': 0},
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
          case '/api/v1/admin/template-submissions/88/approve':
            expect(request.headers['authorization'], 'Bearer admin-token');
            approveBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse({'templateId': 'template-900'});
          default:
            throw StateError('Unexpected request: ${request.url}');
        }
      }),
    );

    await client.login(username: 'operator', password: 'secret');
    final detail = await client.getSubmission('88');
    final templateId = await client.approveSubmission(
      submissionId: '88',
      categoryId: 7,
      difficulty: 2,
      tags: '动物,新手',
      title: '小猫',
    );

    expect(detail.patternData.width, 2);
    expect(templateId, 'template-900');
    expect(approveBody, {
      'categoryId': 7,
      'difficulty': 2,
      'tags': '动物,新手',
      'title': '小猫',
    });
    expect(calls, [
      'POST /api/v1/admin/login',
      'GET /api/v1/admin/template-submissions/88',
      'POST /api/v1/admin/template-submissions/88/approve',
    ]);
  });

  test('admin API rejects a submission with a reason', () async {
    final calls = <String>[];
    final client = AdminApi(
      baseUrl: 'http://api.example.test',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/v1/admin/login') {
          return _jsonResponse({'accessToken': 'admin-token'});
        }
        expect(
          request.url.path,
          '/api/v1/admin/template-submissions/88/reject',
        );
        expect(jsonDecode(request.body), {'reason': '图案存在版权风险'});
        return _jsonResponse({});
      }),
    );

    await client.login(username: 'operator', password: 'secret');
    await client.rejectSubmission(submissionId: '88', reason: '图案存在版权风险');

    expect(calls, [
      'POST /api/v1/admin/login',
      'POST /api/v1/admin/template-submissions/88/reject',
    ]);
  });

  test('admin API creates a draft with the exact create field set', () async {
    Map<String, dynamic>? body;
    final calls = <String>[];
    final client = await _authenticatedClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path == '/api/v1/admin/media/upload') {
        expect(request.headers['content-type'], 'image/png');
        expect(request.bodyBytes, Uint8List.fromList([1, 2, 3]));
        return _jsonResponse({'fileKey': 'admin_preview/draft.png'});
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/admin/template-drafts');
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse({
        'draft': {
          'draftId': 'draft-1',
          'updatedAt': '2026-08-19T10:03:00.123Z',
        },
      });
    });

    final result = await client.createDraft(
      idempotencyKey: 'draft-request-1',
      templateId: 'template-001',
      title: '小狐狸',
      description: '草稿说明',
      categoryId: 7,
      tags: '动物,入门',
      difficulty: 1,
      patternData: _pattern,
      thumbnailBytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(result.draftId, 'draft-1');
    // Echoed verbatim: reformatting or truncating to seconds would break the
    // server side optimistic lock, which compares for exact equality.
    expect(result.updatedAt, '2026-08-19T10:03:00.123Z');
    expect(body!.keys, {
      'idempotencyKey',
      'templateId',
      'title',
      'description',
      'categoryId',
      'tags',
      'difficulty',
      'previewFileKey',
      'patternData',
    });
    expect(body!['previewFileKey'], 'admin_preview/draft.png');
    expect(body!['patternData']['schemaVersion'], 1);
    expect(
      (body!['patternData']['pixels'] as List),
      hasLength(_pattern.width * _pattern.height),
    );
    expect(calls, [
      'POST /api/v1/admin/media/upload',
      'POST /api/v1/admin/template-drafts',
    ]);
  });

  test(
    'admin API saves a draft without a thumbnail when none was rendered',
    () async {
      Map<String, dynamic>? body;
      final calls = <String>[];
      final client = await _authenticatedClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({
          'draft': {
            'draftId': 'draft-1',
            'updatedAt': '2026-08-19T10:03:00.1Z',
          },
        });
      });

      await client.createDraft(idempotencyKey: 'key', patternData: _pattern);

      expect(body!['previewFileKey'], '');
      expect(calls, ['POST /api/v1/admin/template-drafts']);
    },
  );

  test('admin API refuses to create a draft without an idempotency key', () {
    final client = AdminApi(
      baseUrl: 'http://api.example.test',
      httpClient: MockClient((request) async {
        throw StateError('Unexpected request: ${request.url}');
      }),
    );

    expect(
      () => client.createDraft(idempotencyKey: '', patternData: _pattern),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('admin API updates a draft without the create-only fields', () async {
    Map<String, dynamic>? body;
    final client = await _authenticatedClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/v1/admin/template-drafts/draft-1');
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse({
        'draft': {
          'draftId': 'draft-1',
          'updatedAt': '2026-08-19T10:05:12.007Z',
        },
      });
    });

    final updatedAt = await client.updateDraft(
      draftId: 'draft-1',
      patternData: _pattern,
      baseUpdatedAt: '2026-08-19T10:03:00.123Z',
      title: '小狐狸',
      categoryId: 7,
    );

    expect(updatedAt, '2026-08-19T10:05:12.007Z');
    expect(body!.containsKey('idempotencyKey'), isFalse);
    expect(body!.containsKey('templateId'), isFalse);
    expect(body!['baseUpdatedAt'], '2026-08-19T10:03:00.123Z');
    expect(body!.keys, {
      'title',
      'description',
      'categoryId',
      'tags',
      'difficulty',
      'previewFileKey',
      'patternData',
      'baseUpdatedAt',
    });
  });

  test('admin API surfaces the conflict code when a draft moved on', () async {
    final client = await _authenticatedClient((request) async {
      return http.Response(
        jsonEncode({
          'header': {
            'code': 4001,
            'message': 'draft was modified by operator-b',
          },
        }),
        409,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await expectLater(
      client.updateDraft(
        draftId: 'draft-1',
        patternData: _pattern,
        baseUpdatedAt: '2026-08-19T10:03:00.123Z',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', AdminDraftErrorCode.conflict)
            .having((e) => e.httpStatusCode, 'httpStatusCode', 409),
      ),
    );
  });

  test('admin API distinguishes the two 400 draft failures', () async {
    for (final code in [
      AdminDraftErrorCode.boxFull,
      AdminDraftErrorCode.notPublishable,
    ]) {
      final client = await _authenticatedClient((request) async {
        return http.Response(
          jsonEncode({
            'header': {'code': code, 'message': 'draft rejected'},
          }),
          400,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await expectLater(
        client.createDraft(idempotencyKey: 'key', patternData: _pattern),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
      );
    }
  });

  test(
    'admin API publishes a draft with only the three publish fields',
    () async {
      final calls = <String>[];
      Map<String, dynamic>? publishBody;
      final client = await _authenticatedClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        switch (request.url.path) {
          case '/api/v1/admin/media/upload':
            expect(request.bodyBytes, Uint8List.fromList([7, 8, 9]));
            return _jsonResponse({'fileKey': 'admin_preview/draft.png'});
          case '/api/v1/admin/template-drafts/draft-1/publish':
            publishBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse({'templateId': 'template-777'});
          default:
            throw StateError('Unexpected request: ${request.url}');
        }
      });

      final templateId = await client.publishDraft(
        draftId: 'draft-1',
        idempotencyKey: 'publish-request-1',
        baseUpdatedAt: '2026-08-19T10:05:12.007Z',
        thumbnailBytes: Uint8List.fromList([7, 8, 9]),
      );

      expect(templateId, 'template-777');
      expect(publishBody, {
        'idempotencyKey': 'publish-request-1',
        'previewFileKey': 'admin_preview/draft.png',
        'baseUpdatedAt': '2026-08-19T10:05:12.007Z',
      });
      expect(calls, [
        'POST /api/v1/admin/media/upload',
        'POST /api/v1/admin/template-drafts/draft-1/publish',
      ]);
    },
  );

  test('admin API lists drafts without pattern data', () async {
    final client = await _authenticatedClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/admin/template-drafts');
      expect(request.url.queryParameters['page.page'], '1');
      expect(request.url.queryParameters['page.pageSize'], '50');
      return _jsonResponse({
        'drafts': [
          {
            'draftId': 'draft-1',
            'templateId': 'template-001',
            'title': '小狐狸',
            'categoryId': 7,
            'categoryName': '动物',
            'thumbnailUrl': '',
            'width': 29,
            'height': 29,
            'colorCount': 8,
            'updatedAt': '2026-08-19T10:03:00.123Z',
            'updatedByActor': 'operator-b',
          },
          {
            'draftId': 'draft-2',
            'templateId': '',
            'title': '',
            'updatedAt': '2026-08-19T09:00:00.000Z',
          },
          {'draftId': ''},
        ],
        'page': {'total': 2, 'hasMore': false},
      });
    });

    final page = await client.listDrafts();

    expect(page.total, 2);
    expect(page.hasMore, isFalse);
    expect(page.drafts, hasLength(2));
    final revision = page.drafts.first;
    expect(revision.isRevision, isTrue);
    expect(revision.updatedAt, '2026-08-19T10:03:00.123Z');
    expect(revision.updatedByActor, 'operator-b');
    final fresh = page.drafts.last;
    expect(fresh.isRevision, isFalse);
    expect(fresh.displayTitle, '未命名草稿');
  });

  test('admin API reads draft detail tags as a list', () async {
    final client = await _authenticatedClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/admin/template-drafts/draft-1');
      return _jsonResponse({
        'draft': {
          'draftId': 'draft-1',
          'templateId': 'template-001',
          'title': '小狐狸',
          'description': '草稿说明',
          'categoryId': 7,
          'tags': ['动物', '入门'],
          'previewFileKey': '',
          'updatedAt': '2026-08-19T10:03:00.123Z',
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
    });

    final detail = await client.getDraft('draft-1');

    expect(detail.tags, ['动物', '入门']);
    expect(detail.description, '草稿说明');
    expect(detail.previewFileKey, '');
    expect(detail.patternData.pixels, [1, 0, 0, 1]);
    expect(detail.draft.updatedAt, '2026-08-19T10:03:00.123Z');
  });

  test('admin API deletes a draft', () async {
    final calls = <String>[];
    final client = await _authenticatedClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return _jsonResponse({});
    });

    await client.deleteDraft('draft-1');

    expect(calls, ['DELETE /api/v1/admin/template-drafts/draft-1']);
  });

  test('admin templates report whether a draft is waiting', () async {
    final client = await _authenticatedClient((request) async {
      return _jsonResponse({
        'templates': [
          {
            'templateId': 'template-001',
            'title': '小狐狸',
            'hasDraft': true,
            'draftId': 'draft-1',
          },
          {'templateId': 'template-002', 'title': '小兔子'},
        ],
        'page': {'hasMore': false},
      });
    });

    final templates = await client.listTemplates();

    expect(templates.first.hasDraft, isTrue);
    expect(templates.first.draftId, 'draft-1');
    expect(templates.last.hasDraft, isFalse);
    expect(templates.last.draftId, '');
  });

  test('admin templates report blind-box visibility', () async {
    final client = await _authenticatedClient((request) async {
      return _jsonResponse({
        'templates': [
          {
            'templateId': 'template-001',
            'title': '小猫咪',
            'visibility': 'blind_box',
          },
          {
            'templateId': 'template-002',
            'title': '小兔子',
            'visibility': 'public',
          },
          {'templateId': 'template-003', 'title': '樱花'},
        ],
        'page': {'hasMore': false},
      });
    });

    final templates = await client.listTemplates();

    expect(templates[0].visibility, AdminTemplateVisibility.blindBox);
    expect(templates[0].isBlindBoxOnly, isTrue);
    expect(templates[1].visibility, AdminTemplateVisibility.public);
    // A template from before the blind box existed carries no visibility.
    expect(templates[2].visibility, AdminTemplateVisibility.public);
  });

  test('admin categories report and create the blind-box flag', () async {
    Map<String, Object?>? createBody;
    final client = await _authenticatedClient((request) async {
      expect(request.url.path, '/api/v1/admin/template-categories');
      if (request.method == 'POST') {
        createBody = jsonDecode(request.body) as Map<String, Object?>;
        return _jsonResponse({
          'category': {
            'categoryId': 9,
            'name': '盲盒限定',
            'templateCount': 0,
            'isBlindBox': true,
          },
        });
      }
      return _jsonResponse({
        'categories': [
          {'categoryId': 3, 'name': '盲盒限定', 'isBlindBox': true},
          {'categoryId': 4, 'name': '动物'},
        ],
      });
    });

    final categories = await client.listCategories();
    final created = await client.createCategory(name: '盲盒限定', isBlindBox: true);

    expect(categories.first.isBlindBox, isTrue);
    expect(categories.last.isBlindBox, isFalse);
    expect(createBody, {'name': '盲盒限定', 'isBlindBox': true});
    expect(created.isBlindBox, isTrue);
  });

  test('blind-box pool listing parses entries and paging', () async {
    final client = await _authenticatedClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/admin/blind-box-pool');
      expect(request.url.queryParameters, {
        'page.page': '2',
        'page.pageSize': '20',
      });
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
            'status': 1,
          },
          {'itemId': '', 'templateId': '13'},
        ],
        'page': {'total': 21, 'page': 2, 'pageSize': 20, 'hasMore': false},
      });
    });

    final result = await client.listBlindBoxPool(page: 2);

    // The entry without an itemId cannot be edited or removed, so it is dropped.
    expect(result.items, hasLength(1));
    expect(result.total, 21);
    expect(result.hasMore, isFalse);
    final item = result.items.single;
    expect(item.itemId, '1');
    expect(item.templateId, '12');
    expect(item.categoryName, '盲盒限定');
    expect(item.weight, 10);
    expect(item.isActive, isTrue);
    expect(item.imageUrl, 'https://cdn.example.test/thumb.png');
  });

  test('joining the blind-box pool posts the template id and weight', () async {
    Map<String, Object?>? body;
    final client = await _authenticatedClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/admin/blind-box-pool');
      body = jsonDecode(request.body) as Map<String, Object?>;
      return _jsonResponse(const {});
    });

    await client.addToBlindBoxPool(templateId: '12', weight: 10, sortOrder: 3);

    expect(body, {'templateId': '12', 'weight': 10, 'sortOrder': 3});
  });

  test('updating a pool entry sends only the changed fields', () async {
    final bodies = <Map<String, Object?>>[];
    final client = await _authenticatedClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/v1/admin/blind-box-pool/item%201');
      bodies.add(jsonDecode(request.body) as Map<String, Object?>);
      return _jsonResponse(const {});
    });

    await client.updateBlindBoxPoolItem(itemId: 'item 1', status: 0);
    await client.updateBlindBoxPoolItem(
      itemId: 'item 1',
      weight: 5,
      sortOrder: 1,
    );

    expect(bodies, [
      {'status': 0},
      {'weight': 5, 'sortOrder': 1},
    ]);
  });

  test('updating a pool entry without any field is rejected locally', () async {
    var requested = false;
    final client = await _authenticatedClient((request) async {
      requested = true;
      return _jsonResponse(const {});
    });

    expect(
      () => client.updateBlindBoxPoolItem(itemId: '1'),
      throwsArgumentError,
    );
    expect(requested, isFalse);
  });

  test('removing a pool entry deletes it by item id', () async {
    var method = '';
    var path = '';
    final client = await _authenticatedClient((request) async {
      method = request.method;
      path = request.url.path;
      return _jsonResponse(const {});
    });

    await client.removeFromBlindBoxPool('1');

    expect(method, 'DELETE');
    expect(path, '/api/v1/admin/blind-box-pool/1');
  });

  test('a duplicate pool entry surfaces the server message', () async {
    final client = await _authenticatedClient((request) async {
      return http.Response(
        jsonEncode({
          'header': {'code': 3001, 'message': '该图纸已在盲盒奖池中'},
        }),
        400,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await expectLater(
      client.addToBlindBoxPool(templateId: '12'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.message, 'message', '该图纸已在盲盒奖池中')
            .having((error) => error.httpStatusCode, 'httpStatusCode', 400),
      ),
    );
  });
}

const _pattern = PatternData(
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
);

/// Logs in so the caller's handler only sees the request under test.
Future<AdminApi> _authenticatedClient(MockClientHandler handler) async {
  final client = AdminApi(
    baseUrl: 'http://api.example.test',
    httpClient: MockClient((request) async {
      if (request.url.path == '/api/v1/admin/login') {
        return _jsonResponse({'accessToken': 'admin-token'});
      }
      expect(request.headers['authorization'], 'Bearer admin-token');
      return handler(request);
    }),
  );
  await client.login(username: 'operator', password: 'secret');
  return client;
}

http.Response _jsonResponse(
  Map<String, Object?> body, {
  Map<String, String> headers = const {},
}) {
  return http.Response(
    jsonEncode({
      'header': {'code': 0, 'message': 'success'},
      ...body,
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  );
}
