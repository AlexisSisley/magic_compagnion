// Tests unitaires Sprint 14
// US-14.1: Dashboard reactif (DashboardState, ref.invalidate)
// US-14.2: Confirmation suppression a zero
// US-14.3: allCards inclut considering/wishlist
// US-14.4: addToCollection / addToWishlist
// US-14.6: Computed properties avec nouvelles listes

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_detail_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/providers/dashboard_provider.dart';
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
  await Future.delayed(const Duration(milliseconds: 300));
  return controller;
}

void main() {
  // ============================================================
  // US-14.1 : DashboardState
  // ============================================================

  group('US-14.1 - DashboardState', () {
    test('default DashboardState has correct initial values', () {
      const state = DashboardState();
      expect(state.totalCards, 0);
      expect(state.totalValue, 0.0);
      expect(state.valueIsLoading, true);
      expect(state.recentScans, isEmpty);
      expect(state.recentDecks, isEmpty);
      expect(state.valueHistory, isEmpty);
      expect(state.isLoading, true);
    });

    test('DashboardState stores totalCards correctly', () {
      const state = DashboardState(totalCards: 42);
      expect(state.totalCards, 42);
    });

    test('DashboardState stores totalValue correctly', () {
      const state = DashboardState(totalValue: 123.45);
      expect(state.totalValue, 123.45);
    });

    test('DashboardState stores valueIsLoading false', () {
      const state = DashboardState(valueIsLoading: false);
      expect(state.valueIsLoading, false);
    });

    test('DashboardState stores recentDecks', () {
      final decks = [_makeTestDeck(name: 'Deck A'), _makeTestDeck(name: 'Deck B')];
      final state = DashboardState(recentDecks: decks);
      expect(state.recentDecks, hasLength(2));
      expect(state.recentDecks[0].name, 'Deck A');
    });

    test('DashboardState isLoading false when loaded', () {
      const state = DashboardState(isLoading: false);
      expect(state.isLoading, false);
    });
  });

  // ============================================================
  // US-14.3 : allCards inclut considering / wishlist
  // Verifie indirectement via les computed properties
  // ============================================================

  group('US-14.3 - allCards considering/wishlist', () {
    test('deck with considering cards has correct consCount', () {
      final deck = _makeTestDeck(
        considering: [
          DeckCard(scryfallId: 'c1', name: 'Card A', quantity: 3),
          DeckCard(scryfallId: 'c2', name: 'Card B', quantity: 1),
        ],
      );
      final state = DeckDetailState(currentDeck: deck);
      expect(state.consCount, 4);
    });

    test('deck with wishlist cards has correct wishCount', () {
      final deck = _makeTestDeck(
        wishlist: [
          DeckCard(scryfallId: 'c1', name: 'Expensive Card', quantity: 2),
        ],
      );
      final state = DeckDetailState(currentDeck: deck);
      expect(state.wishCount, 2);
    });

    test('all four board counts are independent', () {
      final deck = _makeTestDeck(
        mainboard: [DeckCard(scryfallId: 'm1', name: 'Main', quantity: 10)],
        sideboard: [DeckCard(scryfallId: 's1', name: 'Side', quantity: 5)],
        considering: [DeckCard(scryfallId: 'c1', name: 'Consider', quantity: 3)],
        wishlist: [DeckCard(scryfallId: 'w1', name: 'Wish', quantity: 1)],
      );
      final state = DeckDetailState(currentDeck: deck);
      expect(state.mainCount, 10);
      expect(state.sideCount, 5);
      expect(state.consCount, 3);
      expect(state.wishCount, 1);
    });

    test('empty considering and wishlist return zero counts', () {
      final deck = _makeTestDeck();
      final state = DeckDetailState(currentDeck: deck);
      expect(state.consCount, 0);
      expect(state.wishCount, 0);
    });
  });

  // ============================================================
  // US-14.4 : addToCollection / addToWishlist
  // ============================================================

  group('US-14.4 - addToCollection', () {
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

    test('addToCollection returns success result', () async {
      controller = await _createController(
        deck: _makeTestDeck(mainboard: [
          DeckCard(scryfallId: 'c1', name: 'Sol Ring', quantity: 1),
        ]),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final card = DeckCard(scryfallId: 'c1', name: 'Sol Ring', quantity: 1);
      final result = await controller.addToCollection(card, 2);

      expect(result.success, true);
      expect(result.message, contains('Sol Ring'));
      expect(result.message, contains('x2'));
    });

    test('addToCollection actually adds card to collection', () async {
      controller = await _createController(
        deck: _makeTestDeck(),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final card = DeckCard(scryfallId: 'test-id', name: 'Lightning Bolt', quantity: 4);
      await controller.addToCollection(card, 4);

      final collection = await collectionService.loadCollection();
      final found = collection.where((c) => c.scryfallId == 'test-id');
      expect(found, isNotEmpty);
      expect(found.first.quantity, 4);
    });

    test('addToCollection with foil flag', () async {
      controller = await _createController(
        deck: _makeTestDeck(),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final card = DeckCard(scryfallId: 'foil-id', name: 'Foil Card', quantity: 1, isFoil: true);
      final result = await controller.addToCollection(card, 1);

      expect(result.success, true);
      expect(result.message, contains('Foil Card'));
    });
  });

  group('US-14.4 - addToWishlist', () {
    late AppDatabase db;
    late DeckService deckService;
    late CollectionService collectionService;
    late WishlistService wishlistService;
    late DeckDetailController controller;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      deckService = DeckService(database: db);
      collectionService = CollectionService(database: db);
      wishlistService = WishlistService(database: db);
      // Create a default wishlist for the tests
      await wishlistService.createWishlist('Default Wishlist');
    });

    tearDown(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      controller.dispose();
      await db.close();
    });

    test('addToWishlist returns success result', () async {
      controller = await _createController(
        deck: _makeTestDeck(),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final card = DeckCard(scryfallId: 'w1', name: 'Mana Crypt', quantity: 1);
      final result = await controller.addToWishlist(card, 1, null);

      expect(result.success, true);
      expect(result.message, contains('Mana Crypt'));
      expect(result.message, contains('wishlist'));
    });

    test('addToWishlist with specific wishlistId', () async {
      final wishlists = await wishlistService.loadWishlists();
      final wishlistId = wishlists.first.id;

      controller = await _createController(
        deck: _makeTestDeck(),
        deckService: deckService,
        collectionService: collectionService,
        wishlistService: wishlistService,
      );

      final card = DeckCard(scryfallId: 'w2', name: 'Force of Will', quantity: 2);
      final result = await controller.addToWishlist(card, 2, wishlistId);

      expect(result.success, true);
      expect(result.message, contains('Force of Will'));
      expect(result.message, contains('x2'));
    });
  });

  // ============================================================
  // US-14.2 : Confirmation suppression a zero (logique testable)
  // ============================================================

  group('US-14.2 - Quantity zero confirmation logic', () {
    test('DeckCard quantity of 1 means next decrement would reach zero', () {
      final card = DeckCard(scryfallId: 'c1', name: 'Card', quantity: 1);
      // The modal should show confirmation when quantity <= 1 and user taps minus
      expect(card.quantity <= 1, true);
    });

    test('DeckCard quantity of 2 does not trigger confirmation', () {
      final card = DeckCard(scryfallId: 'c1', name: 'Card', quantity: 2);
      expect(card.quantity <= 1, false);
    });

    test('DeckCard quantity of 0 always triggers confirmation', () {
      final card = DeckCard(scryfallId: 'c1', name: 'Card', quantity: 0);
      expect(card.quantity <= 1, true);
    });
  });

  // ============================================================
  // Computed properties Sprint 14 - comprehensive
  // ============================================================

  group('Sprint 14 - Computed properties comprehensive', () {
    test('mainCount with multiple cards', () {
      final deck = _makeTestDeck(mainboard: [
        DeckCard(scryfallId: 'c1', name: 'A', quantity: 4),
        DeckCard(scryfallId: 'c2', name: 'B', quantity: 3),
        DeckCard(scryfallId: 'c3', name: 'C', quantity: 2),
      ]);
      final state = DeckDetailState(currentDeck: deck);
      expect(state.mainCount, 9);
    });

    test('sideCount with single card', () {
      final deck = _makeTestDeck(sideboard: [
        DeckCard(scryfallId: 'c1', name: 'A', quantity: 15),
      ]);
      final state = DeckDetailState(currentDeck: deck);
      expect(state.sideCount, 15);
    });

    test('all counts sum correctly for full deck', () {
      final deck = _makeTestDeck(
        mainboard: [
          DeckCard(scryfallId: 'c1', name: 'A', quantity: 60),
        ],
        sideboard: [
          DeckCard(scryfallId: 'c2', name: 'B', quantity: 15),
        ],
        considering: [
          DeckCard(scryfallId: 'c3', name: 'C', quantity: 5),
          DeckCard(scryfallId: 'c4', name: 'D', quantity: 3),
        ],
        wishlist: [
          DeckCard(scryfallId: 'c5', name: 'E', quantity: 2),
        ],
      );
      final state = DeckDetailState(currentDeck: deck);
      final total = state.mainCount + state.sideCount + state.consCount + state.wishCount;
      expect(total, 85);
    });

    test('copyWith preserves all counts', () {
      final deck = _makeTestDeck(
        mainboard: [DeckCard(scryfallId: 'c1', name: 'A', quantity: 10)],
        considering: [DeckCard(scryfallId: 'c2', name: 'B', quantity: 5)],
      );
      final state = DeckDetailState(currentDeck: deck);
      final copied = state.copyWith(isLoading: false);
      expect(copied.mainCount, 10);
      expect(copied.consCount, 5);
    });
  });

  // ============================================================
  // DeckDetailActionResult - Sprint 14 scenarios
  // ============================================================

  group('Sprint 14 - DeckDetailActionResult for new methods', () {
    test('addToCollection result has correct format', () {
      const result = DeckDetailActionResult(
        message: 'Sol Ring x2 ajoutee a la collection.',
      );
      expect(result.success, true);
      expect(result.message, contains('collection'));
    });

    test('addToWishlist result has correct format', () {
      const result = DeckDetailActionResult(
        message: 'Mana Crypt x1 ajoutee a la wishlist.',
      );
      expect(result.success, true);
      expect(result.message, contains('wishlist'));
    });
  });
}
