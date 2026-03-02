// Tests unitaires pour DeckSuggestionsController
// Teste la logique d'etat, l'enrichissement de suggestions et les helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_suggestions_controller.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/services/edhrec_service.dart';
import 'package:magic_companion/services/local_card_service.dart';

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

ScryfallCard _makeScryfallCard({
  String id = 'card-1',
  String name = 'Test Card',
  String typeLine = 'Creature',
}) {
  return ScryfallCard(
    id: id,
    oracleId: '',
    name: name,
    imageUrl: '',
    rulesText: '',
    typeLine: typeLine,
    legalities: {},
    prices: {},
    lang: 'en',
    colorIdentity: [],
    setName: '',
    setCode: '',
    collectorNumber: '',
    rarity: '',
    purchaseUris: {},
  );
}

EdhrecCardSuggestion _makeSuggestion({
  String name = 'Suggested Card',
  double synergy = 0.15,
  int inclusion = 60,
  int numDecks = 1000,
  double salt = 0.5,
}) {
  return EdhrecCardSuggestion(
    name: name,
    sanitized: name.toLowerCase().replaceAll(' ', '-'),
    synergy: synergy,
    inclusion: inclusion,
    numDecks: numDecks,
    potentialDecks: 5000,
    salt: salt,
  );
}

/// Creates a controller for testing.
/// Uses real singletons (EdhrecService, LocalCardService) but tests only
/// the synchronous pure logic methods (no API calls).
DeckSuggestionsController _createController({required Deck deck}) {
  return DeckSuggestionsController(
    edhrecService: EdhrecService(),
    localCardService: LocalCardService(),
    deck: deck,
  );
}

