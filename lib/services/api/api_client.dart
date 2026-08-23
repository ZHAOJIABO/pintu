import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_models.dart';
import 'vendor_identifier.dart';

typedef TokenProvider = Future<String?> Function();
typedef DeviceIdProvider = Future<String> Function();
typedef UnauthorizedHandler = Future<bool> Function();
typedef ApiResponseHandler = Future<void> Function(http.Response response);

class ApiClient {
  static const defaultBaseUrl = String.fromEnvironment(
    'BOBOBEADS_API_BASE_URL',
    defaultValue: 'https://appbobo.cn',
    //defaultValue: 'http://localhost:8080',
  );

  final Uri baseUri;
  final http.Client httpClient;
  final TokenProvider tokenProvider;
  final DeviceIdProvider deviceIdProvider;
  final DeviceInfoProvider deviceInfoProvider;
  final UnauthorizedHandler? onUnauthorized;
  final ApiResponseHandler? onResponse;
  final String appVersion;
  final String platform;

  ApiClient({
    String baseUrl = defaultBaseUrl,
    http.Client? httpClient,
    required this.tokenProvider,
    required this.deviceIdProvider,
    this.deviceInfoProvider = const DeviceInfoProvider(),
    this.onUnauthorized,
    this.onResponse,
    this.appVersion = '1.0.0',
    String? platform,
  }) : baseUri = Uri.parse(baseUrl),
       httpClient = httpClient ?? http.Client(),
       platform = platform ?? _defaultPlatform();

  static String _defaultPlatform() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    }
    return 'ios';
  }

  /// Builds the protobuf JSON `RequestHeader` used by authentication calls.
  ///
  /// `deviceId` deliberately does not appear here: guest identity is derived
  /// on the server from `header.device` and `guestCredential` instead.
  Future<Map<String, Object?>> authenticationHeader({
    String? guestCredential,
    DeviceInfo? deviceInfo,
  }) async {
    final device = deviceInfo ?? await deviceInfoProvider.read();
    return {
      'platform': platform,
      'appVersion': appVersion,
      if (guestCredential != null && guestCredential.isNotEmpty)
        'guestCredential': guestCredential,
      'device': device.toJson(),
    };
  }

  Future<JsonMap> get(
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    bool includeAuth = true,
    bool retryUnauthorized = true,
  }) {
    return _sendJson(
      'GET',
      path,
      query: query,
      body: body,
      includeAuth: includeAuth,
      retryUnauthorized: retryUnauthorized,
    );
  }

  Future<JsonMap> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    bool includeAuth = true,
    bool includeDeviceId = true,
    bool retryUnauthorized = true,
  }) {
    return _sendJson(
      'POST',
      path,
      query: query,
      body: body,
      includeAuth: includeAuth,
      includeDeviceId: includeDeviceId,
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
    bool includeDeviceId = true,
    required bool retryUnauthorized,
  }) async {
    final request = http.Request(method, _resolve(path, query));
    request.headers.addAll(
      await _headers(
        includeAuth: includeAuth,
        includeDeviceId: includeDeviceId,
      ),
    );
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    if (kDebugMode) {
      debugPrint(
        '[API] $method $path${query.isNotEmpty ? ' query=$query' : ''}',
      );
      if (body != null) {
        debugPrint(
          '[API] body: ${jsonEncode(_redactSecretsForLog(body, redactVerificationCode: path.startsWith('/api/v1/auth/')))}',
        );
      }
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
          includeDeviceId: includeDeviceId,
          retryUnauthorized: false,
        );
      }
    }

    await _handleResponse(response, includeAuth: includeAuth);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
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
            includeDeviceId: includeDeviceId,
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

    await _handleResponse(response, includeAuth: includeAuth);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
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

  Future<Map<String, String>> _headers({
    required bool includeAuth,
    bool includeDeviceId = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Platform': platform,
      'X-App-Version': appVersion,
    };
    if (includeDeviceId) {
      headers['X-Device-Id'] = await deviceIdProvider();
    }
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

  /// Observes successful authenticated responses before their payload is
  /// decoded. Callers can use this for response-header based session rotation
  /// without coupling the shared client to a specific authentication scheme.
  Future<void> _handleResponse(
    http.Response response, {
    required bool includeAuth,
  }) async {
    if (!includeAuth ||
        response.statusCode < 200 ||
        response.statusCode >= 300) {
      return;
    }
    await onResponse?.call(response);
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

  /// Builds the failure for a non-2xx response.
  ///
  /// The business `header.code` is preferred over the HTTP status because
  /// several distinct codes share one status (the draft endpoints map both
  /// "draft box full" and "draft not publishable" onto `400`), so callers
  /// cannot branch on the status alone.
  ApiException _httpError(http.Response response) {
    final header = _errorHeader(response);
    return ApiException(
      header?.code != null && header!.code != 0
          ? header.code
          : response.statusCode,
      header?.message ?? response.reasonPhrase ?? 'request failed',
      traceId: header?.traceId,
      httpStatusCode: response.statusCode,
    );
  }

  ResponseHeader? _errorHeader(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      final header = decoded['header'];
      if (header is Map) {
        return ResponseHeader.fromJson(header.cast<String, dynamic>());
      }
      final message = decoded['message'] ?? decoded['error'];
      if (message == null) return null;
      return ResponseHeader(code: 0, message: message.toString());
    } catch (_) {
      return null;
    }
  }

  Object? _redactSecretsForLog(
    Object? value, {
    required bool redactVerificationCode,
  }) {
    const secretKeys = {
      'accessToken',
      'guestCredential',
      'refreshToken',
      'token',
    };
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString():
              secretKeys.contains(entry.key.toString()) ||
                  (redactVerificationCode && entry.key == 'code')
              ? '***'
              : _redactSecretsForLog(
                  entry.value,
                  redactVerificationCode: redactVerificationCode,
                ),
      };
    }
    if (value is Iterable) {
      return value
          .map(
            (item) => _redactSecretsForLog(
              item,
              redactVerificationCode: redactVerificationCode,
            ),
          )
          .toList();
    }
    return value;
  }
}
