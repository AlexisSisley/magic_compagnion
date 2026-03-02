# Sprint 12 - Architecture Technique : Features Avancees, Refactoring & Backlog Technique
> Agent : Sanji (Architecte) | Date : 01/03/2026

---

## Phase 1 : Comprehension du Probleme & Perimetre

### Perimetre fonctionnel
- **Inclus** : Syntaxe Scryfall avancee, Power Level Commander, Salt score EDHREC, Rulings Scryfall, Recherche multilangue, Centralisation Colors/Fonts, GameSetupModalController, dependency overrides ML Kit, Bulk Data Scryfall, Catalogs Scryfall
- **Exclu** : i18n complete (ARB), chiffrement BDD, notifications push Firebase, social features

### Stack existante (inchangee)
- **Langage** : Dart 3.9+ / Flutter 3.35.6
- **State Management** : Riverpod (StateNotifier + AutoDispose)
- **Base de donnees** : drift (SQLite)
- **Navigation** : go_router
- **HTTP** : Dio + cache memoire + rate limiting
- **CI/CD** : GitHub Actions
- **Tests** : 433 tests, flutter_test

### NFR
- 0 regression fonctionnelle
- 433 tests verts en permanence
- Chargement Rulings < 1s
- Power level calcule < 100ms (calcul local)
- Syntaxe Scryfall detectable en < 10ms
- Bulk Data download en background sans bloquer l'UI

### Projet existant
**PROJECT_PATH** = `C:/Users/Alexi/Documents/projet/magic_compagnion/`

---

## Phase 2 : Choix Techniques

| Choix | Decision | Justification |
|-------|----------|---------------|
| Syntaxe Scryfall | Detection par regex dans CardSearchController, passthrough a l'API | Simple, fiable, pas besoin de parser la syntaxe cote client |
| Power Level | Heuristique locale dans DeckDetailController a partir des donnees EDHREC + deck | Calcul deterministe, pas d'appel API supplementaire |
| Salt Score | Ajouter champ `salt` dans EdhrecCardSuggestion.fromJson | Le champ existe deja dans la reponse EDHREC |
| Rulings | Charger via ScryfallApiService.getCardRulings, afficher dans CardDetailPage | Service existe, modele existe, juste du cablage |
| Multilangue | Ajouter selecteur de langue dans SearchFilters, passer a searchCards(lang:) | Le parametre existe deja dans le service |
| Colors centralisation | Creer lib/theme/app_colors.dart + script de remplacement progressif | Approche fichier par fichier pour limiter le risque |
| Fonts centralisation | Creer lib/theme/app_text_styles.dart | Meme approche que Colors |
| GameSetupModal | Extraire vers GameSetupModalController (StateNotifier) | Pattern identique aux 6 controllers Sprint 7 |
| ML Kit | Tester les dernieres versions compatibles, supprimer dependency_overrides | Resoudre les conflits de versions |
| Bulk Data | Service de telechargement en background avec Dio + stockage fichier local | Reutiliser Dio existant |
| Catalogs | Charger au demarrage + cache drift persistent | Les catalogs changent rarement |

---

## Phase 3 : Architecture des Changements

### 3.1 US-12.1 : Syntaxe de Recherche Avancee Scryfall

#### Modification de `CardSearchController`

```dart
// Ajout dans card_search_controller.dart

/// Detecte si la query utilise la syntaxe avancee Scryfall.
static bool isAdvancedScryfallSyntax(String query) {
  // Operateurs Scryfall connus
  final advancedPattern = RegExp(
    r'(^|\s)(c:|cmc[<>=]|t:|o:|is:|set:|r:|e:|pow[<>=]|tou[<>=]|'
    r'id:|mv[<>=]|mana:|f:|banned:|restricted:|'
    r'year[<>=]|usd[<>=]|eur[<>=]|new:|name:|oracle:)',
    caseSensitive: false,
  );
  return advancedPattern.hasMatch(query);
}

/// Recherche API avec support syntaxe avancee.
Future<void> searchApi(String query) async {
  // Si syntaxe avancee detectee, envoyer tel quel
  // Sinon, comportement existant (recherche par nom)
  final isAdvanced = isAdvancedScryfallSyntax(query);
  final apiQuery = isAdvanced ? query : 'name:$query';
  // ... appel API existant avec apiQuery ...
}
```

