import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/wishlist_model.dart';

void main() {
  group('Wishlist', () {
    test('fromJson/toJson roundtrip', () {
      final json = {
        'id': 'wl-1',
        'name': 'Ma Wishlist',
        'cards': [
          {'scryfallId': 'card-1', 'name': 'Force of Will', 'quantity': 1},
          {'scryfallId': 'card-2', 'name': 'Mana Crypt', 'quantity': 2},
        ],
        'dateCreated': '2026-01-15T10:30:00.000',
        'iconScryfallId': 'card-1',
      };

      final wishlist = Wishlist.fromJson(json);
      expect(wishlist.id, 'wl-1');
      expect(wishlist.name, 'Ma Wishlist');
      expect(wishlist.cards.length, 2);
      expect(wishlist.dateCreated.year, 2026);
      expect(wishlist.dateCreated.month, 1);
      expect(wishlist.iconScryfallId, 'card-1');

      final output = wishlist.toJson();
      expect(output['id'], 'wl-1');
      expect(output['name'], 'Ma Wishlist');
      expect((output['cards'] as List).length, 2);
      expect(output['iconScryfallId'], 'card-1');
    });

    test('fromJson with null iconScryfallId', () {
      final json = {
        'id': 'wl-2',
        'name': 'Autre Liste',
        'cards': [],
        'dateCreated': '2026-02-20T12:00:00.000',
      };

      final wishlist = Wishlist.fromJson(json);
      expect(wishlist.iconScryfallId, isNull);
    });

    test('fromJson with missing dateCreated falls back', () {
      final json = {
        'id': 'wl-3',
        'name': 'Legacy',
        'cards': [],
      };

      final wishlist = Wishlist.fromJson(json);
      expect(wishlist.dateCreated, isNotNull);
    });

    test('totalCards getter', () {
      final wishlist = Wishlist(
        id: 'test',
        name: 'Test',
        cards: [
          DeckCard(scryfallId: 'a', name: 'A', quantity: 3),
          DeckCard(scryfallId: 'b', name: 'B', quantity: 2),
          DeckCard(scryfallId: 'c', name: 'C', quantity: 1),
        ],
        dateCreated: DateTime.now(),
      );

      expect(wishlist.totalCards, 6);
    });

    test('totalCards with empty cards', () {
      final wishlist = Wishlist(
        id: 'test',
        name: 'Empty',
        cards: [],
        dateCreated: DateTime.now(),
      );

      expect(wishlist.totalCards, 0);
    });
  });
}
