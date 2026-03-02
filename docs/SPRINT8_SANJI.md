# Sprint 8 - Architecture Technique : Widgets, Qualite & Polish
> Agent : Sanji (Architecte) | Date : 28/02/2026

---

## Phase 1 : Comprehension du Probleme & Perimetre

### Perimetre fonctionnel
- **Inclus** : Extraction controllers widgets, extraction sous-widgets pages, refactoring routeur, resolution 1041 infos flutter analyze, centralisation theme
- **Exclu** : i18n, chiffrement BDD, nouvelles fonctionnalites, changement de stack

### Stack existante (inchangee)
- **Langage** : Dart 3.9+ / Flutter
- **State Management** : Riverpod (StateNotifier)
- **Base de donnees** : drift (SQLite)
- **Navigation** : go_router (23 routes)
- **HTTP** : Dio + cache + rate limiting (ScryfallApiService)
- **CI/CD** : GitHub Actions
- **Tests** : 273 tests, flutter_test

### NFR
- 0 regression fonctionnelle
- 273 tests verts en permanence
- flutter analyze : 0 issues (objectif final)
- Performances inchangees

### Projet existant
**PROJECT_PATH** = `C:/Users/Alexi/Documents/projet/magic_compagnion/`

Ce sprint ne cree PAS de nouveau projet. Il refactore le projet existant.

---

## Phase 2 : Choix Technique (Pas de changement de stack)

Le Sprint 8 est un sprint de refactoring pur. La stack Flutter/Riverpod/drift/go_router est conservee. Aucun nouveau package n'est necessaire.

**Choix techniques pour les patterns de refactoring :**

| Choix | Decision | Justification |
|-------|----------|---------------|
| Pattern controllers widgets | StateNotifier + AutoDispose | Coherent avec les 6 controllers existants du Sprint 7 |
| Extraction sous-widgets | StatelessWidget classes privees dans des fichiers separes | Flutter standard, permet le hot reload et la reutilisation |
| Sous-routeurs | Fonctions `List<RouteBase>` dans des fichiers separes | go_router recommande, simple, pas de nouvelle abstraction |
| Remplacement withOpacity | `.withValues(alpha: x)` | API officielle Flutter 3.27+, x = valeur 0.0-1.0 |
| Quotes | `dart format` + script automatique | Pas de modification manuelle |

---

## Phase 3 : Architecture des Changements

### 3.1 Nouveaux Controllers Widgets (US-8.2)

Chaque controller suit le meme pattern que le Sprint 7 :

```dart
// Pattern StateNotifier pour widgets
class XxxState {
  final List<Data> items;
  final bool isLoading;
  final String? error;
  // ... champs specifiques

  XxxState copyWith({...});
}

class XxxController extends StateNotifier<XxxState> {
  final Ref _ref;

  XxxController(this._ref) : super(XxxState.initial());

  // Methodes de logique metier
  Future<void> load() async { ... }
  void filter(SearchFilters filters) { ... }
  void sort(String sortBy) { ... }
}

final xxxControllerProvider = StateNotifierProvider.autoDispose<XxxController, XxxState>((ref) {
  return XxxController(ref);
});
```

#### DeckCardPickerController (extrait de deck_card_picker.dart -- 774 lignes)

**Logique a extraire** :
- Recherche API Scryfall (debounce, pagination, `_loadMoreApiResults`)
- Recherche locale collection (filtrage, pagination, `_loadMoreLocalResults`)
- Gestion du panier de selection (`_selectedQuantities`, `_cardCache`)
- Filtres et tri (API + collection)

**State** :
```dart
class DeckCardPickerState {
  final List<ScryfallCard> apiResults;
  final List<DeckCard> displayedCollection;
  final Map<String, int> selectedQuantities;
  final Map<String, ScryfallCard> cardCache;
  final bool isSearching;
  final bool isApiLoadingMore;
  final String? nextApiPageUrl;
  final int totalApiResults;
  final SearchFilters apiFilters;
  final SearchFilters collectionFilters;
  final String apiSort;
  final String collectionSort;
}
```

