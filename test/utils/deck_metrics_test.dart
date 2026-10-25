import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/utils/deck_metrics.dart';

ScryfallCard _sc(String id, String type, double cmc) =>
    ScryfallCard.fromJson({
      'id': id,
      'oracle_id': 'o-$id',
      'name': id,
      'type_line': type,
      'cmc': cmc,
      'legalities': <String, dynamic>{},
      'prices': <String, dynamic>{},
      'purchase_uris': <String, dynamic>{},
      'color_identity': <String>[],
      'set_name': 'Test',
      'set': 'tst',
      'collector_number': '1',
      'rarity': 'common',
    });

DeckCard _dc(String id, int quantity) =>
    DeckCard(scryfallId: id, name: id, quantity: quantity);

void main() {
  group('averageManaValue', () {
    test('pondère par la quantité', () {
      // (1 x 3 + 4 x 1) / 4 cartes = 1,75 ; sans pondération ce serait 2,5.
      final avg = averageManaValue(
        [_dc('a', 3), _dc('b', 1)],
        [_sc('a', 'Instant', 1), _sc('b', 'Sorcery', 4)],
      );
      expect(avg, 1.75);
    });

    test('exclut les terrains', () {
      final avg = averageManaValue(
        [_dc('a', 1), _dc('forest', 10)],
        [_sc('a', 'Instant', 2), _sc('forest', 'Basic Land — Forest', 0)],
      );
      expect(avg, 2.0);
    });

    test('ignore les identifiants LOCAL:', () {
      final avg = averageManaValue(
        [_dc('a', 1), _dc('LOCAL:x', 5)],
        [_sc('a', 'Instant', 2), _sc('LOCAL:x', 'Sorcery', 9)],
      );
      expect(avg, 2.0);
    });

    test('ignore une carte dont les données sont absentes', () {
      final avg = averageManaValue(
        [_dc('a', 1), _dc('inconnue', 3)],
        [_sc('a', 'Instant', 2)],
      );
      expect(avg, 2.0);
    });

    test('rend 0,0 sans aucune carte comptée', () {
      expect(averageManaValue(const [], const []), 0.0);
      expect(
        averageManaValue(
          [_dc('forest', 4)],
          [_sc('forest', 'Basic Land — Forest', 0)],
        ),
        0.0,
      );
    });
  });

  group('deckCardGridColumns', () {
    test('suit la largeur, bornée entre 3 et 8', () {
      expect(deckCardGridColumns(390), 3);
      expect(deckCardGridColumns(840), 6);
      expect(deckCardGridColumns(1280), 8);
      expect(deckCardGridColumns(200), 3);
      expect(deckCardGridColumns(4000), 8);
    });
  });
}
