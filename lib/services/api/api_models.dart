import 'dart:typed_data';

import '../../models/color.dart';
import '../../models/draft_project.dart';
import '../../models/generated_pattern.dart';
import '../../models/palette.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiException implements Exception {
  final int code;
  final String message;
  final String? traceId;
  final int? httpStatusCode;

  const ApiException(
    this.code,
    this.message, {
    this.traceId,
    this.httpStatusCode,
  });

  bool get isUnauthenticated =>
      httpStatusCode == 401 || code == 1001 || code == 1002;

  @override
  String toString() {
    final http = httpStatusCode == null ? '' : ', http=$httpStatusCode';
    final trace = traceId == null || traceId!.isEmpty
        ? ''
        : ', traceId=$traceId';
    return 'ApiException($code, $message$http$trace)';
  }
}

class ResponseHeader {
  final int code;
  final String message;
  final String? traceId;

  const ResponseHeader({
    required this.code,
    required this.message,
    this.traceId,
  });

  factory ResponseHeader.fromJson(JsonMap json) {
    return ResponseHeader(
      code: _intValue(json['code']),
      message: _stringValue(json['message'], fallback: 'success'),
      traceId: _nullableString(json['traceId']),
    );
  }
}

class PageResponse {
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  const PageResponse({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory PageResponse.fromJson(JsonMap? json) {
    final data = json ?? const {};
    return PageResponse(
      total: _intValue(data['total']),
      page: _intValue(data['page'], fallback: 1),
      pageSize: _intValue(data['pageSize'], fallback: 20),
      hasMore: _boolValue(data['hasMore']),
    );
  }
}

class PagedResult<T> {
  final List<T> items;
  final PageResponse page;

  const PagedResult({required this.items, required this.page});
}

class ApiUser {
  final String userId;
  final String nickname;
  final String avatarUrl;
  final String phone;
  final bool isVip;

  const ApiUser({
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    required this.phone,
    required this.isVip,
  });

  factory ApiUser.fromJson(JsonMap? json) {
    final data = json ?? const {};
    return ApiUser(
      userId: _stringValue(data['userId']),
      nickname: _stringValue(data['nickname']),
      avatarUrl: _stringValue(data['avatarUrl']),
      phone: _stringValue(data['phone']),
      isVip: _boolValue(data['isVip']),
    );
  }

  JsonMap toJson() => {
    'userId': userId,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
    'phone': phone,
    'isVip': isVip,
  };
}

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final ApiUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthSession.fromJson(JsonMap json, {ApiUser? fallbackUser}) {
    final responseUser = ApiUser.fromJson(_mapValue(json['user']));
    final user = responseUser.userId.isEmpty && fallbackUser != null
        ? fallbackUser
        : responseUser;
    return AuthSession(
      accessToken: _stringValue(json['accessToken']),
      refreshToken: _stringValue(json['refreshToken']),
      expiresIn: _intValue(json['expiresIn']),
      user: user,
    );
  }

  factory AuthSession.fromStoredJson(JsonMap json) {
    return AuthSession(
      accessToken: _stringValue(json['accessToken']),
      refreshToken: _stringValue(json['refreshToken']),
      expiresIn: _intValue(json['expiresIn']),
      user: ApiUser.fromJson(_mapValue(json['user'])),
    );
  }

  JsonMap toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresIn': expiresIn,
    'user': user.toJson(),
  };
}

class TemplateCategory {
  final int categoryId;
  final String name;
  final String iconUrl;
  final int templateCount;

  const TemplateCategory({
    required this.categoryId,
    required this.name,
    required this.iconUrl,
    required this.templateCount,
  });

  factory TemplateCategory.fromJson(JsonMap json) {
    return TemplateCategory(
      categoryId: _intValue(json['categoryId']),
      name: _stringValue(json['name']),
      iconUrl: _stringValue(json['iconUrl']),
      templateCount: _intValue(json['templateCount']),
    );
  }
}

