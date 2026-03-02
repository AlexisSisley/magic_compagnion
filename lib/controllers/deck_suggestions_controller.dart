// Fichier : lib/controllers/deck_suggestions_controller.dart
// Controller pour DeckSuggestionsTab - extrait la logique metier du widget.

import 'dart:developer';

import 'package:flutter_riverpod/legacy.dart';

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../providers/service_providers.dart';
import '../services/deck_synergy_service.dart';
import '../services/edhrec_service.dart';
import '../services/local_card_service.dart';

// --- SUGGESTION ENRICHIE (publique) ---

/// Suggestion enrichie avec donnees EDHREC + carte resolue localement.
class EnrichedSuggestion {
  final ScryfallCard card;
  final double synergy;
  final int inclusion;
  final String categoryLabel;
  final int numDecks;
  final double salt;

  const EnrichedSuggestion({
    required this.card,
    required this.synergy,
    required this.inclusion,
    required this.categoryLabel,
    required this.numDecks,
    this.salt = 0.0,
  });
}

// --- ETAT IMMUTABLE ---

class DeckSuggestionsState {
  final EdhrecCommanderData? commanderData;
  final List<EdhrecCardSuggestion>? themeCards;
  final String? selectedTheme;
  final DeckSynergyReport? synergyReport;
  final Map<String, List<EnrichedSuggestion>> enrichedSuggestions;
  final bool isLoading;
  final bool hasLoaded;
  final bool isLoadingTheme;

  const DeckSuggestionsState({
    this.commanderData,
    this.themeCards,
    this.selectedTheme,
    this.synergyReport,
    this.enrichedSuggestions = const {},
    this.isLoading = false,
    this.hasLoaded = false,
    this.isLoadingTheme = false,
  });

  DeckSuggestionsState copyWith({
    EdhrecCommanderData? commanderData,
    List<EdhrecCardSuggestion>? themeCards,
    String? selectedTheme,
    DeckSynergyReport? synergyReport,
    Map<String, List<EnrichedSuggestion>>? enrichedSuggestions,
    bool? isLoading,
    bool? hasLoaded,
    bool? isLoadingTheme,
    bool clearTheme = false,
  }) {
    return DeckSuggestionsState(
      commanderData: commanderData ?? this.commanderData,
      themeCards: clearTheme ? null : (themeCards ?? this.themeCards),
      selectedTheme: clearTheme ? null : (selectedTheme ?? this.selectedTheme),
      synergyReport: synergyReport ?? this.synergyReport,
      enrichedSuggestions: enrichedSuggestions ?? this.enrichedSuggestions,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isLoadingTheme: isLoadingTheme ?? this.isLoadingTheme,
    );
  }
}

// --- CALLBACK TYPE pour generer le rapport de synergie ---

/// Callback qui genere un DeckSynergyReport a partir des donnees EDHREC.
/// Permet de decoupler le controller des details du DeckDetailController.
typedef SynergyReportGenerator = DeckSynergyReport? Function(
    EdhrecCommanderData edhrecData);

// --- CONTROLLER (StateNotifier) ---

class DeckSuggestionsController extends StateNotifier<DeckSuggestionsState> {
  final EdhrecService _edhrecService;
  final LocalCardService _localCardService;
  final Deck _deck;
  final SynergyReportGenerator? _synergyReportGenerator;

  DeckSuggestionsController({
    required EdhrecService edhrecService,
    required LocalCardService localCardService,
    required Deck deck,
    SynergyReportGenerator? synergyReportGenerator,
  })  : _edhrecService = edhrecService,
        _localCardService = localCardService,
        _deck = deck,
        _synergyReportGenerator = synergyReportGenerator,
        super(const DeckSuggestionsState()) {
    _ensureLocalDataLoaded();
  }

  void _ensureLocalDataLoaded() {
    if (!_localCardService.isLoaded) {
      _localCardService.loadLocalData();
    }
  }

  // --- CHARGEMENT SUGGESTIONS ---

  /// Retourne false si le deck n'a pas de commandant (UI doit afficher un message).
  /// Retourne true si le chargement a demarre.
  Future<bool> loadSuggestions() async {
    if (_deck.commanderScryfallId == null) return false;

    state = state.copyWith(isLoading: true);

    final commanderName = getCommanderName();
    if (commanderName.isEmpty) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    // Appel API EDHREC enrichi
    final commanderData =
        await _edhrecService.getCommanderData(commanderName);

    // Enrichir les suggestions avec les donnees locales
    final enriched = enrichSuggestions(commanderData.categorizedSuggestions);

    // Generer le rapport de synergie via le callback
    DeckSynergyReport? synergyReport;
    try {
      synergyReport = _synergyReportGenerator?.call(commanderData);
    } catch (e) {
      log('DeckSuggestionsController: synergyReport unavailable: $e');
    }

    if (!mounted) return true;

    state = state.copyWith(
      commanderData: commanderData,
      enrichedSuggestions: enriched,
      synergyReport: synergyReport,
      isLoading: false,
      hasLoaded: true,
      clearTheme: true,
    );

    return true;
  }

