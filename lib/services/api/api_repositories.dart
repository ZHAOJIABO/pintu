import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_models.dart';
import 'api_session_store.dart';
import 'vendor_identifier.dart';

class AuthRepository {
  final ApiClient apiClient;

  const AuthRepository(this.apiClient);

  Future<AuthSession> guestLogin({
    required String guestCredential,
    DeviceInfo? deviceInfo,
  }) async {
    final data = await apiClient.post(
      '/api/v1/auth/guest',
      body: {
        'header': await apiClient.authenticationHeader(
          guestCredential: guestCredential,
          deviceInfo: deviceInfo,
        ),
      },
      includeAuth: false,
      includeDeviceId: false,
      retryUnauthorized: false,
    );
    return AuthSession.fromJson(data);
  }

  Future<AuthSession> phoneLogin({
    required String phone,
    required String code,
  }) async {
    final data = await apiClient.post(
      '/api/v1/auth/phone',
      body: {
        'header': await apiClient.authenticationHeader(),
        'phone': phone,
        'code': code,
      },
      includeAuth: false,
      retryUnauthorized: false,
    );
    return AuthSession.fromJson(data);
  }

  Future<AuthSession> refresh(
    String refreshToken, {
    ApiUser? fallbackUser,
    DeviceInfo? deviceInfo,
  }) async {
    final data = await apiClient.post(
      '/api/v1/auth/refresh',
      body: {
        'header': await apiClient.authenticationHeader(deviceInfo: deviceInfo),
        'refreshToken': refreshToken,
      },
      includeAuth: false,
      retryUnauthorized: false,
    );
    return AuthSession.fromJson(
      data,
      fallbackUser: fallbackUser,
      fallbackRefreshToken: refreshToken,
    );
  }
}

class AuthSessionController {
  final ApiSessionStore store;
  final AuthRepository repository;
  Future<void>? _signInInFlight;
  Future<bool>? _refreshInFlight;

  AuthSessionController({required this.store, required this.repository});

  Future<void> ensureSignedIn() {
    return _signInInFlight ??= _ensureSignedIn().whenComplete(() {
      _signInInFlight = null;
    });
  }

  Future<void> _ensureSignedIn() async {
    final session = await store.readSession();
    if (session?.hasValidAccessToken() == true) return;
    if (await refreshOrGuestLogin()) return;
    throw StateError('Unable to initialize an authenticated session.');
  }

  Future<bool> refreshOrGuestLogin() {
    return _refreshInFlight ??= _refreshOrGuestLogin().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _refreshOrGuestLogin() async {
    final current = await store.readSession();
    if (current?.refreshToken.isNotEmpty == true) {
      try {
        final refreshed = await repository.refresh(
          current!.refreshToken,
          fallbackUser: current.user,
          deviceInfo: await store.readDeviceInfo(),
        );
        await store.saveSession(refreshed);
        return true;
      } catch (_) {
        await store.clearSession();
      }
    }

    try {
      final guest = await repository.guestLogin(
        guestCredential: await store.readOrCreateGuestCredential(),
        deviceInfo: await store.readDeviceInfo(),
      );
      await store.saveSession(guest);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class TemplateRepository {
  final ApiClient apiClient;
  final AuthSessionController auth;

  const TemplateRepository({required this.apiClient, required this.auth});

  Future<List<TemplateCategory>> listCategories() async {
    await auth.ensureSignedIn();
    final data = await apiClient.get('/api/v1/templates/categories');
    return _mapList(data['categories'], TemplateCategory.fromJson);
  }

  /// Lists categories that contain at least one current-user favorite.
  Future<List<TemplateCategory>> listFavoriteCategories() async {
    await auth.ensureSignedIn();
    final data = await apiClient.get('/api/v1/templates/favorites/categories');
    return _mapList(data['categories'], TemplateCategory.fromJson);
  }

  Future<PagedResult<TemplateItem>> listTemplates({
    String? scene,
    int? categoryId,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    await auth.ensureSignedIn();
    final query = <String, Object?>{
      if (scene != null && scene.isNotEmpty) 'scene': scene,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      'page.page': page,
      'page.pageSize': pageSize,
    };
    if (categoryId != null) {
      query['categoryId'] = categoryId;
    }
    final data = await apiClient.get('/api/v1/templates', query: query);
    return PagedResult(
      items: _mapList(data['templates'], TemplateItem.fromJson),
      page: PageResponse.fromJson(_map(data['page'])),
    );
  }

  Future<TemplateDetail> getTemplate(String templateId) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/templates/${Uri.encodeComponent(templateId)}',
    );
    return TemplateDetail(
      template: TemplateItem.fromJson(_map(data['template']) ?? const {}),
      patternData: PatternData.fromJson(_map(data['patternData']) ?? const {}),
    );
  }

  /// Draws one published template for the home blind box.
  Future<TemplateDetail> getRandomTemplate() async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/templates/random',
      body: const {'header': <String, Object?>{}},
    );
    return TemplateDetail(
      template: TemplateItem.fromJson(_map(data['template']) ?? const {}),
      patternData: PatternData.fromJson(_map(data['patternData']) ?? const {}),
    );
  }

  Future<TemplateFavoriteResult> favorite(String templateId) async {
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/templates/${Uri.encodeComponent(templateId)}/favorite',
      body: const <String, Object?>{},
    );
    return TemplateFavoriteResult.fromJson(data);
  }