class TemplateItem {
  final String templateId;
  final String title;
  final String previewUrl;
  final String thumbnailUrl;
  final String description;
  final String boardSpec;
  final List<String> tags;
  final int difficulty;
  final int width;
  final int height;
  final int colorCount;
  final bool isFree;
  final int creditCost;
  final int downloadCount;
  final int favoriteCount;
  final bool isFavorited;

  const TemplateItem({
    required this.templateId,
    required this.title,
    required this.previewUrl,
    required this.thumbnailUrl,
    required this.description,
    required this.boardSpec,
    required this.tags,
    required this.difficulty,
    required this.width,
    required this.height,
    required this.colorCount,
    required this.isFree,
    required this.creditCost,
    required this.downloadCount,
    required this.favoriteCount,
    required this.isFavorited,
  });

  factory TemplateItem.fromJson(JsonMap json) {
    return TemplateItem(
      templateId: _stringValue(json['templateId']),
      title: _stringValue(json['title']),
      previewUrl: _stringValue(json['previewUrl']),
      thumbnailUrl: _stringValue(json['thumbnailUrl']),
      description: _stringValue(json['description']),
      boardSpec: _stringValue(json['boardSpec']),
      tags: _stringList(json['tags']),
      difficulty: _intValue(json['difficulty']),
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      colorCount: _intValue(json['colorCount']),
      isFree: _boolValue(json['isFree']),
      creditCost: _intValue(json['creditCost']),
      downloadCount: _intValue(json['downloadCount']),
      favoriteCount: _intValue(json['favoriteCount']),
      isFavorited: _boolValue(json['isFavorited']),
    );
  }

  TemplateItem copyWith({bool? isFavorited, int? favoriteCount}) {
    return TemplateItem(
      templateId: templateId,
      title: title,
      previewUrl: previewUrl,
      thumbnailUrl: thumbnailUrl,
      description: description,
      boardSpec: boardSpec,
      tags: tags,
      difficulty: difficulty,
      width: width,
      height: height,
      colorCount: colorCount,
      isFree: isFree,
      creditCost: creditCost,
      downloadCount: downloadCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isFavorited: isFavorited ?? this.isFavorited,
    );
  }
}

class TemplateDetail {
  final TemplateItem template;
  final PatternData patternData;

  const TemplateDetail({required this.template, required this.patternData});
}

class TemplateFavoriteResult {
  final bool isFavorited;
  final int favoriteCount;

  const TemplateFavoriteResult({
    required this.isFavorited,
    required this.favoriteCount,
  });

  factory TemplateFavoriteResult.fromJson(JsonMap json) {
    return TemplateFavoriteResult(
      isFavorited: _boolValue(json['isFavorited']),
      favoriteCount: _intValue(json['favoriteCount']),
    );
  }
}

class PatternPaletteColor {
  final int index;
  final String hex;
  final String brand;
  final String code;
  final String name;

  const PatternPaletteColor({
    required this.index,
    required this.hex,
    this.brand = '',
    this.code = '',
    this.name = '',
  });

  factory PatternPaletteColor.fromJson(JsonMap json) {
    return PatternPaletteColor(
      index: _intValue(json['index']),
      hex: _stringValue(json['hex']),
      brand: _stringValue(json['brand']),
      code: _stringValue(json['code']),
      name: _stringValue(json['name']),
    );
  }

  JsonMap toJson() => {
    'index': index,
    'hex': hex,
    if (brand.isNotEmpty) 'brand': brand,
    if (code.isNotEmpty) 'code': code,
    if (name.isNotEmpty) 'name': name,
  };
}

class PatternData {
  final int width;
  final int height;
  final String boardSpec;
  final List<int> pixels;
  final List<PatternPaletteColor> colorPalette;
  final int schemaVersion;

  const PatternData({
    required this.width,
    required this.height,
    required this.boardSpec,
    required this.pixels,
    required this.colorPalette,
    this.schemaVersion = 1,
  });

