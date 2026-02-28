// Tests unitaires pour DeckDetailController (Sprint 7, US-7.9)
// Teste la logique d'etat et les methodes utilitaires du controller.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_detail_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/services/collection_service.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/wishlist_service.dart';

// --- Helpers ---

Deck _makeTestDeck({
  String id = 'deck-1',
  String name = 'Test Deck',
  String format = 'Standard',
  List<DeckCard>? mainboard,
  List<DeckCard>? sideboard,
  List<DeckCard>? considering,
  List<DeckCard>? wishlist,
  String? commanderScryfallId,
  String? commanderSecondaryScryfallId,
}) {
  return Deck(
    id: id,
    name: name,
    format: format,
    mainboard: mainboard,
    sideboard: sideboard,
    considering: considering,
    wishlist: wishlist,
    commanderScryfallId: commanderScryfallId,
    commanderSecondaryScryfallId: commanderSecondaryScryfallId,
  );
}

/// Helper: creates a DeckDetailController and waits for
/// the initial async load to settle (or fail silently).
Future<DeckDetailController> _createController({
  required Deck deck,
  required DeckService deckService,
  required CollectionService collectionService,
  required WishlistService wishlistService,
}) async {
  final controller = DeckDetailController(
    initialDeck: deck,
    deckService: deckService,
    collectionService: collectionService,
    wishlistService: wishlistService,
    apiService: ScryfallApiService(),
  );
  // Let the constructor's async loadInitialData() settle.
  // The API calls will fail (no network), but the controller handles errors.
  await Future.delayed(const Duration(milliseconds: 300));
  return controller;
}

