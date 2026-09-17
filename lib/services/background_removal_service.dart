import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class BackgroundRemovalService {
  Future<Uint8List> removeBackground(
    Uint8List imageBytes, {
    ForegroundSelection? selection,
  });
}

/// A normalized region used to identify the intended foreground instance.
/// It is a selection hint only; it never crops the returned subject.
class ForegroundSelection {
  final double left;
  final double top;
  final double width;
  final double height;

  const ForegroundSelection({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Map<String, double> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };
}

class PlatformBackgroundRemovalService implements BackgroundRemovalService {
  static const MethodChannel _channel = MethodChannel(
    'bobobeads/background_removal',
  );

  const PlatformBackgroundRemovalService();

  @override
  Future<Uint8List> removeBackground(
    Uint8List imageBytes, {
    ForegroundSelection? selection,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      debugPrint(
        '[BackgroundRemoval] skipped: platform does not support native cutout.',
      );
      return imageBytes;
    }

    try {
      final isSimulator =
          await _channel.invokeMethod<bool>('isSimulator') ?? false;
      if (isSimulator) {
        debugPrint(
          '[BackgroundRemoval] skipped: iOS Simulator does not support Vision cutout.',
        );
        return imageBytes;
      }

      debugPrint('[BackgroundRemoval] invoking iOS Vision cutout.');
      final result = await _channel.invokeMethod<Uint8List>(
        'removeBackground',
        {
          'image': imageBytes,
          if (selection != null) 'selection': selection.toJson(),
        },
      );
      debugPrint(
        '[BackgroundRemoval] iOS Vision returned ${result?.length ?? 0} bytes.',
      );
      return result ?? imageBytes;
    } on MissingPluginException catch (error) {
      debugPrint(
        '[BackgroundRemoval] native channel is unavailable: $error. '
        'Fully restart the app after installing a build with native changes.',
      );
      return imageBytes;
    } on PlatformException catch (error) {
      // Generation remains available on unsupported iOS versions or when
      // Vision cannot find a foreground subject.
      debugPrint(
        '[BackgroundRemoval] iOS Vision failed (${error.code}): '
        '${error.message ?? 'no message'}',
      );
      return imageBytes;
    }
  }
}
