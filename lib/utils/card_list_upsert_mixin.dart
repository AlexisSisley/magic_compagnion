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
  /// [proxyQuantity] : nombre de proxys. Si null, ne modifie pas l'existant.
  /// [mergeVariants] : la carte qui arrive fusionne avec l'existante (proxys
  /// additionnes, plafonnes a la quantite finale ; foil = l'un OU l'autre) au
  /// lieu de la remplacer. Elle ne touche alors ni aux tags ni a [tagsEdited] de
  /// la carte existante (corriges a la main, peut-etre) ; a l'insertion, elle
  /// apporte les siens.
  /// [tagsEdited] : si fourni, ecrit (hors fusion).
  bool upsertCardInList(
    List<DeckCard> cards, {
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    bool matchByFoil = false,
    bool? isFoil,
    List<String>? newTags,
    int? proxyQuantity,
    bool mergeVariants = false,
    bool? tagsEdited,
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

      if (!mergeVariants) {
        if (newTags != null) existingCard.tags = newTags;
        if (tagsEdited != null) existingCard.tagsEdited = tagsEdited;
      }
      if (isFoil != null) {
        existingCard.isFoil =
            mergeVariants ? (existingCard.isFoil || isFoil) : isFoil;
      }
      if (proxyQuantity != null) {
        existingCard.proxyQuantity = mergeVariants
            ? (existingCard.proxyQuantity + proxyQuantity)
                .clamp(0, newQuantity < 0 ? 0 : newQuantity)
            : proxyQuantity;
      }

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
          proxyQuantity: proxyQuantity ?? 0,
          isFoil: isFoil ?? false,
          tags: newTags ?? [],
          tagsEdited: tagsEdited ?? false,
        ));
      }
    }
    return true;
  }
}
