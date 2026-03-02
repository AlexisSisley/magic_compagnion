// Fichier : lib/utils/card_list_upsert_mixin.dart
// Mixin commun pour la logique upsert de cartes dans une liste (Sprint 7 - US-7.6)

import '../models/deck_model.dart';

/// Mixin qui factorise la logique upsert partagée entre
/// CollectionService, DeckService et WishlistService.
///
/// Pattern : indexWhere(scryfallId) → si existe: update qty/tags/foil → sinon: create.
/// Supprime la carte si la quantité tombe à 0 ou moins.
mixin CardListUpsertMixin {
  /// Upsert une carte dans [cards] et retourne true si la liste a été modifiée.
  ///
  /// [matchByFoil] : si true, foil et non-foil sont des entrées séparées (collection).
  /// [quantityToAdd] : quantité relative à ajouter (peut être négatif).
  /// [absoluteQuantity] : quantité absolue à définir (priorité basse vs quantityToAdd).
  /// [newTags] : si non-null, remplace les tags existants.
  /// [isFoil] : statut foil de la carte. Si null, ne modifie pas le foil existant.
  bool upsertCardInList(
    List<DeckCard> cards, {
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    bool matchByFoil = false,
    bool? isFoil,
    List<String>? newTags,
  }) {
    final index = cards.indexWhere((c) =>
        c.scryfallId == scryfallId &&
        (!matchByFoil || c.isFoil == (isFoil ?? false)));

    if (index != -1) {
      final existingCard = cards[index];
      int newQuantity = existingCard.quantity;

      if (quantityToAdd != null) {
        newQuantity += quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newTags != null) existingCard.tags = newTags;
      if (isFoil != null) existingCard.isFoil = isFoil;

      if (newQuantity <= 0) {
        cards.removeAt(index);
      } else {
        existingCard.quantity = newQuantity;
      }
    } else {
      int newQuantity = 0;
      if (quantityToAdd != null) {
        newQuantity = quantityToAdd;
      } else if (absoluteQuantity != null) {
        newQuantity = absoluteQuantity;
      }

      if (newQuantity > 0) {
        cards.add(DeckCard(
          scryfallId: scryfallId,
          name: cardName,
          quantity: newQuantity,
          isFoil: isFoil ?? false,
          tags: newTags ?? [],
        ));
      }
    }
    return true;
  }
}
