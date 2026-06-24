import 'dart:convert';
import 'dart:typed_data';

import '../models/palette.dart';
import 'draft_project.dart';

class GeneratedPattern {
  final Uint8List pixels;
  final int width;
  final int height;
  final Map<String, int> usage;
  final List<PaletteEntry> paletteEntries;
  final DraftProject draft;

  const GeneratedPattern({
    required this.pixels,
    required this.width,
    required this.height,
    required this.usage,
    required this.paletteEntries,
    required this.draft,
  });

  int get totalBeads => usage.values.fold(0, (sum, count) => sum + count);

  GeneratedPattern copyWith({
    Uint8List? pixels,
    int? width,
    int? height,
    Map<String, int>? usage,
    List<PaletteEntry>? paletteEntries,
    DraftProject? draft,
  }) {
    return GeneratedPattern(
      pixels: pixels ?? this.pixels,
      width: width ?? this.width,
      height: height ?? this.height,
      usage: usage ?? this.usage,
      paletteEntries: paletteEntries ?? this.paletteEntries,
      draft: draft ?? this.draft,
    );
  }

  Map<String, Object?> toJson() => {
    'pixels': base64Encode(pixels),
    'width': width,
    'height': height,
    'usage': usage,
    'paletteRefs': paletteEntries.map((entry) => entry.ref).toList(),
  };
}