**Resultat** : widget deck_card_picker.dart passe de 774 a ~350 lignes (UI pure).

#### CollectionListController (extrait de collection_list_tab.dart -- 716 lignes)

**Logique a extraire** :
- Filtrage (query, type, couleurs, set, keyword)
- Tri (nom, prix, quantite, date)
- Actions contextuelles (copier URL, ouvrir lien externe)
- Mode selection (toggle, select all, deselect all)

**Note** : Ce widget recoit deja ses donnees via props (`cards`, `fullCardData`, `filterQuery`, etc.). Le controller va encapsuler la logique de filtrage/tri locale qui est actuellement dans le State du widget.

**State** :
```dart
class CollectionListState {
  final List<DeckCard> filteredCards;
  final List<DeckCard> displayedCards;
  final String sortBy;
  final bool isAscending;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final int pageSize;
  final int displayedCount;
}
```

**Resultat** : widget collection_list_tab.dart passe de 716 a ~350 lignes (UI pure).

#### PlayerZoneController (extrait de player_zone.dart -- 674 lignes)

**Logique a extraire** :
- Gestion des compteurs (vie, poison, energie, commander tax) avec `_triggerChange`
- Mode d'edition (switch entre compteurs, auto-return timer 5s)
- Floating numbers animation data (creation, lifecycle)
- Selection de skin/artwork (recherche carte, image picker)
- Gestion de la rotation et des gestes

**State** :
```dart
class PlayerZoneState {
  final CounterMode editMode;
  final List<FloatingNumber> floatingNumbers;
  final bool isMenuOpen;
}
```

**Note** : La majeure partie de la logique est deja geree via callbacks (`onLifeChanged`, `onStatChanged`, `onColorChanged`). Le controller encapsulera principalement la gestion du mode d'edition, des floating numbers et du menu de personnalisation.

**Resultat** : widget player_zone.dart passe de 674 a ~350 lignes (UI pure).

#### DeckStatsController (extrait de deck_stats_tab.dart -- 612 lignes)

**Logique a extraire** :
- Tous les calculs statistiques :
  - `_calculateManaCurve()` (~20 lignes)
  - `_calculateCardTypes()` (~15 lignes)
  - `_calculatePipCount()` (~25 lignes)
  - `_calculateLandSources()` (~20 lignes)
  - `_calculateColorByType()` (~40 lignes)
  - Calcul `_averageCmc` et `_totalPrice` (~20 lignes)
- Helper `_getPrimaryType()` et `_calculateTotalCards()`

**State** :
```dart
class DeckStatsState {
  final Map<int, int> manaCurveData;
  final Map<String, int> cardTypeData;
  final Map<String, int> pipCountData;
  final Map<String, int> sourceCountData;
  final Map<String, Map<String, int>> colorByTypeData;
  final double averageCmc;
  final double totalPrice;
  final int totalCards;
}
```

**Note** : Ce controller est un cas special -- c'est essentiellement une classe de calcul pure. Un `Provider.autoDispose.family` serait plus adapte qu'un StateNotifier car il n'y a pas d'etat mutable.

**Resultat** : widget deck_stats_tab.dart passe de 612 a ~350 lignes (UI/graphiques pure).

### 3.2 Extraction Sous-Widgets Pages (US-8.3)

Pour chaque page encore >500 lignes, identifier les blocs UI extractibles en sous-widgets :

#### set_detail_page.dart (1039 -> <400 lignes)

| Sous-widget a extraire | Lignes approx | Destination |
|------------------------|---------------|-------------|
| `SetDetailFilterModal` | ~150 | `lib/widgets/collections/set_detail_filter_modal.dart` |
| `WishlistPickerSheet` | ~80 | `lib/widgets/common/wishlist_picker_sheet.dart` |
| `SetCardTile` | ~80 | `lib/widgets/collections/set_card_tile.dart` |
| `SetStatsHeader` | ~50 | `lib/widgets/collections/set_stats_header.dart` |
| `SetBottomActionBar` | ~60 | `lib/widgets/collections/set_bottom_action_bar.dart` |
| `SetControlBar` | ~50 | `lib/widgets/collections/set_control_bar.dart` |
| `ThemedDialog` (reutilisable) | ~30 | `lib/widgets/common/themed_dialog.dart` |
| **Total extrait** | **~500** | **set_detail_page.dart : ~539 lignes restantes** |

