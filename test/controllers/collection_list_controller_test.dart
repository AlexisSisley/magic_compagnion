// Tests unitaires pour CollectionListController
// Teste le filtrage, le tri, le calcul de prix et la couleur de rarete.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/collection_list_controller.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/models/search_filters.dart';

// --- Helpers ---

ScryfallCard _makeScryfallCard({
  required String id,
  required String name,
  String typeLine = 'Creature',
  double? cmc,
  String eurPrice = '0',
  String eurFoilPrice = '0',
  String rarity = 'common',
  List<String> colorIdentity = const [],
  String rulesText = '',
}) {
  return ScryfallCard(
    id: id,
    oracleId: 'oracle-$id',
    name: name,
    imageUrl: '',
    rulesText: rulesText,
    typeLine: typeLine,
    legalities: const {},
    prices: {'eur': eurPrice, 'eur_foil': eurFoilPrice},
    lang: 'en',
    colorIdentity: colorIdentity,
    setName: 'Test Set',
    setCode: 'TST',
    collectorNumber: '1',
    rarity: rarity,
    purchaseUris: const {},
    cmc: cmc,
  );
}

DeckCard _makeDeckCard({
  required String scryfallId,
  required String name,
  int quantity = 1,
  bool isFoil = false,
  List<String> tags = const [],
}) {
  return DeckCard(
    scryfallId: scryfallId,
    name: name,
    quantity: quantity,
    isFoil: isFoil,
    tags: tags,
  );
}

