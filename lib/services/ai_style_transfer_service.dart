import 'dart:typed_data';

import 'api/api_models.dart';
import 'api/api_repositories.dart';
import 'api/api_session_store.dart';

/// Coordinates the multi-request AI style transfer flow without exposing it to
/// presentation widgets. Every submission is an independent task; the backend
/// allows several to run concurrently and rejects the request once its own
/// limit is reached.
class AiStyleTransferService {
  final MediaRepository media;
  final AIGenerationRepository generations;
  final ApiSessionStore store;

  const AiStyleTransferService({
    required this.media,
    required this.generations,
    required this.store,
  });

  Future<AIGenerationItem> submitAndWait({
    required String styleId,
    required Uint8List imageBytes,
  }) async {
    if (imageBytes.isEmpty) {
      throw StateError('风格转换缺少原图');
    }

    final uploadToken = await media.createUploadToken(
      fileName: 'style-input.png',
      contentType: 'image/png',
      purpose: 'style_input',
    );
    if (uploadToken.maxFileSize > 0 &&
        imageBytes.length > uploadToken.maxFileSize) {
      throw StateError('图片超过 ${uploadToken.maxFileSize ~/ (1024 * 1024)}MB 限制');
    }
    await media.uploadToObjectStorage(token: uploadToken, bytes: imageBytes);
    await media.reportUpload(
      fileKey: uploadToken.fileKey,
      fileSize: imageBytes.length,
    );

    final created = await generations.createStyleGeneration(
      styleId: styleId,
      inputFileKey: uploadToken.fileKey,
      clientRequestId: await store.readOrCreatePendingStyleClientRequestId(),
    );
    if (created.taskId.isEmpty) {
      throw const FormatException('风格转换响应缺少 taskId');
    }
    // The idempotency key only has to cover the create call itself, so that a
    // lost response cannot be retried into a second charge. Holding it any
    // longer would make the next submission dedupe onto this task.
    await store.clearPendingStyleClientRequestId();
    await store.markAiTaskUnseen(created.taskId);
    return generations.waitForStyleGeneration(created.taskId);
  }
}
