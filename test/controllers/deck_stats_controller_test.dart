// Tests unitaires pour DeckStatsController (Sprint 10)
// Teste la logique de calcul des statistiques de deck.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_stats_controller.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';

// --- HELPERS ---

/// Cree une ScryfallCard minimale pour les tests.
ScryfallCard _makeCard({
  required String id,
  String name = 'Test Card',
  String typeLine = 'Creature',
  String? manaCost,
  double? cmc,
  List<String> colorIdentity = const [],
  String priceEur = '0',
}) {
  return ScryfallCard(
    id: id,
    oracleId: 'oracle-$id',
    name: name,
    manaCost: manaCost,
    cmc: cmc,
    imageUrl: '',
    rulesText: '',
    typeLine: typeLine,
    legalities: const {},
    prices: {'eur': priceEur},
    lang: 'en',
    colorIdentity: colorIdentity,
    setName: 'Test Set',
    setCode: 'TST',
    collectorNumber: '1',
    rarity: 'common',
    purchaseUris: const {},
  );
}

DeckCard _makeDeckCard({
  required String scryfallId,
  String name = 'Test Card',
  int quantity = 1,
}) {
  return DeckCard(
    scryfallId: scryfallId,
    name: name,
    quantity: quantity,
  );
}

void main() {
  // =================================================================
  // DeckStatsState - Tests sur l'etat immutable
  // =================================================================

  group('DeckStatsState', () {
    test('initial state has correct defaults', () {
      const state = DeckStatsState();

      expect(state.manaCurveData, isEmpty);
      expect(state.cardTypeData, isEmpty);
      expect(state.pipCountData, isEmpty);
      expect(state.sourceCountData, isEmpty);
      expect(state.colorByTypeData, isEmpty);
      expect(state.averageCmc, 0.0);
      expect(state.totalPrice, 0.0);
    });

    test('copyWith preserves values when not specified', () {
      const state = DeckStatsState(
        averageCmc: 3.5,
        totalPrice: 42.0,
      );

      final copied = state.copyWith(averageCmc: 2.0);

      expect(copied.averageCmc, 2.0);
      expect(copied.totalPrice, 42.0);
    });
  });

  // =================================================================
  // DeckStatsController.getPrimaryType - helper statique
  // =================================================================

  group('DeckStatsController.getPrimaryType', () {
    test('identifies creature type', () {
      expect(DeckStatsController.getPrimaryType('Creature — Human Soldier'), 'Créatures');
    });

    test('identifies land type', () {
      expect(DeckStatsController.getPrimaryType('Basic Land — Forest'), 'Terrains');
    });

    test('identifies instant type', () {
      expect(DeckStatsController.getPrimaryType('Instant'), 'Instant');
    });

    test('identifies sorcery type', () {
      expect(DeckStatsController.getPrimaryType('Sorcery'), 'Rituels');
    });

    test('identifies artifact type', () {
      expect(DeckStatsController.getPrimaryType('Artifact'), 'Artefacts');
    });

    test('identifies enchantment type', () {
      expect(DeckStatsController.getPrimaryType('Enchantment — Aura'), 'Enchantements');
    });

    test('returns Autres for unknown type', () {
      expect(DeckStatsController.getPrimaryType('Conspiracy'), 'Autres');
    });

    test('basic land name without dash detected as Terrains', () {
      // e.g. a LOCAL: card named "Forest"
      expect(DeckStatsController.getPrimaryType('Forest'), 'Terrains');
      expect(DeckStatsController.getPrimaryType('Island'), 'Terrains');
      expect(DeckStatsController.getPrimaryType('Swamp'), 'Terrains');
      expect(DeckStatsController.getPrimaryType('Plains'), 'Terrains');
      expect(DeckStatsController.getPrimaryType('Mountain'), 'Terrains');
    });
  });

  // =================================================================
  // DeckStatsController.calculate - Tests de calcul complets
  // =================================================================

  group('DeckStatsController.calculate', () {
    late DeckStatsController controller;

    setUp(() {
      controller = DeckStatsController();
    });

    tearDown(() {
      controller.dispose();
    });

    // --- Test 1: Mainboard vide ---
    test('empty mainboard returns zero stats', () {
      controller.calculate([], []);

      final s = controller.state;
      expect(s.manaCurveData.values.every((v) => v == 0), isTrue);
      expect(s.cardTypeData, isEmpty);
      expect(s.pipCountData, isEmpty);
      expect(s.sourceCountData, isEmpty);
      expect(s.colorByTypeData, isEmpty);
      expect(s.averageCmc, 0.0);
      expect(s.totalPrice, 0.0);
    });

    // --- Test 2: Courbe de mana ---
    test('mana curve calculates correctly', () {
      final cards = [
        _makeCard(id: 'c1', typeLine: 'Creature', cmc: 1),
        _makeCard(id: 'c2', typeLine: 'Creature', cmc: 2),
        _makeCard(id: 'c3', typeLine: 'Creature', cmc: 3),
        _makeCard(id: 'c7', typeLine: 'Creature', cmc: 8), // >= 7 => bucket 7
      ];
      final mainboard = [
        _makeDeckCard(scryfallId: 'c1', quantity: 4),
        _makeDeckCard(scryfallId: 'c2', quantity: 3),
        _makeDeckCard(scryfallId: 'c3', quantity: 2),
        _makeDeckCard(scryfallId: 'c7', quantity: 1),
      ];

      controller.calculate(mainboard, cards);

      expect(controller.state.manaCurveData[1], 4);
      expect(controller.state.manaCurveData[2], 3);
      expect(controller.state.manaCurveData[3], 2);
      expect(controller.state.manaCurveData[7], 1); // cmc 8 goes to bucket 7
      expect(controller.state.manaCurveData[0], 0);
    });

    // --- Test 3: Types de cartes ---
    test('card types identified correctly', () {
      final cards = [
        _makeCard(id: 'c1', typeLine: 'Creature — Elf Warrior', cmc: 2),
        _makeCard(id: 'c2', typeLine: 'Instant', cmc: 1),
        _makeCard(id: 'c3', typeLine: 'Sorcery', cmc: 3),
        _makeCard(id: 'c4', typeLine: 'Enchantment — Aura', cmc: 2),
        _makeCard(id: 'c5', typeLine: 'Basic Land — Forest'),
      ];
      final mainboard = [
        _makeDeckCard(scryfallId: 'c1', quantity: 4),
        _makeDeckCard(scryfallId: 'c2', quantity: 3),
        _makeDeckCard(scryfallId: 'c3', quantity: 2),
        _makeDeckCard(scryfallId: 'c4', quantity: 1),
        _makeDeckCard(scryfallId: 'c5', quantity: 10),
      ];

      controller.calculate(mainboard, cards);

      expect(controller.state.cardTypeData['Créatures'], 4);
      expect(controller.state.cardTypeData['Instant'], 3);
      expect(controller.state.cardTypeData['Rituels'], 2);
      expect(controller.state.cardTypeData['Enchantements'], 1);
      expect(controller.state.cardTypeData['Terrains'], 10);
    });

    // --- Test 4: Pip count ---
    test('pip count from mana cost', () {
      final cards = [
        _makeCard(id: 'c1', typeLine: 'Creature', manaCost: '{1}{G}{G}', cmc: 3),
        _makeCard(id: 'c2', typeLine: 'Instant', manaCost: '{U}{U}', cmc: 2),
        _makeCard(id: 'c3', typeLine: 'Sorcery', manaCost: '{2}{R}', cmc: 3),
      ];
      final mainboard = [
        _makeDeckCard(scryfallId: 'c1', quantity: 2),
        _makeDeckCard(scryfallId: 'c2', quantity: 1),
        _makeDeckCard(scryfallId: 'c3', quantity: 3),
      ];

      controller.calculate(mainboard, cards);

      // c1: {G}{G} x2 = 4 green pips
      // c2: {U}{U} x1 = 2 blue pips
      // c3: {R} x3 = 3 red pips
      expect(controller.state.pipCountData['G'], 4);
      expect(controller.state.pipCountData['U'], 2);
      expect(controller.state.pipCountData['R'], 3);
      expect(controller.state.pipCountData.containsKey('W'), isFalse);
      expect(controller.state.pipCountData.containsKey('B'), isFalse);
    });

    // --- Test 5: Land sources ---
    test('land sources counted', () {
      final cards = [
        _makeCard(id: 'l1', name: 'Forest', typeLine: 'Basic Land — Forest', colorIdentity: ['G']),
        _makeCard(id: 'l2', name: 'Island', typeLine: 'Basic Land — Island', colorIdentity: ['U']),
        _makeCard(id: 'l3', name: 'Command Tower', typeLine: 'Land', colorIdentity: ['W', 'U', 'B', 'R', 'G']),
        _makeCard(id: 'l4', name: 'Wastes', typeLine: 'Basic Land', colorIdentity: []),
        _makeCard(id: 'a1', name: 'Sol Ring', typeLine: 'Artifact', colorIdentity: []),
      ];
      final mainboard = [
        _makeDeckCard(scryfallId: 'l1', name: 'Forest', quantity: 10),
        _makeDeckCard(scryfallId: 'l2', name: 'Island', quantity: 8),
        _makeDeckCard(scryfallId: 'l3', name: 'Command Tower', quantity: 1),
        _makeDeckCard(scryfallId: 'l4', name: 'Wastes', quantity: 2),
        _makeDeckCard(scryfallId: 'a1', name: 'Sol Ring', quantity: 1),
      ];

      controller.calculate(mainboard, cards);

      final sources = controller.state.sourceCountData;
      expect(sources['G'], 11); // 10 Forest + 1 Command Tower
      expect(sources['U'], 9);  // 8 Island + 1 Command Tower
      expect(sources['W'], 1);  // Command Tower
      expect(sources['B'], 1);  // Command Tower
      expect(sources['R'], 1);  // Command Tower
      expect(sources['C'], 3);  // 2 Wastes + 1 Sol Ring
    });

    // --- Test 6: Color by type ---
    test('color by type grouping', () {
      final cards = [
        _makeCard(id: 'c1', typeLine: 'Creature — Elf', colorIdentity: ['G'], cmc: 2),
        _makeCard(id: 'c2', typeLine: 'Creature — Human', colorIdentity: ['W'], cmc: 1),
        _makeCard(id: 'c3', typeLine: 'Instant', colorIdentity: ['U', 'R'], cmc: 2), // multicolor => M
        _makeCard(id: 'c4', typeLine: 'Artifact', colorIdentity: [], cmc: 3), // colorless => C
      ];
      final mainboard = [
        _makeDeckCard(scryfallId: 'c1', quantity: 3),
        _makeDeckCard(scryfallId: 'c2', quantity: 2),
        _makeDeckCard(scryfallId: 'c3', quantity: 4),
        _makeDeckCard(scryfallId: 'c4', quantity: 1),
      ];

      controller.calculate(mainboard, cards);

      final cbt = controller.state.colorByTypeData;
      expect(cbt['Créatures']!['G'], 3);
      expect(cbt['Créatures']!['W'], 2);
      expect(cbt['Instant']!['M'], 4); // multicolor
      expect(cbt['Artefacts']!['C'], 1); // colorless
    });

    // --- Test 7: Average CMC ---
    test('average CMC calculation', () {
      final cards = [
        _makeCard(id: 'c1', typeLine: 'Creature', cmc: 2),
        _makeCard(id: 'c2', typeLine: 'Creature', cmc: 4),
        _makeCard(id: 'land', typeLine: 'Basic Land — Forest', cmc: 0),
      ];
      final mainboard = [
        _makeDeckCard(scryfallId: 'c1', quantity: 2), // 2 * 2 = 4
        _makeDeckCard(scryfallId: 'c2', quantity: 2), // 2 * 4 = 8
        _makeDeckCard(scryfallId: 'land', quantity: 10), // lands are excluded
      ];

      controller.calculate(mainboard, cards);

      // total CMC = 4 + 8 = 12, total non-land cards = 4
      // average = 12 / 4 = 3.0
      expect(controller.state.averageCmc, 3.0);
    });

    // --- Test 8: Price calculation ---
    test('price calculation', () {
      final cards = [
        _makeCard(id: 'c1', typeLine: 'Creature', cmc: 2, priceEur: '1.50'),
        _makeCard(id: 'c2', typeLine: 'Creature', cmc: 4, priceEur: '10.00'),
        _makeCard(id: 'c3', typeLine: 'Instant', cmc: 1, priceEur: '0.25'),
      ];
      final mainboard = [
        _makeDeckCard(scryfallId: 'c1', quantity: 4), // 4 * 1.50 = 6.00
        _makeDeckCard(scryfallId: 'c2', quantity: 1), // 1 * 10.00 = 10.00
        _makeDeckCard(scryfallId: 'c3', quantity: 2), // 2 * 0.25 = 0.50
      ];

      controller.calculate(mainboard, cards);

      // total = 6.00 + 10.00 + 0.50 = 16.50
      expect(controller.state.totalPrice, closeTo(16.50, 0.01));
    });

    // --- Test bonus: LOCAL: cards are skipped ---
    test('LOCAL cards are skipped in calculations', () {
      final cards = <ScryfallCard>[]; // no scryfall data for local cards
      final mainboard = [
        _makeDeckCard(scryfallId: 'LOCAL:Some Card', name: 'Some Card', quantity: 4),
      ];

      controller.calculate(mainboard, cards);

      // Mana curve should be all zeros (LOCAL cards skipped)
      expect(controller.state.manaCurveData.values.every((v) => v == 0), isTrue);
      expect(controller.state.averageCmc, 0.0);
      expect(controller.state.totalPrice, 0.0);
      // But card types should still detect from the name
      expect(controller.state.cardTypeData['Autres'], 4);
    });
  });

  // =================================================================
  // Constants
  // =================================================================

  group('Constants', () {
    test('manaColorValues contains all 7 colors', () {
      expect(manaColorValues.length, 7);
      expect(manaColorValues.containsKey('W'), isTrue);
      expect(manaColorValues.containsKey('U'), isTrue);
      expect(manaColorValues.containsKey('B'), isTrue);
      expect(manaColorValues.containsKey('R'), isTrue);
      expect(manaColorValues.containsKey('G'), isTrue);
      expect(manaColorValues.containsKey('C'), isTrue);
      expect(manaColorValues.containsKey('M'), isTrue);
    });

    test('colorOrder has 7 entries', () {
      expect(colorOrder.length, 7);
      expect(colorOrder.first, 'W');
      expect(colorOrder.last, 'M');
    });
  });
}