void main() {
  // =================================================================
  // CollectionListState
  // =================================================================

  group('CollectionListState', () {
    test('initial state has correct defaults', () {
      const state = CollectionListState();
      expect(state.filteredCards, isEmpty);
      expect(state.topCards, isEmpty);
    });

    test('copyWith preserves values when not specified', () {
      final cards = [_makeDeckCard(scryfallId: 'a', name: 'Alpha')];
      final state = CollectionListState(filteredCards: cards);
      final copied = state.copyWith(topCards: [{'name': 'test'}]);

      expect(copied.filteredCards, equals(cards));
      expect(copied.topCards.length, 1);
    });
  });

  // =================================================================
  // filterAndSort - Filtre par nom
  // =================================================================

  group('filterAndSort - filter by name query', () {
    test('filters cards by name query (case insensitive)', () {
      final cards = [
        _makeDeckCard(scryfallId: '1', name: 'Sol Ring'),
        _makeDeckCard(scryfallId: '2', name: 'Lightning Bolt'),
        _makeDeckCard(scryfallId: '3', name: 'Sol Talisman'),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Sol Ring'),
        _makeScryfallCard(id: '2', name: 'Lightning Bolt'),
        _makeScryfallCard(id: '3', name: 'Sol Talisman'),
      ];

      final result = CollectionListController.filterAndSort(
        cards: cards,
        fullCardData: scryfallData,
        filterQuery: 'sol',
        activeFilters: const SearchFilters(),
      );

      expect(result.length, 2);
      expect(result.every((c) => c.name.toLowerCase().contains('sol')), isTrue);
    });

    test('empty query returns all cards', () {
      final cards = [
        _makeDeckCard(scryfallId: '1', name: 'Sol Ring'),
        _makeDeckCard(scryfallId: '2', name: 'Lightning Bolt'),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Sol Ring'),
        _makeScryfallCard(id: '2', name: 'Lightning Bolt'),
      ];

      final result = CollectionListController.filterAndSort(
        cards: cards,
        fullCardData: scryfallData,
        filterQuery: '',
        activeFilters: const SearchFilters(),
      );

      expect(result.length, 2);
    });
  });

  // =================================================================
  // filterAndSort - Filtre par tags
  // =================================================================

  group('filterAndSort - filter by tags', () {
    test('filters cards by tags (all tags must match)', () {
      final cards = [
        _makeDeckCard(scryfallId: '1', name: 'Sol Ring', tags: ['Ramp', 'Mana Rock']),
        _makeDeckCard(scryfallId: '2', name: 'Lightning Bolt', tags: ['Removal']),
        _makeDeckCard(scryfallId: '3', name: 'Arcane Signet', tags: ['Ramp', 'Mana Rock']),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Sol Ring'),
        _makeScryfallCard(id: '2', name: 'Lightning Bolt'),
        _makeScryfallCard(id: '3', name: 'Arcane Signet'),
      ];

      final result = CollectionListController.filterAndSort(
        cards: cards,
        fullCardData: scryfallData,
        filterQuery: '',
        activeFilters: const SearchFilters(tags: {'Ramp'}),
      );

      expect(result.length, 2);
      expect(result[0].name, 'Arcane Signet');
      expect(result[1].name, 'Sol Ring');
    });
  });

  // =================================================================
  // filterAndSort - Filtre par type de carte
  // =================================================================

  group('filterAndSort - filter by card type', () {
    test('filters cards by type line', () {
      final cards = [
        _makeDeckCard(scryfallId: '1', name: 'Sol Ring'),
        _makeDeckCard(scryfallId: '2', name: 'Lightning Bolt'),
        _makeDeckCard(scryfallId: '3', name: 'Llanowar Elves'),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Sol Ring', typeLine: 'Artifact'),
        _makeScryfallCard(id: '2', name: 'Lightning Bolt', typeLine: 'Instant'),
        _makeScryfallCard(id: '3', name: 'Llanowar Elves', typeLine: 'Creature - Elf Druid'),
      ];

      final result = CollectionListController.filterAndSort(
        cards: cards,
        fullCardData: scryfallData,
        filterQuery: '',
        activeFilters: const SearchFilters(cardType: 'Creature'),
      );

      expect(result.length, 1);
      expect(result[0].name, 'Llanowar Elves');
    });
  });

  // =================================================================
  // filterAndSort - Tri
  // =================================================================

  group('filterAndSort - sorting', () {
    test('sorts by name ascending by default', () {
      final cards = [
        _makeDeckCard(scryfallId: '2', name: 'Zebra Card'),
        _makeDeckCard(scryfallId: '1', name: 'Alpha Card'),
        _makeDeckCard(scryfallId: '3', name: 'Middle Card'),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Alpha Card'),
        _makeScryfallCard(id: '2', name: 'Zebra Card'),
        _makeScryfallCard(id: '3', name: 'Middle Card'),
      ];

      final result = CollectionListController.filterAndSort(
        cards: cards,
        fullCardData: scryfallData,
        filterQuery: '',
        activeFilters: const SearchFilters(sortType: 'name', sortAscending: true),
      );

      expect(result[0].name, 'Alpha Card');
      expect(result[1].name, 'Middle Card');
      expect(result[2].name, 'Zebra Card');
    });

    test('sorts by price ascending', () {
      final cards = [
        _makeDeckCard(scryfallId: '1', name: 'Cheap Card'),
        _makeDeckCard(scryfallId: '2', name: 'Expensive Card'),
        _makeDeckCard(scryfallId: '3', name: 'Mid Card'),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Cheap Card', eurPrice: '1.00'),
        _makeScryfallCard(id: '2', name: 'Expensive Card', eurPrice: '50.00'),
        _makeScryfallCard(id: '3', name: 'Mid Card', eurPrice: '10.00'),
      ];

      final result = CollectionListController.filterAndSort(
        cards: cards,
        fullCardData: scryfallData,
        filterQuery: '',
        activeFilters: const SearchFilters(sortType: 'price', sortAscending: true),
      );

      expect(result[0].name, 'Cheap Card');
      expect(result[1].name, 'Mid Card');
      expect(result[2].name, 'Expensive Card');
    });

    test('sorts by price descending', () {
      final cards = [
        _makeDeckCard(scryfallId: '1', name: 'Cheap Card'),
        _makeDeckCard(scryfallId: '2', name: 'Expensive Card'),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Cheap Card', eurPrice: '1.00'),
        _makeScryfallCard(id: '2', name: 'Expensive Card', eurPrice: '50.00'),
      ];

      final result = CollectionListController.filterAndSort(
        cards: cards,
        fullCardData: scryfallData,
        filterQuery: '',
        activeFilters: const SearchFilters(sortType: 'price', sortAscending: false),
      );

      expect(result[0].name, 'Expensive Card');
      expect(result[1].name, 'Cheap Card');
    });

    test('sorts by cmc ascending', () {
      final cards = [
        _makeDeckCard(scryfallId: '1', name: 'High CMC'),
        _makeDeckCard(scryfallId: '2', name: 'Low CMC'),
        _makeDeckCard(scryfallId: '3', name: 'Mid CMC'),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'High CMC', cmc: 7.0),
        _makeScryfallCard(id: '2', name: 'Low CMC', cmc: 1.0),
        _makeScryfallCard(id: '3', name: 'Mid CMC', cmc: 3.0),
      ];

      final result = CollectionListController.filterAndSort(
        cards: cards,
        fullCardData: scryfallData,
        filterQuery: '',
        activeFilters: const SearchFilters(sortType: 'cmc', sortAscending: true),
      );

      expect(result[0].name, 'Low CMC');
      expect(result[1].name, 'Mid CMC');
      expect(result[2].name, 'High CMC');
    });
  });

  // =================================================================
  // getPrice
  // =================================================================

  group('getPrice', () {
    test('returns correct EUR price for non-foil card', () {
      final card = _makeDeckCard(scryfallId: '1', name: 'Sol Ring');
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Sol Ring', eurPrice: '2.50', eurFoilPrice: '15.00'),
      ];

      final price = CollectionListController.getPrice(card, scryfallData);
      expect(price, 2.50);
    });

    test('returns foil price for foil card', () {
      final card = _makeDeckCard(scryfallId: '1', name: 'Sol Ring', isFoil: true);
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Sol Ring', eurPrice: '2.50', eurFoilPrice: '15.00'),
      ];

      final price = CollectionListController.getPrice(card, scryfallData);
      expect(price, 15.00);
    });

    test('returns 0.0 for unknown card', () {
      final card = _makeDeckCard(scryfallId: 'unknown', name: 'Missing Card');
      final scryfallData = <ScryfallCard>[];

      final price = CollectionListController.getPrice(card, scryfallData);
      expect(price, 0.0);
    });

    test('isFoil parameter overrides card.isFoil', () {
      final card = _makeDeckCard(scryfallId: '1', name: 'Sol Ring', isFoil: false);
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Sol Ring', eurPrice: '2.50', eurFoilPrice: '15.00'),
      ];

      final price = CollectionListController.getPrice(card, scryfallData, isFoil: true);
      expect(price, 15.00);
    });
  });

  // =================================================================
  // getRarityColor
  // =================================================================

  group('getRarityColor', () {
    test('returns correct color for common', () {
      final color = CollectionListController.getRarityColor('common');
      expect(color, const Color(0x3DFFFFFF));
    });

    test('returns correct color for uncommon', () {
      final color = CollectionListController.getRarityColor('uncommon');
      expect(color, const Color(0xFFC0C0C0));
    });

    test('returns correct color for rare', () {
      final color = CollectionListController.getRarityColor('rare');
      expect(color, const Color(0xFFFFD700));
    });

    test('returns correct color for mythic', () {
      final color = CollectionListController.getRarityColor('mythic');
      expect(color, const Color(0xFFFF4500));
    });

    test('is case insensitive', () {
      expect(
        CollectionListController.getRarityColor('RARE'),
        CollectionListController.getRarityColor('rare'),
      );
    });

    test('returns transparent for unknown rarity', () {
      final color = CollectionListController.getRarityColor('unknown');
      expect(color, const Color(0x00000000));
    });
  });

  // =================================================================
  // calculateTopCards
  // =================================================================

  group('calculateTopCards', () {
    test('returns top cards sorted by total price descending', () {
      final cards = [
        _makeDeckCard(scryfallId: '1', name: 'Cheap Card', quantity: 1),
        _makeDeckCard(scryfallId: '2', name: 'Expensive Card', quantity: 2),
        _makeDeckCard(scryfallId: '3', name: 'Mid Card', quantity: 1),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Cheap Card', eurPrice: '1.00'),
        _makeScryfallCard(id: '2', name: 'Expensive Card', eurPrice: '25.00'),
        _makeScryfallCard(id: '3', name: 'Mid Card', eurPrice: '10.00'),
      ];

      final top = CollectionListController.calculateTopCards(
        cards: cards,
        fullCardData: scryfallData,
        count: 15,
      );

      expect(top.length, 3);
      expect(top[0]['name'], 'Expensive Card');
      expect(top[0]['totalPrice'], 50.0); // 25 * 2
      expect(top[1]['name'], 'Mid Card');
      expect(top[1]['totalPrice'], 10.0);
      expect(top[2]['name'], 'Cheap Card');
      expect(top[2]['totalPrice'], 1.0);
    });

    test('limits results to count parameter', () {
      final cards = List.generate(20, (i) => _makeDeckCard(
        scryfallId: 'id-$i',
        name: 'Card $i',
        quantity: 1,
      ));
      final scryfallData = List.generate(20, (i) => _makeScryfallCard(
        id: 'id-$i',
        name: 'Card $i',
        eurPrice: '${i + 1}.00',
      ));

      final top = CollectionListController.calculateTopCards(
        cards: cards,
        fullCardData: scryfallData,
        count: 5,
      );

      expect(top.length, 5);
    });

    test('skips LOCAL: cards', () {
      final cards = [
        _makeDeckCard(scryfallId: 'LOCAL:Unknown', name: 'Unknown Card', quantity: 1),
        _makeDeckCard(scryfallId: '1', name: 'Known Card', quantity: 1),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Known Card', eurPrice: '5.00'),
      ];

      final top = CollectionListController.calculateTopCards(
        cards: cards,
        fullCardData: scryfallData,
      );

      expect(top.length, 1);
      expect(top[0]['name'], 'Known Card');
    });

    test('skips cards with zero price', () {
      final cards = [
        _makeDeckCard(scryfallId: '1', name: 'Free Card', quantity: 1),
        _makeDeckCard(scryfallId: '2', name: 'Priced Card', quantity: 1),
      ];
      final scryfallData = [
        _makeScryfallCard(id: '1', name: 'Free Card', eurPrice: '0'),
        _makeScryfallCard(id: '2', name: 'Priced Card', eurPrice: '3.00'),
      ];

      final top = CollectionListController.calculateTopCards(
        cards: cards,
        fullCardData: scryfallData,
      );

      expect(top.length, 1);
      expect(top[0]['name'], 'Priced Card');
    });
  });
}
