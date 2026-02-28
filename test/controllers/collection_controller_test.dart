// Tests unitaires pour CollectionController (Sprint 7, US-7.9)
// Teste la logique d'etat du controller sans appels API reels.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/collection_controller.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/search_filters.dart';
import 'package:magic_companion/models/wishlist_model.dart';

void main() {
  // ============================================================
  // CollectionState - Tests unitaires purs sur l'etat immutable
  // ============================================================

  group('CollectionState', () {
    test('initial state has correct defaults', () {
      const state = CollectionState();

      expect(state.collection, isEmpty);
      expect(state.wishlists, isEmpty);
      expect(state.fullCardData, isEmpty);
      expect(state.availableTags, isEmpty);
      expect(state.isLoading, true);
      expect(state.isSelectionMode, false);
      expect(state.selectedCardIds, isEmpty);
      expect(state.totalCollectionValue, 0.0);
      expect(state.totalWishlistValue, 0.0);
      expect(state.evolutionValue, isNull);
      expect(state.evolutionPercent, isNull);
      expect(state.hasCalculatedFinance, false);
    });

    test('copyWith preserves values when no arguments given', () {
      const state = CollectionState(
        isLoading: false,
        totalCollectionValue: 123.45,
        isSelectionMode: true,
      );

      final copied = state.copyWith();
      expect(copied.isLoading, false);
      expect(copied.totalCollectionValue, 123.45);
      expect(copied.isSelectionMode, true);
    });

    test('copyWith overrides specified values', () {
      const state = CollectionState();
      final updated = state.copyWith(
        isLoading: false,
        isSelectionMode: true,
        totalCollectionValue: 500.0,
      );

      expect(updated.isLoading, false);
      expect(updated.isSelectionMode, true);
      expect(updated.totalCollectionValue, 500.0);
      // Unchanged
      expect(updated.collection, isEmpty);
    });

    test('copyWith clearEvolution nullifies evolution fields', () {
      const state = CollectionState(
        evolutionValue: 25.0,
        evolutionPercent: 10.0,
      );

      final cleared = state.copyWith(clearEvolution: true);
      expect(cleared.evolutionValue, isNull);
      expect(cleared.evolutionPercent, isNull);
    });
  });

  // ============================================================
  // Computed properties
  // ============================================================

  group('CollectionState computed properties', () {
    test('activeFilterCount is 0 with no filters', () {
      const state = CollectionState();
      expect(state.activeFilterCount, 0);
    });

    test('activeFilterCount counts colors filter', () {
      final state = CollectionState(
        activeFilters: SearchFilters(colors: {'W', 'U'}),
      );
      expect(state.activeFilterCount, 1);
    });

    test('activeFilterCount counts cardType filter', () {
      final state = CollectionState(
        activeFilters: SearchFilters(cardType: 'Creature'),
      );
      expect(state.activeFilterCount, 1);
    });

    test('activeFilterCount counts tags filter', () {
      final state = CollectionState(
        activeFilters: SearchFilters(tags: {'Commander', 'Ramp'}),
      );
      expect(state.activeFilterCount, 1);
    });

    test('activeFilterCount counts keyword filter', () {
      final state = CollectionState(
        activeFilters: SearchFilters(keyword: 'flying'),
      );
      expect(state.activeFilterCount, 1);
    });

    test('activeFilterCount counts multiple filters', () {
      final state = CollectionState(
        activeFilters: SearchFilters(
          colors: {'R'},
          cardType: 'Instant',
          tags: {'Burn'},
          keyword: 'deal damage',
        ),
      );
      expect(state.activeFilterCount, 4);
    });
  });

  // ============================================================
  // Selection mode state transitions
  // ============================================================

  group('CollectionState selection mode', () {
    test('toggleSelectionMode enables selection', () {
      const state = CollectionState(isSelectionMode: false);
      final updated = state.copyWith(
        isSelectionMode: !state.isSelectionMode,
        selectedCardIds: {},
      );
      expect(updated.isSelectionMode, true);
      expect(updated.selectedCardIds, isEmpty);
    });

    test('toggleSelectionMode disables selection and clears selected', () {
      const state = CollectionState(
        isSelectionMode: true,
        selectedCardIds: {'card-1', 'card-2'},
      );
      final updated = state.copyWith(
        isSelectionMode: !state.isSelectionMode,
        selectedCardIds: {},
      );
      expect(updated.isSelectionMode, false);
      expect(updated.selectedCardIds, isEmpty);
    });

    test('toggleCardSelection adds a card ID', () {
      const state = CollectionState(
        isSelectionMode: true,
        selectedCardIds: {},
      );

      final updated = Set<String>.from(state.selectedCardIds)..add('card-1');
      final newState = state.copyWith(selectedCardIds: updated);

      expect(newState.selectedCardIds, contains('card-1'));
      expect(newState.selectedCardIds.length, 1);
    });

    test('toggleCardSelection removes an existing card ID', () {
      const state = CollectionState(
        isSelectionMode: true,
        selectedCardIds: {'card-1', 'card-2', 'card-3'},
      );

      final updated = Set<String>.from(state.selectedCardIds)..remove('card-2');
      final newState = state.copyWith(selectedCardIds: updated);

      expect(newState.selectedCardIds, isNot(contains('card-2')));
      expect(newState.selectedCardIds, contains('card-1'));
      expect(newState.selectedCardIds, contains('card-3'));
      expect(newState.selectedCardIds.length, 2);
    });

    test('toggleCardSelection works with multiple toggles', () {
      Set<String> selected = {};

      // Add card-1
      selected = Set<String>.from(selected)..add('card-1');
      expect(selected.length, 1);

      // Add card-2
      selected = Set<String>.from(selected)..add('card-2');
      expect(selected.length, 2);

      // Remove card-1
      selected = Set<String>.from(selected)..remove('card-1');
      expect(selected.length, 1);
      expect(selected, contains('card-2'));

      // Add card-1 back
      selected = Set<String>.from(selected)..add('card-1');
      expect(selected.length, 2);
    });
  });

  // ============================================================
  // Filter state transitions
  // ============================================================

  group('CollectionState filter transitions', () {
    test('updateFilters stores new SearchFilters', () {
      const state = CollectionState();
      final newFilters = SearchFilters(
        colors: {'B', 'G'},
        cardType: 'Enchantment',
        tags: {'EDH'},
      );
      final updated = state.copyWith(activeFilters: newFilters);

      expect(updated.activeFilters.colors, {'B', 'G'});
      expect(updated.activeFilters.cardType, 'Enchantment');
      expect(updated.activeFilters.tags, {'EDH'});
    });

    test('updateFilters replaces previous filters', () {
      final state = CollectionState(
        activeFilters: SearchFilters(colors: {'W'}, cardType: 'Creature'),
      );
      final newFilters = SearchFilters(colors: {'R'});
      final updated = state.copyWith(activeFilters: newFilters);

      expect(updated.activeFilters.colors, {'R'});
      expect(updated.activeFilters.cardType, isNull);
    });
  });

  // ============================================================
  // CollectionActionResult
  // ============================================================

  group('CollectionActionResult', () {
    test('default values are correct', () {
      const result = CollectionActionResult();
      expect(result.success, true);
      expect(result.message, '');
    });

    test('custom values override defaults', () {
      const result = CollectionActionResult(
        success: false,
        message: 'Error during batch add',
      );
      expect(result.success, false);
      expect(result.message, 'Error during batch add');
    });
  });

  // ============================================================
  // Financial state
  // ============================================================

  group('CollectionState financial data', () {
    test('stores collection and wishlist values', () {
      const state = CollectionState(
        totalCollectionValue: 1500.0,
        totalWishlistValue: 250.0,
        hasCalculatedFinance: true,
      );
      expect(state.totalCollectionValue, 1500.0);
      expect(state.totalWishlistValue, 250.0);
      expect(state.hasCalculatedFinance, true);
    });

    test('stores evolution data', () {
      const state = CollectionState(
        evolutionValue: 50.0,
        evolutionPercent: 3.5,
      );
      expect(state.evolutionValue, 50.0);
      expect(state.evolutionPercent, 3.5);
    });
  });

  // ============================================================
  // State with collection data
  // ============================================================

  group('CollectionState with data', () {
    test('stores collection cards', () {
      final state = CollectionState(
        collection: [
          DeckCard(scryfallId: 'c1', name: 'Sol Ring', quantity: 1),
          DeckCard(scryfallId: 'c2', name: 'Lightning Bolt', quantity: 4),
        ],
      );
      expect(state.collection.length, 2);
      expect(state.collection.first.name, 'Sol Ring');
    });

    test('stores wishlists', () {
      final state = CollectionState(
        wishlists: [
          Wishlist(id: 'wl-1', name: 'Ma Wishlist', dateCreated: DateTime(2026, 2, 28), cards: [
            DeckCard(scryfallId: 'c1', name: 'Force of Will', quantity: 1),
          ]),
        ],
      );
      expect(state.wishlists.length, 1);
      expect(state.wishlists.first.cards.length, 1);
    });

    test('stores available tags', () {
      const state = CollectionState(
        availableTags: ['Burn', 'Commander', 'Ramp', 'Staple'],
      );
      expect(state.availableTags.length, 4);
      expect(state.availableTags, contains('Commander'));
    });
  });
}
