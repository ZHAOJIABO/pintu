import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef ThumbnailCacheDirectoryProvider = Future<Directory> Function();

/// Keeps style thumbnails available across launches without making a cached
/// image failure block the page from falling back to the network.
class StyleThumbnailCache {
  static const _directoryName = 'style_thumbnails';

  final http.Client _httpClient;
  final ThumbnailCacheDirectoryProvider _directoryProvider;
  final Duration maxAge;
  final Map<String, Uint8List> _memory = {};
  final Map<String, Future<Uint8List>> _inFlight = {};
  Future<Directory>? _cacheDirectoryRequest;

  StyleThumbnailCache({
    http.Client? httpClient,
    ThumbnailCacheDirectoryProvider? directoryProvider,
    this.maxAge = const Duration(days: 30),
  }) : _httpClient = httpClient ?? http.Client(),
       _directoryProvider = directoryProvider ?? getTemporaryDirectory;

  Future<Uint8List> load(String url) {
    final memoryValue = _memory[url];
    if (memoryValue != null) {
      if (kDebugMode) debugPrint('[StyleThumbnailCache] memory hit');
      return Future.value(memoryValue);
    }

    return _inFlight.putIfAbsent(url, () async {
      try {
        final diskValue = await _loadFromDisk(url);
        if (diskValue != null) {
          _memory[url] = diskValue;
          if (kDebugMode) debugPrint('[StyleThumbnailCache] disk hit');
          return diskValue;
        }

        if (kDebugMode) debugPrint('[StyleThumbnailCache] network download');
        final response = await _httpClient.get(Uri.parse(url));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Style thumbnail download failed: ${response.statusCode}',
            uri: Uri.parse(url),
          );
        }

        final bytes = response.bodyBytes;
        if (bytes.isEmpty) {
          throw HttpException('Style thumbnail download returned no bytes');
        }
        _memory[url] = bytes;
        await _saveToDisk(url, bytes);
        return bytes;
      } finally {
        _inFlight.remove(url);
      }
    });
  }

  Future<void> preload(Iterable<String> urls, {int maxItems = 8}) async {
    final candidates = urls
        .where((url) => url.isNotEmpty)
        .take(maxItems)
        .toList(growable: false);
    if (kDebugMode) {
      debugPrint('[StyleThumbnailCache] preloading ${candidates.length} items');
    }
    await Future.wait(
      candidates.map((url) async {
        try {
          await load(url);
        } catch (_) {
          // Each visible thumbnail retries through its own loading state.
        }
      }),
    );
  }

  Future<Uint8List?> _loadFromDisk(String url) async {
    try {
      final file = await _fileFor(url);
      if (!await file.exists()) return null;
      final modifiedAt = await file.lastModified();
      if (DateTime.now().difference(modifiedAt) > maxAge) {
        await file.delete();
        return null;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
      await file.delete();
    } catch (_) {
      // A disk-cache failure should not keep a thumbnail from displaying.
    }
    return null;
  }

  Future<void> _saveToDisk(String url, Uint8List bytes) async {
    try {
      final file = await _fileFor(url);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Memory caching still benefits the current app session.
    }
  }

  Future<File> _fileFor(String url) async {
    final directory = await (_cacheDirectoryRequest ??=
        _createCacheDirectory());
    return File('${directory.path}/${_cacheKey(url)}.webp');
  }

  Future<Directory> _createCacheDirectory() async {
    final root = await _directoryProvider();
    return Directory('${root.path}/$_directoryName').create(recursive: true);
  }

  String _cacheKey(String value) {
    var forwardHash = 0x811c9dc5;
    var reverseHash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      forwardHash = ((forwardHash ^ codeUnit) * 0x01000193) & 0xffffffff;
    }
    for (final codeUnit in value.codeUnits.reversed) {
      reverseHash = ((reverseHash ^ codeUnit) * 0x01000193) & 0xffffffff;
    }
    return '${forwardHash.toRadixString(16)}${reverseHash.toRadixString(16)}';
  }
}
