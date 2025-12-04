// Fichier : lib/services/wishlist_service.dart

import 'dart:convert';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/models/wishlist_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck_model.dart'; 

class WishlistService {
  static const _oldWishlistKey = 'user_wishlist'; // Ancienne clé (Liste simple)
  static const _wishlistsKey = 'user_wishlists_v2'; // Nouvelle clé (Liste de Wishlists)

  // --- CHARGEMENT & MIGRATION ---

  Future<List<Wishlist>> loadWishlists() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_oldWishlistKey) && !prefs.containsKey(_wishlistsKey)) {
      await _migrateLegacyData(prefs);
    }
    final String? jsonStr = prefs.getString(_wishlistsKey);
    if (jsonStr == null) {
      final defaultList = Wishlist(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: "Ma Wishlist",
        cards: [],
        dateCreated: DateTime.now()
      );
      await _saveWishlists([defaultList]);
      return [defaultList];
    }
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded.map((e) => Wishlist.fromJson(e)).toList();
  }

  Future<void> _migrateLegacyData(SharedPreferences prefs) async {
    try {
      final String? oldJson = prefs.getString(_oldWishlistKey);
      if (oldJson != null) {
        final List<dynamic> oldList = json.decode(oldJson);
        final List<DeckCard> cards = oldList.map((e) => DeckCard.fromJson(e)).toList();
        
        // Créer la nouvelle structure avec les anciennes cartes
        final newList = Wishlist(
          id: 'legacy_import',
          name: "Wishlist 1", // Nom par défaut demandé
          cards: cards,
          dateCreated: DateTime.now()
        );
        
        // Sauvegarder dans le nouveau format
        await prefs.setString(_wishlistsKey, json.encode([newList.toJson()]));
        
        // Supprimer l'ancienne clé pour ne plus migrer
        await prefs.remove(_oldWishlistKey);
      }
    } catch (e) {
      print("Erreur migration wishlist: $e");
    }
  }

  Future<void> _saveWishlists(List<Wishlist> lists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wishlistsKey, json.encode(lists.map((e) => e.toJson()).toList()));
  }

  // --- ACTIONS CRUD ---

  Future<void> createWishlist(String name) async {
    final lists = await loadWishlists();
    lists.add(Wishlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      cards: [],
      dateCreated: DateTime.now()
    ));
    await _saveWishlists(lists);
  }

  Future<void> deleteWishlist(String id) async {
    final lists = await loadWishlists();
    lists.removeWhere((w) => w.id == id);
    await _saveWishlists(lists);
  }
  
  Future<void> renameWishlist(String id, String newName) async {
    final lists = await loadWishlists();
    final index = lists.indexWhere((w) => w.id == id);
    if (index != -1) {
      lists[index].name = newName;
      await _saveWishlists(lists);
    }
  }

  Future<void> clearWishlistCards(String wishlistId) async {
    final lists = await loadWishlists();
    final index = lists.indexWhere((w) => w.id == wishlistId);
    if (index != -1) {
      lists[index].cards.clear();
      await _saveWishlists(lists);
    }
  }

  // --- GESTION DES CARTES ---

  /// Ajoute/Modifie une carte dans une wishlist spécifique.
  /// Si [wishlistId] est null, utilise la première liste trouvée (comportement par défaut).
  Future<void> upsertCard({
    String? wishlistId, 
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,     
    int? absoluteQuantity,
    bool? isFoil, // <--- NOUVEAU PARAMÈTRE
  }) async {
    final lists = await loadWishlists();
    if (lists.isEmpty) return;

    final index = (wishlistId != null) 
        ? lists.indexWhere((w) => w.id == wishlistId)
        : 0;
    
    if (index == -1) return;

    final targetList = lists[index];
    
    try {
      final existingCard = targetList.cards.firstWhere((c) => c.scryfallId == scryfallId);
      int newQuantity = existingCard.quantity;
      
      if (quantityToAdd != null) newQuantity += quantityToAdd;
      else if (absoluteQuantity != null) newQuantity = absoluteQuantity;

      // Mise à jour du Foil si fourni
      if (isFoil != null) {
        existingCard.isFoil = isFoil;
      }

      if (newQuantity <= 0) targetList.cards.remove(existingCard);
      else existingCard.quantity = newQuantity;
      
    } catch (e) {
      int newQuantity = 0;
      if (quantityToAdd != null) newQuantity = quantityToAdd;
      else if (absoluteQuantity != null) newQuantity = absoluteQuantity;

      if (newQuantity > 0) {
        targetList.cards.add(DeckCard(
          scryfallId: scryfallId, 
          name: cardName, 
          quantity: newQuantity,
          isFoil: isFoil ?? false // <--- Init avec la valeur
        ));
      }
    }

    await _saveWishlists(lists);
  }
  
  Future<void> setWishlistIcon(String wishlistId, String? scryfallId) async {
    final lists = await loadWishlists();
    final index = lists.indexWhere((w) => w.id == wishlistId);
    if (index != -1) {
      lists[index].iconScryfallId = scryfallId;
      await _saveWishlists(lists);
    }
  }
  // Wrapper pratique pour compatibilité
  Future<void> addCard(ScryfallCard card, int quantity, {String? targetWishlistId}) async {
    await upsertCard(
      wishlistId: targetWishlistId,
      scryfallId: card.id,
      cardName: card.name,
      quantityToAdd: quantity
    );
  }
}