Pour atteindre <400 : combiner avec l'extraction des methodes de dialog helpers inline.

#### deck_detail_page.dart (597 -> <400 lignes)

| Sous-widget | Lignes approx | Destination |
|-------------|---------------|-------------|
| `DeckShareModal` | ~50 | `lib/widgets/decks/deck_share_modal.dart` |
| `DeckZoneTabBar` | ~40 | `lib/widgets/decks/deck_zone_tab_bar.dart` |
| `DeckActionButtons` | ~50 | `lib/widgets/decks/deck_action_buttons.dart` |
| Methodes dialog inline | ~60 | Inlines -> sous-widgets |
| **Total extrait** | **~200** | **~397 lignes** |

#### card_search_page.dart (537 -> <400 lignes)

| Sous-widget | Lignes approx | Destination |
|-------------|---------------|-------------|
| `SearchResultTile` | ~60 | `lib/widgets/cards/search_result_tile.dart` |
| `SearchBar` (custom) | ~40 | `lib/widgets/cards/card_search_bar.dart` |
| `SearchPaginationInfo` | ~30 | `lib/widgets/cards/search_pagination_info.dart` |
| Methodes dialog inline | ~40 | Inlines -> sous-widgets |
| **Total extrait** | **~170** | **~367 lignes** |

#### deck_list_page.dart (539 -> <400 lignes)

| Sous-widget | Lignes approx | Destination |
|-------------|---------------|-------------|
| `DeckListTile` | ~60 | `lib/widgets/decks/deck_list_tile.dart` |
| `DeckImportDialog` | ~40 | `lib/widgets/decks/deck_import_dialog.dart` |
| `DeckCreateFAB` | ~40 | `lib/widgets/decks/deck_create_fab.dart` |
| **Total extrait** | **~140** | **~399 lignes** |

#### card_detail_page.dart (508 -> <400 lignes)

| Sous-widget | Lignes approx | Destination |
|-------------|---------------|-------------|
| `CardActionButtons` | ~50 | `lib/widgets/cards/card_action_buttons.dart` |
| `CardRulingsSection` | ~40 | `lib/widgets/cards/card_rulings_section.dart` |
| Methodes dialog inline | ~30 | Inlines -> sous-widgets |
| **Total extrait** | **~120** | **~388 lignes** |

### 3.3 Decoupage app_router.dart (US-8.4)

Structure cible :

```
lib/router/
  app_router.dart              (~150 lignes - config principale + ShellRoute)
  routes/
    life_counter_routes.dart    (~50 lignes - /, /game-history, /game-history/:id, /tournament)
    cards_routes.dart           (~40 lignes - /search, /card-detail, /recognition)
    collections_routes.dart     (~60 lignes - /collection, /set-detail, /set-stats, /global-stats)
    decks_routes.dart           (~50 lignes - /decks, /deck-detail, /deck-card-picker)
    settings_routes.dart        (~40 lignes - /settings, /profile-management)
    tools_routes.dart           (~30 lignes - /scanner, /scan-history, /glossary, /oracle, etc.)
  app_drawer.dart              (~100 lignes - le Drawer extrait)
```

Pattern pour chaque sous-routeur :
```dart
// lib/router/routes/cards_routes.dart
List<RouteBase> cardsRoutes() {
  return [
    GoRoute(
      path: AppRoutes.search,
      name: AppRoutes.search,
      builder: (context, state) => const CardSearchPage(),
    ),
    GoRoute(
      path: AppRoutes.cardDetail,
      name: AppRoutes.cardDetail,
      builder: (context, state) {
        final card = state.extra as ScryfallCard;
        return CardDetailPage(card: card);
      },
    ),
    // ...
  ];
}
```

