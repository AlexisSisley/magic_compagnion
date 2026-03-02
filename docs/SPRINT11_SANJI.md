# Sprint 11 - Architecture Technique : EDHREC Deep Integration
> Agent : Sanji (Architecte) | Date : 01/03/2026

---

## Phase 1 : Comprehension du Probleme & Perimetre

### Perimetre fonctionnel
- **Inclus** : Themes/tribus EDHREC, score de synergie par carte et global, detection de combos, enrichissement de DeckSuggestionsTab
- **Exclu** : Salt score, power level, deck average, recommandations non-Commander, API authentifiee

### Stack existante (inchangee)
- **Langage** : Dart 3.9+ / Flutter 3.35.6
- **State Management** : Riverpod (StateNotifier + AutoDispose)
- **Base de donnees** : drift (SQLite)
- **Navigation** : go_router
- **HTTP** : Dio + cache memoire + rate limiting (ScryfallApiService)
- **CI/CD** : GitHub Actions
- **Tests** : 368 tests, flutter_test

### NFR
- 0 regression fonctionnelle
- 368 tests verts en permanence
- Chargement donnees EDHREC < 3s (themes + synergy) apres le premier chargement
- Cache EDHREC de 1h minimum (donnees stables)
- Rate limiting EDHREC : max 5 req/sec (precaution, pas de doc officielle)
- Fallback gracieux si API EDHREC indisponible

### Projet existant
**PROJECT_PATH** = `C:/Users/Alexi/Documents/projet/magic_compagnion/`

---

## Phase 2 : Choix Techniques

| Choix | Decision | Justification |
|-------|----------|---------------|
| Enrichissement EdhrecService | Ajouter methodes pour themes, combos, synergy | Service existant deja injecte via Riverpod, pas besoin de nouveau service |
| Modeles de donnees EDHREC | Creer `EdhrecModels` avec classes typees | Les donnees actuelles sont des Map brutes, pas typees |
| Cache EDHREC | Cache memoire dans EdhrecService (meme pattern que ScryfallApiService) | Donnees stables, evite les appels repetes |
| Score de synergie global | Calcul local dans DeckDetailController | Cross-reference entre deck et donnees EDHREC, pas de requete supplementaire |
| Detection combos | Comparaison locale deck vs combos EDHREC | Les combos sont des listes de noms de cartes, facile a croiser |
| Themes a la demande | Lazy loading : charger les cartes d'un theme uniquement quand l'utilisateur clique | Evite de charger 20+ themes en parallele |
| Pas de nouveau package | Dio deja present pour les appels HTTP | Zero nouvelle dependance |

---

## Phase 3 : Architecture des Changements

### 3.1 Nouveaux Modeles : `EdhrecModels`

```
lib/models/edhrec_models.dart (~120 lignes)
```

