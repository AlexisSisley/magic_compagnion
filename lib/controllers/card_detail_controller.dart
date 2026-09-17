// Fichier : lib/controllers/card_detail_controller.dart
// Controller pour RecognitionResultPage - extrait la logique metier de la page.

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/glossary_data.dart';
import '../models/scan_history_model.dart';
import '../models/scryfall_card_model.dart';
import '../models/scryfall_ruling.dart';
import '../providers/service_providers.dart';
import '../services/card_resolver.dart';
import '../services/collection_service.dart';
import '../services/deck_service.dart';
import '../services/local_card_service.dart';
import '../services/scan_history_service.dart';
import '../services/scryfall_api_service.dart';
import '../services/translation_worker.dart';
import '../services/wishlist_service.dart';

// --- ENUM (reutilise depuis la page) ---

enum ResultPageState { loading, selection, success, error }

// --- LECTURE DU BAS DE CARTE (edition, numero, langue) ---

/// Langues imprimees sur les cartes et connues de Scryfall (route
/// `/cards/{set}/{cn}/{lang}`). Un code hors de cette liste est traite
/// comme "pas de langue", jamais comme une langue a essayer.
const Set<String> kPrintedLanguages = {
  'en', 'fr', 'de', 'it', 'es', 'pt', 'ja', 'ko', 'ru', 'zhs', 'zht', 'ph',
};

/// Format moderne (post-8e edition) : "`CN`[a]/`TOTAL` [`RARETE`] `SET`",
/// ex. "146/280 C ELD", "150/332 M 2XM" (Double Masters), "10/407 M 40K"
/// (Universes Beyond 40K). Le numero de collection precede le code
/// d'edition, qui peut melanger lettres et chiffres : seule sa *position*
/// (juste apres la rarete, elle-meme juste apres `CN`/`TOTAL`) l'identifie,
/// pas sa forme — imposer "commence par une lettre" exclurait des editions
/// courantes. `•` et `·` sont acceptes comme separateurs : l'OCR restitue
/// parfois le point median imprime entre les segments par l'un ou l'autre
/// caractere.
final RegExp _footerModernRegex = RegExp(
  r'\b(\d{1,4}[a-z]?)\s*/\s*\d{1,4}\b(?:[\s•·]+[A-Z])?[\s•·]+([A-Z0-9]{2,5})\b',
);

/// Format historique : "`SET` `CN`", ex. "ELD 146". Le code d'edition
/// precede le numero de collection. Ne reconnait pas les codes d'edition
/// entierement numeriques (ex. anciens sets "4ED") : ils sont indiscernables
/// d'un numero de collection isole.
final RegExp _footerLegacyRegex = RegExp(
  r'\b([A-Z0-9]{2,5})[\s•·]+(\d{1,4}[a-z]?)\b',
);

/// Code langue attendu juste apres le motif edition/numero (ex. "FR" apres
/// "ELD"). Ancre sur le debut du texte restant (immediatement apres le
/// motif reconnu) plutot que sur la fin de toute la chaine : un bloc OCR
/// peut concatener d'autres lignes (credit artiste, copyright) apres la
/// langue, et un mot plus long ne doit jamais etre tronque pour ressembler
/// a un code valide.
final RegExp _footerLangRegex = RegExp(r'^[\s•·\/\-]*([A-Z]{2,3})\b');

/// Vrai si `token` contient au moins une lettre — un code d'edition Scryfall
/// n'est jamais entierement numerique. Sert de garde-fou pour les deux
/// regex ci-dessus : sans elle, une paire de nombres isoles (ex. deux vies
/// affichees l'une a cote de l'autre) pourrait etre lue comme "set + cn".
bool _looksLikeSetCode(String token) => RegExp(r'[A-Z]').hasMatch(token);

/// Lit le bas d'une carte : edition, numero de collection et langue
/// imprimee. Rend null quand aucun motif d'edition n'est reconnaissable.
///
/// Deux formats sont essayes, dans cet ordre : le format moderne
/// "CN/TOTAL RARETE SET" (le numero precede l'edition), puis le format
/// historique "SET CN" (l'edition precede le numero). La langue, si
/// presente, est lue juste apres le motif reconnu — jamais a la fin de la
/// chaine entiere, qui peut contenir du texte OCR sans rapport.
///
/// Le bas d'une carte Magic est imprime en MAJUSCULES : les jetons edition
/// et langue doivent donc l'etre aussi. Ce n'est pas une simplification —
/// c'est ce qui empeche le texte de regles ordinaire ("turn 2", "put 2
/// loyalty counters") d'etre confondu avec un motif edition/numero, et un
/// mot comme "It" (majuscule de debut de phrase, pas un code) d'etre lu
/// comme la langue italienne.
({String setCode, String collectorNumber, String? lang})? parsePrintFooter(
  String blockText,
) {
  String? setCode;
  String? collectorNumber;
  int matchEnd = 0;

  final modernMatch = _footerModernRegex.firstMatch(blockText);
  if (modernMatch != null && _looksLikeSetCode(modernMatch.group(2)!)) {
    collectorNumber = modernMatch.group(1);
    setCode = modernMatch.group(2);
    matchEnd = modernMatch.end;
  } else {
    final legacyMatch = _footerLegacyRegex.firstMatch(blockText);
    if (legacyMatch != null && _looksLikeSetCode(legacyMatch.group(1)!)) {
      setCode = legacyMatch.group(1);
      collectorNumber = legacyMatch.group(2);
      matchEnd = legacyMatch.end;
    }
  }

  if (setCode == null || collectorNumber == null) return null;

  String? lang;
  final remainder = blockText.substring(matchEnd);
  final langMatch = _footerLangRegex.firstMatch(remainder);
  final candidate = langMatch?.group(1)?.toLowerCase();
  if (candidate != null && kPrintedLanguages.contains(candidate)) {
    lang = candidate;
  }

  return (setCode: setCode, collectorNumber: collectorNumber, lang: lang);
}

