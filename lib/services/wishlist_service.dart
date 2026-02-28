// Fichier : lib/services/wishlist_service.dart

import 'dart:convert';
import 'dart:developer';
import 'package:drift/drift.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/models/wishlist_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/app_database.dart';
import '../models/deck_model.dart';
import '../utils/card_list_upsert_mixin.dart';

class WishlistService with CardListUpsertMixin {
  static const _oldWishlistKey = 'user_wishlist'; // Ancienne cle (Liste simple)
  static const _wishlistsKey = 'user_wishlists_v2'; // Nouvelle cle (Liste de Wishlists)
  final AppDatabase? _db;

  WishlistService({AppDatabase? database}) : _db = database;

  // --- CHARGEMENT & MIGRATION ---

  Future<List<Wishlist>> loadWishlists() async {
    if (_db != null) {
      final rawWishlists = await _db!.getAllWishlistsRaw();
      if (rawWishlists.isEmpty) {
        // Creer une wishlist par defaut
        final defaultId = DateTime.now().millisecondsSinceEpoch.toString();
        await _db!.insertWishlist(WishlistsCompanion.insert(
          id: defaultId,
          name: 'Ma Wishlist',
          dateCreated: DateTime.now(),
        ));
        return [Wishlist(
          id: defaultId,
          name: 'Ma Wishlist',
          cards: [],
          dateCreated: DateTime.now(),
        )];
      }
      final List<Wishlist> result = [];
      for (final w in rawWishlists) {
        final cards = await _db!.getWishlistCardsByWishlistId(w.id);
        result.add(Wishlist(
          id: w.id,
          name: w.name,
          cards: cards.map((c) => DeckCard(
            scryfallId: c.scryfallId,
            name: c.name,
            quantity: c.quantity,
            proxyQuantity: c.proxyQuantity,
            isFoil: c.isFoil,
            tags: AppDatabase.decodeTags(c.tags),
          )).toList(),
          dateCreated: w.dateCreated,
          iconScryfallId: w.iconScryfallId,
        ));
      }
      return result;
    }

    // Fallback SharedPreferences
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

        final newList = Wishlist(
          id: 'legacy_import',
          name: "Wishlist 1",
          cards: cards,
          dateCreated: DateTime.now()
        );

        await prefs.setString(_wishlistsKey, json.encode([newList.toJson()]));
        await prefs.remove(_oldWishlistKey);
      }
    } on FormatException catch (e) {
      log("Erreur migration wishlist (format): $e", name: 'WishlistService');
    } catch (e) {
      log("Erreur migration wishlist: $e", name: 'WishlistService');
    }
  }

  Future<void> _saveWishlists(List<Wishlist> lists) async {
    if (_db != null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wishlistsKey, json.encode(lists.map((e) => e.toJson()).toList()));
  }

  // --- ACTIONS CRUD ---

  Future<void> createWishlist(String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    if (_db != null) {
      await _db!.insertWishlist(WishlistsCompanion.insert(
        id: id,
        name: name,
        dateCreated: DateTime.now(),
      ));
      return;
    }
    final lists = await loadWishlists();
    lists.add(Wishlist(
      id: id,
      name: name,
      cards: [],
      dateCreated: DateTime.now()
    ));
    await _saveWishlists(lists);
  }

  Future<void> deleteWishlist(String id) async {
    if (_db != null) {
      await _db!.deleteWishlistAndCards(id);
      return;
    }
    final lists = await loadWishlists();
    lists.removeWhere((w) => w.id == id);
    await _saveWishlists(lists);
  }

  Future<void> renameWishlist(String id, String newName) async {
    if (_db != null) {
      await _db!.updateWishlistEntry(id, WishlistsCompanion(
        name: Value(newName),
      ));
      return;
    }
    final lists = await loadWishlists();
    final index = lists.indexWhere((w) => w.id == id);
    if (index != -1) {
      lists[index].name = newName;
      await _saveWishlists(lists);
    }
  }

  Future<void> clearWishlistCards(String wishlistId) async {
    if (_db != null) {
      await _db!.clearWishlistCardEntries(wishlistId);
      return;
    }
    final lists = await loadWishlists();
    final index = lists.indexWhere((w) => w.id == wishlistId);
    if (index != -1) {
      lists[index].cards.clear();
      await _saveWishlists(lists);
    }
  }

  // --- GESTION DES CARTES ---

  Future<void> upsertCard({
    String? wishlistId,
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    bool? isFoil,
  }) async {
    if (_db != null) {
      String targetId = wishlistId ?? '';
      if (targetId.isEmpty) {
        final wishlists = await _db!.getAllWishlistsRaw();
        if (wishlists.isEmpty) return;
        targetId = wishlists.first.id;
      }
      await _db!.upsertWishlistCard(
        wishlistId: targetId,
        scryfallId: scryfallId,
        cardName: cardName,
        quantityToAdd: quantityToAdd,
        absoluteQuantity: absoluteQuantity,
        isFoil: isFoil,
      );
      return;
    }

    final lists = await loadWishlists();
    if (lists.isEmpty) return;

    final index = (wishlistId != null)
        ? lists.indexWhere((w) => w.id == wishlistId)
        : 0;

    if (index == -1) return;

    final targetList = lists[index];

    upsertCardInList(
      targetList.cards,
      scryfallId: scryfallId,
      cardName: cardName,
      quantityToAdd: quantityToAdd,
      absoluteQuantity: absoluteQuantity,
      isFoil: isFoil,
    );

    await _saveWishlists(lists);
  }

  Future<void> setWishlistIcon(String wishlistId, String? scryfallId) async {
    if (_db != null) {
      await _db!.updateWishlistEntry(wishlistId, WishlistsCompanion(
        iconScryfallId: Value(scryfallId),
      ));
      return;
    }
    final lists = await loadWishlists();
    final index = lists.indexWhere((w) => w.id == wishlistId);
    if (index != -1) {
      lists[index].iconScryfallId = scryfallId;
      await _saveWishlists(lists);
    }
  }

  // Wrapper pratique pour compatibilite
  Future<void> addCard(ScryfallCard card, int quantity, {String? targetWishlistId}) async {
    await upsertCard(
      wishlistId: targetWishlistId,
      scryfallId: card.id,
      cardName: card.name,
      quantityToAdd: quantity
    );
  }
}
