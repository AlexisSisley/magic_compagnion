// Fichier : lib/controllers/collection_list_controller.dart
// Controller pour CollectionListTab - extrait la logique metier (filtrage, tri, prix, rarete).

import 'dart:ui';

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../models/search_filters.dart';
import '../utils/price_helper.dart';

// --- ETAT IMMUTABLE ---

class CollectionListState {
  final List<DeckCard> filteredCards;
  final List<Map<String, dynamic>> topCards;

  const CollectionListState({
    this.filteredCards = const [],
    this.topCards = const [],
  });

  CollectionListState copyWith({
    List<DeckCard>? filteredCards,
    List<Map<String, dynamic>>? topCards,
  }) {
    return CollectionListState(
      filteredCards: filteredCards ?? this.filteredCards,
      topCards: topCards ?? this.topCards,
    );
  }
}

// --- CONTROLLER ---

class CollectionListController {
  /// Filtre et trie une liste de [DeckCard] selon la requete, les filtres actifs
  /// et les donnees Scryfall completes.
  ///
  /// Retourne la liste filtree et triee.
  static List<DeckCard> filterAndSort({
    required List<DeckCard> cards,
    required List<ScryfallCard> fullCardData,
    required String filterQuery,
    required SearchFilters activeFilters,
  }) {
    List<DeckCard> filtered = cards.where((card) {
      // Filtre par nom
      if (filterQuery.isNotEmpty &&
          !card.name.toLowerCase().contains(filterQuery.toLowerCase())) {
        return false;
      }

      // Filtre par tags
      if (activeFilters.tags.isNotEmpty) {
        if (!activeFilters.tags.every((tag) => card.tags.contains(tag))) {
          return false;
        }
      }

      // Filtres avances necessitant les donnees Scryfall
      if (activeFilters.cardType != null ||
          activeFilters.colors.isNotEmpty ||
          activeFilters.minCmc != null ||
          activeFilters.maxCmc != null ||
          activeFilters.keyword != null) {
        final sc = fullCardData.where((s) => s.id == card.scryfallId).firstOrNull;
        if (sc == null) return false;

        if (activeFilters.cardType != null &&
            !sc.typeLine
                .toLowerCase()
                .contains(activeFilters.cardType!.toLowerCase())) {
          return false;
        }

        if (activeFilters.colors.isNotEmpty) {
          final colors = sc.colorIdentity.toSet();
          if (!activeFilters.colors.every((c) => colors.contains(c))) {
            return false;
          }
        }

        if (activeFilters.minCmc != null &&
            (sc.cmc ?? 0) < activeFilters.minCmc!) {
          return false;
        }
        if (activeFilters.maxCmc != null &&
            (sc.cmc ?? 0) > activeFilters.maxCmc!) {
          return false;
        }

        if (activeFilters.keyword != null &&
            !sc.rulesText
                .toLowerCase()
                .contains(activeFilters.keyword!.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();

    // Tri
    filtered.sort((a, b) {
      int result = 0;
      switch (activeFilters.sortType) {
        case 'price':
          final pA = getPrice(a, fullCardData);
          final pB = getPrice(b, fullCardData);
          result = pA.compareTo(pB);
          break;
        case 'cmc':
          final cA = getCmc(a, fullCardData);
          final cB = getCmc(b, fullCardData);
          result = cA.compareTo(cB);
          break;
        case 'type':
          result = a.name.compareTo(b.name);
          break;
        case 'name':
        default:
          result = a.name.compareTo(b.name);
          break;
      }
      return activeFilters.sortAscending ? result : -result;
    });

    return filtered;
  }

  /// Calcule le top N des cartes les plus cheres a partir d'une collection.
  ///
  /// Retourne une liste de maps contenant 'name', 'unitPrice', 'quantity',
  /// 'totalPrice' et 'image'.
  static List<Map<String, dynamic>> calculateTopCards({
    required List<DeckCard> cards,
    required List<ScryfallCard> fullCardData,
    int count = 15,
  }) {
    List<Map<String, dynamic>> topCards = [];

    for (final deckCard in cards) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      final scryfallCard =
          fullCardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
      if (scryfallCard == null) continue;
      final double unitPrice = PriceHelper.bestPrice(scryfallCard.prices);
      if (unitPrice > 0) {
        topCards.add({
          'name': scryfallCard.name,
          'unitPrice': unitPrice,
          'quantity': deckCard.quantity,
          'totalPrice': unitPrice * deckCard.quantity,
          'image': scryfallCard.smallImageUrl,
        });
      }
    }

    // Tri par prix total decroissant
    topCards.sort(
        (a, b) => (b['totalPrice'] as double).compareTo(a['totalPrice'] as double));

    return topCards.take(count).toList();
  }

  /// Retourne le prix unitaire d'une carte (foil ou normal).
  ///
  /// [card] La carte du deck.
  /// [fullCardData] Les donnees Scryfall completes.
  /// [isFoil] Surcharge optionnelle du statut foil (par defaut utilise card.isFoil).
  static double getPrice(DeckCard card, List<ScryfallCard> fullCardData,
      {bool? isFoil}) {
    final sc = fullCardData.where((s) => s.id == card.scryfallId).firstOrNull;
    if (sc == null) return 0.0;
    final useFoil = isFoil ?? card.isFoil;
    return PriceHelper.bestPrice(sc.prices, isFoil: useFoil);
  }

  /// Retourne le CMC (Converted Mana Cost) d'une carte.
  static double getCmc(DeckCard card, List<ScryfallCard> fullCardData) {
    final sc = fullCardData.where((s) => s.id == card.scryfallId).firstOrNull;
    return sc?.cmc ?? 0.0;
  }

  /// Retourne la couleur associee a une rarete de carte MTG.
  static Color getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return const Color(0x3DFFFFFF); // AppColors.borderMedium
      case 'uncommon':
        return const Color(0xFFC0C0C0); // Argent
      case 'rare':
        return const Color(0xFFFFD700); // Or
      case 'mythic':
        return const Color(0xFFFF4500); // Rouge-orange
      default:
        return const Color(0x00000000); // AppColors.transparent
    }
  }
}