  factory PatternData.fromJson(JsonMap json) {
    return PatternData(
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      boardSpec: _stringValue(json['boardSpec']),
      pixels: _intList(json['pixels']),
      colorPalette: _mapList(
        json['colorPalette'],
        PatternPaletteColor.fromJson,
      ),
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
    );
  }

  factory PatternData.fromGeneratedPattern(
    GeneratedPattern pattern, {
    String? boardSpec,
  }) {
    final palette = <PatternPaletteColor>[];
    final colorIndexes = <int, int>{};

    for (var i = 0; i < pattern.paletteEntries.length; i++) {
      final entry = pattern.paletteEntries[i];
      final index = i + 1;
      colorIndexes[_rgbaKey(
            entry.color.rInt,
            entry.color.gInt,
            entry.color.bInt,
            entry.color.aInt,
          )] =
          index;
      palette.add(
        PatternPaletteColor(
          index: index,
          hex: entry.color.toHex(),
          brand: entry.prefix,
          code: entry.ref,
          name: entry.name,
        ),
      );
    }

    final source = pattern.pixels;
    final expectedLength = pattern.width * pattern.height * 4;
    if (source.length != expectedLength) {
      throw ArgumentError(
        'Pixel buffer length ${source.length} does not match ${pattern.width} x ${pattern.height}',
      );
    }

    final indexedPixels = List<int>.filled(pattern.width * pattern.height, 0);
    for (var i = 0; i < source.length; i += 4) {
      final alpha = source[i + 3];
      if (alpha == 0) continue;

      final key = _rgbaKey(source[i], source[i + 1], source[i + 2], alpha);
      var index = colorIndexes[key];
      if (index == null) {
        index = palette.length + 1;
        colorIndexes[key] = index;
        palette.add(
          PatternPaletteColor(
            index: index,
            hex: _rgbHex(source[i], source[i + 1], source[i + 2]),
            name: 'Color $index',
          ),
        );
      }
      indexedPixels[i ~/ 4] = index;
    }

    return PatternData(
      width: pattern.width,
      height: pattern.height,
      boardSpec: boardSpec ?? '${pattern.width}x${pattern.height}',
      pixels: indexedPixels,
      colorPalette: palette,
    );
  }

  GeneratedPattern toGeneratedPattern({DraftProject? draft}) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError.value(
        '$width x $height',
        'dimensions',
        'Pattern dimensions must be positive.',
      );
    }

    final expectedPixelCount = width * height;
    if (pixels.length != expectedPixelCount) {
      throw ArgumentError(
        'Pixel count ${pixels.length} does not match $width x $height.',
      );
    }

    final paletteByIndex = <int, PatternPaletteColor>{};
    for (final color in colorPalette) {
      if (color.index <= 0 || paletteByIndex.containsKey(color.index)) {
        throw ArgumentError.value(
          color.index,
          'colorPalette.index',
          'Palette indexes must be unique positive values.',
        );
      }
      paletteByIndex[color.index] = color;
    }

    final paletteEntries = <int, PaletteEntry>{
      for (final item in paletteByIndex.entries)
        item.key: PaletteEntry(
          name: item.value.name.isNotEmpty ? item.value.name : '颜色 ${item.key}',
          ref: item.value.code.isNotEmpty ? item.value.code : 'C${item.key}',
          symbol: item.value.code.isNotEmpty
              ? item.value.code.substring(0, 1).toUpperCase()
              : '${item.key}',
          color: _beadColorFromHex(item.value.hex),
          prefix: item.value.brand,
        ),
    };
    final orderedPaletteEntries = paletteEntries.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    final rgbaPixels = Uint8List(expectedPixelCount * 4);
    final usage = <String, int>{};
    for (var i = 0; i < pixels.length; i++) {
      final index = pixels[i];
      if (index == 0) continue;

      final entry = paletteEntries[index];
      if (entry == null) {
        throw ArgumentError.value(
          index,
          'pixels[$i]',
          'Each non-zero pixel index must be present in colorPalette.',
        );
      }

      final offset = i * 4;
      rgbaPixels[offset] = entry.color.rInt;
      rgbaPixels[offset + 1] = entry.color.gInt;
      rgbaPixels[offset + 2] = entry.color.bInt;
      rgbaPixels[offset + 3] = entry.color.aInt;
      usage.update(entry.ref, (count) => count + 1, ifAbsent: () => 1);
    }

    return GeneratedPattern(
      pixels: rgbaPixels,
      width: width,
      height: height,
      usage: usage,
      paletteEntries: orderedPaletteEntries
          .map((entry) => entry.value)
          .toList(),
      draft: draft ?? DraftProject(originalImageBytes: Uint8List(0)),
    );
  }

  JsonMap toJson() => {
    'width': width,
    'height': height,
    'boardSpec': boardSpec,
    'pixels': pixels,
    'colorPalette': colorPalette.map((color) => color.toJson()).toList(),
    'schemaVersion': schemaVersion,
  };
}

