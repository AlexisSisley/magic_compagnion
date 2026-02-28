import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';

void main() {
  group('DeckCard', () {
    test('fromJson/toJson roundtrip', () {
      final json = {
        'scryfallId': 'abc-123',
        'name': 'Lightning Bolt',
        'quantity': 4,
        'proxyQuantity': 2,
        'isFoil': true,
        'tags': ['Burn', 'Staple'],
      };

      final card = DeckCard.fromJson(json);
      expect(card.scryfallId, 'abc-123');
      expect(card.name, 'Lightning Bolt');
      expect(card.quantity, 4);
      expect(card.proxyQuantity, 2);
      expect(card.isFoil, true);
      expect(card.tags, ['Burn', 'Staple']);

      final output = card.toJson();
      expect(output['scryfallId'], json['scryfallId']);
      expect(output['name'], json['name']);
      expect(output['quantity'], json['quantity']);
      expect(output['proxyQuantity'], json['proxyQuantity']);
      expect(output['isFoil'], json['isFoil']);
      expect(output['tags'], json['tags']);
    });

    test('fromJson with default values', () {
      final json = {
        'scryfallId': 'xyz-789',
        'name': 'Sol Ring',
        'quantity': 1,
      };

      final card = DeckCard.fromJson(json);
      expect(card.proxyQuantity, 0);
      expect(card.isFoil, false);
      expect(card.tags, isEmpty);
    });

    test('fromJson with null tags', () {
      final json = {
        'scryfallId': 'xyz-789',
        'name': 'Sol Ring',
        'quantity': 1,
        'tags': null,
      };

      final card = DeckCard.fromJson(json);
      expect(card.tags, isEmpty);
    });
  });

  group('Deck', () {
    test('fromJson/toJson roundtrip', () {
      final json = {
        'id': 'deck-1',
        'name': 'My Commander Deck',
        'mainboard': [
          {'scryfallId': 'a', 'name': 'Card A', 'quantity': 1},
          {'scryfallId': 'b', 'name': 'Card B', 'quantity': 2},
        ],
        'sideboard': [
          {'scryfallId': 'c', 'name': 'Card C', 'quantity': 1},
        ],
        'considering': [],
        'wishlist': [
          {'scryfallId': 'd', 'name': 'Card D', 'quantity': 1},
        ],
        'commanderScryfallId': 'cmd-1',
        'commanderSecondaryScryfallId': null,
        'colors': ['W', 'U'],
        'format': 'Commander',
      };

      final deck = Deck.fromJson(json);
      expect(deck.id, 'deck-1');
      expect(deck.name, 'My Commander Deck');
      expect(deck.mainboard.length, 2);
      expect(deck.sideboard.length, 1);
      expect(deck.considering, isEmpty);
      expect(deck.wishlist.length, 1);
      expect(deck.commanderScryfallId, 'cmd-1');
      expect(deck.commanderSecondaryScryfallId, isNull);
      expect(deck.colors, ['W', 'U']);
      expect(deck.format, 'Commander');

      final output = deck.toJson();
      expect(output['id'], 'deck-1');
      expect(output['name'], 'My Commander Deck');
      expect((output['mainboard'] as List).length, 2);
      expect((output['sideboard'] as List).length, 1);
      expect((output['considering'] as List), isEmpty);
      expect((output['wishlist'] as List).length, 1);
    });

    test('fromJson with missing optional fields', () {
      final json = {
        'id': 'deck-2',
        'name': 'Simple Deck',
      };

      final deck = Deck.fromJson(json);
      expect(deck.mainboard, isEmpty);
      expect(deck.sideboard, isEmpty);
      expect(deck.considering, isEmpty);
      expect(deck.wishlist, isEmpty);
      expect(deck.commanderScryfallId, isNull);
      expect(deck.commanderSecondaryScryfallId, isNull);
      expect(deck.colors, isEmpty);
      expect(deck.format, 'Standard');
    });

    test('constructor defaults', () {
      final deck = Deck(id: 'test', name: 'Test Deck', colors: []);
      expect(deck.mainboard, isEmpty);
      expect(deck.sideboard, isEmpty);
      expect(deck.considering, isEmpty);
      expect(deck.wishlist, isEmpty);
      expect(deck.format, 'Standard');
    });
  });
}
