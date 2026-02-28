// Fichier : lib/services/backup_service.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../data/database/app_database.dart';

class BackupService {
  static const List<String> _dataKeys = [
    'user_collection',
    'user_decks',
    'user_wishlists_v2',
    'user_wishlist',
    'scan_history',
    'glossaryLang',
    'playerCount',  // C'est un int
    'startingLife'  // C'est un int
  ];

  final AppDatabase? _db;

  BackupService({AppDatabase? database}) : _db = database;

  /// 1. Genere la chaine JSON de sauvegarde
  Future<String> generateBackupJson() async {
    if (_db != null) {
      return _generateBackupFromDrift();
    }
    return _generateBackupFromSharedPrefs();
  }

  Future<String> _generateBackupFromDrift() async {
    final Map<String, dynamic> backupData = {};

    // Collection
    final collectionCards = await _db!.getAllCollectionCards();
    if (collectionCards.isNotEmpty) {
      backupData['user_collection'] = collectionCards.map((c) => {
        'scryfallId': c.scryfallId,
        'name': c.name,
        'quantity': c.quantity,
        'proxyQuantity': c.proxyQuantity,
        'isFoil': c.isFoil,
        'tags': json.decode(c.tags),
      }).toList();
    }

    // Decks
    final decks = await _db.getAllDecksRaw();
    if (decks.isNotEmpty) {
      final List<Map<String, dynamic>> decksList = [];
      for (final deck in decks) {
        final cards = await _db.getDeckCardsByDeckId(deck.id);
        final Map<String, List<Map<String, dynamic>>> boards = {
          'mainboard': [],
          'sideboard': [],
          'considering': [],
          'wishlist': [],
        };
        for (final card in cards) {
          final String boardKey;
          switch (card.board) {
            case 'main': boardKey = 'mainboard';
            case 'side': boardKey = 'sideboard';
            default: boardKey = card.board;
          }
          (boards[boardKey] ??= []).add({
            'scryfallId': card.scryfallId,
            'name': card.name,
            'quantity': card.quantity,
            'proxyQuantity': card.proxyQuantity,
            'isFoil': card.isFoil,
            'tags': json.decode(card.tags),
          });
        }
        decksList.add({
          'id': deck.id,
          'name': deck.name,
          'format': deck.format,
          'commanderScryfallId': deck.commanderScryfallId,
          'commanderSecondaryScryfallId': deck.commanderSecondaryScryfallId,
          'colors': json.decode(deck.colors),
          'mainboard': boards['mainboard'],
          'sideboard': boards['sideboard'],
          'considering': boards['considering'],
          'wishlist': boards['wishlist'],
        });
      }
      backupData['user_decks'] = decksList;
    }

    // Wishlists
    final wishlists = await _db.getAllWishlistsRaw();
    if (wishlists.isNotEmpty) {
      final List<Map<String, dynamic>> wishlistsList = [];
      for (final w in wishlists) {
        final cards = await _db.getWishlistCardsByWishlistId(w.id);
        wishlistsList.add({
          'id': w.id,
          'name': w.name,
          'dateCreated': w.dateCreated.toIso8601String(),
          'iconScryfallId': w.iconScryfallId,
          'cards': cards.map((c) => {
            'scryfallId': c.scryfallId,
            'name': c.name,
            'quantity': c.quantity,
            'proxyQuantity': c.proxyQuantity,
            'isFoil': c.isFoil,
            'tags': json.decode(c.tags),
          }).toList(),
        });
      }
      backupData['user_wishlists_v2'] = wishlistsList;
    }

    // Scan history
    final scans = await _db.getAllScanHistory();
    if (scans.isNotEmpty) {
      backupData['scan_history'] = scans.map((s) => {
        'scryfallId': s.scryfallId,
        'cardName': s.cardName,
        'imagePath': s.imagePath,
        'timestamp': s.timestamp.toIso8601String(),
      }).toList();
    }

    // Settings
    final glossaryLang = await _db.getSetting('glossaryLang');
    if (glossaryLang != null) backupData['glossaryLang'] = glossaryLang;

    final playerCount = await _db.getSettingInt('playerCount');
    if (playerCount != null) backupData['playerCount'] = playerCount;

    final startingLife = await _db.getSettingInt('startingLife');
    if (startingLife != null) backupData['startingLife'] = startingLife;

    backupData['backup_date'] = DateTime.now().toIso8601String();
    backupData['app_version'] = '1.0.0';

    return json.encode(backupData);
  }

  Future<String> _generateBackupFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> backupData = {};

    for (String key in _dataKeys) {
      final Object? value = prefs.get(key);
      if (value == null) continue;

      if (value is String) {
        try {
          backupData[key] = json.decode(value);
        } catch (e) {
          backupData[key] = value;
        }
      } else if (value is int) {
        backupData[key] = value;
      } else if (value is bool) {
        backupData[key] = value;
      } else if (value is double) {
        backupData[key] = value;
      }
    }

    backupData['backup_date'] = DateTime.now().toIso8601String();
    backupData['app_version'] = '1.0.0';

