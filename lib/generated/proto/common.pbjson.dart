// This is a generated file - do not edit.
//
// Generated from common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use languageDescriptor instead')
const Language$json = {
  '1': 'Language',
  '2': [
    {'1': 'CHINESE', '2': 0},
    {'1': 'ENGLISH', '2': 1},
    {'1': 'RUSSIAN', '2': 2},
    {'1': 'VIETNAMESE', '2': 3},
    {'1': 'PORTUGUESE', '2': 4},
    {'1': 'INDONESIAN', '2': 5},
    {'1': 'MALAY', '2': 6},
    {'1': 'THAI', '2': 7},
    {'1': 'FILIPINO', '2': 8},
  ],
};

/// Descriptor for `Language`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List languageDescriptor = $convert.base64Decode(
    'CghMYW5ndWFnZRILCgdDSElORVNFEAASCwoHRU5HTElTSBABEgsKB1JVU1NJQU4QAhIOCgpWSU'
    'VUTkFNRVNFEAMSDgoKUE9SVFVHVUVTRRAEEg4KCklORE9ORVNJQU4QBRIJCgVNQUxBWRAGEggK'
    'BFRIQUkQBxIMCghGSUxJUElOTxAI');

@$core.Deprecated('Use platformDescriptor instead')
const Platform$json = {
  '1': 'Platform',
  '2': [
    {'1': 'PLATFORM_UNKNOWN', '2': 0},
    {'1': 'PLATFORM_IOS', '2': 1},
    {'1': 'PLATFORM_ANDROID', '2': 2},
    {'1': 'PLATFORM_MINIPROGRAM', '2': 3},
    {'1': 'PLATFORM_WEB', '2': 4},
  ],
};

/// Descriptor for `Platform`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List platformDescriptor = $convert.base64Decode(
    'CghQbGF0Zm9ybRIUChBQTEFURk9STV9VTktOT1dOEAASEAoMUExBVEZPUk1fSU9TEAESFAoQUE'
    'xBVEZPUk1fQU5EUk9JRBACEhgKFFBMQVRGT1JNX01JTklQUk9HUkFNEAMSEAoMUExBVEZPUk1f'
    'V0VCEAQ=');

@$core.Deprecated('Use deviceDescriptor instead')
const Device$json = {
  '1': 'Device',
  '2': [
    {'1': 'ip', '3': 1, '4': 1, '5': 9, '10': 'ip'},
    {'1': 'user_agent', '3': 2, '4': 1, '5': 9, '10': 'userAgent'},
    {'1': 'idfa', '3': 3, '4': 1, '5': 9, '10': 'idfa'},
    {'1': 'idfa_md5', '3': 4, '4': 1, '5': 9, '10': 'idfaMd5'},
    {'1': 'imei', '3': 5, '4': 1, '5': 9, '10': 'imei'},
    {'1': 'imei_md5', '3': 6, '4': 1, '5': 9, '10': 'imeiMd5'},
    {'1': 'oaid', '3': 7, '4': 1, '5': 9, '10': 'oaid'},
    {'1': 'oaid_md5', '3': 8, '4': 1, '5': 9, '10': 'oaidMd5'},
    {'1': 'android_id', '3': 9, '4': 1, '5': 9, '10': 'androidId'},
    {'1': 'device_type', '3': 10, '4': 1, '5': 5, '10': 'deviceType'},
    {'1': 'brand', '3': 11, '4': 1, '5': 9, '10': 'brand'},
    {'1': 'model', '3': 12, '4': 1, '5': 9, '10': 'model'},
    {'1': 'os', '3': 13, '4': 1, '5': 5, '10': 'os'},
    {'1': 'osv', '3': 14, '4': 1, '5': 9, '10': 'osv'},
    {'1': 'network', '3': 15, '4': 1, '5': 5, '10': 'network'},
    {'1': 'operator', '3': 16, '4': 1, '5': 5, '10': 'operator'},
    {'1': 'width', '3': 17, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 18, '4': 1, '5': 5, '10': 'height'},
    {'1': 'orientation', '3': 20, '4': 1, '5': 5, '10': 'orientation'},
    {
      '1': 'geo',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.bobobeads.v1.Device.Geo',
      '10': 'geo'
    },
    {'1': 'installed_app', '3': 22, '4': 3, '5': 9, '10': 'installedApp'},
    {
      '1': 'caids',
      '3': 23,
      '4': 3,
      '5': 11,
      '6': '.bobobeads.v1.Device.CAID',
      '10': 'caids'
    },
    {'1': 'boot_mark', '3': 24, '4': 1, '5': 9, '10': 'bootMark'},
    {'1': 'update_mark', '3': 25, '4': 1, '5': 9, '10': 'updateMark'},
    {'1': 'mac', '3': 26, '4': 1, '5': 9, '10': 'mac'},
    {'1': 'android_id_md5', '3': 27, '4': 1, '5': 9, '10': 'androidIdMd5'},
    {'1': 'ipv6', '3': 28, '4': 1, '5': 9, '10': 'ipv6'},
    {
      '1': 'user_info',
      '3': 29,
      '4': 1,
      '5': 11,
      '6': '.bobobeads.v1.Device.UserInfo',
      '10': 'userInfo'
    },
    {'1': 'birth_time', '3': 30, '4': 1, '5': 9, '10': 'birthTime'},
    {'1': 'boot_time', '3': 31, '4': 1, '5': 9, '10': 'bootTime'},
    {'1': 'update_time', '3': 32, '4': 1, '5': 9, '10': 'updateTime'},
    {'1': 'idfv', '3': 33, '4': 1, '5': 9, '10': 'idfv'},
    {'1': 'idfv_md5', '3': 34, '4': 1, '5': 9, '10': 'idfvMd5'},
    {
      '1': 'language',
      '3': 35,
      '4': 1,
      '5': 14,
      '6': '.bobobeads.v1.Language',
      '10': 'language'
    },
    {'1': 'timezone', '3': 36, '4': 1, '5': 9, '10': 'timezone'},
  ],
  '3': [Device_Geo$json, Device_CAID$json, Device_UserInfo$json],
};