#### Nouveau widget : `ScryfallSyntaxHelp`

```
lib/widgets/search/scryfall_syntax_help.dart (~120 lignes)
```

Widget modal affichant l'aide syntaxique avec exemples et operateurs.

### 3.2 US-12.2 : Deck Power Level

#### Nouveau modele : `DeckPowerLevel`

```dart
// Ajout dans lib/models/edhrec_models.dart ou nouveau fichier

class DeckPowerLevel {
  final int score;           // 1-10
  final String label;        // "Casual", "Focused", "Optimized", "High Power", "cEDH"
  final Map<String, double> factors; // Facteurs contributifs

  const DeckPowerLevel({
    required this.score,
    required this.label,
    required this.factors,
  });

  static String labelForScore(int score) {
    if (score <= 3) return 'Casual';
    if (score <= 5) return 'Focused';
    if (score <= 7) return 'Optimized';
    if (score <= 9) return 'High Power';
    return 'cEDH';
  }
}
```

#### Logique dans `DeckDetailController`

```dart
/// Estime le power level d'un deck Commander.
DeckPowerLevel? estimatePowerLevel(EdhrecCommanderData? edhrecData) {
  if (state.currentDeck.commanderScryfallId == null) return null;

  final deck = state.currentDeck;
  final allCards = [...deck.mainboard, ...deck.sideboard];
  final fullCards = state.fullCardData;

  // Facteur 1 : Mana Curve (CMC moyen)
  // CMC moyen < 2.0 = score 10, > 4.0 = score 1
  final avgCmc = _calculateAverageCmc(fullCards);
  final cmcScore = ((4.0 - avgCmc) / 2.0 * 10).clamp(1.0, 10.0);

  // Facteur 2 : Synergy Score (depuis Sprint 11)
  final synergyScore = edhrecData != null
    ? (generateSynergyReport(edhrecData)?.globalScore ?? 50) / 10
    : 5.0;

  // Facteur 3 : Combo Potential
  final comboCount = edhrecData != null
    ? detectCombos(edhrecData.topCombos)
        .where((c) => c.completeness != ComboCompleteness.none)
        .length
    : 0;
  final comboScore = (comboCount * 2.0).clamp(0.0, 10.0);

  // Facteur 4 : Interaction Count (removals, counters)
  final interactionScore = _calculateInteractionScore(fullCards);

  // Facteur 5 : Mana Base Quality
  final manaBaseScore = _calculateManaBaseScore(fullCards);

  // Facteur 6 : Card Quality (inclusion EDHREC)
  final cardQualityScore = edhrecData != null
    ? _calculateCardQualityScore(allCards, edhrecData)
    : 5.0;

  // Moyenne ponderee
  final weightedScore = (
    cmcScore * 0.15 +
    synergyScore * 0.15 +
    comboScore * 0.20 +
    interactionScore * 0.20 +
    manaBaseScore * 0.15 +
    cardQualityScore * 0.15
  ).clamp(1.0, 10.0);

  final roundedScore = weightedScore.round();

  return DeckPowerLevel(
    score: roundedScore,
    label: DeckPowerLevel.labelForScore(roundedScore),
    factors: {
      'Mana Curve': cmcScore,
      'Synergy': synergyScore,
      'Combo Potential': comboScore,
      'Interactions': interactionScore,
      'Mana Base': manaBaseScore,
      'Card Quality': cardQualityScore,
    },
  );
}
```

#### Nouveau widget : `DeckPowerLevelBadge`

```
lib/widgets/decks/deck_power_level_badge.dart (~150 lignes)
```

Widget affichant le power level avec jauge, couleur et facteurs cliquables.

### 3.3 US-12.3 : Salt Score EDHREC

#### Enrichissement de `EdhrecCardSuggestion`

