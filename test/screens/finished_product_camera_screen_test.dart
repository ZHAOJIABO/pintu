import 'package:bobobeads/screens/finished_product_camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finished-product capture enables background removal by default', () {
    expect(const FinishedProductCameraScreen().enableBackgroundRemoval, isTrue);
  });

  test(
    'portrait camera preview uses CameraPreview\'s rotated aspect ratio',
    () {
      final scale = portraitCameraPreviewScale(
        cameraAspectRatio: 4 / 3,
        viewportSize: const Size(390, 844),
      );

      expect(scale, closeTo(1.623, 0.001));
    },
  );
}
