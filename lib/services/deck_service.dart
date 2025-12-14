// Fichier : lib/services/deck_service.dart

import 'dart:convert';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck_model.dart';

// Enum pour identifier la zone cible
enum DeckBoard { main, side, considering, wishlist }

class DeckService {
  static const _decksKey = 'user_decks';

  Future<List<Deck>> loadDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? decksJson = prefs.getString(_decksKey);
    if (decksJson == null) return [];
    final List<dynamic> decodedList = json.decode(decksJson) as List;
    return decodedList.map((jsonItem) => Deck.fromJson(jsonItem)).toList();
  }

  Future<void> _saveDecksList(List<Deck> decks) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = decks.map((deck) => deck.toJson()).toList();
    await prefs.setString(_decksKey, json.encode(jsonList));
  }

  // --- ACTIONS ---

  Future<void> deleteDeck(String deckId) async {
    final decks = await loadDecks();
    decks.removeWhere((deck) => deck.id == deckId);
    await _saveDecksList(decks);
  }

  Future<void> createNewDeck(String name) async {
    final newDeck = Deck(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colors: [],
      format: 'Standard',
    );
    final decks = await loadDecks();
    decks.add(newDeck);
    await _saveDecksList(decks);
  }
  
  Future<void> updateDeck(Deck updatedDeck) async {
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
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    
    List<DeckCard> targetList;
    switch (board) {
      case DeckBoard.side: targetList = deck.sideboard; break;
      case DeckBoard.considering: targetList = deck.considering; break;
      case DeckBoard.wishlist: targetList = deck.wishlist; break;
      case DeckBoard.main: targetList = deck.mainboard; break;
    }

    try {
      final existingCard = targetList.firstWhere((c) => c.scryfallId == scryfallId);
      
      int newQuantity = existingCard.quantity;
      if (quantityToAdd != null) newQuantity += quantityToAdd;
      else if (absoluteQuantity != null) newQuantity = absoluteQuantity;

      if (newTags != null) existingCard.tags = newTags;
      if (isFoil != null) existingCard.isFoil = isFoil; 

      if (newQuantity <= 0) targetList.remove(existingCard);
      else existingCard.quantity = newQuantity;
      
    } catch (e) {
      int newQuantity = 0;
      if (quantityToAdd != null) newQuantity = quantityToAdd;
      else if (absoluteQuantity != null) newQuantity = absoluteQuantity;
      
      if (newQuantity > 0) {
        targetList.add(DeckCard(
          scryfallId: scryfallId, 
          name: cardName, 
          quantity: newQuantity,
          tags: newTags ?? [],
          isFoil: isFoil ?? false
        ));
      }
    }
    await updateDeck(deck);
    return deck;
  }
  
  // Changement de version : Supprime l'ancienne et ajoute la nouvelle
  Future<Deck> changeCardVersion({
    required String deckId,
    required DeckCard oldCard,
    required ScryfallCard newVersion,
    required DeckBoard board,
  }) async {
    // 1. Supprimer l'ancienne
    await upsertCardInDeck(
      deckId: deckId, scryfallId: oldCard.scryfallId, cardName: oldCard.name, 
      absoluteQuantity: 0, board: board
    );
    // 2. Ajouter la nouvelle (avec les mêmes propriétés : qté, foil, tags)
    return await upsertCardInDeck(
      deckId: deckId, scryfallId: newVersion.id, cardName: newVersion.name, 
      absoluteQuantity: oldCard.quantity, board: board, 
      newTags: oldCard.tags, isFoil: oldCard.isFoil
    );
  }
  
  // Déplacer une carte d'une zone à une autre
  Future<Deck> moveCard({
    required String deckId,
    required DeckCard card,
    required DeckBoard fromBoard,
    required DeckBoard toBoard,
  }) async {
    // 1. Retirer de la source (qté 0 supprime)
    await upsertCardInDeck(
      deckId: deckId, scryfallId: card.scryfallId, cardName: card.name, 
      absoluteQuantity: 0, board: fromBoard
    );
    // 2. Ajouter à la destination (on garde tags et foil)
    final updatedDeck = await upsertCardInDeck(
      deckId: deckId, scryfallId: card.scryfallId, cardName: card.name, 
      quantityToAdd: card.quantity, board: toBoard, newTags: card.tags
    );
    
    return updatedDeck;
  }

  Future<Deck> setCommander(String deckId, String scryfallId, {int slot = 1}) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    if (slot == 2) deck.commanderSecondaryScryfallId = scryfallId;
    else deck.commanderScryfallId = scryfallId;
    
    // --- CORRECTION : Mise à jour automatique du format ---
    deck.format = 'Commander';
    
    await updateDeck(deck);
    return deck;
  }

  Future<Deck> unsetCommander(String deckId, {int slot = 1}) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    if (slot == 2) deck.commanderSecondaryScryfallId = null;
    else deck.commanderScryfallId = null;
    
    // --- CORRECTION : Retour au format Standard si plus de commandant ---
    if (deck.commanderScryfallId == null && deck.commanderSecondaryScryfallId == null) {
      deck.format = 'Standard';
    }

    await updateDeck(deck);
    return deck;
  }
  
  Future<Deck> clearDeck(String deckId) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    deck.mainboard = []; deck.sideboard = []; deck.considering = []; deck.wishlist = [];
    deck.commanderScryfallId = null; deck.commanderSecondaryScryfallId = null;
    
    // --- CORRECTION : Reset du format ---
    deck.format = 'Standard';
    
    await updateDeck(deck);
    return deck;
  }
}