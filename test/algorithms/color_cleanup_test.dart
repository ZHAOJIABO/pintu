import 'dart:typed_data';

import 'package:bobobeads/algorithms/color_cleanup.dart';
import 'package:bobobeads/models/denoise_strength.dart';
import 'package:bobobeads/models/project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('保边降噪会平滑细微色差，且保留 alpha', () {
    final pixels = Uint8List.fromList([
      200,
      160,
      130,
      255,
      200,
      160,
      130,
      255,
      200,
      160,
      130,
      255,
      200,
      160,
      130,
      255,
      212,
      172,
      142,
      255,
      200,
      160,
      130,
      255,
      200,
      160,
      130,
      255,
      200,
      160,
      130,
      255,
      200,
      160,
      130,
      255,
    ]);

    final result = denoiseRgbaPixels(
      pixels: pixels,
      width: 3,
      height: 3,
      strength: DenoiseStrength.standard,
    );

    expect(result.sublist(16, 20), [204, 164, 134, 255]);
  });

  test('小色块合并会合并相近色孤岛，但保留高反差细节', () {
    final pixels = Uint8List.fromList([
      220,
      180,
      150,
      255,
      220,
      180,
      150,
      255,
      220,
      180,
      150,
      255,
      220,
      180,
      150,
      255,
      214,
      174,
      144,
      255,
      220,
      180,
      150,
      255,
      220,
      180,
      150,
      255,
      220,
      180,
      150,
      255,
      0,
      0,
      0,
      255,
    ]);

    mergeSmallSimilarColorIslands(
      pixels: pixels,
      width: 3,
      height: 3,
      matching: MatchingAlgorithm.cie2000.matcher,
      strength: DenoiseStrength.standard,
    );

    expect(pixels.sublist(16, 20), [220, 180, 150, 255]);
    expect(pixels.sublist(32, 36), [0, 0, 0, 255]);
  });

  test('强力模式会合并比标准模式更大的相近色小块', () {
    Uint8List pixelsWithThreeBeadIsland() {
      final pixels = Uint8List(5 * 3 * 4);
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 5; x++) {
          final offset = (y * 5 + x) * 4;
          final isIsland = y == 1 && x >= 1 && x <= 3;
          pixels[offset] = isIsland ? 214 : 220;
          pixels[offset + 1] = isIsland ? 174 : 180;
          pixels[offset + 2] = isIsland ? 144 : 150;
          pixels[offset + 3] = 255;
        }
      }
      return pixels;
    }

    final standard = pixelsWithThreeBeadIsland();
    final strong = pixelsWithThreeBeadIsland();
    final matching = MatchingAlgorithm.cie2000.matcher;
    mergeSmallSimilarColorIslands(
      pixels: standard,
      width: 5,
      height: 3,
      matching: matching,
      strength: DenoiseStrength.standard,
    );
    mergeSmallSimilarColorIslands(
      pixels: strong,
      width: 5,
      height: 3,
      matching: matching,
      strength: DenoiseStrength.strong,
    );

    const centerOffset = (1 * 5 + 2) * 4;
    expect(standard.sublist(centerOffset, centerOffset + 4), [
      214,
      174,
      144,
      255,
    ]);
    expect(strong.sublist(centerOffset, centerOffset + 4), [
      220,
      180,
      150,
      255,
    ]);
  });
}
