import 'dart:convert';
import 'dart:typed_data';

import 'package:bobobeads/services/api/api_client.dart';
import 'package:bobobeads/services/api/api_repositories.dart';
import 'package:bobobeads/services/export_watermark_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ExportWatermarkPolicy', () {
    test('parses the server-provided online watermark URL', () {
      final policy = ExportWatermarkPolicy.fromConfigs({
        'export_watermark_mode': 'online',
        'export_watermark_url': 'https://appbobo.cn/watermarks/online.png',
      });

      expect(policy.mode, ExportWatermarkMode.online);
      expect(policy.url, 'https://appbobo.cn/watermarks/online.png');
    });

    test('treats missing or unsupported settings as no watermark', () {
      expect(
        ExportWatermarkPolicy.fromConfigs({
          'export_watermark_mode': 'marketing',
        }),
        const ExportWatermarkPolicy.none(),
      );
      expect(
        ExportWatermarkPolicy.fromConfigs({
          'export_watermark_mode': 'unexpected',
          'export_watermark_url': 'https://appbobo.cn/watermarks/online.png',
        }),
        const ExportWatermarkPolicy.none(),
      );
    });
  });

  test(
    'refreshes the policy and downloads only the configured watermark',
    () async {
      final requests = <http.Request>[];
      final client = _apiClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/system/config') {
          return _jsonResponse({
            'configs': {
              'export_watermark_mode': 'marketing',
              'export_watermark_url': 'https://cdn.example.test/marketing.png',
            },
          });
        }
        if (request.url.host == 'cdn.example.test') {
          return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
        }
        throw StateError('Unexpected request: ${request.url}');
      });
      final service = ExportWatermarkService(
        system: SystemRepository(client),
        client: client,
      );

      final watermark = await service.loadWatermarkBytes();

      expect(watermark, Uint8List.fromList([1, 2, 3]));
      expect(requests.map((request) => request.url.toString()), [
        'http://api.example.test/api/v1/system/config',
        'https://cdn.example.test/marketing.png',
      ]);
    },
  );

  test(
    'does not download an image when the server disables watermarks',
    () async {
      final requests = <http.Request>[];
      final client = _apiClient((request) async {
        requests.add(request);
        return _jsonResponse({
          'configs': {
            'export_watermark_mode': 'none',
            'export_watermark_url': '',
          },
        });
      });
      final service = ExportWatermarkService(
        system: SystemRepository(client),
        client: client,
      );

      expect(await service.loadWatermarkBytes(), isNull);
      expect(requests, hasLength(1));
    },
  );
}

ApiClient _apiClient(Future<http.Response> Function(http.Request) responder) {
  return ApiClient(
    baseUrl: 'http://api.example.test',
    httpClient: MockClient(responder),
    tokenProvider: () async => null,
    deviceIdProvider: () async => 'test-device',
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
