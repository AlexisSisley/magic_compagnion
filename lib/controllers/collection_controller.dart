// Fichier : lib/controllers/collection_controller.dart
// Controller pour CollectionPage - extrait la logique metier de la page.

import 'dart:developer';

import 'package:flutter_riverpod/legacy.dart';

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../models/search_filters.dart';
import '../models/wishlist_model.dart';
import '../providers/service_providers.dart';
import '../utils/price_helper.dart';
import '../services/collection_service.dart';
import '../services/deck_service.dart';
import '../services/local_card_service.dart';
import '../services/scryfall_api_service.dart';
import '../services/wishlist_service.dart';

// --- RESULT OBJECT pour les actions ---

class CollectionActionResult {
  final bool success;
  final String message;

  const CollectionActionResult({
    this.success = true,
    this.message = '',
  });
}

// --- ETAT IMMUTABLE ---

class CollectionState {
  final List<DeckCard> collection;
  final List<Wishlist> wishlists;
  final List<ScryfallCard> fullCardData;
  final List<String> availableTags;
  final bool isLoading;
  final SearchFilters activeFilters;

  // Selection mode
  final bool isSelectionMode;
  final Set<String> selectedCardIds;

  // Stats financieres
  final double totalCollectionValue;
  final double totalWishlistValue;
  final double? evolutionValue;
  final double? evolutionPercent;
  final bool hasCalculatedFinance;

  const CollectionState({
    this.collection = const [],
    this.wishlists = const [],
    this.fullCardData = const [],
    this.availableTags = const [],
    this.isLoading = true,
    SearchFilters? activeFilters,
    this.isSelectionMode = false,
    this.selectedCardIds = const {},
    this.totalCollectionValue = 0.0,
    this.totalWishlistValue = 0.0,
    this.evolutionValue,
    this.evolutionPercent,
    this.hasCalculatedFinance = false,
  }) : activeFilters = activeFilters ?? const SearchFilters();

  CollectionState copyWith({
    List<DeckCard>? collection,
    List<Wishlist>? wishlists,
    List<ScryfallCard>? fullCardData,
    List<String>? availableTags,
    bool? isLoading,
    SearchFilters? activeFilters,
    bool? isSelectionMode,
    Set<String>? selectedCardIds,
    double? totalCollectionValue,
    double? totalWishlistValue,
    double? evolutionValue,
    double? evolutionPercent,
    bool? hasCalculatedFinance,
    bool clearEvolution = false,
  }) {
    return CollectionState(
      collection: collection ?? this.collection,
      wishlists: wishlists ?? this.wishlists,
      fullCardData: fullCardData ?? this.fullCardData,
      availableTags: availableTags ?? this.availableTags,
      isLoading: isLoading ?? this.isLoading,
      activeFilters: activeFilters ?? this.activeFilters,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedCardIds: selectedCardIds ?? this.selectedCardIds,
      totalCollectionValue: totalCollectionValue ?? this.totalCollectionValue,
      totalWishlistValue: totalWishlistValue ?? this.totalWishlistValue,
      evolutionValue: clearEvolution ? null : (evolutionValue ?? this.evolutionValue),
      evolutionPercent: clearEvolution ? null : (evolutionPercent ?? this.evolutionPercent),
      hasCalculatedFinance: hasCalculatedFinance ?? this.hasCalculatedFinance,
    );
  }

  // --- Computed properties ---

  int get activeFilterCount {
    int count = 0;
    if (activeFilters.colors.isNotEmpty) count++;
    if (activeFilters.cardType != null) count++;
    if (activeFilters.tags.isNotEmpty) count++;
    if (activeFilters.keyword != null) count++;
    return count;
  }
}

// --- CONTROLLER (StateNotifier) ---

class CollectionController extends StateNotifier<CollectionState> {
  final CollectionService _collectionService;
  final WishlistService _wishlistService;
  final LocalCardService _localCardService;
  final DeckService _deckService;
  final ScryfallApiService _apiService;

  CollectionController({
    required CollectionService collectionService,
    required WishlistService wishlistService,
    required LocalCardService localCardService,
    required DeckService deckService,
    required ScryfallApiService apiService,
  })  : _collectionService = collectionService,
        _wishlistService = wishlistService,
        _localCardService = localCardService,
        _deckService = deckService,
        _apiService = apiService,
        super(const CollectionState()) {
    _localCardService.loadLocalData();
    loadData();
  }

