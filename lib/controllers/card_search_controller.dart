// Fichier : lib/controllers/card_search_controller.dart
// Controller pour CardSearchPage - extrait la logique metier de la page.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../models/search_filters.dart';
import '../providers/service_providers.dart';
import '../services/collection_service.dart';
import '../services/local_card_service.dart';
import '../services/scryfall_api_service.dart';
import '../services/wishlist_service.dart';

// --- ETAT IMMUTABLE ---

class CardSearchState {
  final List<ScryfallCard> searchResults;
  final List<ScryfallCard> fullLocalResults;
  final String? nextPageUrl;
  final bool isApiLoadingMore;
  final SearchFilters activeFilters;
  final bool isLoading;
  final String statusMessage;
  final bool isGridView;
  final String sortBy;
  final List<DeckCard> collection;
  final List<DeckCard> flatWishlist;

  // --- Sprint 9 : Index rapide pour badges collection ---
  final Map<String, int> collectionIndex;     // scryfallId -> quantite normale
  final Map<String, int> collectionFoilIndex; // scryfallId -> quantite foil
  final Set<String> wishlistCardNames;         // noms des cartes en wishlist

  static const int localPageSize = 30;

  CardSearchState({
    this.searchResults = const [],
    this.fullLocalResults = const [],
    this.nextPageUrl,
    this.isApiLoadingMore = false,
    SearchFilters? activeFilters,
    this.isLoading = false,
    this.statusMessage = 'Entrez un nom ou utilisez les filtres.',
    this.isGridView = false,
    this.sortBy = 'name',
    this.collection = const [],
    this.flatWishlist = const [],
    this.collectionIndex = const {},
    this.collectionFoilIndex = const {},
    this.wishlistCardNames = const {},
  }) : activeFilters = activeFilters ?? const SearchFilters();

  CardSearchState copyWith({
    List<ScryfallCard>? searchResults,
    List<ScryfallCard>? fullLocalResults,
    String? nextPageUrl,
    bool clearNextPageUrl = false,
    bool? isApiLoadingMore,
    SearchFilters? activeFilters,
    bool? isLoading,
    String? statusMessage,
    bool? isGridView,
    String? sortBy,
    List<DeckCard>? collection,
    List<DeckCard>? flatWishlist,
    Map<String, int>? collectionIndex,
    Map<String, int>? collectionFoilIndex,
    Set<String>? wishlistCardNames,
  }) {
    return CardSearchState(
      searchResults: searchResults ?? this.searchResults,
      fullLocalResults: fullLocalResults ?? this.fullLocalResults,
      nextPageUrl: clearNextPageUrl ? null : (nextPageUrl ?? this.nextPageUrl),
      isApiLoadingMore: isApiLoadingMore ?? this.isApiLoadingMore,
      activeFilters: activeFilters ?? this.activeFilters,
      isLoading: isLoading ?? this.isLoading,
      statusMessage: statusMessage ?? this.statusMessage,
      isGridView: isGridView ?? this.isGridView,
      sortBy: sortBy ?? this.sortBy,
      collection: collection ?? this.collection,
      flatWishlist: flatWishlist ?? this.flatWishlist,
      collectionIndex: collectionIndex ?? this.collectionIndex,
      collectionFoilIndex: collectionFoilIndex ?? this.collectionFoilIndex,
      wishlistCardNames: wishlistCardNames ?? this.wishlistCardNames,
    );
  }

  // --- Computed properties ---

  bool get hasActiveFilters =>
      activeFilters.setCode != null ||
      activeFilters.cardType != null ||
      activeFilters.colors.isNotEmpty ||
      activeFilters.minCmc != null ||
      activeFilters.maxCmc != null ||
      activeFilters.rarity != null ||
      activeFilters.keyword != null ||
      activeFilters.maxPrice != null;

  bool get hasMoreLocal =>
      fullLocalResults.isNotEmpty &&
      searchResults.length < fullLocalResults.length;

  bool get hasMoreApi => nextPageUrl != null;

  /// Result count display string.
  String get resultCountLabel {
    if (fullLocalResults.isNotEmpty) {
      return '${searchResults.length}/${fullLocalResults.length}';
    }
    return '${searchResults.length} cartes';
  }

  bool isCardInWishlist(String cardName) =>
      flatWishlist.any((c) => c.name == cardName);

  bool isCardInCollection(String scryfallId) =>
      collection.any((c) => c.scryfallId == scryfallId);
}

// --- CONTROLLER (StateNotifier) ---

class CardSearchController extends StateNotifier<CardSearchState> {
  final LocalCardService _localCardService;
  final CollectionService _collectionService;
  final WishlistService _wishlistService;
  final ScryfallApiService _apiService;

