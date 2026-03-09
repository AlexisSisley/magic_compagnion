// Fichier : lib/controllers/set_detail_controller.dart
// Controller pour SetDetailPage - extrait la logique metier de la page.

import 'package:flutter_riverpod/legacy.dart';

import '../models/scryfall_card_model.dart';
import '../models/scryfall_set_model.dart';
import '../models/search_filters.dart';
import '../models/wishlist_model.dart';
import '../providers/service_providers.dart';
import '../utils/price_helper.dart';
import '../services/collection_service.dart';
import '../services/wishlist_service.dart';
import '../services/scryfall_api_service.dart';

// --- CLASSE UTILITAIRE POUR L'AFFICHAGE ---

class SetCardDisplayItem {
  final ScryfallCard card;
  final bool isFoil;

  SetCardDisplayItem(this.card, this.isFoil);
}

// --- Fonction helper globale ---

String makeKey(String id, bool isFoil) => "$id|${isFoil ? 'foil' : 'normal'}";

// --- RESULT OBJECT pour les actions batch ---

class SetDetailActionResult {
  final int count;
  final bool success;
  final String message;

  const SetDetailActionResult({
    required this.count,
    this.success = true,
    this.message = '',
  });
}

// --- ETAT IMMUTABLE ---

class SetDetailState {
  final List<ScryfallCard> allCards;
  final List<SetCardDisplayItem> gridItems;
  final bool isLoading;
  final Set<String> ownedKeys;
  final Set<String> wishlistKeys;
  final Set<String> selectedKeys;
  final Map<String, int> rarityCounts;
  final SearchFilters activeFilters;
  final String sortBy;
  final bool sortAsc;
  final bool hideOwned;
  final String searchQuery;
  final String? errorMessage;