  // --- CHARGEMENT ---

  Future<void> loadData({bool forceLoading = true}) async {
    if (!mounted) return;
    if (forceLoading) {
      state = state.copyWith(isLoading: true);
    }

    late List<DeckCard> collection;
    late List<Wishlist> wishlists;
    late List<String> availableTags;

    await Future.wait([
      _collectionService.loadCollection().then((data) => collection = data),
      _wishlistService.loadWishlists().then((data) => wishlists = data),
      _collectionService.getAllUniqueTags().then((data) => availableTags = data),
    ]);

    if (!mounted) return;

    if (!_localCardService.isLoaded) await _localCardService.loadLocalData();
    if (!mounted) return;

    final fullCardData = await _loadFullCardData(collection, wishlists);
    if (!mounted) return;

    final financials = await _calculateFinancials(collection, wishlists, fullCardData);
    if (!mounted) return;

    state = state.copyWith(
      collection: collection,
      wishlists: wishlists,
      availableTags: availableTags,
      fullCardData: fullCardData,
      totalCollectionValue: financials.totalCollectionValue,
      totalWishlistValue: financials.totalWishlistValue,
      evolutionValue: financials.evolutionValue,
      evolutionPercent: financials.evolutionPercent,
      hasCalculatedFinance: true,
      isLoading: false,
    );
  }

  Future<List<ScryfallCard>> _loadFullCardData(List<DeckCard> collection, List<Wishlist> wishlists) async {
    final List<DeckCard> allWishlistCards = wishlists.expand((w) => w.cards).toList();
    final allCards = [...collection, ...allWishlistCards];
    final uniqueIds = allCards
        .where((card) => card.scryfallId.isNotEmpty && !card.scryfallId.startsWith('LOCAL:'))
        .map((card) => card.scryfallId).toSet().toList();

    if (uniqueIds.isEmpty) return [];

    List<ScryfallCard> loadedCards = [];
    List<String> missingIds = [];

    if (_localCardService.isLoaded) {
      for (String id in uniqueIds) {
        final localCard = _localCardService.getCardById(id);
        if (localCard != null) {
          loadedCards.add(localCard);
        } else {
          missingIds.add(id);
        }
      }
    } else {
      missingIds = uniqueIds;
    }

    if (missingIds.isNotEmpty) {
      const int chunkSize = 75;
      for (var i = 0; i < missingIds.length; i += chunkSize) {
        final end = (i + chunkSize < missingIds.length) ? i + chunkSize : missingIds.length;
        final batch = missingIds.sublist(i, end);
        try {
          final data = await _apiService.fetchCollection(
            batch.map((id) => {'id': id}).toList(),
          );
          loadedCards.addAll((data['data'] as List).map((j) => ScryfallCard.fromJson(j)));
        } catch (e) { log('Erreur API: $e'); }
      }
    }
    return loadedCards;
  }

  Future<_FinancialResult> _calculateFinancials(
    List<DeckCard> collection,
    List<Wishlist> wishlists,
    List<ScryfallCard> fullCardData,
  ) async {
    double getPrice(String id, bool isFoil) {
      final c = fullCardData.where((s) => s.id == id).firstOrNull;
      if (c == null) return 0.0;
      return PriceHelper.bestPrice(c.prices, isFoil: isFoil);
    }

    final totalCollectionValue = collection.fold(0.0, (sum, c) => sum + (getPrice(c.scryfallId, c.isFoil) * c.quantity));
    double totalWishlistValue = 0.0;
    for (var list in wishlists) {
      for (var c in list.cards) {
        totalWishlistValue += (getPrice(c.scryfallId, c.isFoil) * c.quantity);
      }
    }

    await _collectionService.recordDailyValue(totalCollectionValue);
    final evo = await _collectionService.getEvolutionSince(7);

    return _FinancialResult(
      totalCollectionValue: totalCollectionValue,
      totalWishlistValue: totalWishlistValue,
      evolutionValue: evo?['diffValue'],
      evolutionPercent: evo?['diffPercentage'],
    );
  }

  // --- FILTRES ---

  void updateFilters(SearchFilters filters) {
    state = state.copyWith(activeFilters: filters);
  }

  // --- SELECTION ---

  void toggleSelectionMode() {
    state = state.copyWith(
      isSelectionMode: !state.isSelectionMode,
      selectedCardIds: {},
    );
  }

