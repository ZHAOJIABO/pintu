import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A protobuf-JSON compatible representation of `bobobeads.v1.Device`.
///
/// Each field is optional because platform APIs and user-granted permissions
/// differ. Do not synthesize values for unavailable identifiers.
class DeviceInfo {
  final String? ip;
  final String? userAgent;
  final String? idfa;
  final String? idfaMd5;
  final String? imei;
  final String? imeiMd5;
  final String? oaid;
  final String? oaidMd5;
  final String? androidId;
  final int? deviceType;
  final String? brand;
  final String? model;
  final int? os;
  final String? osv;
  final int? network;
  final int? operator;
  final int? width;
  final int? height;
  final int? orientation;
  final Geo? geo;
  final List<String> installedApp;
  final List<Caid> caids;
  final String? bootMark;
  final String? updateMark;
  final String? mac;
  final String? androidIdMd5;
  final String? ipv6;
  final DeviceUserInfo? userInfo;
  final String? birthTime;
  final String? bootTime;
  final String? updateTime;
  final String? idfv;
  final String? idfvMd5;
  final String? language;
  final String? timezone;

  const DeviceInfo({
    this.ip,
    this.userAgent,
    this.idfa,
    this.idfaMd5,
    this.imei,
    this.imeiMd5,
    this.oaid,
    this.oaidMd5,
    this.androidId,
    this.deviceType,
    this.brand,
    this.model,
    this.os,
    this.osv,
    this.network,
    this.operator,
    this.width,
    this.height,
    this.orientation,
    this.geo,
    this.installedApp = const [],
    this.caids = const [],
    this.bootMark,
    this.updateMark,
    this.mac,
    this.androidIdMd5,
    this.ipv6,
    this.userInfo,
    this.birthTime,
    this.bootTime,
    this.updateTime,
    this.idfv,
    this.idfvMd5,
    this.language,
    this.timezone,
  });

  factory DeviceInfo.fromJson(Map<Object?, Object?> json) {
    String? stringValue(String key) {
      final value = json[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    int? intValue(String key) {
      final value = json[key];
      return value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '');
    }

    Map<Object?, Object?>? mapValue(String key) {
      final value = json[key];
      return value is Map ? value : null;
    }

    List<T> mapList<T>(String key, T Function(Map<Object?, Object?>) read) {
      final value = json[key];
      if (value is! Iterable) return const [];
      return value.whereType<Map>().map(read).toList(growable: false);
    }

    final geo = mapValue('geo');
    final userInfo = mapValue('userInfo');
    return DeviceInfo(
      ip: stringValue('ip'),
      userAgent: stringValue('userAgent'),
      idfa: stringValue('idfa'),
      idfaMd5: stringValue('idfaMd5'),
      imei: stringValue('imei'),
      imeiMd5: stringValue('imeiMd5'),
      oaid: stringValue('oaid'),
      oaidMd5: stringValue('oaidMd5'),
      androidId: stringValue('androidId'),
      deviceType: intValue('deviceType'),
      brand: stringValue('brand'),
      model: stringValue('model'),
      os: intValue('os'),
      osv: stringValue('osv'),
      network: intValue('network'),
      operator: intValue('operator'),
      width: intValue('width'),
      height: intValue('height'),
      orientation: intValue('orientation'),
      geo: geo == null ? null : Geo.fromJson(geo),
      installedApp: (json['installedApp'] as Iterable? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      caids: mapList('caids', Caid.fromJson),
      bootMark: stringValue('bootMark'),
      updateMark: stringValue('updateMark'),
      mac: stringValue('mac'),
      androidIdMd5: stringValue('androidIdMd5'),
      ipv6: stringValue('ipv6'),
      userInfo: userInfo == null ? null : DeviceUserInfo.fromJson(userInfo),
      birthTime: stringValue('birthTime'),
      bootTime: stringValue('bootTime'),
      updateTime: stringValue('updateTime'),
      idfv: stringValue('idfv'),
      idfvMd5: stringValue('idfvMd5'),
      language: stringValue('language'),
      timezone: stringValue('timezone'),
    );
  }

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};

    void addString(String key, String? value) {
      if (value != null && value.isNotEmpty) json[key] = value;
    }

    void addInt(String key, int? value) {
      if (value != null) json[key] = value;
    }

    addString('ip', ip);
    addString('userAgent', userAgent);
    addString('idfa', idfa);
    addString('idfaMd5', idfaMd5);
    addString('imei', imei);
    addString('imeiMd5', imeiMd5);
    addString('oaid', oaid);
    addString('oaidMd5', oaidMd5);
    addString('androidId', androidId);
    addInt('deviceType', deviceType);
    addString('brand', brand);
    addString('model', model);
    addInt('os', os);
    addString('osv', osv);
    addInt('network', network);
    addInt('operator', operator);
    addInt('width', width);
    addInt('height', height);
    addInt('orientation', orientation);
    if (geo != null) json['geo'] = geo!.toJson();
    if (installedApp.isNotEmpty) json['installedApp'] = installedApp;
    if (caids.isNotEmpty) {
      json['caids'] = caids.map((value) => value.toJson()).toList();
    }
    addString('bootMark', bootMark);
    addString('updateMark', updateMark);
    addString('mac', mac);
    addString('androidIdMd5', androidIdMd5);
    addString('ipv6', ipv6);
    if (userInfo != null) json['userInfo'] = userInfo!.toJson();
    addString('birthTime', birthTime);
    addString('bootTime', bootTime);
    addString('updateTime', updateTime);
    addString('idfv', idfv);
    addString('idfvMd5', idfvMd5);
    addString('language', language);
    addString('timezone', timezone);
    return json;
  }
}