@$core.Deprecated('Use deviceDescriptor instead')
const Device_Geo$json = {
  '1': 'Geo',
  '2': [
    {'1': 'lat', '3': 1, '4': 1, '5': 1, '10': 'lat'},
    {'1': 'lon', '3': 2, '4': 1, '5': 1, '10': 'lon'},
  ],
};

@$core.Deprecated('Use deviceDescriptor instead')
const Device_CAID$json = {
  '1': 'CAID',
  '2': [
    {'1': 'ver', '3': 1, '4': 1, '5': 9, '10': 'ver'},
    {'1': 'caid', '3': 2, '4': 1, '5': 9, '10': 'caid'},
  ],
};

@$core.Deprecated('Use deviceDescriptor instead')
const Device_UserInfo$json = {
  '1': 'UserInfo',
  '2': [
    {'1': 'age', '3': 1, '4': 1, '5': 5, '10': 'age'},
    {'1': 'gender', '3': 2, '4': 1, '5': 5, '10': 'gender'},
  ],
};

/// Descriptor for `Device`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceDescriptor = $convert.base64Decode(
    'CgZEZXZpY2USDgoCaXAYASABKAlSAmlwEh0KCnVzZXJfYWdlbnQYAiABKAlSCXVzZXJBZ2VudB'
    'ISCgRpZGZhGAMgASgJUgRpZGZhEhkKCGlkZmFfbWQ1GAQgASgJUgdpZGZhTWQ1EhIKBGltZWkY'
    'BSABKAlSBGltZWkSGQoIaW1laV9tZDUYBiABKAlSB2ltZWlNZDUSEgoEb2FpZBgHIAEoCVIEb2'
    'FpZBIZCghvYWlkX21kNRgIIAEoCVIHb2FpZE1kNRIdCgphbmRyb2lkX2lkGAkgASgJUglhbmRy'
    'b2lkSWQSHwoLZGV2aWNlX3R5cGUYCiABKAVSCmRldmljZVR5cGUSFAoFYnJhbmQYCyABKAlSBW'
    'JyYW5kEhQKBW1vZGVsGAwgASgJUgVtb2RlbBIOCgJvcxgNIAEoBVICb3MSEAoDb3N2GA4gASgJ'
    'UgNvc3YSGAoHbmV0d29yaxgPIAEoBVIHbmV0d29yaxIaCghvcGVyYXRvchgQIAEoBVIIb3Blcm'
    'F0b3ISFAoFd2lkdGgYESABKAVSBXdpZHRoEhYKBmhlaWdodBgSIAEoBVIGaGVpZ2h0EiAKC29y'
    'aWVudGF0aW9uGBQgASgFUgtvcmllbnRhdGlvbhIqCgNnZW8YFSABKAsyGC5ib2JvYmVhZHMudj'
    'EuRGV2aWNlLkdlb1IDZ2VvEiMKDWluc3RhbGxlZF9hcHAYFiADKAlSDGluc3RhbGxlZEFwcBIv'
    'CgVjYWlkcxgXIAMoCzIZLmJvYm9iZWFkcy52MS5EZXZpY2UuQ0FJRFIFY2FpZHMSGwoJYm9vdF'
    '9tYXJrGBggASgJUghib290TWFyaxIfCgt1cGRhdGVfbWFyaxgZIAEoCVIKdXBkYXRlTWFyaxIQ'
    'CgNtYWMYGiABKAlSA21hYxIkCg5hbmRyb2lkX2lkX21kNRgbIAEoCVIMYW5kcm9pZElkTWQ1Eh'
    'IKBGlwdjYYHCABKAlSBGlwdjYSOgoJdXNlcl9pbmZvGB0gASgLMh0uYm9ib2JlYWRzLnYxLkRl'
    'dmljZS5Vc2VySW5mb1IIdXNlckluZm8SHQoKYmlydGhfdGltZRgeIAEoCVIJYmlydGhUaW1lEh'
    'sKCWJvb3RfdGltZRgfIAEoCVIIYm9vdFRpbWUSHwoLdXBkYXRlX3RpbWUYICABKAlSCnVwZGF0'
    'ZVRpbWUSEgoEaWRmdhghIAEoCVIEaWRmdhIZCghpZGZ2X21kNRgiIAEoCVIHaWRmdk1kNRIyCg'
    'hsYW5ndWFnZRgjIAEoDjIWLmJvYm9iZWFkcy52MS5MYW5ndWFnZVIIbGFuZ3VhZ2USGgoIdGlt'
    'ZXpvbmUYJCABKAlSCHRpbWV6b25lGikKA0dlbxIQCgNsYXQYASABKAFSA2xhdBIQCgNsb24YAi'
    'ABKAFSA2xvbhosCgRDQUlEEhAKA3ZlchgBIAEoCVIDdmVyEhIKBGNhaWQYAiABKAlSBGNhaWQa'
    'NAoIVXNlckluZm8SEAoDYWdlGAEgASgFUgNhZ2USFgoGZ2VuZGVyGAIgASgFUgZnZW5kZXI=');