```dart
/// Carte recommandee par EDHREC avec scores.
class EdhrecCardSuggestion {
  final String name;
  final String sanitized;
  final double synergy;    // -1.0 a +1.0
  final int inclusion;     // pourcentage (0-100)
  final int numDecks;      // nombre de decks utilisant cette carte
  final int potentialDecks; // nombre total de decks analyses

  const EdhrecCardSuggestion({
    required this.name,
    required this.sanitized,
    required this.synergy,
    required this.inclusion,
    required this.numDecks,
    required this.potentialDecks,
  });

  factory EdhrecCardSuggestion.fromJson(Map<String, dynamic> json) {
    return EdhrecCardSuggestion(
      name: json['name'] ?? '',
      sanitized: json['sanitized'] ?? '',
      synergy: (json['synergy'] as num?)?.toDouble() ?? 0.0,
      inclusion: (json['inclusion'] as num?)?.toInt() ?? 0,
      numDecks: (json['num_decks'] as num?)?.toInt() ?? 0,
      potentialDecks: (json['potential_decks'] as num?)?.toInt() ?? 0,
    );
  }

  /// Label de categorie : "Pick specifique" si haute synergie, "Staple" si haute inclusion + faible synergie.
  String get categoryLabel {
    if (synergy >= 0.20) return 'Pick specifique';
    if (synergy >= 0.05) return 'Bonne synergie';
    if (inclusion >= 80 && synergy < 0.05) return 'Staple generique';
    return 'Standard';
  }
}

/// Theme ou tribu disponible pour un commandant.
class EdhrecTheme {
  final String name;
  final String slug;
  final int deckCount;

  const EdhrecTheme({
    required this.name,
    required this.slug,
    required this.deckCount,
  });

  factory EdhrecTheme.fromJson(Map<String, dynamic> json) {
    final href = json['href'] as String? ?? '';
    // href format: "/themes/atraxa-praetors-voice/infect"
    final slug = href.split('/').last;
    return EdhrecTheme(
      name: json['value'] as String? ?? json['name'] as String? ?? '',
      slug: slug,
      deckCount: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Combo identifie par EDHREC.
class EdhrecCombo {
  final int comboId;
  final String name;         // ex: "Vraska + Vorinclex"
  final List<String> cardNames;  // noms des cartes du combo
  final List<String> results;    // ex: ["Target opponent loses the game"]
  final String colors;       // ex: "GWUB"
  final int deckCount;       // nombre de decks utilisant ce combo
  final double percentage;   // pourcentage d'utilisation
  final int rank;            // rang de popularite

  const EdhrecCombo({
    required this.comboId,
    required this.name,
    required this.cardNames,
    required this.results,
    required this.colors,
    required this.deckCount,
    required this.percentage,
    required this.rank,
  });

  factory EdhrecCombo.fromJson(Map<String, dynamic> section) {
    final cardViews = section['cardviews'] as List<dynamic>? ?? [];
    final cardNames = cardViews.map((c) => c['name'] as String? ?? '').toList();
    final combo = section['combo'] as Map<String, dynamic>? ?? {};
    final results = (combo['results'] as List<dynamic>?)
        ?.map((r) => r.toString())
        .toList() ?? [];

    return EdhrecCombo(
      comboId: (combo['comboId'] as num?)?.toInt() ?? 0,
      name: section['header'] as String? ?? cardNames.join(' + '),
      cardNames: cardNames,
      results: results,
      colors: combo['colors'] as String? ?? '',
      deckCount: (combo['count'] as num?)?.toInt() ?? 0,
      percentage: (combo['percentage'] as num?)?.toDouble() ?? 0.0,
      rank: (combo['rank'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Resultat complet de l'analyse EDHREC pour un commandant.
class EdhrecCommanderData {
  final Map<String, List<EdhrecCardSuggestion>> categorizedSuggestions;
  final List<EdhrecTheme> themes;
  final List<EdhrecCombo> topCombos;  // Top 50 combos (resume depuis la page principale)
  final int totalDecks;               // Nombre total de decks analyses

  const EdhrecCommanderData({
    required this.categorizedSuggestions,
    required this.themes,
    required this.topCombos,
    required this.totalDecks,
  });

  static const empty = EdhrecCommanderData(
    categorizedSuggestions: {},
    themes: [],
    topCombos: [],
    totalDecks: 0,
  );
}

/// Resultat de l'analyse de synergie d'un deck.
class DeckSynergyReport {
  final double globalScore;           // 0-100
  final int cardsWithSynergyData;     // Nombre de cartes du deck trouvees dans EDHREC
  final int totalDeckCards;            // Nombre total de cartes du deck
  final List<CardSynergyEntry> cardScores; // Score par carte du deck

  const DeckSynergyReport({
    required this.globalScore,
    required this.cardsWithSynergyData,
    required this.totalDeckCards,
    required this.cardScores,
  });
}

/// Score de synergie d'une carte individuelle du deck.
class CardSynergyEntry {
  final String cardName;
  final String scryfallId;
  final double synergy;     // -1.0 a +1.0
  final int inclusion;      // 0-100
  final String categoryLabel; // "Pick specifique", "Staple generique", etc.

  const CardSynergyEntry({
    required this.cardName,
    required this.scryfallId,
    required this.synergy,
    required this.inclusion,
    required this.categoryLabel,
  });
}

/// Combo avec statut de presence dans le deck.
class DeckComboStatus {
  final EdhrecCombo combo;
  final List<String> cardsInDeck;     // Cartes du combo presentes dans le deck
  final List<String> cardsMissing;    // Cartes du combo manquantes
  final ComboCompleteness completeness; // complete, partial, none

  const DeckComboStatus({
    required this.combo,
    required this.cardsInDeck,
    required this.cardsMissing,
    required this.completeness,
  });
}

enum ComboCompleteness { complete, partial, none }
```

