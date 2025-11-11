// Fichier : lib/services/deck_service.dart

import 'dart:convert';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck_model.dart'; // Importer nos modèles

class DeckService {
  static const _decksKey = 'user_decks'; // Clé de sauvegarde

  // Récupérer TOUS les decks
  Future<List<Deck>> loadDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? decksJson = prefs.getString(_decksKey);

    if (decksJson == null) {
      return []; // Retourne une liste vide si rien n'est sauvegardé
    }

    // Décoder la chaîne JSON en une liste d'objets
    final List<dynamic> decodedList = json.decode(decksJson) as List;
    
    // Convertir chaque objet JSON en un objet Deck
    return decodedList.map((jsonItem) => Deck.fromJson(jsonItem)).toList();
  }

  // Sauvegarder la liste COMPLÈTE des decks
  Future<void> _saveDecksList(List<Deck> decks) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Convertir la liste d'objets Deck en une liste d'objets JSON
    final List<Map<String, dynamic>> jsonList =
        decks.map((deck) => deck.toJson()).toList();
        
    // Encoder la liste en une seule chaîne JSON
    final String decksJson = json.encode(jsonList);
    
    await prefs.setString(_decksKey, decksJson);
  }

  // --- Fonctions utiles ---
  Future<void> deleteDeck(String deckId) async {
    final decks = await loadDecks();
    decks.removeWhere((deck) => deck.id == deckId);
    await _saveDecksList(decks);
  }
  // Ajouter un nouveau deck (et le sauvegarder)
  Future<void> createNewDeck(String name) async {
    final newDeck = Deck(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // ID simple
      name: name,
    );
    
    final decks = await loadDecks();
    decks.add(newDeck);
    await _saveDecksList(decks);
  }
  
  // Mettre à jour un deck existant
  Future<void> updateDeck(Deck updatedDeck) async {
    final decks = await loadDecks();
    
    // Trouver l'index du deck à remplacer
    final index = decks.indexWhere((d) => d.id == updatedDeck.id);
    
    if (index != -1) {
      decks[index] = updatedDeck; // Remplacer l'ancien
      await _saveDecksList(decks);
    }
  }

  // Ajouter une carte à un deck (Exemple pour le mainboard)
  Future<void> addCardToDeck(String deckId, ScryfallCard cardFromApi, {bool toSideboard = false}) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);

    // L'ID Scryfall de la carte (assurez-vous que votre modèle ScryfallCard l'a)
    // NOTE: L'objet ScryfallCard vient de 'card_detail_page.dart'.
    // Vous devrez peut-être y ajouter le champ 'id' s'il manque.
    // Supposons que 'cardFromApi.id' existe :
    final scryfallId = cardFromApi.id; // !! IMPORTANT: Assurez-vous que ce champ existe
    final cardName = cardFromApi.name;

    final list = toSideboard ? deck.sideboard : deck.mainboard;

    // Vérifier si la carte est déjà dans le deck
    try {
      // Carte déjà présente, on incrémente la quantité
      final existingCard = list.firstWhere((c) => c.scryfallId == scryfallId);
      existingCard.quantity++;
    } catch (e) {
      // Carte non présente, on l'ajoute
      list.add(DeckCard(
        scryfallId: scryfallId,
        name: cardName,
        quantity: 1,
      ));
    }
    
    // Sauvegarder les modifications
    await updateDeck(deck);
  }
  // Gère l'ajout, la mise à jour et la suppression de quantité
  Future<Deck> upsertCardInDeck({
    required String deckId,
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,     // Pour ajouter/retirer (ex: +1, -1)
    int? absoluteQuantity,  // Pour définir une quantité (ex: 4)
    bool toSideboard = false,
  }) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    final list = toSideboard ? deck.sideboard : deck.mainboard;

    try {
      // La carte existe DÉJÀ dans la liste
      final existingCard = list.firstWhere((c) => c.scryfallId == scryfallId);
      
      int newQuantity = existingCard.quantity;
      if (quantityToAdd != null) {
        newQuantity += quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity <= 0) {
        list.remove(existingCard); // Supprime la carte
      } else {
        existingCard.quantity = newQuantity; // Met à jour la quantité
      }

    } catch (e) {
      // La carte N'EXISTE PAS
      int newQuantity = 0;
      if (quantityToAdd != null) {
        newQuantity = quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity > 0) {
        // Ajoute la nouvelle carte
        list.add(DeckCard(
          scryfallId: scryfallId,
          name: cardName,
          quantity: newQuantity,
        ));
      }
    }

    await updateDeck(deck);
    return deck;
  }
  Future<Deck> updateCardQuantity(String deckId, String scryfallId, int newQuantity) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);

    // Cherche dans le mainboard
    try {
      final card = deck.mainboard.firstWhere((c) => c.scryfallId == scryfallId);
      if (newQuantity <= 0) {
        deck.mainboard.remove(card);
      } else {
        card.quantity = newQuantity;
      }
    } catch (e) {
      // Cherche dans le sideboard si pas trouvé
      try {
        final card = deck.sideboard.firstWhere((c) => c.scryfallId == scryfallId);
        if (newQuantity <= 0) {
          deck.sideboard.remove(card);
        } else {
          card.quantity = newQuantity;
        }
      } catch (e) {
        // Carte non trouvée, ne rien faire
      }
    }

    await updateDeck(deck);
    return deck; // Retourne le deck mis à jour
  }
  // --- FONCTION : Définir le Commandant ---
  Future<Deck> setCommander(String deckId, String scryfallId) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);
    
    deck.commanderScryfallId = scryfallId;

    await updateDeck(deck);
    return deck; // Retourne le deck mis à jour
  }

  Future<Deck> clearDeck(String deckId) async {
    final decks = await loadDecks();
    final deck = decks.firstWhere((d) => d.id == deckId);

    // Vide les listes
    deck.mainboard = [];
    deck.sideboard = [];
    // On pourrait aussi supprimer le commandant, mais gardons-le
    // deck.commanderScryfallId = null; 

    await updateDeck(deck);
    return deck; // Retourne le deck vidé
  }
}