### 3.4 Resolution flutter analyze (US-8.1)

**Ordre d'execution** (evite les conflits) :

| Etape | Regle | Methode | Effort |
|-------|-------|---------|--------|
| 1 | prefer_single_quotes (583) | `dart fix --apply` ou script sed `"` -> `'` avec exclusion des strings contenant `'` | 0.5j |
| 2 | deprecated_member_use / withOpacity (148+) | Search/replace `.withOpacity(x)` -> `.withValues(alpha: x)` | 0.5j |
| 3 | prefer_const_constructors (78) | `dart fix --apply` (gere automatiquement) | 0.25j |
| 4 | unnecessary_non_null_assertion (74) | `dart fix --apply` | 0.1j |
| 5 | curly_braces_in_flow_control (57) | `dart fix --apply` | 0.1j |
| 6 | use_build_context_synchronously (23) | Ajouter `if (!mounted) return;` avant chaque usage apres await | 0.25j |
| 7 | Divers (unnecessary_underscores, empty_catches, etc.) (76) | Corrections manuelles ponctuelles | 0.3j |

**Total : ~2j**

### 3.5 Centralisation Theme (US-8.5)

#### Structure fichiers theme :

```
lib/theme/
  app_theme.dart          (~80 lignes - ThemeData principal)
  app_text_styles.dart    (~60 lignes - TextStyles centralises via GoogleFonts)
  app_colors.dart         (~50 lignes - ColorScheme + couleurs MTG)
  mtg_colors.dart         (~40 lignes - extension ThemeData pour couleurs mana/rarete)
```

#### app_text_styles.dart
```dart
class AppTextStyles {
  static TextStyle cinzel({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) => GoogleFonts.cinzel(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  // Variantes predefinies
  static TextStyle get heading => cinzel(fontSize: 20, fontWeight: FontWeight.bold);
  static TextStyle get subheading => cinzel(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle get body => cinzel(fontSize: 14);
  static TextStyle get caption => cinzel(fontSize: 12);
  static TextStyle get button => cinzel(fontSize: 14, fontWeight: FontWeight.bold);
}
```

#### app_colors.dart
```dart
class AppColors {
  // Couleurs principales de l'app
  static const Color background = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF2A2A2A);
  static const Color accent = Color(0xFFD4AF37); // Or
  // ...

  // Couleurs MTG (mana)
  static const Color manaWhite = Color(0xFFF0F2C0);
  static const Color manaBlue = Color(0xFF4287F5);
  static const Color manaBlack = Color(0xFF333333);
  static const Color manaRed = Color(0xFFEB4034);
  static const Color manaGreen = Color(0xFF4CAF50);
  static const Color manaColorless = Color(0xFF9E9E9E);
  static const Color manaMulti = Color(0xFFD4AF37);

  static const Map<String, Color> manaColors = {
    'W': manaWhite, 'U': manaBlue, 'B': manaBlack,
    'R': manaRed, 'G': manaGreen, 'C': manaColorless, 'M': manaMulti,
  };
}
```

**Strategie de migration** : fichier par fichier, remplacer les `GoogleFonts.cinzel(...)` par `AppTextStyles.xxx` et les `Color(0xFF...)` / `Colors.xxx` par `AppColors.xxx`. Cible : reduire de >80% les appels directs.

---

## Phase 4 : Nouvelle Architecture Fichiers

