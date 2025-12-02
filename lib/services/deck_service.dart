// Fichier : lib/services/deck_service.dart

import 'dart:convert';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck_model.dart';

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
    bool toSideboard = false,
  }) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    final list = toSideboard ? deck.sideboard : deck.mainboard;

    try {
      final existingCard = list.firstWhere((c) => c.scryfallId == scryfallId);
      int newQuantity = existingCard.quantity;
      if (quantityToAdd != null) newQuantity += quantityToAdd;
      else if (absoluteQuantity != null) newQuantity = absoluteQuantity;

      if (newQuantity <= 0) list.remove(existingCard);
      else existingCard.quantity = newQuantity;
    } catch (e) {
      int newQuantity = 0;
      if (quantityToAdd != null) newQuantity = quantityToAdd;
      else if (absoluteQuantity != null) newQuantity = absoluteQuantity;
      if (newQuantity > 0) list.add(DeckCard(scryfallId: scryfallId, name: cardName, quantity: newQuantity));
    }
    await updateDeck(deck);
    return deck;
  }
  
  // --- MISE À JOUR ICI : Slot (1 ou 2) ---
  Future<Deck> setCommander(String deckId, String scryfallId, {int slot = 1}) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    
    if (slot == 2) {
      deck.commanderSecondaryScryfallId = scryfallId;
    } else {
      deck.commanderScryfallId = scryfallId;
    }
    
    await updateDeck(deck);
    return deck;
  }
  
  Future<Deck> clearDeck(String deckId) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    deck.mainboard = [];
    deck.sideboard = [];
    deck.commanderScryfallId = null;
    deck.commanderSecondaryScryfallId = null; // Clear aussi le partner
    await updateDeck(deck);
    return deck;
  }
  
  Future<void> addCardToDeck(String deckId, ScryfallCard cardFromApi, {bool toSideboard = false}) async {
    await upsertCardInDeck(deckId: deckId, scryfallId: cardFromApi.id, cardName: cardFromApi.name, quantityToAdd: 1, toSideboard: toSideboard);
  }
}