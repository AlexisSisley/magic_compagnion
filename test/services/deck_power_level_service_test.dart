// Tests unitaires pour DeckPowerLevelService.
// Teste estimatePowerLevel et les facteurs de calcul en isolation (fonctions pures).

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/edhrec_models.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/services/deck_power_level_service.dart';

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

ScryfallCard _makeCard({
  String id = 'c1',
  String name = 'Test Card',
  String typeLine = 'Creature',
  String rulesText = '',
  double? cmc,
}) {
  return ScryfallCard(
    id: id,
    oracleId: '',
    name: name,
    imageUrl: '',
    rulesText: rulesText,
    typeLine: typeLine,
    legalities: {},
    prices: {},
    lang: 'en',
    colorIdentity: [],
    setName: 'Test Set',
    setCode: 'TST',
    collectorNumber: '1',
    rarity: 'common',
    purchaseUris: {},
    cmc: cmc,
  );
}

void main() {
  // ============================================================
  // estimatePowerLevel
  // ============================================================

  group('DeckPowerLevelService.estimatePowerLevel', () {
    test('returns null when commanderScryfallId is null', () {
      final deck = _makeTestDeck(commanderScryfallId: null);
      final result = DeckPowerLevelService.estimatePowerLevel(
        deck: deck,
        fullCardData: [],
        commanderScryfallId: null,
      );
      expect(result, isNull);
    });

    test('returns default score 5 when fullCardData is empty', () {
      final deck = _makeTestDeck(commanderScryfallId: 'cmd-1');
      final result = DeckPowerLevelService.estimatePowerLevel(
        deck: deck,
        fullCardData: [],
        commanderScryfallId: 'cmd-1',
      );
      expect(result, isNotNull);
      expect(result!.score, 5);
      expect(result.label, 'Focused');
      expect(result.factors.length, 6);
    });

    test('produces a valid result with card data', () {
      final deck = _makeTestDeck(
        commanderScryfallId: 'cmd-1',
        mainboard: [
          DeckCard(scryfallId: 'cmd-1', name: 'Atraxa', quantity: 1),
          DeckCard(scryfallId: 'c1', name: 'Sol Ring', quantity: 1),
        ],
      );
      final cards = [
        _makeCard(id: 'cmd-1', name: 'Atraxa', typeLine: 'Legendary Creature', cmc: 4.0),
        _makeCard(id: 'c1', name: 'Sol Ring', typeLine: 'Artifact', rulesText: 'Add {C}{C}', cmc: 1.0),
      ];

      final result = DeckPowerLevelService.estimatePowerLevel(
        deck: deck,
        fullCardData: cards,
        commanderScryfallId: 'cmd-1',
      );
      expect(result, isNotNull);
      expect(result!.score, greaterThanOrEqualTo(1));
      expect(result.score, lessThanOrEqualTo(10));
      expect(result.label, DeckPowerLevel.labelForScore(result.score));
    });

    test('all factors are between 0.0 and 10.0', () {
      final deck = _makeTestDeck(
        commanderScryfallId: 'cmd-1',
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Lightning Bolt', quantity: 1),
        ],
      );
      final cards = [
        _makeCard(
          id: 'c1',
          name: 'Lightning Bolt',
          typeLine: 'Instant',
          rulesText: 'deals damage to any target',
          cmc: 1.0,
        ),
      ];

      final result = DeckPowerLevelService.estimatePowerLevel(
        deck: deck,
        fullCardData: cards,
        commanderScryfallId: 'cmd-1',
      );
      expect(result, isNotNull);
      for (final entry in result!.factors.entries) {
        expect(entry.value, greaterThanOrEqualTo(0.0),
            reason: '${entry.key} should be >= 0.0');
        expect(entry.value, lessThanOrEqualTo(10.0),
            reason: '${entry.key} should be <= 10.0');
      }
    });
  });

  // ============================================================
  // Individual factor calculations
  // ============================================================

  group('DeckPowerLevelService.calculateCmcScore', () {
    test('returns 5.0 for empty non-land cards', () {
      final cards = [
        _makeCard(typeLine: 'Land', cmc: 0.0),
      ];
      expect(DeckPowerLevelService.calculateCmcScore(cards), 5.0);
    });

    test('low CMC average gives high score', () {
      final cards = [
        _makeCard(id: 'a', typeLine: 'Creature', cmc: 1.0),
        _makeCard(id: 'b', typeLine: 'Instant', cmc: 1.0),
      ];
      // avg CMC = 1.0, score = ((4.0 - 1.0) / 2.0 * 9.0 + 1.0) = 14.5 -> clamped to 10.0
      expect(DeckPowerLevelService.calculateCmcScore(cards), 10.0);
    });

    test('high CMC average gives low score', () {
      final cards = [
        _makeCard(id: 'a', typeLine: 'Creature', cmc: 5.0),
        _makeCard(id: 'b', typeLine: 'Creature', cmc: 6.0),
      ];
      // avg CMC = 5.5, score = ((4.0 - 5.5) / 2.0 * 9.0 + 1.0) = -5.75 -> clamped to 1.0
      expect(DeckPowerLevelService.calculateCmcScore(cards), 1.0);
    });
  });

  group('DeckPowerLevelService.calculateInteractionScore', () {
    test('no interactions returns 1.0', () {
      final cards = [
        _makeCard(rulesText: 'Draw a card.'),
      ];
      expect(DeckPowerLevelService.calculateInteractionScore(cards), 1.0);
    });

    test('cards with interaction keywords count', () {
      final cards = [
        _makeCard(id: 'a', rulesText: 'Destroy target creature.'),
        _makeCard(id: 'b', rulesText: 'Exile target permanent.'),
        _makeCard(id: 'c', rulesText: 'Counter target spell.'),
      ];
      final score = DeckPowerLevelService.calculateInteractionScore(cards);
      expect(score, greaterThanOrEqualTo(1.0));
      expect(score, lessThanOrEqualTo(10.0));
    });
  });

  group('DeckPowerLevelService.calculateManaBaseScore', () {
    test('no lands returns 1.0', () {
      final cards = [
        _makeCard(typeLine: 'Creature'),
      ];
      expect(DeckPowerLevelService.calculateManaBaseScore(cards), 1.0);
    });

    test('non-basic lands increase score', () {
      final cards = [
        _makeCard(id: 'a', typeLine: 'Land', rulesText: ''),
        _makeCard(id: 'b', typeLine: 'Land', rulesText: ''),
        _makeCard(id: 'c', typeLine: 'Basic Land', rulesText: ''),
      ];
      final score = DeckPowerLevelService.calculateManaBaseScore(cards);
      // 2 out of 3 lands are non-basic (since 'Basic Land' is detected as basic)
      expect(score, greaterThan(1.0));
    });
  });
}
