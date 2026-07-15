import 'dart:async';
import 'dart:typed_data';

import 'api_client.dart';
import 'api_models.dart';
import 'api_session_store.dart';

class AuthRepository {
  final ApiClient apiClient;

  const AuthRepository(this.apiClient);

  Future<AuthSession> guestLogin(String deviceId) async {
    final data = await apiClient.post(
      '/api/v1/auth/guest',
      body: {'deviceId': deviceId},
      includeAuth: false,
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
      body: {'phone': phone, 'code': code},
      includeAuth: false,
      retryUnauthorized: false,
    );
    return AuthSession.fromJson(data);
  }

  Future<AuthSession> refresh(
    String refreshToken, {
    ApiUser? fallbackUser,
  }) async {
    final data = await apiClient.post(
      '/api/v1/auth/refresh',
      body: {'refreshToken': refreshToken},
      includeAuth: false,
      retryUnauthorized: false,
    );
    return AuthSession.fromJson(data, fallbackUser: fallbackUser);
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
    if (session?.accessToken.isNotEmpty == true) return;
    final deviceId = await store.readOrCreateDeviceId();
    final next = await repository.guestLogin(deviceId);
    await store.saveSession(next);
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
        );
        await store.saveSession(refreshed);
        return true;
      } catch (_) {
        await store.clearSession();
      }
    }

    try {
      final deviceId = await store.readOrCreateDeviceId();
      final guest = await repository.guestLogin(deviceId);
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
    int page = 1,
    int pageSize = 20,
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.get(
      '/api/v1/templates/favorites',
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
  }) async {
    await auth.ensureSignedIn();
    final data = await apiClient.post(
      '/api/v1/media/upload-token',
      body: {
        'fileName': fileName,
        'contentType': contentType,
        'purpose': purpose,
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
      body: {'fileKey': fileKey, 'fileSize': fileSize},
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
  }) async {
    final token = await createUploadToken(
      fileName: fileName,
      contentType: contentType,
      purpose: purpose,
    );
    await uploadToObjectStorage(token: token, bytes: bytes);
    return reportUpload(fileKey: token.fileKey, fileSize: bytes.length);
  }

  Future<Uint8List> downloadBytes(String url) {
    return apiClient.getBytes(url);
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
        'styleId': styleId,
        'inputFileKey': inputFileKey,
        'clientRequestId': clientRequestId,
      },
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

  Future<AIGenerationItem> waitForStyleGeneration(
    String taskId, {
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final task = await getStyleGeneration(taskId);
      if (!task.isProcessing) return task;
      await Future<void>.delayed(interval);
    }
    throw const ApiException(2002, 'AI 风格转换超时');
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
    return PagedResult(
      items: _mapList(data['works'], WorkItem.fromJson),
      page: PageResponse.fromJson(_map(data['page'])),
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

List<T> _mapList<T>(Object? value, T Function(JsonMap json) decode) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => decode(item.cast<String, dynamic>()))
      .toList();
}
