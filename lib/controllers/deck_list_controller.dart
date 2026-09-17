// Fichier : lib/controllers/deck_list_controller.dart
// Controller pour DeckListPage - extrait la logique metier de la page.

import 'package:flutter_riverpod/legacy.dart';

import '../data/secondary_breakfast.dart';
import '../models/card_print.dart';
import '../models/deck_model.dart';
import '../providers/preferred_language_provider.dart';
import '../providers/service_providers.dart';
import '../utils/price_helper.dart';
import '../services/collection_service.dart';
import '../services/deck_format_service.dart';
import '../services/deck_service.dart';
import '../services/local_card_service.dart';

// --- RESULT OBJECT pour les actions ---

class DeckListActionResult {
  final bool success;
  final String message;

  const DeckListActionResult({
    this.success = true,
    this.message = '',
  });
}

// --- ETAT IMMUTABLE ---

class DeckListState {
  final List<Deck> decks;
  final List<Deck> filteredDecks;
  final Map<String, double> deckPrices;
  final bool isLoading;
  final bool isImporting;
  final String searchQuery;
  final String selectedFormat;
  final String selectedSort;
  final String? selectedIdentityName;
  final List<String>? selectedIdentityColors;

  const DeckListState({
    this.decks = const [],
    this.filteredDecks = const [],
    this.deckPrices = const {},
    this.isLoading = true,
    this.isImporting = false,
    this.searchQuery = '',
    this.selectedFormat = 'Tous',
    this.selectedSort = 'name',
    this.selectedIdentityName,
    this.selectedIdentityColors,
  });

  DeckListState copyWith({
    List<Deck>? decks,
    List<Deck>? filteredDecks,
    Map<String, double>? deckPrices,
    bool? isLoading,
    bool? isImporting,
    String? searchQuery,
    String? selectedFormat,
    String? selectedSort,
    String? selectedIdentityName,
    List<String>? selectedIdentityColors,
    bool clearIdentity = false,
  }) {
    return DeckListState(
      decks: decks ?? this.decks,
      filteredDecks: filteredDecks ?? this.filteredDecks,
      deckPrices: deckPrices ?? this.deckPrices,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      selectedSort: selectedSort ?? this.selectedSort,
      selectedIdentityName: clearIdentity ? null : (selectedIdentityName ?? this.selectedIdentityName),
      selectedIdentityColors: clearIdentity ? null : (selectedIdentityColors ?? this.selectedIdentityColors),
    );
  }
}

// --- CONTROLLER (StateNotifier) ---

class DeckListController extends StateNotifier<DeckListState> {
  final DeckService _deckService;
  final LocalCardService _localCardService;
  final CollectionService _collectionService;

  static const Map<String, Map<String, List<String>>> colorFamilies = {
    'Mono': {
      'Blanc': ['W'], 'Bleu': ['U'], 'Noir': ['B'], 'Rouge': ['R'], 'Vert': ['G'], 'Incolore': []
    },
    'Guilde (2)': {
      'Azorius': ['W', 'U'], 'Dimir': ['U', 'B'], 'Rakdos': ['B', 'R'], 'Gruul': ['R', 'G'], 'Selesnya': ['G', 'W'],
      'Orzhov': ['W', 'B'], 'Izzet': ['U', 'R'], 'Golgari': ['B', 'G'], 'Boros': ['R', 'W'], 'Simic': ['G', 'U']
    },
    'Trio (3)': {
      'Esper': ['W', 'U', 'B'], 'Grixis': ['U', 'B', 'R'], 'Jund': ['B', 'R', 'G'], 'Naya': ['R', 'G', 'W'], 'Bant': ['G', 'W', 'U'],
      'Abzan': ['W', 'B', 'G'], 'Jeskai': ['U', 'R', 'W'], 'Sultai': ['B', 'G', 'U'], 'Mardu': ['R', 'W', 'B'], 'Temur': ['G', 'U', 'R']
    },
    'Nephilim (4)': {
      'Yore-Tiller': ['W', 'U', 'B', 'R'], 'Glint-Eye': ['U', 'B', 'R', 'G'], 'Dune-Brood': ['B', 'R', 'G', 'W'],
      'Ink-Treader': ['R', 'G', 'W', 'U'], 'Witch-Maw': ['G', 'W', 'U', 'B']
    },
    'WUBRG (5)': {
      '5 Couleurs': ['W', 'U', 'B', 'R', 'G']
    }
  };

  DeckListController({
    required DeckService deckService,
    required LocalCardService localCardService,
    required CollectionService collectionService,
  })  : _deckService = deckService,
        _localCardService = localCardService,
        _collectionService = collectionService,
        super(const DeckListState()) {
    loadDecks();
  }

  // --- CHARGEMENT ---

