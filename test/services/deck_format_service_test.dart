// Tests unitaires pour DeckFormatService (Sprint 10, Phase 1)
// Teste le parsing TXT/CSV et la generation export TXT/CSV.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/services/deck_format_service.dart';

void main() {
  // =================================================================
  // parseDecklistText - Format Moxfield
  // =================================================================

  group('DeckFormatService.parseDecklistText', () {
    test('parses Moxfield format with Commander/Deck/Sideboard sections', () {
      const input = '''
Commander
1 Atraxa, Praetors' Voice

Deck
1 Sol Ring
1 Arcane Signet
1 Command Tower
35 Plains
30 Island

Sideboard
1 Path to Exile
''';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.commanderName, "Atraxa, Praetors' Voice");
      // Commander is added to mainboard
      expect(result.mainboard.length, 6); // commander + 5 cards
      expect(result.sideboard.length, 1);
      expect(result.sideboard.first.name, 'Path to Exile');
      expect(result.warnings, isEmpty);
      expect(result.hasErrors, false);

      // Check commander is in mainboard
      final commander = result.mainboard.firstWhere(
        (e) => e.name == "Atraxa, Praetors' Voice",
      );
      expect(commander.quantity, 1);

      // Check quantities
      final plains = result.mainboard.firstWhere((e) => e.name == 'Plains');
      expect(plains.quantity, 35);
    });

    test('parses MTGO format without Commander', () {
      const input = '''
4 Lightning Bolt
4 Goblin Guide
4 Monastery Swiftspear
4 Eidolon of the Great Revel

Sideboard
3 Smash to Smithereens
2 Blood Moon
''';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.commanderName, isNull);
      expect(result.mainboard.length, 4);
      expect(result.sideboard.length, 2);

      final bolt = result.mainboard.firstWhere((e) => e.name == 'Lightning Bolt');
      expect(bolt.quantity, 4);

      final bloodMoon = result.sideboard.firstWhere((e) => e.name == 'Blood Moon');
      expect(bloodMoon.quantity, 2);
    });

    test('handles empty lines and comments', () {
      const input = '''
// This is a comment
# Another comment

Deck
4 Lightning Bolt

// Another comment in the middle

4 Goblin Guide
''';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.mainboard.length, 2);
      expect(result.warnings, isEmpty);
    });

    test('handles double-faced cards (strips back face)', () {
      const input = '''
1 Delver of Secrets // Insectile Aberration
4 Jace, Vryn's Prodigy // Jace, Telepath Unbound
''';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.mainboard.length, 2);
      expect(result.mainboard[0].name, 'Delver of Secrets');
      expect(result.mainboard[1].name, "Jace, Vryn's Prodigy");
    });

    test('handles set codes in parentheses', () {
      const input = '''
1 Lightning Bolt (M10)
4 Sol Ring (C21)
''';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.mainboard.length, 2);
      expect(result.mainboard[0].name, 'Lightning Bolt');
      expect(result.mainboard[1].name, 'Sol Ring');
    });

    test('handles MTGO foil indicator *F*', () {
      const input = '''
1 Sol Ring *F*
4 Lightning Bolt *F*
''';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.mainboard.length, 2);
      expect(result.mainboard[0].name, 'Sol Ring');
      expect(result.mainboard[1].name, 'Lightning Bolt');
    });

    test('handles "Nx" format (with x after quantity)', () {
      const input = '''
4x Lightning Bolt
2x Sol Ring
''';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.mainboard.length, 2);
      expect(result.mainboard[0].quantity, 4);
      expect(result.mainboard[0].name, 'Lightning Bolt');
    });

    test('skips Considering/Maybeboard sections', () {
      const input = '''
Deck
4 Lightning Bolt

Considering
1 Path to Exile
1 Swords to Plowshares

Sideboard
2 Blood Moon
''';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.mainboard.length, 1);
      expect(result.sideboard.length, 1);
      expect(result.sideboard.first.name, 'Blood Moon');
    });

    test('handles completely invalid text gracefully', () {
      const input = 'Lorem ipsum dolor sit amet';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.mainboard, isEmpty);
      expect(result.sideboard, isEmpty);
      expect(result.warnings, isNotEmpty);
      expect(result.hasErrors, false);
    });

    test('handles alternate section names', () {
      const input = '''
Mainboard
4 Lightning Bolt

Side Board
2 Blood Moon
''';
      final result = DeckFormatService.parseDecklistText(input);

      expect(result.mainboard.length, 1);
      expect(result.mainboard.first.name, 'Lightning Bolt');
      expect(result.sideboard.length, 1);
      expect(result.sideboard.first.name, 'Blood Moon');
    });
  });

  // =================================================================
  // parseDecklistCsv - Format Archidekt / generique
  // =================================================================

  group('DeckFormatService.parseDecklistCsv', () {
    test('parses standard CSV with quantity,name,section', () {
      const input = '''quantity,name,section
4,Lightning Bolt,mainboard
4,Goblin Guide,mainboard
2,Blood Moon,sideboard''';

      final result = DeckFormatService.parseDecklistCsv(input);

      expect(result.mainboard.length, 2);
      expect(result.sideboard.length, 1);
      expect(result.mainboard[0].name, 'Lightning Bolt');
      expect(result.mainboard[0].quantity, 4);
      expect(result.sideboard[0].name, 'Blood Moon');
      expect(result.sideboard[0].quantity, 2);
    });

    test('parses Archidekt CSV with categories as tags', () {
      const input = '''Quantity,Name,Categories
1,Sol Ring,"Ramp, Mana Rock"
1,Arcane Signet,"Ramp, Mana Rock"
1,Command Tower,"Land"''';

      final result = DeckFormatService.parseDecklistCsv(input);

      expect(result.mainboard.length, 3);
      expect(result.cardTags['Sol Ring'], ['Ramp', 'Mana Rock']);
      expect(result.cardTags['Arcane Signet'], ['Ramp', 'Mana Rock']);
      expect(result.cardTags['Command Tower'], ['Land']);
    });

    test('handles CSV without section column (defaults to mainboard)', () {
      const input = '''quantity,name
4,Lightning Bolt
4,Goblin Guide''';

      final result = DeckFormatService.parseDecklistCsv(input);

      expect(result.mainboard.length, 2);
      expect(result.sideboard, isEmpty);
    });

    test('handles CSV with commander section', () {
      const input = '''quantity,name,section
1,Atraxa Praetors Voice,commander
1,Sol Ring,mainboard
1,Path to Exile,sideboard''';

      final result = DeckFormatService.parseDecklistCsv(input);

      expect(result.commanderName, 'Atraxa Praetors Voice');
      expect(result.mainboard.length, 2); // commander + sol ring
      expect(result.sideboard.length, 1);
    });

    test('rejects CSV without required columns', () {
      const input = '''foo,bar,baz
1,Lightning Bolt,test''';

      final result = DeckFormatService.parseDecklistCsv(input);

      expect(result.mainboard, isEmpty);
      expect(result.hasErrors, true);
      expect(result.warnings, contains('CSV invalide: colonnes quantity/name introuvables'));
    });

    test('handles semicolon-delimited CSV', () {
      const input = '''quantity;name;section
4;Lightning Bolt;mainboard
2;Blood Moon;sideboard''';

      final result = DeckFormatService.parseDecklistCsv(input);

      expect(result.mainboard.length, 1);
      expect(result.sideboard.length, 1);
      expect(result.mainboard.first.name, 'Lightning Bolt');
    });

    test('handles empty CSV gracefully', () {
      const input = '';
      final result = DeckFormatService.parseDecklistCsv(input);

      expect(result.mainboard, isEmpty);
      expect(result.warnings, isNotEmpty);
    });
  });

  // =================================================================
  // autoDetectAndParse
  // =================================================================

  group('DeckFormatService.autoDetectAndParse', () {
    test('detects TXT format', () {
      const input = '''
4 Lightning Bolt
4 Goblin Guide

Sideboard
2 Blood Moon
''';
      final result = DeckFormatService.autoDetectAndParse(input);

      expect(result.mainboard.length, 2);
      expect(result.sideboard.length, 1);
    });

    test('detects CSV format', () {
      const input = '''quantity,name,section
4,Lightning Bolt,mainboard
2,Blood Moon,sideboard''';

      final result = DeckFormatService.autoDetectAndParse(input);

      expect(result.mainboard.length, 1);
      expect(result.sideboard.length, 1);
    });

    test('handles empty content', () {
      final result = DeckFormatService.autoDetectAndParse('');
      expect(result.mainboard, isEmpty);
      expect(result.warnings, isNotEmpty);
    });
  });

  // =================================================================
  // exportToTxt
  // =================================================================

  group('DeckFormatService.exportToTxt', () {
    test('exports standard deck (no commander)', () {
      final deck = Deck(
        id: 'test-1',
        name: 'Burn',
        format: 'Modern',
        mainboard: [
          DeckCard(scryfallId: 'a', name: 'Lightning Bolt', quantity: 4),
          DeckCard(scryfallId: 'b', name: 'Goblin Guide', quantity: 4),
        ],
        sideboard: [
          DeckCard(scryfallId: 'c', name: 'Blood Moon', quantity: 2),
          DeckCard(scryfallId: 'd', name: 'Smash to Smithereens', quantity: 3),
        ],
      );

      final txt = DeckFormatService.exportToTxt(deck);

      expect(txt, contains('Deck'));
      expect(txt, contains('4 Lightning Bolt'));
      expect(txt, contains('4 Goblin Guide'));
      expect(txt, contains('Sideboard'));
      expect(txt, contains('2 Blood Moon'));
      expect(txt, contains('3 Smash to Smithereens'));
      expect(txt, isNot(contains('Commander')));
    });

    test('exports Commander deck with commander section', () {
      final deck = Deck(
        id: 'test-2',
        name: 'Atraxa',
        format: 'Commander',
        commanderScryfallId: 'cmd-1',
        mainboard: [
          DeckCard(scryfallId: 'cmd-1', name: "Atraxa, Praetors' Voice", quantity: 1),
          DeckCard(scryfallId: 'a', name: 'Sol Ring', quantity: 1),
          DeckCard(scryfallId: 'b', name: 'Command Tower', quantity: 1),
        ],
      );

      final txt = DeckFormatService.exportToTxt(deck);

      // Commander section should come first
      final commanderIdx = txt.indexOf('Commander');
      final deckIdx = txt.indexOf('Deck');
      expect(commanderIdx, lessThan(deckIdx));
      expect(txt, contains("1 Atraxa, Praetors' Voice"));
      expect(txt, contains('1 Sol Ring'));
      expect(txt, contains('1 Command Tower'));
      // Commander should NOT appear in Deck section
      final deckSection = txt.substring(deckIdx);
      expect(deckSection, isNot(contains("Atraxa, Praetors' Voice")));
    });

    test('exports empty deck without crash', () {
      final deck = Deck(
        id: 'test-3',
        name: 'Empty',
        format: 'Standard',
      );

      final txt = DeckFormatService.exportToTxt(deck);
      expect(txt, contains('Deck'));
      // Should not crash, just have the Deck header
    });
  });

  // =================================================================
  // exportToCsv
  // =================================================================

  group('DeckFormatService.exportToCsv', () {
    test('exports deck with correct CSV headers and data', () {
      final deck = Deck(
        id: 'test-4',
        name: 'Test CSV',
        format: 'Modern',
        mainboard: [
          DeckCard(scryfallId: 'a', name: 'Lightning Bolt', quantity: 4, tags: ['Burn']),
          DeckCard(scryfallId: 'b', name: 'Goblin Guide', quantity: 4),
        ],
        sideboard: [
          DeckCard(scryfallId: 'c', name: 'Blood Moon', quantity: 2),
        ],
      );

      final csv = DeckFormatService.exportToCsv(deck);

      expect(csv, startsWith('quantity,name,section,scryfallId,tags'));
      expect(csv, contains('4,Lightning Bolt,mainboard,a,"Burn"'));
      expect(csv, contains('4,Goblin Guide,mainboard,b,""'));
      expect(csv, contains('2,Blood Moon,sideboard,c,""'));
    });

    test('exports deck with considering and wishlist zones', () {
      final deck = Deck(
        id: 'test-5',
        name: 'Full Zones',
        format: 'Standard',
        mainboard: [
          DeckCard(scryfallId: 'a', name: 'Card A', quantity: 1),
        ],
        considering: [
          DeckCard(scryfallId: 'b', name: 'Card B', quantity: 1),
        ],
        wishlist: [
          DeckCard(scryfallId: 'c', name: 'Card C', quantity: 1),
        ],
      );

      final csv = DeckFormatService.exportToCsv(deck);

      expect(csv, contains('1,Card A,mainboard'));
      expect(csv, contains('1,Card B,considering'));
      expect(csv, contains('1,Card C,wishlist'));
    });

    test('handles card names with special characters in CSV', () {
      final deck = Deck(
        id: 'test-6',
        name: 'Special',
        format: 'Standard',
        mainboard: [
          DeckCard(scryfallId: 'a', name: 'Jace, the Mind Sculptor', quantity: 1),
        ],
      );

      final csv = DeckFormatService.exportToCsv(deck);

      // Name with comma should be quoted
      expect(csv, contains('"Jace, the Mind Sculptor"'));
    });
  });

  // =================================================================
  // DecklistParseResult
  // =================================================================

  group('DecklistParseResult', () {
    test('totalCards sums mainboard and sideboard quantities', () {
      const result = DecklistParseResult(
        mainboard: [
          DecklistEntry(name: 'A', quantity: 4, section: 'mainboard'),
          DecklistEntry(name: 'B', quantity: 3, section: 'mainboard'),
        ],
        sideboard: [
          DecklistEntry(name: 'C', quantity: 2, section: 'sideboard'),
        ],
      );

      expect(result.totalCards, 9);
    });

    test('empty result has zero totalCards', () {
      final result = DecklistParseResult.empty();
      expect(result.totalCards, 0);
    });
  });

  // =================================================================
  // Roundtrip: export -> parse -> compare
  // =================================================================

  group('Roundtrip export -> parse', () {
    test('TXT roundtrip preserves cards', () {
      final originalDeck = Deck(
        id: 'roundtrip-1',
        name: 'Roundtrip',
        format: 'Modern',
        mainboard: [
          DeckCard(scryfallId: 'a', name: 'Lightning Bolt', quantity: 4),
          DeckCard(scryfallId: 'b', name: 'Goblin Guide', quantity: 4),
        ],
        sideboard: [
          DeckCard(scryfallId: 'c', name: 'Blood Moon', quantity: 2),
        ],
      );

      final txt = DeckFormatService.exportToTxt(originalDeck);
      final parsed = DeckFormatService.parseDecklistText(txt);

      expect(parsed.mainboard.length, 2);
      expect(parsed.sideboard.length, 1);
      expect(
        parsed.mainboard.firstWhere((e) => e.name == 'Lightning Bolt').quantity,
        4,
      );
      expect(
        parsed.sideboard.firstWhere((e) => e.name == 'Blood Moon').quantity,
        2,
      );
    });
  });
}