### 3.2 US-11.1 + US-11.2 : Enrichissement EdhrecService

#### Enrichissement du service : `EdhrecService`

Le service existant (`lib/services/edhrec_service.dart`) est enrichi avec :

```dart
class EdhrecService {
  final Dio _dio;
  // Cache memoire (commanderSlug -> EdhrecCommanderData)
  final Map<String, _CacheEntry<EdhrecCommanderData>> _commanderCache = {};
  // Cache themes (commanderSlug/theme -> List<EdhrecCardSuggestion>)
  final Map<String, _CacheEntry<List<EdhrecCardSuggestion>>> _themeCache = {};
  // Cache combos (commanderSlug -> List<EdhrecCombo>)
  final Map<String, _CacheEntry<List<EdhrecCombo>>> _comboCache = {};

  static const Duration _cacheTtl = Duration(hours: 1);

  // ... constructeur et _formatSlug() existants ...

  /// Charge les donnees completes d'un commandant (suggestions enrichies + themes + combos resume).
  Future<EdhrecCommanderData> getCommanderData(String commanderName) async {
    final slug = _formatSlug(commanderName);

    // Cache check
    final cached = _commanderCache[slug];
    if (cached != null && !cached.isExpired) return cached.data;

    try {
      final response = await _dio.get('/pages/commanders/$slug.json');
      if (response.statusCode != 200) return EdhrecCommanderData.empty;

      final data = response.data as Map<String, dynamic>? ?? {};
      if (!data.containsKey('container')) return EdhrecCommanderData.empty;

      final container = data['container'] as Map<String, dynamic>? ?? {};
      final jsonDict = container['json_dict'] as Map<String, dynamic>? ?? {};
      final cardLists = jsonDict['cardlists'] as List<dynamic>? ?? [];

      // 1. Parser les suggestions enrichies
      final categorized = _parseCardLists(cardLists);

      // 2. Parser les themes (taglinks)
      final themes = _parseThemes(container);

      // 3. Parser les combos resume (combocounts)
      final topCombos = _parseTopCombos(container);

      // 4. Total decks
      final totalDecks = (data['num_decks_avg'] as num?)?.toInt() ?? 0;

      final result = EdhrecCommanderData(
        categorizedSuggestions: categorized,
        themes: themes,
        topCombos: topCombos,
        totalDecks: totalDecks,
      );

      _commanderCache[slug] = _CacheEntry(result);
      return result;
    } catch (e) {
      log('Exception EDHREC getCommanderData: $e', name: 'EdhrecService');
      return EdhrecCommanderData.empty;
    }
  }

  /// Charge les cartes recommandees pour un theme specifique.
  Future<List<EdhrecCardSuggestion>> getThemeCards(
    String commanderName,
    String themeSlug,
  ) async {
    final cmdSlug = _formatSlug(commanderName);
    final cacheKey = '$cmdSlug/$themeSlug';

    final cached = _themeCache[cacheKey];
    if (cached != null && !cached.isExpired) return cached.data;

    try {
      final response = await _dio.get('/pages/themes/$cmdSlug/$themeSlug.json');
      if (response.statusCode != 200) return [];

      final data = response.data as Map<String, dynamic>? ?? {};
      final container = data['container'] as Map<String, dynamic>? ?? {};
      final jsonDict = container['json_dict'] as Map<String, dynamic>? ?? {};
      final cardLists = jsonDict['cardlists'] as List<dynamic>? ?? [];

      final allCards = <EdhrecCardSuggestion>[];
      for (final section in cardLists) {
        final cardViews = section['cardviews'] as List<dynamic>? ?? [];
        for (final card in cardViews) {
          allCards.add(EdhrecCardSuggestion.fromJson(card));
        }
      }

      _themeCache[cacheKey] = _CacheEntry(allCards);
      return allCards;
    } catch (e) {
      log('Exception EDHREC getThemeCards: $e', name: 'EdhrecService');
      return [];
    }
  }

  /// Charge les combos complets pour un commandant.
  Future<List<EdhrecCombo>> getCommanderCombos(String commanderName) async {
    final slug = _formatSlug(commanderName);

    final cached = _comboCache[slug];
    if (cached != null && !cached.isExpired) return cached.data;

    try {
      final response = await _dio.get('/pages/combos/$slug.json');
      if (response.statusCode != 200) return [];

      final data = response.data as Map<String, dynamic>? ?? {};
      final container = data['container'] as Map<String, dynamic>? ?? {};
      final jsonDict = container['json_dict'] as Map<String, dynamic>? ?? {};
      final cardLists = jsonDict['cardlists'] as List<dynamic>? ?? [];

      final combos = cardLists
          .map((section) => EdhrecCombo.fromJson(section))
          .where((c) => c.cardNames.isNotEmpty)
          .toList()
        ..sort((a, b) => b.deckCount.compareTo(a.deckCount));

      // Limiter a 50 combos les plus populaires
      final top50 = combos.take(50).toList();

      _comboCache[slug] = _CacheEntry(top50);
      return top50;
    } catch (e) {
      log('Exception EDHREC getCombos: $e', name: 'EdhrecService');
      return [];
    }
  }

  // --- CONSERVE : methode existante pour retrocompatibilite ---
  Future<Map<String, List<String>>> getRecommendations(String commanderName) async {
    // ... code existant inchange ...
  }

  // --- PRIVATE HELPERS ---

  Map<String, List<EdhrecCardSuggestion>> _parseCardLists(List<dynamic> cardLists) {
    final Map<String, List<EdhrecCardSuggestion>> result = {};

    final sectionsMap = {
      'High Synergy Cards': 'Haute Synergie',
      'Top Cards': 'Top Cartes',
      'New Cards': 'Nouvelles Cartes',
      'Creatures': 'Creatures',
      'Instants': 'Ephemeres',
      'Sorceries': 'Rituels',
      'Artifacts': 'Artefacts',
      'Enchantments': 'Enchantements',
      'Lands': 'Terrains',
      'Planeswalkers': 'Planeswalkers',
      'Utility Artifacts': 'Artefacts Utilitaires',
      'Game Changers': 'Game Changers',
    };

    for (final section in cardLists) {
      final header = section['header'] as String? ?? '';
      final categoryTitle = sectionsMap[header];
      if (categoryTitle == null) continue;

      final cardViews = section['cardviews'] as List<dynamic>? ?? [];
      final cards = cardViews
          .map((cv) => EdhrecCardSuggestion.fromJson(cv))
          .toList();

      if (cards.isNotEmpty) {
        result[categoryTitle] = cards;
      }
    }

    return result;
  }

  List<EdhrecTheme> _parseThemes(Map<String, dynamic> container) {
    final List<EdhrecTheme> themes = [];
    final jsonDict = container['json_dict'] as Map<String, dynamic>? ?? {};
    final tagLinks = jsonDict['taglinks'] as List<dynamic>? ?? [];

    for (final tagLink in tagLinks) {
      if (tagLink is Map<String, dynamic>) {
        final theme = EdhrecTheme.fromJson(tagLink);
        if (theme.deckCount >= 50) { // Filtrer les themes trop petits
          themes.add(theme);
        }
      }
    }

    // Trier par nombre de decks decroissant
    themes.sort((a, b) => b.deckCount.compareTo(a.deckCount));
    return themes;
  }

  List<EdhrecCombo> _parseTopCombos(Map<String, dynamic> container) {
    final jsonDict = container['json_dict'] as Map<String, dynamic>? ?? {};
    final comboCounts = jsonDict['combocounts'] as List<dynamic>? ?? [];

    return comboCounts
        .take(10)  // Top 10 combos depuis la page principale
        .map((c) {
          if (c is Map<String, dynamic>) {
            return EdhrecCombo(
              comboId: 0,
              name: c['name'] as String? ?? '',
              cardNames: (c['name'] as String? ?? '').split(' + '),
              results: [],
              colors: '',
              deckCount: (c['count'] as num?)?.toInt() ?? 0,
              percentage: 0.0,
              rank: 0,
            );
          }
          return null;
        })
        .whereType<EdhrecCombo>()
        .toList();
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime createdAt;

  _CacheEntry(this.data) : createdAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(createdAt) > EdhrecService._cacheTtl;
}
```

