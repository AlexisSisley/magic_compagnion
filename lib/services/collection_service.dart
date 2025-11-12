// Fichier : lib/services/collection_service.dart
// NOUVEAU FICHIER

import 'dart:convert';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
// On peut réutiliser le modèle DeckCard car il est parfait pour nos besoins
import '../models/deck_model.dart'; 

class CollectionService {
  static const _collectionKey = 'user_collection'; // Clé de sauvegarde unique

  /// Récupère TOUTE la collection sauvegardée
  Future<List<DeckCard>> loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final String? collectionJson = prefs.getString(_collectionKey);

    if (collectionJson == null) {
      return []; // Retourne une liste vide si rien n'est sauvegardé
    }

    // Décoder la chaîne JSON en une liste d'objets
    final List<dynamic> decodedList = json.decode(collectionJson) as List;
    
    // Convertir chaque objet JSON en un objet DeckCard
    return decodedList.map((jsonItem) => DeckCard.fromJson(jsonItem)).toList();
  }

  /// Sauvegarde la liste COMPLÈTE de la collection
  Future<void> _saveCollection(List<DeckCard> collection) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Convertir la liste d'objets DeckCard en une liste d'objets JSON
    final List<Map<String, dynamic>> jsonList =
        collection.map((card) => card.toJson()).toList();
        
    // Encoder la liste en une seule chaîne JSON
    final String collectionJson = json.encode(jsonList);
    
    await prefs.setString(_collectionKey, collectionJson);
  }

  /// Gère l'ajout, la mise à jour et la suppression de quantité
  Future<List<DeckCard>> upsertCardInCollection({
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,     // Pour +1, -1
    int? absoluteQuantity,  // Pour définir une quantité (ex: 4)
  }) async {
    // 1. Charge la collection actuelle
    final collection = await loadCollection();

    try {
      // 2. Tente de trouver la carte
      final existingCard = collection.firstWhere((c) => c.scryfallId == scryfallId);
      
      // La carte existe DÉJÀ
      int newQuantity = existingCard.quantity;
      if (quantityToAdd != null) {
        newQuantity += quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity <= 0) {
        collection.remove(existingCard); // Supprime la carte
      } else {
        existingCard.quantity = newQuantity; // Met à jour la quantité
      }

    } catch (e) {
      // 3. La carte N'EXISTE PAS
      int newQuantity = 0;
      if (quantityToAdd != null) {
        newQuantity = quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity > 0) {
        // Ajoute la nouvelle carte
        collection.add(DeckCard(
          scryfallId: scryfallId,
          name: cardName,
          quantity: newQuantity,
        ));
      }
    }

    // 4. Sauvegarde la collection mise à jour
    await _saveCollection(collection);
    return collection; // Retourne la nouvelle collection
  }
  
  /// Fonction pratique pour ajouter depuis un objet ScryfallCard
   Future<void> addCard(ScryfallCard card, int quantity) async {
      await upsertCardInCollection(
        scryfallId: card.id,
        cardName: card.name,
        quantityToAdd: quantity
      );
   }
}