    return json.encode(backupData);
  }

  /// 2. Restaure les donnees
  Future<void> restoreFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);

      if (_db != null) {
        await _restoreToDrift(data);
      } else {
        await _restoreToSharedPrefs(data);
      }
    } catch (e) {
      log("Erreur restauration JSON: $e", name: 'BackupService');
      throw Exception("Donnees corrompues.");
    }
  }

  Future<void> _restoreToDrift(Map<String, dynamic> data) async {
    // Clear existing data
    await _db!.clearCollection();
    await _db.clearGameHistory();
    await _db.clearScanHistory();

    // Delete all decks
    final existingDecks = await _db.getAllDecksRaw();
    for (final d in existingDecks) {
      await _db.deleteDeckAndCards(d.id);
    }

    // Delete all wishlists
    final existingWishlists = await _db.getAllWishlistsRaw();
    for (final w in existingWishlists) {
      await _db.deleteWishlistAndCards(w.id);
    }

    // Delete all profiles
    final existingProfiles = await _db.getAllProfiles();
    for (final p in existingProfiles) {
      await _db.deleteProfile(p.id);
    }

    // Collection
    if (data.containsKey('user_collection') && data['user_collection'] is List) {
      for (final item in data['user_collection'] as List) {
        final map = item as Map<String, dynamic>;
        await _db.upsertCollectionCard(
          scryfallId: map['scryfallId'] as String,
          cardName: map['name'] as String,
          absoluteQuantity: map['quantity'] as int,
          isFoil: map['isFoil'] as bool? ?? false,
          newTags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        );
      }
    }

    // Decks
    if (data.containsKey('user_decks') && data['user_decks'] is List) {
      for (final item in data['user_decks'] as List) {
        final map = item as Map<String, dynamic>;
        final deckId = map['id'] as String;
        await _db.insertDeck(DecksCompanion.insert(
          id: deckId,
          name: map['name'] as String,
          format: drift.Value(map['format'] as String? ?? 'Standard'),
          commanderScryfallId: drift.Value(map['commanderScryfallId'] as String?),
          commanderSecondaryScryfallId: drift.Value(map['commanderSecondaryScryfallId'] as String?),
          colors: drift.Value(json.encode(map['colors'] ?? [])),
        ));
        for (final boardEntry in {'mainboard': 'main', 'sideboard': 'side', 'considering': 'considering', 'wishlist': 'wishlist'}.entries) {
          final cards = map[boardEntry.key] as List? ?? [];
          for (final cardJson in cards) {
            final cardMap = cardJson as Map<String, dynamic>;
            await _db.upsertDeckCard(
              deckId: deckId,
              board: boardEntry.value,
              scryfallId: cardMap['scryfallId'] as String,
              cardName: cardMap['name'] as String,
              absoluteQuantity: cardMap['quantity'] as int,
              newTags: (cardMap['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
              isFoil: cardMap['isFoil'] as bool? ?? false,
            );
          }
        }
      }
    }

    // Wishlists
    if (data.containsKey('user_wishlists_v2') && data['user_wishlists_v2'] is List) {
      for (final item in data['user_wishlists_v2'] as List) {
        final map = item as Map<String, dynamic>;
        final wishlistId = map['id'] as String;
        await _db.insertWishlist(WishlistsCompanion.insert(
          id: wishlistId,
          name: map['name'] as String,
          dateCreated: DateTime.parse(map['dateCreated'] ?? DateTime.now().toIso8601String()),
          iconScryfallId: drift.Value(map['iconScryfallId'] as String?),
        ));
        for (final cardJson in (map['cards'] as List? ?? [])) {
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
    }

    // Settings
    if (data.containsKey('glossaryLang') && data['glossaryLang'] is String) {
      await _db.setSetting('glossaryLang', data['glossaryLang'] as String);
    }
    if (data.containsKey('playerCount') && data['playerCount'] is int) {
      await _db.setSettingInt('playerCount', data['playerCount'] as int);
    }
    if (data.containsKey('startingLife') && data['startingLife'] is int) {
      await _db.setSettingInt('startingLife', data['startingLife'] as int);
    }
  }

  Future<void> _restoreToSharedPrefs(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (String key in _dataKeys) {
      if (data.containsKey(key)) {
        final dynamic value = data[key];
        if (value is Map || value is List) {
          await prefs.setString(key, json.encode(value));
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        }
      }
    }
  }

  // Export et import fichier
  Future<void> exportData() async {
    final String jsonString = await generateBackupJson();

    final Directory tempDir = await getTemporaryDirectory();
    final String dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final File file = File('${tempDir.path}/magic_companion_backup_$dateStr.json');

    await file.writeAsString(jsonString);
    await Share.shareXFiles([XFile(file.path)], text: 'Ma sauvegarde Magic Companion');
  }

  Future<bool> importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return false;

      final File file = File(result.files.single.path!);
      final String content = await file.readAsString();

      await restoreFromJson(content);
      return true;
    } catch (e) {
      log("Erreur import fichier: $e", name: 'BackupService');
      return false;
    }
  }
}
