import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'api_models.dart';
import 'guest_credential_store.dart';
import 'vendor_identifier.dart';

typedef DeviceIdentifiersProvider = Future<DeviceInfo> Function();

class ApiSessionStore {
  static const _fileName = 'bobobeads_api_session.json';
  static const _deviceIdKey = 'deviceId';
  static const _deviceIdFileSuffix = '.device_id';
  static const _guestCredentialFileSuffix = '.guest_credential';
  static const _sessionKey = 'session';
  static const _pendingStyleClientRequestIdKey = 'pendingStyleClientRequestId';
  static const _pendingAiTaskIdKey = 'pendingAiTaskId';
  static const _pendingGenerationClientRequestIdKey =
      'pendingGenerationClientRequestId';
  static const _pendingGenerationIdKey = 'pendingGenerationId';

  final Future<File> Function()? fileProvider;
  final DeviceIdentifiersProvider? deviceIdentifiersProvider;
  final GuestCredentialStore? guestCredentialStore;

  /// Multiple service instances can be created while the widget tree is being
  /// rebuilt. Serialize the first read/create per persisted file so they can
  /// never generate competing IDs for one installation.
  static final Map<String, Future<String>> _deviceIdRequests = {};

  /// Keychain is shared by every service instance in this process. Serialize
  /// first-use so concurrent startup requests cannot register separate guest
  /// accounts before either one writes the credential.
  static final Map<GuestCredentialStore, Future<String>>
  _guestCredentialRequests = {};

  const ApiSessionStore({
    this.fileProvider,
    this.deviceIdentifiersProvider,
    this.guestCredentialStore,
  });

  Future<DeviceInfo> readDeviceInfo() async {
    final provider = deviceIdentifiersProvider;
    if (provider != null) return provider();
    return PlatformDeviceInfoReader.read();
  }

  @Deprecated('Use readDeviceInfo. Authentication now reports header.device.')
  Future<DeviceInfo> readDeviceIdentifiers() => readDeviceInfo();

  Future<String> readOrCreateDeviceId() async {
    final deviceFile = await _deviceFile();
    final existingRequest = _deviceIdRequests[deviceFile.path];
    if (existingRequest != null) return existingRequest;

    final request = _readOrCreateDeviceId(deviceFile);
    _deviceIdRequests[deviceFile.path] = request;
    unawaited(
      request.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
          if (identical(_deviceIdRequests[deviceFile.path], request)) {
            _deviceIdRequests.remove(deviceFile.path);
          }
        },
      ),
    );
    return request;
  }

  /// Returns the opaque credential used to restore an anonymous account.
  ///
  /// On iOS it is stored in Keychain, which normally remains available after
  /// the app is deleted and reinstalled. It is intentionally distinct from
  /// IDFV/IDFA, which are only device signals and must not own a user account.
  Future<String> readOrCreateGuestCredential() async {
    final secureStore = guestCredentialStore;
    if (secureStore != null || Platform.isIOS) {
      return _readOrCreateSharedGuestCredential(
        secureStore ?? const KeychainGuestCredentialStore(),
      );
    }
    return _readOrCreateFileGuestCredential();
  }

  Future<String> _readOrCreateSharedGuestCredential(
    GuestCredentialStore secureStore,
  ) {
    final existingRequest = _guestCredentialRequests[secureStore];
    if (existingRequest != null) return existingRequest;

    final request = _readOrCreateSecureGuestCredential(secureStore);
    _guestCredentialRequests[secureStore] = request;
    unawaited(
      request.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
          if (identical(_guestCredentialRequests[secureStore], request)) {
            _guestCredentialRequests.remove(secureStore);
          }
        },
      ),
    );
    return request;
  }

  Future<String> _readOrCreateSecureGuestCredential(
    GuestCredentialStore secureStore,
  ) async {
    final existing = await secureStore.read();
    if (existing != null && existing.isNotEmpty) return existing;

    final credential = RequestId.generate();
    await secureStore.write(credential);
    final storedCredential = await secureStore.read();
    if (storedCredential == null || storedCredential.isEmpty) {
      throw StateError('Guest credential storage did not retain its value.');
    }
    return storedCredential;
  }

  Future<String> _readOrCreateFileGuestCredential() async {
    final credentialFile = await _guestCredentialFile();
    if (await credentialFile.exists()) {
      final existing = (await credentialFile.readAsString()).trim();
      if (existing.isNotEmpty) return existing;
    }

    final credential = RequestId.generate();
    await credentialFile.parent.create(recursive: true);
    await credentialFile.writeAsString(credential, flush: true);
    return credential;
  }

  Future<String> _readOrCreateDeviceId(File deviceFile) async {
    final deviceInfo = await readDeviceInfo();
    final idfv = deviceInfo.idfv;
    if (idfv != null && idfv.isNotEmpty) return 'ios-$idfv';
    final androidId = deviceInfo.androidId ?? deviceInfo.oaid;
    if (androidId != null && androidId.isNotEmpty) return 'android-$androidId';

    if (await deviceFile.exists()) {
      final existing = (await deviceFile.readAsString()).trim();
      if (existing.isNotEmpty) return existing;
    }

    // Migrate installations that stored the device id in the session file.
    final data = await _read();
    final existing = data[_deviceIdKey]?.toString().trim();
    if (existing != null && existing.isNotEmpty) {
      await deviceFile.parent.create(recursive: true);
      await deviceFile.writeAsString(existing, flush: true);
      return existing;
    }

    final deviceId = 'ios-${RequestId.generate()}';
    await deviceFile.parent.create(recursive: true);
    await deviceFile.writeAsString(deviceId, flush: true);
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

  Future<String?> readPendingAiTaskId() async {
    final data = await _read();
    final taskId = data[_pendingAiTaskIdKey]?.toString();
    return taskId == null || taskId.isEmpty ? null : taskId;
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

  /// Clears the generation idempotency state in one file write so a new user
  /// click cannot retain either half of a previous attempt.
  Future<void> clearPendingGenerationAttempt() async {
    final data = await _read();
    data
      ..remove(_pendingGenerationClientRequestIdKey)
      ..remove(_pendingGenerationIdKey);
    await _write(data);
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

  Future<File> _deviceFile() async {
    final sessionFile = await _file();
    return File('${sessionFile.path}$_deviceIdFileSuffix');
  }

  Future<File> _guestCredentialFile() async {
    final sessionFile = await _file();
    return File('${sessionFile.path}$_guestCredentialFileSuffix');
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