```dart
// Modification dans lib/models/edhrec_models.dart

class EdhrecCardSuggestion {
  // ... champs existants ...
  final double salt;  // NOUVEAU : salt score (0.0+)

  factory EdhrecCardSuggestion.fromJson(Map<String, dynamic> json) {
    return EdhrecCardSuggestion(
      // ... existant ...
      salt: (json['salt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
```

#### Enrichissement de `DeckSynergyReport`

```dart
class DeckSynergyReport {
  // ... champs existants ...
  final double averageSalt;  // NOUVEAU : salt moyen du deck

  // ... constructeur mis a jour ...
}
```

#### Modification de `DeckSuggestionsTab`

Ajouter un badge salt (icone sel + valeur) a cote de chaque carte dans les suggestions.

### 3.4 US-12.4 : Rulings Scryfall

#### Enrichissement de `CardDetailController`

```dart
// Ajout dans card_detail_controller.dart

/// Charge les rulings d'une carte.
Future<void> loadRulings(String scryfallId) async {
  try {
    final response = await _scryfallApiService.getCardRulings(scryfallId);
    final rulingsList = response['data'] as List<dynamic>? ?? [];
    final rulings = rulingsList
      .map((r) => ScryfallRuling(
        date: r['published_at'] ?? '',
        comment: r['comment'] ?? '',
      ))
      .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Plus recent en premier

    state = state.copyWith(rulings: rulings);
  } catch (e) {
    log('Error loading rulings: $e', name: 'CardDetailController');
  }
}
```

#### Nouveau widget : `RulingsSection`

```
lib/widgets/cards/rulings_section.dart (~100 lignes)
```

Section collapsable dans `CardDetailPage` qui charge les rulings en lazy loading.

### 3.5 US-12.5 : Recherche Multilangue

#### Modification de `SearchFilters`

```dart
// Ajout dans lib/models/search_filters.dart

class SearchFilters {
  // ... champs existants ...
  final String? searchLanguage;  // NOUVEAU : null = anglais par defaut

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'fr', 'name': 'Francais'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'es', 'name': 'Espanol'},
    {'code': 'it', 'name': 'Italiano'},
    {'code': 'pt', 'name': 'Portugues'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'ko', 'name': 'Korean'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'zhs', 'name': 'Simplified Chinese'},
    {'code': 'zht', 'name': 'Traditional Chinese'},
  ];
}
```

#### Modification de `CardSearchController`

Passer `lang: state.activeFilters.searchLanguage` a `searchCards()`.

#### Modification de `SearchFilterModal`

Ajouter un dropdown de selection de langue dans le modal de filtres.

### 3.6 US-12.6 : Centralisation Colors et GoogleFonts

#### Nouveaux fichiers theme

```
lib/theme/app_colors.dart (~200 lignes)
lib/theme/app_text_styles.dart (~100 lignes)
```

```dart
// lib/theme/app_colors.dart

import 'package:flutter/material.dart';

/// Couleurs centralisees de Magic Companion.
/// Remplace les 1625 occurrences de Colors.xxx et Color(0x...) hardcodes.
abstract final class AppColors {
  // Backgrounds
  static const Color scaffoldBackground = Color(0xFF1A1A2E);
  static const Color cardBackground = Color(0xFF16213E);
  static const Color surfaceLight = Color(0xFF0F3460);
  static const Color dialogBackground = Color(0xFF1A1A2E);

  // Primary
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color accent = Color(0xFFE94560);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;
  static const Color textOnPrimary = Colors.white;

  // MTG Mana Colors
  static const Color manaWhite = Color(0xFFF9FAF4);
  static const Color manaBlue = Color(0xFF0E68AB);
  static const Color manaBlack = Color(0xFF150B00);
  static const Color manaRed = Color(0xFFD3202A);
  static const Color manaGreen = Color(0xFF00733E);
  static const Color manaColorless = Color(0xFFC0C0C0);

  // Rarity
  static const Color rarityCommon = Colors.white;
  static const Color rarityUncommon = Color(0xFFC0C0C0);
  static const Color rarityRare = Color(0xFFFFD700);
  static const Color rarityMythic = Color(0xFFFF6B35);

  // Status
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  static const Color info = Colors.blue;

  // Synergy / Salt (Sprint 11-12)
  static const Color synergyPositive = Colors.green;
  static const Color synergyNegative = Colors.red;
  static const Color synergyNeutral = Colors.grey;
  static const Color saltHigh = Colors.red;
  static const Color saltLow = Colors.green;

  // Power Level
  static const Color powerCasual = Colors.green;
  static const Color powerFocused = Colors.teal;
  static const Color powerOptimized = Colors.orange;
  static const Color powerHigh = Colors.deepOrange;
  static const Color powerCEDH = Colors.red;
}
```

