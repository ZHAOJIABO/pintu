import 'package:http/http.dart' as http;
import '../models/color.dart';
import '../models/palette.dart';

class PaletteDefinition {
  final String id;
  final String prefix;
  final String displayName;
  final bool perlerTransform;

  const PaletteDefinition(
    this.id,
    this.prefix,
    this.displayName, {
    this.perlerTransform = false,
  });
}

const _paletteDefinitions = [
  PaletteDefinition('hama', 'H', 'Hama Midi'),
  PaletteDefinition('hama_mini', 'H', 'Hama Mini'),
  PaletteDefinition('hama_maxi', 'H', 'Hama Maxi'),
  PaletteDefinition('nabbi', 'N', 'Nabbi'),
  PaletteDefinition('mard', 'M', 'Mard'),
  PaletteDefinition('artkal_a', 'A', 'Artkal A-2.6MM'),
  PaletteDefinition('artkal_c', 'C', 'Artkal C-2.6MM'),
  PaletteDefinition('artkal_m', 'M', 'Artkal M-2.6MM'),
  PaletteDefinition('artkal_r', 'R', 'Artkal R-5MM'),
  PaletteDefinition('artkal_s', 'S', 'Artkal S-5MM'),
  PaletteDefinition('perler', 'P', 'Perler', perlerTransform: true),
  PaletteDefinition('perler_mini', 'P', 'Perler Mini', perlerTransform: true),
  PaletteDefinition('perler_caps', 'P', 'Perler Caps', perlerTransform: true),
  PaletteDefinition('yant', 'Y', 'Yant'),
  PaletteDefinition('diamondDotz', 'D', 'Diamond Dotz'),
];

final Palette _bwPalette = Palette(
  name: 'B&W',
  entries: [
    PaletteEntry(
      name: 'White',
      ref: 'BW1',
      symbol: 'W',
      color: BeadColor.fromInt(255, 255, 255, 255),
      prefix: 'BW',
    ),
    PaletteEntry(
      name: 'Black',
      ref: 'BW2',
      symbol: 'B',
      color: BeadColor.fromInt(0, 0, 0, 255),
      prefix: 'BW',
    ),
  ],
);

class PaletteService {
  final Map<String, Palette> _cache = {};

  List<PaletteDefinition> get availablePalettes => _paletteDefinitions;

  Future<List<Palette>> loadAll() async {
    final futures = _paletteDefinitions.map((def) => _loadPalette(def));
    final results = await Future.wait(futures);
    return results.whereType<Palette>().toList();
  }

  Future<Palette> loadByName(String id) async {
    final def = _paletteDefinitions.firstWhere((d) => d.id == id);
    return await _loadPalette(def) ?? _bwPalette;
  }

  Future<Palette?> _loadPalette(PaletteDefinition def) async {
    if (_cache.containsKey(def.id)) return _cache[def.id]!;

    try {
      final url = 'https://beadcolors.eremes.xyz/gen/v3/${def.id}.csv';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final lines = response.body.split('\n');
      final entries = <PaletteEntry>[];

      for (final line in lines) {
        final cells = line.split(',');
        if (cells.length < 6) continue;

        String ref = cells[0];
        if (def.perlerTransform) {
          final numPart = int.tryParse(ref.substring(ref.length - 3)) ?? 0;
          ref = 'P${numPart.toString().padLeft(2, '0')}';
        }

        entries.add(
          PaletteEntry(
            ref: ref,
            name: cells[1],
            symbol: cells[2],
            color: BeadColor.fromInt(
              int.parse(cells[3]),
              int.parse(cells[4]),
              int.parse(cells[5]),
              255,
            ),
            prefix: def.prefix,
          ),
        );
      }

      final palette = Palette(name: def.displayName, entries: entries);
      _cache[def.id] = palette;
      return palette;
    } catch (_) {
      return null;
    }
  }

  Palette get fallbackPalette => _bwPalette;
}
