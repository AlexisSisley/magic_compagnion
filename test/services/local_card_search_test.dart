// Tests pour la fonction top-level _executeSearch de LocalCardService.
// Comme _executeSearch est privée, on la re-déclare ici avec la même logique
// pour tester l'algorithme de recherche/filtrage sans dépendre de rootBundle.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/models/search_filters.dart';

// Re-implémentation de la fonction de recherche identique à celle du service
// (elle est top-level dans local_card_service.dart mais privée avec le prefixe _)
List<ScryfallCard> executeSearch(List<ScryfallCard> cards, String query, SearchFilters? filters) {
  final lowerQuery = query.toLowerCase().trim();

  final lowerType = filters?.cardType?.toLowerCase();
  final lowerSet = filters?.setCode?.toLowerCase();
  final colors = filters?.colors ?? {};
  final rarity = filters?.rarity;
  final minCmc = filters?.minCmc;
  final maxCmc = filters?.maxCmc;
  final lowerKeyword = filters?.keyword?.toLowerCase();

  return cards.where((card) {
    if (lowerQuery.isNotEmpty) {
      bool matchName = card.name.toLowerCase().contains(lowerQuery);
      bool matchPrinted = card.printedName?.toLowerCase().contains(lowerQuery) ?? false;
      if (!matchName && !matchPrinted) return false;
    }

    if (lowerType != null && !card.typeLine.toLowerCase().contains(lowerType)) return false;
    if (lowerSet != null && card.setCode.toLowerCase() != lowerSet) return false;
    if (rarity != null && card.rarity != rarity) return false;

    if (minCmc != null && (card.cmc ?? 0) < minCmc) return false;
    if (maxCmc != null && (card.cmc ?? 0) > maxCmc) return false;

    if (colors.isNotEmpty) {
      final cardColors = card.colorIdentity.toSet();
      if (!colors.every((c) => cardColors.contains(c))) return false;
    }

    if (lowerKeyword != null && lowerKeyword.isNotEmpty) {
      if (!card.rulesText.toLowerCase().contains(lowerKeyword)) return false;
    }

    return true;
  }).toList();
}

// --- Helpers pour créer des cartes de test ---
ScryfallCard _makeCard({
  String id = 'test-id',
  String name = 'Test Card',
  String? printedName,
  String typeLine = 'Creature',
  String setCode = 'tst',
  String rarity = 'common',
  double? cmc,
  List<String> colorIdentity = const [],
  String rulesText = '',
  String? manaCost,
}) {
  return ScryfallCard(
    id: id,
    oracleId: '',
    name: name,
    printedName: printedName,
    manaCost: manaCost,
    cmc: cmc,
    imageUrl: '',
    rulesText: rulesText,
    typeLine: typeLine,
    legalities: {},
    prices: {},
    lang: 'en',
    colorIdentity: colorIdentity,
    setName: '',
    setCode: setCode,
    collectorNumber: '',
    rarity: rarity,
    purchaseUris: {},
  );
}