```dart
// lib/theme/app_text_styles.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Styles texte centralises de Magic Companion.
/// Remplace les 325 occurrences de GoogleFonts.cinzel() hardcodes.
abstract final class AppTextStyles {
  // Titres principaux (Cinzel)
  static TextStyle pageTitle({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 24,
      fontWeight: FontWeight.bold,
    );

  static TextStyle sectionTitle({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 18,
      fontWeight: FontWeight.bold,
    );

  static TextStyle cardTitle({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 16,
      fontWeight: FontWeight.w600,
    );

  static TextStyle subtitle({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textSecondary,
      fontSize: fontSize ?? 14,
    );

  static TextStyle label({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 12,
    );

  static TextStyle buttonText({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textOnPrimary,
      fontSize: fontSize ?? 14,
      fontWeight: FontWeight.bold,
    );
}
```

#### Strategie de migration

La migration se fera par lots de fichiers :
1. Pages (19 fichiers)
2. Widgets (30+ fichiers)
3. Controllers (6 fichiers)
4. Autres (router, main, etc.)

### 3.7 US-12.7 : GameSetupModalController

#### Extraction du controller

```
lib/controllers/game_setup_modal_controller.dart (~200 lignes)
```

```dart
class GameSetupModalState {
  final int startingLife;
  final int playerCount;
  final List<Profile?> profiles;
  final List<ScryfallCard?> commanderArts;
  final bool isCustomLife;
  // ... autres champs extraits du widget

  const GameSetupModalState({...});
  GameSetupModalState copyWith({...}) => ...;
}

class GameSetupModalController extends StateNotifier<GameSetupModalState> {
  final ProfileService _profileService;

  GameSetupModalController(this._profileService) : super(const GameSetupModalState(...));

  void setPlayerCount(int count) { ... }
  void setStartingLife(int life) { ... }
  void selectProfile(int index, Profile profile) { ... }
  void removeProfile(int index) { ... }
  Future<void> loadProfiles() { ... }
  // ... autres methodes extraites
}
```

### 3.8 US-12.9 : Mise a jour Bulk Data

#### Nouveau service : `BulkDataService`

```
lib/services/bulk_data_service.dart (~150 lignes)
```

```dart
class BulkDataService {
  final Dio _dio;

  /// Verifie si une mise a jour est disponible.
  Future<bool> isUpdateAvailable() async {
    // GET https://api.scryfall.com/bulk-data/oracle-cards
    // Comparer updated_at avec la date locale
  }

  /// Telecharge le fichier oracle-cards.json en background.
  Future<void> downloadOracleCards({
    void Function(int received, int total)? onProgress,
  }) async {
    // 1. Obtenir l'URL de telechargement via l'API Bulk Data
    // 2. Telecharger en streaming vers un fichier temporaire
    // 3. Verifier l'integrite (taille > 0)
    // 4. Remplacer l'ancien fichier
    // 5. Recharger LocalCardService
  }
}
```

### 3.9 US-12.10 : Catalogs Scryfall

#### Enrichissement de `ScryfallApiService`

```dart
// Ajout dans scryfall_api_service.dart

/// Charge un catalog Scryfall (types de creature, noms de planeswalker, etc.).
Future<List<String>> getCatalog(String catalogName) async {
  final response = await _get('/catalog/$catalogName', cacheTtl: longCacheTtl);
  return (response['data'] as List<dynamic>?)
      ?.map((e) => e.toString())
      .toList() ?? [];
}
```