  Future<TemplateFavoriteResult> unfavorite(String templateId) async {
    await auth.ensureSignedIn();
    final data = await apiClient.delete(
      '/api/v1/templates/${Uri.encodeComponent(templateId)}/favorite',
    );
    return TemplateFavoriteResult.fromJson(data);
  }

  Future<PagedResult<TemplateItem>> listFavorites({
    int? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/templates/favorites',
      query: {
        if (categoryId != null && categoryId > 0) 'categoryId': categoryId,
        'page.page': page,
        'page.pageSize': pageSize,
      },
    );
    return PagedResult(
      items: _mapList(data['templates'], TemplateItem.fromJson),
      page: PageResponse.fromJson(_map(data['page'])),
    );
  }

  /// Lists the current user's blind-box opening history, newest first.
  Future<PagedResult<TemplateItem>> listRandomHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/templates/random/history',
      query: {'page.page': page, 'page.pageSize': pageSize},
    );
    return PagedResult(
      items: _mapList(data['templates'], TemplateItem.fromJson),
      page: PageResponse.fromJson(_map(data['page'])),
    );
  }
}

class MediaRepository {
  final ApiClient apiClient;
  final AuthSessionController auth;

  const MediaRepository({required this.apiClient, required this.auth});

  Future<UploadToken> createUploadToken({
    required String fileName,
    required String contentType,
    required String purpose,
    String? clientRequestId,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/media/upload-token',
      body: {
        'file_name': fileName,
        'content_type': contentType,
        'purpose': purpose,
        if (clientRequestId != null && clientRequestId.isNotEmpty)
          'client_request_id': clientRequestId,
      },
    );
    return UploadToken.fromJson(data);
  }

  Future<void> uploadToObjectStorage({
    required UploadToken token,
    required Uint8List bytes,
  }) {
    return apiClient.putBytes(
      token.uploadUrl,
      bytes: bytes,
      headers: token.headers,
    );
  }

  Future<UploadedMedia> reportUpload({
    required String fileKey,
    required int fileSize,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/media/report-upload',
      body: {'file_key': fileKey, 'file_size': fileSize},
    );
    return UploadedMedia(
      fileKey: fileKey,
      fileUrl: data['fileUrl']?.toString() ?? '',
    );
  }

  Future<UploadedMedia> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String purpose,
    String? clientRequestId,
  }) async {
    final token = await createUploadToken(
      fileName: fileName,
      contentType: contentType,
      purpose: purpose,
      clientRequestId: clientRequestId,
    );
    await uploadToObjectStorage(token: token, bytes: bytes);
    return reportUpload(fileKey: token.fileKey, fileSize: bytes.length);
  }

  Future<Uint8List> downloadBytes(String url) {
    return apiClient.getBytes(url);
  }
}