  // --- THEMES ---

  Future<void> loadThemeCards(EdhrecTheme theme) async {
    state = state.copyWith(
      isLoadingTheme: true,
      selectedTheme: theme.slug,
    );

    final commanderName = getCommanderName();
    final cards =
        await _edhrecService.getThemeCards(commanderName, theme.slug);

    if (!mounted) return;

    state = state.copyWith(
      themeCards: cards,
      isLoadingTheme: false,
    );
  }

  void clearTheme() {
    state = state.copyWith(clearTheme: true);
  }

  // --- HELPERS ---

  /// Resout le nom du commandant depuis les cartes du deck.
  String getCommanderName() {
    try {
      final allCards = [..._deck.mainboard, ..._deck.sideboard];
      final cmdCard = allCards.firstWhere(
        (c) => c.scryfallId == _deck.commanderScryfallId,
        orElse: () => DeckCard(scryfallId: '', name: '', quantity: 0),
      );

      if (cmdCard.name.isNotEmpty) {
        return cmdCard.name;
      }

      final localCmd =
          _localCardService.getCardById(_deck.commanderScryfallId!);
      if (localCmd != null) return localCmd.name;
    } catch (e) {
      // Ignorer
    }
    return '';
  }

  /// Enrichit les suggestions EDHREC avec les donnees de cartes locales.
  /// Filtre les cartes deja presentes dans le deck.
  Map<String, List<EnrichedSuggestion>> enrichSuggestions(
    Map<String, List<EdhrecCardSuggestion>> categorized,
  ) {
    final Set<String> deckCardNames =
        _deck.mainboard.map((c) => c.name.toLowerCase()).toSet();
    deckCardNames
        .addAll(_deck.sideboard.map((c) => c.name.toLowerCase()));

    final Map<String, List<EnrichedSuggestion>> enrichedMap = {};

    for (var entry in categorized.entries) {
      final String category = entry.key;
      final List<EnrichedSuggestion> cards = [];

      for (var suggestion in entry.value) {
        if (deckCardNames.contains(suggestion.name.toLowerCase())) continue;

        // Recherche locale
        ScryfallCard? card =
            _localCardService.getCardByName(suggestion.name);

        // Fallback virtuel
        card ??= ScryfallCard(
          id: 'edhrec_${suggestion.name.hashCode}',
          oracleId: '',
          name: suggestion.name,
          imageUrl: '',
          rulesText: '',
          typeLine: 'Suggestion externe',
          legalities: {},
          prices: {},
          lang: 'en',
          colorIdentity: [],
          setName: '',
          setCode: '',
          collectorNumber: '',
          rarity: '',
          purchaseUris: {},
        );

        cards.add(EnrichedSuggestion(
          card: card,
          synergy: suggestion.synergy,
          inclusion: suggestion.inclusion,
          categoryLabel: suggestion.categoryLabel,
          numDecks: suggestion.numDecks,
          salt: suggestion.salt,
        ));
      }

      if (cards.isNotEmpty) {
        enrichedMap[category] = cards;
      }
    }

    return enrichedMap;
  }
}

// --- PROVIDER (family, parametre par Deck) ---

final deckSuggestionsControllerProvider = StateNotifierProvider.autoDispose
    .family<DeckSuggestionsController, DeckSuggestionsState, Deck>(
  (ref, deck) {
    final edhrecService = ref.watch(edhrecServiceProvider);
    final localCardService = ref.watch(localCardServiceProvider);

    // Callback pour generer le rapport de synergie via DeckSynergyService
    DeckSynergyReport? synergyGenerator(EdhrecCommanderData edhrecData) =>
        DeckSynergyService.generateSynergyReport(
          edhrecData: edhrecData,
          deck: deck,
          commanderScryfallId: deck.commanderScryfallId,
        );

    return DeckSuggestionsController(
      edhrecService: edhrecService,
      localCardService: localCardService,
      deck: deck,
      synergyReportGenerator: synergyGenerator,
    );
  },
);
