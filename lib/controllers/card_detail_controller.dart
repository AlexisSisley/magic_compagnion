// Fichier : lib/controllers/card_detail_controller.dart
// Controller pour RecognitionResultPage - extrait la logique metier de la page.

import 'dart:convert';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/glossary_data.dart';
import '../models/scan_history_model.dart';
import '../models/scryfall_card_model.dart';
import '../models/scryfall_ruling.dart';
import '../providers/service_providers.dart';
import '../services/collection_service.dart';
import '../services/deck_service.dart';
import '../services/local_card_service.dart';
import '../services/scan_history_service.dart';
import '../services/scryfall_api_service.dart';
import '../services/wishlist_service.dart';

// --- ENUM (reutilise depuis la page) ---

enum ResultPageState { loading, selection, success, error }

// --- ETAT IMMUTABLE ---

class CardDetailState {
  final ResultPageState pageState;
  final String statusMessage;
  final List<ScryfallCard> candidates;
  final ScryfallCard? foundCard;
  final String userLang;
  final List<Keyword> activeGlossary;
  final List<ScryfallRuling> rulings;
  final bool isLoadingRulings;
  final int collectionNormalCount;
  final int collectionFoilCount;
  final bool inWishlist;
  final String currentDisplayLang;

  CardDetailState({
    this.pageState = ResultPageState.loading,
    this.statusMessage = 'Démarrage...',
    this.candidates = const [],
    this.foundCard,
    this.userLang = 'fr',
    this.activeGlossary = const [],
    this.rulings = const [],
    this.isLoadingRulings = false,
    this.collectionNormalCount = 0,
    this.collectionFoilCount = 0,
    this.inWishlist = false,
    this.currentDisplayLang = 'fr',
  });

  CardDetailState copyWith({
    ResultPageState? pageState,
    String? statusMessage,
    List<ScryfallCard>? candidates,
    ScryfallCard? foundCard,
    bool clearFoundCard = false,
    String? userLang,
    List<Keyword>? activeGlossary,
    List<ScryfallRuling>? rulings,
    bool? isLoadingRulings,
    int? collectionNormalCount,
    int? collectionFoilCount,
    bool? inWishlist,
    String? currentDisplayLang,
  }) {
    return CardDetailState(
      pageState: pageState ?? this.pageState,
      statusMessage: statusMessage ?? this.statusMessage,
      candidates: candidates ?? this.candidates,
      foundCard: clearFoundCard ? null : (foundCard ?? this.foundCard),
      userLang: userLang ?? this.userLang,
      activeGlossary: activeGlossary ?? this.activeGlossary,
      rulings: rulings ?? this.rulings,
      isLoadingRulings: isLoadingRulings ?? this.isLoadingRulings,
      collectionNormalCount: collectionNormalCount ?? this.collectionNormalCount,
      collectionFoilCount: collectionFoilCount ?? this.collectionFoilCount,
      inWishlist: inWishlist ?? this.inWishlist,
      currentDisplayLang: currentDisplayLang ?? this.currentDisplayLang,
    );
  }
}

// --- PARAMETRES D'INITIALISATION ---

class CardDetailParams {
  final String? imagePath;
  final String? cardName;
  final bool isContinuousScan;

