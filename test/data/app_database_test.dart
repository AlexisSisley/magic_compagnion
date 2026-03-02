// Tests d'intégration pour la base de données drift (Sprint 4)
// Utilise une base in-memory pour les tests

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';

AppDatabase _createTestDb() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ============================================================
  // COLLECTION TESTS
  // ============================================================

  group('Collection DAO', () {
    test('getAllCollectionCards returns empty initially', () async {
      final cards = await db.getAllCollectionCards();
      expect(cards, isEmpty);
    });

    test('upsertCollectionCard adds a new card', () async {
      await db.upsertCollectionCard(
        scryfallId: 'bolt-123',
        cardName: 'Lightning Bolt',
        quantityToAdd: 4,
      );

      final cards = await db.getAllCollectionCards();
      expect(cards, hasLength(1));
      expect(cards.first.scryfallId, 'bolt-123');
      expect(cards.first.name, 'Lightning Bolt');
      expect(cards.first.quantity, 4);
      expect(cards.first.isFoil, false);
    });

    test('upsertCollectionCard updates quantity for existing card', () async {
      await db.upsertCollectionCard(
        scryfallId: 'bolt-123',
        cardName: 'Lightning Bolt',
        quantityToAdd: 2,
      );
      await db.upsertCollectionCard(
        scryfallId: 'bolt-123',
        cardName: 'Lightning Bolt',
        quantityToAdd: 3,
      );

      final cards = await db.getAllCollectionCards();
      expect(cards, hasLength(1));
      expect(cards.first.quantity, 5);
    });

    test('upsertCollectionCard removes card when quantity reaches 0', () async {
      await db.upsertCollectionCard(
        scryfallId: 'bolt-123',
        cardName: 'Lightning Bolt',
        absoluteQuantity: 2,
      );
      await db.upsertCollectionCard(
        scryfallId: 'bolt-123',
        cardName: 'Lightning Bolt',
        absoluteQuantity: 0,
      );

      final cards = await db.getAllCollectionCards();
      expect(cards, isEmpty);
    });

    test('foil and non-foil are separate entries', () async {
      await db.upsertCollectionCard(
        scryfallId: 'bolt-123',
        cardName: 'Lightning Bolt',
        quantityToAdd: 4,
        isFoil: false,
      );
      await db.upsertCollectionCard(
        scryfallId: 'bolt-123',
        cardName: 'Lightning Bolt',
        quantityToAdd: 1,
        isFoil: true,
      );

      final cards = await db.getAllCollectionCards();
      expect(cards, hasLength(2));
      final nonFoil = cards.firstWhere((c) => !c.isFoil);
      final foil = cards.firstWhere((c) => c.isFoil);
      expect(nonFoil.quantity, 4);
      expect(foil.quantity, 1);
    });

    test('tags are stored and retrieved correctly', () async {
      await db.upsertCollectionCard(
        scryfallId: 'bolt-123',
        cardName: 'Lightning Bolt',
        quantityToAdd: 1,
        newTags: ['Burn', 'Staple'],
      );

      final cards = await db.getAllCollectionCards();
      final tags = AppDatabase.decodeTags(cards.first.tags);
      expect(tags, ['Burn', 'Staple']);
    });

    test('clearCollection removes all cards', () async {
      await db.upsertCollectionCard(scryfallId: 'a', cardName: 'A', quantityToAdd: 1);
      await db.upsertCollectionCard(scryfallId: 'b', cardName: 'B', quantityToAdd: 2);
      await db.clearCollection();

      final cards = await db.getAllCollectionCards();
      expect(cards, isEmpty);
    });

    test('getAllUniqueCollectionTags returns sorted unique tags', () async {
      await db.upsertCollectionCard(scryfallId: 'a', cardName: 'A', quantityToAdd: 1, newTags: ['Ramp', 'Draw']);
      await db.upsertCollectionCard(scryfallId: 'b', cardName: 'B', quantityToAdd: 1, newTags: ['Draw', 'Removal']);

      final tags = await db.getAllUniqueCollectionTags();
      expect(tags, ['Draw', 'Ramp', 'Removal']);
    });
  });

  // ============================================================
  // COLLECTION VALUE HISTORY TESTS
  // ============================================================

  group('Collection Value History', () {
    test('recordDailyValue and getCollectionEvolution', () async {
      await db.recordDailyValue('2026-02-20', 100.0);
      await db.recordDailyValue('2026-02-25', 120.0);
      await db.recordDailyValue('2026-02-27', 150.0);

      final evolution = await db.getCollectionEvolution(1);
      expect(evolution, isNotNull);
      expect(evolution!['currentValue'], 150.0);
      expect(evolution['pastValue'], 120.0);
      expect(evolution['diffValue'], 30.0);
    });

    test('getCollectionEvolution returns null when empty', () async {
      final evolution = await db.getCollectionEvolution(7);
      expect(evolution, isNull);
    });

    test('recordDailyValue limits to 30 entries', () async {
      for (int i = 0; i < 35; i++) {
        await db.recordDailyValue('2026-01-${(i + 1).toString().padLeft(2, '0')}', i * 10.0);
      }

      final all = await (db.select(db.collectionValueHistory)
            ..orderBy([(t) => OrderingTerm.asc(t.dateKey)]))
          .get();
      expect(all.length, 30);
    });

    test('recordDailyValue double call same dateKey updates without exception', () async {
      // First insert
      await db.recordDailyValue('2026-02-28', 100.0);
      // Second insert with same dateKey should update, not throw
      await db.recordDailyValue('2026-02-28', 200.0);

      final all = await (db.select(db.collectionValueHistory)
            ..where((t) => t.dateKey.equals('2026-02-28')))
          .get();
      expect(all.length, 1);
      expect(all.first.totalValue, 200.0);
    });

    test('recordDailyValue with 31+ entries cleans old ones', () async {
      // Insert exactly 31 entries
      for (int i = 1; i <= 31; i++) {
        await db.recordDailyValue('2026-03-${i.toString().padLeft(2, '0')}', i * 5.0);
      }

      final all = await (db.select(db.collectionValueHistory)
            ..orderBy([(t) => OrderingTerm.asc(t.dateKey)]))
          .get();
      expect(all.length, 30);
      // The oldest entry (2026-03-01) should have been cleaned
      expect(all.first.dateKey, '2026-03-02');
      // The newest entry should still be present
      expect(all.last.dateKey, '2026-03-31');
      expect(all.last.totalValue, 155.0);
    });
  });

  // ============================================================
  // DECK TESTS
  // ============================================================

  group('Deck DAO', () {
    test('insert and retrieve a deck', () async {
      await db.insertDeck(DecksCompanion.insert(
        id: 'deck-1',
        name: 'Test Deck',
      ));

      final decks = await db.getAllDecksRaw();
      expect(decks, hasLength(1));
      expect(decks.first.name, 'Test Deck');
      expect(decks.first.format, 'Standard');
    });

    test('upsertDeckCard adds card to correct board', () async {
      await db.insertDeck(DecksCompanion.insert(id: 'deck-1', name: 'Test'));

      await db.upsertDeckCard(
        deckId: 'deck-1',
        board: 'main',
        scryfallId: 'card-1',
        cardName: 'Sol Ring',
        quantityToAdd: 1,
      );
      await db.upsertDeckCard(
        deckId: 'deck-1',
        board: 'side',
        scryfallId: 'card-2',
        cardName: 'Swords',
        quantityToAdd: 2,
      );

      final mainCards = await db.getDeckCardsByDeckId('deck-1');
      final mainOnly = mainCards.where((c) => c.board == 'main').toList();
      final sideOnly = mainCards.where((c) => c.board == 'side').toList();
      expect(mainOnly, hasLength(1));
      expect(sideOnly, hasLength(1));
      expect(mainOnly.first.name, 'Sol Ring');
      expect(sideOnly.first.name, 'Swords');
    });

    test('deleteDeckAndCards removes deck and all its cards', () async {
      await db.insertDeck(DecksCompanion.insert(id: 'deck-1', name: 'Test'));
      await db.upsertDeckCard(deckId: 'deck-1', board: 'main', scryfallId: 'c1', cardName: 'Card', quantityToAdd: 1);

      await db.deleteDeckAndCards('deck-1');

      expect(await db.getAllDecksRaw(), isEmpty);
      expect(await db.getDeckCardsByDeckId('deck-1'), isEmpty);
    });

    test('updateDeckEntry updates commander and format', () async {
      await db.insertDeck(DecksCompanion.insert(id: 'deck-1', name: 'Test'));

      await db.updateDeckEntry('deck-1', const DecksCompanion(
        commanderScryfallId: Value('cmd-1'),
        format: Value('Commander'),
      ));

      final deck = (await db.getAllDecksRaw()).first;
      expect(deck.commanderScryfallId, 'cmd-1');
      expect(deck.format, 'Commander');
    });

    test('clearDeckCards removes only cards, not the deck', () async {
      await db.insertDeck(DecksCompanion.insert(id: 'deck-1', name: 'Test'));
      await db.upsertDeckCard(deckId: 'deck-1', board: 'main', scryfallId: 'c1', cardName: 'A', quantityToAdd: 1);
      await db.upsertDeckCard(deckId: 'deck-1', board: 'side', scryfallId: 'c2', cardName: 'B', quantityToAdd: 2);

      await db.clearDeckCards('deck-1');

      expect(await db.getAllDecksRaw(), hasLength(1));
      expect(await db.getDeckCardsByDeckId('deck-1'), isEmpty);
    });
  });

  // ============================================================
  // WISHLIST TESTS
  // ============================================================

  group('Wishlist DAO', () {
    test('insert and retrieve wishlists', () async {
      await db.insertWishlist(WishlistsCompanion.insert(
        id: 'wl-1',
        name: 'Ma Wishlist',
        dateCreated: DateTime(2026, 2, 27),
      ));

      final wishlists = await db.getAllWishlistsRaw();
      expect(wishlists, hasLength(1));
      expect(wishlists.first.name, 'Ma Wishlist');
    });

    test('upsertWishlistCard adds and updates cards', () async {
      await db.insertWishlist(WishlistsCompanion.insert(
        id: 'wl-1', name: 'Test', dateCreated: DateTime.now(),
      ));

      await db.upsertWishlistCard(wishlistId: 'wl-1', scryfallId: 'card-1', cardName: 'Force of Will', quantityToAdd: 1);
      await db.upsertWishlistCard(wishlistId: 'wl-1', scryfallId: 'card-1', cardName: 'Force of Will', quantityToAdd: 2);

      final cards = await db.getWishlistCardsByWishlistId('wl-1');
      expect(cards, hasLength(1));
      expect(cards.first.quantity, 3);
    });

    test('deleteWishlistAndCards removes both', () async {
      await db.insertWishlist(WishlistsCompanion.insert(id: 'wl-1', name: 'Test', dateCreated: DateTime.now()));
      await db.upsertWishlistCard(wishlistId: 'wl-1', scryfallId: 'c1', cardName: 'Card', quantityToAdd: 1);

      await db.deleteWishlistAndCards('wl-1');

      expect(await db.getAllWishlistsRaw(), isEmpty);
      expect(await db.getWishlistCardsByWishlistId('wl-1'), isEmpty);
    });

    test('clearWishlistCardEntries keeps wishlist but removes cards', () async {
      await db.insertWishlist(WishlistsCompanion.insert(id: 'wl-1', name: 'Test', dateCreated: DateTime.now()));
      await db.upsertWishlistCard(wishlistId: 'wl-1', scryfallId: 'c1', cardName: 'A', quantityToAdd: 1);

      await db.clearWishlistCardEntries('wl-1');

      expect(await db.getAllWishlistsRaw(), hasLength(1));
      expect(await db.getWishlistCardsByWishlistId('wl-1'), isEmpty);
    });
  });

  // ============================================================
  // PROFILE TESTS
  // ============================================================

  group('Profile DAO', () {
    test('upsert and retrieve profiles', () async {
      await db.upsertProfile(const ProfilesCompanion(
        id: Value('p-1'),
        name: Value('Alexis'),
        colorValue: Value(0xFF4CAF50),
        commanderName: Value('Atraxa'),
      ));

      final profiles = await db.getAllProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.name, 'Alexis');
      expect(profiles.first.commanderName, 'Atraxa');
    });

    test('upsert updates existing profile', () async {
      await db.upsertProfile(const ProfilesCompanion(
        id: Value('p-1'),
        name: Value('Old Name'),
      ));
      await db.upsertProfile(const ProfilesCompanion(
        id: Value('p-1'),
        name: Value('New Name'),
      ));

      final profiles = await db.getAllProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.name, 'New Name');
    });

    test('deleteProfile removes the correct profile', () async {
      await db.upsertProfile(const ProfilesCompanion(id: Value('p-1'), name: Value('A')));
      await db.upsertProfile(const ProfilesCompanion(id: Value('p-2'), name: Value('B')));

      await db.deleteProfile('p-1');

      final profiles = await db.getAllProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.id, 'p-2');
    });
  });

  // ============================================================
  // GAME HISTORY TESTS
  // ============================================================

  group('Game History DAO', () {
    test('insert and retrieve game history', () async {
      await db.insertGameHistory(GameHistoryItemsCompanion.insert(
        id: 'game-1',
        date: DateTime(2026, 2, 27),
        winnerName: 'Alexis',
        playerStates: const Value('[]'),
      ));

      final history = await db.getAllGameHistory();
      expect(history, hasLength(1));
      expect(history.first.winnerName, 'Alexis');
    });

    test('clearGameHistory removes all entries', () async {
      await db.insertGameHistory(GameHistoryItemsCompanion.insert(
        id: 'g-1', date: DateTime.now(), winnerName: 'A',
      ));
      await db.insertGameHistory(GameHistoryItemsCompanion.insert(
        id: 'g-2', date: DateTime.now(), winnerName: 'B',
      ));

      await db.clearGameHistory();
      expect(await db.getAllGameHistory(), isEmpty);
    });
  });

  // ============================================================
  // SCAN HISTORY TESTS
  // ============================================================

  group('Scan History DAO', () {
    test('insert and retrieve scan history', () async {
      await db.insertScanHistory(ScanHistoryItemsCompanion.insert(
        scryfallId: 'card-1',
        cardName: 'Lightning Bolt',
        timestamp: DateTime(2026, 2, 27),
      ));

      final history = await db.getAllScanHistory();
      expect(history, hasLength(1));
      expect(history.first.cardName, 'Lightning Bolt');
    });

    test('scan history limited to 50 items', () async {
      for (int i = 0; i < 55; i++) {
        await db.insertScanHistory(ScanHistoryItemsCompanion.insert(
          scryfallId: 'card-$i',
          cardName: 'Card $i',
          timestamp: DateTime(2026, 1, 1).add(Duration(hours: i)),
        ));
      }

      final history = await db.getAllScanHistory();
      expect(history.length, 50);
    });

    test('clearScanHistory removes all', () async {
      await db.insertScanHistory(ScanHistoryItemsCompanion.insert(
        scryfallId: 'c-1', cardName: 'A', timestamp: DateTime.now(),
      ));
      await db.clearScanHistory();

      expect(await db.getAllScanHistory(), isEmpty);
    });
  });

  // ============================================================
  // APP SETTINGS TESTS
  // ============================================================

  group('App Settings', () {
    test('set and get string setting', () async {
      await db.setSetting('glossaryLang', 'fr');
      final val = await db.getSetting('glossaryLang');
      expect(val, 'fr');
    });

    test('set and get int setting', () async {
      await db.setSettingInt('playerCount', 4);
      final val = await db.getSettingInt('playerCount');
      expect(val, 4);
    });

    test('getSetting returns null for missing key', () async {
      final val = await db.getSetting('nonexistent');
      expect(val, isNull);
    });

    test('setSetting overwrites existing value', () async {
      await db.setSetting('key', 'old');
      await db.setSetting('key', 'new');
      expect(await db.getSetting('key'), 'new');
    });
  });
}