### 3.3 US-11.2 : Score de Synergie dans DeckDetailController

Ajouter dans `DeckDetailController` :

```dart
/// Genere le rapport de synergie du deck.
/// Cross-reference les cartes du deck avec les donnees EDHREC.
DeckSynergyReport? generateSynergyReport(EdhrecCommanderData edhrecData) {
  if (state.currentDeck.commanderScryfallId == null) return null;

  final deck = state.currentDeck;
  final allDeckCards = [...deck.mainboard, ...deck.sideboard];

  // Construire la map nom -> synergy depuis toutes les categories EDHREC
  final Map<String, EdhrecCardSuggestion> edhrecByName = {};
  for (final cards in edhrecData.categorizedSuggestions.values) {
    for (final card in cards) {
      edhrecByName[card.name.toLowerCase()] = card;
    }
  }

  // Cross-reference
  final List<CardSynergyEntry> entries = [];
  for (final deckCard in allDeckCards) {
    final match = edhrecByName[deckCard.name.toLowerCase()];
    if (match != null) {
      entries.add(CardSynergyEntry(
        cardName: deckCard.name,
        scryfallId: deckCard.scryfallId,
        synergy: match.synergy,
        inclusion: match.inclusion,
        categoryLabel: match.categoryLabel,
      ));
    }
  }

  // Score global : moyenne ponderee des synergies (les cartes avec haute inclusion ponderent moins)
  double totalSynergy = 0.0;
  for (final entry in entries) {
    totalSynergy += entry.synergy;
  }
  final avgSynergy = entries.isEmpty ? 0.0 : totalSynergy / entries.length;
  // Normaliser en 0-100 : synergy de -1 -> 0, synergy de 0 -> 50, synergy de +1 -> 100
  final globalScore = ((avgSynergy + 1.0) / 2.0 * 100).clamp(0.0, 100.0);

  return DeckSynergyReport(
    globalScore: globalScore,
    cardsWithSynergyData: entries.length,
    totalDeckCards: allDeckCards.length,
    cardScores: entries..sort((a, b) => b.synergy.compareTo(a.synergy)),
  );
}
```