  SetDetailState({
    this.allCards = const [],
    this.gridItems = const [],
    this.isLoading = true,
    this.ownedKeys = const {},
    this.wishlistKeys = const {},
    this.selectedKeys = const {},
    this.rarityCounts = const {'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0},
    SearchFilters? activeFilters,
    this.sortBy = 'number',
    this.sortAsc = true,
    this.hideOwned = false,
    this.searchQuery = '',
    this.errorMessage,
  }) : activeFilters = activeFilters ?? const SearchFilters();

  SetDetailState copyWith({
    List<ScryfallCard>? allCards,
    List<SetCardDisplayItem>? gridItems,
    bool? isLoading,
    Set<String>? ownedKeys,
    Set<String>? wishlistKeys,
    Set<String>? selectedKeys,
    Map<String, int>? rarityCounts,
    SearchFilters? activeFilters,
    String? sortBy,
    bool? sortAsc,
    bool? hideOwned,
    String? searchQuery,
    String? errorMessage,
  }) {
    return SetDetailState(
      allCards: allCards ?? this.allCards,
      gridItems: gridItems ?? this.gridItems,
      isLoading: isLoading ?? this.isLoading,
      ownedKeys: ownedKeys ?? this.ownedKeys,
      wishlistKeys: wishlistKeys ?? this.wishlistKeys,
      selectedKeys: selectedKeys ?? this.selectedKeys,
      rarityCounts: rarityCounts ?? this.rarityCounts,
      activeFilters: activeFilters ?? this.activeFilters,
      sortBy: sortBy ?? this.sortBy,
      sortAsc: sortAsc ?? this.sortAsc,
      hideOwned: hideOwned ?? this.hideOwned,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }

  // --- Computed properties ---

  int get totalSetCount => allCards.length;

  int get totalOwnedUnique => allCards.where((c) =>
      ownedKeys.contains(makeKey(c.id, false)) ||
      ownedKeys.contains(makeKey(c.id, true))).length;

  int get totalMissing => totalSetCount - totalOwnedUnique;

  bool get hasActiveFilters =>
      activeFilters.colors.isNotEmpty ||
      activeFilters.cardType != null ||
      hideOwned;
}

// --- CONTROLLER (StateNotifier) ---

class SetDetailController extends StateNotifier<SetDetailState> {
  final ScryfallSet targetSet;
  final CollectionService _collectionService;
  final WishlistService _wishlistService;
  final ScryfallApiService _apiService;

  SetDetailController({
    required this.targetSet,
    required CollectionService collectionService,
    required WishlistService wishlistService,
    required ScryfallApiService apiService,
  })  : _collectionService = collectionService,
        _wishlistService = wishlistService,
        _apiService = apiService,
        super(SetDetailState()) {
    loadSetCards();
  }

  // --- CHARGEMENT ---

  Future<void> loadSetCards() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    // 1. Collection
    final col = await _collectionService.loadCollection();
    final ownedKeys = <String>{};
    for (var c in col) {
      ownedKeys.add(makeKey(c.scryfallId, c.isFoil));
    }

    // 2. Wishlists
    final wishlists = await _wishlistService.loadWishlists();
    final wishlistKeys = <String>{};
    for (var w in wishlists) {
      for (var c in w.cards) {
        wishlistKeys.add(makeKey(c.scryfallId, c.isFoil));
      }
    }

    // 3. API
    List<ScryfallCard> accumulator = [];

    try {
      Map<String, dynamic> data = await _apiService.searchCards(
        'e:${targetSet.code}',
        unique: 'prints',
        order: 'set',
      );
      final List<dynamic> firstRaw = data['data'] ?? [];
      accumulator.addAll(firstRaw.map((j) => ScryfallCard.fromJson(j)).toList());

      String? nextPageUrl = data['has_more'] == true ? data['next_page'] : null;
      while (nextPageUrl != null) {
        data = await _apiService.fetchNextPage(nextPageUrl);
        nextPageUrl = data['has_more'] == true ? data['next_page'] : null;
        final List<dynamic> raw = data['data'] ?? [];
        accumulator.addAll(raw.map((j) => ScryfallCard.fromJson(j)).toList());
      }

      Map<String, int> counts = {'common': 0, 'uncommon': 0, 'rare': 0, 'mythic': 0};
      for (var c in accumulator) {
        final r = c.rarity.toLowerCase();
        if (counts.containsKey(r)) counts[r] = (counts[r] ?? 0) + 1;
      }

      state = state.copyWith(
        allCards: accumulator,
        rarityCounts: counts,
        ownedKeys: ownedKeys,
        wishlistKeys: wishlistKeys,
        isLoading: false,
      );
      _applyFiltersAndSort();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // --- FILTRES & TRI ---

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFiltersAndSort();
  }

  void updateFilters(SearchFilters filters) {
    state = state.copyWith(activeFilters: filters);
  }

  void updateSort(String sortBy) {
    if (state.sortBy == sortBy) {
      state = state.copyWith(sortAsc: !state.sortAsc);
    } else {
      state = state.copyWith(sortBy: sortBy, sortAsc: true);
    }
    _applyFiltersAndSort();
  }

  void updateHideOwned(bool hideOwned) {
    state = state.copyWith(hideOwned: hideOwned);
  }

  void applyFilters() {
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    final query = state.searchQuery.toLowerCase().trim();
    final filters = state.activeFilters;
    final hideOwned = state.hideOwned;
    final ownedKeys = state.ownedKeys;

    List<ScryfallCard> filtered = state.allCards.where((card) {
      // 1. Recherche Texte
      if (query.isNotEmpty) {
        bool matchName = card.name.toLowerCase().contains(query);
        bool matchNum = card.collectorNumber.toLowerCase() == query;
        if (!matchName && !matchNum) return false;
      }

      // 2. Masquer les possedees
      if (hideOwned) {
        final keyNormal = makeKey(card.id, false);
        final keyFoil = makeKey(card.id, true);
        bool isOwned = ownedKeys.contains(keyNormal) || ownedKeys.contains(keyFoil);
        if (isOwned) return false;
      }

      // 3. Type
      if (filters.cardType != null &&
          !card.typeLine.toLowerCase().contains(filters.cardType!.toLowerCase())) {
        return false;
      }

      // 4. Rarete
      if (filters.rarity != null &&
          card.rarity.toLowerCase() != filters.rarity!.toLowerCase()) {
        return false;
      }

      // 5. Couleurs (W, U, B, R, G, C, M)
      if (filters.colors.isNotEmpty) {
        final cardColors = card.colorIdentity.toSet();

        bool wantsColorless = filters.colors.contains('C');
        bool wantsMulti = filters.colors.contains('M');
        Set<String> standardColors =
            filters.colors.where((c) => !['C', 'M'].contains(c)).toSet();

        bool match = false;
        if (wantsColorless && cardColors.isEmpty) match = true;
        if (wantsMulti && cardColors.length > 1) match = true;
        if (standardColors.isNotEmpty &&
            cardColors.any((c) => standardColors.contains(c))) {
          match = true;
        }

        if (!match) return false;
      }

      return true;
    }).toList();

    // Tri
    filtered.sort((a, b) {
      int result = 0;
      switch (state.sortBy) {
        case 'name':
          result = a.name.compareTo(b.name);
          break;
        case 'rarity':
          final rarities = {'mythic': 3, 'rare': 2, 'uncommon': 1, 'common': 0};
          result = (rarities[a.rarity] ?? 0).compareTo(rarities[b.rarity] ?? 0);
          break;
        case 'price':
          double pA = PriceHelper.bestPrice(a.prices);
          double pB = PriceHelper.bestPrice(b.prices);
          result = pA.compareTo(pB);
          break;
        case 'number':
        default:
          int nA = int.tryParse(a.collectorNumber) ?? 9999;
          int nB = int.tryParse(b.collectorNumber) ?? 9999;
          result = (nA == nB)
              ? a.collectorNumber.compareTo(b.collectorNumber)
              : nA.compareTo(nB);
          break;
      }
      return state.sortAsc ? result : -result;
    });

    // Build grid items (normal + foil variants)
    List<SetCardDisplayItem> newGridItems = [];
    for (var card in filtered) {
      bool hasNormal = PriceHelper.rawPrice(card.prices) != null || PriceHelper.rawPrice(card.prices, currency: PriceCurrency.usd) != null;
      bool hasFoil =
          PriceHelper.rawPrice(card.prices, isFoil: true) != null || PriceHelper.rawPrice(card.prices, isFoil: true, currency: PriceCurrency.usd) != null;
      if (!hasNormal && !hasFoil) hasNormal = true;

      if (hasNormal) newGridItems.add(SetCardDisplayItem(card, false));
      if (hasFoil) newGridItems.add(SetCardDisplayItem(card, true));
    }

    state = state.copyWith(gridItems: newGridItems);
  }

  // --- ACTIONS DE SELECTION ---

  void toggleSelection(String id, bool isFoil) {
    final key = makeKey(id, isFoil);
    final newSelected = Set<String>.from(state.selectedKeys);
    if (newSelected.contains(key)) {
      newSelected.remove(key);
    } else {
      newSelected.add(key);
    }
    state = state.copyWith(selectedKeys: newSelected);
  }

  void selectAllMissingFiltered() {
    final newSelected = Set<String>.from(state.selectedKeys);
    for (var item in state.gridItems) {
      final key = makeKey(item.card.id, item.isFoil);
      if (!state.ownedKeys.contains(key)) newSelected.add(key);
    }
    state = state.copyWith(selectedKeys: newSelected);
  }

  void clearSelection() {
    state = state.copyWith(selectedKeys: <String>{});
  }

  // --- ACTIONS PRINCIPALES (Ajout/Retrait) ---

  /// Ajoute les cartes selectionnees a la collection.
  Future<SetDetailActionResult> addSelectedToCollection() async {
    if (state.selectedKeys.isEmpty) {
      return const SetDetailActionResult(count: 0);
    }

    state = state.copyWith(isLoading: true);
    int count = 0;

    for (String key in state.selectedKeys) {
      final parts = key.split('|');
      final id = parts[0];
      final isFoil = parts[1] == 'foil';
      final card = state.allCards.where((c) => c.id == id).firstOrNull;
      if (card == null) continue;
      try {
        await _collectionService.addCard(card, 1, isFoil: isFoil);
        count++;
      } catch (e) {
        /* service error */
      }
    }

    await _refreshKeys();
    state = state.copyWith(isLoading: false, selectedKeys: <String>{});
    return SetDetailActionResult(count: count, message: '$count cartes ajoutees !');
  }

  /// Ajoute les cartes selectionnees a une wishlist.
  /// [wishlistId] doit etre fourni (choisi cote UI).
  Future<SetDetailActionResult> addSelectedToWishlist(String wishlistId) async {
    if (state.selectedKeys.isEmpty) {
      return const SetDetailActionResult(count: 0);
    }

    state = state.copyWith(isLoading: true);
    int count = 0;

    for (String key in state.selectedKeys) {
      final parts = key.split('|');
      final id = parts[0];
      final isFoil = parts[1] == 'foil';
      final card = state.allCards.where((c) => c.id == id).firstOrNull;
      if (card == null) continue;
      try {
        await _wishlistService.upsertCard(
          wishlistId: wishlistId,
          scryfallId: card.id,
          cardName: card.name,
          quantityToAdd: 1,
          isFoil: isFoil,
        );
        count++;
      } catch (e) {
        /* service error */
      }
    }

    await _refreshKeys();
    state = state.copyWith(isLoading: false, selectedKeys: <String>{});
    return SetDetailActionResult(count: count, message: '$count cartes ajoutees !');
  }

  /// Retire les cartes selectionnees de la collection.
  Future<SetDetailActionResult> removeSelectedFromCollection() async {
    if (state.selectedKeys.isEmpty) {
      return const SetDetailActionResult(count: 0);
    }

    state = state.copyWith(isLoading: true);
    int count = 0;

    for (String key in state.selectedKeys) {
      final parts = key.split('|');
      final id = parts[0];
      final isFoil = parts[1] == 'foil';
      final card = state.allCards.where((c) => c.id == id).firstOrNull;
      if (card == null) continue;
      try {
        await _collectionService.upsertCardInCollection(
          scryfallId: id,
          cardName: card.name,
          absoluteQuantity: 0,
          isFoil: isFoil,
        );
        count++;
      } catch (e) {
        /* service error */
      }
    }

    await _refreshKeys();
    state = state.copyWith(isLoading: false, selectedKeys: <String>{});
    return SetDetailActionResult(count: count, message: '$count cartes retirees !');
  }

  /// Retire les cartes selectionnees de toutes les wishlists.
  Future<SetDetailActionResult> removeSelectedFromWishlists() async {
    if (state.selectedKeys.isEmpty) {
      return const SetDetailActionResult(count: 0);
    }

    state = state.copyWith(isLoading: true);
    int count = 0;

    for (String key in state.selectedKeys) {
      final parts = key.split('|');
      final id = parts[0];
      final isFoil = parts[1] == 'foil';
      final card = state.allCards.where((c) => c.id == id).firstOrNull;
      if (card == null) continue;
      try {
        final lists = await _wishlistService.loadWishlists();
        for (var list in lists) {
          await _wishlistService.upsertCard(
            wishlistId: list.id,
            scryfallId: id,
            cardName: card.name,
            absoluteQuantity: 0,
            isFoil: isFoil,
          );
        }
        count++;
      } catch (e) {
        /* card not found or service error */
      }
    }

    await _refreshKeys();
    state = state.copyWith(isLoading: false, selectedKeys: <String>{});
    return SetDetailActionResult(count: count, message: '$count cartes retirees !');
  }

  // --- WISHLISTS (pour UI picker) ---

  Future<List<Wishlist>> getWishlists() async {
    return _wishlistService.loadWishlists();
  }

  Future<String?> createWishlistAndGetId(String name) async {
    await _wishlistService.createWishlist(name);
    final updatedLists = await _wishlistService.loadWishlists();
    try {
      final newList = updatedLists.lastWhere((w) => w.name == name);
      return newList.id;
    } catch (_) {
      return null;
    }
  }

  // --- STATS (pour navigation) ---

  Future<List<dynamic>> getSetCollectionForStats() async {
    final fullCollection = await _collectionService.loadCollection();
    return fullCollection
        .where((dc) => state.allCards.any((sc) => sc.id == dc.scryfallId))
        .toList();
  }

  // --- REFRESH INTERNE ---

  Future<void> _refreshKeys() async {
    final col = await _collectionService.loadCollection();
    final newOwnedKeys = <String>{};
    for (var c in col) {
      newOwnedKeys.add(makeKey(c.scryfallId, c.isFoil));
    }

    final w = await _wishlistService.loadWishlists();
    final newWishlistKeys = <String>{};
    for (var l in w) {
      for (var c in l.cards) {
        newWishlistKeys.add(makeKey(c.scryfallId, c.isFoil));
      }
    }

    state = state.copyWith(ownedKeys: newOwnedKeys, wishlistKeys: newWishlistKeys);
  }
}

// --- PROVIDER (family, parametre par ScryfallSet) ---

final setDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<SetDetailController, SetDetailState, ScryfallSet>(
  (ref, targetSet) {
    final collectionService = ref.watch(collectionServiceProvider);
    final wishlistService = ref.watch(wishlistServiceProvider);
    final apiService = ref.watch(scryfallApiServiceProvider);

    return SetDetailController(
      targetSet: targetSet,
      collectionService: collectionService,
      wishlistService: wishlistService,
      apiService: apiService,
    );
  },
);
