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

class Language extends $pb.ProtobufEnum {
  static const Language CHINESE =
      Language._(0, _omitEnumNames ? '' : 'CHINESE');
  static const Language ENGLISH =
      Language._(1, _omitEnumNames ? '' : 'ENGLISH');
  static const Language RUSSIAN =
      Language._(2, _omitEnumNames ? '' : 'RUSSIAN');
  static const Language VIETNAMESE =
      Language._(3, _omitEnumNames ? '' : 'VIETNAMESE');
  static const Language PORTUGUESE =
      Language._(4, _omitEnumNames ? '' : 'PORTUGUESE');
  static const Language INDONESIAN =
      Language._(5, _omitEnumNames ? '' : 'INDONESIAN');
  static const Language MALAY = Language._(6, _omitEnumNames ? '' : 'MALAY');
  static const Language THAI = Language._(7, _omitEnumNames ? '' : 'THAI');
  static const Language FILIPINO =
      Language._(8, _omitEnumNames ? '' : 'FILIPINO');

  static const $core.List<Language> values = <Language>[
    CHINESE,
    ENGLISH,
    RUSSIAN,
    VIETNAMESE,
    PORTUGUESE,
    INDONESIAN,
    MALAY,
    THAI,
    FILIPINO,
  ];

  static final $core.List<Language?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static Language? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Language._(super.value, super.name);
}

class Platform extends $pb.ProtobufEnum {
  static const Platform PLATFORM_UNKNOWN =
      Platform._(0, _omitEnumNames ? '' : 'PLATFORM_UNKNOWN');
  static const Platform PLATFORM_IOS =
      Platform._(1, _omitEnumNames ? '' : 'PLATFORM_IOS');
  static const Platform PLATFORM_ANDROID =
      Platform._(2, _omitEnumNames ? '' : 'PLATFORM_ANDROID');
  static const Platform PLATFORM_MINIPROGRAM =
      Platform._(3, _omitEnumNames ? '' : 'PLATFORM_MINIPROGRAM');
  static const Platform PLATFORM_WEB =
      Platform._(4, _omitEnumNames ? '' : 'PLATFORM_WEB');

  static const $core.List<Platform> values = <Platform>[
    PLATFORM_UNKNOWN,
    PLATFORM_IOS,
    PLATFORM_ANDROID,
    PLATFORM_MINIPROGRAM,
    PLATFORM_WEB,
  ];

  static final $core.List<Platform?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static Platform? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Platform._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
