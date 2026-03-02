// Fichier : lib/services/card_collection_actions.dart
// Service statique pour les actions collection et wishlist
// extraites de CardSearchController.

import '../models/deck_model.dart';
import 'collection_service.dart';
import 'wishlist_service.dart';

/// Donnees chargees depuis les services collection et wishlist.
/// Utilisee comme valeur de retour pour [CardCollectionActions.loadCollectionAndWishlistData].
class CollectionWishlistData {
  final List<DeckCard> collection;
  final List<DeckCard> flatWishlist;
  final Map<String, int> collectionIndex;
  final Map<String, int> collectionFoilIndex;
  final Set<String> wishlistCardNames;

  const CollectionWishlistData({
    required this.collection,
    required this.flatWishlist,
    required this.collectionIndex,
    required this.collectionFoilIndex,
    required this.wishlistCardNames,
  });
}

/// Actions statiques pour la collection et la wishlist.
///
/// Regroupe la logique metier qui etait dans CardSearchController :
/// - loadCollectionAndWishlistData (loadLocalData)
/// - toggleCollection
/// - removeFromAllWishlists
/// - addToWishlist
class CardCollectionActions {
  /// Charge la collection et les wishlists, et construit les index rapides.
  static Future<CollectionWishlistData> loadCollectionAndWishlistData(
    CollectionService collectionService,
    WishlistService wishlistService,
  ) async {
    final collection = await collectionService.loadCollection();
    final wishlists = await wishlistService.loadWishlists();
    final allWishlistCards = wishlists.expand((w) => w.cards).toList();

    // Index rapide pour les badges collection (O(1) lookup)
    final Map<String, int> collIdx = {};
    final Map<String, int> foilIdx = {};
    for (final card in collection) {
      if (card.isFoil) {
        foilIdx[card.scryfallId] =
            (foilIdx[card.scryfallId] ?? 0) + card.quantity;
      } else {
        collIdx[card.scryfallId] =
            (collIdx[card.scryfallId] ?? 0) + card.quantity;
      }
    }
    final wishlistNames = allWishlistCards.map((c) => c.name).toSet();

    return CollectionWishlistData(
      collection: collection,
      flatWishlist: allWishlistCards,
      collectionIndex: collIdx,
      collectionFoilIndex: foilIdx,
      wishlistCardNames: wishlistNames,
    );
  }

  /// Toggle l'etat d'une carte dans la collection.
  /// Retourne un message de feedback pour l'UI.
  static Future<String> toggleCollection(
    CollectionService collectionService,
    String id,
    String name,
    bool currentState,
  ) async {
    if (currentState) {
      await collectionService.upsertCardInCollection(
        scryfallId: id,
        cardName: name,
        absoluteQuantity: 0,
      );
    } else {
      await collectionService.upsertCardInCollection(
        scryfallId: id,
        cardName: name,
        quantityToAdd: 1,
      );
    }
    return currentState ? 'Retire de la collection' : 'Ajoute a la collection';
  }

  /// Retire une carte de toutes les wishlists par nom.
  /// Retourne un message de feedback pour l'UI.
  static Future<String> removeFromAllWishlists(
    WishlistService wishlistService,
    String name,
  ) async {
    final lists = await wishlistService.loadWishlists();
    for (var list in lists) {
      final cardsToRemove = list.cards.where((c) => c.name == name).toList();
      for (var c in cardsToRemove) {
        await wishlistService.upsertCard(
          wishlistId: list.id,
          scryfallId: c.scryfallId,
          cardName: name,
          absoluteQuantity: 0,
        );
      }
    }
    return 'Retire de toutes les Wishlists';
  }

  /// Ajoute une carte a une wishlist specifique.
  /// Retourne un message de feedback pour l'UI.
  static Future<String> addToWishlist(
    WishlistService wishlistService,
    String wishlistId,
    String scryfallId,
    String cardName,
  ) async {
    await wishlistService.upsertCard(
      wishlistId: wishlistId,
      scryfallId: scryfallId,
      cardName: cardName,
      quantityToAdd: 1,
    );
    return 'Ajoute a la Wishlist';
  }
}