class UploadToken {
  final String uploadUrl;
  final String fileKey;
  final Map<String, String> headers;
  final int expiresAt;
  final String uploadMethod;
  final String publicUrl;
  final int maxFileSize;

  const UploadToken({
    required this.uploadUrl,
    required this.fileKey,
    required this.headers,
    required this.expiresAt,
    required this.uploadMethod,
    required this.publicUrl,
    required this.maxFileSize,
  });

  factory UploadToken.fromJson(JsonMap json) {
    return UploadToken(
      uploadUrl: _stringValue(json['uploadUrl']),
      fileKey: _stringValue(json['fileKey']),
      headers: _stringMap(json['headers']),
      expiresAt: _intValue(json['expiresAt']),
      uploadMethod: _stringValue(json['uploadMethod'], fallback: 'PUT'),
      publicUrl: _stringValue(json['publicUrl']),
      maxFileSize: _intValue(json['maxFileSize']),
    );
  }
}

class UploadedMedia {
  final String fileKey;
  final String fileUrl;

  const UploadedMedia({required this.fileKey, required this.fileUrl});
}

class AIStyleItem {
  final String styleId;
  final String styleKey;
  final String name;
  final String description;
  final String coverUrl;
  final String exampleUrl;
  final int costCredits;

  const AIStyleItem({
    required this.styleId,
    required this.styleKey,
    required this.name,
    required this.description,
    required this.coverUrl,
    required this.exampleUrl,
    required this.costCredits,
  });

  factory AIStyleItem.fromJson(JsonMap json) {
    return AIStyleItem(
      styleId: _stringValue(json['styleId']),
      styleKey: _stringValue(json['styleKey']),
      name: _stringValue(json['name']),
      description: _stringValue(json['description']),
      coverUrl: _stringValue(json['coverUrl']),
      exampleUrl: _stringValue(json['exampleUrl']),
      costCredits: _intValue(json['costCredits']),
    );
  }
}

class AIGenerationItem {
  static const int pending = 0;
  static const int running = 1;
  static const int succeeded = 2;
  static const int failed = 3;
  static const int cancelled = 4;
  static const int expired = 5;

  final String taskId;
  final String styleId;
  final String styleName;
  final String inputImageUrl;
  final String outputImageUrl;
  final int status;
  final int creditsDeducted;
  final String errorMessage;
  final int createdAt;
  final int completedAt;

  const AIGenerationItem({
    required this.taskId,
    required this.styleId,
    required this.styleName,
    required this.inputImageUrl,
    required this.outputImageUrl,
    required this.status,
    required this.creditsDeducted,
    required this.errorMessage,
    required this.createdAt,
    required this.completedAt,
  });

  bool get isProcessing => status == pending || status == running;
  bool get isSucceeded => status == succeeded;
  bool get isFinished => !isProcessing;

