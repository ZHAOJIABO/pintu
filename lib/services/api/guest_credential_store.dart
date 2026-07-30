import 'package:flutter/services.dart';

/// Stores the opaque credential that identifies an anonymous account.
abstract interface class GuestCredentialStore {
  Future<String?> read();

  Future<void> write(String value);
}

/// iOS Keychain implementation for the anonymous-account credential.
///
/// The native item is deliberately non-synchronizable and device-only, so an
/// anonymous account is not copied to another person's device via iCloud.
class KeychainGuestCredentialStore implements GuestCredentialStore {
  static const _channel = MethodChannel('bobobeads/guest_credential');

  const KeychainGuestCredentialStore();

  @override
  Future<String?> read() async {
    final value = await _channel.invokeMethod<String>('readGuestCredential');
    final credential = value?.trim();
    return credential == null || credential.isEmpty ? null : credential;
  }

  @override
  Future<void> write(String value) {
    return _channel.invokeMethod<void>('writeGuestCredential', {
      'value': value,
    });
  }
}
