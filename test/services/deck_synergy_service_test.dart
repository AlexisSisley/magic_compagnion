// Tests unitaires pour DeckSynergyService.
// Teste generateSynergyReport et detectCombos en isolation (fonctions pures).

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/edhrec_models.dart';
import 'package:magic_companion/services/deck_synergy_service.dart';

// --- Helpers ---

Deck _makeTestDeck({
  String id = 'deck-1',
  String name = 'Test Deck',
  String format = 'Commander',
  List<DeckCard>? mainboard,
  List<DeckCard>? sideboard,
  String? commanderScryfallId,
}) {
  return Deck(
    id: id,
    name: name,
    format: format,
    mainboard: mainboard,
    sideboard: sideboard,
    commanderScryfallId: commanderScryfallId,
  );
}

void main() {
  // ============================================================
  // generateSynergyReport
  // ============================================================

  group('DeckSynergyService.generateSynergyReport', () {
    test('returns null when commanderScryfallId is null', () {
      final deck = _makeTestDeck(commanderScryfallId: null);
      final report = DeckSynergyService.generateSynergyReport(
        edhrecData: EdhrecCommanderData.empty,
        deck: deck,
        commanderScryfallId: null,
      );
      expect(report, isNull);
    });

    test('computes correct global score for matching cards', () {
      final deck = _makeTestDeck(
        commanderScryfallId: 'cmd-1',
        mainboard: [
          DeckCard(scryfallId: 'cmd-1', name: 'Atraxa', quantity: 1),
          DeckCard(scryfallId: 'c1', name: 'Sword of Truth', quantity: 1),
          DeckCard(scryfallId: 'c2', name: 'Sol Ring', quantity: 1),
        ],
      );

      const edhrecData = EdhrecCommanderData(
        categorizedSuggestions: {
          'Haute Synergie': [
            EdhrecCardSuggestion(
              name: 'Sword of Truth',
              sanitized: 'sword',
              synergy: 0.35,
              inclusion: 45,
              numDecks: 5000,
              potentialDecks: 12000,
            ),
          ],
          'Top Cartes': [
            EdhrecCardSuggestion(
              name: 'Sol Ring',
              sanitized: 'sol-ring',
              synergy: -0.05,
              inclusion: 98,
              numDecks: 150000,
              potentialDecks: 155000,
            ),
          ],
        },
        themes: [],
        topCombos: [],
        totalDecks: 12000,
      );

      final report = DeckSynergyService.generateSynergyReport(
        edhrecData: edhrecData,
        deck: deck,
        commanderScryfallId: 'cmd-1',
      );

      expect(report, isNotNull);
      expect(report!.cardsWithSynergyData, 2);
      expect(report.totalDeckCards, 3);
      // avg synergy = (0.35 + (-0.05)) / 2 = 0.15
      // global = ((0.15 + 1) / 2) * 100 = 57.5
      expect(report.globalScore, closeTo(57.5, 0.5));
    });

    test('handles no matching cards (score = 50)', () {
      final deck = _makeTestDeck(
        commanderScryfallId: 'cmd-1',
        mainboard: [
          DeckCard(scryfallId: 'cmd-1', name: 'Atraxa', quantity: 1),
          DeckCard(scryfallId: 'c1', name: 'Random Card', quantity: 1),
        ],
      );

      const edhrecData = EdhrecCommanderData(
        categorizedSuggestions: {
          'Top': [
            EdhrecCardSuggestion(
              name: 'Other Card',
              sanitized: 'other',
              synergy: 0.10,
              inclusion: 50,
              numDecks: 1000,
              potentialDecks: 10000,
            ),
          ],
        },
        themes: [],
        topCombos: [],
        totalDecks: 10000,
      );

      final report = DeckSynergyService.generateSynergyReport(
        edhrecData: edhrecData,
        deck: deck,
        commanderScryfallId: 'cmd-1',
      );

      expect(report, isNotNull);
      expect(report!.cardsWithSynergyData, 0);
      expect(report.globalScore, 50.0);
    });

    test('computes averageSalt correctly', () {
      final deck = _makeTestDeck(
        commanderScryfallId: 'cmd-1',
        mainboard: [
          DeckCard(scryfallId: 'cmd-1', name: 'Atraxa', quantity: 1),
          DeckCard(scryfallId: 'c1', name: 'Rhystic Study', quantity: 1),
          DeckCard(scryfallId: 'c2', name: 'Sol Ring', quantity: 1),
        ],
      );

      const edhrecData = EdhrecCommanderData(
        categorizedSuggestions: {
          'Top': [
            EdhrecCardSuggestion(
              name: 'Rhystic Study',
              sanitized: 'rhystic-study',
              synergy: 0.10,
              inclusion: 85,
              numDecks: 120000,
              potentialDecks: 140000,
              salt: 2.73,
            ),
            EdhrecCardSuggestion(
              name: 'Sol Ring',
              sanitized: 'sol-ring',
              synergy: -0.05,
              inclusion: 98,
              numDecks: 150000,
              potentialDecks: 155000,
              salt: 0.0,
            ),
          ],
        },
        themes: [],
        topCombos: [],
        totalDecks: 155000,
      );

      final report = DeckSynergyService.generateSynergyReport(
        edhrecData: edhrecData,
        deck: deck,
        commanderScryfallId: 'cmd-1',
      );

      expect(report, isNotNull);
      // Only Rhystic Study has salt != 0 -> averageSalt = 2.73 / 1 = 2.73
      expect(report!.averageSalt, closeTo(2.73, 0.01));
    });

    test('includes sideboard cards in analysis', () {
      final deck = _makeTestDeck(
        commanderScryfallId: 'cmd-1',
        mainboard: [
          DeckCard(scryfallId: 'cmd-1', name: 'Atraxa', quantity: 1),
        ],
        sideboard: [
          DeckCard(scryfallId: 'c1', name: 'Sol Ring', quantity: 1),
        ],
      );

      const edhrecData = EdhrecCommanderData(
        categorizedSuggestions: {
          'Top': [
            EdhrecCardSuggestion(
              name: 'Sol Ring',
              sanitized: 'sol-ring',
              synergy: -0.05,
              inclusion: 98,
              numDecks: 150000,
              potentialDecks: 155000,
            ),
          ],
        },
        themes: [],
        topCombos: [],
        totalDecks: 155000,
      );

      final report = DeckSynergyService.generateSynergyReport(
        edhrecData: edhrecData,
        deck: deck,
        commanderScryfallId: 'cmd-1',
      );

      expect(report, isNotNull);
      expect(report!.cardsWithSynergyData, 1);
    });
  });

  // ============================================================
  // detectCombos
  // ============================================================

  group('DeckSynergyService.detectCombos', () {
    test('detects complete combo (all cards in deck)', () {
      final deck = _makeTestDeck(
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Exquisite Blood', quantity: 1),
          DeckCard(scryfallId: 'c2', name: 'Sanguine Bond', quantity: 1),
        ],
      );

      final combos = [
        const EdhrecCombo(
          comboId: 1,
          name: 'Exquisite Blood + Sanguine Bond',
          cardNames: ['Exquisite Blood', 'Sanguine Bond'],
          results: ['Infinite damage'],
          colors: 'B',
          deckCount: 18340,
          percentage: 1.07,
          rank: 1,
        ),
      ];

      final results = DeckSynergyService.detectCombos(combos: combos, deck: deck);

      expect(results, hasLength(1));
      expect(results[0].completeness, ComboCompleteness.complete);
      expect(results[0].cardsInDeck, hasLength(2));
      expect(results[0].cardsMissing, isEmpty);
    });

    test('detects partial combo (some cards missing)', () {
      final deck = _makeTestDeck(
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Exquisite Blood', quantity: 1),
        ],
      );

      final combos = [
        const EdhrecCombo(
          comboId: 1,
          name: 'Exquisite Blood + Sanguine Bond',
          cardNames: ['Exquisite Blood', 'Sanguine Bond'],
          results: ['Infinite damage'],
          colors: 'B',
          deckCount: 18340,
          percentage: 1.07,
          rank: 1,
        ),
      ];

      final results = DeckSynergyService.detectCombos(combos: combos, deck: deck);

      expect(results, hasLength(1));
      expect(results[0].completeness, ComboCompleteness.partial);
      expect(results[0].cardsInDeck, ['Exquisite Blood']);
      expect(results[0].cardsMissing, ['Sanguine Bond']);
    });

    test('detects none combo (no cards in deck)', () {
      final deck = _makeTestDeck(
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Random Card', quantity: 1),
        ],
      );

      final combos = [
        const EdhrecCombo(
          comboId: 1,
          name: 'Card A + Card B',
          cardNames: ['Card A', 'Card B'],
          results: [],
          colors: 'W',
          deckCount: 5000,
          percentage: 0.5,
          rank: 3,
        ),
      ];

      final results = DeckSynergyService.detectCombos(combos: combos, deck: deck);

      expect(results, hasLength(1));
      expect(results[0].completeness, ComboCompleteness.none);
    });

    test('sorts combos: complete > partial > none', () {
      final deck = _makeTestDeck(
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Card A', quantity: 1),
          DeckCard(scryfallId: 'c2', name: 'Card B', quantity: 1),
          DeckCard(scryfallId: 'c3', name: 'Card X', quantity: 1),
        ],
      );

      final combos = [
        const EdhrecCombo(
          comboId: 1,
          name: 'None Combo',
          cardNames: ['Card Z', 'Card W'],
          results: [],
          colors: 'R',
          deckCount: 20000,
          percentage: 2.0,
          rank: 1,
        ),
        const EdhrecCombo(
          comboId: 2,
          name: 'Complete Combo',
          cardNames: ['Card A', 'Card B'],
          results: ['Win'],
          colors: 'G',
          deckCount: 5000,
          percentage: 0.5,
          rank: 3,
        ),
        const EdhrecCombo(
          comboId: 3,
          name: 'Partial Combo',
          cardNames: ['Card X', 'Card Y'],
          results: [],
          colors: 'U',
          deckCount: 10000,
          percentage: 1.0,
          rank: 2,
        ),
      ];

      final results = DeckSynergyService.detectCombos(combos: combos, deck: deck);

      expect(results, hasLength(3));
      expect(results[0].completeness, ComboCompleteness.complete);
      expect(results[1].completeness, ComboCompleteness.partial);
      expect(results[2].completeness, ComboCompleteness.none);
    });

    test('returns empty list for empty combos input', () {
      final deck = _makeTestDeck(
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Card A', quantity: 1),
        ],
      );

      final results = DeckSynergyService.detectCombos(combos: [], deck: deck);
      expect(results, isEmpty);
    });
  });
}