  factory AIGenerationItem.fromJson(JsonMap json) {
    return AIGenerationItem(
      taskId: _stringValue(json['taskId']),
      styleId: _stringValue(json['styleId']),
      styleName: _stringValue(json['styleName']),
      inputImageUrl: _stringValue(json['inputImageUrl']),
      outputImageUrl: _stringValue(json['outputImageUrl']),
      status: _intValue(json['status']),
      creditsDeducted: _intValue(json['creditsDeducted']),
      errorMessage: _stringValue(json['errorMessage']),
      createdAt: _intValue(json['createdAt']),
      completedAt: _intValue(json['completedAt']),
    );
  }
}

class AIGenerationCreateResult {
  final String taskId;
  final int status;
  final int creditsDeducted;
  final int remainingBalance;
  final bool duplicated;

  const AIGenerationCreateResult({
    required this.taskId,
    required this.status,
    required this.creditsDeducted,
    required this.remainingBalance,
    required this.duplicated,
  });

  factory AIGenerationCreateResult.fromJson(JsonMap json) {
    return AIGenerationCreateResult(
      taskId: _stringValue(json['taskId']),
      status: _intValue(json['status']),
      creditsDeducted: _intValue(json['creditsDeducted']),
      remainingBalance: _intValue(json['remainingBalance']),
      duplicated: _boolValue(json['duplicated']),
    );
  }
}

class GenerationCreateResult {
  final String generationId;
  final int creditsDeducted;
  final int remainingBalance;
  final int expiresAt;
  final bool duplicated;

  const GenerationCreateResult({
    required this.generationId,
    required this.creditsDeducted,
    required this.remainingBalance,
    required this.expiresAt,
    required this.duplicated,
  });

  factory GenerationCreateResult.fromJson(JsonMap json) {
    return GenerationCreateResult(
      generationId: _stringValue(json['generationId']),
      creditsDeducted: _intValue(json['creditsDeducted']),
      remainingBalance: _intValue(json['remainingBalance']),
      expiresAt: _intValue(json['expiresAt']),
      duplicated: _boolValue(json['duplicated']),
    );
  }
}

class GenerationCompleteResult {
  final String workId;
  final bool duplicated;

  const GenerationCompleteResult({
    required this.workId,
    required this.duplicated,
  });

  factory GenerationCompleteResult.fromJson(JsonMap json) {
    return GenerationCompleteResult(
      workId: _stringValue(json['workId']),
      duplicated: _boolValue(json['duplicated']),
    );
  }
}

class GenerationStatus {
  final int status;
  final int creditsDeducted;
  final String workId;

  const GenerationStatus({
    required this.status,
    required this.creditsDeducted,
    required this.workId,
  });

  factory GenerationStatus.fromJson(JsonMap json) {
    return GenerationStatus(
      status: _intValue(json['status']),
      creditsDeducted: _intValue(json['creditsDeducted']),
      workId: _stringValue(json['workId']),
    );
  }
}

class WorkItem {
  final String workId;
  final String title;
  final String originalImageUrl;
  final String patternImageUrl;
  final String boardSpec;
  final int width;
  final int height;
  final int beadCount;
  final int colorCount;
  final int status;
  final int createdAt;
  final String thumbnailUrl;
  final int updatedAt;
  final String sourceType;
  final String sourceId;

  const WorkItem({
    required this.workId,
    required this.title,
    required this.originalImageUrl,
    required this.patternImageUrl,
    required this.boardSpec,
    required this.width,
    required this.height,
    required this.beadCount,
    required this.colorCount,
    required this.status,
    required this.createdAt,
    required this.thumbnailUrl,
    required this.updatedAt,
    required this.sourceType,
    required this.sourceId,
  });