@Deprecated('Use DeviceInfo. The value is no longer a guest identity alone.')
typedef DeviceIdentifiers = DeviceInfo;

class Geo {
  final double lat;
  final double lon;

  const Geo({required this.lat, required this.lon});

  factory Geo.fromJson(Map<Object?, Object?> json) => Geo(
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lon: (json['lon'] as num?)?.toDouble() ?? 0,
  );

  Map<String, Object> toJson() => {'lat': lat, 'lon': lon};
}

class Caid {
  final String ver;
  final String caid;

  const Caid({required this.ver, required this.caid});

  factory Caid.fromJson(Map<Object?, Object?> json) => Caid(
    ver: json['ver']?.toString() ?? '',
    caid: json['caid']?.toString() ?? '',
  );

  Map<String, String> toJson() => {'ver': ver, 'caid': caid};
}

class DeviceUserInfo {
  final int age;
  final int gender;

  const DeviceUserInfo({required this.age, required this.gender});

  factory DeviceUserInfo.fromJson(Map<Object?, Object?> json) => DeviceUserInfo(
    age: (json['age'] as num?)?.toInt() ?? 0,
    gender: (json['gender'] as num?)?.toInt() ?? 0,
  );

  Map<String, int> toJson() => {'age': age, 'gender': gender};
}

typedef DeviceInfoReader = Future<DeviceInfo> Function();

/// Centralizes device collection so every authentication method reports the
/// same profile. Sources must return only values the user has authorized.
class DeviceInfoProvider {
  final DeviceInfoReader? reader;

  const DeviceInfoProvider({this.reader});

  Future<DeviceInfo> read() =>
      reader?.call() ?? PlatformDeviceInfoReader.read();
}

class PlatformDeviceInfoReader {
  PlatformDeviceInfoReader._();

  static const _channel = MethodChannel('bobobeads/device_identifiers');

  static Future<DeviceInfo> read() async {
    if (kIsWeb) return const DeviceInfo();

    final method = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => 'getDeviceInfo',
      _ => null,
    };
    if (method == null) return const DeviceInfo();

    try {
      final result = await _channel.invokeMethod<Object?>(method);
      if (result is Map) return DeviceInfo.fromJson(result);
    } on MissingPluginException {
      // Platform support is optional; send an empty Device message instead.
    } on PlatformException {
      // Do not block authentication when one optional signal is unavailable.
    } on FlutterError {
      // The provider is intentionally best-effort.
    }
    return const DeviceInfo();
  }
}
