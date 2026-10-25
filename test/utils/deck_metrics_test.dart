import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/utils/deck_metrics.dart';

ScryfallCard _sc(String id, String type, double cmc) => ScryfallCard.fromJson({
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

  group('sortByManaValue', () {
    List<String> names(List<DeckCard> cards) =>
        cards.map((c) => c.name).toList();

    test('mana value croissante', () {
      final sorted = sortByManaValue(
        [_dc('c', 1), _dc('a', 1), _dc('b', 1)],
        [
          _sc('a', 'Sorcery', 5),
          _sc('b', 'Instant', 1),
          _sc('c', 'Artifact', 3),
        ],
      );
      expect(names(sorted), ['b', 'c', 'a']);
    });

    test('à mana value égale, par nom', () {
      final sorted = sortByManaValue(
        [
          DeckCard(scryfallId: 'x', name: 'Zuran Orb', quantity: 1),
          DeckCard(scryfallId: 'y', name: 'Arcane Signet', quantity: 1),
        ],
        [_sc('x', 'Artifact', 2), _sc('y', 'Artifact', 2)],
      );
      expect(names(sorted), ['Arcane Signet', 'Zuran Orb']);
    });

    test('les terrains (cmc 0) restent triés par nom', () {
      final sorted = sortByManaValue(
        [
          DeckCard(scryfallId: 'p', name: 'Plains', quantity: 6),
          DeckCard(scryfallId: 't', name: 'Command Tower', quantity: 1),
          DeckCard(scryfallId: 'f', name: 'Forest', quantity: 8),
        ],
        [
          _sc('p', 'Basic Land — Plains', 0),
          _sc('t', 'Land', 0),
          _sc('f', 'Basic Land — Forest', 0),
        ],
      );
      expect(names(sorted), ['Command Tower', 'Forest', 'Plains']);
    });

    test('sans donnée ou sans cmc, la carte compte pour 0', () {
      final noCmc = ScryfallCard.fromJson({
        'id': 'n',
        'oracle_id': 'o-n',
        'name': 'n',
        'type_line': 'Instant',
        'legalities': <String, dynamic>{},
        'prices': <String, dynamic>{},
        'purchase_uris': <String, dynamic>{},
        'color_identity': <String>[],
        'set_name': 'Test',
        'set': 'tst',
        'collector_number': '1',
        'rarity': 'common',
      });
      final sorted = sortByManaValue(
        [
          DeckCard(scryfallId: 'deux', name: 'B', quantity: 1),
          DeckCard(scryfallId: 'LOCAL:Ma carte', name: 'C', quantity: 1),
          DeckCard(scryfallId: 'n', name: 'D', quantity: 1),
          DeckCard(scryfallId: 'zero', name: 'A', quantity: 1),
        ],
        [_sc('deux', 'Instant', 2), _sc('zero', 'Artifact', 0), noCmc],
      );
      expect(names(sorted), ['A', 'C', 'D', 'B']);
    });

    test('rend une nouvelle liste, sans toucher celle reçue', () {
      final input = [_dc('b', 1), _dc('a', 1)];
      final sorted = sortByManaValue(input, [
        _sc('a', 'Instant', 1),
        _sc('b', 'Instant', 2),
      ]);
      expect(names(sorted), ['a', 'b']);
      expect(names(input), ['b', 'a']);
    });
  });
}
