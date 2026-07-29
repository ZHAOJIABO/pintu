import 'dart:io';
import 'dart:typed_data';

import 'package:bobobeads/services/style_thumbnail_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('persists a thumbnail and reuses it without another request', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bobobeads_style_thumbnail_cache_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    var firstRequestCount = 0;
    final firstCache = StyleThumbnailCache(
      httpClient: MockClient((request) async {
        firstRequestCount += 1;
        return http.Response.bytes(const [1, 2, 3], 200);
      }),
      directoryProvider: () async => directory,
    );

    expect(
      await firstCache.load('https://images.example.test/style.webp'),
      Uint8List.fromList(const [1, 2, 3]),
    );
    expect(firstRequestCount, 1);

    var secondRequestCount = 0;
    final secondCache = StyleThumbnailCache(
      httpClient: MockClient((request) async {
        secondRequestCount += 1;
        return http.Response.bytes(const [4, 5, 6], 200);
      }),
      directoryProvider: () async => directory,
    );

    expect(
      await secondCache.load('https://images.example.test/style.webp'),
      Uint8List.fromList(const [1, 2, 3]),
    );
    expect(secondRequestCount, 0);
  });
}