  const CardDetailParams({
    this.imagePath,
    this.cardName,
    this.isContinuousScan = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardDetailParams &&
          runtimeType == other.runtimeType &&
          imagePath == other.imagePath &&
          cardName == other.cardName &&
          isContinuousScan == other.isContinuousScan;

  @override
  int get hashCode =>
      imagePath.hashCode ^ cardName.hashCode ^ isContinuousScan.hashCode;
}

// --- CONTROLLER (StateNotifier) ---

class CardDetailController extends StateNotifier<CardDetailState> {
  final DeckService _deckService;
  final CollectionService _collectionService;
  final ScanHistoryService _historyService;
  final WishlistService _wishlistService;
  final LocalCardService _localCardService;
  final ScryfallApiService _apiService;
  final CardDetailParams _params;

  CardDetailController({
    required DeckService deckService,
    required CollectionService collectionService,
    required ScanHistoryService historyService,
    required WishlistService wishlistService,
    required LocalCardService localCardService,
    required ScryfallApiService apiService,
    required CardDetailParams params,
  })  : _deckService = deckService,
        _collectionService = collectionService,
        _historyService = historyService,
        _wishlistService = wishlistService,
        _localCardService = localCardService,
        _apiService = apiService,
        _params = params,
        super(CardDetailState()) {
    _initializeAndSearch();
  }

  // Expose services en lecture seule pour la UI (modales, deck picker)
  DeckService get deckService => _deckService;
  WishlistService get wishlistService => _wishlistService;
  CardDetailParams get params => _params;

  // --- INITIALISATION ---

  Future<void> _initializeAndSearch() async {
    await _localCardService.loadLocalData();
    try {
      final prefs = await SharedPreferences.getInstance();
      final displayLang = prefs.getString('glossaryLang') ?? 'fr';
      final String assetPath =
          (state.userLang == 'fr') ? 'assets/glossary_fr.json' : 'assets/glossary_en.json';
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List;
      final glossary = jsonList
          .map((jsonItem) => Keyword.fromJson(jsonItem as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      state = state.copyWith(
        activeGlossary: glossary,
        currentDisplayLang: displayLang,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(activeGlossary: []);
    }

    if (_params.imagePath != null) {
      await _startAutomaticProcess();
    } else if (_params.cardName != null) {
      await searchForCandidates(_params.cardName!);
    }
  }

  // --- OCR ---

  String _cleanOcrText(String text) {
    String cleanedText = text;
    cleanedText = cleanedText.replaceAll(RegExp(r'[\[\].,:;]'), ' ');
    cleanedText = cleanedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleanedText;
  }

  Future<void> _startAutomaticProcess() async {
    state = state.copyWith(
      pageState: ResultPageState.loading,
      statusMessage: 'Lecture de la carte...',
    );
    if (_params.imagePath == null) return;

    final inputImage = InputImage.fromFilePath(_params.imagePath!);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      final RegExp collectorRegex =
          RegExp(r'\b([A-Z0-9]{3,5})[\s•\/\-]{1,3}([0-9]{1,4}[a-z]?)\b', caseSensitive: false);

      for (var block in recognizedText.blocks) {
        String blockText = block.text.replaceAll('\n', ' ');
        final match = collectorRegex.firstMatch(blockText);
        if (match != null) {
          final String setCode = match.group(1)!;
          final String collectorNumber = match.group(2)!;
          if (!mounted) return;
          state = state.copyWith(
            statusMessage: 'Code détecté : $setCode #$collectorNumber',
          );
          bool success = await _fetchExactCard(setCode, collectorNumber);
          if (success) return;
        }
      }

      List<TextBlock> sortedBlocks = List.from(recognizedText.blocks);
      sortedBlocks
          .sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      String? bestGuess;
      const List<String> badKeywords = [
        // EN
        'creature', 'artifact', 'enchantment', 'instant', 'sorcery',
        'land', 'token', 'legendary', 'planeswalker',
        // FR
        'créature', 'artefact', 'enchantement', 'éphémère', 'rituel',
        'terrain', 'jeton', 'légendaire',
        // DE
        'kreatur', 'artefakt', 'verzauberung', 'spontanzauber', 'hexerei',
        'spielstein', 'legendär',
        // ES
        'criatura', 'artefacto', 'encantamiento', 'instantáneo', 'conjuro',
        'tierra', 'ficha', 'legendario', 'legendaria',
        // IT
        'creatura', 'artefatto', 'incantesimo', 'istantaneo', 'stregoneria',
        'terra', 'pedina', 'leggendario', 'leggendaria',
        // PT
        'artefato', 'encantamento', 'mágica instantânea', 'feitiço',
        'terreno', 'lendário', 'lendária',
      ];

      for (int i = 0; i < sortedBlocks.length && i < 5; i++) {
        for (var line in sortedBlocks[i].lines) {
          String text = _cleanOcrText(line.text);
          if (text.length < 3) continue;
          bool isTypeLine =
              badKeywords.any((k) => text.toLowerCase().contains(k));
          if (isTypeLine) continue;
          bestGuess = text;
          break;
        }
        if (bestGuess != null) break;
      }

      if (bestGuess == null || bestGuess.isEmpty) {
        if (!mounted) return;
        state = state.copyWith(
          pageState: ResultPageState.error,
          statusMessage: 'Titre non reconnu.',
        );
        return;
      }

      await searchForCandidates(bestGuess);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        pageState: ResultPageState.error,
        statusMessage: 'Erreur OCR: $e',
      );
    }
  }

  /// Returns the OCR best guess text (for populating search field).
  /// Null when coming from a direct name search.
  String? get initialSearchText => _params.cardName;

  // --- FETCHING ---

  Future<bool> _fetchExactCard(String set, String cn) async {
    state = state.copyWith(
      statusMessage: 'Identification précise ($set #$cn)...',
    );
    try {
      final data = await _apiService.getCardBySetAndNumber(set, cn);
      selectCard(ScryfallCard.fromJson(data));
      return true;
    } catch (e) {
      // Silently fall through
    }
    return false;
  }

  Future<void> searchForCandidates(String query) async {
    if (!mounted) return;
    state = state.copyWith(
      pageState: ResultPageState.loading,
      statusMessage: 'Recherche de correspondances...',
      candidates: [],
    );

    bool foundApi = false;

    final connectivityResult = await (Connectivity().checkConnectivity());
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      try {
        List<ScryfallCard> apiResults = [];

        try {
          final data = await _apiService.searchCards(query, unique: 'cards');
          final List<dynamic> rawList = data['data'] ?? [];
          apiResults = rawList.map((json) => ScryfallCard.fromJson(json)).take(10).toList();
        } catch (_) {
          // 404 = 0 résultats, on essaiera multilangue
        }

        if (apiResults.isEmpty) {
          try {
            final multiData = await _apiService.searchCards(
              query, unique: 'cards', includeMultilingual: true,
            );
            final List<dynamic> multiRawList = multiData['data'] ?? [];
            apiResults = multiRawList.map((json) => ScryfallCard.fromJson(json)).take(10).toList();
          } catch (_) {}
        }

        if (apiResults.isNotEmpty) {
          if (apiResults.length == 1) {
            selectCard(apiResults.first);
            return;
          }
          if (!mounted) return;
          state = state.copyWith(
            candidates: apiResults,
            pageState: ResultPageState.selection,
          );
          foundApi = true;
        }
      } catch (e) {
        log('Erreur API Search: $e', name: 'CardDetailController');
      }
    }

    if (!foundApi && _localCardService.isLoaded) {
      if (!mounted) return;
      state = state.copyWith(statusMessage: 'Recherche locale...');
      var localResults = _localCardService.findSmartMatch(query, limit: 10);
      if (localResults.isEmpty) {
        final searchResult = await _localCardService.searchCards(query: query);
        localResults = searchResult.take(10).toList();
      }

      if (localResults.isNotEmpty) {
        if (localResults.length == 1) {
          selectCard(localResults.first);
          return;
        }
        if (!mounted) return;
        state = state.copyWith(
          candidates: localResults,
          pageState: ResultPageState.selection,
        );
        return;
      }
    }

    if (!mounted) return;
    if (state.candidates.isEmpty) {
      state = state.copyWith(
        statusMessage: 'Aucune carte trouvée pour "$query".',
        pageState: ResultPageState.error,
      );
    }
  }

  void selectCard(ScryfallCard card) {
    if (!mounted) return;
    state = state.copyWith(
      foundCard: card,
      pageState: ResultPageState.success,
    );

    if (_params.imagePath != null) {
      final newItem = ScanHistoryItem(
        scryfallId: card.id,
        cardName: card.name,
        imagePath: _params.imagePath,
        timestamp: DateTime.now(),
      );
      _historyService.addScan(newItem);
    }
    _fetchRulings(card.id);
    checkCardStatus();
  }

  // --- CARD STATUS (collection + wishlist) ---

  Future<void> checkCardStatus() async {
    if (state.foundCard == null) return;
    final collection = await _collectionService.loadCollection();
    final wishlists = await _wishlistService.loadWishlists();

    int normal = 0;
    int foil = 0;

    for (var c in collection) {
      if (c.scryfallId == state.foundCard!.id) {
        if (c.isFoil) {
          foil += c.quantity;
        } else {
          normal += c.quantity;
        }
      }
    }

    if (!mounted) return;
    state = state.copyWith(
      collectionNormalCount: normal,
      collectionFoilCount: foil,
      inWishlist: wishlists
          .any((w) => w.cards.any((c) => c.scryfallId == state.foundCard!.id)),
    );
  }

  // --- RULINGS ---

  Future<void> _fetchRulings(String cardId) async {
    if (!mounted) return;
    state = state.copyWith(isLoadingRulings: true);
    try {
      final Map<String, dynamic> data =
          await _apiService.getCardRulings(cardId);
      final List<dynamic> rulingsList = data['data'] ?? [];
      if (!mounted) return;
      state = state.copyWith(
        rulings: rulingsList
            .map((rulingJson) => ScryfallRuling(
                  date: rulingJson['published_at'],
                  comment: rulingJson['comment'],
                ))
            .toList(),
      );
    } catch (e) {
      // Silently ignore
    }
    if (!mounted) return;
    state = state.copyWith(isLoadingRulings: false);
  }

  // --- COLLECTION OPERATIONS ---

  Future<void> saveCollection({
    required int normalCount,
    required int foilCount,
  }) async {
    if (state.foundCard == null) return;

    await _collectionService.upsertCardInCollection(
      scryfallId: state.foundCard!.id,
      cardName: state.foundCard!.name,
      absoluteQuantity: normalCount,
      isFoil: false,
    );
    await _collectionService.upsertCardInCollection(
      scryfallId: state.foundCard!.id,
      cardName: state.foundCard!.name,
      absoluteQuantity: foilCount,
      isFoil: true,
    );

    await checkCardStatus();
  }

  // --- WISHLIST OPERATIONS ---

  Future<void> addToWishlist({
    required String listId,
    required bool isFoil,
  }) async {
    if (state.foundCard == null) return;

    await _wishlistService.upsertCard(
      wishlistId: listId,
      scryfallId: state.foundCard!.id,
      cardName: state.foundCard!.name,
      quantityToAdd: 1,
      isFoil: isFoil,
    );

    await checkCardStatus();
  }

  Future<String?> createWishlist(String name) async {
    await _wishlistService.createWishlist(name);
    final updatedLists = await _wishlistService.loadWishlists();
    try {
      final newList = updatedLists.lastWhere((w) => w.name == name);
      return newList.id;
    } catch (_) {
      return null;
    }
  }

  // --- GLOSSARY HELPER ---

  Keyword? findKeyword(String word) {
    if (state.activeGlossary.isEmpty) return null;
    final normalizedWord = word.toLowerCase().replaceAll(RegExp(r'[,\.]'), '');
    return state.activeGlossary
        .where((k) => k.term.toLowerCase() == normalizedWord).firstOrNull;
  }
}

// --- PROVIDER (family, parametre par CardDetailParams) ---

final cardDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<CardDetailController, CardDetailState, CardDetailParams>(
  (ref, params) {
    final deckService = ref.watch(deckServiceProvider);
    final collectionService = ref.watch(collectionServiceProvider);
    final historyService = ref.watch(scanHistoryServiceProvider);
    final wishlistService = ref.watch(wishlistServiceProvider);
    final localCardService = ref.watch(localCardServiceProvider);
    final apiService = ref.watch(scryfallApiServiceProvider);

    return CardDetailController(
      deckService: deckService,
      collectionService: collectionService,
      historyService: historyService,
      wishlistService: wishlistService,
      localCardService: localCardService,
      apiService: apiService,
      params: params,
    );
  },
);
