// Fichier : lib/providers/deck_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../services/deck_service.dart';
import 'service_providers.dart';

class DeckListNotifier extends AsyncNotifier<List<Deck>> {
  @override
  Future<List<Deck>> build() async {
    final service = ref.read(deckServiceProvider);
    return service.loadDecks();
  }

  Future<void> createDeck(String name) async {
    final service = ref.read(deckServiceProvider);
    await service.createNewDeck(name);
    ref.invalidateSelf();
  }

  Future<void> deleteDeck(String deckId) async {
    final service = ref.read(deckServiceProvider);
    await service.deleteDeck(deckId);
    ref.invalidateSelf();
  }

  Future<Deck> upsertCardInDeck({
    required String deckId,
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    DeckBoard board = DeckBoard.main,
    List<String>? newTags,
    bool? isFoil,
  }) async {
    final service = ref.read(deckServiceProvider);
    final deck = await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: scryfallId,
      cardName: cardName,
      quantityToAdd: quantityToAdd,
      absoluteQuantity: absoluteQuantity,
      board: board,
      newTags: newTags,
      isFoil: isFoil,
    );
    ref.invalidateSelf();
    return deck;
  }

  Future<Deck> changeCardVersion({
    required String deckId,
    required DeckCard oldCard,
    required ScryfallCard newVersion,
    required DeckBoard board,
  }) async {
    final service = ref.read(deckServiceProvider);
    final deck = await service.changeCardVersion(
      deckId: deckId,
      oldCard: oldCard,
      newVersion: newVersion,
      board: board,
    );
    ref.invalidateSelf();
    return deck;
  }

  Future<Deck> moveCard({
    required String deckId,
    required DeckCard card,
    required DeckBoard fromBoard,
    required DeckBoard toBoard,
  }) async {
    final service = ref.read(deckServiceProvider);
    final deck = await service.moveCard(
      deckId: deckId,
      card: card,
      fromBoard: fromBoard,
      toBoard: toBoard,
    );
    ref.invalidateSelf();
    return deck;
  }

  Future<Deck> setCommander(String deckId, String scryfallId, {int slot = 1}) async {
    final service = ref.read(deckServiceProvider);
    final deck = await service.setCommander(deckId, scryfallId, slot: slot);
    ref.invalidateSelf();
    return deck;
  }

  Future<Deck> unsetCommander(String deckId, {int slot = 1}) async {
    final service = ref.read(deckServiceProvider);
    final deck = await service.unsetCommander(deckId, slot: slot);
    ref.invalidateSelf();
    return deck;
  }

  Future<Deck> clearDeck(String deckId) async {
    final service = ref.read(deckServiceProvider);
    final deck = await service.clearDeck(deckId);
    ref.invalidateSelf();
    return deck;
  }

  Future<void> updateDeck(Deck deck) async {
    final service = ref.read(deckServiceProvider);
    await service.updateDeck(deck);
    ref.invalidateSelf();
  }

  Future<void> reload() async {
    ref.invalidateSelf();
  }
}

final deckListProvider = AsyncNotifierProvider<DeckListNotifier, List<Deck>>(
  DeckListNotifier.new,
);