  factory WorkItem.fromJson(JsonMap json) {
    return WorkItem(
      workId: _stringValue(json['workId']),
      title: _stringValue(json['title']),
      originalImageUrl: _stringValue(json['originalImageUrl']),
      patternImageUrl: _stringValue(json['patternImageUrl']),
      boardSpec: _stringValue(json['boardSpec']),
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      beadCount: _intValue(json['beadCount']),
      colorCount: _intValue(json['colorCount']),
      status: _intValue(json['status']),
      createdAt: _intValue(json['createdAt']),
      thumbnailUrl: _stringValue(json['thumbnailUrl']),
      updatedAt: _intValue(json['updatedAt']),
      sourceType: _stringValue(json['sourceType']),
      sourceId: _stringValue(json['sourceId']),
    );
  }
}

class WorkDetail {
  final WorkItem work;
  final PatternData patternData;

  const WorkDetail({required this.work, required this.patternData});
}

class CreditBalance {
  final int balance;
  final int dailyFreeRemaining;
  final int dailyFreeTotal;

  const CreditBalance({
    required this.balance,
    required this.dailyFreeRemaining,
    required this.dailyFreeTotal,
  });

  factory CreditBalance.fromJson(JsonMap json) {
    return CreditBalance(
      balance: _intValue(json['balance']),
      dailyFreeRemaining: _intValue(json['dailyFreeRemaining']),
      dailyFreeTotal: _intValue(json['dailyFreeTotal']),
    );
  }
}

class BoardSpecItem {
  final String specId;
  final String name;
  final String shape;
  final int width;
  final int height;
  final String beadSize;

  const BoardSpecItem({
    required this.specId,
    required this.name,
    required this.shape,
    required this.width,
    required this.height,
    required this.beadSize,
  });

  factory BoardSpecItem.fromJson(JsonMap json) {
    return BoardSpecItem(
      specId: _stringValue(json['specId']),
      name: _stringValue(json['name']),
      shape: _stringValue(json['shape']),
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      beadSize: _stringValue(json['beadSize']),
    );
  }
}

class BeadColorItem {
  final String code;
  final String name;
  final String hex;

  const BeadColorItem({
    required this.code,
    required this.name,
    required this.hex,
  });

  factory BeadColorItem.fromJson(JsonMap json) {
    return BeadColorItem(
      code: _stringValue(json['code']),
      name: _stringValue(json['name']),
      hex: _stringValue(json['hex']),
    );
  }
}

class BeadColorBrand {
  final String brand;
  final String displayName;
  final List<BeadColorItem> colors;

  const BeadColorBrand({
    required this.brand,
    required this.displayName,
    required this.colors,
  });

  factory BeadColorBrand.fromJson(JsonMap json) {
    return BeadColorBrand(
      brand: _stringValue(json['brand']),
      displayName: _stringValue(json['displayName']),
      colors: _mapList(json['colors'], BeadColorItem.fromJson),
    );
  }
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _boolValue(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  if (value is num) return value != 0;
  return fallback;
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

JsonMap? _mapValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

List<T> _mapList<T>(Object? value, T Function(JsonMap json) decode) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => decode(item.cast<String, dynamic>()))
      .toList();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

List<int> _intList(Object? value) {
  if (value is! List) return const [];
  return value.map(_intValue).toList();
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, mapValue) => MapEntry(key.toString(), mapValue.toString()),
  );
}

int _rgbaKey(int r, int g, int b, int a) {
  return (r << 24) | (g << 16) | (b << 8) | a;
}

String _rgbHex(int r, int g, int b) {
  return '#${((1 << 24) + (r << 16) + (g << 8) + b).toRadixString(16).substring(1)}';
}

BeadColor _beadColorFromHex(String hex) {
  final normalized = hex.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
    throw ArgumentError.value(
      hex,
      'colorPalette.hex',
      'Palette colors must use #RRGGBB hex values.',
    );
  }

  return BeadColor.fromInt(
    int.parse(normalized.substring(0, 2), radix: 16),
    int.parse(normalized.substring(2, 4), radix: 16),
    int.parse(normalized.substring(4, 6), radix: 16),
    255,
  );
}