  Timer? _debounce;

  CardSearchController({
    required LocalCardService localCardService,
    required CollectionService collectionService,
    required WishlistService wishlistService,
    required ScryfallApiService apiService,
  })  : _localCardService = localCardService,
        _collectionService = collectionService,
        _wishlistService = wishlistService,
        _apiService = apiService,
        super(CardSearchState()) {
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      loadLocalData(),
      _initLocalDatabase(),
    ]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // --- INITIALISATION ---

  Future<void> _initLocalDatabase() async {
    await _localCardService.loadLocalData();
  }

  Future<void> loadLocalData() async {
    final collection = await _collectionService.loadCollection();
    final wishlists = await _wishlistService.loadWishlists();
    final allWishlistCards = wishlists.expand((w) => w.cards).toList();

    // Index rapide pour les badges collection (O(1) lookup)
    final Map<String, int> collIdx = {};
    final Map<String, int> foilIdx = {};
    for (final card in collection) {
      if (card.isFoil) {
        foilIdx[card.scryfallId] = (foilIdx[card.scryfallId] ?? 0) + card.quantity;
      } else {
        collIdx[card.scryfallId] = (collIdx[card.scryfallId] ?? 0) + card.quantity;
      }
    }
    final wishlistNames = allWishlistCards.map((c) => c.name).toSet();

    if (!mounted) return;
    state = state.copyWith(
      collection: collection,
      flatWishlist: allWishlistCards,
      collectionIndex: collIdx,
      collectionFoilIndex: foilIdx,
      wishlistCardNames: wishlistNames,
    );
  }

  // --- SCROLL PAGINATION ---

  void onScroll({required bool nearEnd}) {
    if (!nearEnd) return;
    if (state.nextPageUrl != null) {
      loadMoreApiResults();
    } else if (state.fullLocalResults.isNotEmpty) {
      loadMoreLocalResults();
    }
  }

  void loadMoreLocalResults() {
    if (state.searchResults.length >= state.fullLocalResults.length) return;
    final int nextCount = (state.searchResults.length + CardSearchState.localPageSize)
        .clamp(0, state.fullLocalResults.length);
    state = state.copyWith(
      searchResults: state.fullLocalResults.sublist(0, nextCount),
    );
  }

  Future<void> loadMoreApiResults() async {
    if (state.isApiLoadingMore || state.nextPageUrl == null) return;
    state = state.copyWith(isApiLoadingMore: true);

    try {
      final Map<String, dynamic> data =
          await _apiService.fetchNextPage(state.nextPageUrl!);
      final String? nextUri = data['next_page'];
      final List<dynamic> rawList = data['data'] ?? [];
      List<ScryfallCard> newCards =
          rawList.map((json) => ScryfallCard.fromJson(json)).toList();

      if (state.sortBy == 'type') {
        newCards.sort((a, b) => a.typeLine.compareTo(b.typeLine));
      }

      if (!mounted) return;
      state = state.copyWith(
        searchResults: [...state.searchResults, ...newCards],
        nextPageUrl: nextUri,
        clearNextPageUrl: nextUri == null,
        isApiLoadingMore: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isApiLoadingMore: false);
    }
  }

  // --- SEARCH (debounced) ---

