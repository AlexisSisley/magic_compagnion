// Fichier : lib/models/card_category.dart

/// Rôle d'une carte dans un deck. Taxonomie fermée, distincte des tags libres
/// de `DeckCard.tags`. L'ordre de déclaration EST l'ordre d'affichage des
/// sections de la liste.
enum CardCategory {
  ramp,
  draw,
  removal,
  wipe,
  protection,
  tutor,
  lands,
  creatures,
  wincon,
  other,
}

/// Libellé français d'une catégorie.
String cardCategoryLabel(CardCategory c) {
  switch (c) {
    case CardCategory.ramp:
      return 'Ramp';
    case CardCategory.draw:
      return 'Pioche';
    case CardCategory.removal:
      return 'Removal';
    case CardCategory.wipe:
      return 'Wipe';
    case CardCategory.protection:
      return 'Protection';
    case CardCategory.tutor:
      return 'Tuteur';
    case CardCategory.lands:
      return 'Terrains';
    case CardCategory.creatures:
      return 'Créatures';
    case CardCategory.wincon:
      return 'Win-con';
    case CardCategory.other:
      return 'Autres';
  }
}

/// Relit une catégorie stockée. Un nom inconnu (sauvegarde d'une version
/// future, valeur corrompue) donne `null` plutôt qu'une erreur : la carte
/// retombe alors sur la déduction automatique.
CardCategory? cardCategoryFromName(String? s) {
  if (s == null) return null;
  for (final c in CardCategory.values) {
    if (c.name == s) return c;
  }
  return null;
}