class FinishedProductRepository {
  static const _endpoint = '/api/v1/finished-products';

  final ApiClient apiClient;
  final AuthSessionController auth;
  final MediaRepository media;

  const FinishedProductRepository({
    required this.apiClient,
    required this.auth,
    required this.media,
  });

  Future<FinishedProductPage> listFinishedProducts({
    String? cursor,
    int limit = 12,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      _endpoint,
      query: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return FinishedProductPage(
      items: _mapList(data['items'], FinishedProductItem.fromJson),
      nextCursor: _nullableString(data['nextCursor']),
    );
  }

  Future<FinishedProductItem> uploadAndCreate({
    required Uint8List bytes,
    required String clientRequestId,
  }) async {
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final token = await media.createUploadToken(
      fileName: isPng ? 'finished-product.png' : 'finished-product.jpg',
      contentType: isPng ? 'image/png' : 'image/jpeg',
      purpose: 'finished_product',
      clientRequestId: clientRequestId,
    );
    if (token.maxFileSize > 0 && bytes.length > token.maxFileSize) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'The finished-product export exceeds the upload limit.',
      );
    }
    await media.uploadToObjectStorage(token: token, bytes: bytes);
    final uploaded = await media.reportUpload(
      fileKey: token.fileKey,
      fileSize: bytes.length,
    );
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      _endpoint,
      body: {
        'media_file_key': uploaded.fileKey,
        'client_request_id': clientRequestId,
      },
    );
    final itemJson = _map(data['item']);
    if (itemJson == null) {
      throw const FormatException('Finished-product response is missing item.');
    }
    final item = FinishedProductItem.fromJson(itemJson);
    if (item.finishedProductId.isEmpty || item.displayUrl.isEmpty) {
      throw const FormatException(
        'Finished-product response is missing required fields.',
      );
    }
    return item;
  }
}

class AIGenerationRepository {
  final ApiClient apiClient;
  final AuthSessionController auth;

  const AIGenerationRepository({required this.apiClient, required this.auth});

  Future<List<AIStyleItem>> listStyles() async {
    await auth.ensureSignedIn();
    final data = await apiClient.get('/api/v1/ai/styles');
    return _mapList(data['styles'], AIStyleItem.fromJson);
  }

  Future<AIGenerationCreateResult> createStyleGeneration({
    required String styleId,
    required String inputFileKey,
    required String clientRequestId,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/ai/style-generations',
      body: {
        'style_id': styleId,
        'input_file_key': inputFileKey,
        'client_request_id': clientRequestId,
      },
    );
    return AIGenerationCreateResult.fromJson(data);
  }

