// Fichier : lib/services/deck_service.dart

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/app_database.dart';
import '../models/deck_model.dart';
import '../utils/card_list_upsert_mixin.dart';

// Enum pour identifier la zone cible
enum DeckBoard { main, side, considering, wishlist }

class DeckService with CardListUpsertMixin {
  static const _decksKey = 'user_decks';
  final AppDatabase? _db;

  DeckService({AppDatabase? database}) : _db = database;

  String _boardToString(DeckBoard board) {
    switch (board) {
      case DeckBoard.main: return 'main';
      case DeckBoard.side: return 'side';
      case DeckBoard.considering: return 'considering';
      case DeckBoard.wishlist: return 'wishlist';
    }
  }

  Future<List<Deck>> loadDecks() async {
    if (_db != null) {
      final rawDecks = await _db.getAllDecksRaw();
      final List<Deck> result = [];
      for (final d in rawDecks) {
        final cards = await _db.getDeckCardsByDeckId(d.id);
        result.add(_dbDeckToDeck(d, cards));
      }
      return result;
    }
    // Fallback SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final String? decksJson = prefs.getString(_decksKey);
    if (decksJson == null) return [];
    final List<dynamic> decodedList = json.decode(decksJson) as List;
    return decodedList.map((jsonItem) => Deck.fromJson(jsonItem)).toList();
  }

  Deck _dbDeckToDeck(DbDeck d, List<DbDeckCard> cards) {
    List<DeckCard> mainboard = [];
    List<DeckCard> sideboard = [];
    List<DeckCard> considering = [];
    List<DeckCard> wishlist = [];

    for (final c in cards) {
      final deckCard = DeckCard(
        scryfallId: c.scryfallId,
        name: c.name,
        quantity: c.quantity,
        proxyQuantity: c.proxyQuantity,
        isFoil: c.isFoil,
        tags: AppDatabase.decodeTags(c.tags),
      );
      switch (c.board) {
        case 'main': mainboard.add(deckCard);
        case 'side': sideboard.add(deckCard);
        case 'considering': considering.add(deckCard);
        case 'wishlist': wishlist.add(deckCard);
      }
    }

    return Deck(
      id: d.id,
      name: d.name,
      format: d.format,
      commanderScryfallId: d.commanderScryfallId,
      commanderSecondaryScryfallId: d.commanderSecondaryScryfallId,
      colors: AppDatabase.decodeTags(d.colors),
      mainboard: mainboard,
      sideboard: sideboard,
      considering: considering,
      wishlist: wishlist,
    );
  }

  Future<void> _saveDecksList(List<Deck> decks) async {
    if (_db != null) return;
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = decks.map((deck) => deck.toJson()).toList();
    await prefs.setString(_decksKey, json.encode(jsonList));
  }

  // --- ACTIONS ---

  Future<void> deleteDeck(String deckId) async {
    if (_db != null) {
      await _db.deleteDeckAndCards(deckId);
      return;
    }
    final decks = await loadDecks();
    decks.removeWhere((deck) => deck.id == deckId);
    await _saveDecksList(decks);
  }

  Future<void> createNewDeck(String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    if (_db != null) {
      await _db.insertDeck(DecksCompanion.insert(
        id: id,
        name: name,
        format: const Value('Standard'),
        colors: const Value('[]'),
      ));
      return;
    }
    final newDeck = Deck(
      id: id,
      name: name,
      colors: [],
      format: 'Standard',
    );
    final decks = await loadDecks();
    decks.add(newDeck);
    await _saveDecksList(decks);
  }

  Future<void> updateDeck(Deck updatedDeck) async {
    if (_db != null) {
      await _db.updateDeckEntry(updatedDeck.id, DecksCompanion(
        name: Value(updatedDeck.name),
        format: Value(updatedDeck.format),
        commanderScryfallId: Value(updatedDeck.commanderScryfallId),
        commanderSecondaryScryfallId: Value(updatedDeck.commanderSecondaryScryfallId),
        colors: Value(json.encode(updatedDeck.colors)),
      ));
      // Sync all cards: clear and re-insert
      await _db.clearDeckCards(updatedDeck.id);
      for (final entry in [
        MapEntry('main', updatedDeck.mainboard),
        MapEntry('side', updatedDeck.sideboard),
        MapEntry('considering', updatedDeck.considering),
        MapEntry('wishlist', updatedDeck.wishlist),
      ]) {
        for (final card in entry.value) {
          await _db.upsertDeckCard(
            deckId: updatedDeck.id,
            board: entry.key,
            scryfallId: card.scryfallId,
            cardName: card.name,
            absoluteQuantity: card.quantity,
            newTags: card.tags,
            isFoil: card.isFoil,
          );
        }
      }
      return;
    }
    final decks = await loadDecks();
    final index = decks.indexWhere((d) => d.id == updatedDeck.id);
    if (index != -1) {
      decks[index] = updatedDeck;
      await _saveDecksList(decks);
    }
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
    if (_db != null) {
      await _db.upsertDeckCard(
        deckId: deckId,
        board: _boardToString(board),
        scryfallId: scryfallId,
        cardName: cardName,
        quantityToAdd: quantityToAdd,
        absoluteQuantity: absoluteQuantity,
        newTags: newTags,
        isFoil: isFoil,
      );
      final rawDeck = (await _db.getAllDecksRaw()).firstWhere((d) => d.id == deckId);
      final cards = await _db.getDeckCardsByDeckId(deckId);
      return _dbDeckToDeck(rawDeck, cards);
    }

    final decks = await loadDecks();
    final deckIndex = decks.indexWhere((d) => d.id == deckId);
    if (deckIndex == -1) throw StateError('Deck $deckId not found');
    final deck = decks[deckIndex];

    List<DeckCard> targetList;
    switch (board) {
      case DeckBoard.side: targetList = deck.sideboard;
      case DeckBoard.considering: targetList = deck.considering;
      case DeckBoard.wishlist: targetList = deck.wishlist;
      case DeckBoard.main: targetList = deck.mainboard;
    }

    upsertCardInList(
      targetList,
      scryfallId: scryfallId,
      cardName: cardName,
      quantityToAdd: quantityToAdd,
      absoluteQuantity: absoluteQuantity,
      isFoil: isFoil,
      newTags: newTags,
    );
    await updateDeck(deck);
    return deck;
  }

