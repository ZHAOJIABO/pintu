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

  Future<String> publishTemplate({
    required String idempotencyKey,
    required String title,
    required String description,
    required int categoryId,
    required String tags,
    required int difficulty,
    required PatternData patternData,
    required Uint8List previewBytes,
  }) async {
    if (previewBytes.isEmpty) {
      throw ArgumentError.value(previewBytes, 'previewBytes', '预览图不能为空');
    }
    final upload = await _client.postBytes(
      '/api/v1/admin/media/upload',
      bytes: previewBytes,
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
