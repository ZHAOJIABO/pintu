import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/services/api/api_client.dart';
import 'package:bobobeads/services/api/generation_completion_service.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_repositories.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:bobobeads/services/pattern_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('ApiClient sends common headers and parses successful body', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'http://example.test',
      tokenProvider: () async => 'token-1',
      deviceIdProvider: () async => 'device-1',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'header': {'code': 0, 'message': 'success'},
            'templates': const [],
          }),
          200,
        );
      }),
    );

    final data = await client.get(
      '/api/v1/templates',
      query: {'scene': 'home', 'page.page': 1, 'page.pageSize': 20},
    );

    expect(data['templates'], isEmpty);
    expect(captured.url.toString(), contains('/api/v1/templates'));
    expect(captured.url.queryParameters['scene'], 'home');
    expect(captured.url.queryParameters['page.page'], '1');
    expect(captured.headers['Authorization'], 'Bearer token-1');
    expect(captured.headers['X-Platform'], 'ios');
    expect(captured.headers['X-App-Version'], '1.0.0');
    expect(captured.headers['X-Device-Id'], 'device-1');
  });

  test('ApiClient converts non-zero response header to ApiException', () async {
    final client = ApiClient(
      baseUrl: 'http://example.test',
      tokenProvider: () async => null,
      deviceIdProvider: () async => 'device-1',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'header': {
              'code': 1101,
              'message': 'client_request_id required',
              'traceId': 'trace-1',
            },
          }),
          200,
        );
      }),
    );

    expect(
      () => client.post('/api/v1/ai/style-generations', body: const {}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 1101)
            .having((error) => error.traceId, 'traceId', 'trace-1'),
      ),
    );
  });

  test(
    'ApiClient retries once after unauthorized handler refreshes token',
    () async {
      var calls = 0;
      var token = 'expired-token';
      final client = ApiClient(
        baseUrl: 'http://example.test',
        tokenProvider: () async => token,
        deviceIdProvider: () async => 'device-1',
        onUnauthorized: () async {
          token = 'fresh-token';
          return true;
        },
        httpClient: MockClient((request) async {
          calls++;
          if (calls == 1) {
            expect(request.headers['Authorization'], 'Bearer expired-token');
            return http.Response('unauthorized', 401);
          }
          expect(request.headers['Authorization'], 'Bearer fresh-token');
          return http.Response(
            jsonEncode({
              'header': {'code': 0, 'message': 'success'},
              'works': const [],
            }),
            200,
          );
        }),
      );

      final data = await client.get('/api/v1/works');

      expect(data['works'], isEmpty);
      expect(calls, 2);
    },
  );

  test('PatternData serializes generated rgba pixels as palette indexes', () {
    final red = PaletteEntry(
      name: '红色',
      ref: 'A01',
      symbol: 'R',
      color: BeadColor.fromInt(255, 0, 0, 255),
      prefix: 'mard',
    );
    final white = PaletteEntry(
      name: '白色',
      ref: 'A02',
      symbol: 'W',
      color: BeadColor.fromInt(255, 255, 255, 255),
      prefix: 'mard',
    );
    final pattern = GeneratedPattern(
      width: 2,
      height: 2,
      pixels: Uint8List.fromList([
        255,
        0,
        0,
        255,
        255,
        255,
        255,
        255,
        0,
        0,
        0,
        0,
        255,
        0,
        0,
        255,
      ]),
      usage: const {'A01': 2, 'A02': 1},
      paletteEntries: [red, white],
      draft: DraftProject(originalImageBytes: Uint8List(0)),
    );

    final data = PatternData.fromGeneratedPattern(pattern);

    expect(data.width, 2);
    expect(data.height, 2);
    expect(data.pixels, [1, 2, 0, 1]);
    expect(data.colorPalette, hasLength(2));
    expect(data.toJson()['colorPalette'], [
      {
        'index': 1,
        'hex': '#ff0000',
        'brand': 'mard',
        'code': 'A01',
        'name': '红色',
      },
      {
        'index': 2,
        'hex': '#ffffff',
        'brand': 'mard',
        'code': 'A02',
        'name': '白色',
      },
    ]);
  });

  test('PatternData converts indexed API pixels for the result screen', () {
    const data = PatternData(
      width: 2,
      height: 2,
      boardSpec: '2x2',
      pixels: [1, 2, 0, 1],
      colorPalette: [
        PatternPaletteColor(
          index: 1,
          hex: '#ff0000',
          brand: 'mard',
          code: 'A01',
          name: '红色',
        ),
        PatternPaletteColor(
          index: 2,
          hex: '#ffffff',
          brand: 'mard',
          code: 'A02',
          name: '白色',
        ),
      ],
    );

    final pattern = data.toGeneratedPattern();

    expect(pattern.pixels, [
      255,
      0,
      0,
      255,
      255,
      255,
      255,
      255,
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      255,
    ]);
    expect(pattern.usage, {'A01': 2, 'A02': 1});
    expect(pattern.paletteEntries.map((entry) => entry.ref), ['A01', 'A02']);
  });

  test(
    'GenerationCompletionService uploads assets and completes a pattern',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_generation_completion_test_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));

      final requests = <http.Request>[];
      var completeAttempts = 0;
      final store = ApiSessionStore(
        fileProvider: () async =>
            File('${temporaryDirectory.path}/session.json'),
      );
      late final AuthSessionController auth;
      late final ApiClient client;
      client = ApiClient(
        baseUrl: 'http://api.example.test',
        tokenProvider: store.readAccessToken,
        deviceIdProvider: store.readOrCreateDeviceId,
        onUnauthorized: () => auth.refreshOrGuestLogin(),
        httpClient: MockClient((request) async {
          requests.add(request);
          final requestBody = request.method == 'PUT' || request.body.isEmpty
              ? const <String, dynamic>{}
              : jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path ==
                  '/api/v1/generation/generation-001/complete' &&
              completeAttempts++ == 0) {
            return http.Response(
              jsonEncode({
                'header': {'code': 9001, 'message': 'retry later'},
              }),
              200,
            );
          }
          final body = switch (request.url.path) {
            '/api/v1/auth/guest' => {
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'expiresIn': 3600,
              'user': {'userId': 'guest-1'},
            },
            '/api/v1/generation/create' => {
              'generationId': 'generation-001',
              'creditsDeducted': 0,
              'remainingBalance': 3,
              'expiresAt': 1783421800,
              'duplicated': false,
            },
            '/api/v1/media/upload-token' => {
              'uploadUrl':
                  'https://storage.example.test/${requestBody['purpose']}',
              'fileKey': '${requestBody['purpose']}-key',
              'headers': const <String, String>{},
              'expiresAt': 1783421800,
              'uploadMethod': 'PUT',
              'publicUrl': '',
              'maxFileSize': 20 * 1024 * 1024,
            },
            '/api/v1/media/report-upload' => {
              'fileUrl': 'https://cdn.example.test/${requestBody['fileKey']}',
            },
            '/api/v1/generation/generation-001/complete' => {
              'workId': 'work-001',
              'duplicated': false,
            },
            '/original' || '/pattern' => <String, Object?>{},
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
      auth = AuthSessionController(
        store: store,
        repository: AuthRepository(client),
      );
      final service = GenerationCompletionService(
        media: MediaRepository(apiClient: client, auth: auth),
        generations: GenerationRepository(apiClient: client, auth: auth),
        store: store,
        exportService: const _FakePatternExportService(),
      );

      await expectLater(
        () => service.completeGeneratedPattern(_pattern()),
        throwsA(isA<ApiException>()),
      );
      expect(await store.readPendingGenerationId(), 'generation-001');

      final result = await service.completeGeneratedPattern(_pattern());

      expect(result.workId, 'work-001');
      final createRequests = requests
          .where((request) => request.url.path == '/api/v1/generation/create')
          .toList();
      expect(createRequests, hasLength(1));
      final createRequest = createRequests.single;
      expect(jsonDecode(createRequest.body), {
        'boardSpec': '2x2',
        'sourceType': 'photo',
        'sourceId': '',
        'clientRequestId': isA<String>(),
      });
      final completeRequests = requests
          .where(
            (request) =>
                request.url.path ==
                '/api/v1/generation/generation-001/complete',
          )
          .toList();
      expect(completeRequests, hasLength(2));
      final completeRequest = completeRequests.last;
      final completeBody =
          jsonDecode(completeRequest.body) as Map<String, dynamic>;
      expect(
        completeBody['originalImageUrl'],
        'https://cdn.example.test/original-key',
      );
      expect(
        completeBody['patternImageUrl'],
        'https://cdn.example.test/pattern-key',
      );
      expect(completeBody['beadCount'], 3);
      expect(completeBody['colorCount'], 2);
      expect(completeBody['patternData'], {
        'width': 2,
        'height': 2,
        'boardSpec': '2x2',
        'pixels': [1, 2, 0, 1],
        'colorPalette': [
          {
            'index': 1,
            'hex': '#ff0000',
            'brand': 'mard',
            'code': 'A01',
            'name': '红色',
          },
          {
            'index': 2,
            'hex': '#ffffff',
            'brand': 'mard',
            'code': 'A02',
            'name': '白色',
          },
        ],
        'schemaVersion': 1,
      });
      expect(await store.readPendingGenerationId(), isNull);
    },
  );

  test(
    'startup warm-up preloads template categories, home list and detail',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_api_warm_up_test_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));

      final requests = <http.Request>[];
      final services = BackendServices(
        baseUrl: 'http://example.test',
        store: ApiSessionStore(
          fileProvider: () async =>
              File('${temporaryDirectory.path}/session.json'),
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          final body = switch (request.url.path) {
            '/api/v1/auth/guest' => {
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'expiresIn': 3600,
              'user': {'userId': 'guest-1'},
            },
            '/api/v1/system/config' => <String, Object?>{},
            '/api/v1/system/board-specs' => {'specs': const []},
            '/api/v1/system/bead-colors' => {'brands': const []},
            '/api/v1/templates/categories' => {'categories': const []},
            '/api/v1/templates' => {
              'templates': [
                {'templateId': 'template-001'},
              ],
              'page': {'total': 1, 'page': 1, 'pageSize': 20, 'hasMore': false},
            },
            '/api/v1/templates/template-001' => {
              'template': {'templateId': 'template-001'},
              'patternData': <String, Object?>{},
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

      await services.warmUp();

      final paths = requests.map((request) => request.url.path).toSet();
      expect(paths, contains('/api/v1/templates/categories'));
      expect(paths, contains('/api/v1/templates'));
      expect(paths, contains('/api/v1/templates/template-001'));

      final homeListRequest = requests.singleWhere(
        (request) => request.url.path == '/api/v1/templates',
      );
      expect(homeListRequest.url.queryParameters['scene'], 'home');
      expect(homeListRequest.url.queryParameters['page.page'], '1');
      expect(homeListRequest.url.queryParameters['page.pageSize'], '20');
    },
  );
}

class _FakePatternExportService extends PatternExportService {
  const _FakePatternExportService();

  @override
  Future<Uint8List> exportChartPngBytes(GeneratedPattern pattern) async {
    return Uint8List.fromList([1, 2, 3]);
  }
}

GeneratedPattern _pattern() {
  final red = PaletteEntry(
    name: '红色',
    ref: 'A01',
    symbol: 'R',
    color: BeadColor.fromInt(255, 0, 0, 255),
    prefix: 'mard',
  );
  final white = PaletteEntry(
    name: '白色',
    ref: 'A02',
    symbol: 'W',
    color: BeadColor.fromInt(255, 255, 255, 255),
    prefix: 'mard',
  );
  return GeneratedPattern(
    width: 2,
    height: 2,
    pixels: Uint8List.fromList([
      255,
      0,
      0,
      255,
      255,
      255,
      255,
      255,
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      255,
    ]),
    usage: const {'A01': 2, 'A02': 1},
    paletteEntries: [red, white],
    draft: DraftProject(originalImageBytes: Uint8List.fromList([1, 2, 3])),
  );
}