void main() {
  late List<ScryfallCard> testCards;

  setUp(() {
    testCards = [
      _makeCard(id: '1', name: 'Lightning Bolt', printedName: 'Eclair', typeLine: 'Instant', setCode: 'lea', rarity: 'common', cmc: 1, colorIdentity: ['R'], rulesText: 'Lightning Bolt deals 3 damage to any target.'),
      _makeCard(id: '2', name: 'Counterspell', typeLine: 'Instant', setCode: 'lea', rarity: 'uncommon', cmc: 2, colorIdentity: ['U'], rulesText: 'Counter target spell.'),
      _makeCard(id: '3', name: 'Sol Ring', typeLine: 'Artifact', setCode: 'cmd', rarity: 'uncommon', cmc: 1, colorIdentity: [], rulesText: 'Tap: Add two colorless mana.'),
      _makeCard(id: '4', name: 'Swords to Plowshares', typeLine: 'Instant', setCode: 'lea', rarity: 'uncommon', cmc: 1, colorIdentity: ['W'], rulesText: 'Exile target creature. Its controller gains life equal to its power.'),
      _makeCard(id: '5', name: 'Tarmogoyf', typeLine: 'Creature — Lhurgoyf', setCode: 'fut', rarity: 'rare', cmc: 2, colorIdentity: ['G'], rulesText: "Tarmogoyf's power is equal to the number of card types among cards in all graveyards."),
      _makeCard(id: '6', name: 'Atraxa, Praetors\' Voice', printedName: 'Atraxa, voix des praetors', typeLine: 'Legendary Creature — Phyrexian Angel Horror', setCode: 'c16', rarity: 'mythic', cmc: 4, colorIdentity: ['W', 'U', 'B', 'G'], rulesText: 'Flying, vigilance, deathtouch, lifelink. At the beginning of your end step, proliferate.'),
      _makeCard(id: '7', name: 'Mystic Remora', typeLine: 'Enchantment', setCode: 'ice', rarity: 'common', cmc: 1, colorIdentity: ['U'], rulesText: 'Cumulative upkeep. Whenever an opponent casts a noncreature spell, you may draw a card.'),
    ];
  });

  group('Search by name', () {
    test('finds card by exact name', () {
      final results = executeSearch(testCards, 'Lightning Bolt', null);
      expect(results.length, 1);
      expect(results.first.name, 'Lightning Bolt');
    });

    test('finds card by partial name (case insensitive)', () {
      final results = executeSearch(testCards, 'bolt', null);
      expect(results.length, 1);
      expect(results.first.name, 'Lightning Bolt');
    });

    test('finds card by printedName', () {
      final results = executeSearch(testCards, 'eclair', null);
      expect(results.length, 1);
      expect(results.first.name, 'Lightning Bolt');
    });

    test('finds card by translated printedName', () {
      final results = executeSearch(testCards, 'voix des praetors', null);
      expect(results.length, 1);
      expect(results.first.name, "Atraxa, Praetors' Voice");
    });

    test('empty query returns all cards', () {
      final results = executeSearch(testCards, '', null);
      expect(results.length, testCards.length);
    });

    test('no match returns empty', () {
      final results = executeSearch(testCards, 'Nonexistent Card', null);
      expect(results, isEmpty);
    });
  });

  group('Filter by type', () {
    test('filters by type Instant', () {
      final filters = SearchFilters(cardType: 'Instant');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 3); // Bolt, Counterspell, Swords
      expect(results.every((c) => c.typeLine.contains('Instant')), true);
    });

    test('filters by type Creature', () {
      final filters = SearchFilters(cardType: 'Creature');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 2); // Tarmogoyf, Atraxa
    });

    test('filter type is case insensitive', () {
      final filters = SearchFilters(cardType: 'artifact');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 1);
      expect(results.first.name, 'Sol Ring');
    });
  });

  group('Filter by set code', () {
    test('filters by set code', () {
      final filters = SearchFilters(setCode: 'lea');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 3); // Bolt, Counterspell, Swords
    });

    test('set code is case insensitive', () {
      final filters = SearchFilters(setCode: 'CMD');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 1);
      expect(results.first.name, 'Sol Ring');
    });
  });

  group('Filter by rarity', () {
    test('filters by common rarity', () {
      final filters = SearchFilters(rarity: 'common');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 2); // Bolt, Mystic Remora
    });

    test('filters by mythic rarity', () {
      final filters = SearchFilters(rarity: 'mythic');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 1);
      expect(results.first.name, "Atraxa, Praetors' Voice");
    });
  });

  group('Filter by CMC', () {
    test('filters by minCmc', () {
      final filters = SearchFilters(minCmc: 2);
      final results = executeSearch(testCards, '', filters);
      expect(results.every((c) => (c.cmc ?? 0) >= 2), true);
    });

    test('filters by maxCmc', () {
      final filters = SearchFilters(maxCmc: 1);
      final results = executeSearch(testCards, '', filters);
      expect(results.every((c) => (c.cmc ?? 0) <= 1), true);
      expect(results.length, 4); // Bolt, Sol Ring, Swords, Mystic Remora
    });

    test('filters by minCmc and maxCmc range', () {
      final filters = SearchFilters(minCmc: 2, maxCmc: 3);
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 2); // Counterspell (2), Tarmogoyf (2)
    });
  });

  group('Filter by colors', () {
    test('filters by single color', () {
      final filters = SearchFilters(colors: {'R'});
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 1);
      expect(results.first.name, 'Lightning Bolt');
    });

    test('filters by multiple colors (must have all)', () {
      final filters = SearchFilters(colors: {'W', 'U'});
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 1);
      expect(results.first.name, "Atraxa, Praetors' Voice");
    });

    test('colorless cards excluded by color filter', () {
      final filters = SearchFilters(colors: {'U'});
      final results = executeSearch(testCards, '', filters);
      // Counterspell (U), Atraxa (WUBG), Mystic Remora (U)
      expect(results.length, 3);
      expect(results.any((c) => c.name == 'Sol Ring'), false);
    });
  });

  group('Filter by keyword (rules text)', () {
    test('filters by keyword in rules text', () {
      final filters = SearchFilters(keyword: 'damage');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 1);
      expect(results.first.name, 'Lightning Bolt');
    });

    test('keyword is case insensitive', () {
      final filters = SearchFilters(keyword: 'COUNTER');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 1);
      expect(results.first.name, 'Counterspell');
    });

    test('keyword proliferate finds Atraxa', () {
      final filters = SearchFilters(keyword: 'proliferate');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 1);
      expect(results.first.name, "Atraxa, Praetors' Voice");
    });
  });

  group('Combined filters', () {
    test('name + type filter', () {
      final filters = SearchFilters(cardType: 'Instant');
      final results = executeSearch(testCards, 'bolt', filters);
      expect(results.length, 1);
      expect(results.first.name, 'Lightning Bolt');
    });

    test('type + color filter', () {
      final filters = SearchFilters(cardType: 'Instant', colors: {'U'});
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 1);
      expect(results.first.name, 'Counterspell');
    });

    test('type + rarity + set filter', () {
      final filters = SearchFilters(cardType: 'Instant', rarity: 'uncommon', setCode: 'lea');
      final results = executeSearch(testCards, '', filters);
      expect(results.length, 2); // Counterspell, Swords
    });

    test('all filters combined narrows to single card', () {
      final filters = SearchFilters(
        cardType: 'Creature',
        colors: {'G'},
        rarity: 'rare',
        minCmc: 2,
        maxCmc: 2,
      );
      final results = executeSearch(testCards, 'goyf', filters);
      expect(results.length, 1);
      expect(results.first.name, 'Tarmogoyf');
    });

    test('contradictory filters return empty', () {
      final filters = SearchFilters(cardType: 'Instant', colors: {'G'});
      final results = executeSearch(testCards, '', filters);
      expect(results, isEmpty);
    });
  });
}
