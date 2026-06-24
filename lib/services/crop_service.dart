import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/product_template.dart';

class CropService {
  Future<Uint8List> cropToAspectRatio(
    Uint8List bytes,
    CropAspectRatio ratio,
  ) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Image could not be decoded');
    }

    final targetRatio = ratio.value;
    if (targetRatio == null) {
      return Uint8List.fromList(img.encodePng(decoded));
    }

    final sourceRatio = decoded.width / decoded.height;
    int cropWidth = decoded.width;
    int cropHeight = decoded.height;

    if (sourceRatio > targetRatio) {
      cropWidth = (decoded.height * targetRatio).round();
    } else if (sourceRatio < targetRatio) {
      cropHeight = (decoded.width / targetRatio).round();
    }

    final x = ((decoded.width - cropWidth) / 2).round();
    final y = ((decoded.height - cropHeight) / 2).round();
    final cropped = img.copyCrop(
      decoded,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );
    return Uint8List.fromList(img.encodePng(cropped));
  }

  Future<Uint8List> cropToAspectRatioWithTransform(
    Uint8List bytes,
    CropAspectRatio ratio, {
    required double renderScale,
    required double displayOffsetX,
    required double displayOffsetY,
    required double cropDisplayWidth,
    required double cropDisplayHeight,
    bool flipped = false,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Image could not be decoded');
    }

    if (renderScale <= 0 || cropDisplayWidth <= 0 || cropDisplayHeight <= 0) {
      return cropToAspectRatio(bytes, ratio);
    }

    final cropWidth = (cropDisplayWidth / renderScale)
        .round()
        .clamp(1, decoded.width)
        .toInt();
    final cropHeight = (cropDisplayHeight / renderScale)
        .round()
        .clamp(1, decoded.height)
        .toInt();

    final sourceCenterX = decoded.width / 2 - displayOffsetX / renderScale;
    final sourceCenterY = decoded.height / 2 - displayOffsetY / renderScale;
    final maxX = decoded.width - cropWidth;
    final maxY = decoded.height - cropHeight;
    var x = (sourceCenterX - cropWidth / 2).round().clamp(0, maxX).toInt();
    final y = (sourceCenterY - cropHeight / 2).round().clamp(0, maxY).toInt();

    if (flipped) {
      x = decoded.width - x - cropWidth;
    }

    var cropped = img.copyCrop(
      decoded,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );
    if (flipped) {
      cropped = img.copyFlip(cropped, direction: img.FlipDirection.horizontal);
    }

    return Uint8List.fromList(img.encodePng(cropped));
  }
}
