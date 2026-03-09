// Fichier : lib/providers/collection_value_provider.dart
// Sprint 14, US-14.2 : Provider temps reel de la valeur totale de la collection.
// Utilise le cache Scryfall avec TTL 24h pour les prix.

import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deck_model.dart';
import '../utils/price_helper.dart';
import 'collection_provider.dart';
import 'service_providers.dart';

/// Etat de la valeur de la collection.
class CollectionValueState {
  final double totalValueEur;
  final double totalValueFoilEur;
  final double grandTotalEur;
  final int totalCards;
  final int pricedCards;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const CollectionValueState({
    this.totalValueEur = 0,
    this.totalValueFoilEur = 0,
    this.grandTotalEur = 0,
    this.totalCards = 0,
    this.pricedCards = 0,
    this.isLoading = true,
    this.error,
    this.lastUpdated,
  });

  CollectionValueState copyWith({
    double? totalValueEur,
    double? totalValueFoilEur,
    double? grandTotalEur,
    int? totalCards,
    int? pricedCards,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return CollectionValueState(
      totalValueEur: totalValueEur ?? this.totalValueEur,
      totalValueFoilEur: totalValueFoilEur ?? this.totalValueFoilEur,
      grandTotalEur: grandTotalEur ?? this.grandTotalEur,
      totalCards: totalCards ?? this.totalCards,
      pricedCards: pricedCards ?? this.pricedCards,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Provider de la valeur de la collection en temps reel.
///
/// - Se recalcule automatiquement quand la collection change (via collectionProvider).
/// - Utilise les prix du cache local (LocalCardService) quand disponibles.
/// - Pour les cartes absentes du cache local, fait un appel batch Scryfall
///   avec cache TTL 24h (via ScryfallApiService).
/// - Respecte le rate limit Scryfall (10 req/s).
class CollectionValueNotifier extends Notifier<CollectionValueState> {
  @override
  CollectionValueState build() {
    // Ecoute les changements de la collection
    final collectionAsync = ref.watch(collectionProvider);

    collectionAsync.when(
      data: (cards) => _computeValue(cards),
      loading: () {},
      error: (e, _) {
        state = CollectionValueState(
          isLoading: false,
          error: 'Erreur chargement collection: $e',
        );
      },
    );

    return const CollectionValueState();
  }

  /// Recalcule la valeur totale de la collection.
  Future<void> _computeValue(List<DeckCard> collection) async {
    if (collection.isEmpty) {
      state = CollectionValueState(
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
      return;
    }

    try {
      final localCardService = ref.read(localCardServiceProvider);
      final scryfallApi = ref.read(scryfallApiServiceProvider);

      double totalNormal = 0;
      double totalFoil = 0;
      int pricedCount = 0;

      // Phase 1 : Resoudre les prix via le cache local
      final List<DeckCard> unresolvedCards = [];

      for (final card in collection) {
        final localCard = localCardService.getCardById(card.scryfallId);
        if (localCard != null) {
          final price = PriceHelper.bestPrice(localCard.prices, isFoil: card.isFoil);
          if (price > 0) {
            if (card.isFoil) {
              totalFoil += price * card.quantity;
            } else {
              totalNormal += price * card.quantity;
            }
            pricedCount++;
          }
        } else {
          unresolvedCards.add(card);
        }
      }

      // Phase 2 : Batch Scryfall pour les cartes non resolues (max 75 par requete)
      if (unresolvedCards.isNotEmpty) {
        const int batchSize = 75;
        for (int i = 0; i < unresolvedCards.length; i += batchSize) {
          final end = (i + batchSize < unresolvedCards.length)
              ? i + batchSize
              : unresolvedCards.length;
          final batch = unresolvedCards.sublist(i, end);

          final identifiers = batch
              .map((c) => <String, dynamic>{'id': c.scryfallId})
              .toList();

          try {
            // Le cache de ScryfallApiService gere le TTL 24h pour les appels POST
            // indirectement via les resultats. Pour les batch, on utilise fetchCollection.
            final data = await scryfallApi.fetchCollection(identifiers);
            final List<dynamic> foundCards = data['data'] ?? [];

            for (final cardJson in foundCards) {
              final prices = Map<String, dynamic>.from(cardJson['prices'] ?? {});
              final String cardId = cardJson['id'] ?? '';
              final matchingCard = batch.where((c) => c.scryfallId == cardId);

              for (final mc in matchingCard) {
                final price = PriceHelper.bestPrice(prices, isFoil: mc.isFoil);
                if (price > 0) {
                  if (mc.isFoil) {
                    totalFoil += price * mc.quantity;
                  } else {
                    totalNormal += price * mc.quantity;
                  }
                  pricedCount++;
                }
              }
            }
          } catch (e) {
            log('CollectionValue batch error: $e', name: 'CollectionValueProvider');
          }
        }
      }

      state = CollectionValueState(
        totalValueEur: totalNormal,
        totalValueFoilEur: totalFoil,
        grandTotalEur: totalNormal + totalFoil,
        totalCards: collection.fold(0, (sum, c) => sum + c.quantity),
        pricedCards: pricedCount,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );

      // Enregistrer la valeur quotidienne
      final collectionService = ref.read(collectionServiceProvider);
      await collectionService.recordDailyValue(totalNormal + totalFoil);
    } catch (e) {
      state = CollectionValueState(
        isLoading: false,
        error: 'Erreur calcul valeur: $e',
      );
    }
  }

  /// Force un recalcul (invalide le cache et recharge).
  void refresh() {
    ref.invalidateSelf();
  }
}

/// Provider singleton pour la valeur de la collection.
final collectionValueProvider =
    NotifierProvider<CollectionValueNotifier, CollectionValueState>(
  CollectionValueNotifier.new,
);