/// Vrai quand `e` signale l'absence d'une traduction precise sur la route
/// `/cards/{set}/{cn}/{lang}` (404 Scryfall) — le seul cas ou il est correct
/// de retomber sur un appel sans langue. Toute autre erreur (reseau coupe,
/// 5xx, timeout...) est une vraie panne et rend faux, pour ne jamais la
/// faire passer silencieusement pour une simple carte introuvable.
bool isMissingTranslation(Object e) =>
    e is DioException && e.response?.statusCode == 404;

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
  final CardResolver _cardResolver;
  final TranslationWorker _translationWorker;
  final CardDetailParams _params;

  CardDetailController({
    required DeckService deckService,
    required CollectionService collectionService,
    required ScanHistoryService historyService,
    required WishlistService wishlistService,
    required LocalCardService localCardService,
    required ScryfallApiService apiService,
    required CardResolver cardResolver,
    required TranslationWorker translationWorker,
    required CardDetailParams params,
  })  : _deckService = deckService,
        _collectionService = collectionService,
        _historyService = historyService,
        _wishlistService = wishlistService,
        _localCardService = localCardService,
        _apiService = apiService,
        _cardResolver = cardResolver,
        _translationWorker = translationWorker,
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

      for (var block in recognizedText.blocks) {
        final String blockText = block.text.replaceAll('\n', ' ');
        final parsed = parsePrintFooter(blockText);
        if (parsed != null) {
          if (!mounted) return;
          state = state.copyWith(
            statusMessage:
                'Code détecté : ${parsed.setCode} #${parsed.collectorNumber}',
          );
          final bool success = await _fetchExactCard(
            parsed.setCode,
            parsed.collectorNumber,
            lang: parsed.lang,
          );
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

  /// Identification precise d'une carte par son edition et son numero de
  /// collection : l'etape du scan une fois le bas de carte lu.
  ///
  /// Publique pour etre testable : le chemin normal y arrive par l'OCR d'une
  /// photo, qu'un test `flutter_test` ne peut pas jouer.
  Future<bool> fetchExactCard(String set, String cn, {String? lang}) =>
      _fetchExactCard(set, cn, lang: lang);

  Future<bool> _fetchExactCard(String set, String cn, {String? lang}) async {
    state = state.copyWith(
      statusMessage: 'Identification précise ($set #$cn)...',
    );
    try {
      final data = await _apiService.getCardBySetAndNumber(set, cn, lang: lang);
      // Le scan tient le JSON Scryfall complet : il ecrit le tirage dans le
      // cache `card_prints`. Sans cela, une carte identifiee par scan (puis
      // ajoutee a la collection) n'aurait jamais de ligne `card_prints` --
      // `PrintBackfillService.runOnce` ne s'executant qu'une seule fois dans
      // la vie de l'app --, donc resterait invisible pour `resolveDisplay`
      // comme pour `enqueueOwnedCardsForLanguage`, definitivement.
      // Une panne d'ecriture du cache ne doit pas faire echouer
      // l'identification elle-meme : elle se consigne (voir _cachePrint).
      await _cachePrint(data);
      selectCard(ScryfallCard.fromJson(data));
      // Temps 2 : un scan reussi est l'un des trois declencheurs de vidage de
      // la file de traduction prevus par la spec. Sans `await` : l'affichage
      // de la carte ne l'attend pas.
      unawaited(_translationWorker.drain());
      return true;
    } catch (e) {
      // Une traduction absente rend 404 sur cette route (isMissingTranslation) :
      // ce n'est pas un echec d'identification, on retente sans langue (un
      // seul niveau, toujours avec lang: null, donc aucune boucle possible).
      // Toute autre erreur (reseau coupe, 5xx, timeout...) est une vraie
      // panne : on ne la masque pas derriere un repli qui echouerait de la
      // meme façon.
      if (lang != null && isMissingTranslation(e)) {
        return _fetchExactCard(set, cn);
      }
    }
    return false;
  }

  /// Ecrit un tirage dans le cache sans jamais lever : une panne base ne doit
  /// pas transformer une identification reussie en echec affiche.
  Future<void> _cachePrint(Map<String, dynamic> json) async {
    try {
      await _cardResolver.cachePrintFromJson(json);
    } catch (e) {
      log('Mise en cache du tirage scanne impossible: $e',
          name: 'CardDetailController');
    }
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
    final cardResolver = ref.watch(cardResolverProvider);
    final translationWorker = ref.watch(translationWorkerProvider);

    return CardDetailController(
      deckService: deckService,
      collectionService: collectionService,
      historyService: historyService,
      wishlistService: wishlistService,
      localCardService: localCardService,
      apiService: apiService,
      cardResolver: cardResolver,
      translationWorker: translationWorker,
      params: params,
    );
  },
);