```
lib/
  main.dart (76 lignes)

  theme/                        ← NOUVEAU Sprint 8
    app_theme.dart
    app_text_styles.dart
    app_colors.dart
    mtg_colors.dart

  controllers/ (10 fichiers)    ← 6 Sprint 7 + 4 NOUVEAU Sprint 8
    set_detail_controller.dart       (543 lignes - Sprint 7)
    deck_detail_controller.dart      (581 lignes - Sprint 7)
    card_search_controller.dart      (554 lignes - Sprint 7)
    card_detail_controller.dart      (522 lignes - Sprint 7)
    deck_list_controller.dart        (326 lignes - Sprint 7)
    collection_controller.dart       (398 lignes - Sprint 7)
    deck_card_picker_controller.dart (~300 lignes - Sprint 8)
    collection_list_controller.dart  (~200 lignes - Sprint 8)
    player_zone_controller.dart      (~180 lignes - Sprint 8)
    deck_stats_controller.dart       (~150 lignes - Sprint 8)

  providers/ (6 fichiers, 24+ providers)
    service_providers.dart
    + 4 nouveaux controller providers

  services/ (14 fichiers, mixin upsert)
  data/database/ (10 tables drift)

  router/                       ← MODIFIE Sprint 8
    app_router.dart             (~150 lignes au lieu de 713)
    app_drawer.dart             (~100 lignes extraites)
    routes/
      life_counter_routes.dart
      cards_routes.dart
      collections_routes.dart
      decks_routes.dart
      settings_routes.dart
      tools_routes.dart

  pages/                        ← MODIFIE Sprint 8 (toutes <400 lignes)
    collections/
      set_detail_page.dart      (1039 → <400)
      collection_page.dart      (353 - deja OK)
    cards/
      card_search_page.dart     (537 → <400)
      card_detail_page.dart     (508 → <400)
    decks/
      deck_detail_page.dart     (597 → <400)
      deck_list_page.dart       (539 → <400)

  widgets/                      ← MODIFIE Sprint 8
    collections/
      collection_list_tab.dart  (716 → <350)
      set_detail_filter_modal.dart   ← NOUVEAU
      set_card_tile.dart             ← NOUVEAU
      set_stats_header.dart          ← NOUVEAU
      set_bottom_action_bar.dart     ← NOUVEAU
      set_control_bar.dart           ← NOUVEAU
    life_counter/
      player_zone.dart          (674 → <350)
      game_setup_modal.dart     (507 - hors scope controllers)
    decks/
      deck_card_picker.dart     (774 → <350)
      deck_stats_tab.dart       (612 → <350)
      deck_list_tile.dart            ← NOUVEAU
      deck_share_modal.dart          ← NOUVEAU
      deck_action_buttons.dart       ← NOUVEAU
    cards/
      search_result_tile.dart        ← NOUVEAU
      card_action_buttons.dart       ← NOUVEAU
      card_rulings_section.dart      ← NOUVEAU
    common/
      wishlist_picker_sheet.dart     ← NOUVEAU (reutilisable)
      themed_dialog.dart             ← NOUVEAU (reutilisable)

  utils/ (1 mixin)
  models/ (10 modeles)

test/
  controllers/ (10 fichiers)    ← 4 Sprint 7 + 4 NOUVEAU Sprint 8
    deck_card_picker_controller_test.dart
    collection_list_controller_test.dart
    player_zone_controller_test.dart
    deck_stats_controller_test.dart
```

---

## Phase 5 : Risques Techniques & Strategie de Test

### Risques

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| Regression UI lors extraction sous-widgets | Haut | Moyen | Extraire un widget a la fois, test visuel |
| withValues() non disponible | Haut | Faible | Verifier `flutter --version` avant de commencer |
| Script quotes casse des strings avec apostrophes | Moyen | Faible | Utiliser `dart fix --apply` qui est context-aware |
| Conflit controller widget vs controller page | Haut | Faible | Controllers widgets dependent uniquement des services, jamais des controllers pages |
| Routeur decoupe casse la navigation Shell | Haut | Moyen | Garder le ShellRoute dans le fichier principal |

### Strategie de Test

**Nouveaux tests Sprint 8** :

| Fichier test | Tests prevus | Type |
|-------------|-------------|------|
| deck_card_picker_controller_test.dart | 8 | Unit |
| collection_list_controller_test.dart | 6 | Unit |
| player_zone_controller_test.dart | 5 | Unit |
| deck_stats_controller_test.dart | 8 | Unit |
| app_text_styles_test.dart | 3 | Unit |
| app_colors_test.dart | 2 | Unit |
| **Total nouveaux** | **~32** | |
| **Total cumule** | **~305** | **(273 + 32)** |

