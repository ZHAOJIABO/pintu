import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_models.dart';

typedef TokenProvider = Future<String?> Function();
typedef DeviceIdProvider = Future<String> Function();
typedef UnauthorizedHandler = Future<bool> Function();

class ApiClient {
  static const defaultBaseUrl = String.fromEnvironment(
    'BOBOBEADS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  final Uri baseUri;
  final http.Client httpClient;
  final TokenProvider tokenProvider;
  final DeviceIdProvider deviceIdProvider;
  final UnauthorizedHandler? onUnauthorized;
  final String appVersion;
  final String platform;

  ApiClient({
    String baseUrl = defaultBaseUrl,
    http.Client? httpClient,
    required this.tokenProvider,
    required this.deviceIdProvider,
    this.onUnauthorized,
    this.appVersion = '1.0.0',
    this.platform = 'ios',
  }) : baseUri = Uri.parse(baseUrl),
       httpClient = httpClient ?? http.Client();

  Future<JsonMap> get(
    String path, {
    Map<String, Object?> query = const {},
    bool includeAuth = true,
    bool retryUnauthorized = true,
  }) {
    return _sendJson(
      'GET',
      path,
      query: query,
      includeAuth: includeAuth,
      retryUnauthorized: retryUnauthorized,
    );
  }

  Future<JsonMap> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    bool includeAuth = true,
    bool retryUnauthorized = true,
  }) {
    return _sendJson(
      'POST',
      path,
      query: query,
      body: body,
      includeAuth: includeAuth,
      retryUnauthorized: retryUnauthorized,
    );
  }

  Future<JsonMap> put(
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    bool includeAuth = true,
    bool retryUnauthorized = true,
  }) {
    return _sendJson(
      'PUT',
      path,
      query: query,
      body: body,
      includeAuth: includeAuth,
      retryUnauthorized: retryUnauthorized,
    );
  }

  /// Sends an authenticated binary body to the API and decodes the standard
  /// JSON response envelope. This keeps internal Web uploads on the API origin
  /// instead of requiring browser CORS access to object storage.
  Future<JsonMap> postBytes(
    String path, {
    required Uint8List bytes,
    required String contentType,
    Map<String, Object?> query = const {},
    bool includeAuth = true,
    bool retryUnauthorized = true,
  }) {
    return _sendBytes(
      'POST',
      path,
      bytes: bytes,
      contentType: contentType,
      query: query,
      includeAuth: includeAuth,
      retryUnauthorized: retryUnauthorized,
    );
  }

  Future<JsonMap> delete(
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    bool includeAuth = true,
    bool retryUnauthorized = true,
  }) {
    return _sendJson(
      'DELETE',
      path,
      query: query,
      body: body,
      includeAuth: includeAuth,
      retryUnauthorized: retryUnauthorized,
    );
  }

  Future<Uint8List> getBytes(
    String url, {
    Map<String, String> headers = const {},
  }) async {
    if (kDebugMode) {
      debugPrint('[API] GET bytes: $url');
    }
    final response = await httpClient.get(Uri.parse(url), headers: headers);
    if (kDebugMode) {
      debugPrint('[API] GET bytes response: ${response.statusCode}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        'download failed',
        httpStatusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  Future<void> putBytes(
    String url, {
    required Uint8List bytes,
    Map<String, String> headers = const {},
  }) async {
    if (kDebugMode) {
      debugPrint('[API] PUT bytes: $url (${bytes.length} bytes)');
    }
    final response = await httpClient.put(
      Uri.parse(url),
      headers: headers,
      body: bytes,
    );
    if (kDebugMode) {
      debugPrint('[API] PUT bytes response: ${response.statusCode}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        'upload failed',
        httpStatusCode: response.statusCode,
      );
    }
  }

  Future<JsonMap> _sendJson(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    required bool includeAuth,
    required bool retryUnauthorized,
  }) async {
    final request = http.Request(method, _resolve(path, query));
    request.headers.addAll(await _headers(includeAuth: includeAuth));
    if (body != null) {
      request.body = jsonEncode(body);
    }

    if (kDebugMode) {
      debugPrint(
        '[API] $method $path${query.isNotEmpty ? ' query=$query' : ''}',
      );
      if (body != null) debugPrint('[API] body: ${jsonEncode(body)}');
    }

    final streamed = await httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    if (kDebugMode) {
      debugPrint('[API] $method $path -> ${response.statusCode}');
    }

    if (response.statusCode == 401 && retryUnauthorized) {
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        return _sendJson(
          method,
          path,
          query: query,
          body: body,
          includeAuth: includeAuth,
          retryUnauthorized: false,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        _httpErrorMessage(response),
        httpStatusCode: response.statusCode,
      );
    }

    final data = _decodeBody(response);
    final header = ResponseHeader.fromJson(
      (data['header'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    if (header.code == 1001 || header.code == 1002) {
      if (retryUnauthorized) {
        final refreshed = await _handleUnauthorized();
        if (refreshed) {
          return _sendJson(
            method,
            path,
            query: query,
            body: body,
            includeAuth: includeAuth,
            retryUnauthorized: false,
          );
        }
      }
      throw ApiException(
        header.code,
        header.message,
        traceId: header.traceId,
        httpStatusCode: response.statusCode,
      );
    }
    if (header.code != 0) {
      throw ApiException(
        header.code,
        header.message,
        traceId: header.traceId,
        httpStatusCode: response.statusCode,
      );
    }

    return data;
  }

  Future<JsonMap> _sendBytes(
    String method,
    String path, {
    required Uint8List bytes,
    required String contentType,
    Map<String, Object?> query = const {},
    required bool includeAuth,
    required bool retryUnauthorized,
  }) async {
    final request = http.Request(method, _resolve(path, query));
    request.headers.addAll(await _headers(includeAuth: includeAuth));
    request.headers['Content-Type'] = contentType;
    request.bodyBytes = bytes;

    if (kDebugMode) {
      debugPrint('[API] $method bytes $path (${bytes.length} bytes)');
    }

    final streamed = await httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    if (kDebugMode) {
      debugPrint('[API] $method bytes $path -> ${response.statusCode}');
    }

    if (response.statusCode == 401 && retryUnauthorized) {
      final refreshed = await _handleUnauthorized();
      if (refreshed) {
        return _sendBytes(
          method,
          path,
          bytes: bytes,
          contentType: contentType,
          query: query,
          includeAuth: includeAuth,
          retryUnauthorized: false,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        _httpErrorMessage(response),
        httpStatusCode: response.statusCode,
      );
    }

    final data = _decodeBody(response);
    final header = ResponseHeader.fromJson(
      (data['header'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    if (header.code == 1001 || header.code == 1002) {
      if (retryUnauthorized) {
        final refreshed = await _handleUnauthorized();
        if (refreshed) {
          return _sendBytes(
            method,
            path,
            bytes: bytes,
            contentType: contentType,
            query: query,
            includeAuth: includeAuth,
            retryUnauthorized: false,
          );
        }
      }
      throw ApiException(
        header.code,
        header.message,
        traceId: header.traceId,
        httpStatusCode: response.statusCode,
      );
    }
    if (header.code != 0) {
      throw ApiException(
        header.code,
        header.message,
        traceId: header.traceId,
        httpStatusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<Map<String, String>> _headers({required bool includeAuth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Platform': platform,
      'X-App-Version': appVersion,
      'X-Device-Id': await deviceIdProvider(),
    };
    if (includeAuth) {
      final token = await tokenProvider();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<bool> _handleUnauthorized() async {
    final handler = onUnauthorized;
    if (handler == null) return false;
    return handler();
  }

  Uri _resolve(String path, Map<String, Object?> query) {
    final normalizedBase = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final existingQuery = Map<String, String>.from(baseUri.queryParameters);
    final nextQuery = <String, String>{
      ...existingQuery,
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return baseUri.replace(
      path: '$normalizedBase$normalizedPath',
      queryParameters: nextQuery.isEmpty ? null : nextQuery,
    );
  }

  JsonMap _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return {};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw ApiException(
      response.statusCode,
      'invalid api response',
      httpStatusCode: response.statusCode,
    );
  }

  String _httpErrorMessage(http.Response response) {
    if (response.bodyBytes.isEmpty) return 'request failed';
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        final header = decoded['header'];
        if (header is Map && header['message'] != null) {
          return header['message'].toString();
        }
        if (decoded['message'] != null) return decoded['message'].toString();
        if (decoded['error'] != null) return decoded['error'].toString();
      }
    } catch (_) {
      return response.reasonPhrase ?? 'request failed';
    }
    return response.reasonPhrase ?? 'request failed';
  }
}