@$core.Deprecated('Use requestHeaderDescriptor instead')
const RequestHeader$json = {
  '1': 'RequestHeader',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'platform', '3': 2, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'app_version', '3': 3, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'device_id', '3': 4, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'language', '3': 5, '4': 1, '5': 9, '10': 'language'},
    {
      '1': 'device',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.bobobeads.v1.Device',
      '10': 'device'
    },
    {'1': 'guest_credential', '3': 7, '4': 1, '5': 9, '10': 'guestCredential'},
  ],
};

/// Descriptor for `RequestHeader`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestHeaderDescriptor = $convert.base64Decode(
    'Cg1SZXF1ZXN0SGVhZGVyEhQKBXRva2VuGAEgASgJUgV0b2tlbhIaCghwbGF0Zm9ybRgCIAEoCV'
    'IIcGxhdGZvcm0SHwoLYXBwX3ZlcnNpb24YAyABKAlSCmFwcFZlcnNpb24SGwoJZGV2aWNlX2lk'
    'GAQgASgJUghkZXZpY2VJZBIaCghsYW5ndWFnZRgFIAEoCVIIbGFuZ3VhZ2USLAoGZGV2aWNlGA'
    'YgASgLMhQuYm9ib2JlYWRzLnYxLkRldmljZVIGZGV2aWNlEikKEGd1ZXN0X2NyZWRlbnRpYWwY'
    'ByABKAlSD2d1ZXN0Q3JlZGVudGlhbA==');

@$core.Deprecated('Use responseHeaderDescriptor instead')
const ResponseHeader$json = {
  '1': 'ResponseHeader',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 5, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'trace_id', '3': 3, '4': 1, '5': 9, '10': 'traceId'},
  ],
};

/// Descriptor for `ResponseHeader`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List responseHeaderDescriptor = $convert.base64Decode(
    'Cg5SZXNwb25zZUhlYWRlchISCgRjb2RlGAEgASgFUgRjb2RlEhgKB21lc3NhZ2UYAiABKAlSB2'
    '1lc3NhZ2USGQoIdHJhY2VfaWQYAyABKAlSB3RyYWNlSWQ=');

@$core.Deprecated('Use pageRequestDescriptor instead')
const PageRequest$json = {
  '1': 'PageRequest',
  '2': [
    {'1': 'page', '3': 1, '4': 1, '5': 5, '10': 'page'},
    {'1': 'page_size', '3': 2, '4': 1, '5': 5, '10': 'pageSize'},
  ],
};

/// Descriptor for `PageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageRequestDescriptor = $convert.base64Decode(
    'CgtQYWdlUmVxdWVzdBISCgRwYWdlGAEgASgFUgRwYWdlEhsKCXBhZ2Vfc2l6ZRgCIAEoBVIIcG'
    'FnZVNpemU=');

@$core.Deprecated('Use pageResponseDescriptor instead')
const PageResponse$json = {
  '1': 'PageResponse',
  '2': [
    {'1': 'total', '3': 1, '4': 1, '5': 5, '10': 'total'},
    {'1': 'page', '3': 2, '4': 1, '5': 5, '10': 'page'},
    {'1': 'page_size', '3': 3, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'has_more', '3': 4, '4': 1, '5': 8, '10': 'hasMore'},
  ],
};

/// Descriptor for `PageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageResponseDescriptor = $convert.base64Decode(
    'CgxQYWdlUmVzcG9uc2USFAoFdG90YWwYASABKAVSBXRvdGFsEhIKBHBhZ2UYAiABKAVSBHBhZ2'
    'USGwoJcGFnZV9zaXplGAMgASgFUghwYWdlU2l6ZRIZCghoYXNfbW9yZRgEIAEoCFIHaGFzTW9y'
    'ZQ==');
