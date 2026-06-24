import 'color.dart';

class PaletteEntry {
  final String name;
  final String ref;
  final String symbol;
  final BeadColor color;
  final String prefix;
  bool enabled;

  PaletteEntry({
    required this.name,
    required this.ref,
    required this.symbol,
    required this.color,
    required this.prefix,
    this.enabled = true,
  });
}

class Palette {
  final String name;
  final List<PaletteEntry> entries;

  Palette({required this.name, required this.entries});
}
