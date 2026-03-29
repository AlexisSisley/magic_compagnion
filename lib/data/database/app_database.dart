// Fichier : lib/data/database/app_database.dart
// Base de donnees drift pour Magic Companion (Sprint 4)
//
// ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
//   V I V R E   C A R D
// │                                                     │
//       Cette base de donnees est comme une
// │     Vivre Card : elle pointe toujours vers           │
//       les donnees de son proprietaire, peu
// │     importe la distance.                             │
//
// │     Si cette base disparait, c'est que               │
//       son proprietaire a arrete de jouer.
// │     Et ca, c'est la vraie tragedie.                  │
//
// │     "Meme si on est separes... nos Vivre Cards       │
//       brulent toujours !"  — Portgas D. Ace
// └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ============================================================
// TABLES
// Prefix "Db" sur les DataClassName pour eviter les conflits
// avec les classes metier existantes (Deck, DeckCard, etc.)
// ============================================================

/// Table des cartes de la collection
@DataClassName('DbCollectionCard')
class CollectionCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get scryfallId => text()();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get proxyQuantity => integer().withDefault(const Constant(0))();
  BoolColumn get isFoil => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
}

/// Table des decks
@DataClassName('DbDeck')
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get format => text().withDefault(const Constant('Standard'))();
  TextColumn get commanderScryfallId => text().nullable()();
  TextColumn get commanderSecondaryScryfallId => text().nullable()();
  TextColumn get colors => text().withDefault(const Constant('[]'))(); // JSON array

  @override
  Set<Column> get primaryKey => {id};
}

/// Table des cartes dans les decks
@DataClassName('DbDeckCard')
class DeckCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get board => text()(); // 'main', 'side', 'considering', 'wishlist'
  TextColumn get scryfallId => text()();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get proxyQuantity => integer().withDefault(const Constant(0))();
  BoolColumn get isFoil => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
}

/// Table des wishlists
@DataClassName('DbWishlist')
class Wishlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get dateCreated => dateTime()();
  TextColumn get iconScryfallId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table des cartes dans les wishlists
@DataClassName('DbWishlistCard')
class WishlistCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get wishlistId => text().references(Wishlists, #id)();
  TextColumn get scryfallId => text()();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get proxyQuantity => integer().withDefault(const Constant(0))();
  BoolColumn get isFoil => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
}

/// Table des profils joueurs
@DataClassName('DbProfile')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF2196F3))();
  TextColumn get commanderScryfallId => text().nullable()();
  TextColumn get commanderName => text().nullable()();
  TextColumn get commanderArtCropUrl => text().nullable()();
  TextColumn get secondaryCommanderScryfallId => text().nullable()();
  TextColumn get secondaryCommanderName => text().nullable()();
  TextColumn get secondaryCommanderArtCropUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table de l'historique des parties
@DataClassName('DbGameHistoryItem')
class GameHistoryItems extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  TextColumn get winnerName => text()();
  TextColumn get format => text().withDefault(const Constant('Standard'))();
  TextColumn get winMethod => text().withDefault(const Constant('normal'))();
  TextColumn get playerStates => text().withDefault(const Constant('[]'))(); // JSON array
  IntColumn get startingLife => integer().withDefault(const Constant(20))();
  IntColumn get playerCount => integer().withDefault(const Constant(2))();
  TextColumn get tag => text().nullable()();
  TextColumn get winnerDeckName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table de l'historique des scans
@DataClassName('DbScanHistoryItem')
class ScanHistoryItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get scryfallId => text()();
  TextColumn get cardName => text()();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
}

/// Table de l'historique de valeur de la collection
@DataClassName('DbCollectionValueEntry')
class CollectionValueHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text().unique()();
  RealColumn get totalValue => real()();
}

/// Table des parametres de l'application
@DataClassName('DbAppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Table des formats de jeu
@DataClassName('DbGameFormat')
class GameFormats extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get startingLife => integer().withDefault(const Constant(20))();
  IntColumn get minPlayers => integer().withDefault(const Constant(2))();
  IntColumn get maxPlayers => integer().withDefault(const Constant(8))();
  IntColumn get maxCommanders => integer().withDefault(const Constant(0))();
  TextColumn get enabledCounterIds => text().withDefault(const Constant('[]'))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table des types de compteurs
@DataClassName('DbCounterType')
class CounterTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('🔢'))();
  IntColumn get color => integer().withDefault(const Constant(0xFFFFFFFF))();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get maxValue => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table des configs joueurs (owner/guest)