Catalogs utiles : `creature-types`, `planeswalker-types`, `land-types`, `artifact-types`, `enchantment-types`, `spell-types`, `powers`, `toughnesses`, `loyalties`, `keyword-abilities`, `keyword-actions`.

---

## Phase 4 : Architecture Fichiers Modifies/Crees

```
lib/
  theme/
    app_colors.dart                         NOUVEAU (~200 lignes)
    app_text_styles.dart                    NOUVEAU (~100 lignes)

  models/
    edhrec_models.dart                      MODIFIE (+salt, +DeckPowerLevel)
    search_filters.dart                     MODIFIE (+searchLanguage)
    scryfall_ruling.dart                    INCHANGE (existe deja)

  services/
    edhrec_service.dart                     INCHANGE (Sprint 11 suffit)
    scryfall_api_service.dart               MODIFIE (+getCatalog)
    bulk_data_service.dart                  NOUVEAU (~150 lignes)

  controllers/
    card_search_controller.dart             MODIFIE (+syntaxe avancee, +multilangue)
    card_detail_controller.dart             MODIFIE (+loadRulings)
    deck_detail_controller.dart             MODIFIE (+estimatePowerLevel, +salt dans synergyReport)
    game_setup_modal_controller.dart        NOUVEAU (~200 lignes)

  widgets/
    search/
      scryfall_syntax_help.dart             NOUVEAU (~120 lignes)
    cards/
      rulings_section.dart                  NOUVEAU (~100 lignes)
    decks/
      deck_power_level_badge.dart           NOUVEAU (~150 lignes)
      deck_suggestions_tab.dart             MODIFIE (+salt badges)

  pages/
    cards/
      card_detail_page.dart                 MODIFIE (+rulings section)
      card_search_page.dart                 MODIFIE (+syntaxe help button)

    life_counter/
      game_setup_modal.dart -> REFACTORE (utilise GameSetupModalController)

  + ~58 fichiers MODIFIES pour Colors -> AppColors
  + ~52 fichiers MODIFIES pour GoogleFonts.cinzel -> AppTextStyles

test/
  models/
    edhrec_models_test.dart                 MODIFIE (+salt tests, +power level tests)
  controllers/
    card_search_controller_test.dart        MODIFIE (+syntaxe tests)
    card_detail_controller_test.dart        MODIFIE (+rulings tests)
    deck_detail_controller_test.dart        MODIFIE (+power level tests)
    game_setup_modal_controller_test.dart   NOUVEAU (~20 tests)
  services/
    bulk_data_service_test.dart             NOUVEAU (~10 tests)
  widgets/
    scryfall_syntax_help_test.dart          NOUVEAU (~5 tests)
    rulings_section_test.dart               NOUVEAU (~5 tests)
```

---

## Phase 5 : Risques Techniques & Strategie de Test

### Risques

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| Regression visuelle lors centralisation Colors (1625 occ.) | Haut | Haute | Migration par lots, review visuelle apres chaque lot |
| Power level mal calibre | Moyen | Moyenne | Seuils ajustables, facteurs ponderes, feedback utilisateur |
| Bulk Data trop volumineux en memoire | Haut | Moyenne | Streaming download, pas de chargement en memoire |
| Syntaxe Scryfall edge cases | Moyen | Moyenne | Passthrough direct, gestion erreurs API |
| ML Kit versions incompatibles | Haut | Moyenne | Tester isolement, branch separee |
| Salt score absent pour certaines cartes EDHREC | Faible | Faible | Default 0.0 |

### Strategie de Test

**Nouveaux tests Sprint 12** :

