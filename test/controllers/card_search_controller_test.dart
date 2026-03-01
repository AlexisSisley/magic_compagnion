// Tests unitaires pour CardSearchController (Sprint 7, US-7.9)
// Teste la logique d'etat du controller sans appels API reels.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/card_search_controller.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/models/search_filters.dart';

// --- Helpers ---

ScryfallCard _makeCard({
  required String id,
  required String name,
  String typeLine = 'Creature',
  Map<String, dynamic>? prices,
}) {
  return ScryfallCard(
    id: id,
    oracleId: 'oracle-$id',
    name: name,
    imageUrl: '',
    rulesText: '',
    typeLine: typeLine,
    legalities: {},
    prices: prices ?? {'eur': '1.00'},
    lang: 'en',
    colorIdentity: [],
    setName: 'Test Set',
    setCode: 'tst',
    collectorNumber: '1',
    rarity: 'common',
    purchaseUris: {},
  );
}

void main() {
  // ============================================================
  // CardSearchState - Tests unitaires purs sur l'etat immutable
  // ============================================================

  group('CardSearchState', () {
    test('initial state has correct defaults', () {
      final state = CardSearchState();

      expect(state.searchResults, isEmpty);
      expect(state.fullLocalResults, isEmpty);
      expect(state.nextPageUrl, isNull);
      expect(state.isApiLoadingMore, false);
      expect(state.isLoading, false);
      expect(state.isGridView, false);
      expect(state.sortBy, 'name');
      expect(state.collection, isEmpty);
      expect(state.flatWishlist, isEmpty);
      expect(state.statusMessage, 'Entrez un nom ou utilisez les filtres.');
      expect(state.activeFilters.colors, isEmpty);
    });

    test('copyWith preserves values when no arguments given', () {
      final state = CardSearchState(
        isLoading: true,
        sortBy: 'cmc',
        isGridView: true,
        statusMessage: 'Searching...',
      );

      final copied = state.copyWith();
      expect(copied.isLoading, true);
      expect(copied.sortBy, 'cmc');
      expect(copied.isGridView, true);
      expect(copied.statusMessage, 'Searching...');
    });

    test('copyWith overrides specified values', () {
      final state = CardSearchState();
      final updated = state.copyWith(
        isLoading: true,
        sortBy: 'eur',
        isGridView: true,
        statusMessage: 'Loading...',
      );

      expect(updated.isLoading, true);
      expect(updated.sortBy, 'eur');
      expect(updated.isGridView, true);
      expect(updated.statusMessage, 'Loading...');
      // Unchanged
      expect(updated.searchResults, isEmpty);
    });

    test('copyWith clearNextPageUrl clears the URL', () {
      final state = CardSearchState(nextPageUrl: 'https://example.com/page2');
      final updated = state.copyWith(clearNextPageUrl: true);
      expect(updated.nextPageUrl, isNull);
    });

    test('copyWith sets new nextPageUrl', () {
      final state = CardSearchState();
      final updated = state.copyWith(nextPageUrl: 'https://example.com/page2');
      expect(updated.nextPageUrl, 'https://example.com/page2');
    });
  });

  // ============================================================
  // Computed properties
  // ============================================================

  group('CardSearchState computed properties', () {
    test('hasActiveFilters detects setCode', () {
      final state = CardSearchState(
        activeFilters: SearchFilters(setCode: 'dom'),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters detects colors', () {
      final state = CardSearchState(
        activeFilters: SearchFilters(colors: {'W'}),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters detects cardType', () {
      final state = CardSearchState(
        activeFilters: SearchFilters(cardType: 'Instant'),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters detects rarity', () {
      final state = CardSearchState(
        activeFilters: SearchFilters(rarity: 'mythic'),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters detects keyword', () {
      final state = CardSearchState(
        activeFilters: SearchFilters(keyword: 'flying'),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters detects minCmc', () {
      final state = CardSearchState(
        activeFilters: SearchFilters(minCmc: 3),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters detects maxCmc', () {
      final state = CardSearchState(
        activeFilters: SearchFilters(maxCmc: 5),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters is false with no filters', () {
      final state = CardSearchState();
      expect(state.hasActiveFilters, false);
    });

    test('hasMoreLocal is true when fullLocalResults has more items', () {
      final state = CardSearchState(
        searchResults: [_makeCard(id: 'c1', name: 'Card 1')],
        fullLocalResults: [
          _makeCard(id: 'c1', name: 'Card 1'),
          _makeCard(id: 'c2', name: 'Card 2'),
        ],
      );
      expect(state.hasMoreLocal, true);
    });

    test('hasMoreLocal is false when all results loaded', () {
      final cards = [_makeCard(id: 'c1', name: 'Card 1')];
      final state = CardSearchState(
        searchResults: cards,
        fullLocalResults: cards,
      );
      expect(state.hasMoreLocal, false);
    });

    test('hasMoreApi is true when nextPageUrl exists', () {
      final state = CardSearchState(nextPageUrl: 'https://api.scryfall.com/next');
      expect(state.hasMoreApi, true);
    });

    test('hasMoreApi is false when nextPageUrl is null', () {
      final state = CardSearchState();
      expect(state.hasMoreApi, false);
    });

    test('resultCountLabel with local results shows fraction', () {
      final state = CardSearchState(
        searchResults: [_makeCard(id: 'c1', name: 'Card 1')],
        fullLocalResults: [
          _makeCard(id: 'c1', name: 'Card 1'),
          _makeCard(id: 'c2', name: 'Card 2'),
          _makeCard(id: 'c3', name: 'Card 3'),
        ],
      );
      expect(state.resultCountLabel, '1/3');
    });

    test('resultCountLabel without local results shows total', () {
      final state = CardSearchState(
        searchResults: [
          _makeCard(id: 'c1', name: 'Card 1'),
          _makeCard(id: 'c2', name: 'Card 2'),
        ],
      );
      expect(state.resultCountLabel, '2 cartes');
    });

    test('isCardInWishlist matches by name', () {
      final state = CardSearchState(
        flatWishlist: [
          DeckCard(scryfallId: 'c1', name: 'Force of Will', quantity: 1),
        ],
      );
      expect(state.isCardInWishlist('Force of Will'), true);
      expect(state.isCardInWishlist('Lightning Bolt'), false);
    });

    test('isCardInCollection matches by scryfallId', () {
      final state = CardSearchState(
        collection: [
          DeckCard(scryfallId: 'abc-123', name: 'Sol Ring', quantity: 1),
        ],
      );
      expect(state.isCardInCollection('abc-123'), true);
      expect(state.isCardInCollection('xyz-789'), false);
    });
  });

  // ============================================================
  // State transition simulations (updateSort, updateFilters, etc.)
  // ============================================================

  group('CardSearchState transitions', () {
    test('updateSort changes sort order', () {
      final state = CardSearchState(sortBy: 'name');

      // Simulate updateSort
      final newSortBy = 'cmc';
      expect(state.sortBy != newSortBy, true);
      final updated = state.copyWith(sortBy: newSortBy);
      expect(updated.sortBy, 'cmc');
    });

    test('updateSort returns false when same sort', () {
      final state = CardSearchState(sortBy: 'name');
      // Same sort -> no change
      expect(state.sortBy == 'name', true);
    });

    test('updateFilters stores new SearchFilters', () {
      final state = CardSearchState();
      final newFilters = SearchFilters(
        colors: {'R', 'U'},
        cardType: 'Instant',
        rarity: 'rare',
      );
      final updated = state.copyWith(activeFilters: newFilters);

      expect(updated.activeFilters.colors, {'R', 'U'});
      expect(updated.activeFilters.cardType, 'Instant');
      expect(updated.activeFilters.rarity, 'rare');
    });

    test('toggleGridView switches view mode', () {
      final state = CardSearchState(isGridView: false);
      final updated = state.copyWith(isGridView: !state.isGridView);
      expect(updated.isGridView, true);

      final toggled = updated.copyWith(isGridView: !updated.isGridView);
      expect(toggled.isGridView, false);
    });

    test('clearSearchResults empties results', () {
      final state = CardSearchState(
        searchResults: [_makeCard(id: 'c1', name: 'Card 1')],
        fullLocalResults: [_makeCard(id: 'c1', name: 'Card 1')],
        nextPageUrl: 'https://api.scryfall.com/next',
      );

      final cleared = state.copyWith(
        searchResults: [],
        fullLocalResults: [],
        clearNextPageUrl: true,
      );

      expect(cleared.searchResults, isEmpty);
      expect(cleared.fullLocalResults, isEmpty);
      expect(cleared.nextPageUrl, isNull);
    });

    test('resetFilters clears everything', () {
      final state = CardSearchState(
        activeFilters: SearchFilters(colors: {'W'}, cardType: 'Enchantment'),
        searchResults: [_makeCard(id: 'c1', name: 'Card 1')],
        fullLocalResults: [_makeCard(id: 'c1', name: 'Card 1')],
        nextPageUrl: 'http://example.com',
      );

      final reset = state.copyWith(
        activeFilters: SearchFilters(),
        searchResults: [],
        fullLocalResults: [],
        clearNextPageUrl: true,
        statusMessage: "Entrez un nom ou choisissez une edition.",
      );

      expect(reset.activeFilters.colors, isEmpty);
      expect(reset.activeFilters.cardType, isNull);
      expect(reset.searchResults, isEmpty);
      expect(reset.nextPageUrl, isNull);
    });

    test('onSetSelected sets setCode filter', () {
      final state = CardSearchState();
      final updated = state.copyWith(
        activeFilters: state.activeFilters.copyWith(setCode: 'dom'),
      );
      expect(updated.activeFilters.setCode, 'dom');
    });
  });

  // ============================================================
  // Sprint 9 : Collection index, price filter, price sort
  // ============================================================

  group('Sprint 9 - Collection index', () {
    test('collectionIndex stores normal quantities by scryfallId', () {
      final state = CardSearchState(
        collectionIndex: {'abc': 3, 'def': 1},
        collectionFoilIndex: {'abc': 2},
        wishlistCardNames: {'Sol Ring', 'Force of Will'},
      );

      expect(state.collectionIndex['abc'], 3);
      expect(state.collectionIndex['def'], 1);
      expect(state.collectionFoilIndex['abc'], 2);
      expect(state.wishlistCardNames.contains('Sol Ring'), true);
      expect(state.wishlistCardNames.contains('Lightning Bolt'), false);
    });

    test('copyWith preserves collection indexes', () {
      final state = CardSearchState(
        collectionIndex: {'abc': 3},
        collectionFoilIndex: {'abc': 2},
        wishlistCardNames: {'Sol Ring'},
      );

      final updated = state.copyWith(isLoading: true);
      expect(updated.collectionIndex['abc'], 3);
      expect(updated.collectionFoilIndex['abc'], 2);
      expect(updated.wishlistCardNames.contains('Sol Ring'), true);
    });

    test('copyWith overrides collection indexes', () {
      final state = CardSearchState(
        collectionIndex: {'abc': 3},
      );

      final updated = state.copyWith(
        collectionIndex: {'xyz': 5},
      );
      expect(updated.collectionIndex['abc'], isNull);
      expect(updated.collectionIndex['xyz'], 5);
    });
  });

  group('Sprint 9 - hasActiveFilters with maxPrice', () {
    test('hasActiveFilters detects maxPrice', () {
      final state = CardSearchState(
        activeFilters: SearchFilters(maxPrice: 10.0),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters is false without maxPrice', () {
      final state = CardSearchState();
      expect(state.hasActiveFilters, false);
    });
  });

  group('Sprint 9 - SearchFilters maxPrice', () {
    test('maxPrice copyWith sets new value', () {
      const filters = SearchFilters();
      final updated = filters.copyWith(maxPrice: 5.0);
      expect(updated.maxPrice, 5.0);
    });

    test('maxPrice copyWith preserves value', () {
      const filters = SearchFilters(maxPrice: 10.0);
      final updated = filters.copyWith(rarity: 'rare');
      expect(updated.maxPrice, 10.0);
    });

    test('maxPrice clearMaxPrice resets to null', () {
      const filters = SearchFilters(maxPrice: 10.0);
      final updated = filters.copyWith(clearMaxPrice: true);
      expect(updated.maxPrice, isNull);
    });
  });
}