### 3.4 US-11.3 : Detection de Combos dans DeckDetailController

```dart
/// Analyse les combos EDHREC et detecte leur presence dans le deck.
List<DeckComboStatus> detectCombos(List<EdhrecCombo> combos) {
  final deck = state.currentDeck;
  final deckCardNames = <String>{
    ...deck.mainboard.map((c) => c.name.toLowerCase()),
    ...deck.sideboard.map((c) => c.name.toLowerCase()),
  };

  final List<DeckComboStatus> results = [];
  for (final combo in combos) {
    final inDeck = <String>[];
    final missing = <String>[];

    for (final cardName in combo.cardNames) {
      if (deckCardNames.contains(cardName.toLowerCase())) {
        inDeck.add(cardName);
      } else {
        missing.add(cardName);
      }
    }

    final completeness = missing.isEmpty
        ? ComboCompleteness.complete
        : inDeck.isNotEmpty
            ? ComboCompleteness.partial
            : ComboCompleteness.none;

    results.add(DeckComboStatus(
      combo: combo,
      cardsInDeck: inDeck,
      cardsMissing: missing,
      completeness: completeness,
    ));
  }

  // Trier : complete en premier, puis partial, puis none ; au sein de chaque groupe, par deckCount decroissant
  results.sort((a, b) {
    final orderA = a.completeness.index;
    final orderB = b.completeness.index;
    if (orderA != orderB) return orderA.compareTo(orderB);
    return b.combo.deckCount.compareTo(a.combo.deckCount);
  });

  return results;
}
```

