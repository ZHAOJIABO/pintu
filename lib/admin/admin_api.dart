import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../services/api/api_client.dart';
import '../services/api/api_models.dart';

class AdminCategory {
  final int id;
  final String name;
  final int templateCount;

  const AdminCategory({
    required this.id,
    required this.name,
    required this.templateCount,
  });

  factory AdminCategory.fromJson(JsonMap json) => AdminCategory(
    id: (json['categoryId'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    templateCount: (json['templateCount'] as num?)?.toInt() ?? 0,
  );
}

/// A published template as returned by the internal admin listing endpoint.
///
/// This intentionally stays separate from the customer-facing [TemplateItem]:
/// operators need the category id in order to group and manage templates.
class AdminTemplate {
  final String id;
  final String title;
  final int categoryId;
  final String categoryName;
  final String previewUrl;
  final String thumbnailUrl;
  final String previewFileKey;
  final String description;
  final List<String> tags;
  final int difficulty;
  final int width;
  final int height;
  final int colorCount;
  final PatternData? patternData;

  const AdminTemplate({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.previewUrl,
    required this.thumbnailUrl,
    this.previewFileKey = '',
    required this.description,
    required this.tags,
    required this.difficulty,
    required this.width,
    required this.height,
    required this.colorCount,
    this.patternData,
  });

  String get imageUrl {
    for (final value in [thumbnailUrl, previewUrl, previewFileKey]) {
      if (value.startsWith('https://') ||
          value.startsWith('http://') ||
          value.startsWith('/')) {
        return value;
      }
    }
    return '';
  }

  factory AdminTemplate.fromJson(JsonMap json) {
    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags
              .map((value) => value.toString())
              .where((tag) => tag.isNotEmpty)
              .toList()
        : rawTags
                  ?.toString()
                  .split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .toList() ??
              const <String>[];
    return AdminTemplate(
      id: json['templateId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      categoryName: json['categoryName']?.toString() ?? '',
      previewUrl: _firstValue(json, const [
        'previewUrl',
        'previewFileUrl',
        'patternImageUrl',
        'imageUrl',
      ]),
      thumbnailUrl: _firstValue(json, const [
        'thumbnailUrl',
        'thumbnailFileUrl',
      ]),
      previewFileKey: json['previewFileKey']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      tags: tags,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      colorCount: (json['colorCount'] as num?)?.toInt() ?? 0,
      patternData: json['patternData'] is Map
          ? PatternData.fromJson(
              (json['patternData'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  static String _firstValue(JsonMap json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

class AdminTemplateDetail {
  final AdminTemplate template;
  final PatternData patternData;

  const AdminTemplateDetail({
    required this.template,
    required this.patternData,
  });
}

class AdminApi {
  String? _accessToken;
  late final ApiClient _client;

  AdminApi({
    String baseUrl = ApiClient.defaultBaseUrl,
    http.Client? httpClient,
  }) {
    _client = ApiClient(
      baseUrl: baseUrl,
      httpClient: httpClient,
      platform: 'web',
      tokenProvider: () async => _accessToken,
      deviceIdProvider: () async => 'admin-web',
    );
  }

  bool get isAuthenticated => _accessToken?.isNotEmpty == true;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final data = await _client.post(
      '/api/v1/admin/login',
      body: {'username': username, 'password': password},
      includeAuth: false,
      retryUnauthorized: false,
    );
    final token = data['accessToken']?.toString() ?? '';
    if (token.isEmpty) {
      throw const FormatException('管理员登录响应缺少 accessToken');
    }
    _accessToken = token;
  }

  void logout() => _accessToken = null;

  Future<List<AdminCategory>> listCategories() async {
    final data = await _client.get('/api/v1/admin/template-categories');
    final values = data['categories'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => AdminCategory.fromJson(value.cast<String, dynamic>()))
        .where((category) => category.id > 0 && category.name.isNotEmpty)
        .toList();
  }

  Future<AdminCategory> createCategory({required String name}) async {
    final data = await _client.post(
      '/api/v1/admin/template-categories',
      body: {'name': name},
    );
    final rawCategory = data['category'];
    final category = AdminCategory.fromJson(
      rawCategory is Map ? rawCategory.cast<String, dynamic>() : data,
    );
    if (category.id <= 0 || category.name.isEmpty) {
      throw const FormatException('创建分类响应缺少分类信息');
    }
    return category;
  }

  /// Loads every published template for the library page.
  ///
  /// API contract: `GET /api/v1/admin/templates?page.page=1&page.pageSize=100`
  /// returns `templates` and the normal `{page: {hasMore: bool}}` envelope.
  Future<List<AdminTemplate>> listTemplates() async {
    const pageSize = 100;
    final templates = <AdminTemplate>[];
    var page = 1;
    var hasMore = true;

    while (hasMore) {
      final data = await _client.get(
        '/api/v1/admin/templates',
        query: {'page.page': page, 'page.pageSize': pageSize},
      );
      final values = data['templates'];
      if (values is List) {
        templates.addAll(
          values
              .whereType<Map>()
              .map(
                (value) =>
                    AdminTemplate.fromJson(value.cast<String, dynamic>()),
              )
              .where((template) => template.id.isNotEmpty),
        );
      }
      final pageInfo = data['page'];
      hasMore = pageInfo is Map && pageInfo['hasMore'] == true;
      page += 1;
    }
    return templates;
  }

  Future<AdminTemplateDetail> getTemplate(String templateId) async {
    final data = await _client.get(
      '/api/v1/admin/templates/${Uri.encodeComponent(templateId)}',
    );
    final rawTemplate = data['template'];
    final rawPatternData = data['patternData'];
    if (rawPatternData is! Map) {
      throw const FormatException('模板详情响应缺少 patternData');
    }
    return AdminTemplateDetail(
      template: AdminTemplate.fromJson(
        rawTemplate is Map ? rawTemplate.cast<String, dynamic>() : data,
      ),
      patternData: PatternData.fromJson(rawPatternData.cast<String, dynamic>()),
    );
  }

  Future<String> publishTemplate({
    required String idempotencyKey,
    required String title,
    required String description,
    required int categoryId,
    required String tags,
    required int difficulty,
    required PatternData patternData,
    required Uint8List thumbnailBytes,
  }) async {
    if (thumbnailBytes.isEmpty) {
      throw ArgumentError.value(thumbnailBytes, 'thumbnailBytes', '图库缩略图不能为空');
    }
    final upload = await _client.postBytes(
      '/api/v1/admin/media/upload',
      bytes: thumbnailBytes,
      contentType: 'image/png',
    );
    final fileKey = upload['fileKey']?.toString() ?? '';
    if (fileKey.isEmpty) throw const FormatException('预览图上传响应缺少 fileKey');

    final data = await _client.post(
      '/api/v1/admin/templates',
      body: {
        'idempotencyKey': idempotencyKey,
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'tags': tags,
        'difficulty': difficulty,
        'previewFileKey': fileKey,
        'patternData': patternData.toJson(),
      },
    );
    final templateId = data['templateId']?.toString() ?? '';
    if (templateId.isEmpty) {
      throw const FormatException('发布响应缺少 templateId');
    }
    return templateId;
  }

  Future<void> updateTemplate({
    required String templateId,
    required String title,
    required String description,
    required int categoryId,
    required String tags,
    required int difficulty,
    required PatternData patternData,
    required Uint8List thumbnailBytes,
  }) async {
    if (thumbnailBytes.isEmpty) {
      throw ArgumentError.value(thumbnailBytes, 'thumbnailBytes', '图库缩略图不能为空');
    }
    final upload = await _client.postBytes(
      '/api/v1/admin/media/upload',
      bytes: thumbnailBytes,
      contentType: 'image/png',
    );
    final fileKey = upload['fileKey']?.toString() ?? '';
    if (fileKey.isEmpty) throw const FormatException('预览图上传响应缺少 fileKey');

    await _client.put(
      '/api/v1/admin/templates/${Uri.encodeComponent(templateId)}',
      body: {
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'tags': tags,
        'difficulty': difficulty,
        'previewFileKey': fileKey,
        'patternData': patternData.toJson(),
      },
    );
  }

  Future<void> unpublishTemplate({
    required String templateId,
    String reason = '',
  }) {
    return _client.post(
      '/api/v1/admin/templates/${Uri.encodeComponent(templateId)}/unpublish',
      body: {'reason': reason},
    );
  }
}
