import 'dart:typed_data';

import 'api/api_models.dart';
import 'api/api_repositories.dart';
import 'api/api_session_store.dart';

/// Coordinates the multi-request AI style transfer flow without exposing it to
/// presentation widgets. A pending task is retained so it can be polled again
/// after the app returns to the foreground.
class AiStyleTransferService {
  final MediaRepository media;
  final AIGenerationRepository generations;
  final ApiSessionStore store;

  const AiStyleTransferService({
    required this.media,
    required this.generations,
    required this.store,
  });

  Future<void> startNewAttempt() async {
    await Future.wait([
      store.clearPendingStyleClientRequestId(),
      store.clearPendingAiTaskId(),
    ]);
  }

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
    await store.savePendingAiTaskId(created.taskId);
    return _waitForTerminalTask(created.taskId);
  }

  Future<AIGenerationItem?> resumePendingTask() async {
    final taskId = await store.readPendingAiTaskId();
    if (taskId == null) return null;
    return _waitForTerminalTask(taskId);
  }

  Future<AIGenerationItem> _waitForTerminalTask(String taskId) async {
    final task = await generations.waitForStyleGeneration(taskId);
    await Future.wait([
      store.clearPendingAiTaskId(),
      store.clearPendingStyleClientRequestId(),
    ]);
    return task;
  }
}
