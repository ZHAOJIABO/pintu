import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../algorithms/color_reducer.dart';

class ImageService {
  static const _finishedProductImageSource = ImageSource.camera;
  static const minSaturation = 0;
  static const maxSaturation = 100;

  final ImagePicker _picker = ImagePicker();

  bool get finishedProductUsesCamera =>
      _finishedProductImageSource == ImageSource.camera;

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    return await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
    );
  }

  /// Picks an image without any resizing. Chart import samples individual grid
  /// cells, and image_picker's maxWidth/maxHeight resampling (which does run on
  /// web) blends grid lines into cell colors.
  Future<XFile?> pickFullResolutionImage({
    ImageSource source = ImageSource.gallery,
  }) {
    return _picker.pickImage(source: source);
  }

  Future<XFile?> pickFinishedProductPhoto() {
    return _picker.pickImage(
      source: _finishedProductImageSource,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 95,
      requestFullMetadata: false,
    );
  }

  /// Returns a color matrix that adjusts saturation using the same scale as
  /// the parameter page: 0 is grayscale and 100 preserves the source colors.
  static List<double> saturationColorMatrix(int saturation) {
    _validateSaturation(saturation);

    final factor = saturation / maxSaturation;
    final inverseFactor = 1 - factor;
    const redLuminance = 0.213;
    const greenLuminance = 0.715;
    const blueLuminance = 0.072;

    return [
      redLuminance * inverseFactor + factor,
      greenLuminance * inverseFactor,
      blueLuminance * inverseFactor,
      0,
      0,
      redLuminance * inverseFactor,
      greenLuminance * inverseFactor + factor,
      blueLuminance * inverseFactor,
      0,
      0,
      redLuminance * inverseFactor,
      greenLuminance * inverseFactor,
      blueLuminance * inverseFactor + factor,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  /// Applies the parameter-page saturation scale to packed RGBA pixels.
  Uint8List adjustSaturation(Uint8List rgbaPixels, int saturation) {
    _validateSaturation(saturation);
    if (rgbaPixels.lengthInBytes % 4 != 0) {
      throw ArgumentError.value(
        rgbaPixels.lengthInBytes,
        'rgbaPixels.lengthInBytes',
        'must be divisible by 4',
      );
    }
    if (saturation == maxSaturation) {
      return Uint8List.fromList(rgbaPixels);
    }

    final matrix = saturationColorMatrix(saturation);
    final adjusted = Uint8List.fromList(rgbaPixels);
    for (var offset = 0; offset < adjusted.lengthInBytes; offset += 4) {
      final red = rgbaPixels[offset];
      final green = rgbaPixels[offset + 1];
      final blue = rgbaPixels[offset + 2];
      adjusted[offset] = _clampColor(
        matrix[0] * red + matrix[1] * green + matrix[2] * blue,
      );
      adjusted[offset + 1] = _clampColor(
        matrix[5] * red + matrix[6] * green + matrix[7] * blue,
      );
      adjusted[offset + 2] = _clampColor(
        matrix[10] * red + matrix[11] * green + matrix[12] * blue,
      );
    }
    return adjusted;
  }

  static void _validateSaturation(int saturation) {
    if (saturation < minSaturation || saturation > maxSaturation) {
      throw ArgumentError.value(
        saturation,
        'saturation',
        'must be between $minSaturation and $maxSaturation',
      );
    }
  }

  static int _clampColor(double value) => value.round().clamp(0, 255);

  Future<Uint8List> resizeAndGetPixels(
    Uint8List imageBytes,
    int targetWidth,
    int targetHeight, {
    bool fit = true,
    bool center = true,
    int? alphaThreshold,
  }) async {
    if (alphaThreshold != null &&
        (alphaThreshold < 1 || alphaThreshold > 255)) {
      throw ArgumentError.value(
        alphaThreshold,
        'alphaThreshold',
        'must be between 1 and 255',
      );
    }
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
        final alpha = pixel.a.toInt();
        final isTransparent = alphaThreshold != null && alpha < alphaThreshold;
        pixels[offset] = isTransparent ? 0 : pixel.r.toInt();
        pixels[offset + 1] = isTransparent ? 0 : pixel.g.toInt();
        pixels[offset + 2] = isTransparent ? 0 : pixel.b.toInt();
        pixels[offset + 3] = alphaThreshold == null
            ? alpha
            : isTransparent
            ? 0
            : 255;
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
