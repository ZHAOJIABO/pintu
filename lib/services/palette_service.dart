import 'package:flutter/services.dart' show rootBundle;

import '../models/color.dart';
import '../models/palette.dart';

class PaletteDefinition {
  final String id;
  final String prefix;
  final String displayName;

  const PaletteDefinition(this.id, this.prefix, this.displayName);
}

const _mard221Definition = PaletteDefinition('mard221', 'M', 'Mard 221');
const _mard221AssetPath = 'assets/palettes/mard221.csv';

class PaletteService {
  Palette? _mard221Cache;

  List<PaletteDefinition> get availablePalettes => const [_mard221Definition];

  Future<List<Palette>> loadAll() async {
    return [await _loadMard221()];
  }

  /// Only Mard 221 is supported. The unused value keeps legacy drafts usable.
  Future<Palette> loadByName(String _) => _loadMard221();

  Future<Palette> _loadMard221() async {
    final cachedPalette = _mard221Cache;
    if (cachedPalette != null) return cachedPalette;

    final csv = await rootBundle.loadString(_mard221AssetPath);
    final entries = <PaletteEntry>[];
    final lines = csv.split(RegExp(r'\r?\n'));

    for (var lineNumber = 0; lineNumber < lines.length; lineNumber++) {
      final line = lines[lineNumber].trim();
      if (line.isEmpty) continue;

      final cells = line.split(',').map((cell) => cell.trim()).toList();
      if (cells.length != 6) {
        throw FormatException(
          'Mard 221 palette row ${lineNumber + 1} must have six columns.',
        );
      }

      final red = int.tryParse(cells[3]);
      final green = int.tryParse(cells[4]);
      final blue = int.tryParse(cells[5]);
      if (red == null || green == null || blue == null) {
        throw FormatException(
          'Mard 221 palette row ${lineNumber + 1} contains an invalid RGB value.',
        );
      }
      if (red < 0 ||
          red > 255 ||
          green < 0 ||
          green > 255 ||
          blue < 0 ||
          blue > 255) {
        throw FormatException(
          'Mard 221 palette row ${lineNumber + 1} has an out-of-range RGB value.',
        );
      }

      entries.add(
        PaletteEntry(
          ref: cells[0],
          name: cells[1],
          symbol: cells[2],
          color: BeadColor.fromInt(red, green, blue, 255),
          prefix: _mard221Definition.prefix,
        ),
      );
    }

    if (entries.length != 221) {
      throw FormatException(
        'Mard 221 palette must contain 221 colors, found ${entries.length}.',
      );
    }

    final palette = Palette(
      name: _mard221Definition.displayName,
      entries: entries,
    );
    _mard221Cache = palette;
    return palette;
  }
}
