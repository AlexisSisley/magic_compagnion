// Tests unitaires pour les modeles EDHREC (Sprint 11, Phase 1).

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/edhrec_models.dart';

void main() {
  // ============================================================
  // EdhrecCardSuggestion
  // ============================================================

  group('EdhrecCardSuggestion', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'name': 'Sword of Truth and Justice',
        'sanitized': 'sword-of-truth-and-justice',
        'synergy': 0.35,
        'inclusion': 45,
        'num_decks': 5600,
        'potential_decks': 12000,
      };

      final card = EdhrecCardSuggestion.fromJson(json);

      expect(card.name, 'Sword of Truth and Justice');
      expect(card.sanitized, 'sword-of-truth-and-justice');
      expect(card.synergy, 0.35);
      expect(card.inclusion, 45);
      expect(card.numDecks, 5600);
      expect(card.potentialDecks, 12000);
    });

    test('fromJson handles null/missing fields gracefully', () {
      final json = <String, dynamic>{
        'name': null,
        // sanitized, synergy, inclusion, num_decks, potential_decks all missing
      };

      final card = EdhrecCardSuggestion.fromJson(json);

      expect(card.name, '');
      expect(card.sanitized, '');
      expect(card.synergy, 0.0);
      expect(card.inclusion, 0);
      expect(card.numDecks, 0);
      expect(card.potentialDecks, 0);
    });

    test('fromJson handles integer synergy (num cast)', () {
      final json = {
        'name': 'Sol Ring',
        'sanitized': 'sol-ring',
        'synergy': -1, // int, not double
        'inclusion': 98,
        'num_decks': 150000,
        'potential_decks': 155000,
      };

      final card = EdhrecCardSuggestion.fromJson(json);

      expect(card.synergy, -1.0);
      expect(card.inclusion, 98);
    });

    test('fromJson handles empty map', () {
      final card = EdhrecCardSuggestion.fromJson({});

      expect(card.name, '');
      expect(card.synergy, 0.0);
    });

    test('categoryLabel returns "Pick specifique" for high synergy', () {
      const card = EdhrecCardSuggestion(
        name: 'Sword',
        sanitized: 'sword',
        synergy: 0.35,
        inclusion: 45,
        numDecks: 5000,
        potentialDecks: 12000,
      );

      expect(card.categoryLabel, 'Pick specifique');
    });

    test('categoryLabel returns "Pick specifique" for synergy exactly 0.20', () {
      const card = EdhrecCardSuggestion(
        name: 'Card',
        sanitized: 'card',
        synergy: 0.20,
        inclusion: 30,
        numDecks: 1000,
        potentialDecks: 5000,
      );

      expect(card.categoryLabel, 'Pick specifique');
    });

    test('categoryLabel returns "Bonne synergie" for moderate synergy', () {
      const card = EdhrecCardSuggestion(
        name: 'Card',
        sanitized: 'card',
        synergy: 0.10,
        inclusion: 60,
        numDecks: 3000,
        potentialDecks: 10000,
      );

      expect(card.categoryLabel, 'Bonne synergie');
    });

    test('categoryLabel returns "Staple generique" for high inclusion + low synergy', () {
      const card = EdhrecCardSuggestion(
        name: 'Sol Ring',
        sanitized: 'sol-ring',
        synergy: -0.05,
        inclusion: 98,
        numDecks: 150000,
        potentialDecks: 155000,
      );

      expect(card.categoryLabel, 'Staple generique');
    });

    test('categoryLabel returns "Staple generique" for inclusion exactly 80 and synergy < 0.05', () {
      const card = EdhrecCardSuggestion(
        name: 'Arcane Signet',
        sanitized: 'arcane-signet',
        synergy: 0.02,
        inclusion: 80,
        numDecks: 100000,
        potentialDecks: 125000,
      );

      expect(card.categoryLabel, 'Staple generique');
    });

    test('categoryLabel returns "Standard" for average card', () {
      const card = EdhrecCardSuggestion(
        name: 'Random Card',
        sanitized: 'random-card',
        synergy: 0.01,
        inclusion: 40,
        numDecks: 2000,
        potentialDecks: 10000,
      );

      expect(card.categoryLabel, 'Standard');
    });

    test('categoryLabel returns "Standard" for negative synergy + low inclusion', () {
      const card = EdhrecCardSuggestion(
        name: 'Bad Card',
        sanitized: 'bad-card',
        synergy: -0.30,
        inclusion: 10,
        numDecks: 500,
        potentialDecks: 10000,
      );

      expect(card.categoryLabel, 'Standard');
    });
  });

  // ============================================================
  // Sprint 12 : Salt Score
  // ============================================================

  group('EdhrecCardSuggestion - Salt Score (Sprint 12)', () {
    test('fromJson parses salt field correctly', () {
      final json = {
        'name': 'Rhystic Study',
        'sanitized': 'rhystic-study',
        'synergy': 0.10,
        'inclusion': 85,
        'num_decks': 120000,
        'potential_decks': 140000,
        'salt': 2.73,
      };

      final card = EdhrecCardSuggestion.fromJson(json);
      expect(card.salt, 2.73);
    });

    test('fromJson defaults salt to 0.0 when absent', () {
      final json = {
        'name': 'Sol Ring',
        'sanitized': 'sol-ring',
        'synergy': -0.05,
        'inclusion': 98,
        'num_decks': 150000,
        'potential_decks': 155000,
      };

      final card = EdhrecCardSuggestion.fromJson(json);
      expect(card.salt, 0.0);
    });

    test('fromJson handles null salt gracefully', () {
      final json = {
        'name': 'Card',
        'sanitized': 'card',
        'salt': null,
      };

      final card = EdhrecCardSuggestion.fromJson(json);
      expect(card.salt, 0.0);
    });

    test('fromJson handles integer salt (num cast)', () {
      final json = {
        'name': 'Armageddon',
        'sanitized': 'armageddon',
        'salt': 3, // int, not double
      };

      final card = EdhrecCardSuggestion.fromJson(json);
      expect(card.salt, 3.0);
    });

    test('salt can be negative', () {
      final json = {
        'name': 'Nice Card',
        'sanitized': 'nice-card',
        'salt': -0.5,
      };

      final card = EdhrecCardSuggestion.fromJson(json);
      expect(card.salt, -0.5);
    });
  });

  // ============================================================
  // DeckSynergyReport - averageSalt (Sprint 12)
  // ============================================================

  group('DeckSynergyReport - averageSalt (Sprint 12)', () {
    test('averageSalt defaults to 0.0', () {
      const report = DeckSynergyReport(
        globalScore: 50.0,
        cardsWithSynergyData: 10,
        totalDeckCards: 99,
        cardScores: [],
      );
      expect(report.averageSalt, 0.0);
    });

    test('averageSalt stores correct value', () {
      const report = DeckSynergyReport(
        globalScore: 50.0,
        cardsWithSynergyData: 10,
        totalDeckCards: 99,
        cardScores: [],
        averageSalt: 1.85,
      );
      expect(report.averageSalt, 1.85);
    });
  });

  // ============================================================
  // CardSynergyEntry - salt (Sprint 12)
  // ============================================================

  group('CardSynergyEntry - salt (Sprint 12)', () {
    test('salt defaults to 0.0', () {
      const entry = CardSynergyEntry(
        cardName: 'Sol Ring',
        scryfallId: 'abc',
        synergy: -0.05,
        inclusion: 98,
        categoryLabel: 'Staple generique',
      );
      expect(entry.salt, 0.0);
    });

    test('salt stores correct value', () {
      const entry = CardSynergyEntry(
        cardName: 'Rhystic Study',
        scryfallId: 'xyz',
        synergy: 0.10,
        inclusion: 85,
        categoryLabel: 'Bonne synergie',
        salt: 2.73,
      );
      expect(entry.salt, 2.73);
    });
  });

  // ============================================================
  // EdhrecTheme
  // ============================================================

  group('EdhrecTheme', () {
    test('fromJson parses name, slug, and deckCount', () {
      final json = {
        'value': 'Infect',
        'href': '/themes/atraxa-praetors-voice/infect',
        'count': 6284,
      };

      final theme = EdhrecTheme.fromJson(json);

      expect(theme.name, 'Infect');
      expect(theme.slug, 'infect');
      expect(theme.deckCount, 6284);
    });

    test('fromJson uses "name" field if "value" is missing', () {
      final json = {
        'name': 'Voltron',
        'href': '/themes/sigarda/voltron',
        'count': 1200,
      };

      final theme = EdhrecTheme.fromJson(json);

      expect(theme.name, 'Voltron');
      expect(theme.slug, 'voltron');
    });

    test('fromJson handles empty href', () {
      final json = {
        'value': 'Unknown',
        'href': '',
        'count': 0,
      };

      final theme = EdhrecTheme.fromJson(json);

      expect(theme.name, 'Unknown');
      expect(theme.slug, '');
      expect(theme.deckCount, 0);
    });

    test('fromJson handles missing fields', () {
      final theme = EdhrecTheme.fromJson({});

      expect(theme.name, '');
      expect(theme.slug, '');
      expect(theme.deckCount, 0);
    });

    test('fromJson extracts slug from complex href', () {
      final json = {
        'value': '+1/+1 Counters',
        'href': '/themes/atraxa-praetors-voice/+1+1-counters',
        'count': 2790,
      };

      final theme = EdhrecTheme.fromJson(json);

      expect(theme.slug, '+1+1-counters');
      expect(theme.deckCount, 2790);
    });
  });

  // ============================================================
  // EdhrecCombo
  // ============================================================

  group('EdhrecCombo', () {
    test('fromJson parses combo with cardviews and results', () {
      final json = {
        'header': 'Exquisite Blood + Sanguine Bond',
        'cardviews': [
          {'name': 'Exquisite Blood'},
          {'name': 'Sanguine Bond'},
        ],
        'combo': {
          'comboId': 42,
          'results': ['Infinite damage', 'Win the game'],
          'colors': 'B',
          'count': 18340,
          'percentage': 1.07,
          'rank': 2,
        },
      };

      final combo = EdhrecCombo.fromJson(json);

      expect(combo.comboId, 42);
      expect(combo.name, 'Exquisite Blood + Sanguine Bond');
      expect(combo.cardNames, ['Exquisite Blood', 'Sanguine Bond']);
      expect(combo.results, ['Infinite damage', 'Win the game']);
      expect(combo.colors, 'B');
      expect(combo.deckCount, 18340);
      expect(combo.percentage, 1.07);
      expect(combo.rank, 2);
    });

    test('fromJson handles missing combo object', () {
      final json = {
        'header': 'Some Combo',
        'cardviews': [
          {'name': 'Card A'},
        ],
      };

      final combo = EdhrecCombo.fromJson(json);

      expect(combo.comboId, 0);
      expect(combo.name, 'Some Combo');
      expect(combo.cardNames, ['Card A']);
      expect(combo.results, isEmpty);
      expect(combo.colors, '');
    });

    test('fromJson handles missing cardviews', () {
      final json = {
        'combo': {
          'comboId': 1,
          'count': 100,
        },
      };

      final combo = EdhrecCombo.fromJson(json);

      expect(combo.cardNames, isEmpty);
      expect(combo.name, ''); // join of empty list
      expect(combo.deckCount, 100);
    });

    test('fromJson handles empty section', () {
      final combo = EdhrecCombo.fromJson({});

      expect(combo.comboId, 0);
      expect(combo.name, '');
      expect(combo.cardNames, isEmpty);
      expect(combo.results, isEmpty);
    });

    test('fromComboCount creates simplified combo', () {
      final json = {
        'name': 'Vraska + Vorinclex',
        'count': 24872,
      };

      final combo = EdhrecCombo.fromComboCount(json);

      expect(combo.name, 'Vraska + Vorinclex');
      expect(combo.cardNames, ['Vraska', 'Vorinclex']);
      expect(combo.deckCount, 24872);
      expect(combo.comboId, 0);
      expect(combo.results, isEmpty);
    });

    test('fromComboCount handles missing name', () {
      final combo = EdhrecCombo.fromComboCount({});

      expect(combo.name, '');
      expect(combo.cardNames, ['']);
      expect(combo.deckCount, 0);
    });
  });

  // ============================================================
  // EdhrecCommanderData
  // ============================================================

  group('EdhrecCommanderData', () {
    test('empty constant has all empty collections', () {
      expect(EdhrecCommanderData.empty.categorizedSuggestions, isEmpty);
      expect(EdhrecCommanderData.empty.themes, isEmpty);
      expect(EdhrecCommanderData.empty.topCombos, isEmpty);
      expect(EdhrecCommanderData.empty.totalDecks, 0);
    });

    test('isEmpty returns true for empty data', () {
      expect(EdhrecCommanderData.empty.isEmpty, true);
    });

    test('isEmpty returns false when suggestions exist', () {
      const data = EdhrecCommanderData(
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
        totalDecks: 10000,
      );

      expect(data.isEmpty, false);
    });

    test('isEmpty returns false when themes exist', () {
      const data = EdhrecCommanderData(
        categorizedSuggestions: {},
        themes: [
          EdhrecTheme(name: 'Infect', slug: 'infect', deckCount: 6000),
        ],
        topCombos: [],
        totalDecks: 10000,
      );

      expect(data.isEmpty, false);
    });
  });

  // ============================================================
  // DeckSynergyReport
  // ============================================================

  group('DeckSynergyReport', () {
    test('stores all properties correctly', () {
      const report = DeckSynergyReport(
        globalScore: 72.5,
        cardsWithSynergyData: 45,
        totalDeckCards: 99,
        cardScores: [
          CardSynergyEntry(
            cardName: 'Sol Ring',
            scryfallId: 'abc',
            synergy: -0.05,
            inclusion: 98,
            categoryLabel: 'Staple generique',
          ),
        ],
      );

      expect(report.globalScore, 72.5);
      expect(report.cardsWithSynergyData, 45);
      expect(report.totalDeckCards, 99);
      expect(report.cardScores, hasLength(1));
      expect(report.cardScores[0].cardName, 'Sol Ring');
    });
  });

  // ============================================================
  // CardSynergyEntry
  // ============================================================

  group('CardSynergyEntry', () {
    test('stores all properties correctly', () {
      const entry = CardSynergyEntry(
        cardName: 'Sword of Truth and Justice',
        scryfallId: 'xyz',
        synergy: 0.35,
        inclusion: 45,
        categoryLabel: 'Pick specifique',
      );

      expect(entry.cardName, 'Sword of Truth and Justice');
      expect(entry.scryfallId, 'xyz');
      expect(entry.synergy, 0.35);
      expect(entry.inclusion, 45);
      expect(entry.categoryLabel, 'Pick specifique');
    });
  });

  // ============================================================
  // DeckComboStatus
  // ============================================================

  group('DeckComboStatus', () {
    test('complete combo has no missing cards', () {
      const combo = EdhrecCombo(
        comboId: 1,
        name: 'A + B',
        cardNames: ['A', 'B'],
        results: ['Win'],
        colors: 'WU',
        deckCount: 5000,
        percentage: 1.0,
        rank: 1,
      );

      const status = DeckComboStatus(
        combo: combo,
        cardsInDeck: ['A', 'B'],
        cardsMissing: [],
        completeness: ComboCompleteness.complete,
      );

      expect(status.completeness, ComboCompleteness.complete);
      expect(status.cardsInDeck, hasLength(2));
      expect(status.cardsMissing, isEmpty);
    });

    test('partial combo has some missing cards', () {
      const combo = EdhrecCombo(
        comboId: 2,
        name: 'X + Y + Z',
        cardNames: ['X', 'Y', 'Z'],
        results: ['Infinite mana'],
        colors: 'G',
        deckCount: 3000,
        percentage: 0.5,
        rank: 5,
      );

      const status = DeckComboStatus(
        combo: combo,
        cardsInDeck: ['X'],
        cardsMissing: ['Y', 'Z'],
        completeness: ComboCompleteness.partial,
      );

      expect(status.completeness, ComboCompleteness.partial);
      expect(status.cardsInDeck, ['X']);
      expect(status.cardsMissing, ['Y', 'Z']);
    });

    test('none combo has all cards missing', () {
      const combo = EdhrecCombo(
        comboId: 3,
        name: 'P + Q',
        cardNames: ['P', 'Q'],
        results: [],
        colors: 'R',
        deckCount: 1000,
        percentage: 0.1,
        rank: 10,
      );

      const status = DeckComboStatus(
        combo: combo,
        cardsInDeck: [],
        cardsMissing: ['P', 'Q'],
        completeness: ComboCompleteness.none,
      );

      expect(status.completeness, ComboCompleteness.none);
      expect(status.cardsInDeck, isEmpty);
      expect(status.cardsMissing, hasLength(2));
    });
  });

  // ============================================================
  // ComboCompleteness enum
  // ============================================================

  group('ComboCompleteness', () {
    test('enum values are ordered correctly', () {
      expect(ComboCompleteness.complete.index, 0);
      expect(ComboCompleteness.partial.index, 1);
      expect(ComboCompleteness.none.index, 2);
    });

    test('enum has 3 values', () {
      expect(ComboCompleteness.values, hasLength(3));
    });
  });
}
