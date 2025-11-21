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

  // --- MISE À JOUR ICI ---
  Future<void> createNewDeck(String name) async {
    final newDeck = Deck(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colors: [], // Initialisé vide
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

  // ... (Les méthodes addCardToDeck, upsertCardInDeck, updateCardQuantity, setCommander, clearDeck restent INCHANGÉES) ...
  // Pour gagner de la place, je ne les remets pas car elles n'ont pas besoin de modif, 
  // elles manipulent l'objet Deck qui a déjà été mis à jour via le modèle.
  // Assurez-vous de garder le reste de votre fichier existant.

  Future<Deck> upsertCardInDeck({
    required String deckId,
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    bool toSideboard = false,
  }) async {
     // ... (Garder le code existant) ...
     // Note : Idéalement, recalculer les couleurs ici serait bien, 
     // mais pour la simplicité, on le fera à l'import ou via le DetailPage.
     // Je remets le code minimal pour que ça compile si vous copiez-collez tout le fichier
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
  
  Future<Deck> setCommander(String deckId, String scryfallId) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    deck.commanderScryfallId = scryfallId;
    await updateDeck(deck);
    return deck;
  }
  
  Future<Deck> clearDeck(String deckId) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    deck.mainboard = [];
    deck.sideboard = [];
    await updateDeck(deck);
    return deck;
  }
  
  Future<void> addCardToDeck(String deckId, ScryfallCard cardFromApi, {bool toSideboard = false}) async {
    // Wrapper simple vers upsert
    await upsertCardInDeck(deckId: deckId, scryfallId: cardFromApi.id, cardName: cardFromApi.name, quantityToAdd: 1, toSideboard: toSideboard);
  }
}