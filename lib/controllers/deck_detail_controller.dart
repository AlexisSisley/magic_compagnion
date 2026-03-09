// Fichier : lib/controllers/deck_detail_controller.dart
// Controller pour DeckDetailPage - extrait la logique metier de la page.

import 'dart:developer';

import 'package:flutter_riverpod/legacy.dart';

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../providers/service_providers.dart';
import '../utils/price_helper.dart';
import '../models/legality_report.dart';
import '../services/collection_service.dart';
import '../services/deck_format_service.dart';
import '../services/deck_service.dart';
import '../services/legality_service.dart';
import '../services/scryfall_api_service.dart';
import '../services/wishlist_service.dart';

// --- RESULT OBJECT pour les actions ---

class DeckDetailActionResult {
  final bool success;
  final String message;

  const DeckDetailActionResult({
    this.success = true,
    this.message = '',
  });
}

// --- ETAT IMMUTABLE ---

/// Info d'un token requis par le deck.
class TokenInfo {
  final String id;
  final String name;
  final String typeLine;
  final String? imageUrl;

  const TokenInfo({
    required this.id,
    required this.name,
    required this.typeLine,
    this.imageUrl,
  });
}

class DeckDetailState {
  final Deck currentDeck;
  final List<ScryfallCard> fullCardData;
  final List<DeckCard> myCollection;
  final double totalDeckPrice;
  final bool isLoading;
  final bool isValidating;
  final String? errorMessage;
  final List<TokenInfo> tokens;

  DeckDetailState({
    required this.currentDeck,
    this.fullCardData = const [],
    this.myCollection = const [],
    this.totalDeckPrice = 0.0,
    this.isLoading = true,
    this.isValidating = false,
    this.errorMessage,
    this.tokens = const [],
  });

  DeckDetailState copyWith({
    Deck? currentDeck,
    List<ScryfallCard>? fullCardData,
    List<DeckCard>? myCollection,
    double? totalDeckPrice,
    bool? isLoading,
    bool? isValidating,
    String? errorMessage,
    List<TokenInfo>? tokens,
  }) {
    return DeckDetailState(
      currentDeck: currentDeck ?? this.currentDeck,
      fullCardData: fullCardData ?? this.fullCardData,
      myCollection: myCollection ?? this.myCollection,
      totalDeckPrice: totalDeckPrice ?? this.totalDeckPrice,
      isLoading: isLoading ?? this.isLoading,
      isValidating: isValidating ?? this.isValidating,
      errorMessage: errorMessage,
      tokens: tokens ?? this.tokens,
    );
  }

  // --- Computed properties ---

  int get mainCount => currentDeck.mainboard.fold(0, (s, c) => s + c.quantity);
  int get sideCount => currentDeck.sideboard.fold(0, (s, c) => s + c.quantity);
  int get consCount => currentDeck.considering.fold(0, (s, c) => s + c.quantity);
  int get wishCount => currentDeck.wishlist.fold(0, (s, c) => s + c.quantity);
}

// --- CONTROLLER (StateNotifier) ---

class DeckDetailController extends StateNotifier<DeckDetailState> {
  final DeckService _deckService;
  final CollectionService _collectionService;
  final WishlistService _wishlistService;
  final ScryfallApiService _apiService;

  DeckDetailController({
    required Deck initialDeck,
    required DeckService deckService,
    required CollectionService collectionService,
    required WishlistService wishlistService,
    required ScryfallApiService apiService,
  })  : _deckService = deckService,
        _collectionService = collectionService,
        _wishlistService = wishlistService,
        _apiService = apiService,
        super(DeckDetailState(currentDeck: initialDeck)) {
    loadInitialData();
  }