### 3.5 Refactoring de DeckSuggestionsTab

Le widget `DeckSuggestionsTab` est refactorise pour :

1. **Utiliser les nouvelles donnees enrichies** : `EdhrecCardSuggestion` au lieu de `String`
2. **Afficher le score de synergie** : badge colore par carte
3. **Afficher le taux d'inclusion** : texte secondaire
4. **Ajouter la section themes** : chips cliquables en haut
5. **Ajouter le score global** : bandeau en haut de la page

```
lib/widgets/decks/deck_suggestions_tab.dart -- REFACTORE (~400 lignes)
```

#### Structure du widget refactorise

```dart
class _DeckSuggestionsTabState extends ConsumerState<DeckSuggestionsTab> {
  EdhrecCommanderData? _commanderData;
  List<EdhrecCardSuggestion>? _themeCards; // Cartes du theme selectionne
  String? _selectedTheme;
  DeckSynergyReport? _synergyReport;
  bool _isLoading = false;
  bool _hasLoaded = false;

  // Methode enrichie : charge EdhrecCommanderData au lieu de Map<String, List<String>>
  Future<void> _loadSuggestions() async { ... }

  // Charge les cartes d'un theme specifique
  Future<void> _loadThemeCards(EdhrecTheme theme) async { ... }

  // Revient aux suggestions generales
  void _clearTheme() { ... }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Bandeau score global
      if (_synergyReport != null) _buildSynergyBanner(),
      // Chips themes
      if (_commanderData?.themes.isNotEmpty == true) _buildThemeChips(),
      // Liste de suggestions (enrichies)
      Expanded(child: _buildSuggestionsList()),
    ]);
  }

  Widget _buildSynergyBanner() {
    // Affiche "Synergie : 72/100" avec jauge coloree
  }

  Widget _buildThemeChips() {
    // Chips horizontaux scrollables pour chaque theme
    // Chip active = theme selectionne
  }

  Widget _buildSuggestionsList() {
    // Liste des suggestions avec score de synergie et inclusion
  }

  Widget _buildEnrichedSuggestionTile(EdhrecCardSuggestion suggestion, ScryfallCard? localCard) {
    // Tile enrichie avec :
    // - Score de synergie (badge vert/rouge)
    // - Taux d'inclusion
    // - Categorie (Pick specifique / Staple generique)
    // - Image, mana cost, prix (comme avant)
  }
}
```

### 3.6 Nouveau Widget : DeckCombosSection

```
lib/widgets/decks/deck_combos_section.dart (~250 lignes)
```

Widget affichant les combos detectes dans le deck et les combos populaires :

```dart
class DeckCombosSection extends ConsumerStatefulWidget {
  final Deck deck;
  const DeckCombosSection({super.key, required this.deck});
  // ...
}

class _DeckCombosSectionState extends ConsumerState<DeckCombosSection> {
  List<DeckComboStatus> _comboStatuses = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  Future<void> _loadCombos() async {
    // 1. Recuperer le nom du commandant
    // 2. Appeler edhrecService.getCommanderCombos()
    // 3. Appeler deckDetailController.detectCombos()
    // 4. Mettre a jour l'etat
  }

  @override
  Widget build(BuildContext context) {
    // Bouton "Analyser les combos" si pas encore charge
    // Liste triee : complets > partiels > populaires
    // Chaque combo : cartes, resultat, badges presentes/manquantes
  }

  Widget _buildComboCard(DeckComboStatus status) {
    // Card avec :
    // - Titre du combo + badge (Dans votre deck / 1 carte manquante / Populaire)
    // - Cartes listees avec icone check/cross
    // - Resultats (effets du combo)
    // - Stats : X decks, Y% utilisation
  }
}
```

