// Fichier : lib/controllers/deck_card_picker_controller.dart
// Controller pour DeckCardPicker - extrait la logique metier du widget.

import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/legacy.dart';

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../models/search_filters.dart';
import '../providers/service_providers.dart';
import '../services/collection_service.dart';
import '../services/local_card_service.dart';
import '../services/scryfall_api_service.dart';

// --- ETAT IMMUTABLE ---

class DeckCardPickerState {
  // API search tab
  final List<ScryfallCard> apiResults;
  final bool isSearching;
  final SearchFilters apiFilters;
  final String apiSort;
  final String? nextApiPageUrl;
  final bool isApiLoadingMore;
  final int totalApiResults;

  // Collection tab
  final List<DeckCard> fullCollection;
  final List<DeckCard> displayedCollection;
  final SearchFilters collectionFilters;
  final String collectionSort;

  // Cart
  final Map<String, int> selectedQuantities;
  final Map<String, ScryfallCard> cardCache;

  static const int localPageSize = 30;

  const DeckCardPickerState({
    this.apiResults = const [],
    this.isSearching = false,
    this.apiFilters = const SearchFilters(),
    this.apiSort = 'name',
    this.nextApiPageUrl,
    this.isApiLoadingMore = false,
    this.totalApiResults = 0,
    this.fullCollection = const [],
    this.displayedCollection = const [],
    this.collectionFilters = const SearchFilters(),
    this.collectionSort = 'name',
    this.selectedQuantities = const {},
    this.cardCache = const {},
  });

  DeckCardPickerState copyWith({
    List<ScryfallCard>? apiResults,
    bool? isSearching,
    SearchFilters? apiFilters,
    String? apiSort,
    String? nextApiPageUrl,
    bool? isApiLoadingMore,
    int? totalApiResults,
    List<DeckCard>? fullCollection,
    List<DeckCard>? displayedCollection,
    SearchFilters? collectionFilters,
    String? collectionSort,
    Map<String, int>? selectedQuantities,
    Map<String, ScryfallCard>? cardCache,
    bool clearNextApiPageUrl = false,
  }) {
    return DeckCardPickerState(
      apiResults: apiResults ?? this.apiResults,
      isSearching: isSearching ?? this.isSearching,
      apiFilters: apiFilters ?? this.apiFilters,
      apiSort: apiSort ?? this.apiSort,
      nextApiPageUrl: clearNextApiPageUrl ? null : (nextApiPageUrl ?? this.nextApiPageUrl),
      isApiLoadingMore: isApiLoadingMore ?? this.isApiLoadingMore,
      totalApiResults: totalApiResults ?? this.totalApiResults,
      fullCollection: fullCollection ?? this.fullCollection,
      displayedCollection: displayedCollection ?? this.displayedCollection,
      collectionFilters: collectionFilters ?? this.collectionFilters,
      collectionSort: collectionSort ?? this.collectionSort,
      selectedQuantities: selectedQuantities ?? this.selectedQuantities,
      cardCache: cardCache ?? this.cardCache,
    );
  }

  /// Total number of cards selected in the cart.
  int get totalCards => selectedQuantities.values.fold(0, (sum, qty) => sum + qty);

  /// Number of unique card names selected.
  int get uniqueCardCount => selectedQuantities.length;
}

// --- CONTROLLER (StateNotifier) ---

class DeckCardPickerController extends StateNotifier<DeckCardPickerState> {
  final CollectionService _collectionService;
  final LocalCardService _localCardService;
  final ScryfallApiService _apiService;

  Timer? _debounce;