| Fichier test | Tests prevus | Type |
|-------------|-------------|------|
| card_search_controller_test.dart | +10 (syntaxe avancee, multilangue) | Unit |
| deck_detail_controller_test.dart | +12 (power level, salt report) | Unit |
| card_detail_controller_test.dart | +5 (rulings) | Unit |
| edhrec_models_test.dart | +5 (salt, power level) | Unit |
| game_setup_modal_controller_test.dart | 20 (nouveau) | Unit |
| bulk_data_service_test.dart | 10 (nouveau) | Unit |
| scryfall_syntax_help_test.dart | 5 (nouveau) | Widget |
| rulings_section_test.dart | 5 (nouveau) | Widget |
| **Total nouveaux** | **~72** | |
| **Total cumule** | **~505** | **(433 + 72)** |

---

## Plan d'Execution

### Phase 1 : Salt Score + Rulings (5j) -- Quick Wins

| # | Tache | Effort | US |
|---|-------|--------|----|
| 1 | Ajouter champ `salt` dans EdhrecCardSuggestion + tests | 0.5j | 12.3 |
| 2 | Ajouter `averageSalt` dans DeckSynergyReport | 0.5j | 12.3 |
| 3 | Badge salt dans DeckSuggestionsTab | 0.5j | 12.3 |
| 4 | Tests salt (5 tests) | 0.5j | 12.3 |
| 5 | Ajouter `loadRulings()` dans CardDetailController | 0.5j | 12.4 |
| 6 | Creer RulingsSection widget | 0.5j | 12.4 |
| 7 | Integrer dans CardDetailPage (lazy loading) | 0.5j | 12.4 |
| 8 | Tests rulings (5 tests controller + 5 tests widget) | 1.5j | 12.4 |
| **Checkpoint** | `flutter test` >= 448 PASS, salt + rulings fonctionnels | |

### Phase 2 : Syntaxe Scryfall + Multilangue (6j)

| # | Tache | Effort | US |
|---|-------|--------|----|
| 9 | Ajouter `isAdvancedScryfallSyntax()` dans CardSearchController | 0.5j | 12.1 |
| 10 | Modifier la logique de recherche API pour passthrough syntaxe | 0.5j | 12.1 |
| 11 | Creer ScryfallSyntaxHelp widget | 0.5j | 12.1 |
| 12 | Ajouter bouton aide dans CardSearchPage | 0.25j | 12.1 |
| 13 | Gestion erreur syntaxe invalide | 0.25j | 12.1 |
| 14 | Tests syntaxe (10 tests) | 1j | 12.1 |
| 15 | Ajouter `searchLanguage` dans SearchFilters | 0.25j | 12.5 |
| 16 | Ajouter dropdown langue dans SearchFilterModal | 0.5j | 12.5 |
| 17 | Passer lang a CardSearchController.searchApi | 0.25j | 12.5 |
| 18 | Tests multilangue (5 tests) | 1j | 12.5 |
| 19 | Gestion fallback si 0 resultat dans une langue | 1j | 12.5 |
| **Checkpoint** | `flutter test` >= 463 PASS, syntaxe + multilangue fonctionnels | |

### Phase 3 : Power Level (5j) -- Feature Differenciante

| # | Tache | Effort | US |
|---|-------|--------|----|
| 20 | Creer DeckPowerLevel modele | 0.25j | 12.2 |
| 21 | Implementer `estimatePowerLevel()` dans DeckDetailController | 1.5j | 12.2 |
| 22 | Creer helpers : _calculateAverageCmc, _calculateInteractionScore, _calculateManaBaseScore, _calculateCardQualityScore | 1j | 12.2 |
| 23 | Creer DeckPowerLevelBadge widget | 0.75j | 12.2 |
| 24 | Integrer dans DeckDetailPage (onglet Stats ou bandeau) | 0.5j | 12.2 |
| 25 | Tests power level (12 tests) | 1j | 12.2 |
| **Checkpoint** | `flutter test` >= 475 PASS, power level affiche | |

### Phase 4 : Refactoring GameSetupModal + Colors/Fonts (7j)

