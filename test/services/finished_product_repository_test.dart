import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bobobeads/services/api/api_client.dart';
import 'package:bobobeads/services/api/api_repositories.dart';
import 'package:bobobeads/services/api/api_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<ApiSessionStore> createStore() async {
    final directory = await Directory.systemTemp.createTemp(
      'bobobeads_finished_product_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    return ApiSessionStore(
      fileProvider: () async => File('${directory.path}/session.json'),
    );
  }

  test(
    'uploads and creates one finished product through the signed media flow',
    () async {
      final requests = <http.Request>[];
      late final AuthSessionController auth;
      final client = ApiClient(
        baseUrl: 'http://api.example.test',
        tokenProvider: () async => null,
        deviceIdProvider: () async => 'device-1',
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
              'uploadUrl': 'https://storage.example.test/finished.jpg',
              'fileKey': 'finished_product/guest-1/request-1.jpg',
              'headers': {'Content-Type': 'image/jpeg'},
              'maxFileSize': 1024,
            },
            '/api/v1/media/report-upload' => const <String, Object?>{},
            '/api/v1/finished-products' => {
              'item': {
                'finishedProductId': 'finished-1',
                'imageUrl': 'https://cdn.example.test/finished.jpg',
                'thumbnailUrl': 'https://cdn.example.test/finished-thumb.jpg',
                'createdAt': 1785209431,
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
        store: await createStore(),
        repository: AuthRepository(client),
      );
      final media = MediaRepository(apiClient: client, auth: auth);
      final repository = FinishedProductRepository(
        apiClient: client,
        auth: auth,
        media: media,
      );

      final item = await repository.uploadAndCreate(
        bytes: Uint8List.fromList([1, 2, 3]),
        clientRequestId: 'request-1',
      );

      expect(item.finishedProductId, 'finished-1');
      final tokenRequest = requests.firstWhere(
        (request) => request.url.path == '/api/v1/media/upload-token',
      );
      expect(jsonDecode(tokenRequest.body), {
        'file_name': 'finished-product.jpg',
        'content_type': 'image/jpeg',
        'purpose': 'finished_product',
        'client_request_id': 'request-1',
      });
      final storageRequest = requests.firstWhere(
        (request) => request.url.host == 'storage.example.test',
      );
      expect(storageRequest.method, 'PUT');
      expect(storageRequest.headers.containsKey('authorization'), isFalse);
      final createRequest = requests.firstWhere(
        (request) => request.url.path == '/api/v1/finished-products',
      );
      expect(jsonDecode(createRequest.body), {
        'media_file_key': 'finished_product/guest-1/request-1.jpg',
        'client_request_id': 'request-1',
      });
    },
  );

  test(
    'rejects an export larger than the server-issued limit before upload',
    () async {
      late final AuthSessionController auth;
      var storageTouched = false;
      final client = ApiClient(
        baseUrl: 'http://api.example.test',
        tokenProvider: () async => null,
        deviceIdProvider: () async => 'device-1',
        onUnauthorized: () => auth.refreshOrGuestLogin(),
        httpClient: MockClient((request) async {
          if (request.url.host == 'storage.example.test') {
            storageTouched = true;
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
              'uploadUrl': 'https://storage.example.test/finished.jpg',
              'fileKey': 'finished_product/guest-1/request-2.jpg',
              'headers': {'Content-Type': 'image/jpeg'},
              'maxFileSize': 2,
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
        store: await createStore(),
        repository: AuthRepository(client),
      );
      final media = MediaRepository(apiClient: client, auth: auth);
      final repository = FinishedProductRepository(
        apiClient: client,
        auth: auth,
        media: media,
      );

      await expectLater(
        repository.uploadAndCreate(
          bytes: Uint8List.fromList([1, 2, 3]),
          clientRequestId: 'request-2',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(storageTouched, isFalse);
    },
  );

  test('rejects a successful create response without an item', () async {
    late final AuthSessionController auth;
    final client = ApiClient(
      baseUrl: 'http://api.example.test',
      tokenProvider: () async => null,
      deviceIdProvider: () async => 'device-1',
      onUnauthorized: () => auth.refreshOrGuestLogin(),
      httpClient: MockClient((request) async {
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
            'uploadUrl': 'https://storage.example.test/finished.jpg',
            'fileKey': 'finished_product/guest-1/request-invalid.jpg',
            'headers': {'Content-Type': 'image/jpeg'},
            'maxFileSize': 1024,
          },
          '/api/v1/media/report-upload' => const <String, Object?>{},
          '/api/v1/finished-products' => const <String, Object?>{},
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
      store: await createStore(),
      repository: AuthRepository(client),
    );
    final repository = FinishedProductRepository(
      apiClient: client,
      auth: auth,
      media: MediaRepository(apiClient: client, auth: auth),
    );

    await expectLater(
      repository.uploadAndCreate(
        bytes: Uint8List.fromList([1, 2, 3]),
        clientRequestId: 'request-invalid',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
