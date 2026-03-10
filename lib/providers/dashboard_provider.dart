// Fichier : lib/providers/dashboard_provider.dart
// Sprint 14, US-14.6 : Provider du Dashboard Home.
// Agregge les donnees locales (collection, scans, decks) sans appel Scryfall.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deck_model.dart';
import '../models/scan_history_model.dart';
import '../utils/price_helper.dart';
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
  final Deck? favoriteDeck;
  final List<DeckCard> topValueCards;
  final Map<String, int> colorDistribution;
  final int editionCount;

  const DashboardState({
    this.totalCards = 0,
    this.totalValue = 0,
    this.valueIsLoading = true,
    this.recentScans = const [],
    this.recentDecks = const [],
    this.valueHistory = const [],
    this.isLoading = true,
    this.favoriteDeck,
    this.topValueCards = const [],
    this.colorDistribution = const {},
    this.editionCount = 0,
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

  // Favorite deck (first deck = most recently modified)
  final favoriteDeck = allDecks.isNotEmpty ? allDecks.first : null;

  // Value history for chart preview
  final collectionService = ref.watch(collectionServiceProvider);
  final valueHistory = await collectionService.getValueHistory();

  // Top value cards (top 3 by price from local cache)
  final localCardService = ref.read(localCardServiceProvider);
  final List<({DeckCard card, double price})> cardPrices = [];
  for (final card in collection) {
    final localCard = localCardService.getCardById(card.scryfallId);
    if (localCard != null) {
      final price =
          PriceHelper.bestPrice(localCard.prices, isFoil: card.isFoil);
      if (price > 0) {
        cardPrices.add((card: card, price: price));
      }
    }
  }
  cardPrices.sort((a, b) => b.price.compareTo(a.price));
  final topValueCards = cardPrices.take(3).map((e) => e.card).toList();

  // Color distribution from local card data
  final Map<String, int> colorDist = {};
  for (final card in collection) {
    final localCard = localCardService.getCardById(card.scryfallId);
    if (localCard != null) {
      final ci = localCard.colorIdentity;
      if (ci.isEmpty) {
        colorDist['C'] = (colorDist['C'] ?? 0) + card.quantity;
      } else if (ci.length > 1) {
        colorDist['M'] = (colorDist['M'] ?? 0) + card.quantity;
      } else {
        final c = ci.first;
        colorDist[c] = (colorDist[c] ?? 0) + card.quantity;
      }
    }
  }

  // Edition count
  final Set<String> editions = {};
  for (final card in collection) {
    final localCard = localCardService.getCardById(card.scryfallId);
    if (localCard != null && localCard.setCode.isNotEmpty) {
      editions.add(localCard.setCode);
    }
  }

  return DashboardState(
    totalCards: totalCards,
    totalValue: valueState.grandTotalEur,
    valueIsLoading: valueState.isLoading,
    recentScans: recentScans,
    recentDecks: recentDecks,
    valueHistory: valueHistory,
    isLoading: false,
    favoriteDeck: favoriteDeck,
    topValueCards: topValueCards,
    colorDistribution: colorDist,
    editionCount: editions.length,
  );
});