  /// Starts a new attempt from a failed or expired style-generation task.
  ///
  /// [taskId] identifies the original task. The returned task ID belongs to
  /// the new attempt and must be used for all subsequent polling.
  Future<AIGenerationCreateResult> retryStyleGeneration(
    String taskId, {
    required String clientRequestId,
  }) async {
    if (taskId.isEmpty) {
      throw ArgumentError.value(taskId, 'taskId', 'must not be empty');
    }
    if (clientRequestId.isEmpty) {
      throw ArgumentError.value(
        clientRequestId,
        'clientRequestId',
        'must not be empty',
      );
    }
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/ai/style-generations/${Uri.encodeComponent(taskId)}/retry',
      body: {'clientRequestId': clientRequestId},
    );
    return AIGenerationCreateResult.fromJson(data);
  }

  Future<AIGenerationItem> getStyleGeneration(String taskId) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/ai/style-generations/${Uri.encodeComponent(taskId)}',
    );
    return AIGenerationItem.fromJson(_map(data['task']) ?? const {});
  }

  Future<PagedResult<AIGenerationItem>> listStyleGenerations({
    int page = 1,
    int pageSize = 20,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/ai/style-generations',
      query: {'page.page': page, 'page.pageSize': pageSize},
    );
    return PagedResult(
      items: _mapList(data['tasks'], AIGenerationItem.fromJson),
      page: PageResponse.fromJson(_map(data['page'])),
    );
  }

  /// Fetches every style-generation task belonging to the signed-in user.
  ///
  /// The response contains every task status, and pagination must be driven by
  /// `page.hasMore` rather than the item count.
  Future<List<AIGenerationItem>> listAllStyleGenerations({
    int pageSize = 50,
  }) async {
    final items = <AIGenerationItem>[];
    var page = 1;
    while (true) {
      final result = await listStyleGenerations(page: page, pageSize: pageSize);
      items.addAll(result.items);
      if (!result.page.hasMore) return items;
      page++;
    }
  }

  Future<AIGenerationItem> waitForStyleGeneration(
    String taskId, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final started = DateTime.now();
    var attempt = 0;
    while (DateTime.now().difference(started) < timeout) {
      final task = await getStyleGeneration(taskId);
      if (task.isFinished) return task;
      attempt++;
      final delay = attempt <= 3
          ? const Duration(seconds: 1)
          : (attempt <= 15
                ? const Duration(seconds: 2)
                : const Duration(seconds: 3));
      await Future<void>.delayed(delay);
    }
    throw StyleGenerationStillRunningException(taskId);
  }
}

class GenerationRepository {
  final ApiClient apiClient;
  final AuthSessionController auth;

  const GenerationRepository({required this.apiClient, required this.auth});

  Future<GenerationCreateResult> createGeneration({
    required String boardSpec,
    required String sourceType,
    required String sourceId,
    required String clientRequestId,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/generation/create',
      body: {
        'boardSpec': boardSpec,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'clientRequestId': clientRequestId,
      },
    );
    return GenerationCreateResult.fromJson(data);
  }

  Future<GenerationCompleteResult> completeGeneration({
    required String generationId,
    required String title,
    required String originalImageUrl,
    required String patternImageUrl,
    String thumbnailUrl = '',
    required PatternData patternData,
    required int beadCount,
    required int colorCount,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/generation/${Uri.encodeComponent(generationId)}/complete',
      body: {
        'title': title,
        'originalImageUrl': originalImageUrl,
        'patternImageUrl': patternImageUrl,
        'thumbnailUrl': thumbnailUrl,
        'patternData': patternData.toJson(),
        'beadCount': beadCount,
        'colorCount': colorCount,
      },
    );
    return GenerationCompleteResult.fromJson(data);
  }

  Future<void> cancelGeneration({
    required String generationId,
    String reason = 'user_cancelled',
  }) async {
    await auth.ensureSignedIn();
    await apiClient.post(
      '/api/v1/generation/${Uri.encodeComponent(generationId)}/cancel',
      body: {'reason': reason},
    );
  }

  Future<GenerationStatus> getGeneration(String generationId) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/generation/${Uri.encodeComponent(generationId)}',
    );
    return GenerationStatus.fromJson(data);
  }
}

class WorkRepository {
  final ApiClient apiClient;
  final AuthSessionController auth;

  const WorkRepository({required this.apiClient, required this.auth});

  Future<PagedResult<WorkItem>> listWorks({
    String? sourceType,
    int page = 1,
    int pageSize = 20,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/works',
      query: {
        if (sourceType != null && sourceType.isNotEmpty)
          'sourceType': sourceType,
        'page.page': page,
        'page.pageSize': pageSize,
      },
    );
    if (kDebugMode) {
      debugPrintSynchronously(
        '[API] GET /api/v1/works response: ${jsonEncode(data)}',
      );
    }
    final payload = _map(data['data']) ?? data;
    return PagedResult(
      items: _mapList(payload['works'], WorkItem.fromJson),
      page: PageResponse.fromJson(_map(payload['page'])),
    );
  }

