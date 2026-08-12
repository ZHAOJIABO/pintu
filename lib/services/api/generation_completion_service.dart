import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/generated_pattern.dart';
import '../pattern_image_upload_service.dart';
import 'api_models.dart';
import 'api_repositories.dart';
import 'api_session_store.dart';

typedef GenerationDiagnosticLogger = void Function(Map<String, Object?> event);

class GenerationCompletionService {
  final MediaRepository media;
  final GenerationRepository generations;
  final ApiSessionStore store;
  final PatternImageUploadService patternImageUploader;
  final GenerationDiagnosticLogger? diagnosticLogger;

  const GenerationCompletionService({
    required this.media,
    required this.generations,
    required this.store,
    this.patternImageUploader = const PatternImageUploadService(),
    this.diagnosticLogger,
  });

  /// Starts an independent generation attempt and records the user click.
  Future<String> startNewAttempt() async {
    await store.clearPendingGenerationAttempt();
    final clientRequestId = await store
        .readOrCreatePendingGenerationClientRequestId();
    _log(event: 'click', clientRequestId: clientRequestId, isRetry: false);
    return clientRequestId;
  }

  Future<GenerationCompleteResult> completeGeneratedPattern(
    GeneratedPattern pattern, {
    String sourceType = 'photo',
    String sourceId = '',
    String? title,
    String? originalImageUrl,
  }) async {
    final clientRequestId = await store
        .readOrCreatePendingGenerationClientRequestId();
    String? generationId;

    try {
      final boardSpec = '${pattern.width}x${pattern.height}';
      final patternData = PatternData.fromGeneratedPattern(
        pattern,
        boardSpec: boardSpec,
      );
      final beadCount = patternData.pixels.where((pixel) => pixel != 0).length;
      final colorCount = patternData.pixels
          .where((pixel) => pixel != 0)
          .toSet()
          .length;
      generationId = await _resolveGenerationId(
        boardSpec: boardSpec,
        sourceType: sourceType,
        sourceId: sourceId,
        clientRequestId: clientRequestId,
      );
      final sourceUrl =
          originalImageUrl ??
          await _uploadOriginalImage(pattern.draft.imageForGeneration);
      final uploadedPatternImages = await patternImageUploader
          .uploadEditedPattern(media: media, pattern: pattern);
      final result = await generations.completeGeneration(
        generationId: generationId,
        title: title ?? _defaultTitle(),
        originalImageUrl: sourceUrl,
        patternImageUrl: uploadedPatternImages.patternImageUrl,
        thumbnailUrl: uploadedPatternImages.thumbnailUrl,
        patternData: patternData,
        beadCount: beadCount,
        colorCount: colorCount,
      );
      _log(
        event: 'complete_response',
        clientRequestId: clientRequestId,
        headerCode: result.headerCode,
        duplicated: result.duplicated,
        generationId: generationId,
        traceId: result.traceId,
      );
      await store.clearPendingGenerationAttempt();
      return result;
    } on ApiException catch (error) {
      _log(
        event: 'failed',
        clientRequestId: clientRequestId,
        headerCode: error.code,
        generationId: generationId,
        traceId: error.traceId,
      );
      rethrow;
    } catch (error) {
      _log(
        event: 'failed',
        clientRequestId: clientRequestId,
        generationId: generationId,
        error: error.runtimeType.toString(),
      );
      rethrow;
    }
  }

  Future<String> _resolveGenerationId({
    required String boardSpec,
    required String sourceType,
    required String sourceId,
    required String clientRequestId,
  }) async {
    final pending = await store.readPendingGenerationId();
    if (pending != null && pending.isNotEmpty) return pending;

    final created = await generations.createGeneration(
      boardSpec: boardSpec,
      sourceType: sourceType,
      sourceId: sourceId,
      clientRequestId: clientRequestId,
    );
    _log(
      event: 'create_response',
      clientRequestId: clientRequestId,
      headerCode: created.headerCode,
      duplicated: created.duplicated,
      generationId: created.generationId,
      traceId: created.traceId,
    );
    if (created.generationId.isEmpty) {
      throw const FormatException('生成凭证响应缺少 generationId');
    }
    await store.savePendingGenerationId(created.generationId);
    return created.generationId;
  }

  void _log({
    required String event,
    required String clientRequestId,
    int? headerCode,
    bool? duplicated,
    String? generationId,
    String? traceId,
    bool? isRetry,
    String? error,
  }) {
    final fields = <String, Object?>{
      'event': event,
      'clientRequestId': clientRequestId,
      'header.code': headerCode,
      'duplicated': duplicated,
      'generationId': generationId,
      'traceId': traceId,
      'isRetry': ?isRetry,
      'error': ?error,
    };
    final logger = diagnosticLogger;
    if (logger != null) {
      logger(fields);
      return;
    }
    debugPrint('[GenerationDiagnostic] ${jsonEncode(fields)}');
  }

  Future<String> _uploadOriginalImage(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw StateError('生成图纸缺少原图');
    }
    final uploaded = await media.uploadBytes(
      bytes: bytes,
      fileName: 'generation-source.png',
      contentType: 'image/png',
      purpose: 'original',
    );
    return _requiredUrl(uploaded, '原图');
  }

  String _requiredUrl(UploadedMedia media, String label) {
    if (media.fileUrl.isEmpty) {
      throw StateError('$label上传响应缺少 fileUrl');
    }
    return media.fileUrl;
  }

  String _defaultTitle() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '拼豆图纸 ${now.year}-$month-$day';
  }
}
