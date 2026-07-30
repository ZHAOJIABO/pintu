import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Stable, platform-provided device identifiers accepted by guest login.
class DeviceIdentifiers {
  final String? androidId;
  final String? oaid;
  final String? idfv;
  final String? idfa;

  const DeviceIdentifiers({this.androidId, this.oaid, this.idfv, this.idfa});

  factory DeviceIdentifiers.fromJson(Map<Object?, Object?> json) {
    String? value(String key) {
      final value = json[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return DeviceIdentifiers(
      androidId: value('androidId'),
      oaid: value('oaid'),
      idfv: value('idfv'),
      idfa: value('idfa'),
    );
  }

  Map<String, Object?> toGuestLoginBody(
    String platform, {
    required String guestCredential,
  }) {
    final device = <String, Object?>{};
    if (platform == 'android') {
      final primary = _nonEmpty(androidId);
      if (primary != null) {
        device['androidId'] = primary;
      } else if (_nonEmpty(oaid) case final fallback?) {
        device['oaid'] = fallback;
      }
    } else {
      final primary = _nonEmpty(idfv);
      if (primary != null) {
        device['idfv'] = primary;
      } else if (_nonEmpty(idfa) case final fallback?) {
        device['idfa'] = fallback;
      }
    }
    return {
      'header': {'guestCredential': guestCredential, 'device': device},
    };
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}

/// Reads platform-provided identifiers without generating a guest identifier.
class DeviceIdentifierReader {
  DeviceIdentifierReader._();

  static const _channel = MethodChannel('bobobeads/device_identifiers');

  static Future<DeviceIdentifiers> read() async {
    if (kIsWeb) return const DeviceIdentifiers();

    final method = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => 'getDeviceIdentifiers',
      _ => null,
    };
    if (method == null) return const DeviceIdentifiers();

    try {
      final result = await _channel.invokeMethod<Object?>(method);
      if (result is Map) {
        return DeviceIdentifiers.fromJson(result);
      }
    } on MissingPluginException {
      return const DeviceIdentifiers();
    } on PlatformException {
      return const DeviceIdentifiers();
    } on FlutterError {
      return const DeviceIdentifiers();
    }
    return const DeviceIdentifiers();
  }
}