void main() {
  // ============================================================
  // DeckDetailState - Tests unitaires purs sur l'etat immutable
  // ============================================================

  group('DeckDetailState', () {
    test('initial state has correct deck data', () {
      final deck = _makeTestDeck(name: 'My Deck', format: 'Commander');
      final state = DeckDetailState(currentDeck: deck);

      expect(state.currentDeck.name, 'My Deck');
      expect(state.currentDeck.format, 'Commander');
      expect(state.isLoading, true);
      expect(state.fullCardData, isEmpty);
      expect(state.myCollection, isEmpty);
      expect(state.totalDeckPrice, 0.0);
      expect(state.isValidating, false);
      expect(state.errorMessage, isNull);
    });

    test('copyWith preserves values when no arguments given', () {
      final deck = _makeTestDeck();
      final state = DeckDetailState(
        currentDeck: deck,
        isLoading: false,
        totalDeckPrice: 42.5,
      );

      final copied = state.copyWith();
      expect(copied.currentDeck.id, 'deck-1');
      expect(copied.isLoading, false);
      expect(copied.totalDeckPrice, 42.5);
    });

    test('copyWith overrides specified values', () {
      final deck = _makeTestDeck();
      final state = DeckDetailState(currentDeck: deck);
      final updated = state.copyWith(
        isLoading: false,
        totalDeckPrice: 99.9,
        isValidating: true,
      );

      expect(updated.isLoading, false);
      expect(updated.totalDeckPrice, 99.9);
      expect(updated.isValidating, true);
      expect(updated.currentDeck.id, 'deck-1');
    });

    test('computed mainCount sums mainboard quantities', () {
      final deck = _makeTestDeck(
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'A', quantity: 4),
          DeckCard(scryfallId: 'c2', name: 'B', quantity: 2),
          DeckCard(scryfallId: 'c3', name: 'C', quantity: 1),
        ],
      );
      final state = DeckDetailState(currentDeck: deck);
      expect(state.mainCount, 7);
    });

    test('computed sideCount sums sideboard quantities', () {
      final deck = _makeTestDeck(
        sideboard: [
          DeckCard(scryfallId: 'c1', name: 'A', quantity: 3),
          DeckCard(scryfallId: 'c2', name: 'B', quantity: 2),
        ],
      );
      final state = DeckDetailState(currentDeck: deck);
      expect(state.sideCount, 5);
    });

    test('computed consCount and wishCount work', () {
      final deck = _makeTestDeck(
        considering: [DeckCard(scryfallId: 'c1', name: 'A', quantity: 2)],
        wishlist: [DeckCard(scryfallId: 'c2', name: 'B', quantity: 3)],
      );
      final state = DeckDetailState(currentDeck: deck);
      expect(state.consCount, 2);
      expect(state.wishCount, 3);
    });

    test('mainCount is 0 for empty deck', () {
      final deck = _makeTestDeck();
      final state = DeckDetailState(currentDeck: deck);
      expect(state.mainCount, 0);
      expect(state.sideCount, 0);
      expect(state.consCount, 0);
      expect(state.wishCount, 0);
    });
  });

  // ============================================================
  // DeckDetailActionResult
  // ============================================================

  group('DeckDetailActionResult', () {
    test('default values are correct', () {
      const result = DeckDetailActionResult();
      expect(result.success, true);
      expect(result.message, '');
    });

    test('custom values override defaults', () {
      const result = DeckDetailActionResult(
        success: false,
        message: 'Singleton rule violation',
      );
      expect(result.success, false);
      expect(result.message, 'Singleton rule violation');
    });
  });

  // ============================================================
  // Controller methods that need real services
  // ============================================================

  group('DeckDetailController.generateFullDeckText', () {
    late AppDatabase db;
    late DeckService deckService;
    late CollectionService collectionService;
    late WishlistService wishlistService;
    late DeckDetailController controller;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      deckService = DeckService(database: db);
      collectionService = CollectionService(database: db);
      wishlistService = WishlistService(database: db);
    });

    tearDown(() async {
      // Wait for any async work to complete before disposing
      await Future.delayed(const Duration(milliseconds: 300));
      controller.dispose();
      await db.close();
    });

    test('generates correct format with mainboard and sideboard', () async {
      final deck = _makeTestDeck(
        name: 'Burn Deck',
        format: 'Modern',
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Lightning Bolt', quantity: 4),
          DeckCard(scryfallId: 'c2', name: 'Lava Spike', quantity: 4),
        ],
        sideboard: [
          DeckCard(scryfallId: 'c3', name: 'Smash to Smithereens', quantity: 2),
        ],
      );

      controller = await _createController(
        deck: deck,
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final text = controller.generateFullDeckText();

      expect(text, contains('Deck: Burn Deck'));
      expect(text, contains('Format: Modern'));
      expect(text, contains('MAINBOARD:'));
      expect(text, contains('4 Lightning Bolt'));
      expect(text, contains('4 Lava Spike'));
      expect(text, contains('SIDEBOARD:'));
      expect(text, contains('2 Smash to Smithereens'));
    });

    test('generates text without sideboard section when sideboard is empty', () async {
      final deck = _makeTestDeck(
        name: 'Simple Deck',
        format: 'Standard',
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Plains', quantity: 20),
        ],
      );

      controller = await _createController(
        deck: deck,
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final text = controller.generateFullDeckText();

      expect(text, contains('MAINBOARD:'));
      expect(text, contains('20 Plains'));
      expect(text, isNot(contains('SIDEBOARD:')));
    });

    test('generates text with commander section', () async {
      final deck = _makeTestDeck(
        name: 'EDH Deck',
        format: 'Commander',
        commanderScryfallId: 'cmd-1',
        mainboard: [
          DeckCard(scryfallId: 'cmd-1', name: 'Atraxa', quantity: 1),
          DeckCard(scryfallId: 'c1', name: 'Sol Ring', quantity: 1),
        ],
      );

      controller = await _createController(
        deck: deck,
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final text = controller.generateFullDeckText();

      expect(text, contains('COMMANDER:'));
      expect(text, contains('MAINBOARD:'));
      expect(text, contains('1 Sol Ring'));
    });
  });

  // ============================================================
  // generateConsideringText and generateWishlistText
  // ============================================================

  group('DeckDetailController text generation helpers', () {
    late AppDatabase db;
    late DeckService deckService;
    late CollectionService collectionService;
    late WishlistService wishlistService;
    late DeckDetailController controller;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      deckService = DeckService(database: db);
      collectionService = CollectionService(database: db);
      wishlistService = WishlistService(database: db);
    });

    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      controller.dispose();
      await db.close();
    });

    test('generateConsideringText returns null when empty', () async {
      controller = await _createController(
        deck: _makeTestDeck(),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );
      expect(controller.generateConsideringText(), isNull);
    });

    test('generateConsideringText returns formatted text', () async {
      controller = await _createController(
        deck: _makeTestDeck(considering: [
          DeckCard(scryfallId: 'c1', name: 'Rhystic Study', quantity: 1),
        ]),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );
      final text = controller.generateConsideringText();
      expect(text, isNotNull);
      expect(text!, contains('Considering for:'));
      expect(text, contains('1 Rhystic Study'));
    });

    test('generateWishlistText returns null when empty', () async {
      controller = await _createController(
        deck: _makeTestDeck(),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );
      expect(controller.generateWishlistText(), isNull);
    });

    test('generateWishlistText returns formatted text', () async {
      controller = await _createController(
        deck: _makeTestDeck(wishlist: [
          DeckCard(scryfallId: 'c1', name: 'Mana Crypt', quantity: 1),
          DeckCard(scryfallId: 'c2', name: 'Force of Will', quantity: 2),
        ]),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );
      final text = controller.generateWishlistText();
      expect(text, isNotNull);
      expect(text!, contains('Wishlist for:'));
      expect(text, contains('1 Mana Crypt'));
      expect(text, contains('2 Force of Will'));
    });
  });

  // ============================================================
  // validateDeckRules
  // ============================================================

  group('DeckDetailController.validateDeckRules', () {
    late AppDatabase db;
    late DeckService deckService;
    late CollectionService collectionService;
    late WishlistService wishlistService;
    late DeckDetailController controller;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      deckService = DeckService(database: db);
      collectionService = CollectionService(database: db);
      wishlistService = WishlistService(database: db);
    });

    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      controller.dispose();
      await db.close();
    });

    test('returns validation results for all formats', () async {
      controller = await _createController(
        deck: _makeTestDeck(mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Sol Ring', quantity: 60),
        ]),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final rules = controller.validateDeckRules();

      expect(rules.containsKey('standard'), true);
      expect(rules.containsKey('pioneer'), true);
      expect(rules.containsKey('modern'), true);
      expect(rules.containsKey('commander'), true);
      expect(rules['commander'], contains('60'));
      expect(rules['Bordeciel (Whiterun)'], contains('Arrow in the knee'));
    });

    test('commander validation fails when no commander set', () async {
      controller = await _createController(
        deck: _makeTestDeck(mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Plains', quantity: 100),
        ]),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final rules = controller.validateDeckRules();
      expect(rules['commander'], contains('Cdt manquant'));
    });
  });

  // ============================================================
  // clearDeck via real service
  // ============================================================

  group('DeckDetailController.clearDeck', () {
    late AppDatabase db;
    late DeckService deckService;
    late CollectionService collectionService;
    late WishlistService wishlistService;
    late DeckDetailController controller;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      deckService = DeckService(database: db);
      collectionService = CollectionService(database: db);
      wishlistService = WishlistService(database: db);
    });

    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      controller.dispose();
      await db.close();
    });

    test('clears all cards from the deck', () async {
      await deckService.createNewDeck('Test Deck');
      final decks = await deckService.loadDecks();
      final deck = decks.first;

      await deckService.upsertCardInDeck(
        deckId: deck.id,
        scryfallId: 'c1',
        cardName: 'Sol Ring',
        quantityToAdd: 1,
      );
      await deckService.upsertCardInDeck(
        deckId: deck.id,
        scryfallId: 'c2',
        cardName: 'Mana Crypt',
        quantityToAdd: 1,
        board: DeckBoard.side,
      );

      final deckWithCards = (await deckService.loadDecks()).first;
      expect(deckWithCards.mainboard, isNotEmpty);
      expect(deckWithCards.sideboard, isNotEmpty);

      controller = await _createController(
        deck: deckWithCards,
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final result = await controller.clearDeck();

      expect(result.success, true);
      expect(controller.state.currentDeck.mainboard, isEmpty);
      expect(controller.state.currentDeck.sideboard, isEmpty);
      expect(controller.state.totalDeckPrice, 0.0);
    });
  });

  // ============================================================
  // isCommander
  // ============================================================

  group('DeckDetailController.isCommander', () {
    late AppDatabase db;
    late DeckService deckService;
    late CollectionService collectionService;
    late WishlistService wishlistService;
    late DeckDetailController controller;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      deckService = DeckService(database: db);
      collectionService = CollectionService(database: db);
      wishlistService = WishlistService(database: db);
    });

    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      controller.dispose();
      await db.close();
    });

    test('returns true for primary commander', () async {
      controller = await _createController(
        deck: _makeTestDeck(commanderScryfallId: 'cmd-1'),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final card = DeckCard(scryfallId: 'cmd-1', name: 'Commander', quantity: 1);
      expect(controller.isCommander(card), true);

      final otherCard = DeckCard(scryfallId: 'other', name: 'Other', quantity: 1);
      expect(controller.isCommander(otherCard), false);
    });

    test('returns true for secondary commander', () async {
      controller = await _createController(
        deck: _makeTestDeck(
          commanderScryfallId: 'cmd-1',
          commanderSecondaryScryfallId: 'cmd-2',
        ),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final partnerCard = DeckCard(scryfallId: 'cmd-2', name: 'Partner', quantity: 1);
      expect(controller.isCommander(partnerCard), true);
    });
  });
}
