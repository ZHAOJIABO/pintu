import 'dart:typed_data';

import '../../models/generated_pattern.dart';
import '../pattern_export_service.dart';
import 'api_models.dart';
import 'api_repositories.dart';
import 'api_session_store.dart';

class GenerationCompletionService {
  final MediaRepository media;
  final GenerationRepository generations;
  final ApiSessionStore store;
  final PatternExportService exportService;

  const GenerationCompletionService({
    required this.media,
    required this.generations,
    required this.store,
    this.exportService = const PatternExportService(),
  });

  Future<void> startNewAttempt() async {
    await Future.wait([
      store.clearPendingGenerationClientRequestId(),
      store.clearPendingGenerationId(),
    ]);
    await store.readOrCreatePendingGenerationClientRequestId();
  }

  Future<GenerationCompleteResult> completeGeneratedPattern(
    GeneratedPattern pattern, {
    String sourceType = 'photo',
    String sourceId = '',
    String? title,
    String? originalImageUrl,
  }) async {
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
    final generationId = await _resolveGenerationId(
      boardSpec: boardSpec,
      sourceType: sourceType,
      sourceId: sourceId,
    );
    final sourceUrl =
        originalImageUrl ??
        await _uploadOriginalImage(pattern.draft.imageForGeneration);
    final previewUrl = await _uploadPatternPreview(pattern);
    final result = await generations.completeGeneration(
      generationId: generationId,
      title: title ?? _defaultTitle(),
      originalImageUrl: sourceUrl,
      patternImageUrl: previewUrl,
      patternData: patternData,
      beadCount: beadCount,
      colorCount: colorCount,
    );
    await Future.wait([
      store.clearPendingGenerationClientRequestId(),
      store.clearPendingGenerationId(),
    ]);
    return result;
  }

  Future<String> _resolveGenerationId({
    required String boardSpec,
    required String sourceType,
    required String sourceId,
  }) async {
    final pending = await store.readPendingGenerationId();
    if (pending != null && pending.isNotEmpty) return pending;

    final created = await generations.createGeneration(
      boardSpec: boardSpec,
      sourceType: sourceType,
      sourceId: sourceId,
      clientRequestId: await store
          .readOrCreatePendingGenerationClientRequestId(),
    );
    if (created.generationId.isEmpty) {
      throw const FormatException('生成凭证响应缺少 generationId');
    }
    await store.savePendingGenerationId(created.generationId);
    return created.generationId;
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

  Future<String> _uploadPatternPreview(GeneratedPattern pattern) async {
    final bytes = await exportService.exportChartPngBytes(pattern);
    final uploaded = await media.uploadBytes(
      bytes: bytes,
      fileName: 'pattern-preview.png',
      contentType: 'image/png',
      purpose: 'pattern',
    );
    return _requiredUrl(uploaded, '图纸预览图');
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