  Future<WorkDetail> getWork(String workId) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/works/${Uri.encodeComponent(workId)}',
    );
    return WorkDetail(
      work: WorkItem.fromJson(_map(data['work']) ?? const {}),
      patternData: PatternData.fromJson(_map(data['patternData']) ?? const {}),
    );
  }

  /// Persists edits made to an existing user work.
  ///
  /// The server owns the derived counts and thumbnail metadata. The editor
  /// submits both the updated [PatternData] source of truth and its newly
  /// rendered, uploaded chart image.
  Future<void> updateWork({
    required String workId,
    required PatternData patternData,
    required String patternImageUrl,
    required String thumbnailUrl,
  }) async {
    await auth.ensureSignedIn();
    await apiClient.put(
      '/api/v1/works/${Uri.encodeComponent(workId)}',
      body: {
        'patternImageUrl': patternImageUrl,
        'thumbnailUrl': thumbnailUrl,
        'patternData': patternData.toJson(),
      },
    );
  }

  /// Deletes a user work.
  ///
  /// [workId] comes from the works list and must be kept intact when it is
  /// appended to the API path.
  Future<void> deleteWork(String workId) async {
    await auth.ensureSignedIn();
    await apiClient.delete('/api/v1/works/$workId');
  }

  Future<String> saveWork({
    required String title,
    required String originalImageUrl,
    required String patternImageUrl,
    required PatternData patternData,
    required int beadCount,
    required int colorCount,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/works',
      body: {
        'title': title,
        'originalImageUrl': originalImageUrl,
        'patternImageUrl': patternImageUrl,
        'patternData': patternData.toJson(),
        'beadCount': beadCount,
        'colorCount': colorCount,
      },
    );
    return data['workId']?.toString() ?? '';
  }
}

class TemplateSubmissionRepository {
  final ApiClient apiClient;
  final AuthSessionController auth;

  const TemplateSubmissionRepository({
    required this.apiClient,
    required this.auth,
  });

  Future<TemplateSubmissionItem> submit({
    required String workId,
    required String title,
    required String description,
    required String clientRequestId,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/template-submissions',
      body: {
        'workId': workId,
        'title': title,
        'description': description,
        'clientRequestId': clientRequestId,
      },
    );
    final payload = _map(data['data']) ?? data;
    return TemplateSubmissionItem.fromJson(_map(payload['item']) ?? const {});
  }

  Future<TemplateSubmissionPage> list({int limit = 20, String? cursor}) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/template-submissions',
      query: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final payload = _map(data['data']) ?? data;
    return TemplateSubmissionPage(
      items: _mapList(payload['items'], TemplateSubmissionItem.fromJson),
      nextCursor: payload['nextCursor']?.toString() ?? '',
    );
  }
}

class CreditRepository {
  final ApiClient apiClient;
  final AuthSessionController auth;

  const CreditRepository({required this.apiClient, required this.auth});

  Future<CreditBalance> getBalance() async {
    await auth.ensureSignedIn();
    final data = await apiClient.get('/api/v1/credits/balance');
    return CreditBalance.fromJson(data);
  }
}

class SystemRepository {
  final ApiClient apiClient;

  const SystemRepository(this.apiClient);

  Future<JsonMap> getConfig() {
    return apiClient.get('/api/v1/system/config', includeAuth: false);
  }

  Future<List<BoardSpecItem>> listBoardSpecs() async {
    final data = await apiClient.get(
      '/api/v1/system/board-specs',
      includeAuth: false,
    );
    return _mapList(data['specs'], BoardSpecItem.fromJson);
  }

  Future<List<BeadColorBrand>> listBeadColors({String? brand}) async {
    final data = await apiClient.get(
      '/api/v1/system/bead-colors',
      query: {if (brand != null && brand.isNotEmpty) 'brand': brand},
      includeAuth: false,
    );
    return _mapList(data['brands'], BeadColorBrand.fromJson);
  }
}

JsonMap? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String? _nullableString(Object? value) {
  final result = value?.toString();
  return result == null || result.isEmpty ? null : result;
}

List<T> _mapList<T>(Object? value, T Function(JsonMap json) decode) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => decode(item.cast<String, dynamic>()))
      .toList();
}