### 3.7 Integration dans DeckDetailPage

L'onglet existant "Suggestions" est enrichi pour inclure les themes + synergie. Un nouvel onglet ou une sous-section "Combos" est ajoutee.

**Option choisie** : Integrer les combos dans l'onglet Suggestions comme une section supplementaire, plutot qu'un 8eme onglet. Raison : le TabController a deja 7 onglets, ajouter un 8eme compliquerait l'UX mobile. Les combos sont thematiquement lies aux suggestions.

#### Modification `DeckDetailPage`

```dart
// L'onglet Suggestions (index 5) utilise le widget refactorise DeckSuggestionsTab
// qui inclut maintenant : themes, synergie, ET combos en bas de la page
```

---

## Phase 4 : Architecture Fichiers Modifies/Crees

```
lib/
  models/
    edhrec_models.dart              NOUVEAU (~200 lignes) -- modeles EDHREC enrichis

  services/
    edhrec_service.dart             MODIFIE (~350 lignes, etait 96) -- 3 nouvelles methodes + cache

  controllers/
    deck_detail_controller.dart     MODIFIE (~750 lignes, etait 668) -- synergie + combos

  widgets/
    decks/
      deck_suggestions_tab.dart     REFACTORE (~450 lignes, etait 287) -- themes + synergy
      deck_combos_section.dart      NOUVEAU (~250 lignes) -- section combos

  pages/
    decks/
      deck_detail_page.dart         MODIFIE (mineur) -- integration combos dans Suggestions

test/
  models/
    edhrec_models_test.dart         NOUVEAU (~25 tests)
  services/
    edhrec_service_test.dart        NOUVEAU (~20 tests)
  controllers/
    deck_detail_controller_test.dart  MODIFIE (~10 tests supplementaires)
```

---

## Phase 5 : Risques Techniques & Strategie de Test

### Risques

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| API EDHREC change de structure JSON | Haut | Moyenne | Parsing tolerant (null-safe), cache, fallback vers suggestions de base |
| Endpoint combos retourne trop de combos (3000+) | Moyen | Haute | Limiter a 50, tri par popularite, pagination lazy |
| Certains commandants n'ont pas de themes | Faible | Faible | Section themes cachee si vide, suggestions generales toujours disponibles |
| Resolution noms EDHREC <-> deck echoue (noms differents) | Moyen | Moyenne | Comparaison case-insensitive, split double-face |
| Performance : 3 appels API (commander + combos + theme) | Moyen | Faible | Cache 1h, lazy loading themes, pas d'appel automatique |
| Rate limit EDHREC (pas documente) | Haut | Faible | 5 req/sec max, delay entre appels, cache agressif |

### Strategie de Test

**Nouveaux tests Sprint 11** :

| Fichier test | Tests prevus | Type |
|-------------|-------------|------|
| edhrec_models_test.dart | 15 (fromJson, categoryLabel, empty, edge cases) | Unit |
| edhrec_service_test.dart | 12 (getCommanderData, getThemeCards, getCombos, cache, errors) | Unit (mock Dio) |
| deck_detail_controller_test.dart | 8 (synergyReport, detectCombos, edge cases) | Unit |
| deck_suggestions_tab_test.dart | 5 (themes, synergy display, combo display) | Widget |
| **Total nouveaux** | **~40** | |
| **Total cumule** | **~408** | **(368 + 40)** |

---

## Plan d'Execution

### Phase 1 : Modeles EDHREC (1j)

| # | Tache | Effort |
|---|-------|--------|
| 1 | Creer `lib/models/edhrec_models.dart` avec toutes les classes | 0.5j |
| 2 | Tests edhrec_models_test.dart (15 tests) | 0.5j |
| **Checkpoint** | `flutter test` >= 383 PASS, modeles compiles | |

### Phase 2 : Enrichissement EdhrecService (2j)

