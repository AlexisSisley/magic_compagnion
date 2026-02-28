import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/utils/card_list_upsert_mixin.dart';

class _TestService with CardListUpsertMixin {}

void main() {
  late _TestService service;
  late List<DeckCard> cards;

  setUp(() {
    service = _TestService();
    cards = [];
  });

  group('upsertCardInList', () {
    test('ajoute une nouvelle carte avec quantityToAdd', () {
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        quantityToAdd: 2,
      );
      expect(cards, hasLength(1));
      expect(cards.first.scryfallId, 'abc-123');
      expect(cards.first.name, 'Black Lotus');
      expect(cards.first.quantity, 2);
    });

    test('ajoute une nouvelle carte avec absoluteQuantity', () {
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        absoluteQuantity: 4,
      );
      expect(cards, hasLength(1));
      expect(cards.first.quantity, 4);
    });

    test('incremente la quantite d une carte existante', () {
      cards.add(DeckCard(scryfallId: 'abc-123', name: 'Black Lotus', quantity: 2));
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        quantityToAdd: 3,
      );
      expect(cards, hasLength(1));
      expect(cards.first.quantity, 5);
    });

    test('supprime la carte quand la quantite tombe a 0', () {
      cards.add(DeckCard(scryfallId: 'abc-123', name: 'Black Lotus', quantity: 2));
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        quantityToAdd: -2,
      );
      expect(cards, isEmpty);
    });

    test('supprime la carte quand absoluteQuantity est 0', () {
      cards.add(DeckCard(scryfallId: 'abc-123', name: 'Black Lotus', quantity: 5));
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        absoluteQuantity: 0,
      );
      expect(cards, isEmpty);
    });

    test('ne cree pas de carte si quantityToAdd est negatif', () {
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        quantityToAdd: -1,
      );
      expect(cards, isEmpty);
    });

    test('met a jour les tags d une carte existante', () {
      cards.add(DeckCard(scryfallId: 'abc-123', name: 'Black Lotus', quantity: 1, tags: ['old']));
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        quantityToAdd: 1,
        newTags: ['new', 'tag'],
      );
      expect(cards.first.tags, ['new', 'tag']);
      expect(cards.first.quantity, 2);
    });

    test('met a jour le statut foil d une carte existante', () {
      cards.add(DeckCard(scryfallId: 'abc-123', name: 'Black Lotus', quantity: 1, isFoil: false));
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        quantityToAdd: 1,
        isFoil: true,
      );
      expect(cards.first.isFoil, true);
    });

    test('matchByFoil distingue foil et non-foil', () {
      cards.add(DeckCard(scryfallId: 'abc-123', name: 'Black Lotus', quantity: 1, isFoil: false));
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        quantityToAdd: 1,
        matchByFoil: true,
        isFoil: true,
      );
      // Devrait creer une 2eme entree (foil) au lieu d'updater la non-foil
      expect(cards, hasLength(2));
      expect(cards[0].isFoil, false);
      expect(cards[0].quantity, 1);
      expect(cards[1].isFoil, true);
      expect(cards[1].quantity, 1);
    });

    test('matchByFoil false fusionne foil et non-foil', () {
      cards.add(DeckCard(scryfallId: 'abc-123', name: 'Black Lotus', quantity: 1, isFoil: false));
      service.upsertCardInList(
        cards,
        scryfallId: 'abc-123',
        cardName: 'Black Lotus',
        quantityToAdd: 1,
        matchByFoil: false,
        isFoil: true,
      );
      // Devrait updater l'entree existante
      expect(cards, hasLength(1));
      expect(cards.first.quantity, 2);
      expect(cards.first.isFoil, true);
    });
  });
}
