import 'dart:typed_data';

import '../models/generated_pattern.dart';
import 'api/api_models.dart';
import 'api/api_repositories.dart';
import 'pattern_export_service.dart';

class UploadedPatternImages {
  final String patternImageUrl;
  final String thumbnailUrl;

  const UploadedPatternImages({
    required this.patternImageUrl,
    required this.thumbnailUrl,
  });
}

/// Renders an edited chart and its thumbnail, then publishes both to storage.
class PatternImageUploadService {
  static const _previewFileName = 'pattern-preview.png';
  static const _thumbnailFileName = 'pattern-thumbnail.png';

  final PatternExportService exportService;

  const PatternImageUploadService({
    this.exportService = const PatternExportService(),
  });

  Future<UploadedPatternImages> uploadEditedPattern({
    required MediaRepository media,
    required GeneratedPattern pattern,
  }) async {
    final previewBytesFuture = exportService.exportChartPngBytes(pattern);
    final thumbnailBytesFuture = exportService.exportChartThumbnailPngBytes(
      pattern,
    );
    final previewUrlFuture = _uploadPng(
      media: media,
      bytes: previewBytesFuture,
      fileName: _previewFileName,
    );
    final thumbnailUrlFuture = _uploadPng(
      media: media,
      bytes: thumbnailBytesFuture,
      fileName: _thumbnailFileName,
    );
    final urls = await Future.wait<String>([
      previewUrlFuture,
      thumbnailUrlFuture,
    ]);
    return UploadedPatternImages(
      patternImageUrl: urls[0],
      thumbnailUrl: urls[1],
    );
  }

  Future<String> _uploadPng({
    required MediaRepository media,
    required Future<Uint8List> bytes,
    required String fileName,
  }) async {
    final uploadTokenFuture = media.createUploadToken(
      fileName: fileName,
      contentType: 'image/png',
      purpose: 'pattern',
    );
    final results = await Future.wait<Object>([bytes, uploadTokenFuture]);
    final imageBytes = results[0] as Uint8List;
    final uploadToken = results[1] as UploadToken;
    await media.uploadToObjectStorage(token: uploadToken, bytes: imageBytes);
    final uploaded = await media.reportUpload(
      fileKey: uploadToken.fileKey,
      fileSize: imageBytes.length,
    );
    if (uploaded.fileUrl.isEmpty) {
      throw const FormatException('图纸图片上传响应缺少 fileUrl');
    }
    return uploaded.fileUrl;
  }
}
