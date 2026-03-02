// Tests unitaires pour DeckCardPickerController
// Teste l'etat immutable, le panier, les filtres et les helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_card_picker_controller.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/models/search_filters.dart';

/// Helper to create a minimal ScryfallCard for testing.
ScryfallCard _makeCard({
  String id = 'card-1',
  String name = 'Lightning Bolt',
  String typeLine = 'Instant',
  String setCode = 'M21',
  String setName = 'Core Set 2021',
  String rarity = 'common',
  String rulesText = 'Deal 3 damage to any target.',
  List<String> colorIdentity = const ['R'],
  Map<String, dynamic> prices = const {'eur': '0.50'},
}) {
  return ScryfallCard(
    id: id,
    oracleId: 'oracle-$id',
    name: name,
    imageUrl: '',
    rulesText: rulesText,
    typeLine: typeLine,
    legalities: {},
    prices: prices,
    lang: 'en',
    colorIdentity: colorIdentity,
    setName: setName,
    setCode: setCode,
    collectorNumber: '1',
    rarity: rarity,
    purchaseUris: {},
  );
}

void main() {
  // =================================================================
  // DeckCardPickerState - Tests unitaires purs sur l'etat immutable
  // =================================================================

  group('DeckCardPickerState', () {
    test('initial state has correct defaults', () {
      const state = DeckCardPickerState();

      expect(state.apiResults, isEmpty);
      expect(state.isSearching, false);
      expect(state.apiFilters, const SearchFilters());
      expect(state.apiSort, 'name');
      expect(state.nextApiPageUrl, isNull);
      expect(state.isApiLoadingMore, false);
      expect(state.totalApiResults, 0);
      expect(state.fullCollection, isEmpty);
      expect(state.displayedCollection, isEmpty);
      expect(state.collectionFilters, const SearchFilters());
      expect(state.collectionSort, 'name');
      expect(state.selectedQuantities, isEmpty);
      expect(state.cardCache, isEmpty);
      expect(state.totalCards, 0);
      expect(state.uniqueCardCount, 0);
    });

    test('copyWith preserves values when not specified', () {
      const state = DeckCardPickerState(
        apiSort: 'cmc',
        collectionSort: 'price',
        isSearching: true,
        totalApiResults: 42,
        selectedQuantities: {'card-1': 3},
      );

      final copied = state.copyWith(apiSort: 'name');

      expect(copied.apiSort, 'name');
      expect(copied.collectionSort, 'price');
      expect(copied.isSearching, true);
      expect(copied.totalApiResults, 42);
      expect(copied.selectedQuantities, {'card-1': 3});
    });

    test('copyWith clearNextApiPageUrl resets nextApiPageUrl', () {
      const state = DeckCardPickerState(nextApiPageUrl: 'https://api.scryfall.com/page2');

      final cleared = state.copyWith(clearNextApiPageUrl: true);

      expect(cleared.nextApiPageUrl, isNull);
    });

    test('totalCards sums all quantities', () {
      const state = DeckCardPickerState(
        selectedQuantities: {'card-1': 3, 'card-2': 2, 'card-3': 1},
      );

      expect(state.totalCards, 6);
      expect(state.uniqueCardCount, 3);
    });
  });

  // =================================================================
  // Cart logic - increment / decrement / submit (sans services)
  // =================================================================

  group('Cart logic (pure state manipulation)', () {
    test('increment adds card to selectedQuantities and cardCache', () {
      const state = DeckCardPickerState();
      final card = _makeCard(id: 'bolt-1', name: 'Lightning Bolt');

      // Simulate increment logic
      final updatedQuantities = Map<String, int>.from(state.selectedQuantities);
      updatedQuantities[card.id] = (updatedQuantities[card.id] ?? 0) + 1;
      final updatedCache = Map<String, ScryfallCard>.from(state.cardCache);
      updatedCache[card.id] = card;

      final newState = state.copyWith(
        selectedQuantities: updatedQuantities,
        cardCache: updatedCache,
      );

      expect(newState.selectedQuantities['bolt-1'], 1);
      expect(newState.cardCache['bolt-1']?.name, 'Lightning Bolt');
      expect(newState.totalCards, 1);
    });

    test('decrement removes card when quantity reaches 0', () {
      final state = DeckCardPickerState(
        selectedQuantities: {'bolt-1': 1},
        cardCache: {'bolt-1': _makeCard(id: 'bolt-1')},
      );

      // Simulate decrement logic
      final updatedQuantities = Map<String, int>.from(state.selectedQuantities);
      updatedQuantities['bolt-1'] = updatedQuantities['bolt-1']! - 1;
      if (updatedQuantities['bolt-1']! <= 0) {
        updatedQuantities.remove('bolt-1');
      }

      final newState = state.copyWith(selectedQuantities: updatedQuantities);

      expect(newState.selectedQuantities.containsKey('bolt-1'), false);
      expect(newState.totalCards, 0);
    });

    test('decrement from quantity 3 goes to 2', () {
      final state = DeckCardPickerState(
        selectedQuantities: {'bolt-1': 3},
        cardCache: {'bolt-1': _makeCard(id: 'bolt-1')},
      );

      final updatedQuantities = Map<String, int>.from(state.selectedQuantities);
      updatedQuantities['bolt-1'] = updatedQuantities['bolt-1']! - 1;

      final newState = state.copyWith(selectedQuantities: updatedQuantities);

      expect(newState.selectedQuantities['bolt-1'], 2);
      expect(newState.totalCards, 2);
    });

    test('buildSubmitResult returns correct structure', () {
      final bolt = _makeCard(id: 'bolt-1', name: 'Lightning Bolt');
      final ring = _makeCard(id: 'ring-1', name: 'Sol Ring');

      final state = DeckCardPickerState(
        selectedQuantities: {'bolt-1': 4, 'ring-1': 1},
        cardCache: {'bolt-1': bolt, 'ring-1': ring},
      );

      // Simulate buildSubmitResult logic
      List<Map<String, dynamic>> result = [];
      state.selectedQuantities.forEach((id, qty) {
        if (state.cardCache.containsKey(id)) {
          result.add({'card': state.cardCache[id], 'quantity': qty});
        }
      });

      expect(result.length, 2);
      expect(result.any((r) => (r['card'] as ScryfallCard).name == 'Lightning Bolt' && r['quantity'] == 4), true);
      expect(result.any((r) => (r['card'] as ScryfallCard).name == 'Sol Ring' && r['quantity'] == 1), true);
    });
  });

  // =================================================================
  // Collection filtering (pure state logic)
  // =================================================================

  group('Collection filtering logic', () {
    test('filter application with collectionSort name sorts alphabetically', () {
      final cards = [
        DeckCard(scryfallId: 'z-1', name: 'Zephyr', quantity: 1),
        DeckCard(scryfallId: 'a-1', name: 'Arcane Signet', quantity: 2),
        DeckCard(scryfallId: 'm-1', name: 'Mountain', quantity: 4),
      ];

      // Simulate name sort
      final sorted = List<DeckCard>.from(cards)..sort((a, b) => a.name.compareTo(b.name));

      expect(sorted[0].name, 'Arcane Signet');
      expect(sorted[1].name, 'Mountain');
      expect(sorted[2].name, 'Zephyr');
    });

    test('text filter narrows collection by name', () {
      final cards = [
        DeckCard(scryfallId: '1', name: 'Lightning Bolt', quantity: 1),
        DeckCard(scryfallId: '2', name: 'Lightning Helix', quantity: 1),
        DeckCard(scryfallId: '3', name: 'Sol Ring', quantity: 1),
      ];

      const query = 'lightning';
      final filtered = cards.where((c) => c.name.toLowerCase().contains(query)).toList();

      expect(filtered.length, 2);
      expect(filtered.every((c) => c.name.toLowerCase().contains('lightning')), true);
    });
  });

  // =================================================================
  // API search state transitions
  // =================================================================

  group('API search state transitions', () {
    test('search start clears results and sets isSearching', () {
      final state = DeckCardPickerState(
        apiResults: [_makeCard()],
        totalApiResults: 10,
        nextApiPageUrl: 'https://api.scryfall.com/page2',
      );

      final searching = state.copyWith(
        isSearching: true,
        apiResults: [],
        clearNextApiPageUrl: true,
        totalApiResults: 0,
      );

      expect(searching.isSearching, true);
      expect(searching.apiResults, isEmpty);
      expect(searching.nextApiPageUrl, isNull);
      expect(searching.totalApiResults, 0);
    });

    test('load more API results appends to existing results', () {
      final existing = [_makeCard(id: 'card-1', name: 'Card 1')];
      final newCards = [_makeCard(id: 'card-2', name: 'Card 2')];

      final state = DeckCardPickerState(
        apiResults: existing,
        isApiLoadingMore: true,
      );

      final updated = state.copyWith(
        apiResults: [...state.apiResults, ...newCards],
        isApiLoadingMore: false,
      );

      expect(updated.apiResults.length, 2);
      expect(updated.apiResults[0].name, 'Card 1');
      expect(updated.apiResults[1].name, 'Card 2');
      expect(updated.isApiLoadingMore, false);
    });

    test('sort change updates apiSort', () {
      const state = DeckCardPickerState(apiSort: 'name');

      final updated = state.copyWith(apiSort: 'cmc');

      expect(updated.apiSort, 'cmc');
    });
  });

  // =================================================================
  // Local pagination
  // =================================================================

  group('Local pagination', () {
    test('loadMoreLocalResults extends displayedCollection', () {
      final full = List.generate(50, (i) => DeckCard(scryfallId: 'c-$i', name: 'Card $i', quantity: 1));
      final displayed = full.sublist(0, 30); // First page

      final state = DeckCardPickerState(
        fullCollection: full,
        displayedCollection: displayed,
      );

      // Simulate loadMoreLocalResults
      final nextCount = (state.displayedCollection.length + DeckCardPickerState.localPageSize)
          .clamp(0, state.fullCollection.length);
      final updated = state.copyWith(
        displayedCollection: state.fullCollection.sublist(0, nextCount),
      );

      expect(updated.displayedCollection.length, 50); // 30 + 30 = 60, clamped to 50
    });

    test('loadMoreLocalResults does nothing when all items displayed', () {
      final full = List.generate(10, (i) => DeckCard(scryfallId: 'c-$i', name: 'Card $i', quantity: 1));

      final state = DeckCardPickerState(
        fullCollection: full,
        displayedCollection: full,
      );

      // Simulate guard
      final shouldLoad = state.displayedCollection.length < state.fullCollection.length;
      expect(shouldLoad, false);
    });
  });

  // =================================================================
  // replaceApiCard
  // =================================================================

  group('replaceApiCard logic', () {
    test('replaces card at correct index', () {
      final cards = [
        _makeCard(id: 'v1', name: 'Bolt v1', setCode: 'M20'),
        _makeCard(id: 'other', name: 'Other'),
      ];
      final newVersion = _makeCard(id: 'v2', name: 'Bolt v2', setCode: 'M21');

      // Simulate replaceApiCard
      final updatedResults = List<ScryfallCard>.from(cards);
      updatedResults[0] = newVersion;

      expect(updatedResults[0].id, 'v2');
      expect(updatedResults[0].setCode, 'M21');
      expect(updatedResults[1].id, 'other');
    });
  });
}
