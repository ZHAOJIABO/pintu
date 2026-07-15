import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'api_models.dart';

class ApiSessionStore {
  static const _fileName = 'bobobeads_api_session.json';
  static const _deviceIdKey = 'deviceId';
  static const _sessionKey = 'session';
  static const _pendingStyleClientRequestIdKey = 'pendingStyleClientRequestId';
  static const _pendingAiTaskIdKey = 'pendingAiTaskId';
  static const _pendingGenerationClientRequestIdKey =
      'pendingGenerationClientRequestId';
  static const _pendingGenerationIdKey = 'pendingGenerationId';

  final Future<File> Function()? fileProvider;

  const ApiSessionStore({this.fileProvider});

  Future<String> readOrCreateDeviceId() async {
    final data = await _read();
    final existing = data[_deviceIdKey]?.toString();
    if (existing != null && existing.isNotEmpty) return existing;

    final deviceId = 'ios-${RequestId.generate()}';
    data[_deviceIdKey] = deviceId;
    await _write(data);
    return deviceId;
  }

  Future<AuthSession?> readSession() async {
    final data = await _read();
    final sessionJson = data[_sessionKey];
    if (sessionJson is Map<String, dynamic>) {
      return AuthSession.fromStoredJson(sessionJson);
    }
    if (sessionJson is Map) {
      return AuthSession.fromStoredJson(sessionJson.cast<String, dynamic>());
    }
    return null;
  }

  Future<String?> readAccessToken() async {
    return (await readSession())?.accessToken;
  }

  Future<void> saveSession(AuthSession session) async {
    final data = await _read();
    data[_sessionKey] = session.toJson();
    await _write(data);
  }

  Future<void> clearSession() async {
    final data = await _read();
    data.remove(_sessionKey);
    await _write(data);
  }

  Future<String> readOrCreatePendingStyleClientRequestId() {
    return _readOrCreateString(_pendingStyleClientRequestIdKey);
  }

  Future<void> clearPendingStyleClientRequestId() {
    return _remove(_pendingStyleClientRequestIdKey);
  }

  Future<void> savePendingAiTaskId(String taskId) {
    return _writeString(_pendingAiTaskIdKey, taskId);
  }

  Future<void> clearPendingAiTaskId() {
    return _remove(_pendingAiTaskIdKey);
  }

  Future<String> readOrCreatePendingGenerationClientRequestId() {
    return _readOrCreateString(_pendingGenerationClientRequestIdKey);
  }

  Future<void> clearPendingGenerationClientRequestId() {
    return _remove(_pendingGenerationClientRequestIdKey);
  }

  Future<void> savePendingGenerationId(String generationId) {
    return _writeString(_pendingGenerationIdKey, generationId);
  }

  Future<String?> readPendingGenerationId() async {
    final data = await _read();
    final generationId = data[_pendingGenerationIdKey]?.toString();
    return generationId == null || generationId.isEmpty ? null : generationId;
  }

  Future<void> clearPendingGenerationId() {
    return _remove(_pendingGenerationIdKey);
  }

  Future<String> _readOrCreateString(String key) async {
    final data = await _read();
    final existing = data[key]?.toString();
    if (existing != null && existing.isNotEmpty) return existing;

    final value = RequestId.generate();
    data[key] = value;
    await _write(data);
    return value;
  }

  Future<void> _writeString(String key, String value) async {
    final data = await _read();
    data[key] = value;
    await _write(data);
  }

  Future<void> _remove(String key) async {
    final data = await _read();
    data.remove(key);
    await _write(data);
  }

  Future<JsonMap> _read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return {};
    }
    return {};
  }

  Future<void> _write(JsonMap data) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  Future<File> _file() async {
    final provider = fileProvider;
    if (provider != null) return provider();
    final root = await getApplicationDocumentsDirectory();
    return File('${root.path}/$_fileName');
  }
}

class RequestId {
  const RequestId._();

  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
