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
    final tags = _parseTags(json['tags']);
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
}

/// A user-submitted pattern awaiting operator review.
///
/// Mirrors `GET /api/v1/admin/template-submissions`. Unlike the customer-facing
/// [TemplateSubmissionItem] this carries the submitter id and the reviewer
/// bookkeeping operators need in order to audit a decision.
class AdminSubmission {
  final String id;
  final String userId;
  final String workId;
  final String title;
  final String description;
  final AdminSubmissionStatus status;
  final String reviewReason;
  final String reviewerActor;
  final String templateId;
  final String boardSpec;
  final int width;
  final int height;
  final int beadCount;
  final int colorCount;
  final String previewUrl;
  final String thumbnailUrl;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const AdminSubmission({
    required this.id,
    required this.userId,
    required this.workId,
    required this.title,
    required this.description,
    required this.status,
    required this.reviewReason,
    required this.reviewerActor,
    required this.templateId,
    required this.boardSpec,
    required this.width,
    required this.height,
    required this.beadCount,
    required this.colorCount,
    required this.previewUrl,
    required this.thumbnailUrl,
    this.createdAt,
    this.reviewedAt,
  });

  /// The preview the operator can actually render, or an empty string when the
  /// submission arrived without one and the chart has to stand in for it.
  String get imageUrl {
    for (final value in [thumbnailUrl, previewUrl]) {
      if (value.startsWith('https://') ||
          value.startsWith('http://') ||
          value.startsWith('/')) {
        return value;
      }
    }
    return '';
  }

  factory AdminSubmission.fromJson(JsonMap json) {
    return AdminSubmission(
      id: json['submissionId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      workId: json['workId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: AdminSubmissionStatus.fromCode(
        (json['status'] as num?)?.toInt() ?? 0,
      ),
      reviewReason: json['reviewReason']?.toString() ?? '',
      reviewerActor: json['reviewerActor']?.toString() ?? '',
      templateId: json['templateId']?.toString() ?? '',
      boardSpec: json['boardSpec']?.toString() ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      beadCount: (json['beadCount'] as num?)?.toInt() ?? 0,
      colorCount: (json['colorCount'] as num?)?.toInt() ?? 0,
      previewUrl: _firstValue(json, const ['previewUrl', 'previewFileUrl']),
      thumbnailUrl: _firstValue(json, const [
        'thumbnailUrl',
        'thumbnailFileUrl',
      ]),
      createdAt: _timestamp(json['createdAt']),
      reviewedAt: _timestamp(json['reviewedAt']),
    );
  }
}

enum AdminSubmissionStatus {
  pending('pending', '待审核'),
  approved('approved', '已通过'),
  rejected('rejected', '已驳回');

  const AdminSubmissionStatus(this.wireName, this.label);

  /// Value accepted by the `status` query parameter.
  final String wireName;
  final String label;

  static AdminSubmissionStatus fromCode(int code) => switch (code) {
    1 => AdminSubmissionStatus.approved,
    2 => AdminSubmissionStatus.rejected,
    _ => AdminSubmissionStatus.pending,
  };
}

class AdminSubmissionDetail {
  final AdminSubmission submission;
  final PatternData patternData;

  const AdminSubmissionDetail({
    required this.submission,
    required this.patternData,
  });
}

class AdminSubmissionPage {
  final List<AdminSubmission> submissions;
  final int total;
  final bool hasMore;

