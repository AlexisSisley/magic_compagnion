// Fichier : lib/providers/dashboard_provider.dart
// Sprint 14, US-14.6 : Provider du Dashboard Home.
// Agregge les donnees locales (collection, scans, decks) sans appel Scryfall.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deck_model.dart';
import '../models/scan_history_model.dart';
import 'collection_provider.dart';
import 'collection_value_provider.dart';
import 'deck_provider.dart';
import 'service_providers.dart';

/// Etat agrege du Dashboard.
class DashboardState {
  final int totalCards;
  final double totalValue;
  final bool valueIsLoading;
  final List<ScanHistoryItem> recentScans;
  final List<Deck> recentDecks;
  final List<({String dateKey, double value})> valueHistory;
  final bool isLoading;

  const DashboardState({
    this.totalCards = 0,
    this.totalValue = 0,
    this.valueIsLoading = true,
    this.recentScans = const [],
    this.recentDecks = const [],
    this.valueHistory = const [],
    this.isLoading = true,
  });
}

/// Provider du Dashboard.
/// Consomme uniquement des donnees locales (cache) pour garantir
/// un affichage instantane sans appel reseau au lancement.
final dashboardProvider = FutureProvider<DashboardState>((ref) async {
  // Collection cards count
  final collectionAsync = ref.watch(collectionProvider);
  final collection = collectionAsync.when(
    data: (cards) => cards,
    loading: () => <DeckCard>[],
    error: (e, s) => <DeckCard>[],
  );
  final totalCards = collection.fold<int>(0, (sum, c) => sum + c.quantity);

  // Collection value (deja calcule par collectionValueProvider)
  final valueState = ref.watch(collectionValueProvider);

  // Recent scans (5 derniers)
  final scanService = ref.watch(scanHistoryServiceProvider);
  final allScans = await scanService.loadHistory();
  final recentScans = allScans.take(5).toList();

  // Recent decks (3 derniers)
  final decksAsync = ref.watch(deckListProvider);
  final allDecks = decksAsync.when(
    data: (decks) => decks,
    loading: () => <Deck>[],
    error: (e, s) => <Deck>[],
  );
  final recentDecks = allDecks.take(3).toList();

  // Value history for chart preview
  final collectionService = ref.watch(collectionServiceProvider);
  final valueHistory = await collectionService.getValueHistory();

  return DashboardState(
    totalCards: totalCards,
    totalValue: valueState.grandTotalEur,
    valueIsLoading: valueState.isLoading,
    recentScans: recentScans,
    recentDecks: recentDecks,
    valueHistory: valueHistory,
    isLoading: false,
  );
});
