import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../algorithms/color_reducer.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    return await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
    );
  }

  Future<Uint8List> resizeAndGetPixels(
    Uint8List imageBytes,
    int targetWidth,
    int targetHeight, {
    bool fit = true,
    bool center = true,
  }) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Failed to decode image');

    // Use an explicit alpha channel so letterboxed areas stay transparent.
    final canvas = img.Image(
      width: targetWidth,
      height: targetHeight,
      numChannels: 4,
    )..clear(img.ColorUint8.rgba(0, 0, 0, 0));

    // Calculate aspect-ratio-preserving dimensions (mirrors drawImageInsideCanvas)
    final imageAspect = decoded.width / decoded.height;
    final canvasAspect = targetWidth / targetHeight;

    double renderableWidth, renderableHeight;
    if (imageAspect < canvasAspect) {
      renderableHeight = fit
          ? targetHeight.toDouble()
          : decoded.height.toDouble();
      renderableWidth = fit
          ? decoded.width * (renderableHeight / decoded.height)
          : decoded.width.toDouble();
    } else if (imageAspect > canvasAspect) {
      renderableWidth = fit ? targetWidth.toDouble() : decoded.width.toDouble();
      renderableHeight = fit
          ? decoded.height * (renderableWidth / decoded.width)
          : decoded.height.toDouble();
    } else {
      renderableHeight = fit
          ? targetHeight.toDouble()
          : decoded.height.toDouble();
      renderableWidth = fit ? targetWidth.toDouble() : decoded.width.toDouble();
    }

    final xStart = center ? ((targetWidth - renderableWidth) / 2).floor() : 0;
    final yStart = center ? ((targetHeight - renderableHeight) / 2).floor() : 0;
    final rw = renderableWidth.floor();
    final rh = renderableHeight.floor();

    // Resize image to the renderable size (not target size)
    final resized = img.copyResize(
      decoded,
      width: rw,
      height: rh,
      interpolation: img.Interpolation.linear,
    );

    // Composite resized image onto transparent canvas at calculated offset
    for (int y = 0; y < rh && (yStart + y) < targetHeight; y++) {
      for (int x = 0; x < rw && (xStart + x) < targetWidth; x++) {
        final pixel = resized.getPixel(x, y);
        canvas.setPixel(xStart + x, yStart + y, pixel);
      }
    }

    // Extract RGBA pixel data
    final pixels = Uint8List(targetWidth * targetHeight * 4);
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final pixel = canvas.getPixel(x, y);
        final offset = (y * targetWidth + x) * 4;
        pixels[offset] = pixel.r.toInt();
        pixels[offset + 1] = pixel.g.toInt();
        pixels[offset + 2] = pixel.b.toInt();
        pixels[offset + 3] = pixel.a.toInt();
      }
    }

    return pixels;
  }

  ImagePosition calculateDrawingPosition(
    int canvasWidth,
    int canvasHeight,
    int imageWidth,
    int imageHeight, {
    bool fit = true,
    bool center = true,
  }) {
    double renderableWidth, renderableHeight;
    final imageAspect = imageWidth / imageHeight;
    final canvasAspect = canvasWidth / canvasHeight;

    if (imageAspect < canvasAspect) {
      renderableHeight = fit ? canvasHeight.toDouble() : imageHeight.toDouble();
      renderableWidth = fit
          ? imageWidth * (renderableHeight / imageHeight)
          : imageWidth.toDouble();
    } else if (imageAspect > canvasAspect) {
      renderableWidth = fit ? canvasWidth.toDouble() : imageWidth.toDouble();
      renderableHeight = fit
          ? imageHeight * (renderableWidth / imageWidth)
          : imageHeight.toDouble();
    } else {
      renderableHeight = fit ? canvasHeight.toDouble() : imageHeight.toDouble();
      renderableWidth = fit ? canvasWidth.toDouble() : imageWidth.toDouble();
    }

    final xStart = center ? ((canvasWidth - renderableWidth) / 2).floor() : 0;
    final yStart = center ? ((canvasHeight - renderableHeight) / 2).floor() : 0;

    return ImagePosition(
      xStart,
      yStart,
      renderableWidth.floor(),
      renderableHeight.floor(),
    );
  }
}
