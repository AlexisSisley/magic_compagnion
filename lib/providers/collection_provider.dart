// Fichier : lib/providers/collection_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import 'service_providers.dart';

class CollectionNotifier extends AsyncNotifier<List<DeckCard>> {
  @override
  Future<List<DeckCard>> build() async {
    final service = ref.read(collectionServiceProvider);
    return service.loadCollection();
  }

  Future<void> upsertCard({
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    bool isFoil = false,
    List<String>? newTags,
  }) async {
    final service = ref.read(collectionServiceProvider);
    final result = await service.upsertCardInCollection(
      scryfallId: scryfallId,
      cardName: cardName,
      quantityToAdd: quantityToAdd,
      absoluteQuantity: absoluteQuantity,
      isFoil: isFoil,
      newTags: newTags,
    );
    state = AsyncData(result);
  }

  Future<void> addCard(ScryfallCard card, int quantity, {bool isFoil = false}) async {
    final service = ref.read(collectionServiceProvider);
    await service.addCard(card, quantity, isFoil: isFoil);
    ref.invalidateSelf();
  }

  Future<Map<String, int>> importBatchCards(List<String> rawNames) async {
    final service = ref.read(collectionServiceProvider);
    final result = await service.importBatchCards(rawNames);
    ref.invalidateSelf();
    return result;
  }

  Future<void> clearCollection() async {
    final service = ref.read(collectionServiceProvider);
    await service.clearCollection();
    state = const AsyncData([]);
  }

  Future<void> reload() async {
    ref.invalidateSelf();
  }
}

final collectionProvider = AsyncNotifierProvider<CollectionNotifier, List<DeckCard>>(
  CollectionNotifier.new,
);