  /// Called by the text field's onChanged.
  /// Returns true if search should switch to the first tab (for the UI to handle).
  void onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().isNotEmpty || state.hasActiveFilters) {
        searchCards(query);
      }
    });
  }

  /// Main search entry point.
  /// Returns true if the tab should switch to index 0 (cards tab).
  Future<bool> searchCards(String query) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty && !state.hasActiveFilters) {
      state = state.copyWith(
        searchResults: [],
        fullLocalResults: [],
        clearNextPageUrl: true,
        statusMessage: 'Veuillez entrer un critère.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      searchResults: [],
      fullLocalResults: [],
      clearNextPageUrl: true,
      statusMessage: 'Recherche...',
    );

    // 1. PRIORITE LOCALE
    if (_localCardService.isLoaded && state.activeFilters.setCode == null) {
      bool localSuccess = await _performLocalSearch(trimmed);
      if (localSuccess) return true;
    }

    // 2. APPEL API
    bool apiSuccess = await _searchCardsApi(trimmed);

    // 3. FALLBACK
    if (!apiSuccess && _localCardService.isLoaded) {
      state = state.copyWith(
        statusMessage: 'Erreur API. Recherche locale de secours...',
      );
      await _performLocalSearch(trimmed, ignoreSetFilter: true);
      if (mounted && state.searchResults.isNotEmpty) {
        state = state.copyWith(
          statusMessage:
              '${state.searchResults.length} résultats (Mode Hors-Ligne / Fallback)',
        );
      }
    }

    return true;
  }

  Future<bool> _performLocalSearch(String query,
      {bool ignoreSetFilter = false}) async {
    await Future.delayed(const Duration(milliseconds: 50));

    String? setCodeFilter =
        ignoreSetFilter ? null : state.activeFilters.setCode;
    SearchFilters effectiveFilters =
        state.activeFilters.copyWith(setCode: setCodeFilter);

    List<ScryfallCard> results = await _localCardService.searchCards(
      query: query,
      filters: effectiveFilters,
    );

    if (results.isNotEmpty) {
      _applySort(results);
      results = _applyPriceFilter(results);
      if (!mounted) return false;
      final int initialCount =
          (results.length < CardSearchState.localPageSize)
              ? results.length
              : CardSearchState.localPageSize;
      state = state.copyWith(
        isLoading: false,
        fullLocalResults: results,
        searchResults: results.sublist(0, initialCount),
        statusMessage: '${results.length} cartes trouvées (Local)',
      );
      return true;
    }
    return false;
  }

  Future<bool> _searchCardsApi(String query) async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }

    List<String> queryParts = [];
    if (query.isNotEmpty) queryParts.add(query);

    final filters = state.activeFilters;
    if (filters.setCode != null) queryParts.add('e:${filters.setCode}');
    if (filters.colors.isNotEmpty) {
      queryParts.add('c:${filters.colors.join()}');
    }
    if (filters.cardType != null) queryParts.add('t:${filters.cardType}');
    if (filters.rarity != null) queryParts.add('r:${filters.rarity}');
    if (filters.minCmc != null) {
      queryParts.add('cmc>=${filters.minCmc!.toInt()}');
    }
    if (filters.maxCmc != null) {
      queryParts.add('cmc<=${filters.maxCmc!.toInt()}');
    }
    if (filters.keyword != null) {
      queryParts
          .add('o:"${filters.keyword!.replaceAll('"', '')}"');
    }

    final String finalQuery = queryParts.join(' ');
    final prefs = await SharedPreferences.getInstance();
    final String lang = prefs.getString('glossaryLang') ?? 'fr';

    try {
      String unique = filters.setCode != null ? 'prints' : 'cards';
      String? order;
      if (state.sortBy == 'cmc') {
        order = 'cmc';
      } else if (state.sortBy == 'eur' || state.sortBy == 'price_desc' || state.sortBy == 'price_asc') {
        order = 'eur';
      } else {
        order = 'name';
      }

      final Map<String, dynamic> data = await _apiService.searchCards(
        finalQuery,
        lang: lang,
        unique: unique,
        order: order,
      );

      String? nextPage;
      if (data.containsKey('has_more') && data['has_more'] == true) {
        nextPage = data['next_page'];
      }

      final List<dynamic> rawList = data['data'] ?? [];
      List<ScryfallCard> apiResults =
          rawList.map((json) => ScryfallCard.fromJson(json)).toList();

      if (state.sortBy == 'type') {
        apiResults.sort((a, b) => a.typeLine.compareTo(b.typeLine));
      }

      // Filtre prix max cote client
      apiResults = _applyPriceFilter(apiResults);

      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        searchResults: apiResults,
        nextPageUrl: nextPage,
        clearNextPageUrl: nextPage == null,
        statusMessage: apiResults.isEmpty
            ? 'Ce ne sont pas les cartes que vous recherchez...'
            : state.statusMessage,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Erreur réseau',
      );
      return false;
    }
  }

  // --- SORTING ---

  void _applySort(List<ScryfallCard> list) {
    switch (state.sortBy) {
      case 'cmc':
        list.sort((a, b) => (a.cmc ?? 0).compareTo(b.cmc ?? 0));
        break;
      case 'type':
        list.sort((a, b) => a.typeLine.compareTo(b.typeLine));
        break;
      case 'eur':
      case 'price_desc':
        list.sort((a, b) =>
            (double.tryParse(b.prices['eur']?.toString() ?? '0') ?? 0)
                .compareTo(double.tryParse(a.prices['eur']?.toString() ?? '0') ?? 0));
        break;
      case 'price_asc':
        list.sort((a, b) =>
            (double.tryParse(a.prices['eur']?.toString() ?? '0') ?? 0)
                .compareTo(double.tryParse(b.prices['eur']?.toString() ?? '0') ?? 0));
        break;
      case 'name':
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
  }

  /// Filtre les cartes par prix max (cote client).
  List<ScryfallCard> _applyPriceFilter(List<ScryfallCard> cards) {
    final maxPrice = state.activeFilters.maxPrice;
    if (maxPrice == null) return cards;
    return cards.where((card) {
      final priceStr = card.prices['eur']?.toString();
      if (priceStr == null) return false;
      final price = double.tryParse(priceStr) ?? 0;
      return price <= maxPrice;
    }).toList();
  }

  /// Change the sort method and re-triggers search.
  /// Returns true if sort changed (so the UI can re-trigger search).
  bool updateSort(String newSortBy) {
    if (state.sortBy == newSortBy) return false;
    state = state.copyWith(sortBy: newSortBy);
    return true;
  }

  // --- FILTERS ---

  void updateFilters(SearchFilters newFilters) {
    state = state.copyWith(activeFilters: newFilters);
  }

  /// Called when a set is selected from the sets tab.
  void onSetSelected(String setCode) {
    state = state.copyWith(
      activeFilters: state.activeFilters.copyWith(setCode: setCode),
    );
  }

  /// Reset all filters and results.
  void resetFilters() {
    state = state.copyWith(
      activeFilters: const SearchFilters(),
      searchResults: [],
      fullLocalResults: [],
      clearNextPageUrl: true,
      statusMessage: 'Entrez un nom ou choisissez une édition.',
    );
  }

  /// Clear just the search text results (keep filters).
  void clearSearchResults() {
    state = state.copyWith(
      searchResults: [],
      fullLocalResults: [],
      clearNextPageUrl: true,
    );
  }

  // --- VIEW MODE ---

  void toggleGridView() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  // --- COLLECTION ACTIONS ---

  /// Toggle collection status. Returns a message for the UI to display.
  Future<String> toggleCollection(
      String id, String name, bool currentState) async {
    // Optimistic UI update
    if (currentState) {
      final newCollection = List<DeckCard>.from(state.collection)
        ..removeWhere((c) => c.scryfallId == id);
      state = state.copyWith(collection: newCollection);
    } else {
      final newCollection = List<DeckCard>.from(state.collection)
        ..add(DeckCard(scryfallId: id, name: name, quantity: 1));
      state = state.copyWith(collection: newCollection);
    }

    // Service call
    if (currentState) {
      await _collectionService.upsertCardInCollection(
          scryfallId: id, cardName: name, absoluteQuantity: 0);
    } else {
      await _collectionService.upsertCardInCollection(
          scryfallId: id, cardName: name, quantityToAdd: 1);
    }

    await loadLocalData();
    return currentState
        ? 'Retiré de la collection'
        : 'Ajouté à la collection';
  }

  // --- WISHLIST ACTIONS ---

  /// Remove a card from all wishlists by name. Returns a feedback message.
  Future<String> removeFromAllWishlists(String name) async {
    // Optimistic UI
    final newWishlist = List<DeckCard>.from(state.flatWishlist)
      ..removeWhere((c) => c.name == name);
    state = state.copyWith(flatWishlist: newWishlist);

    final lists = await _wishlistService.loadWishlists();
    for (var list in lists) {
      var cardsToRemove = list.cards.where((c) => c.name == name).toList();
      for (var c in cardsToRemove) {
        await _wishlistService.upsertCard(
          wishlistId: list.id,
          scryfallId: c.scryfallId,
          cardName: name,
          absoluteQuantity: 0,
        );
      }
    }

    await loadLocalData();
    return 'Retiré de toutes les Wishlists';
  }

  /// Add a card to a specific wishlist. Returns a feedback message.
  Future<String> addToWishlist(
      String wishlistId, String scryfallId, String cardName) async {
    // Optimistic UI
    final newWishlist = List<DeckCard>.from(state.flatWishlist)
      ..add(DeckCard(scryfallId: scryfallId, name: cardName, quantity: 1));
    state = state.copyWith(flatWishlist: newWishlist);

    await _wishlistService.upsertCard(
      wishlistId: wishlistId,
      scryfallId: scryfallId,
      cardName: cardName,
      quantityToAdd: 1,
    );

    await loadLocalData();
    return 'Ajouté à la Wishlist';
  }
}

// --- PROVIDER ---

final cardSearchControllerProvider =
    StateNotifierProvider.autoDispose<CardSearchController, CardSearchState>(
  (ref) {
    final localCardService = ref.watch(localCardServiceProvider);
    final collectionService = ref.watch(collectionServiceProvider);
    final wishlistService = ref.watch(wishlistServiceProvider);
    final apiService = ref.watch(scryfallApiServiceProvider);

    return CardSearchController(
      localCardService: localCardService,
      collectionService: collectionService,
      wishlistService: wishlistService,
      apiService: apiService,
    );
  },
);
