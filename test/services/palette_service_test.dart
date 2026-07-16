import 'package:bobobeads/services/palette_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads the bundled Mard 221 palette for every palette request',
    () async {
      final service = PaletteService();

      expect(service.availablePalettes, hasLength(1));
      expect(service.availablePalettes.single.id, 'mard221');

      final palette = await service.loadByName('legacy-brand-id');
      expect(palette.name, 'Mard 221');
      expect(palette.entries, hasLength(221));

      final first = palette.entries.first;
      expect(first.ref, 'A1');
      expect(first.name, 'A1');
      expect(first.symbol, 'A1');
      expect(first.color.toHex(), '#faf4c8');

      final black = palette.entries.firstWhere((entry) => entry.ref == 'H7');
      expect(black.color.toHex(), '#000000');
    },
  );
}
