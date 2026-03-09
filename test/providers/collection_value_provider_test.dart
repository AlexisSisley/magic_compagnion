// Test : lib/providers/collection_value_provider.dart (Sprint 14, US-14.2)

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/providers/collection_value_provider.dart';

void main() {
  group('CollectionValueState', () {
    test('valeurs par defaut', () {
      const state = CollectionValueState();
      expect(state.totalValueEur, 0);
      expect(state.totalValueFoilEur, 0);
      expect(state.grandTotalEur, 0);
      expect(state.totalCards, 0);
      expect(state.pricedCards, 0);
      expect(state.isLoading, true);
      expect(state.error, isNull);
      expect(state.lastUpdated, isNull);
    });

    test('copyWith met a jour les champs', () {
      const state = CollectionValueState();
      final updated = state.copyWith(
        totalValueEur: 100,
        totalValueFoilEur: 50,
        grandTotalEur: 150,
        totalCards: 10,
        pricedCards: 8,
        isLoading: false,
        lastUpdated: DateTime(2026, 1, 1),
      );
      expect(updated.totalValueEur, 100);
      expect(updated.totalValueFoilEur, 50);
      expect(updated.grandTotalEur, 150);
      expect(updated.totalCards, 10);
      expect(updated.pricedCards, 8);
      expect(updated.isLoading, false);
      expect(updated.error, isNull);
      expect(updated.lastUpdated, DateTime(2026, 1, 1));
    });

    test('copyWith preserve les champs non modifies', () {
      const state = CollectionValueState(
        totalValueEur: 100,
        isLoading: false,
        error: 'test error',
      );
      final updated = state.copyWith(totalValueFoilEur: 50);
      expect(updated.totalValueEur, 100);
      expect(updated.isLoading, false);
      expect(updated.totalValueFoilEur, 50);
      // error est reset a null par copyWith (par design)
    });

    test('copyWith peut effacer l\'erreur', () {
      const state = CollectionValueState(error: 'erreur');
      final updated = state.copyWith(error: null);
      expect(updated.error, isNull);
    });
  });
}