| # | Tache | Effort |
|---|-------|--------|
| 3 | Ajouter `getCommanderData()` avec parsing enrichi | 0.5j |
| 4 | Ajouter `getThemeCards()` avec cache | 0.25j |
| 5 | Ajouter `getCommanderCombos()` avec cache et limit 50 | 0.25j |
| 6 | Ajouter le systeme de cache `_CacheEntry` | 0.25j |
| 7 | Tests edhrec_service_test.dart (12 tests avec mock Dio) | 0.75j |
| **Checkpoint** | `flutter test` >= 395 PASS, service enrichi fonctionnel | |

### Phase 3 : Score de Synergie (2j)

| # | Tache | Effort |
|---|-------|--------|
| 8 | Ajouter `generateSynergyReport()` dans DeckDetailController | 0.25j |
| 9 | Refactorer `DeckSuggestionsTab` pour afficher synergy scores | 0.75j |
| 10 | Ajouter bandeau score global | 0.25j |
| 11 | Ajouter section themes (chips + lazy loading) | 0.5j |
| 12 | Tests synergie (5 tests controller + 3 tests widget) | 0.25j |
| **Checkpoint** | `flutter test` >= 403 PASS, scores affiches | |

### Phase 4 : Detection de Combos (2j)

| # | Tache | Effort |
|---|-------|--------|
| 13 | Ajouter `detectCombos()` dans DeckDetailController | 0.25j |
| 14 | Creer `DeckCombosSection` widget | 0.75j |
| 15 | Integrer combos dans DeckSuggestionsTab (section en bas) | 0.25j |
| 16 | Tests combos (5 tests controller + 2 tests widget) | 0.75j |
| **Checkpoint** | `flutter test` >= 410 PASS, combos detectes et affiches | |

### Phase 5 : Integration & Validation Finale (1j)

| # | Tache | Effort |
|---|-------|--------|
| 17 | Test regression complet (`flutter test`) | 0.25j |
| 18 | `flutter analyze` : 0 errors | 0.15j |
| 19 | Test manuel E2E : suggestions -> theme -> synergie -> combos | 0.35j |
| 20 | Mise a jour ROADMAP_MUGIWARA.md | 0.25j |

### Graphe de Dependances

```
Phase 1 (1j) ──> Phase 2 (2j) ──> Phase 3 (2j)
[Modeles]         [Service]         [Synergie + Themes]
                      │                    │
                      └──> Phase 4 (2j) ──> Phase 5 (1j) [Integration]
                           [Combos]
```

**Chemin critique** : Phase 1 -> Phase 2 -> Phase 3 -> Phase 5 = **6j**
**Parallele** : Phase 4 (combos, 2j) peut commencer apres Phase 2 en parallele de Phase 3
**Total** : 8j (avec parallelisme) + 1j integration = 9j

---

## Metriques Cibles Sprint 11

| Metrique | Sprint 10 (actuel) | Cible Sprint 11 |
|----------|-------------------|-----------------|
| Tests | 368 | **>= 400** |
| Fichiers modifies | - | ~4 |
| Fichiers crees | - | 3 (modeles, widget combos, test modeles) |
| Endpoints EDHREC utilises | 1 | **3** (commander, themes, combos) |
| Themes affiches | 0 | **Tous** (filtres > 50 decks) |
| Score synergie | Non | **Oui** (par carte + global) |
| Combos detectes | Non | **Oui** (top 50 + presence deck) |
| Score qualite | 9.0/10 | **9.0/10** (pas de regression, features ajoutees) |

*"Les meilleurs plats sont ceux qui revelent les saveurs cachees. Le synergy score, c'est l'assaisonnement : il montre quelles cartes sont vraiment faites pour ce commandant. Les themes, c'est le menu : chaque archetype a sa propre carte de suggestions. Les combos, c'est le dessert : cette satisfaction quand on decouvre que deux cartes qu'on a deja font quelque chose d'extraordinaire ensemble. Apres ce sprint, l'onglet Suggestions ne sera plus une simple liste de cartes -- ce sera un chef personnel pour le deckbuilding Commander."* -- Sanji
