// Fichier : lib/services/wishlist_service.dart
// NOUVEAU FICHIER

import 'dart:convert';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
// On réutilise le modèle DeckCard
import '../models/deck_model.dart'; 

class WishlistService {
  // Clé de sauvegarde différente !
  static const _wishlistKey = 'user_wishlist'; 

  /// Récupère TOUTE la wishlist sauvegardée
  Future<List<DeckCard>> loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final String? wishlistJson = prefs.getString(_wishlistKey);

    if (wishlistJson == null) {
      return []; // Retourne une liste vide
    }

    final List<dynamic> decodedList = json.decode(wishlistJson) as List;
    return decodedList.map((jsonItem) => DeckCard.fromJson(jsonItem)).toList();
  }

  /// Sauvegarde la liste COMPLÈTE
  Future<void> _saveWishlist(List<DeckCard> wishlist) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        wishlist.map((card) => card.toJson()).toList();
    final String wishlistJson = json.encode(jsonList);
    await prefs.setString(_wishlistKey, wishlistJson);
  }

  /// Gère l'ajout, la mise à jour et la suppression de quantité
  Future<List<DeckCard>> upsertCardInWishlist({
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,     
    int? absoluteQuantity,  
  }) async {
    final wishlist = await loadWishlist();

    try {
      // La carte existe DÉJÀ
      final existingCard = wishlist.firstWhere((c) => c.scryfallId == scryfallId);
      
      int newQuantity = existingCard.quantity;
      if (quantityToAdd != null) {
        newQuantity += quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity <= 0) {
        wishlist.remove(existingCard); // Supprime
      } else {
        existingCard.quantity = newQuantity; // Met à jour
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
        wishlist.add(DeckCard(
          scryfallId: scryfallId,
          name: cardName,
          quantity: newQuantity,
        ));
      }
    }

    await _saveWishlist(wishlist);
    return wishlist;
  }
  
  /// Fonction pratique pour ajouter depuis un objet ScryfallCard
   Future<void> addCard(ScryfallCard card, int quantity) async {
      await upsertCardInWishlist(
        scryfallId: card.id,
        cardName: card.name,
        quantityToAdd: quantity
      );
   }
}