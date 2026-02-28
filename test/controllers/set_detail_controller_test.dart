// Tests unitaires pour SetDetailController (Sprint 7, US-7.9)
// Teste la logique d'etat du controller sans appels API reels.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/set_detail_controller.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/models/search_filters.dart';

// --- Helpers ---

ScryfallCard _makeCard({
  required String id,
  required String name,
  String rarity = 'common',
  String collectorNumber = '1',
  List<String> colorIdentity = const [],
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
    colorIdentity: colorIdentity,
    setName: 'Test Set',
    setCode: 'tst',
    collectorNumber: collectorNumber,
    rarity: rarity,
    purchaseUris: {},
  );
}

void main() {
  // ============================================================
  // SetDetailState - Tests unitaires purs sur l'etat immutable
  // ============================================================

  group('SetDetailState', () {
    test('initial state has correct defaults', () {
      final state = SetDetailState();

      expect(state.isLoading, true);
      expect(state.allCards, isEmpty);
      expect(state.gridItems, isEmpty);
      expect(state.ownedKeys, isEmpty);
      expect(state.wishlistKeys, isEmpty);
      expect(state.selectedKeys, isEmpty);
      expect(state.searchQuery, '');
      expect(state.sortBy, 'number');
      expect(state.sortAsc, true);
      expect(state.hideOwned, false);
      expect(state.errorMessage, isNull);
      expect(state.rarityCounts, {'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0});
    });

    test('copyWith preserves values when no arguments given', () {
      final original = SetDetailState(
        allCards: [_makeCard(id: 'c1', name: 'Card 1')],
        isLoading: false,
        searchQuery: 'bolt',
        sortBy: 'name',
      );

      final copied = original.copyWith();

      expect(copied.allCards.length, 1);
      expect(copied.isLoading, false);
      expect(copied.searchQuery, 'bolt');
      expect(copied.sortBy, 'name');
    });

    test('copyWith overrides specified values', () {
      final state = SetDetailState();
      final updated = state.copyWith(
        isLoading: false,
        searchQuery: 'fire',
        sortBy: 'price',
      );

      expect(updated.isLoading, false);
      expect(updated.searchQuery, 'fire');
      expect(updated.sortBy, 'price');
      // Unchanged
      expect(updated.allCards, isEmpty);
      expect(updated.sortAsc, true);
    });

    test('computed totalSetCount returns allCards length', () {
      final state = SetDetailState(
        allCards: [
          _makeCard(id: 'c1', name: 'Card 1'),
          _makeCard(id: 'c2', name: 'Card 2'),
          _makeCard(id: 'c3', name: 'Card 3'),
        ],
      );
      expect(state.totalSetCount, 3);
    });

    test('computed totalOwnedUnique counts cards with owned keys', () {
      final state = SetDetailState(
        allCards: [
          _makeCard(id: 'c1', name: 'Card 1'),
          _makeCard(id: 'c2', name: 'Card 2'),
          _makeCard(id: 'c3', name: 'Card 3'),
        ],
        ownedKeys: {'c1|normal', 'c3|foil'},
      );
      expect(state.totalOwnedUnique, 2);
      expect(state.totalMissing, 1);
    });

    test('hasActiveFilters detects colors filter', () {
      final state = SetDetailState(
        activeFilters: SearchFilters(colors: {'R'}),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters detects cardType filter', () {
      final state = SetDetailState(
        activeFilters: SearchFilters(cardType: 'Creature'),
      );
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters detects hideOwned', () {
      final state = SetDetailState(hideOwned: true);
      expect(state.hasActiveFilters, true);
    });

    test('hasActiveFilters is false with no filters', () {
      final state = SetDetailState();
      expect(state.hasActiveFilters, false);
    });
  });

  // ============================================================
  // makeKey helper function tests
  // ============================================================

  group('makeKey', () {
    test('generates correct key for normal card', () {
      expect(makeKey('abc-123', false), 'abc-123|normal');
    });

    test('generates correct key for foil card', () {
      expect(makeKey('abc-123', true), 'abc-123|foil');
    });
  });

  // ============================================================
  // Selection logic tests (state manipulation only)
  // ============================================================

  group('SetDetailState selection logic', () {
    test('toggleSelection adds a key to selectedKeys', () {
      // Simulate what the controller does
      final state = SetDetailState(selectedKeys: <String>{});
      final key = makeKey('c1', false);
      final newSelected = Set<String>.from(state.selectedKeys)..add(key);
      final updated = state.copyWith(selectedKeys: newSelected);

      expect(updated.selectedKeys, contains('c1|normal'));
      expect(updated.selectedKeys.length, 1);
    });

    test('toggleSelection removes an existing key', () {
      final state = SetDetailState(selectedKeys: {'c1|normal', 'c2|foil'});
      final newSelected = Set<String>.from(state.selectedKeys)..remove('c1|normal');
      final updated = state.copyWith(selectedKeys: newSelected);

      expect(updated.selectedKeys, isNot(contains('c1|normal')));
      expect(updated.selectedKeys, contains('c2|foil'));
      expect(updated.selectedKeys.length, 1);
    });

    test('selectAllMissingFiltered adds unowned grid items', () {
      final card1 = _makeCard(id: 'c1', name: 'Card 1', prices: {'eur': '1.00'});
      final card2 = _makeCard(id: 'c2', name: 'Card 2', prices: {'eur': '2.00'});
      final card3 = _makeCard(id: 'c3', name: 'Card 3', prices: {'eur': '3.00'});

      final state = SetDetailState(
        gridItems: [
          SetCardDisplayItem(card1, false),
          SetCardDisplayItem(card2, false),
          SetCardDisplayItem(card3, false),
        ],
        ownedKeys: {'c2|normal'}, // c2 is owned
        selectedKeys: <String>{},
      );

      // Replicate selectAllMissingFiltered logic
      final newSelected = Set<String>.from(state.selectedKeys);
      for (var item in state.gridItems) {
        final key = makeKey(item.card.id, item.isFoil);
        if (!state.ownedKeys.contains(key)) newSelected.add(key);
      }
      final updated = state.copyWith(selectedKeys: newSelected);

      expect(updated.selectedKeys.length, 2);
      expect(updated.selectedKeys, contains('c1|normal'));
      expect(updated.selectedKeys, isNot(contains('c2|normal')));
      expect(updated.selectedKeys, contains('c3|normal'));
    });

    test('clearSelection empties selectedKeys', () {
      final state = SetDetailState(selectedKeys: {'c1|normal', 'c2|foil', 'c3|normal'});
      final updated = state.copyWith(selectedKeys: <String>{});
      expect(updated.selectedKeys, isEmpty);
    });
  });

  // ============================================================
  // SetCardDisplayItem tests
  // ============================================================

  group('SetCardDisplayItem', () {
    test('holds card and foil flag', () {
      final card = _makeCard(id: 'test', name: 'Test Card');
      final item = SetCardDisplayItem(card, true);

      expect(item.card.id, 'test');
      expect(item.card.name, 'Test Card');
      expect(item.isFoil, true);
    });
  });

  // ============================================================
  // SetDetailActionResult tests
  // ============================================================

  group('SetDetailActionResult', () {
    test('default values are correct', () {
      const result = SetDetailActionResult(count: 5);
      expect(result.count, 5);
      expect(result.success, true);
      expect(result.message, '');
    });

    test('custom values override defaults', () {
      const result = SetDetailActionResult(
        count: 0,
        success: false,
        message: 'Error occurred',
      );
      expect(result.count, 0);
      expect(result.success, false);
      expect(result.message, 'Error occurred');
    });
  });

  // ============================================================
  // Filter / sort state transition tests
  // ============================================================

  group('SetDetailState filter and sort transitions', () {
    test('updateSearchQuery stores query in state', () {
      final state = SetDetailState();
      final updated = state.copyWith(searchQuery: 'lightning');
      expect(updated.searchQuery, 'lightning');
    });

    test('updateSort toggles sortAsc when same sortBy', () {
      final state = SetDetailState(sortBy: 'name', sortAsc: true);
      // Same sort key -> toggle
      final updated = state.copyWith(sortAsc: !state.sortAsc);
      expect(updated.sortAsc, false);
      expect(updated.sortBy, 'name');
    });

    test('updateSort changes sortBy and resets sortAsc for new key', () {
      final state = SetDetailState(sortBy: 'number', sortAsc: false);
      final updated = state.copyWith(sortBy: 'price', sortAsc: true);
      expect(updated.sortBy, 'price');
      expect(updated.sortAsc, true);
    });

    test('updateFilters stores new SearchFilters', () {
      final state = SetDetailState();
      final newFilters = SearchFilters(colors: {'W', 'U'}, cardType: 'Instant');
      final updated = state.copyWith(activeFilters: newFilters);
      expect(updated.activeFilters.colors, {'W', 'U'});
      expect(updated.activeFilters.cardType, 'Instant');
    });

    test('updateHideOwned stores new value', () {
      final state = SetDetailState(hideOwned: false);
      final updated = state.copyWith(hideOwned: true);
      expect(updated.hideOwned, true);
    });
  });
}