  Future<Deck> changeCardVersion({
    required String deckId,
    required DeckCard oldCard,
    required ScryfallCard newVersion,
    required DeckBoard board,
  }) async {
    await upsertCardInDeck(
      deckId: deckId, scryfallId: oldCard.scryfallId, cardName: oldCard.name,
      absoluteQuantity: 0, board: board
    );
    return await upsertCardInDeck(
      deckId: deckId, scryfallId: newVersion.id, cardName: newVersion.name,
      absoluteQuantity: oldCard.quantity, board: board,
      newTags: oldCard.tags, isFoil: oldCard.isFoil
    );
  }

  Future<Deck> moveCard({
    required String deckId,
    required DeckCard card,
    required DeckBoard fromBoard,
    required DeckBoard toBoard,
  }) async {
    await upsertCardInDeck(
      deckId: deckId, scryfallId: card.scryfallId, cardName: card.name,
      absoluteQuantity: 0, board: fromBoard
    );
    final updatedDeck = await upsertCardInDeck(
      deckId: deckId, scryfallId: card.scryfallId, cardName: card.name,
      quantityToAdd: card.quantity, board: toBoard, newTags: card.tags
    );
    return updatedDeck;
  }

  Future<Deck> setCommander(String deckId, String scryfallId, {int slot = 1}) async {
    if (_db != null) {
      if (slot == 2) {
        await _db.updateDeckEntry(deckId, DecksCompanion(
          commanderSecondaryScryfallId: Value(scryfallId),
          format: const Value('Commander'),
        ));
      } else {
        await _db.updateDeckEntry(deckId, DecksCompanion(
          commanderScryfallId: Value(scryfallId),
          format: const Value('Commander'),
        ));
      }
      final rawDeck = (await _db.getAllDecksRaw()).firstWhere((d) => d.id == deckId);
      final cards = await _db.getDeckCardsByDeckId(deckId);
      return _dbDeckToDeck(rawDeck, cards);
    }

    final decks = await loadDecks();
    final idx = decks.indexWhere((d) => d.id == deckId);
    if (idx == -1) throw StateError('Deck $deckId not found');
    final deck = decks[idx];
    if (slot == 2) deck.commanderSecondaryScryfallId = scryfallId;
    else deck.commanderScryfallId = scryfallId;
    deck.format = 'Commander';
    await updateDeck(deck);
    return deck;
  }

  Future<Deck> unsetCommander(String deckId, {int slot = 1}) async {
    if (_db != null) {
      final rawDeck = (await _db.getAllDecksRaw()).firstWhere((d) => d.id == deckId,
          orElse: () => throw StateError('Deck $deckId not found'));

      String? newCmd = rawDeck.commanderScryfallId;
      String? newCmd2 = rawDeck.commanderSecondaryScryfallId;
      if (slot == 2) newCmd2 = null;
      else newCmd = null;

      String newFormat = (newCmd == null && newCmd2 == null) ? 'Standard' : rawDeck.format;

      await _db.updateDeckEntry(deckId, DecksCompanion(
        commanderScryfallId: Value(newCmd),
        commanderSecondaryScryfallId: Value(newCmd2),
        format: Value(newFormat),
      ));
      final updatedDeck = (await _db.getAllDecksRaw()).firstWhere((d) => d.id == deckId);
      final cards = await _db.getDeckCardsByDeckId(deckId);
      return _dbDeckToDeck(updatedDeck, cards);
    }

    final decks = await loadDecks();
    final idx = decks.indexWhere((d) => d.id == deckId);
    if (idx == -1) throw StateError('Deck $deckId not found');
    final deck = decks[idx];
    if (slot == 2) deck.commanderSecondaryScryfallId = null;
    else deck.commanderScryfallId = null;

    if (deck.commanderScryfallId == null && deck.commanderSecondaryScryfallId == null) {
      deck.format = 'Standard';
    }

    await updateDeck(deck);
    return deck;
  }

  Future<Deck> clearDeck(String deckId) async {
    if (_db != null) {
      await _db.clearDeckCards(deckId);
      await _db.updateDeckEntry(deckId, const DecksCompanion(
        commanderScryfallId: Value(null),
        commanderSecondaryScryfallId: Value(null),
        format: Value('Standard'),
      ));
      final updatedDeck = (await _db.getAllDecksRaw()).firstWhere((d) => d.id == deckId);
      final cards = await _db.getDeckCardsByDeckId(deckId);
      return _dbDeckToDeck(updatedDeck, cards);
    }

    final decks = await loadDecks();
    final idx = decks.indexWhere((d) => d.id == deckId);
    if (idx == -1) throw StateError('Deck $deckId not found');
    final deck = decks[idx];
    deck.mainboard = []; deck.sideboard = []; deck.considering = []; deck.wishlist = [];
    deck.commanderScryfallId = null; deck.commanderSecondaryScryfallId = null;
    deck.format = 'Standard';
    await updateDeck(deck);
    return deck;
  }
}
