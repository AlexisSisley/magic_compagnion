import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/card_detail_controller.dart';

void main() {
  group('parsePrintFooter', () {
    test('lit set, numero et langue sur un bas de carte francais', () {
      final parsed = parsePrintFooter('146/280 C ELD FR');

      expect(parsed, isNotNull);
      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, 'fr');
    });

    test('sans code langue, la langue est nulle', () {
      final parsed = parsePrintFooter('ELD 146');

      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, isNull);
    });

    test('ignore un code langue qui n est pas supporte par Scryfall', () {
      final parsed = parsePrintFooter('146/280 C ELD ZZ');

      expect(parsed!.lang, isNull);
    });

    test('rend null sur un texte sans motif d edition', () {
      expect(parsePrintFooter('Créature : humain et éclaireur'), isNull);
    });
  });
}