Cible : >300 tests, >65% couverture.

---

## Plan d'Execution

### Phase 1 : Quick Wins Analyse (US-8.1) -- 2j

| # | Tache | Effort |
|---|-------|--------|
| 1 | Verifier `flutter --version` (>= 3.27 pour withValues) | 0.1j |
| 2 | `dart fix --apply` (prefer_single_quotes, prefer_const_constructors, curly_braces, unnecessary_non_null) | 0.5j |
| 3 | Script replace .withOpacity(x) -> .withValues(alpha: x) dans lib/ et test/ | 0.5j |
| 4 | Corriger manuellement use_build_context_synchronously (23 occurrences) | 0.25j |
| 5 | Corriger divers (empty_catches, unnecessary_underscores, etc.) | 0.3j |
| 6 | Verifier flutter analyze : 0 issues | 0.1j |
| 7 | Verifier flutter test : 273 tests verts | 0.1j |

### Phase 2 : Controllers Widgets (US-8.2) -- 5j

| # | Tache | Effort |
|---|-------|--------|
| 8 | Creer DeckCardPickerController + tests | 1.5j |
| 9 | Creer CollectionListController + tests | 1j |
| 10 | Creer PlayerZoneController + tests | 1j |
| 11 | Creer DeckStatsController + tests | 1j |
| 12 | Verifier flutter test : ~297 tests verts | 0.5j |

### Phase 3 : Extraction Sous-Widgets Pages (US-8.3) -- 3j

| # | Tache | Effort |
|---|-------|--------|
| 13 | Extraire sous-widgets set_detail_page (5 widgets) | 1j |
| 14 | Extraire sous-widgets deck_detail_page + deck_list_page | 0.75j |
| 15 | Extraire sous-widgets card_search_page + card_detail_page | 0.75j |
| 16 | Verifier toutes pages <400 lignes, flutter test vert | 0.5j |

### Phase 4 : Refactoring Routeur (US-8.4) -- 1.5j

| # | Tache | Effort |
|---|-------|--------|
| 17 | Creer lib/router/routes/ et deplacer les routes par theme | 0.75j |
| 18 | Extraire le Drawer dans app_drawer.dart | 0.25j |
| 19 | Verifier toute la navigation (23 routes) + flutter test | 0.5j |

### Phase 5 : Centralisation Theme (US-8.5) -- 3.5j

| # | Tache | Effort |
|---|-------|--------|
| 20 | Creer lib/theme/ (app_theme, app_text_styles, app_colors, mtg_colors) | 0.5j |
| 21 | Migrer GoogleFonts.cinzel -> AppTextStyles (333 occurrences, ~40 fichiers) | 1.5j |
| 22 | Migrer Color()/Colors. hardcodes -> AppColors (top 50 couleurs les plus utilisees) | 1j |
| 23 | Tests + verification visuelle | 0.5j |

---

## Metriques Cibles Sprint 8

| Metrique | Sprint 7 | Cible Sprint 8 |
|----------|----------|-----------------|
| Tests | 273 | >300 |
| Couverture | ~55% | >65% |
| flutter analyze issues | 1041 | **0** |
| Fichiers pages >500 lignes | 5 | **0** |
| Fichiers widgets >500 lignes | 5 | **0** |
| Fichiers total >500 lignes (hors genere/controllers) | 17 | **<= 8** (controllers existants) |
| Controllers Riverpod | 6 | **10** |
| Providers actifs | 20+ | **24+** |
| GoogleFonts.cinzel directs | 333 | **<60** |
| app_router.dart lignes | 713 | **<200** |
| Score qualite | 9.0/10 | **9.5/10** |

*"Les meilleurs ingredients (controllers propres, theme centralise, analyse zero-defaut) cuisines dans l'ordre parfait. Le Baratie de Magic Companion sert maintenant des plats 9.5 etoiles."* -- Sanji
