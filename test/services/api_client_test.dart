import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/draft_project.dart';
import 'package:bobobeads/models/generated_pattern.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/services/ai_style_transfer_service.dart';
import 'package:bobobeads/services/api/api_client.dart';
import 'package:bobobeads/services/api/generation_completion_service.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/api/api_repositories.dart';
import 'package:bobobeads/services/api/api_scope.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:bobobeads/services/api/guest_credential_store.dart';
import 'package:bobobeads/services/api/vendor_identifier.dart';
import 'package:bobobeads/services/pattern_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

void main() {
  test('ApiClient defaults to the production API origin', () {
    expect(ApiClient.defaultBaseUrl, 'https://appbobo.cn');
  });

  test('ApiClient sends common headers and parses successful body', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'http://example.test',
      tokenProvider: () async => 'token-1',
      deviceIdProvider: () async => 'device-1',
      platform: 'ios',
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

  test(
    'guest login sends a persistent credential with iOS identifiers',
    () async {
      late http.Request captured;
      final client = ApiClient(
        baseUrl: 'http://example.test',
        tokenProvider: () async => null,
        deviceIdProvider: () async => 'legacy-device-id',
        platform: 'ios',
        httpClient: MockClient((request) async {
          captured = request;
          return _jsonResponse({
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': '8635871597563'},
          });
        }),
      );

      final session = await AuthRepository(client).guestLogin(
        const DeviceIdentifiers(idfv: '6F3B8D2A-58E3-4EF8-9C1A-815CE8C5D3D4'),
        guestCredential: 'guest-credential',
      );

      expect(captured.url.path, '/api/v1/auth/guest');
      expect(captured.headers['X-Platform'], 'ios');
      expect(captured.headers.containsKey('X-Device-Id'), isFalse);
      expect(jsonDecode(captured.body), {
        'header': {
          'guestCredential': 'guest-credential',
          'device': {'idfv': '6F3B8D2A-58E3-4EF8-9C1A-815CE8C5D3D4'},
        },
      });
      expect(jsonDecode(captured.body), isNot(contains('deviceId')));
      expect(session.user.userId, '8635871597563');
    },
  );

  test(
    'guest login sends Android identifiers in server priority order',
    () async {
      late http.Request captured;
      final client = ApiClient(
        baseUrl: 'http://example.test',
        tokenProvider: () async => null,
        deviceIdProvider: () async => 'legacy-device-id',
        platform: 'android',
        httpClient: MockClient((request) async {
          captured = request;
          return _jsonResponse({
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'user': {'userId': '8635871597563'},
          });
        }),
      );

      await AuthRepository(client).guestLogin(
        const DeviceIdentifiers(androidId: 'android-id', oaid: 'oaid-value'),
        guestCredential: 'guest-credential',
      );

      expect(captured.headers['X-Platform'], 'android');
      expect(captured.headers.containsKey('X-Device-Id'), isFalse);
      expect(jsonDecode(captured.body), {
        'header': {
          'guestCredential': 'guest-credential',
          'device': {'androidId': 'android-id'},
        },
      });
    },
  );

  test('guest login uses the fallback identifier only when needed', () {
    expect(
      const DeviceIdentifiers(
        androidId: '',
        oaid: 'oaid-value',
      ).toGuestLoginBody('android', guestCredential: 'guest-credential'),
      {
        'header': {
          'guestCredential': 'guest-credential',
          'device': {'oaid': 'oaid-value'},
        },
      },
    );
    expect(
      const DeviceIdentifiers(
        idfv: '',
        idfa: 'idfa-value',
      ).toGuestLoginBody('ios', guestCredential: 'guest-credential'),
      {
        'header': {
          'guestCredential': 'guest-credential',
          'device': {'idfa': 'idfa-value'},
        },
      },
    );
  });

  test(
    'ApiClient sends the blind box request header as the only GET body',
    () async {
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
              'template': const {},
              'patternData': const {},
            }),
            200,
          );
        }),
      );

      await client.get(
        '/api/v1/templates/random',
        body: const {'header': <String, Object?>{}},
      );

      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/v1/templates/random');
      expect(jsonDecode(captured.body), {'header': {}});
      expect(captured.headers['Content-Type'], 'application/json');
    },
  );

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
    'AI style transfer uploads, submits and polls with documented fields',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_ai_style_test_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));

      final requests = <http.Request>[];
      final store = ApiSessionStore(
        fileProvider: () async => File('${temporaryDirectory.path}/session'),
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
          if (request.url.host == 'storage.example.test') {
            return http.Response('', 200);
          }
          final body = switch (request.url.path) {
            '/api/v1/auth/guest' => {
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'expiresIn': 3600,
              'user': {'userId': 'guest-1'},
            },
            '/api/v1/media/upload-token' => {
              'uploadUrl': 'https://storage.example.test/style-input.png',
              'fileKey': 'style_input/style-input.png',
              'headers': {'Content-Type': 'image/png'},
              'uploadMethod': 'PUT',
              'maxFileSize': 20 * 1024 * 1024,
            },
            '/api/v1/media/report-upload' => const <String, Object?>{},
            '/api/v1/ai/style-generations' => {
              'taskId': 'style-task-1',
              'status': 0,
              'creditsDeducted': 1,
              'remainingBalance': 9,
              'duplicated': false,
            },
            '/api/v1/ai/style-generations/style-task-1' => {
              'task': {
                'taskId': 'style-task-1',
                'styleId': '2',
                'status': 2,
                'outputImageUrl': 'https://cdn.example.test/output.png',
                'createdAt': '1785209431',
                'completedAt': '1785209432',
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
      auth = AuthSessionController(
        store: store,
        repository: AuthRepository(client),
      );
      final service = AiStyleTransferService(
        media: MediaRepository(apiClient: client, auth: auth),
        generations: AIGenerationRepository(apiClient: client, auth: auth),
        store: store,
      );

      final task = await service.submitAndWait(
        styleId: '2',
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(task.isSucceeded, isTrue);
      expect(task.createdAt, 1785209431);
      expect(await store.readPendingAiTaskId(), isNull);
      final uploadToken = requests.firstWhere(
        (request) => request.url.path == '/api/v1/media/upload-token',
      );
      expect(jsonDecode(uploadToken.body), {
        'file_name': 'style-input.png',
        'content_type': 'image/png',
        'purpose': 'style_input',
      });
      final storageRequest = requests.firstWhere(
        (request) => request.url.host == 'storage.example.test',
      );
      expect(storageRequest.method, 'PUT');
      expect(storageRequest.headers.containsKey('Authorization'), isFalse);
      final report = requests.firstWhere(
        (request) => request.url.path == '/api/v1/media/report-upload',
      );
      expect(jsonDecode(report.body), {
        'file_key': 'style_input/style-input.png',
        'file_size': 3,
      });
      final submission = requests.firstWhere(
        (request) => request.url.path == '/api/v1/ai/style-generations',
      );
      expect(jsonDecode(submission.body), {
        'style_id': '2',
        'input_file_key': 'style_input/style-input.png',
        'client_request_id': isA<String>(),
      });
    },
  );

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

  test(
    'expired persisted access token refreshes before another guest login',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_auth_expiry_test_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));

      final sessionFile = File('${temporaryDirectory.path}/session.json');
      await sessionFile.writeAsString(
        jsonEncode({
          'session': {
            'accessToken': 'expired-access-token',
            'refreshToken': 'refresh-token',
            'expiresIn': 3600,
            'accessTokenExpiresAtMs': DateTime.now()
                .subtract(const Duration(minutes: 1))
                .millisecondsSinceEpoch,
            'user': {'userId': 'guest-1'},
          },
        }),
      );
      final store = ApiSessionStore(fileProvider: () async => sessionFile);
      var refreshRequests = 0;
      var guestRequests = 0;
      late final AuthSessionController auth;
      late final ApiClient client;
      client = ApiClient(
        baseUrl: 'http://api.example.test',
        tokenProvider: store.readAccessToken,
        deviceIdProvider: store.readOrCreateDeviceId,
        onUnauthorized: () => auth.refreshOrGuestLogin(),
        httpClient: MockClient((request) async {
          switch (request.url.path) {
            case '/api/v1/auth/refresh':
              refreshRequests++;
              expect(jsonDecode(request.body), {
                'refreshToken': 'refresh-token',
              });
              return _jsonResponse({
                'accessToken': 'fresh-access-token',
                'refreshToken': 'fresh-refresh-token',
                'expiresIn': 3600,
                'user': {'userId': 'guest-1'},
              });
            case '/api/v1/auth/guest':
              guestRequests++;
              return _jsonResponse(const {});
            default:
              throw StateError('Unexpected request: ${request.url}');
          }
        }),
      );
      auth = AuthSessionController(
        store: store,
        repository: AuthRepository(client),
      );

      await auth.ensureSignedIn();
      await auth.ensureSignedIn();

      expect(refreshRequests, 1);
      expect(guestRequests, 0);
      final session = await store.readSession();
      expect(session?.accessToken, 'fresh-access-token');
      expect(session?.refreshToken, 'fresh-refresh-token');
      expect(session?.accessTokenExpiresAt, isNotNull);
      expect(session!.hasValidAccessToken(), isTrue);
    },
  );

  test('refresh fallback reuses one stable IDFV for guest logins', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'bobobeads_guest_device_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));

    final sessionFile = File('${temporaryDirectory.path}/session.json');
    const idfv = '6F3B8D2A-58E3-4EF8-9C1A-815CE8C5D3D4';
    final store = ApiSessionStore(
      fileProvider: () async => sessionFile,
      deviceIdentifiersProvider: () async =>
          const DeviceIdentifiers(idfv: idfv),
    );
    await store.saveSession(
      AuthSession(
        accessToken: 'expired-access-token',
        refreshToken: 'bad-refresh-token',
        expiresIn: 3600,
        accessTokenExpiresAt: DateTime.now().subtract(
          const Duration(minutes: 1),
        ),
        user: const ApiUser(
          userId: 'guest-1',
          nickname: '',
          avatarUrl: '',
          phone: '',
          isVip: false,
        ),
      ),
    );

    final guestIdfvs = <String>[];
    late final AuthSessionController auth;
    late final ApiClient client;
    client = ApiClient(
      baseUrl: 'http://api.example.test',
      tokenProvider: store.readAccessToken,
      deviceIdProvider: store.readOrCreateDeviceId,
      platform: 'ios',
      onUnauthorized: () => auth.refreshOrGuestLogin(),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          return http.Response('expired refresh token', 401);
        }
        if (request.url.path == '/api/v1/auth/guest') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final device =
              (body['header'] as Map<String, dynamic>)['device']
                  as Map<String, dynamic>;
          expect(body, isNot(contains('deviceId')));
          guestIdfvs.add(device['idfv'] as String);
          return _jsonResponse({
            'accessToken': 'guest-access-${guestIdfvs.length}',
            'refreshToken': 'guest-refresh-${guestIdfvs.length}',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          });
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    auth = AuthSessionController(
      store: store,
      repository: AuthRepository(client),
    );

    expect(await auth.refreshOrGuestLogin(), isTrue);
    final firstGuestSession = await store.readSession();
    expect(firstGuestSession?.accessToken, 'guest-access-1');
    expect(firstGuestSession?.refreshToken, 'guest-refresh-1');
    expect(firstGuestSession?.accessTokenExpiresAt, isNotNull);
    await store.saveSession(
      AuthSession(
        accessToken: 'expired-access-token',
        refreshToken: 'bad-refresh-token',
        expiresIn: 3600,
        accessTokenExpiresAt: DateTime.now().subtract(
          const Duration(minutes: 1),
        ),
        user: (await store.readSession())!.user,
      ),
    );
    expect(await auth.refreshOrGuestLogin(), isTrue);

    expect(guestIdfvs, [idfv, idfv]);
    expect(await store.readOrCreateDeviceId(), 'ios-$idfv');
  });

  test('valid access token skips both refresh and guest login', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'bobobeads_valid_auth_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));

    final sessionFile = File('${temporaryDirectory.path}/session.json');
    final store = ApiSessionStore(fileProvider: () async => sessionFile);
    await store.saveSession(
      AuthSession(
        accessToken: 'valid-access-token',
        refreshToken: 'refresh-token',
        expiresIn: 3600,
        accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: const ApiUser(
          userId: 'guest-1',
          nickname: '',
          avatarUrl: '',
          phone: '',
          isVip: false,
        ),
      ),
    );
    late final AuthSessionController auth;
    late final ApiClient client;
    client = ApiClient(
      baseUrl: 'http://api.example.test',
      tokenProvider: store.readAccessToken,
      deviceIdProvider: store.readOrCreateDeviceId,
      onUnauthorized: () => auth.refreshOrGuestLogin(),
      httpClient: MockClient(
        (request) => throw StateError('Unexpected request: ${request.url}'),
      ),
    );
    auth = AuthSessionController(
      store: store,
      repository: AuthRepository(client),
    );

    await auth.ensureSignedIn();
    await auth.ensureSignedIn();
  });

  test(
    'legacy persisted session refreshes before protected requests',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_legacy_auth_test_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));

      final sessionFile = File('${temporaryDirectory.path}/session.json');
      await sessionFile.writeAsString(
        jsonEncode({
          'session': {
            'accessToken': 'legacy-access-token',
            'refreshToken': 'legacy-refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          },
        }),
      );
      final store = ApiSessionStore(fileProvider: () async => sessionFile);
      var refreshRequests = 0;
      late final AuthSessionController auth;
      late final ApiClient client;
      client = ApiClient(
        baseUrl: 'http://api.example.test',
        tokenProvider: store.readAccessToken,
        deviceIdProvider: store.readOrCreateDeviceId,
        onUnauthorized: () => auth.refreshOrGuestLogin(),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/refresh');
          refreshRequests++;
          return _jsonResponse({
            'accessToken': 'fresh-access-token',
            'refreshToken': 'fresh-refresh-token',
            'expiresIn': 3600,
            'user': {'userId': 'guest-1'},
          });
        }),
      );
      auth = AuthSessionController(
        store: store,
        repository: AuthRepository(client),
      );

      await auth.ensureSignedIn();

      expect(refreshRequests, 1);
      expect((await store.readSession())?.hasValidAccessToken(), isTrue);
    },
  );

  test('refresh keeps the prior token when the response omits it', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'bobobeads_refresh_token_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));

    final sessionFile = File('${temporaryDirectory.path}/session.json');
    final store = ApiSessionStore(fileProvider: () async => sessionFile);
    final expiredAt = DateTime.now().subtract(const Duration(minutes: 1));
    await store.saveSession(
      AuthSession(
        accessToken: 'expired-access-token',
        refreshToken: 'retained-refresh-token',
        expiresIn: 3600,
        accessTokenExpiresAt: expiredAt,
        user: const ApiUser(
          userId: 'guest-1',
          nickname: '',
          avatarUrl: '',
          phone: '',
          isVip: false,
        ),
      ),
    );
    var refreshRequests = 0;
    late final AuthSessionController auth;
    late final ApiClient client;
    client = ApiClient(
      baseUrl: 'http://api.example.test',
      tokenProvider: store.readAccessToken,
      deviceIdProvider: store.readOrCreateDeviceId,
      onUnauthorized: () => auth.refreshOrGuestLogin(),
      httpClient: MockClient((request) async {
        expect(jsonDecode(request.body), {
          'refreshToken': 'retained-refresh-token',
        });
        refreshRequests++;
        return _jsonResponse({
          'accessToken': 'fresh-access-token-$refreshRequests',
          'expiresIn': 3600,
          'user': {'userId': 'guest-1'},
        });
      }),
    );
    auth = AuthSessionController(
      store: store,
      repository: AuthRepository(client),
    );

    await auth.ensureSignedIn();
    expect((await store.readSession())?.refreshToken, 'retained-refresh-token');
    await store.saveSession(
      AuthSession(
        accessToken: 'expired-again',
        refreshToken: (await store.readSession())!.refreshToken,
        expiresIn: 3600,
        accessTokenExpiresAt: expiredAt,
        user: (await store.readSession())!.user,
      ),
    );
    await auth.ensureSignedIn();

    expect(refreshRequests, 2);
  });

  test(
    'device id is generated once across concurrent store instances',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_device_id_test_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));

      final sessionFile = File('${temporaryDirectory.path}/session.json');
      final firstStore = ApiSessionStore(fileProvider: () async => sessionFile);
      final secondStore = ApiSessionStore(
        fileProvider: () async => sessionFile,
      );

      final deviceIds = await Future.wait([
        firstStore.readOrCreateDeviceId(),
        secondStore.readOrCreateDeviceId(),
        firstStore.readOrCreateDeviceId(),
      ]);

      expect(deviceIds.toSet(), hasLength(1));
      expect(deviceIds.first, matches(r'^ios-[0-9a-f-]{36}$'));
      expect(
        await ApiSessionStore(
          fileProvider: () async => sessionFile,
        ).readOrCreateDeviceId(),
        deviceIds.first,
      );
    },
  );

  test('device id follows an unchanged IDFV across app-data resets', () async {
    final firstDirectory = await Directory.systemTemp.createTemp(
      'bobobeads_idfv_first_test_',
    );
    final secondDirectory = await Directory.systemTemp.createTemp(
      'bobobeads_idfv_second_test_',
    );
    addTearDown(() async {
      await firstDirectory.delete(recursive: true);
      await secondDirectory.delete(recursive: true);
    });

    Future<DeviceIdentifiers> readIdentifiers() async =>
        const DeviceIdentifiers(idfv: '6F3B8D2A-58E3-4EF8-9C1A-815CE8C5D3D4');
    final firstStore = ApiSessionStore(
      fileProvider: () async => File('${firstDirectory.path}/session.json'),
      deviceIdentifiersProvider: readIdentifiers,
    );
    final secondStore = ApiSessionStore(
      fileProvider: () async => File('${secondDirectory.path}/session.json'),
      deviceIdentifiersProvider: readIdentifiers,
    );

    expect(
      await firstStore.readOrCreateDeviceId(),
      'ios-6F3B8D2A-58E3-4EF8-9C1A-815CE8C5D3D4',
    );
    expect(
      await secondStore.readOrCreateDeviceId(),
      'ios-6F3B8D2A-58E3-4EF8-9C1A-815CE8C5D3D4',
    );
  });

  test(
    'guest credential survives an application-data reset via secure storage',
    () async {
      final firstDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_guest_credential_first_test_',
      );
      final secondDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_guest_credential_second_test_',
      );
      addTearDown(() async {
        await firstDirectory.delete(recursive: true);
        await secondDirectory.delete(recursive: true);
      });
      final secureStorage = _MemoryGuestCredentialStore();
      final firstStore = ApiSessionStore(
        fileProvider: () async => File('${firstDirectory.path}/session.json'),
        guestCredentialStore: secureStorage,
      );
      final reinstalledStore = ApiSessionStore(
        fileProvider: () async => File('${secondDirectory.path}/session.json'),
        guestCredentialStore: secureStorage,
      );

      final credential = await firstStore.readOrCreateGuestCredential();

      expect(await reinstalledStore.readOrCreateGuestCredential(), credential);
    },
  );

  test(
    'guest credential is created once across concurrent store instances',
    () async {
      final secureStorage = _MemoryGuestCredentialStore();
      final firstStore = ApiSessionStore(guestCredentialStore: secureStorage);
      final secondStore = ApiSessionStore(guestCredentialStore: secureStorage);

      final credentials = await Future.wait([
        firstStore.readOrCreateGuestCredential(),
        secondStore.readOrCreateGuestCredential(),
        firstStore.readOrCreateGuestCredential(),
      ]);

      expect(credentials.toSet(), hasLength(1));
      expect(secureStorage.writeCount, 1);
    },
  );

  test('device id creation retries after a transient file failure', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'bobobeads_device_retry_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));

    final sessionFile = File('${temporaryDirectory.path}/session.json');
    final deviceDirectory = Directory('${sessionFile.path}.device_id');
    await deviceDirectory.create();
    final store = ApiSessionStore(fileProvider: () async => sessionFile);

    await expectLater(
      store.readOrCreateDeviceId(),
      throwsA(isA<FileSystemException>()),
    );
    await deviceDirectory.delete();

    final deviceId = await store.readOrCreateDeviceId();

    expect(deviceId, matches(r'^ios-[0-9a-f-]{36}$'));
  });

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
    'PatternExportService renders compact color blocks without chart lines',
    () async {
      final bytes = await const PatternExportService()
          .exportChartThumbnailPngBytes(_pattern());
      final image = img.decodePng(bytes);

      expect(image, isNotNull);
      expect(image!.width, 300);
      expect(image.height, 300);
      expect(_pixelAt(image, 75, 75), [255, 0, 0, 255]);
      expect(_pixelAt(image, 225, 75), [255, 255, 255, 255]);
      expect(_pixelAt(image, 75, 225), [255, 255, 255, 255]);
      expect(_pixelAt(image, 225, 225), [255, 0, 0, 255]);
    },
  );

  test(
    'GenerationRepository defaults an omitted thumbnailUrl to empty',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_complete_default_thumbnail_test_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));

      late final AuthSessionController auth;
      late final http.Request completeRequest;
      late final ApiClient client;
      client = ApiClient(
        baseUrl: 'http://api.example.test',
        tokenProvider: () async => 'access-token',
        deviceIdProvider: () async => 'device-1',
        onUnauthorized: () => auth.refreshOrGuestLogin(),
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/auth/guest') {
            return http.Response(
              jsonEncode({
                'header': {'code': 0, 'message': 'success'},
                'accessToken': 'access-token',
                'refreshToken': 'refresh-token',
                'expiresIn': 3600,
                'user': {'userId': 'guest-1'},
              }),
              200,
            );
          }
          completeRequest = request;
          return http.Response(
            jsonEncode({
              'header': {'code': 0, 'message': 'success'},
              'workId': 'work-001',
              'duplicated': false,
            }),
            200,
          );
        }),
      );
      auth = AuthSessionController(
        store: ApiSessionStore(
          fileProvider: () async =>
              File('${temporaryDirectory.path}/session.json'),
        ),
        repository: AuthRepository(client),
      );

      await GenerationRepository(
        apiClient: client,
        auth: auth,
      ).completeGeneration(
        generationId: 'generation-001',
        title: '拼豆图纸',
        originalImageUrl: 'https://cdn.example.test/original.png',
        patternImageUrl: 'https://cdn.example.test/pattern.png',
        patternData: PatternData.fromGeneratedPattern(_pattern()),
        beadCount: 3,
        colorCount: 2,
      );

      final body = jsonDecode(completeRequest.body) as Map<String, dynamic>;
      expect(body['thumbnailUrl'], '');
    },
  );

  test(
    'GenerationCompletionService creates a new attempt after a failed click',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'bobobeads_generation_completion_test_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));

      final requests = <http.Request>[];
      final diagnostics = <Map<String, Object?>>[];
      var completeAttempts = 0;
      var generationCreateAttempts = 0;
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
              'generationId': 'generation-00${++generationCreateAttempts}',
              'creditsDeducted': 0,
              'remainingBalance': 3,
              'expiresAt': 1783421800,
              'duplicated': false,
            },
            '/api/v1/media/upload-token' => {
              'uploadUrl':
                  'https://storage.example.test/${requestBody['file_name']}',
              'fileKey': '${requestBody['file_name']}-key',
              'headers': const <String, String>{},
              'expiresAt': 1783421800,
              'uploadMethod': 'PUT',
              'publicUrl': '',
              'maxFileSize': 20 * 1024 * 1024,
            },
            '/api/v1/media/report-upload' => {
              'fileUrl': 'https://cdn.example.test/${requestBody['file_key']}',
            },
            '/api/v1/generation/generation-001/complete' => {
              'workId': 'work-001',
              'duplicated': false,
            },
            '/api/v1/generation/generation-002/complete' => {
              'workId': 'work-002',
              'duplicated': false,
            },
            '/generation-source.png' ||
            '/pattern-preview.png' ||
            '/pattern-thumbnail.png' => <String, Object?>{},
            _ => throw StateError('Unexpected request: ${request.url}'),
          };
          return http.Response(
            jsonEncode({
              'header': {
                'code': 0,
                'message': 'success',
                'traceId': 'trace${request.url.path}',
              },
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
        diagnosticLogger: diagnostics.add,
      );

      final clientRequestId = await service.startNewAttempt();
      await expectLater(
        () => service.completeGeneratedPattern(_pattern()),
        throwsA(isA<ApiException>()),
      );
      expect(await store.readPendingGenerationId(), 'generation-001');

      final secondClientRequestId = await service.startNewAttempt();
      expect(secondClientRequestId, isNot(clientRequestId));
      final result = await service.completeGeneratedPattern(_pattern());

      expect(result.workId, 'work-002');
      final createRequests = requests
          .where((request) => request.url.path == '/api/v1/generation/create')
          .toList();
      expect(createRequests, hasLength(2));
      expect(jsonDecode(createRequests.first.body), {
        'boardSpec': '2x2',
        'sourceType': 'photo',
        'sourceId': '',
        'clientRequestId': isA<String>(),
      });
      final createRequestIds = createRequests
          .map(
            (request) =>
                (jsonDecode(request.body)
                    as Map<String, dynamic>)['clientRequestId'],
          )
          .toList();
      expect(createRequestIds, [clientRequestId, secondClientRequestId]);
      final completeRequests = requests
          .where(
            (request) =>
                request.url.path.startsWith('/api/v1/generation/') &&
                request.url.path.endsWith('/complete'),
          )
          .toList();
      expect(completeRequests, hasLength(2));
      final completeRequest = completeRequests.last;
      final completeBody =
          jsonDecode(completeRequest.body) as Map<String, dynamic>;
      expect(
        completeBody['originalImageUrl'],
        'https://cdn.example.test/generation-source.png-key',
      );
      expect(
        completeBody['patternImageUrl'],
        'https://cdn.example.test/pattern-preview.png-key',
      );
      expect(
        completeBody['thumbnailUrl'],
        'https://cdn.example.test/pattern-thumbnail.png-key',
      );
      final uploadTokenRequests = requests
          .where((request) => request.url.path == '/api/v1/media/upload-token')
          .map((request) => jsonDecode(request.body) as Map<String, dynamic>)
          .toList();
      expect(
        uploadTokenRequests.map((request) => request['file_name']).toList(),
        [
          'generation-source.png',
          'pattern-preview.png',
          'pattern-thumbnail.png',
          'generation-source.png',
          'pattern-preview.png',
          'pattern-thumbnail.png',
        ],
      );
      expect(
        uploadTokenRequests
            .where((request) => request['file_name'] == 'pattern-thumbnail.png')
            .map((request) => request['purpose'])
            .toList(),
        ['pattern', 'pattern'],
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
      final clicks = diagnostics
          .where((event) => event['event'] == 'click')
          .toList();
      expect(clicks, hasLength(2));
      expect(clicks.first['clientRequestId'], clientRequestId);
      expect(clicks.first['header.code'], isNull);
      expect(clicks.first['duplicated'], isNull);
      expect(clicks.first['generationId'], isNull);
      expect(clicks.first['traceId'], isNull);
      expect(clicks.first['isRetry'], false);
      expect(clicks.last['clientRequestId'], secondClientRequestId);
      expect(clicks.last['generationId'], isNull);
      expect(clicks.last['isRetry'], false);

      final createEvents = diagnostics
          .where((event) => event['event'] == 'create_response')
          .toList();
      expect(createEvents, hasLength(2));
      final createEvent = createEvents.last;
      expect(createEvent['clientRequestId'], secondClientRequestId);
      expect(createEvent['header.code'], 0);
      expect(createEvent['duplicated'], false);
      expect(createEvent['generationId'], 'generation-002');
      expect(createEvent['traceId'], 'trace/api/v1/generation/create');

      final completeEvent = diagnostics.singleWhere(
        (event) => event['event'] == 'complete_response',
      );
      expect(completeEvent['clientRequestId'], secondClientRequestId);
      expect(completeEvent['header.code'], 0);
      expect(completeEvent['duplicated'], false);
      expect(completeEvent['generationId'], 'generation-002');
      expect(
        completeEvent['traceId'],
        'trace/api/v1/generation/generation-002/complete',
      );
    },
  );

  test(
    'startup warm-up preloads the style covers for the first screen',
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
          if (request.url.host == 'images.example.test') {
            return http.Response.bytes(const [1, 2, 3], 200);
          }
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
            '/api/v1/ai/styles' => {
              'styles': List.generate(
                10,
                (index) => {
                  'styleId': 'style-$index',
                  'styleKey': 'style_$index',
                  'coverUrl': 'https://images.example.test/style-$index.webp',
                },
              ),
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
      expect(paths, contains('/api/v1/ai/styles'));
      expect(
        requests.where((request) => request.url.host == 'images.example.test'),
        hasLength(8),
      );

      final homeListRequest = requests.singleWhere(
        (request) => request.url.path == '/api/v1/templates',
      );
      expect(homeListRequest.url.queryParameters['scene'], 'home');
      expect(homeListRequest.url.queryParameters['page.page'], '1');
      expect(homeListRequest.url.queryParameters['page.pageSize'], '20');
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
  );
}

class _FakePatternExportService extends PatternExportService {
  const _FakePatternExportService();

  @override
  Future<Uint8List> exportChartPngBytes(
    GeneratedPattern pattern, {
    Uint8List? watermarkPngBytes,
  }) async {
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<Uint8List> exportChartThumbnailPngBytes(
    GeneratedPattern pattern,
  ) async {
    return Uint8List.fromList([4, 5, 6]);
  }
}

class _MemoryGuestCredentialStore implements GuestCredentialStore {
  String? value;
  int writeCount = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    writeCount++;
    this.value = value;
  }
}

List<int> _pixelAt(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), pixel.a.toInt()];
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
