// Fichier : lib/data/migration/migration_service.dart
// Migration transparente SharedPreferences -> drift (Sprint 4)

import 'dart:convert';
import 'dart:developer';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

class MigrationService {
  final AppDatabase _db;
  static const String _migrationCompletedKey = 'drift_migration_completed';

  MigrationService(this._db);

  /// Verifie si la migration est necessaire et l'execute si oui.
  /// Retourne true si une migration a ete effectuee, false sinon.
  Future<bool> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // Deja migre ?
    if (prefs.getBool(_migrationCompletedKey) == true) {
      log('Migration deja effectuee, on passe.', name: 'MigrationService');
      return false;
    }

    // Verifier s'il y a des donnees a migrer
    final hasData = _hasAnyData(prefs);
    if (!hasData) {
      log('Aucune donnee SharedPreferences a migrer.', name: 'MigrationService');
      await prefs.setBool(_migrationCompletedKey, true);
      return false;
    }

    log('Debut de la migration SharedPreferences -> drift...', name: 'MigrationService');

    try {
      await _migrateCollection(prefs);
      await _migrateDecks(prefs);
      await _migrateWishlists(prefs);
      await _migrateProfiles(prefs);
      await _migrateGameHistory(prefs);
      await _migrateScanHistory(prefs);
      await _migrateCollectionValueHistory(prefs);
      await _migrateSettings(prefs);

      // Marquer la migration comme terminee
      await prefs.setBool(_migrationCompletedKey, true);
      log('Migration terminee avec succes !', name: 'MigrationService');
      return true;
    } catch (e, stack) {
      log('ERREUR lors de la migration: $e', name: 'MigrationService', error: e, stackTrace: stack);
      // On ne marque PAS comme complete -> la migration sera retentee au prochain lancement
      rethrow;
    }
  }

  bool _hasAnyData(SharedPreferences prefs) {
    const keys = [
      'user_collection',
      'user_decks',
      'user_wishlists_v2',
      'user_wishlist',
      'user_profiles',
      'game_history',
      'scan_history',
    ];
    return keys.any((key) => prefs.containsKey(key));
  }

  // ============================================================
  // MIGRATION COLLECTION
  // ============================================================

  Future<void> _migrateCollection(SharedPreferences prefs) async {
    final String? collectionJson = prefs.getString('user_collection');
    if (collectionJson == null) return;

    log('Migration collection...', name: 'MigrationService');
    final List<dynamic> decodedList = json.decode(collectionJson) as List;

    for (final jsonItem in decodedList) {
      final map = jsonItem as Map<String, dynamic>;
      await _db.upsertCollectionCard(
        scryfallId: map['scryfallId'] as String,
        cardName: map['name'] as String,
        absoluteQuantity: map['quantity'] as int,
        isFoil: map['isFoil'] as bool? ?? false,
        newTags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
    }
    log('Collection migree: ${decodedList.length} cartes.', name: 'MigrationService');
  }

  // ============================================================
  // MIGRATION DECKS
  // ============================================================

  Future<void> _migrateDecks(SharedPreferences prefs) async {
    final String? decksJson = prefs.getString('user_decks');
    if (decksJson == null) return;

    log('Migration decks...', name: 'MigrationService');
    final List<dynamic> decodedList = json.decode(decksJson) as List;

    for (final jsonItem in decodedList) {
      final map = jsonItem as Map<String, dynamic>;
      final deckId = map['id'] as String;

      // Inserer le deck
      await _db.insertDeck(DecksCompanion.insert(
        id: deckId,
        name: map['name'] as String,
        format: Value(map['format'] as String? ?? 'Standard'),
        commanderScryfallId: Value(map['commanderScryfallId'] as String?),
        commanderSecondaryScryfallId: Value(map['commanderSecondaryScryfallId'] as String?),
        colors: Value(json.encode(map['colors'] ?? [])),
      ));

      // Inserer les cartes pour chaque board
      await _migrateDeckCards(deckId, 'main', map['mainboard'] as List? ?? []);
      await _migrateDeckCards(deckId, 'side', map['sideboard'] as List? ?? []);
      await _migrateDeckCards(deckId, 'considering', map['considering'] as List? ?? []);
      await _migrateDeckCards(deckId, 'wishlist', map['wishlist'] as List? ?? []);
    }
    log('Decks migres: ${decodedList.length} decks.', name: 'MigrationService');
  }

  Future<void> _migrateDeckCards(String deckId, String board, List<dynamic> cards) async {
    for (final cardJson in cards) {
      final map = cardJson as Map<String, dynamic>;
      await _db.upsertDeckCard(
        deckId: deckId,
        board: board,
        scryfallId: map['scryfallId'] as String,
        cardName: map['name'] as String,
        absoluteQuantity: map['quantity'] as int,
        newTags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isFoil: map['isFoil'] as bool? ?? false,
      );
    }
  }

  // ============================================================
  // MIGRATION WISHLISTS
  // ============================================================

  Future<void> _migrateWishlists(SharedPreferences prefs) async {
    // Gerer d'abord la migration legacy v1 -> v2 si necessaire
    if (prefs.containsKey('user_wishlist') && !prefs.containsKey('user_wishlists_v2')) {
      await _migrateLegacyWishlistToV2(prefs);
    }

    final String? wishlistsJson = prefs.getString('user_wishlists_v2');
    if (wishlistsJson == null) return;

    log('Migration wishlists...', name: 'MigrationService');
    final List<dynamic> decodedList = json.decode(wishlistsJson) as List;

    for (final jsonItem in decodedList) {
      final map = jsonItem as Map<String, dynamic>;
      final wishlistId = map['id'] as String;

      await _db.insertWishlist(WishlistsCompanion.insert(
        id: wishlistId,
        name: map['name'] as String,
        dateCreated: DateTime.parse(map['dateCreated'] ?? DateTime.now().toIso8601String()),
        iconScryfallId: Value(map['iconScryfallId'] as String?),
      ));

      final cards = map['cards'] as List? ?? [];
      for (final cardJson in cards) {
        final cardMap = cardJson as Map<String, dynamic>;
        await _db.upsertWishlistCard(
          wishlistId: wishlistId,
          scryfallId: cardMap['scryfallId'] as String,
          cardName: cardMap['name'] as String,
          absoluteQuantity: cardMap['quantity'] as int,
          isFoil: cardMap['isFoil'] as bool? ?? false,
        );
      }
    }
    log('Wishlists migrees: ${decodedList.length} wishlists.', name: 'MigrationService');
  }

  Future<void> _migrateLegacyWishlistToV2(SharedPreferences prefs) async {
    log('Migration wishlist legacy v1 -> v2...', name: 'MigrationService');
    final String? oldJson = prefs.getString('user_wishlist');
    if (oldJson == null) return;

    try {
      final List<dynamic> oldList = json.decode(oldJson);
      final newList = {
        'id': 'legacy_import',
        'name': 'Wishlist 1',
        'cards': oldList,
        'dateCreated': DateTime.now().toIso8601String(),
      };
      await prefs.setString('user_wishlists_v2', json.encode([newList]));
      await prefs.remove('user_wishlist');
    } catch (e) {
      log('Erreur migration legacy wishlist: $e', name: 'MigrationService');
    }
  }

  // ============================================================
  // MIGRATION PROFILES
  // ============================================================

  Future<void> _migrateProfiles(SharedPreferences prefs) async {
    final String? profilesJson = prefs.getString('user_profiles');
    if (profilesJson == null) return;

    log('Migration profiles...', name: 'MigrationService');
    final List<dynamic> decodedList = json.decode(profilesJson) as List;

    for (final jsonItem in decodedList) {
      final map = jsonItem as Map<String, dynamic>;
      await _db.upsertProfile(ProfilesCompanion(
        id: Value(map['id'] as String),
        name: Value(map['name'] as String),
        colorValue: Value(map['colorValue'] as int? ?? 0xFF2196F3),
        commanderScryfallId: Value(map['commanderScryfallId'] as String?),
        commanderName: Value(map['commanderName'] as String?),
        commanderArtCropUrl: Value(map['commanderArtCropUrl'] as String?),
        secondaryCommanderScryfallId: Value(map['secondaryCommanderScryfallId'] as String?),
        secondaryCommanderName: Value(map['secondaryCommanderName'] as String?),
        secondaryCommanderArtCropUrl: Value(map['secondaryCommanderArtCropUrl'] as String?),
      ));
    }
    log('Profiles migres: ${decodedList.length} profils.', name: 'MigrationService');
  }

  // ============================================================
  // MIGRATION GAME HISTORY
  // ============================================================

  Future<void> _migrateGameHistory(SharedPreferences prefs) async {
    final String? historyJson = prefs.getString('game_history');
    if (historyJson == null) return;

    log('Migration game history...', name: 'MigrationService');
    final List<dynamic> decodedList = json.decode(historyJson) as List;

    for (final jsonItem in decodedList) {
      final map = jsonItem as Map<String, dynamic>;
      await _db.insertGameHistory(GameHistoryItemsCompanion.insert(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        durationSeconds: Value(map['durationSeconds'] as int? ?? 0),
        winnerName: map['winnerName'] as String,
        format: Value(map['format'] as String? ?? 'Standard'),
        winMethod: Value(map['winMethod'] as String? ?? 'normal'),
        playerStates: Value(json.encode(map['playerStates'] ?? [])),
      ));
    }
    log('Game history migre: ${decodedList.length} parties.', name: 'MigrationService');
  }

  // ============================================================
  // MIGRATION SCAN HISTORY
  // ============================================================

  Future<void> _migrateScanHistory(SharedPreferences prefs) async {
    final String? historyJson = prefs.getString('scan_history');
    if (historyJson == null) return;

    log('Migration scan history...', name: 'MigrationService');
    final List<dynamic> decodedList = json.decode(historyJson) as List;

    for (final jsonItem in decodedList) {
      final map = jsonItem as Map<String, dynamic>;
      await _db.insertScanHistory(ScanHistoryItemsCompanion.insert(
        scryfallId: map['scryfallId'] as String,
        cardName: map['cardName'] as String,
        imagePath: Value(map['imagePath'] as String?),
        timestamp: DateTime.parse(map['timestamp'] as String),
      ));
    }
    log('Scan history migre: ${decodedList.length} scans.', name: 'MigrationService');
  }

  // ============================================================
  // MIGRATION COLLECTION VALUE HISTORY
  // ============================================================

  Future<void> _migrateCollectionValueHistory(SharedPreferences prefs) async {
    final String? historyJson = prefs.getString('collection_value_history');
    if (historyJson == null) return;

    log('Migration collection value history...', name: 'MigrationService');
    final Map<String, dynamic> history = json.decode(historyJson);

    for (final entry in history.entries) {
      await _db.recordDailyValue(entry.key, (entry.value as num).toDouble());
    }
    log('Value history migre: ${history.length} entrees.', name: 'MigrationService');
  }

  // ============================================================
  // MIGRATION SETTINGS
  // ============================================================

  Future<void> _migrateSettings(SharedPreferences prefs) async {
    log('Migration settings...', name: 'MigrationService');

    // glossaryLang (String)
    final glossaryLang = prefs.getString('glossaryLang');
    if (glossaryLang != null) {
      await _db.setSetting('glossaryLang', glossaryLang);
    }

    // playerCount (int)
    final playerCount = prefs.getInt('playerCount');
    if (playerCount != null) {
      await _db.setSettingInt('playerCount', playerCount);
    }

    // startingLife (int)
    final startingLife = prefs.getInt('startingLife');
    if (startingLife != null) {
      await _db.setSettingInt('startingLife', startingLife);
    }

    log('Settings migres.', name: 'MigrationService');
  }
}