  const AdminSubmissionPage({
    required this.submissions,
    required this.total,
    required this.hasMore,
  });
}

List<String> _parseTags(Object? raw) {
  if (raw is List) {
    return raw
        .map((value) => value.toString())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }
  return raw
          ?.toString()
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList() ??
      const <String>[];
}

String _firstValue(JsonMap json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// Admin timestamps are Unix **seconds**, and `0` means "never happened".
DateTime? _timestamp(Object? raw) {
  final seconds = (raw as num?)?.toInt() ?? 0;
  if (seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
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
      onUnauthorized: () async {
        // Admin sessions have no refresh endpoint. Let the caller surface the
        // error, but clear the in-memory session so the next build shows login.
        _accessToken = null;
        return false;
      },
      onResponse: (response) async {
        // `package:http` normalizes response header names to lowercase.
        // The header is intentionally absent until the current token is past
        // half of its idle timeout, so never clear the existing token here.
        final fresh = response.headers['x-admin-access-token'];
        if (fresh != null && fresh.isNotEmpty) {
          _accessToken = fresh;
        }
      },
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

  /// Uploads a preview image through the API origin and returns its `fileKey`.
  ///
  /// The portal deliberately uses the server-side proxy channel rather than the
  /// direct object-storage upload: the bucket CORS policy does not allow
  /// browser PUTs, and the proxy already performs the token/report handshake.
  Future<String> uploadPreviewImage({
    required Uint8List bytes,
    String? contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', '预览图内容不能为空');
    }
    final upload = await _client.postBytes(
      '/api/v1/admin/media/upload',
      bytes: bytes,
      contentType: contentType ?? _detectImageContentType(bytes),
    );
    final fileKey = upload['fileKey']?.toString() ?? '';
    if (fileKey.isEmpty) throw const FormatException('预览图上传响应缺少 fileKey');
    return fileKey;
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
    final fileKey = await uploadPreviewImage(
      bytes: thumbnailBytes,
      contentType: 'image/png',
    );

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
    final fileKey = await uploadPreviewImage(
      bytes: thumbnailBytes,
      contentType: 'image/png',
    );

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

  /// Loads one page of the review queue.
  ///
  /// Unlike [listTemplates] this does not walk every page: the approved and
  /// rejected archives keep growing, so the caller pages on demand instead.
  Future<AdminSubmissionPage> listSubmissions({
    AdminSubmissionStatus? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final data = await _client.get(
      '/api/v1/admin/template-submissions',
      query: {
        if (status != null) 'status': status.wireName,
        'page.page': page,
        'page.pageSize': pageSize,
      },
    );
    final values = data['submissions'];
    final submissions = values is List
        ? values
              .whereType<Map>()
              .map(
                (value) =>
                    AdminSubmission.fromJson(value.cast<String, dynamic>()),
              )
              .where((submission) => submission.id.isNotEmpty)
              .toList()
        : const <AdminSubmission>[];
    final pageInfo = data['page'];
    return AdminSubmissionPage(
      submissions: submissions,
      total: pageInfo is Map ? (pageInfo['total'] as num?)?.toInt() ?? 0 : 0,
      hasMore: pageInfo is Map && pageInfo['hasMore'] == true,
    );
  }

  Future<AdminSubmissionDetail> getSubmission(String submissionId) async {
    final data = await _client.get(
      '/api/v1/admin/template-submissions/${Uri.encodeComponent(submissionId)}',
    );
    final rawSubmission = data['submission'];
    final rawPatternData = data['patternData'];
    if (rawPatternData is! Map) {
      throw const FormatException('投稿详情响应缺少 patternData');
    }
    return AdminSubmissionDetail(
      submission: AdminSubmission.fromJson(
        rawSubmission is Map ? rawSubmission.cast<String, dynamic>() : data,
      ),
      patternData: PatternData.fromJson(rawPatternData.cast<String, dynamic>()),
    );
  }

  /// Approves a submission and returns the official template it produced.
  ///
  /// Empty optional fields are omitted rather than sent blank so the server
  /// keeps the submitter's own title, description and preview image.
  Future<String> approveSubmission({
    required String submissionId,
    required int categoryId,
    required int difficulty,
    String tags = '',
    String title = '',
    String description = '',
    String previewFileKey = '',
  }) async {
    final data = await _client.post(
      '/api/v1/admin/template-submissions/'
      '${Uri.encodeComponent(submissionId)}/approve',
      body: {
        'categoryId': categoryId,
        'difficulty': difficulty,
        if (tags.isNotEmpty) 'tags': tags,
        if (title.isNotEmpty) 'title': title,
        if (description.isNotEmpty) 'description': description,
        if (previewFileKey.isNotEmpty) 'previewFileKey': previewFileKey,
      },
    );
    final templateId = data['templateId']?.toString() ?? '';
    if (templateId.isEmpty) {
      throw const FormatException('审核通过响应缺少 templateId');
    }
    return templateId;
  }

  Future<void> rejectSubmission({
    required String submissionId,
    required String reason,
  }) {
    return _client.post(
      '/api/v1/admin/template-submissions/'
      '${Uri.encodeComponent(submissionId)}/reject',
      body: {'reason': reason},
    );
  }

  /// The proxy upload endpoint rejects anything outside jpeg/png/webp, so the
  /// type is sniffed from the magic bytes of the operator's chosen file.
  static String _detectImageContentType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    throw const FormatException('预览图仅支持 JPG、PNG 或 WebP 格式');
  }
}
