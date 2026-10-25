// Fichier : lib/controllers/deck_list_filters.dart
// Filtres et tri de la bibliotheque de decks, en fonctions pures : le
// controleur ne fait que les brancher sur son etat, ce qui les rend testables
// sans base ni service.

import '../models/deck_model.dart';

enum DeckSort { name, priceDesc, priceAsc, updated, cardCount }

String deckSortLabel(DeckSort sort) {
  switch (sort) {
    case DeckSort.name:
      return 'Nom (A-Z)';
    case DeckSort.priceDesc:
      return 'Prix décroissant';
    case DeckSort.priceAsc:
      return 'Prix croissant';
    case DeckSort.updated:
      return 'Modifié récemment';
    case DeckSort.cardCount:
      return 'Nombre de cartes';
  }
}

class DeckFilterCriteria {
  final String query;

  /// Nul = tous les formats.
  final String? format;

  /// Nul = pas de filtre ; liste vide = decks incolores.
  final List<String>? identityColors;
  final List<String> tags;
  final (double, double)? priceRange;
  final DeckSort sort;

  const DeckFilterCriteria({
    this.query = '',
    this.format,
    this.identityColors,
    this.tags = const [],
    this.priceRange,
    this.sort = DeckSort.name,
  });

  DeckFilterCriteria copyWith({
    String? query,
    String? format,
    List<String>? identityColors,
    List<String>? tags,
    (double, double)? priceRange,
    DeckSort? sort,
    bool clearFormat = false,
    bool clearIdentity = false,
    bool clearPriceRange = false,
  }) {
    return DeckFilterCriteria(
      query: query ?? this.query,
      format: clearFormat ? null : (format ?? this.format),
      identityColors:
          clearIdentity ? null : (identityColors ?? this.identityColors),
      tags: tags ?? this.tags,
      priceRange: clearPriceRange ? null : (priceRange ?? this.priceRange),
      sort: sort ?? this.sort,
    );
  }
}

int _mainboardCount(Deck d) =>
    d.mainboard.fold<int>(0, (sum, c) => sum + c.quantity);

List<Deck> applyDeckFilters(
  List<Deck> decks,
  Map<String, double> prices,
  DeckFilterCriteria c,
) {
  final query = c.query.toLowerCase();
  final format = c.format?.toLowerCase();

  final result = decks.where((deck) {
    if (!deck.name.toLowerCase().contains(query)) return false;

    // Le format est celui que le deck porte (pose par l'import et par le
    // choix du commandant), pas une deduction depuis la presence d'un
    // commandant.
    if (format != null && deck.format.toLowerCase() != format) return false;

    final identity = c.identityColors;
    if (identity != null) {
      if (identity.isEmpty) {
        if (deck.colors.isNotEmpty) return false;
      } else {
        final deckSet = deck.colors.toSet();
        final filterSet = identity.toSet();
        if (deckSet.length != filterSet.length ||
            !deckSet.containsAll(filterSet)) {
          return false;
        }
      }
    }

    // Les tags sont des dossiers : selectionner plusieurs dossiers, c'est
    // vouloir voir le contenu de chacun, donc l'union et non l'intersection.
    if (c.tags.isNotEmpty && !deck.tags.any(c.tags.contains)) return false;

    // Un deck sans prix calcule vaut 0.
    final range = c.priceRange;
    if (range != null) {
      final price = prices[deck.id] ?? 0;
      if (price < range.$1 || price > range.$2) return false;
    }
    return true;
  }).toList();

  int byName(Deck a, Deck b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  double priceOf(Deck d) => prices[d.id] ?? 0;

  result.sort((a, b) {
    switch (c.sort) {
      case DeckSort.name:
        return byName(a, b);
      case DeckSort.priceDesc:
        return priceOf(b).compareTo(priceOf(a));
      case DeckSort.priceAsc:
        return priceOf(a).compareTo(priceOf(b));
      case DeckSort.updated:
        final ua = a.updatedAt;
        final ub = b.updatedAt;
        if (ua == null && ub == null) return byName(a, b);
        // Les decks sans date (anterieurs au suivi) passent apres les autres.
        if (ua == null) return 1;
        if (ub == null) return -1;
        final cmp = ub.compareTo(ua);
        return cmp != 0 ? cmp : byName(a, b);
      case DeckSort.cardCount:
        final cmp = _mainboardCount(b).compareTo(_mainboardCount(a));
        return cmp != 0 ? cmp : byName(a, b);
    }
  });
  return result;
}

/// Nombre de filtres poses. Les tags comptent pour un seul, quel que soit leur
/// nombre ; la recherche et le tri ne sont pas des filtres.
int activeFilterCount(DeckFilterCriteria c) {
  var n = 0;
  if (c.format != null) n++;
  if (c.identityColors != null) n++;
  if (c.tags.isNotEmpty) n++;
  if (c.priceRange != null) n++;
  return n;
}

/// Retire des tags selectionnes ceux qu'aucun deck ne porte plus : sinon un
/// filtre sur un dossier vide rendrait une liste vide sans moyen de comprendre.
List<String> pruneSelectedTags(List<String> selected, List<Deck> decks) {
  final existing = {for (final d in decks) ...d.tags};
  return selected.where(existing.contains).toList();
}