@DataClassName('DbPlayerConfig')
class PlayerConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('guest'))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF2196F3))();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get linkedDeckId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table des commanders par config joueur
@DataClassName('DbPlayerConfigCommander')
class PlayerConfigCommanders extends Table {
  TextColumn get id => text()();
  TextColumn get playerConfigId => text().references(PlayerConfigs, #id)();
  TextColumn get name => text()();
  TextColumn get scryfallId => text().nullable()();
  TextColumn get artCropUrl => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================
// DATABASE
// ============================================================

@DriftDatabase(tables: [
  CollectionCards,
  Decks,
  DeckCards,
  Wishlists,
  WishlistCards,
  Profiles,
  GameHistoryItems,
  ScanHistoryItems,
  CollectionValueHistory,
  AppSettings,
  GameFormats,
  CounterTypes,
  PlayerConfigs,
  PlayerConfigCommanders,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(gameFormats);
          await m.createTable(counterTypes);
          await m.createTable(playerConfigs);
          await m.createTable(playerConfigCommanders);
          await m.addColumn(gameHistoryItems, gameHistoryItems.startingLife);
          await m.addColumn(gameHistoryItems, gameHistoryItems.playerCount);
          await m.addColumn(gameHistoryItems, gameHistoryItems.tag);
          await m.addColumn(gameHistoryItems, gameHistoryItems.winnerDeckName);
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'magic_companion');
  }

  // ============================================================
  // COLLECTION DAO METHODS
  // ============================================================

  Future<List<DbCollectionCard>> getAllCollectionCards() =>
      select(collectionCards).get();

  Future<void> upsertCollectionCard({
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    bool isFoil = false,
    List<String>? newTags,
  }) async {
    final existing = await (select(collectionCards)
          ..where((c) => c.scryfallId.equals(scryfallId) & c.isFoil.equals(isFoil)))
        .getSingleOrNull();

    if (existing != null) {
      int newQuantity = existing.quantity;
      if (quantityToAdd != null) {
        newQuantity += quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      final List<String> tags = newTags ?? decodeTags(existing.tags);

      if (newQuantity <= 0) {
        await (delete(collectionCards)..where((c) => c.id.equals(existing.id))).go();
      } else {
        await (update(collectionCards)..where((c) => c.id.equals(existing.id))).write(
          CollectionCardsCompanion(
            quantity: Value(newQuantity),
            tags: Value(json.encode(tags)),
          ),
        );
      }
    } else {
      int newQuantity = 0;
      if (quantityToAdd != null) {
        newQuantity = quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity > 0) {
        await into(collectionCards).insert(CollectionCardsCompanion.insert(
          scryfallId: scryfallId,
          name: cardName,
          quantity: Value(newQuantity),
          isFoil: Value(isFoil),
          tags: Value(json.encode(newTags ?? [])),
        ));
      }
    }
  }

  Future<void> clearCollection() async {
    await delete(collectionCards).go();
  }

  Future<List<String>> getAllUniqueCollectionTags() async {
    final cards = await select(collectionCards).get();
    final Set<String> allTags = {};
    for (final card in cards) {
      allTags.addAll(decodeTags(card.tags));
    }
    return allTags.toList()..sort();
  }

  Future<void> recordDailyValue(String dateKey, double value) async {
    // Upsert manuel sur date_key (la contrainte UNIQUE est sur date_key, pas sur id)
    final existing = await (select(collectionValueHistory)
          ..where((t) => t.dateKey.equals(dateKey)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(collectionValueHistory)
            ..where((t) => t.id.equals(existing.id)))
          .write(CollectionValueHistoryCompanion(
        totalValue: Value(value),
      ));
    } else {
      await into(collectionValueHistory).insert(
        CollectionValueHistoryCompanion.insert(
          dateKey: dateKey,
          totalValue: value,
        ),
      );
    }

    // Nettoyage > 30 jours
    final all = await (select(collectionValueHistory)
          ..orderBy([(t) => OrderingTerm.asc(t.dateKey)]))
        .get();
    if (all.length > 30) {
      final toDelete = all.sublist(0, all.length - 30);
      for (final entry in toDelete) {
        await (delete(collectionValueHistory)..where((t) => t.id.equals(entry.id))).go();
      }
    }
  }

  Future<Map<String, double>?> getCollectionEvolution(int daysAgo) async {
    final all = await (select(collectionValueHistory)
          ..orderBy([(t) => OrderingTerm.asc(t.dateKey)]))
        .get();

    if (all.isEmpty) return null;

    final double currentValue = all.last.totalValue;
    int targetIndex = all.length - 1 - daysAgo;
    if (targetIndex < 0) targetIndex = 0;
    final double pastValue = all[targetIndex].totalValue;
    final double diffValue = currentValue - pastValue;
    final double diffPercentage = pastValue > 0 ? (diffValue / pastValue) * 100 : 0.0;

    return {
      'currentValue': currentValue,
      'pastValue': pastValue,
      'diffValue': diffValue,
      'diffPercentage': diffPercentage,
    };
  }

  /// Retourne tous les points de valeur historiques, tries par date.
  /// Utilise pour le graphique d'evolution de la collection (US-14.7).
  Future<List<DbCollectionValueEntry>> getCollectionValueHistory() async {
    return (select(collectionValueHistory)
          ..orderBy([(t) => OrderingTerm.asc(t.dateKey)]))
        .get();
  }

  // ============================================================
  // DECK DAO METHODS
  // ============================================================

  Future<List<DbDeck>> getAllDecksRaw() => select(decks).get();

  Future<List<DbDeckCard>> getDeckCardsByDeckId(String deckId) =>
      (select(deckCards)..where((c) => c.deckId.equals(deckId))).get();

  Future<void> insertDeck(DecksCompanion deck) async {
    await into(decks).insert(deck);
  }

  Future<void> updateDeckEntry(String deckId, DecksCompanion companion) async {
    await (update(decks)..where((d) => d.id.equals(deckId))).write(companion);
  }

  Future<void> deleteDeckAndCards(String deckId) async {
    await (delete(deckCards)..where((c) => c.deckId.equals(deckId))).go();
    await (delete(decks)..where((d) => d.id.equals(deckId))).go();
  }

  Future<void> upsertDeckCard({
    required String deckId,
    required String board,
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    List<String>? newTags,
    bool? isFoil,
  }) async {
    final existing = await (select(deckCards)
          ..where((c) =>
              c.deckId.equals(deckId) &
              c.board.equals(board) &
              c.scryfallId.equals(scryfallId)))
        .getSingleOrNull();

    if (existing != null) {
      int newQuantity = existing.quantity;
      if (quantityToAdd != null) {
        newQuantity += quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity <= 0) {
        await (delete(deckCards)..where((c) => c.id.equals(existing.id))).go();
      } else {
        await (update(deckCards)..where((c) => c.id.equals(existing.id))).write(
          DeckCardsCompanion(
            quantity: Value(newQuantity),
            tags: newTags != null ? Value(json.encode(newTags)) : const Value.absent(),
            isFoil: isFoil != null ? Value(isFoil) : const Value.absent(),
          ),
        );
      }
    } else {
      int newQuantity = 0;
      if (quantityToAdd != null) {
        newQuantity = quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity > 0) {
        await into(deckCards).insert(DeckCardsCompanion.insert(
          deckId: deckId,
          board: board,
          scryfallId: scryfallId,
          name: cardName,
          quantity: Value(newQuantity),
          isFoil: Value(isFoil ?? false),
          tags: Value(json.encode(newTags ?? [])),
        ));
      }
    }
  }

  Future<void> clearDeckCards(String deckId) async {
    await (delete(deckCards)..where((c) => c.deckId.equals(deckId))).go();
  }

  // ============================================================
  // WISHLIST DAO METHODS
  // ============================================================

  Future<List<DbWishlist>> getAllWishlistsRaw() => select(wishlists).get();

  Future<List<DbWishlistCard>> getWishlistCardsByWishlistId(String wishlistId) =>
      (select(wishlistCards)..where((c) => c.wishlistId.equals(wishlistId))).get();

  Future<void> insertWishlist(WishlistsCompanion wishlist) async {
    await into(wishlists).insert(wishlist);
  }

  Future<void> updateWishlistEntry(String wishlistId, WishlistsCompanion companion) async {
    await (update(wishlists)..where((w) => w.id.equals(wishlistId))).write(companion);
  }

  Future<void> deleteWishlistAndCards(String wishlistId) async {
    await (delete(wishlistCards)..where((c) => c.wishlistId.equals(wishlistId))).go();
    await (delete(wishlists)..where((w) => w.id.equals(wishlistId))).go();
  }

  Future<void> clearWishlistCardEntries(String wishlistId) async {
    await (delete(wishlistCards)..where((c) => c.wishlistId.equals(wishlistId))).go();
  }

  Future<void> upsertWishlistCard({
    required String wishlistId,
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    bool? isFoil,
  }) async {
    final existing = await (select(wishlistCards)
          ..where((c) =>
              c.wishlistId.equals(wishlistId) &
              c.scryfallId.equals(scryfallId)))
        .getSingleOrNull();

    if (existing != null) {
      int newQuantity = existing.quantity;
      if (quantityToAdd != null) {
        newQuantity += quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity <= 0) {
        await (delete(wishlistCards)..where((c) => c.id.equals(existing.id))).go();
      } else {
        await (update(wishlistCards)..where((c) => c.id.equals(existing.id))).write(
          WishlistCardsCompanion(
            quantity: Value(newQuantity),
            isFoil: isFoil != null ? Value(isFoil) : const Value.absent(),
          ),
        );
      }
    } else {
      int newQuantity = 0;
      if (quantityToAdd != null) {
        newQuantity = quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity > 0) {
        await into(wishlistCards).insert(WishlistCardsCompanion.insert(
          wishlistId: wishlistId,
          scryfallId: scryfallId,
          name: cardName,
          quantity: Value(newQuantity),
          isFoil: Value(isFoil ?? false),
        ));
      }
    }
  }

  // ============================================================
  // PROFILE DAO METHODS
  // ============================================================

  Future<List<DbProfile>> getAllProfiles() => select(profiles).get();

  Future<void> upsertProfile(ProfilesCompanion profile) async {
    await into(profiles).insertOnConflictUpdate(profile);
  }

  Future<void> deleteProfile(String profileId) async {
    await (delete(profiles)..where((p) => p.id.equals(profileId))).go();
  }

  // ============================================================
  // GAME HISTORY DAO METHODS
  // ============================================================

  Future<List<DbGameHistoryItem>> getAllGameHistory() =>
      (select(gameHistoryItems)..orderBy([(t) => OrderingTerm.desc(t.date)])).get();

  Future<void> insertGameHistory(GameHistoryItemsCompanion item) async {
    await into(gameHistoryItems).insert(item);
  }

  Future<void> clearGameHistory() async {
    await delete(gameHistoryItems).go();
  }

  // ============================================================
  // SCAN HISTORY DAO METHODS
  // ============================================================

  static const int _maxScanHistoryItems = 50;

  Future<List<DbScanHistoryItem>> getAllScanHistory() =>
      (select(scanHistoryItems)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();

  Future<void> insertScanHistory(ScanHistoryItemsCompanion item) async {
    await into(scanHistoryItems).insert(item);

    // Limiter a 50 items
    final all = await (select(scanHistoryItems)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
    if (all.length > _maxScanHistoryItems) {
      final toRemove = all.sublist(_maxScanHistoryItems);
      for (final entry in toRemove) {
        await (delete(scanHistoryItems)..where((t) => t.id.equals(entry.id))).go();
      }
    }
  }

  Future<void> clearScanHistory() async {
    await delete(scanHistoryItems).go();
  }

  // ============================================================
  // APP SETTINGS DAO METHODS
  // ============================================================

  Future<String?> getSetting(String key) async {
    final result = await (select(appSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return result?.value;
  }

  Future<int?> getSettingInt(String key) async {
    final val = await getSetting(key);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> setSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<void> setSettingInt(String key, int value) async {
    await setSetting(key, value.toString());
  }

  // ============================================================
  // GAME FORMATS DAO
  // ============================================================

  Future<List<DbGameFormat>> getAllGameFormats() => select(gameFormats).get();

  Future<void> upsertGameFormat(GameFormatsCompanion format) async {
    await into(gameFormats).insertOnConflictUpdate(format);
  }

  Future<void> deleteGameFormat(String id) async {
    await (delete(gameFormats)..where((f) => f.id.equals(id))).go();
  }

  // ============================================================
  // COUNTER TYPES DAO
  // ============================================================

  Future<List<DbCounterType>> getAllCounterTypes() => select(counterTypes).get();

  Future<void> upsertCounterType(CounterTypesCompanion counter) async {
    await into(counterTypes).insertOnConflictUpdate(counter);
  }

  Future<void> deleteCounterType(String id) async {
    await (delete(counterTypes)..where((c) => c.id.equals(id))).go();
  }

  // ============================================================
  // PLAYER CONFIGS DAO
  // ============================================================

  Future<List<DbPlayerConfig>> getAllPlayerConfigs() => select(playerConfigs).get();

  Future<void> upsertPlayerConfig(PlayerConfigsCompanion config) async {
    await into(playerConfigs).insertOnConflictUpdate(config);
  }

  Future<void> deletePlayerConfig(String id) async {
    await (delete(playerConfigCommanders)..where((c) => c.playerConfigId.equals(id))).go();
    await (delete(playerConfigs)..where((p) => p.id.equals(id))).go();
  }

  Future<List<DbPlayerConfigCommander>> getCommandersForConfig(String configId) =>
      (select(playerConfigCommanders)
        ..where((c) => c.playerConfigId.equals(configId))
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .get();

  Future<void> insertPlayerConfigCommander(PlayerConfigCommandersCompanion commander) async {
    await into(playerConfigCommanders).insertOnConflictUpdate(commander);
  }

  Future<void> clearCommandersForConfig(String configId) async {
    await (delete(playerConfigCommanders)..where((c) => c.playerConfigId.equals(configId))).go();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static List<String> decodeTags(String tagsJson) {
    try {
      return (json.decode(tagsJson) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
}