  Future<void> loadDecks() async {
    state = state.copyWith(isLoading: true);
    await _localCardService.loadLocalData();
    final decks = await _deckService.loadDecks();

    // Calcul des prix
    final Map<String, double> prices = {};
    for (var deck in decks) {
      double total = 0.0;
      for (var card in deck.mainboard) {
        final localCard = _localCardService.getCardById(card.scryfallId);
        if (localCard != null) {
          double price = PriceHelper.bestPrice(localCard.prices);
          total += price * card.quantity;
        }
      }
      prices[deck.id] = total;
    }

    state = state.copyWith(decks: decks, deckPrices: prices, isLoading: false);
    _applyFilters();
  }

  // --- FILTRES ---

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void updateFormat(String format) {
    state = state.copyWith(selectedFormat: format);
    _applyFilters();
  }

  void updateSort(String sortCode) {
    state = state.copyWith(selectedSort: sortCode);
    _applyFilters();
  }

  void updateIdentityFilter(String name, List<String> colors) {
    state = state.copyWith(selectedIdentityName: name, selectedIdentityColors: colors);
    _applyFilters();
  }

  void clearIdentityFilter() {
    state = state.copyWith(clearIdentity: true);
    _applyFilters();
  }

  void _applyFilters() {
    final query = state.searchQuery.toLowerCase();

    var tempDecks = state.decks.where((deck) {
      if (!deck.name.toLowerCase().contains(query)) return false;

      final bool isCommander = deck.commanderScryfallId != null;
      if (state.selectedFormat == 'Commander' && !isCommander) return false;
      if (state.selectedFormat == 'Standard' && isCommander) return false;

      if (state.selectedIdentityColors != null) {
        if (state.selectedIdentityColors!.isEmpty) {
          if (deck.colors.isNotEmpty) return false;
        } else {
          final deckSet = deck.colors.toSet();
          final filterSet = state.selectedIdentityColors!.toSet();
          if (deckSet.length != filterSet.length || !deckSet.containsAll(filterSet)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    tempDecks.sort((a, b) {
      if (state.selectedSort == 'price_desc') {
        return (state.deckPrices[b.id] ?? 0).compareTo(state.deckPrices[a.id] ?? 0);
      } else if (state.selectedSort == 'price_asc') {
        return (state.deckPrices[a.id] ?? 0).compareTo(state.deckPrices[b.id] ?? 0);
      }
      return a.name.compareTo(b.name);
    });

    state = state.copyWith(filteredDecks: tempDecks);
  }

  // --- ACTIONS ---

  Future<void> deleteDeck(String deckId) async {
    await _deckService.deleteDeck(deckId);
    await loadDecks();
  }

  Future<void> createNewDeck(String name) async {
    if (name.isEmpty) return;
    await _deckService.createNewDeck(name);
    await loadDecks();
  }

  /// Resolves the easter egg check and returns the actual name/list to import.
  /// Returns (deckName, decklistText) after easter egg resolution.
  (String, String) resolveEasterEgg(String deckName, String decklistText) {
    if (deckName.toLowerCase() == 'second petit déjeuner') {
      return ('Nourriture et communauté', secondBreakfastDecklist);
    }
    return (deckName, decklistText);
  }

  /// Importe une decklist (texte ou CSV) en deck.
  ///
  /// Le decoupage en lignes/sections passe par [DeckFormatService] (TXT et
  /// CSV, Commander/Sideboard/Considering...) : plus de parser en doublon ici.
  /// La resolution passe par [CollectionService.resolveImportedEntries], donc
  /// par [CardResolver] : chaque carte est identifiee par son edition exacte
  /// (set + numero) quand la ligne la precise, et non par une recherche floue
  /// par nom qui rend une impression arbitraire. Aucun plafond arbitraire
  /// n'est applique : `resolveEditions` decoupe deja en lots en interne.
  ///
  /// Un import partiel n'est jamais silencieux : le message rendu a
  /// l'utilisateur nomme le nombre de cartes non identifiees.
  Future<DeckListActionResult> importDeck(String deckName, String decklistText) async {
    state = state.copyWith(isImporting: true, isLoading: true);

    final parseResult = DeckFormatService.autoDetectAndParse(decklistText);
    final List<DecklistEntry> allEntries = [
      ...parseResult.mainboard,
      ...parseResult.sideboard,
    ];

    EditionResolution resolution = const EditionResolution();
    final Map<String, List<ResolvedPrint>> printsByKey = {};

    if (allEntries.isNotEmpty) {
      final preferredLang = await readPreferredLanguage();

      resolution = await _collectionService.resolveImportedEntries(
        allEntries,
        preferredLang: preferredLang,
      );

      for (final print in resolution.resolved) {
        printsByKey.putIfAbsent(_printKey(print.name), () => []).add(print);
      }
    }

    // Couleur d'identite : accumulee au fil de la resolution de chaque
    // DeckCard ci-dessous, depuis le ResolvedPrint effectivement attribue --
    // il porte l'identite de couleur du tirage reellement resolu par
    // Scryfall, gratuite dans la reponse batch. LocalCardService ne sert
    // plus que de filet pour les cartes non resolues (notFound/failed) : le
    // bulk local (oracle-cards.json) est fige a la date de build de l'app et
    // ignorerait silencieusement toute carte plus recente.
    final Set<String> deckColors = {};

    DeckCard toDeckCard(DecklistEntry entry) {
      final print = _consumePrint(printsByKey, entry);
      if (print != null) {
        deckColors.addAll(print.colorIdentity);
        return DeckCard(
          scryfallId: print.scryfallId,
          name: entry.name,
          quantity: entry.quantity,
          isFoil: entry.isFoil,
        );
      }
      final local = _localCardService.getCardByName(entry.name);
      if (local != null) deckColors.addAll(local.colorIdentity);
      return DeckCard(
        scryfallId: 'LOCAL:${entry.name}',
        name: entry.name,
        quantity: entry.quantity,
        isFoil: entry.isFoil,
      );
    }

    await _deckService.createNewDeck(deckName);
    final decks = await _deckService.loadDecks();
    Deck newDeck = decks.where((d) => d.name == deckName).first;
    newDeck.format = parseResult.commanderName != null ? 'Commander' : 'Standard';
    newDeck.mainboard = parseResult.mainboard.map(toDeckCard).toList();
    newDeck.sideboard = parseResult.sideboard.map(toDeckCard).toList();

    const order = {'W': 0, 'U': 1, 'B': 2, 'R': 3, 'G': 4, 'C': 5};
    newDeck.colors = deckColors.toList()
      ..sort((a, b) => (order[a] ?? 9).compareTo(order[b] ?? 9));

    if (parseResult.commanderName != null) {
      final commanderCard = newDeck.mainboard
          .where((c) => c.name == parseResult.commanderName)
          .firstOrNull;
      newDeck.commanderScryfallId =
          commanderCard?.scryfallId ?? 'LOCAL:${parseResult.commanderName}';
    }

    await _deckService.updateDeck(newDeck);
    state = state.copyWith(isImporting: false, isLoading: false);
    await loadDecks();

    final unresolved = resolution.notFound.length + resolution.failed.length;
    final message = resolution.isComplete
        ? 'Deck importé avec succès.'
        : 'Deck importé : $unresolved carte(s) sur ${allEntries.length} n\'ont pas '
            'pu être identifiées.';

    return DeckListActionResult(success: resolution.isComplete, message: message);
  }

  // --- HELPERS ---

  /// Cle d'association entre un [DecklistEntry] et le [ResolvedPrint] qui lui
  /// correspond. Par nom, pas par set+numero : un [ResolvedPrint] porte
  /// toujours une edition concrete (celle que Scryfall a rendue), meme quand
  /// la ligne d'origine n'en precisait aucune -- cle par set+numero cote
  /// tirage et par nom cote entree ne matcheraient alors jamais. Le nom, lui,
  /// est stable entre les deux cotes (Scryfall rend le nom demande a
  /// l'identique, que la requete ait ete faite par nom ou par edition).
  ///
  /// Deux entrees de meme nom (rare : editions distinctes de la meme carte
  /// sur deux lignes) partagent alors la meme cle et se voient attribuer un
  /// tirage chacune par consommation FIFO -- pas necessairement celui
  /// demande par chacune. C'est le meme compromis, deja assume et documente,
  /// que celui de `CardResolver._identifierMatches`/`_consumeMatch` : non
  /// corrige ici, non plus.
  String _printKey(String name) => name.toLowerCase();

  /// Consomme, dans [printsByKey], le tirage resolu correspondant a [entry].
  /// Rend `null` sans correspondance (carte non resolue : `notFound`,
  /// `failed`, ou file deja epuisee pour ce nom) -- l'appelant retombe alors
  /// sur le sentinel `LOCAL:<nom>`, le meme que le reste de l'app utilise
  /// deja pour signaler une carte sans identite Scryfall connue (voir
  /// `legality_service.dart`, `deck_stats_controller.dart`...).
  ResolvedPrint? _consumePrint(
    Map<String, List<ResolvedPrint>> printsByKey,
    DecklistEntry entry,
  ) {
    final bucket = printsByKey[_printKey(entry.name)];
    if (bucket != null && bucket.isNotEmpty) {
      return bucket.removeAt(0);
    }
    return null;
  }

  String getSortLabel(String code) {
    switch(code) {
      case 'price_desc': return 'Prix (Décroissant)';
      case 'price_asc': return 'Prix (Croissant)';
      default: return 'Nom (A-Z)';
    }
  }

  double getDeckPrice(String deckId) => state.deckPrices[deckId] ?? 0.0;
}

// --- PROVIDER ---

final deckListControllerProvider = StateNotifierProvider.autoDispose<DeckListController, DeckListState>(
  (ref) {
    final deckService = ref.watch(deckServiceProvider);
    final localCardService = ref.watch(localCardServiceProvider);
    final collectionService = ref.watch(collectionServiceProvider);

    return DeckListController(
      deckService: deckService,
      localCardService: localCardService,
      collectionService: collectionService,
    );
  },
);