  // --- CHARGEMENT ---

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      _loadFullCardData(),
      _loadCollection(),
    ]);
    _calculateDeckValue();
    await _computeTokens();
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadCollection() async {
    final col = await _collectionService.loadCollection();
    state = state.copyWith(myCollection: col);
  }

  Future<void> _loadFullCardData() async {
    final deck = state.currentDeck;
    final allCards = [...deck.mainboard, ...deck.sideboard, ...deck.considering, ...deck.wishlist];

    final uniqueIds = allCards
        .map((c) => c.scryfallId)
        .where((id) => id.isNotEmpty && !id.startsWith('LOCAL:'))
        .toSet()
        .toList();

    if (deck.commanderScryfallId != null) uniqueIds.add(deck.commanderScryfallId!);
    if (deck.commanderSecondaryScryfallId != null) uniqueIds.add(deck.commanderSecondaryScryfallId!);

    if (uniqueIds.isEmpty) {
      state = state.copyWith(fullCardData: []);
      return;
    }

    List<ScryfallCard> loadedCards = [];
    const int chunkSize = 75;
    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final end = (i + chunkSize < uniqueIds.length) ? i + chunkSize : uniqueIds.length;
      final batchIds = uniqueIds.sublist(i, end);

      try {
        final data = await _apiService.fetchCollection(
          batchIds.map((id) => {'id': id}).toList(),
        );
        final List<ScryfallCard> batchCards = (data['data'] as List)
            .map((cardJson) => ScryfallCard.fromJson(cardJson))
            .toList();
        loadedCards.addAll(batchCards);
      } catch (e) {
        log('Exception Scryfall: $e');
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Compute colors from mainboard + commander cards
    final Set<String> computedColors = {};
    for (var card in loadedCards) {
      if (deck.mainboard.any((c) => c.scryfallId == card.id) ||
          card.id == deck.commanderScryfallId ||
          card.id == deck.commanderSecondaryScryfallId) {
        computedColors.addAll(card.colorIdentity);
      }
    }
    final order = {'W': 0, 'U': 1, 'B': 2, 'R': 3, 'G': 4, 'C': 5};
    final sortedColors = computedColors.toList()
      ..sort((a, b) => (order[a] ?? 9).compareTo(order[b] ?? 9));

    if (deck.colors.join() != sortedColors.join()) {
      deck.colors = sortedColors;
      _deckService.updateDeck(deck);
    }

    state = state.copyWith(fullCardData: loadedCards);
  }

  void _calculateDeckValue() {
    double total = 0.0;
    final deck = state.currentDeck;
    final activeCards = [...deck.mainboard, ...deck.sideboard];

    for (var deckCard in activeCards) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      final scryfallCard = state.fullCardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
      if (scryfallCard == null) continue;

      final double unitPrice = PriceHelper.bestPrice(scryfallCard.prices, isFoil: deckCard.isFoil);

      final int realQuantity = (deckCard.quantity - deckCard.proxyQuantity).clamp(0, deckCard.quantity);
      total += (realQuantity * unitPrice);
    }

    state = state.copyWith(totalDeckPrice: total);
  }

  /// Extrait les tokens uniques requis par le deck depuis allParts.
  Future<void> _computeTokens() async {
    final Map<String, RelatedCard> tokenMap = {};
    for (final card in state.fullCardData) {
      for (final part in card.allParts) {
        if (part.isToken && !tokenMap.containsKey(part.id)) {
          tokenMap[part.id] = part;
        }
      }
    }

    if (tokenMap.isEmpty) {
      state = state.copyWith(tokens: []);
      return;
    }

    // Charger les images des tokens via l'API /cards/collection
    List<TokenInfo> tokens = [];
    final tokenIds = tokenMap.values.toList();
    try {
      final data = await _apiService.fetchCollection(
        tokenIds.map((t) => {'id': t.id}).toList(),
      );
      final List<dynamic> rawList = data['data'] ?? [];
      for (final json in rawList) {
        final card = ScryfallCard.fromJson(json as Map<String, dynamic>);
        tokens.add(TokenInfo(
          id: card.id,
          name: card.name,
          typeLine: card.typeLine,
          imageUrl: card.imageUrl.isNotEmpty ? card.imageUrl : card.smallImageUrl,
        ));
      }
    } catch (e) {
      // Fallback sans images
      tokens = tokenIds.map((t) => TokenInfo(
        id: t.id,
        name: t.name,
        typeLine: t.typeLine,
      )).toList();
    }

    if (!mounted) return;
    state = state.copyWith(tokens: tokens);
  }

  // --- CARD CRUD ---

  /// Returns a DeckDetailActionResult. If not successful, the UI should show
  /// the message (e.g., Commander singleton rule violation).
  Future<DeckDetailActionResult> updateQuantity(DeckCard card, int change, DeckBoard board) async {
    final deck = state.currentDeck;

    if (change > 0 && board == DeckBoard.main && deck.format.toLowerCase() == 'commander') {
      bool isBasicLand = false;
      final scryfall = state.fullCardData.where((s) => s.id == card.scryfallId).firstOrNull;
      if (scryfall != null) {
        if (scryfall.typeLine.toLowerCase().contains('basic land')) isBasicLand = true;
        if (scryfall.rulesText.toLowerCase().contains('a deck can have any number')) isBasicLand = true;
      }

      if (!isBasicLand && card.quantity >= 1) {
        return const DeckDetailActionResult(
          success: false,
          message: 'Commander : 1 seul exemplaire autorise (sauf terrains de base).',
        );
      }
    }

    final updatedDeck = await _deckService.upsertCardInDeck(
      deckId: deck.id,
      scryfallId: card.scryfallId,
      cardName: card.name,
      quantityToAdd: change,
      board: board,
    );
    state = state.copyWith(currentDeck: updatedDeck);
    _calculateDeckValue();
    return const DeckDetailActionResult();
  }

  Future<void> toggleFoil(DeckCard card, DeckBoard board) async {
    final updatedDeck = await _deckService.upsertCardInDeck(
      deckId: state.currentDeck.id,
      scryfallId: card.scryfallId,
      cardName: card.name,
      board: board,
      isFoil: !card.isFoil,
    );
    state = state.copyWith(currentDeck: updatedDeck);
    _calculateDeckValue();
  }

  Future<void> switchVersion(DeckCard card, ScryfallCard newVersion, DeckBoard board) async {
    final updatedDeck = await _deckService.changeCardVersion(
      deckId: state.currentDeck.id,
      oldCard: card,
      newVersion: newVersion,
      board: board,
    );
    state = state.copyWith(currentDeck: updatedDeck);
    await _loadFullCardData();
    _calculateDeckValue();
  }

  /// Returns a DeckDetailActionResult. If not successful, the UI should show
  /// the message (e.g., Commander singleton rule violation).
  Future<DeckDetailActionResult> moveCard(DeckCard card, DeckBoard targetBoard, DeckBoard sourceBoard) async {
    if (targetBoard == sourceBoard) return const DeckDetailActionResult();

    final deck = state.currentDeck;

    if (targetBoard == DeckBoard.main && deck.format.toLowerCase() == 'commander') {
      bool exists = deck.mainboard.any((c) => c.scryfallId == card.scryfallId);
      if (exists) {
        bool isBasic = false;
        final sc = state.fullCardData.where((s) => s.id == card.scryfallId).firstOrNull;
        if (sc != null && sc.typeLine.toLowerCase().contains('basic land')) isBasic = true;

        if (!isBasic) {
          return const DeckDetailActionResult(
            success: false,
            message: 'Deja present dans le deck (Regle Singleton).',
          );
        }
      }
    }

    final updatedDeck = await _deckService.moveCard(
      deckId: deck.id,
      card: card,
      fromBoard: sourceBoard,
      toBoard: targetBoard,
    );
    state = state.copyWith(currentDeck: updatedDeck);
    _calculateDeckValue();
    return DeckDetailActionResult(
      message: 'Carte deplacee vers ${targetBoard.name.toUpperCase()} !',
    );
  }

  Future<void> updateTags(DeckCard card, List<String> tags, DeckBoard board) async {
    final updatedDeck = await _deckService.upsertCardInDeck(
      deckId: state.currentDeck.id,
      scryfallId: card.scryfallId,
      cardName: card.name,
      board: board,
      newTags: tags,
    );
    state = state.copyWith(currentDeck: updatedDeck);
  }

  // --- COLLECTION / WISHLIST MULTI-ADD ---

  /// Ajoute une carte du deck dans la collection globale.
  Future<DeckDetailActionResult> addToCollection(DeckCard card, int quantity) async {
    await _collectionService.upsertCardInCollection(
      scryfallId: card.scryfallId,
      cardName: card.name,
      quantityToAdd: quantity,
      isFoil: card.isFoil,
    );
    return DeckDetailActionResult(
      message: '${card.name} x$quantity ajoutee a la collection.',
    );
  }

  /// Ajoute une carte du deck dans une wishlist globale.
  Future<DeckDetailActionResult> addToWishlist(DeckCard card, int quantity, String? wishlistId) async {
    await _wishlistService.upsertCard(
      wishlistId: wishlistId,
      scryfallId: card.scryfallId,
      cardName: card.name,
      quantityToAdd: quantity,
      isFoil: card.isFoil,
    );
    return DeckDetailActionResult(
      message: '${card.name} x$quantity ajoutee a la wishlist.',
    );
  }

  // --- COMMANDER LOGIC ---

  /// Returns a DeckDetailActionResult indicating what happened.
  /// The `slot` field should be requested from the UI when needed (returned as message "NEED_SLOT").
  Future<DeckDetailActionResult> unsetCommander(DeckCard deckCard) async {
    final deck = state.currentDeck;

    if (deckCard.scryfallId == deck.commanderScryfallId) {
      await _deckService.unsetCommander(deck.id, slot: 1);
      final d = (await _deckService.loadDecks()).where((d) => d.id == deck.id).first;
      state = state.copyWith(currentDeck: d);
      return const DeckDetailActionResult(message: 'Retire du slot Commandant.');
    }
    if (deckCard.scryfallId == deck.commanderSecondaryScryfallId) {
      await _deckService.unsetCommander(deck.id, slot: 2);
      final d = (await _deckService.loadDecks()).where((d) => d.id == deck.id).first;
      state = state.copyWith(currentDeck: d);
      return const DeckDetailActionResult(message: 'Retire du slot Partenaire.');
    }

    return const DeckDetailActionResult(success: false, message: '');
  }

  /// Validates whether a card can be set as commander.
  /// Returns null if valid, or an error message if not.
  String? validateCommanderEligibility(DeckCard deckCard) {
    if (deckCard.scryfallId.startsWith('LOCAL:')) {
      return 'Carte locale : Impossible de definir comme Cdt.';
    }

    final scryfallCard = state.fullCardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
    if (scryfallCard == null) return 'Erreur: Donnees carte introuvables.';

    if (!scryfallCard.typeLine.toLowerCase().contains('legendary') &&
        !scryfallCard.rulesText.toLowerCase().contains('can be your commander')) {
      return 'Le commandant doit etre une creature legendaire.';
    }

    return null;
  }

  /// Check if the card is currently a commander (slot 1 or 2).
  bool isCommander(DeckCard deckCard) {
    return deckCard.scryfallId == state.currentDeck.commanderScryfallId ||
        deckCard.scryfallId == state.currentDeck.commanderSecondaryScryfallId;
  }

  /// Sets a card as commander in the given slot (1 or 2).
  /// The UI is responsible for showing the slot picker dialog.
  Future<DeckDetailActionResult> setCommanderSlot(DeckCard deckCard, int slot) async {
    final scryfallCard = state.fullCardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
    if (scryfallCard == null) {
      return const DeckDetailActionResult(success: false, message: 'Erreur: Donnees carte introuvables.');
    }

    await _deckService.setCommander(state.currentDeck.id, scryfallCard.id, slot: slot);
    final reloadedDeck = (await _deckService.loadDecks()).where((d) => d.id == state.currentDeck.id).first;

    state = state.copyWith(currentDeck: reloadedDeck);
    await _loadFullCardData();
    return DeckDetailActionResult(
      message: '"${scryfallCard.name}" defini en slot $slot.',
    );
  }

  // --- EXPORT MULTI-FORMAT (TXT, CSV) & LEGALITY REPORT ---

  String exportAsTxt() => DeckFormatService.exportToTxt(state.currentDeck);
  String exportAsCsv() => DeckFormatService.exportToCsv(state.currentDeck);
  LegalityReport generateLegalityReport() => LegalityService.generateReport(
    deck: state.currentDeck,
    fullCardData: state.fullCardData,
  );

  // --- SHARE / EXPORT LOGIC (text generation, no BuildContext) ---

  String generateFullDeckText() {
    final deck = state.currentDeck;
    StringBuffer sb = StringBuffer();
    sb.writeln('Deck: ${deck.name}');
    sb.writeln('Format: ${deck.format}');
    sb.writeln('');

    if (deck.commanderScryfallId != null) {
      final cmd = _findCardOrUnknown(deck.commanderScryfallId!);
      sb.writeln('COMMANDER:');
      sb.writeln('1 ${cmd.name}');
    }
    if (deck.commanderSecondaryScryfallId != null) {
      final partner = _findCardOrUnknown(deck.commanderSecondaryScryfallId!);
      sb.writeln('1 ${partner.name}');
    }
    if (deck.commanderScryfallId != null) sb.writeln('');

    sb.writeln('MAINBOARD:');
    for (var c in deck.mainboard) {
      if (c.scryfallId != deck.commanderScryfallId && c.scryfallId != deck.commanderSecondaryScryfallId) {
        sb.writeln('${c.quantity} ${c.name}');
      }
    }
    sb.writeln('');

    if (deck.sideboard.isNotEmpty) {
      sb.writeln('SIDEBOARD:');
      for (var c in deck.sideboard) {
        sb.writeln('${c.quantity} ${c.name}');
      }
    }

    return sb.toString();
  }

  String? generateConsideringText() {
    final deck = state.currentDeck;
    if (deck.considering.isEmpty) return null;

    StringBuffer sb = StringBuffer();
    sb.writeln('Considering for: ${deck.name}');
    sb.writeln('');
    for (var c in deck.considering) {
      sb.writeln('${c.quantity} ${c.name}');
    }
    return sb.toString();
  }

  String? generateWishlistText() {
    final deck = state.currentDeck;
    if (deck.wishlist.isEmpty) return null;

    StringBuffer sb = StringBuffer();
    sb.writeln('Wishlist for: ${deck.name}');
    sb.writeln('');
    for (var c in deck.wishlist) {
      sb.writeln('${c.quantity} ${c.name}');
    }
    return sb.toString();
  }

  // --- EXPORT WISHLIST TO GLOBAL ---

  /// Exports the deck wishlist cards into a new global wishlist.
  /// Returns null if the deck wishlist is empty, otherwise returns a result.
  Future<DeckDetailActionResult?> exportDeckWishlistToGlobal(String wishlistName) async {
    final deck = state.currentDeck;
    if (deck.wishlist.isEmpty) return null;

    await _wishlistService.createWishlist(wishlistName);
    final lists = await _wishlistService.loadWishlists();
    final newList = lists.lastWhere((l) => l.name == wishlistName);

    for (var card in deck.wishlist) {
      await _wishlistService.upsertCard(
        wishlistId: newList.id,
        scryfallId: card.scryfallId,
        cardName: card.name,
        quantityToAdd: card.quantity,
        isFoil: card.isFoil,
      );
    }

    return DeckDetailActionResult(message: "Wishlist '$wishlistName' creee avec succes !");
  }

  // --- VALIDATION ---

  Map<String, String> validateDeckRules() {
    Map<String, String> results = {};
    const List<String> formats = ['standard', 'pioneer', 'modern', 'commander'];

    int totalDeckSize = state.currentDeck.mainboard.fold(0, (sum, c) => sum + c.quantity);

    for (final format in formats) {
      if (format == 'commander') {
        if (totalDeckSize != 100) {
          results[format] = 'X $totalDeckSize cartes (100 requises)';
          continue;
        }
        if (state.currentDeck.commanderScryfallId == null) {
          results[format] = 'X Cdt manquant';
          continue;
        }
      }
      results[format] = 'OK Legal';
    }
    results['Bordeciel (Whiterun)'] = 'Interdit (Arrow in the knee)';
    return results;
  }

  // --- CARD PICKER (add cards from picker) ---

  Future<void> addCardsFromPicker(List<Map<String, dynamic>> pickedCards) async {
    state = state.copyWith(isLoading: true);
    for (var item in pickedCards) {
      final ScryfallCard card = item['card'];
      final int quantity = item['quantity'];
      await _deckService.upsertCardInDeck(
        deckId: state.currentDeck.id,
        scryfallId: card.id,
        cardName: card.name,
        quantityToAdd: quantity,
        board: DeckBoard.main,
      );
    }
    final updated = (await _deckService.loadDecks()).where((d) => d.id == state.currentDeck.id).first;
    state = state.copyWith(currentDeck: updated);
    await loadInitialData();
  }

  // --- CLEAR DECK ---

  Future<DeckDetailActionResult> clearDeck() async {
    bool hadCards = state.currentDeck.mainboard.isNotEmpty;
    await _deckService.clearDeck(state.currentDeck.id);
    final d = (await _deckService.loadDecks()).where((d) => d.id == state.currentDeck.id).first;
    state = state.copyWith(
      currentDeck: d,
      fullCardData: [],
      totalDeckPrice: 0.0,
    );
    if (hadCards) {
      return const DeckDetailActionResult(
        message: "L'Ordre 66 a ete execute. (Deck vide)",
      );
    }
    return const DeckDetailActionResult();
  }

  // --- PRIVATE HELPERS ---

  ScryfallCard _findCardOrUnknown(String scryfallId) {
    return state.fullCardData.where((c) => c.id == scryfallId).firstOrNull ??
        ScryfallCard(
          id: '',
          oracleId: '',
          name: 'Inconnu',
          imageUrl: '',
          rulesText: '',
          typeLine: '',
          legalities: {},
          prices: {},
          lang: '',
          colorIdentity: [],
          setName: '',
          setCode: '',
          collectorNumber: '',
          rarity: '',
          purchaseUris: {},
        );
  }
}

// --- PROVIDER (family, parametre par Deck) ---

final deckDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<DeckDetailController, DeckDetailState, Deck>(
  (ref, initialDeck) {
    final deckService = ref.watch(deckServiceProvider);
    final collectionService = ref.watch(collectionServiceProvider);
    final wishlistService = ref.watch(wishlistServiceProvider);
    final apiService = ref.watch(scryfallApiServiceProvider);

    return DeckDetailController(
      initialDeck: initialDeck,
      deckService: deckService,
      collectionService: collectionService,
      wishlistService: wishlistService,
      apiService: apiService,
    );
  },
);