  void toggleCardSelection(String scryfallId) {
    final updated = Set<String>.from(state.selectedCardIds);
    if (updated.contains(scryfallId)) {
      updated.remove(scryfallId);
    } else {
      updated.add(scryfallId);
    }
    state = state.copyWith(selectedCardIds: updated);
  }

  // --- COLLECTION CARD OPERATIONS ---

  Future<void> updateQuantity(DeckCard card, int quantityToAdd) async {
    await _collectionService.upsertCardInCollection(
      scryfallId: card.scryfallId,
      cardName: card.name,
      quantityToAdd: quantityToAdd,
      isFoil: card.isFoil,
    );
    if (!mounted) return;
    await loadData(forceLoading: false);
  }

  Future<void> toggleFoil(DeckCard card) async {
    await _collectionService.upsertCardInCollection(
      scryfallId: card.scryfallId,
      cardName: card.name,
      quantityToAdd: -1,
      isFoil: card.isFoil,
    );
    if (!mounted) return;
    await _collectionService.upsertCardInCollection(
      scryfallId: card.scryfallId,
      cardName: card.name,
      quantityToAdd: 1,
      isFoil: !card.isFoil,
      newTags: card.tags,
    );
    if (!mounted) return;
    await loadData(forceLoading: false);
  }

  Future<void> updateTags(DeckCard card, List<String> newTags) async {
    await _collectionService.upsertCardInCollection(
      scryfallId: card.scryfallId,
      cardName: card.name,
      isFoil: card.isFoil,
      newTags: newTags,
    );
    if (!mounted) return;
    await loadData(forceLoading: false);
  }

  Future<void> clearCollection() async {
    await _collectionService.clearCollection();
    if (!mounted) return;
    await loadData();
  }

  // --- DECK OPERATIONS (called from selection mode) ---

  Future<List<Deck>> getDecks() async {
    return _deckService.loadDecks();
  }

  Future<String> createNewDeckAndGetId(String name) async {
    await _deckService.createNewDeck(name);
    final decks = await _deckService.loadDecks();
    return decks.last.id;
  }

  Future<CollectionActionResult> addSelectedCardsToDeck(String deckId, String deckName) async {
    if (!mounted) return const CollectionActionResult(success: false, message: 'Controller disposed');
    state = state.copyWith(isLoading: true);
    int count = 0;
    for (String id in state.selectedCardIds) {
      final collectionCard = state.collection.where((c) => c.scryfallId == id).firstOrNull;
      if (collectionCard == null) continue;
      try {
        await _deckService.upsertCardInDeck(
          deckId: deckId,
          scryfallId: id,
          cardName: collectionCard.name,
          quantityToAdd: 1,
        );
        count++;
      } catch (e) { log('Erreur ajout carte $id : $e', name: 'CollectionController'); }
      if (!mounted) return CollectionActionResult(message: '$count cartes ajoutees (interrompu)');
    }

    if (!mounted) return CollectionActionResult(message: '$count cartes ajoutees a $deckName');
    state = state.copyWith(
      isLoading: false,
      isSelectionMode: false,
      selectedCardIds: {},
    );

    return CollectionActionResult(
      message: '$count cartes ajoutées à $deckName',
    );
  }

  // --- TAB CHANGE ---

  void onTabChanged(int index) {
    if (!mounted) return;
    if (index == 1 || index == 2) {
      loadData(forceLoading: false);
    }
    if (state.isSelectionMode) {
      toggleSelectionMode();
    }
  }
}

// --- PRIVATE HELPER ---

class _FinancialResult {
  final double totalCollectionValue;
  final double totalWishlistValue;
  final double? evolutionValue;
  final double? evolutionPercent;

  _FinancialResult({
    required this.totalCollectionValue,
    required this.totalWishlistValue,
    this.evolutionValue,
    this.evolutionPercent,
  });
}

// --- PROVIDER ---

final collectionControllerProvider = StateNotifierProvider.autoDispose<CollectionController, CollectionState>(
  (ref) {
    final collectionService = ref.watch(collectionServiceProvider);
    final wishlistService = ref.watch(wishlistServiceProvider);
    final localCardService = ref.watch(localCardServiceProvider);
    final deckService = ref.watch(deckServiceProvider);
    final apiService = ref.watch(scryfallApiServiceProvider);

    return CollectionController(
      collectionService: collectionService,
      wishlistService: wishlistService,
      localCardService: localCardService,
      deckService: deckService,
      apiService: apiService,
    );
  },
);