| # | Tache | Effort | US |
|---|-------|--------|----|
| 26 | Extraire GameSetupModalController | 1j | 12.7 |
| 27 | Refactorer GameSetupModal pour utiliser le controller | 0.5j | 12.7 |
| 28 | Tests GameSetupModalController (20 tests) | 0.5j | 12.7 |
| 29 | Creer lib/theme/app_colors.dart | 0.5j | 12.6 |
| 30 | Migrer Colors -> AppColors : pages (19 fichiers) | 1.5j | 12.6 |
| 31 | Migrer Colors -> AppColors : widgets (30+ fichiers) | 1.5j | 12.6 |
| 32 | Migrer Colors -> AppColors : controllers + autres | 0.5j | 12.6 |
| 33 | Creer lib/theme/app_text_styles.dart + migrer GoogleFonts | 1j | 12.6 |
| **Checkpoint** | `flutter test` >= 495 PASS, AppColors et AppTextStyles centralises | |

### Phase 5 : Backlog Technique (9j) -- P2, reportable

| # | Tache | Effort | US |
|---|-------|--------|----|
| 34 | Resoudre dependency overrides ML Kit | 1j | 12.8 |
| 35 | Tester le scanner avec les nouvelles versions | 1j | 12.8 |
| 36 | Creer BulkDataService | 1.5j | 12.9 |
| 37 | Integrer telechargement Bulk Data dans settings | 1j | 12.9 |
| 38 | Tests BulkDataService (10 tests) | 1.5j | 12.9 |
| 39 | Ajouter getCatalog() dans ScryfallApiService | 0.5j | 12.10 |
| 40 | Integrer catalogs dans SearchFilterModal | 1.5j | 12.10 |
| 41 | Tests catalogs (5 tests) | 1j | 12.10 |
| **Checkpoint** | `flutter test` >= 505 PASS | |

### Phase 6 : Integration & Validation Finale (1j)

| # | Tache | Effort |
|---|-------|--------|
| 42 | Test regression complet (`flutter test`) | 0.25j |
| 43 | `flutter analyze` : 0 errors | 0.15j |
| 44 | Test manuel E2E complet | 0.35j |
| 45 | Mise a jour ROADMAP_MUGIWARA.md | 0.25j |

### Graphe de Dependances

```
Phase 1 (5j)  ──> Phase 2 (6j)  ──> Phase 3 (5j)  ──> Phase 6 (1j)
[Salt+Rulings]    [Syntaxe+Lang]    [Power Level]      [Integration]
                                          │
Phase 4 (7j)  ──────────────────────────┘
[GameSetup+Colors]   (parallele a Phase 2-3)

Phase 5 (9j)  ──────────────────────────────────> Phase 6
[Backlog P2]         (parallele, reportable)
```

**Chemin critique** : Phase 1 -> Phase 2 -> Phase 3 -> Phase 6 = **17j**
**Parallele** : Phase 4 (7j) et Phase 5 (9j) en parallele
**Total** : 32j avec parallelisme sur 5 semaines (33j ouvrables)

---

## Metriques Cibles Sprint 12

| Metrique | Sprint 11 (actuel) | Cible Sprint 12 |
|----------|-------------------|-----------------|
| Tests | 433 | **>= 500** |
| flutter analyze errors | 0 | **0** |
| Colors.xxx + Color(0x) directes | 1625 | **< 100** |
| GoogleFonts.cinzel directes | 325 | **< 10** |
| Fichiers > 500 lignes | 17 | **< 15** |
| Endpoints Scryfall utilises | 5 | **7** (+rulings, +catalogs) |
| Power level automatique | Non | **Oui** |
| Salt score | Non | **Oui** |
| Syntaxe recherche avancee | Non | **Oui** |
| Recherche multilangue | Non | **Oui (11 langues)** |
| Score qualite | 9.0/10 | **9.5/10** |

*"Les meilleurs plats sont ceux qui s'ameliorent avec le temps. Le Sprint 12 est un plat de resistance : la syntaxe Scryfall donne le controle total au joueur avance, le power level transforme un ressenti subjectif en mesure objective, le salt score ajoute une dimension sociale au deckbuilding. Et en cuisine, le nettoyage (Colors, Fonts, GameSetup) est aussi important que le service. Apres ce sprint, l'app est prete pour le service a table -- belle, fonctionnelle, maintenable."* -- Sanji