  DeckCardPickerController({
    required CollectionService collectionService,
    required LocalCardService localCardService,
    required ScryfallApiService apiService,
  })  : _collectionService = collectionService,
        _localCardService = localCardService,
        _apiService = apiService,
        super(const DeckCardPickerState()) {
    loadCollection();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // API SEARCH
  // ===========================================================================

  /// Called when the search text changes. Debounces by 500ms.
  void onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty ||
          state.apiFilters.cardType != null ||
          state.apiFilters.colors.isNotEmpty ||
          state.apiFilters.setCode != null) {
        searchScryfall(query);
      }
    });
  }

  /// Executes the Scryfall API search with current filters and sort.
  Future<void> searchScryfall(String query) async {
    state = state.copyWith(
      isSearching: true,
      apiResults: [],
      clearNextApiPageUrl: true,
      totalApiResults: 0,
    );

    try {
      List<String> parts = [];
      if (query.trim().isNotEmpty) parts.add(query.trim());
      if (state.apiFilters.setCode != null) parts.add('e:${state.apiFilters.setCode}');
      if (state.apiFilters.cardType != null) parts.add('t:${state.apiFilters.cardType}');
      if (state.apiFilters.colors.isNotEmpty) parts.add('c:${state.apiFilters.colors.join()}');
      if (state.apiFilters.rarity != null) parts.add('r:${state.apiFilters.rarity}');
      if (state.apiFilters.minCmc != null) parts.add('cmc>=${state.apiFilters.minCmc!.toInt()}');
      if (state.apiFilters.maxCmc != null) parts.add('cmc<=${state.apiFilters.maxCmc!.toInt()}');
      if (state.apiFilters.keyword != null) {
        parts.add('o:"${state.apiFilters.keyword!.replaceAll('"', '')}"');
      }

      String finalQuery = parts.join(' ');
      if (finalQuery.isEmpty) {
        state = state.copyWith(isSearching: false);
        return;
      }

      final data = await _apiService.searchCards(
        finalQuery,
        unique: 'cards',
        order: state.apiSort,
      );

      final int totalCards = data['total_cards'] ?? 0;
      String? nextPage;
      if (data['has_more'] == true) {
        nextPage = data['next_page'];
      }

      final List<dynamic> raw = data['data'] ?? [];
      final cards = raw.map((json) => ScryfallCard.fromJson(json as Map<String, dynamic>)).toList();

      if (!mounted) return;
      state = state.copyWith(
        apiResults: cards,
        totalApiResults: totalCards,
        nextApiPageUrl: nextPage,
        isSearching: false,
      );
    } catch (e) {
      log('DeckCardPickerController.searchScryfall error: $e');
      if (mounted) {
        state = state.copyWith(isSearching: false);
      }
    }
  }

  /// Loads the next page of API results (infinite scroll).
  Future<void> loadMoreApiResults() async {
    if (state.isApiLoadingMore || state.nextApiPageUrl == null) return;
    state = state.copyWith(isApiLoadingMore: true);

    try {
      final data = await _apiService.fetchNextPage(state.nextApiPageUrl!);
      String? nextPage;
      if (data['has_more'] == true) {
        nextPage = data['next_page'];
      }

      final List<dynamic> raw = data['data'] ?? [];
      final newCards = raw.map((json) => ScryfallCard.fromJson(json as Map<String, dynamic>)).toList();

      if (!mounted) return;
      state = state.copyWith(
        apiResults: [...state.apiResults, ...newCards],
        nextApiPageUrl: nextPage,
        clearNextApiPageUrl: nextPage == null,
        isApiLoadingMore: false,
      );
    } catch (e) {
      log('DeckCardPickerController.loadMoreApiResults error: $e');
      if (mounted) {
        state = state.copyWith(isApiLoadingMore: false);
      }
    }
  }

  /// Updates the API filters and triggers a new search.
  void updateApiFilters(SearchFilters newFilters, String currentQuery) {
    state = state.copyWith(apiFilters: newFilters);
    searchScryfall(currentQuery);
  }

  /// Updates the API sort and triggers a new search.
  void updateApiSort(String newSort, String currentQuery) {
    state = state.copyWith(apiSort: newSort);
    searchScryfall(currentQuery);
  }

  /// Replaces a card in the API results (e.g. after version selector).
  void replaceApiCard(int index, ScryfallCard newVersion) {
    if (index < 0 || index >= state.apiResults.length) return;
    final updatedResults = List<ScryfallCard>.from(state.apiResults);
    updatedResults[index] = newVersion;
    state = state.copyWith(apiResults: updatedResults);
  }

  // ===========================================================================
  // COLLECTION (LOCAL)
  // ===========================================================================

  /// Loads the full collection from the service.
  Future<void> loadCollection() async {
    if (!_localCardService.isLoaded) {
      await _localCardService.loadLocalData();
    }

    final col = await _collectionService.loadCollection();
    if (!mounted) return;
    state = state.copyWith(fullCollection: col);
    applyCollectionFilters('');
  }

  /// Applies text query + advanced filters + sort to the collection.
  void applyCollectionFilters(String query) {
    final lowerQuery = query.toLowerCase();

    // 1. Filter
    List<DeckCard> filtered = state.fullCollection.where((deckCard) {
      if (lowerQuery.isNotEmpty && !deckCard.name.toLowerCase().contains(lowerQuery)) {
        return false;
      }

      if (state.collectionFilters.cardType != null ||
          state.collectionFilters.colors.isNotEmpty ||
          state.collectionFilters.setCode != null ||
          state.collectionFilters.keyword != null) {
        final scryfallCard = _localCardService.getCardById(deckCard.scryfallId);
        if (scryfallCard == null) return false;

        if (state.collectionFilters.cardType != null &&
            !scryfallCard.typeLine.toLowerCase().contains(state.collectionFilters.cardType!.toLowerCase())) {
          return false;
        }
        if (state.collectionFilters.colors.isNotEmpty) {
          final cardColors = scryfallCard.colorIdentity.toSet();
          if (!state.collectionFilters.colors.every((c) => cardColors.contains(c))) return false;
        }
        if (state.collectionFilters.setCode != null &&
            scryfallCard.setCode.toLowerCase() != state.collectionFilters.setCode!.toLowerCase()) {
          return false;
        }
        if (state.collectionFilters.keyword != null &&
            !scryfallCard.rulesText.toLowerCase().contains(state.collectionFilters.keyword!.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      final cardA = _localCardService.getCardById(a.scryfallId);
      final cardB = _localCardService.getCardById(b.scryfallId);

      switch (state.collectionSort) {
        case 'price':
          double priceA = double.tryParse(cardA?.prices['eur'] ?? '0') ?? 0;
          double priceB = double.tryParse(cardB?.prices['eur'] ?? '0') ?? 0;
          return priceB.compareTo(priceA);
        case 'type':
          return (cardA?.typeLine ?? '').compareTo(cardB?.typeLine ?? '');
        case 'name':
        default:
          return a.name.compareTo(b.name);
      }
    });

    // 3. Local pagination
    final int count = (filtered.length < DeckCardPickerState.localPageSize)
        ? filtered.length
        : DeckCardPickerState.localPageSize;
    state = state.copyWith(
      fullCollection: filtered,
      displayedCollection: filtered.sublist(0, count),
    );
  }

  /// Loads the next page of local collection results.
  void loadMoreLocalResults() {
    if (state.displayedCollection.length >= state.fullCollection.length) return;
    final int nextCount = (state.displayedCollection.length + DeckCardPickerState.localPageSize)
        .clamp(0, state.fullCollection.length);
    state = state.copyWith(
      displayedCollection: state.fullCollection.sublist(0, nextCount),
    );
  }

  /// Updates collection filters. Reloads collection from service then refilters.
  Future<void> updateCollectionFilters(SearchFilters newFilters, String currentQuery) async {
    state = state.copyWith(collectionFilters: newFilters);
    // Reload raw collection because the previous call to applyCollectionFilters
    // overwrites fullCollection with filtered results.
    final col = await _collectionService.loadCollection();
    if (!mounted) return;
    state = state.copyWith(fullCollection: col);
    applyCollectionFilters(currentQuery);
  }

  /// Updates the collection sort and reapplies filters.
  void updateCollectionSort(String newSort, String currentQuery) {
    state = state.copyWith(collectionSort: newSort);
    applyCollectionFilters(currentQuery);
  }

  // ===========================================================================
  // CART
  // ===========================================================================

  /// Increment the quantity of a card in the cart.
  void increment(ScryfallCard card) {
    final updatedQuantities = Map<String, int>.from(state.selectedQuantities);
    updatedQuantities[card.id] = (updatedQuantities[card.id] ?? 0) + 1;
    final updatedCache = Map<String, ScryfallCard>.from(state.cardCache);
    updatedCache[card.id] = card;
    state = state.copyWith(
      selectedQuantities: updatedQuantities,
      cardCache: updatedCache,
    );
  }

  /// Decrement the quantity of a card in the cart.
  void decrement(String id) {
    final updatedQuantities = Map<String, int>.from(state.selectedQuantities);
    if (updatedQuantities.containsKey(id)) {
      updatedQuantities[id] = updatedQuantities[id]! - 1;
      if (updatedQuantities[id]! <= 0) {
        updatedQuantities.remove(id);
      }
    }
    state = state.copyWith(selectedQuantities: updatedQuantities);
  }

  /// Builds the result list from the cart and returns it.
  List<Map<String, dynamic>> buildSubmitResult() {
    List<Map<String, dynamic>> result = [];
    state.selectedQuantities.forEach((id, qty) {
      if (state.cardCache.containsKey(id)) {
        result.add({'card': state.cardCache[id], 'quantity': qty});
      }
    });
    return result;
  }
}

// --- PROVIDER ---

final deckCardPickerControllerProvider =
    StateNotifierProvider.autoDispose<DeckCardPickerController, DeckCardPickerState>(
  (ref) {
    final collectionService = ref.watch(collectionServiceProvider);
    final localCardService = ref.watch(localCardServiceProvider);
    final apiService = ref.watch(scryfallApiServiceProvider);

    return DeckCardPickerController(
      collectionService: collectionService,
      localCardService: localCardService,
      apiService: apiService,
    );
  },
);
