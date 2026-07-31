// This is a generated file - do not edit.
//
// Generated from common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'common.pbenum.dart';

class Device_Geo extends $pb.GeneratedMessage {
  factory Device_Geo({
    $core.double? lat,
    $core.double? lon,
  }) {
    final result = create();
    if (lat != null) result.lat = lat;
    if (lon != null) result.lon = lon;
    return result;
  }

  Device_Geo._();

  factory Device_Geo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Device_Geo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Device.Geo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bobobeads.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'lat')
    ..aD(2, _omitFieldNames ? '' : 'lon')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device_Geo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device_Geo copyWith(void Function(Device_Geo) updates) =>
      super.copyWith((message) => updates(message as Device_Geo)) as Device_Geo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Device_Geo create() => Device_Geo._();
  @$core.override
  Device_Geo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Device_Geo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Device_Geo>(create);
  static Device_Geo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get lat => $_getN(0);
  @$pb.TagNumber(1)
  set lat($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLat() => $_has(0);
  @$pb.TagNumber(1)
  void clearLat() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get lon => $_getN(1);
  @$pb.TagNumber(2)
  set lon($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLon() => $_has(1);
  @$pb.TagNumber(2)
  void clearLon() => $_clearField(2);
}

class Device_CAID extends $pb.GeneratedMessage {
  factory Device_CAID({
    $core.String? ver,
    $core.String? caid,
  }) {
    final result = create();
    if (ver != null) result.ver = ver;
    if (caid != null) result.caid = caid;
    return result;
  }

  Device_CAID._();

  factory Device_CAID.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Device_CAID.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Device.CAID',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bobobeads.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'ver')
    ..aOS(2, _omitFieldNames ? '' : 'caid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device_CAID clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device_CAID copyWith(void Function(Device_CAID) updates) =>
      super.copyWith((message) => updates(message as Device_CAID))
          as Device_CAID;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Device_CAID create() => Device_CAID._();
  @$core.override
  Device_CAID createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Device_CAID getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Device_CAID>(create);
  static Device_CAID? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get ver => $_getSZ(0);
  @$pb.TagNumber(1)
  set ver($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVer() => $_has(0);
  @$pb.TagNumber(1)
  void clearVer() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get caid => $_getSZ(1);
  @$pb.TagNumber(2)
  set caid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCaid() => $_has(1);
  @$pb.TagNumber(2)
  void clearCaid() => $_clearField(2);
}

class Device_UserInfo extends $pb.GeneratedMessage {
  factory Device_UserInfo({
    $core.int? age,
    $core.int? gender,
  }) {
    final result = create();
    if (age != null) result.age = age;
    if (gender != null) result.gender = gender;
    return result;
  }

  Device_UserInfo._();

  factory Device_UserInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Device_UserInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Device.UserInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bobobeads.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'age')
    ..aI(2, _omitFieldNames ? '' : 'gender')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device_UserInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device_UserInfo copyWith(void Function(Device_UserInfo) updates) =>
      super.copyWith((message) => updates(message as Device_UserInfo))
          as Device_UserInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Device_UserInfo create() => Device_UserInfo._();
  @$core.override
  Device_UserInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Device_UserInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Device_UserInfo>(create);
  static Device_UserInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get age => $_getIZ(0);
  @$pb.TagNumber(1)
  set age($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAge() => $_has(0);
  @$pb.TagNumber(1)
  void clearAge() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get gender => $_getIZ(1);
  @$pb.TagNumber(2)
  set gender($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGender() => $_has(1);
  @$pb.TagNumber(2)
  void clearGender() => $_clearField(2);
}

/// 客户端设备信息。
class Device extends $pb.GeneratedMessage {
  factory Device({
    $core.String? ip,
    $core.String? userAgent,
    $core.String? idfa,
    $core.String? idfaMd5,
    $core.String? imei,
    $core.String? imeiMd5,
    $core.String? oaid,
    $core.String? oaidMd5,
    $core.String? androidId,
    $core.int? deviceType,
    $core.String? brand,
    $core.String? model,
    $core.int? os,
    $core.String? osv,
    $core.int? network,
    $core.int? operator,
    $core.int? width,
    $core.int? height,
    $core.int? orientation,
    Device_Geo? geo,
    $core.Iterable<$core.String>? installedApp,
    $core.Iterable<Device_CAID>? caids,
    $core.String? bootMark,
    $core.String? updateMark,
    $core.String? mac,
    $core.String? androidIdMd5,
    $core.String? ipv6,
    Device_UserInfo? userInfo,
    $core.String? birthTime,
    $core.String? bootTime,
    $core.String? updateTime,
    $core.String? idfv,
    $core.String? idfvMd5,
    Language? language,
    $core.String? timezone,
  }) {
    final result = create();
    if (ip != null) result.ip = ip;
    if (userAgent != null) result.userAgent = userAgent;
    if (idfa != null) result.idfa = idfa;
    if (idfaMd5 != null) result.idfaMd5 = idfaMd5;
    if (imei != null) result.imei = imei;
    if (imeiMd5 != null) result.imeiMd5 = imeiMd5;
    if (oaid != null) result.oaid = oaid;
    if (oaidMd5 != null) result.oaidMd5 = oaidMd5;
    if (androidId != null) result.androidId = androidId;
    if (deviceType != null) result.deviceType = deviceType;
    if (brand != null) result.brand = brand;
    if (model != null) result.model = model;
    if (os != null) result.os = os;
    if (osv != null) result.osv = osv;
    if (network != null) result.network = network;
    if (operator != null) result.operator = operator;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (orientation != null) result.orientation = orientation;
    if (geo != null) result.geo = geo;
    if (installedApp != null) result.installedApp.addAll(installedApp);
    if (caids != null) result.caids.addAll(caids);
    if (bootMark != null) result.bootMark = bootMark;
    if (updateMark != null) result.updateMark = updateMark;
    if (mac != null) result.mac = mac;
    if (androidIdMd5 != null) result.androidIdMd5 = androidIdMd5;
    if (ipv6 != null) result.ipv6 = ipv6;
    if (userInfo != null) result.userInfo = userInfo;
    if (birthTime != null) result.birthTime = birthTime;
    if (bootTime != null) result.bootTime = bootTime;
    if (updateTime != null) result.updateTime = updateTime;
    if (idfv != null) result.idfv = idfv;
    if (idfvMd5 != null) result.idfvMd5 = idfvMd5;
    if (language != null) result.language = language;
    if (timezone != null) result.timezone = timezone;
    return result;
  }

  Device._();

  factory Device.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Device.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Device',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bobobeads.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'ip')
    ..aOS(2, _omitFieldNames ? '' : 'userAgent')
    ..aOS(3, _omitFieldNames ? '' : 'idfa')
    ..aOS(4, _omitFieldNames ? '' : 'idfaMd5')
    ..aOS(5, _omitFieldNames ? '' : 'imei')
    ..aOS(6, _omitFieldNames ? '' : 'imeiMd5')
    ..aOS(7, _omitFieldNames ? '' : 'oaid')
    ..aOS(8, _omitFieldNames ? '' : 'oaidMd5')
    ..aOS(9, _omitFieldNames ? '' : 'androidId')
    ..aI(10, _omitFieldNames ? '' : 'deviceType')
    ..aOS(11, _omitFieldNames ? '' : 'brand')
    ..aOS(12, _omitFieldNames ? '' : 'model')
    ..aI(13, _omitFieldNames ? '' : 'os')
    ..aOS(14, _omitFieldNames ? '' : 'osv')
    ..aI(15, _omitFieldNames ? '' : 'network')
    ..aI(16, _omitFieldNames ? '' : 'operator')
    ..aI(17, _omitFieldNames ? '' : 'width')
    ..aI(18, _omitFieldNames ? '' : 'height')
    ..aI(20, _omitFieldNames ? '' : 'orientation')
    ..aOM<Device_Geo>(21, _omitFieldNames ? '' : 'geo',
        subBuilder: Device_Geo.create)
    ..pPS(22, _omitFieldNames ? '' : 'installedApp')
    ..pPM<Device_CAID>(23, _omitFieldNames ? '' : 'caids',
        subBuilder: Device_CAID.create)
    ..aOS(24, _omitFieldNames ? '' : 'bootMark')
    ..aOS(25, _omitFieldNames ? '' : 'updateMark')
    ..aOS(26, _omitFieldNames ? '' : 'mac')
    ..aOS(27, _omitFieldNames ? '' : 'androidIdMd5')
    ..aOS(28, _omitFieldNames ? '' : 'ipv6')
    ..aOM<Device_UserInfo>(29, _omitFieldNames ? '' : 'userInfo',
        subBuilder: Device_UserInfo.create)
    ..aOS(30, _omitFieldNames ? '' : 'birthTime')
    ..aOS(31, _omitFieldNames ? '' : 'bootTime')
    ..aOS(32, _omitFieldNames ? '' : 'updateTime')
    ..aOS(33, _omitFieldNames ? '' : 'idfv')
    ..aOS(34, _omitFieldNames ? '' : 'idfvMd5')
    ..aE<Language>(35, _omitFieldNames ? '' : 'language',
        enumValues: Language.values)
    ..aOS(36, _omitFieldNames ? '' : 'timezone')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device copyWith(void Function(Device) updates) =>
      super.copyWith((message) => updates(message as Device)) as Device;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Device create() => Device._();
  @$core.override
  Device createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Device getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Device>(create);
  static Device? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get ip => $_getSZ(0);
  @$pb.TagNumber(1)
  set ip($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIp() => $_has(0);
  @$pb.TagNumber(1)
  void clearIp() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userAgent => $_getSZ(1);
  @$pb.TagNumber(2)
  set userAgent($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserAgent() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserAgent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get idfa => $_getSZ(2);
  @$pb.TagNumber(3)
  set idfa($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIdfa() => $_has(2);
  @$pb.TagNumber(3)
  void clearIdfa() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get idfaMd5 => $_getSZ(3);
  @$pb.TagNumber(4)
  set idfaMd5($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIdfaMd5() => $_has(3);
  @$pb.TagNumber(4)
  void clearIdfaMd5() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get imei => $_getSZ(4);
  @$pb.TagNumber(5)
  set imei($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasImei() => $_has(4);
  @$pb.TagNumber(5)
  void clearImei() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get imeiMd5 => $_getSZ(5);
  @$pb.TagNumber(6)
  set imeiMd5($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasImeiMd5() => $_has(5);
  @$pb.TagNumber(6)
  void clearImeiMd5() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get oaid => $_getSZ(6);
  @$pb.TagNumber(7)
  set oaid($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOaid() => $_has(6);
  @$pb.TagNumber(7)
  void clearOaid() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get oaidMd5 => $_getSZ(7);
  @$pb.TagNumber(8)
  set oaidMd5($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOaidMd5() => $_has(7);
  @$pb.TagNumber(8)
  void clearOaidMd5() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get androidId => $_getSZ(8);
  @$pb.TagNumber(9)
  set androidId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAndroidId() => $_has(8);
  @$pb.TagNumber(9)
  void clearAndroidId() => $_clearField(9);

  /// 0-手机；1-平板；2-PC；3-互联网电视。
  @$pb.TagNumber(10)
  $core.int get deviceType => $_getIZ(9);
  @$pb.TagNumber(10)
  set deviceType($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDeviceType() => $_has(9);
  @$pb.TagNumber(10)
  void clearDeviceType() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get brand => $_getSZ(10);
  @$pb.TagNumber(11)
  set brand($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasBrand() => $_has(10);
  @$pb.TagNumber(11)
  void clearBrand() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get model => $_getSZ(11);
  @$pb.TagNumber(12)
  set model($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasModel() => $_has(11);
  @$pb.TagNumber(12)
  void clearModel() => $_clearField(12);

  /// 1-Android；2-iOS。
  @$pb.TagNumber(13)
  $core.int get os => $_getIZ(12);
  @$pb.TagNumber(13)
  set os($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasOs() => $_has(12);
  @$pb.TagNumber(13)
  void clearOs() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get osv => $_getSZ(13);
  @$pb.TagNumber(14)
  set osv($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasOsv() => $_has(13);
  @$pb.TagNumber(14)
  void clearOsv() => $_clearField(14);

  /// 0-未识别；1-wifi；2-2G；3-3G；4-4G；5-5G。
  @$pb.TagNumber(15)
  $core.int get network => $_getIZ(14);
  @$pb.TagNumber(15)
  set network($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasNetwork() => $_has(14);
  @$pb.TagNumber(15)
  void clearNetwork() => $_clearField(15);

  /// 0-未知；1-移动；2-联通；3-电信。
  @$pb.TagNumber(16)
  $core.int get operator => $_getIZ(15);
  @$pb.TagNumber(16)
  set operator($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(16)
  $core.bool hasOperator() => $_has(15);
  @$pb.TagNumber(16)
  void clearOperator() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.int get width => $_getIZ(16);
  @$pb.TagNumber(17)
  set width($core.int value) => $_setSignedInt32(16, value);
  @$pb.TagNumber(17)
  $core.bool hasWidth() => $_has(16);
  @$pb.TagNumber(17)
  void clearWidth() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get height => $_getIZ(17);
  @$pb.TagNumber(18)
  set height($core.int value) => $_setSignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasHeight() => $_has(17);
  @$pb.TagNumber(18)
  void clearHeight() => $_clearField(18);

  /// 0-未知；1-竖屏；2-横屏。
  @$pb.TagNumber(20)
  $core.int get orientation => $_getIZ(18);
  @$pb.TagNumber(20)
  set orientation($core.int value) => $_setSignedInt32(18, value);
  @$pb.TagNumber(20)
  $core.bool hasOrientation() => $_has(18);
  @$pb.TagNumber(20)
  void clearOrientation() => $_clearField(20);

  @$pb.TagNumber(21)
  Device_Geo get geo => $_getN(19);
  @$pb.TagNumber(21)
  set geo(Device_Geo value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasGeo() => $_has(19);
  @$pb.TagNumber(21)
  void clearGeo() => $_clearField(21);
  @$pb.TagNumber(21)
  Device_Geo ensureGeo() => $_ensure(19);

  @$pb.TagNumber(22)
  $pb.PbList<$core.String> get installedApp => $_getList(20);

  @$pb.TagNumber(23)
  $pb.PbList<Device_CAID> get caids => $_getList(21);

  @$pb.TagNumber(24)
  $core.String get bootMark => $_getSZ(22);
  @$pb.TagNumber(24)
  set bootMark($core.String value) => $_setString(22, value);
  @$pb.TagNumber(24)
  $core.bool hasBootMark() => $_has(22);
  @$pb.TagNumber(24)
  void clearBootMark() => $_clearField(24);

  @$pb.TagNumber(25)
  $core.String get updateMark => $_getSZ(23);
  @$pb.TagNumber(25)
  set updateMark($core.String value) => $_setString(23, value);
  @$pb.TagNumber(25)
  $core.bool hasUpdateMark() => $_has(23);
  @$pb.TagNumber(25)
  void clearUpdateMark() => $_clearField(25);

  @$pb.TagNumber(26)
  $core.String get mac => $_getSZ(24);
  @$pb.TagNumber(26)
  set mac($core.String value) => $_setString(24, value);
  @$pb.TagNumber(26)
  $core.bool hasMac() => $_has(24);
  @$pb.TagNumber(26)
  void clearMac() => $_clearField(26);

  @$pb.TagNumber(27)
  $core.String get androidIdMd5 => $_getSZ(25);
  @$pb.TagNumber(27)
  set androidIdMd5($core.String value) => $_setString(25, value);
  @$pb.TagNumber(27)
  $core.bool hasAndroidIdMd5() => $_has(25);
  @$pb.TagNumber(27)
  void clearAndroidIdMd5() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.String get ipv6 => $_getSZ(26);
  @$pb.TagNumber(28)
  set ipv6($core.String value) => $_setString(26, value);
  @$pb.TagNumber(28)
  $core.bool hasIpv6() => $_has(26);
  @$pb.TagNumber(28)
  void clearIpv6() => $_clearField(28);

  @$pb.TagNumber(29)
  Device_UserInfo get userInfo => $_getN(27);
  @$pb.TagNumber(29)
  set userInfo(Device_UserInfo value) => $_setField(29, value);
  @$pb.TagNumber(29)
  $core.bool hasUserInfo() => $_has(27);
  @$pb.TagNumber(29)
  void clearUserInfo() => $_clearField(29);
  @$pb.TagNumber(29)
  Device_UserInfo ensureUserInfo() => $_ensure(27);

  @$pb.TagNumber(30)
  $core.String get birthTime => $_getSZ(28);
  @$pb.TagNumber(30)
  set birthTime($core.String value) => $_setString(28, value);
  @$pb.TagNumber(30)
  $core.bool hasBirthTime() => $_has(28);
  @$pb.TagNumber(30)
  void clearBirthTime() => $_clearField(30);

  @$pb.TagNumber(31)
  $core.String get bootTime => $_getSZ(29);
  @$pb.TagNumber(31)
  set bootTime($core.String value) => $_setString(29, value);
  @$pb.TagNumber(31)
  $core.bool hasBootTime() => $_has(29);
  @$pb.TagNumber(31)
  void clearBootTime() => $_clearField(31);

  @$pb.TagNumber(32)
  $core.String get updateTime => $_getSZ(30);
  @$pb.TagNumber(32)
  set updateTime($core.String value) => $_setString(30, value);
  @$pb.TagNumber(32)
  $core.bool hasUpdateTime() => $_has(30);
  @$pb.TagNumber(32)
  void clearUpdateTime() => $_clearField(32);

  @$pb.TagNumber(33)
  $core.String get idfv => $_getSZ(31);
  @$pb.TagNumber(33)
  set idfv($core.String value) => $_setString(31, value);
  @$pb.TagNumber(33)
  $core.bool hasIdfv() => $_has(31);
  @$pb.TagNumber(33)
  void clearIdfv() => $_clearField(33);

  @$pb.TagNumber(34)
  $core.String get idfvMd5 => $_getSZ(32);
  @$pb.TagNumber(34)
  set idfvMd5($core.String value) => $_setString(32, value);
  @$pb.TagNumber(34)
  $core.bool hasIdfvMd5() => $_has(32);
  @$pb.TagNumber(34)
  void clearIdfvMd5() => $_clearField(34);

  @$pb.TagNumber(35)
  Language get language => $_getN(33);
  @$pb.TagNumber(35)
  set language(Language value) => $_setField(35, value);
  @$pb.TagNumber(35)
  $core.bool hasLanguage() => $_has(33);
  @$pb.TagNumber(35)
  void clearLanguage() => $_clearField(35);

  @$pb.TagNumber(36)
  $core.String get timezone => $_getSZ(34);
  @$pb.TagNumber(36)
  set timezone($core.String value) => $_setString(34, value);
  @$pb.TagNumber(36)
  $core.bool hasTimezone() => $_has(34);
  @$pb.TagNumber(36)
  void clearTimezone() => $_clearField(36);
}

class RequestHeader extends $pb.GeneratedMessage {
  factory RequestHeader({
    $core.String? token,
    $core.String? platform,
    $core.String? appVersion,
    $core.String? deviceId,
    $core.String? language,
    Device? device,
    $core.String? guestCredential,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (platform != null) result.platform = platform;
    if (appVersion != null) result.appVersion = appVersion;
    if (deviceId != null) result.deviceId = deviceId;
    if (language != null) result.language = language;
    if (device != null) result.device = device;
    if (guestCredential != null) result.guestCredential = guestCredential;
    return result;
  }

  RequestHeader._();

  factory RequestHeader.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RequestHeader.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RequestHeader',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bobobeads.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aOS(2, _omitFieldNames ? '' : 'platform')
    ..aOS(3, _omitFieldNames ? '' : 'appVersion')
    ..aOS(4, _omitFieldNames ? '' : 'deviceId')
    ..aOS(5, _omitFieldNames ? '' : 'language')
    ..aOM<Device>(6, _omitFieldNames ? '' : 'device', subBuilder: Device.create)
    ..aOS(7, _omitFieldNames ? '' : 'guestCredential')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestHeader clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestHeader copyWith(void Function(RequestHeader) updates) =>
      super.copyWith((message) => updates(message as RequestHeader))
          as RequestHeader;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RequestHeader create() => RequestHeader._();
  @$core.override
  RequestHeader createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RequestHeader getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RequestHeader>(create);
  static RequestHeader? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get platform => $_getSZ(1);
  @$pb.TagNumber(2)
  set platform($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlatform() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlatform() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get appVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set appVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAppVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearAppVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get deviceId => $_getSZ(3);
  @$pb.TagNumber(4)
  set deviceId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeviceId() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get language => $_getSZ(4);
  @$pb.TagNumber(5)
  set language($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLanguage() => $_has(4);
  @$pb.TagNumber(5)
  void clearLanguage() => $_clearField(5);

  @$pb.TagNumber(6)
  Device get device => $_getN(5);
  @$pb.TagNumber(6)
  set device(Device value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDevice() => $_has(5);
  @$pb.TagNumber(6)
  void clearDevice() => $_clearField(6);
  @$pb.TagNumber(6)
  Device ensureDevice() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.String get guestCredential => $_getSZ(6);
  @$pb.TagNumber(7)
  set guestCredential($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasGuestCredential() => $_has(6);
  @$pb.TagNumber(7)
  void clearGuestCredential() => $_clearField(7);
}

class ResponseHeader extends $pb.GeneratedMessage {
  factory ResponseHeader({
    $core.int? code,
    $core.String? message,
    $core.String? traceId,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    if (traceId != null) result.traceId = traceId;
    return result;
  }

  ResponseHeader._();

  factory ResponseHeader.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResponseHeader.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResponseHeader',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bobobeads.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOS(3, _omitFieldNames ? '' : 'traceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResponseHeader clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResponseHeader copyWith(void Function(ResponseHeader) updates) =>
      super.copyWith((message) => updates(message as ResponseHeader))
          as ResponseHeader;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResponseHeader create() => ResponseHeader._();
  @$core.override
  ResponseHeader createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResponseHeader getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResponseHeader>(create);
  static ResponseHeader? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get code => $_getIZ(0);
  @$pb.TagNumber(1)
  set code($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get traceId => $_getSZ(2);
  @$pb.TagNumber(3)
  set traceId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTraceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTraceId() => $_clearField(3);
}

class PageRequest extends $pb.GeneratedMessage {
  factory PageRequest({
    $core.int? page,
    $core.int? pageSize,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (pageSize != null) result.pageSize = pageSize;
    return result;
  }

  PageRequest._();

  factory PageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bobobeads.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'page')
    ..aI(2, _omitFieldNames ? '' : 'pageSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageRequest copyWith(void Function(PageRequest) updates) =>
      super.copyWith((message) => updates(message as PageRequest))
          as PageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PageRequest create() => PageRequest._();
  @$core.override
  PageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PageRequest>(create);
  static PageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get page => $_getIZ(0);
  @$pb.TagNumber(1)
  set page($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get pageSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set pageSize($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageSize() => $_clearField(2);
}

class PageResponse extends $pb.GeneratedMessage {
  factory PageResponse({
    $core.int? total,
    $core.int? page,
    $core.int? pageSize,
    $core.bool? hasMore,
  }) {
    final result = create();
    if (total != null) result.total = total;
    if (page != null) result.page = page;
    if (pageSize != null) result.pageSize = pageSize;
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  PageResponse._();

  factory PageResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PageResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PageResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'bobobeads.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'total')
    ..aI(2, _omitFieldNames ? '' : 'page')
    ..aI(3, _omitFieldNames ? '' : 'pageSize')
    ..aOB(4, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageResponse copyWith(void Function(PageResponse) updates) =>
      super.copyWith((message) => updates(message as PageResponse))
          as PageResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PageResponse create() => PageResponse._();
  @$core.override
  PageResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PageResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PageResponse>(create);
  static PageResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get total => $_getIZ(0);
  @$pb.TagNumber(1)
  set total($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotal() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotal() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get page => $_getIZ(1);
  @$pb.TagNumber(2)
  set page($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get pageSize => $_getIZ(2);
  @$pb.TagNumber(3)
  set pageSize($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPageSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageSize() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get hasMore => $_getBF(3);
  @$pb.TagNumber(4)
  set hasMore($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHasMore() => $_has(3);
  @$pb.TagNumber(4)
  void clearHasMore() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
