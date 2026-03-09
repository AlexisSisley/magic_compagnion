// Fichier : lib/controllers/deck_list_controller.dart
// Controller pour DeckListPage - extrait la logique metier de la page.

import 'dart:developer';

import 'package:flutter_riverpod/legacy.dart';

import '../data/secondary_breakfast.dart';
import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../providers/service_providers.dart';
import '../utils/price_helper.dart';
import '../services/deck_service.dart';
import '../services/local_card_service.dart';
import '../services/scryfall_api_service.dart';

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
  final ScryfallApiService _apiService;

  static final RegExp decklistRegex = RegExp(r'^(\d+)x?\s+(.+)$');

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
    required ScryfallApiService apiService,
  })  : _deckService = deckService,
        _localCardService = localCardService,
        _apiService = apiService,
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

  Future<DeckListActionResult> importDeck(String deckName, String decklistText) async {
    state = state.copyWith(isImporting: true, isLoading: true);

    List<Map<String, dynamic>> parsedMain = [];
    List<Map<String, dynamic>> parsedSide = [];
    String? commanderName;
    List<String> ids = [];
    String section = 'main';

    for (var line in decklistText.split('\n')) {
      line = line.trim();
      if (line.toLowerCase().startsWith('commander')) { section = 'cmd'; continue; }
      if (line.toLowerCase().startsWith('deck')) { section = 'main'; continue; }
      if (line.toLowerCase().startsWith('sideboard')) { section = 'side'; continue; }
      final match = decklistRegex.firstMatch(line);
      if (match != null) {
        int qty = int.parse(match.group(1)!);
        String name = match.group(2)!.trim().split('//')[0].trim();
        if (!ids.contains(name)) ids.add(name);
        if (section == 'cmd') {
          commanderName = name;
        } else if (section == 'side') {
          parsedSide.add({'name': name, 'quantity': qty});
        } else {
          parsedMain.add({'name': name, 'quantity': qty});
        }
      }
    }

    List<ScryfallCard> scryfallData = [];
    if (ids.isNotEmpty) {
      final query = ids.take(75).map((n) => '!"$n"').join(' OR ');
      try {
        final data = await _apiService.searchCards(query, unique: 'cards');
        scryfallData = (data['data'] as List).map((j) => ScryfallCard.fromJson(j)).toList();
      } catch (e) { log('Erreur import: $e'); }
    }

    Set<String> deckColors = {};
    for (var sc in scryfallData) { deckColors.addAll(sc.colorIdentity); }
    final order = {'W':0, 'U':1, 'B':2, 'R':3, 'G':4, 'C':5};
    final sortedColors = deckColors.toList()..sort((a,b) => (order[a]??9).compareTo(order[b]??9));

    await _deckService.createNewDeck(deckName);
    final decks = await _deckService.loadDecks();
    Deck newDeck = decks.where((d) => d.name == deckName).first;
    newDeck.colors = sortedColors;
    newDeck.format = commanderName != null ? 'Commander' : 'Standard';
    newDeck.mainboard = parsedMain.map((p) => DeckCard(scryfallId: _findId(scryfallData, p['name']), name: p['name'], quantity: p['quantity'])).toList();
    newDeck.sideboard = parsedSide.map((p) => DeckCard(scryfallId: _findId(scryfallData, p['name']), name: p['name'], quantity: p['quantity'])).toList();

    if (commanderName != null) {
      String cid = _findId(scryfallData, commanderName);
      newDeck.commanderScryfallId = cid;
      if (!newDeck.mainboard.any((c) => c.name == commanderName)) {
        newDeck.mainboard.add(DeckCard(scryfallId: cid, name: commanderName, quantity: 1));
      }
    }
    await _deckService.updateDeck(newDeck);
    state = state.copyWith(isImporting: false, isLoading: false);
    await loadDecks();

    return const DeckListActionResult(message: 'Deck importé avec succès.');
  }

  // --- HELPERS ---

  String _findId(List<ScryfallCard> data, String name) {
    return data.where((s) => s.name.toLowerCase() == name.toLowerCase()).firstOrNull?.id ?? 'LOCAL:$name';
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
    final apiService = ref.watch(scryfallApiServiceProvider);

    return DeckListController(
      deckService: deckService,
      localCardService: localCardService,
      apiService: apiService,
    );
  },
);
