// Fichier : lib/providers/service_providers.dart
// Providers Riverpod pour les services (avec injection AppDatabase + ScryfallApiService)
//
// Purupurupurupuru... Purupurupurupuru...
// Gatcha!
//
// "Ici le QG des Mugiwara, poste d'ecoute des Providers.
//  Tous les services sont en ligne, Capitaine.
//  La connexion Scryfall est stable. Le Log Pose est calibre.
//  On attend vos ordres."
//
//  — Den Den Mushi de service

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../services/backup_service.dart';
import '../services/bulk_data_service.dart';
import '../services/collection_service.dart';
import '../services/deck_service.dart';
import '../services/edhrec_service.dart';
import '../services/game_history_service.dart';
import '../services/google_drive_service.dart';
import '../services/local_card_service.dart';
import '../services/oracle_service.dart';
import '../services/profile_service.dart';
import '../services/scan_history_service.dart';
import '../services/scryfall_api_service.dart';
import '../services/set_service.dart';
import '../services/game_session_service.dart';
import '../services/wishlist_service.dart';

// --- Database singleton ---

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// --- Client HTTP Scryfall (singleton) ---

final scryfallApiServiceProvider = Provider<ScryfallApiService>((ref) {
  return ScryfallApiService();
});

// --- Services avec injection de la base drift + API ---

final collectionServiceProvider = Provider<CollectionService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(scryfallApiServiceProvider);
  return CollectionService(database: db, api: api);
});

final deckServiceProvider = Provider<DeckService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DeckService(database: db);
});

final wishlistServiceProvider = Provider<WishlistService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WishlistService(database: db);
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProfileService(database: db);
});

final gameHistoryServiceProvider = Provider<GameHistoryService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GameHistoryService(database: db);
});

final scanHistoryServiceProvider = Provider<ScanHistoryService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ScanHistoryService(database: db);
});

// --- Services sans dépendance à la base ---

final setServiceProvider = Provider<SetService>((ref) {
  final api = ref.watch(scryfallApiServiceProvider);
  return SetService(api: api);
});
final edhrecServiceProvider = Provider<EdhrecService>((ref) => EdhrecService());
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) => GoogleDriveService());
final oracleServiceProvider = Provider<OracleService>((ref) => OracleService());
final localCardServiceProvider = Provider<LocalCardService>((ref) => LocalCardService());
final bulkDataServiceProvider = Provider<BulkDataService>((ref) {
  final api = ref.watch(scryfallApiServiceProvider);
  return BulkDataService(api: api);
});

// --- Provider pour le chargement initial des cartes locales ---

final localCardsInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(localCardServiceProvider);
  await service.loadLocalData();
});

final gameSessionServiceProvider = Provider<GameSessionService>((ref) {
  return GameSessionService();
});