void main() {
  // =================================================================
  // DeckSuggestionsState - Tests unitaires sur l'etat immutable
  // =================================================================

  group('DeckSuggestionsState', () {
    test('initial state has correct defaults', () {
      const state = DeckSuggestionsState();

      expect(state.commanderData, isNull);
      expect(state.themeCards, isNull);
      expect(state.selectedTheme, isNull);
      expect(state.synergyReport, isNull);
      expect(state.enrichedSuggestions, isEmpty);
      expect(state.isLoading, false);
      expect(state.hasLoaded, false);
      expect(state.isLoadingTheme, false);
    });

    test('copyWith preserves values when not specified', () {
      final state = DeckSuggestionsState(
        isLoading: true,
        hasLoaded: true,
        selectedTheme: 'tokens',
        enrichedSuggestions: {
          'Creatures': [
            EnrichedSuggestion(
              card: _makeScryfallCard(),
              synergy: 0.5,
              inclusion: 80,
              categoryLabel: 'Pick specifique',
              numDecks: 2000,
            ),
          ],
        },
      );

      final copied = state.copyWith(isLoading: false);

      expect(copied.isLoading, false);
      expect(copied.hasLoaded, true);
      expect(copied.selectedTheme, 'tokens');
      expect(copied.enrichedSuggestions, isNotEmpty);
    });

    test('copyWith with clearTheme resets theme and themeCards', () {
      final state = DeckSuggestionsState(
        selectedTheme: 'voltron',
        themeCards: [_makeSuggestion()],
        hasLoaded: true,
      );

      final cleared = state.copyWith(clearTheme: true);

      expect(cleared.selectedTheme, isNull);
      expect(cleared.themeCards, isNull);
      expect(cleared.hasLoaded, true); // not affected
    });

    test('copyWith can set new selectedTheme', () {
      const state = DeckSuggestionsState();

      final updated = state.copyWith(selectedTheme: 'infect');

      expect(updated.selectedTheme, 'infect');
    });
  });

  // =================================================================
  // EnrichedSuggestion - Tests unitaires
  // =================================================================

  group('EnrichedSuggestion', () {
    test('creates with all required fields', () {
      final card = _makeScryfallCard(name: 'Sol Ring');
      const synergy = 0.35;
      const inclusion = 90;
      const categoryLabel = 'Staple generique';
      const numDecks = 50000;
      const salt = 1.2;

      final suggestion = EnrichedSuggestion(
        card: card,
        synergy: synergy,
        inclusion: inclusion,
        categoryLabel: categoryLabel,
        numDecks: numDecks,
        salt: salt,
      );

      expect(suggestion.card.name, 'Sol Ring');
      expect(suggestion.synergy, 0.35);
      expect(suggestion.inclusion, 90);
      expect(suggestion.categoryLabel, 'Staple generique');
      expect(suggestion.numDecks, 50000);
      expect(suggestion.salt, 1.2);
    });

    test('salt defaults to 0.0', () {
      final suggestion = EnrichedSuggestion(
        card: _makeScryfallCard(),
        synergy: 0.1,
        inclusion: 50,
        categoryLabel: 'Standard',
        numDecks: 100,
      );

      expect(suggestion.salt, 0.0);
    });
  });

  // =================================================================
  // DeckSuggestionsController.getCommanderName
  // =================================================================

  group('DeckSuggestionsController.getCommanderName', () {
    test('resolves commander name from mainboard', () {
      final deck = _makeTestDeck(
        commanderScryfallId: 'cmd-001',
        mainboard: [
          DeckCard(scryfallId: 'cmd-001', name: 'Atraxa, Praetors\' Voice', quantity: 1),
          DeckCard(scryfallId: 'card-002', name: 'Sol Ring', quantity: 1),
        ],
      );

      final controller = _createController(deck: deck);
      expect(controller.getCommanderName(), 'Atraxa, Praetors\' Voice');
      controller.dispose();
    });

    test('returns empty string when commander not found in cards', () {
      final deck = _makeTestDeck(
        commanderScryfallId: 'cmd-missing',
        mainboard: [
          DeckCard(scryfallId: 'card-002', name: 'Sol Ring', quantity: 1),
        ],
      );

      final controller = _createController(deck: deck);
      // Commander ID doesn't match any card, local service has no data -> empty
      expect(controller.getCommanderName(), '');
      controller.dispose();
    });
  });

  // =================================================================
  // DeckSuggestionsController.enrichSuggestions
  // =================================================================

  group('DeckSuggestionsController.enrichSuggestions', () {
    test('filters out cards already in the deck', () {
      final deck = _makeTestDeck(
        mainboard: [
          DeckCard(scryfallId: 'id-1', name: 'Sol Ring', quantity: 1),
          DeckCard(scryfallId: 'id-2', name: 'Command Tower', quantity: 1),
        ],
      );

      final controller = _createController(deck: deck);

      final categorized = {
        'Top Cartes': [
          _makeSuggestion(name: 'Sol Ring'), // deja dans le deck
          _makeSuggestion(name: 'Arcane Signet'), // pas dans le deck
          _makeSuggestion(name: 'Command Tower'), // deja dans le deck
        ],
      };

      final enriched = controller.enrichSuggestions(categorized);

      expect(enriched['Top Cartes']!.length, 1);
      expect(enriched['Top Cartes']![0].card.name, 'Arcane Signet');

      controller.dispose();
    });

    test('creates fallback card when not found locally', () {
      final deck = _makeTestDeck(mainboard: []);

      final controller = _createController(deck: deck);

      final categorized = {
        'Creatures': [
          _makeSuggestion(name: 'Unknown Card XYZ', synergy: 0.25, inclusion: 40),
        ],
      };

      final enriched = controller.enrichSuggestions(categorized);

      expect(enriched['Creatures']!.length, 1);
      final card = enriched['Creatures']![0];
      expect(card.card.id, startsWith('edhrec_'));
      expect(card.card.typeLine, 'Suggestion externe');
      expect(card.synergy, 0.25);
      expect(card.inclusion, 40);

      controller.dispose();
    });

    test('removes empty categories', () {
      final deck = _makeTestDeck(
        mainboard: [
          DeckCard(scryfallId: 'id-1', name: 'Only Card', quantity: 1),
        ],
      );

      final controller = _createController(deck: deck);

      final categorized = {
        'Creatures': [
          _makeSuggestion(name: 'Only Card'), // will be filtered out
        ],
        'Artefacts': [
          _makeSuggestion(name: 'New Artifact'),
        ],
      };

      final enriched = controller.enrichSuggestions(categorized);

      expect(enriched.containsKey('Creatures'), false);
      expect(enriched.containsKey('Artefacts'), true);
      expect(enriched['Artefacts']!.length, 1);

      controller.dispose();
    });

    test('preserves synergy and salt values from suggestions', () {
      final deck = _makeTestDeck(mainboard: []);

      final controller = _createController(deck: deck);

      final categorized = {
        'Haute Synergie': [
          _makeSuggestion(name: 'Synergy Card', synergy: 0.42, inclusion: 85, salt: 2.5),
        ],
      };

      final enriched = controller.enrichSuggestions(categorized);
      final suggestion = enriched['Haute Synergie']![0];

      expect(suggestion.synergy, 0.42);
      expect(suggestion.inclusion, 85);
      expect(suggestion.salt, 2.5);

      controller.dispose();
    });
  });

  // =================================================================
  // DeckSuggestionsController.clearTheme
  // =================================================================

  group('DeckSuggestionsController.clearTheme', () {
    test('resets selectedTheme and themeCards to null', () {
      final deck = _makeTestDeck();

      final controller = _createController(deck: deck);

      controller.clearTheme();

      expect(controller.state.selectedTheme, isNull);
      expect(controller.state.themeCards, isNull);

      controller.dispose();
    });
  });

  // =================================================================
  // DeckSuggestionsController initial state
  // =================================================================

  group('DeckSuggestionsController initial state', () {
    test('starts with default empty state', () {
      final deck = _makeTestDeck();

      final controller = _createController(deck: deck);

      expect(controller.state.isLoading, false);
      expect(controller.state.hasLoaded, false);
      expect(controller.state.isLoadingTheme, false);
      expect(controller.state.enrichedSuggestions, isEmpty);
      expect(controller.state.commanderData, isNull);
      expect(controller.state.synergyReport, isNull);

      controller.dispose();
    });
  });
}
