// Tests unitaires pour DeckListController (Sprint 10, Phase 2)
// Teste la logique d'etat, les helpers et le parsing d'import.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_list_controller.dart';
import 'package:magic_companion/services/deck_format_service.dart';

void main() {
  // =================================================================
  // DeckListState - Tests unitaires purs sur l'etat immutable
  // =================================================================

  group('DeckListState', () {
    test('initial state has correct defaults', () {
      const state = DeckListState();

      expect(state.decks, isEmpty);
      expect(state.filteredDecks, isEmpty);
      expect(state.deckPrices, isEmpty);
      expect(state.isLoading, true);
      expect(state.isImporting, false);
      expect(state.searchQuery, '');
      expect(state.selectedFormat, 'Tous');
      expect(state.selectedSort, 'name');
      expect(state.selectedIdentityName, isNull);
      expect(state.selectedIdentityColors, isNull);
    });

    test('copyWith preserves values when not specified', () {
      const state = DeckListState(
        searchQuery: 'test',
        selectedFormat: 'Commander',
        isImporting: true,
      );

      final copied = state.copyWith(searchQuery: 'new');

      expect(copied.searchQuery, 'new');
      expect(copied.selectedFormat, 'Commander');
      expect(copied.isImporting, true);
    });

    test('copyWith clearIdentity resets identity fields', () {
      const state = DeckListState(
        selectedIdentityName: 'Gruul',
        selectedIdentityColors: ['R', 'G'],
      );

      final cleared = state.copyWith(clearIdentity: true);

      expect(cleared.selectedIdentityName, isNull);
      expect(cleared.selectedIdentityColors, isNull);
    });
  });

  // =================================================================
  // DeckListActionResult
  // =================================================================

  group('DeckListActionResult', () {
    test('defaults to success', () {
      const result = DeckListActionResult();
      expect(result.success, true);
      expect(result.message, '');
    });

    test('can indicate failure', () {
      const result = DeckListActionResult(
        success: false,
        message: 'Import failed',
      );
      expect(result.success, false);
      expect(result.message, 'Import failed');
    });
  });

  // =================================================================
  // Import parsing scenarios (integration: DeckFormatService + import logic)
  // =================================================================

  group('Import parsing scenarios', () {
    test('Moxfield Commander deck parses correctly for import', () {
      const moxfieldTxt = '''
Commander
1 Atraxa, Praetors' Voice

Deck
1 Sol Ring
1 Arcane Signet
35 Plains
30 Island
30 Swamp

Sideboard
1 Path to Exile
''';
      final result = DeckFormatService.autoDetectAndParse(moxfieldTxt);

      expect(result.commanderName, "Atraxa, Praetors' Voice");
      expect(result.mainboard, isNotEmpty);
      expect(result.sideboard, isNotEmpty);
      expect(result.totalCards, greaterThan(90));
    });

    test('MTGO Standard deck parses correctly for import', () {
      const mtgoTxt = '''
4 Lightning Bolt
4 Goblin Guide
4 Monastery Swiftspear
4 Eidolon of the Great Revel
4 Lava Spike
4 Searing Blaze
4 Rift Bolt
4 Shard Volley
4 Skullcrack
4 Inspiring Vantage
4 Sacred Foundry
4 Fiery Islet
4 Sunbaked Canyon
8 Mountain

Sideboard
4 Smash to Smithereens
3 Path to Exile
2 Blood Moon
2 Kor Firewalker
2 Rest in Peace
2 Deflecting Palm
''';
      final result = DeckFormatService.autoDetectAndParse(mtgoTxt);

      expect(result.commanderName, isNull);
      expect(result.mainboard.length, 14);
      expect(result.sideboard.length, 6);
      // Total should be 60 + 15
      expect(result.totalCards, 75);
    });

    test('CSV Archidekt import with categories extracts tags', () {
      const archidektCsv = '''Quantity,Name,Categories
1,Sol Ring,"Ramp, Mana Rock"
1,Arcane Signet,"Ramp, Mana Rock"
1,Command Tower,"Land"
1,Counterspell,"Interaction"''';

      final result = DeckFormatService.autoDetectAndParse(archidektCsv);

      expect(result.mainboard.length, 4);
      expect(result.cardTags['Sol Ring'], ['Ramp', 'Mana Rock']);
      expect(result.cardTags['Command Tower'], ['Land']);
    });

    test('empty import content returns failure', () {
      final result = DeckFormatService.autoDetectAndParse('');
      expect(result.mainboard, isEmpty);
      expect(result.sideboard, isEmpty);
    });

    test('import with invalid text returns warnings', () {
      const invalidTxt = '''
Hello World
This is not a decklist
Random text here
''';
      final result = DeckFormatService.autoDetectAndParse(invalidTxt);
      expect(result.mainboard, isEmpty);
      expect(result.warnings, isNotEmpty);
    });
  });

  // =================================================================
  // colorFamilies static data
  // =================================================================

  group('DeckListController.colorFamilies', () {
    test('contains all expected families', () {
      const families = DeckListController.colorFamilies;
      expect(families.containsKey('Mono'), isTrue);
      expect(families.containsKey('Guilde (2)'), isTrue);
      expect(families.containsKey('Trio (3)'), isTrue);
      expect(families.containsKey('Nephilim (4)'), isTrue);
      expect(families.containsKey('WUBRG (5)'), isTrue);
    });

    test('Mono contains all 6 options', () {
      final mono = DeckListController.colorFamilies['Mono']!;
      expect(mono.length, 6);
      expect(mono.containsKey('Blanc'), isTrue);
      expect(mono.containsKey('Incolore'), isTrue);
    });

    test('Guilde contains 10 guilds', () {
      final guilds = DeckListController.colorFamilies['Guilde (2)']!;
      expect(guilds.length, 10);
    });
  });
}
