# Sprint 8 - Synthese Capitaine : REPRISE Apres Sprints 9-12
> Agent : Luffy (Capitaine) | Date : 01/03/2026 | Mise a jour : Reprise post-pause

---

## 1. Resume Executif

Le Sprint 8 a ete **mis en pause** apres la correction des 77 `unnecessary_non_null_assertion` (commit `8035d46`). Les Sprints 9 a 12 ont livre des features utilisateur (suggestions EDHREC, import/export, legalite, tags, power level, syntaxe Scryfall, etc.), mais la dette technique a **continue de croitre**. Le nombre de fichiers >500 lignes est passe de **10 a 17**, les `GoogleFonts` directs de 333 a **365**, les `Colors.` hardcodes de 1536 a **1609**, et les `withOpacity` de 148 a **164**. En contrepartie, les tests sont passes de 273 a **561** (excellent filet de securite), et `AppColors` + `AppTextStyles` ont ete **crees au Sprint 12** (mais non migres).

**Decision strategique** : Le Sprint 8 original (15j) ne suffit plus vu l'ampleur de la dette. Le Sprint 8 est **scinde en 2 sous-sprints** :
- **Sprint 8A** (10j) : Nettoyage analyse + 4 controllers originaux + nouveaux God Controllers
- **Sprint 8B** (10j) : Sous-widgets pages + routeur + migration theme massive

---

## 2. Audit Actualise -- Etat des Lieux 01/03/2026

### 2.1 Metriques Comparees

| Metrique | Sprint 8 (pause) | Aujourd'hui | Delta | Tendance |
|----------|-----------------|-------------|-------|----------|
| Tests totaux | 273 | **561** | +288 | Amelioration |
| flutter analyze issues | 1041 | **1019** | -22 | Stable |
| withOpacity | 148 | **164** | +16 | Degradation |
| GoogleFonts directs | 333 | **365** | +32 | Degradation |
| Colors. hardcodes | 1536 | **1609** | +73 | Degradation |
| Controllers Riverpod | 6 | **8** | +2 | Amelioration |
| Fichiers >500 lignes (lib/) | 10 | **17** | +7 | Degradation |
| AppColors/AppTextStyles | N/A | **Crees** | - | Nouveau |

### 2.2 Inventaire Complet des Fichiers >500 Lignes (hors genere)

#### God Widgets (6 fichiers -- etaient 5)

| Fichier | Lignes | Sprint 8 original | Statut |
|---------|--------|-------------------|--------|
| `widgets/decks/deck_card_picker.dart` | **774** | 774 (inchange) | A extraire |
| `widgets/decks/deck_suggestions_tab.dart` | **771** | N/A (nouveau Sprint 11) | **NOUVEAU** -- A extraire |
| `widgets/life_counter/player_zone.dart` | **674** | 674 (inchange) | A extraire |
| `widgets/collection/collection_list_tab.dart` | **661** | 716 (-55, Sprint 10 tags) | A extraire |
| `widgets/decks/deck_stats_tab.dart` | **612** | 612 (inchange) | A extraire |
| `widgets/life_counter/game_setup_modal.dart` | **511** | 507 (etait hors scope) | A reevaluer |

#### God Controllers (4 fichiers -- NOUVEAUX)

| Fichier | Lignes | Sprint 8 original | Statut |
|---------|--------|-------------------|--------|
| `controllers/deck_detail_controller.dart` | **958** | ~450 (Sprint 7) | **CRITIQUE** -- a splitter |
| `controllers/card_search_controller.dart` | **665** | ~350 (Sprint 7) | **NOUVEAU** -- a splitter |
| `controllers/card_detail_controller.dart` | **555** | ~350 (Sprint 7) | **NOUVEAU** -- a evaluer |
| `controllers/set_detail_controller.dart` | **543** | ~350 (Sprint 7) | **NOUVEAU** -- a evaluer |

#### God Pages (5 fichiers -- etaient 5)

| Fichier | Lignes | Sprint 8 original | Statut |
|---------|--------|-------------------|--------|
| `pages/collections/set_detail_page.dart` | **1039** | 1039 (inchange) | A decomposer |
| `pages/decks/deck_detail_page.dart` | **656** | 656 (inchange) | A decomposer |
| `pages/cards/card_search_page.dart` | **562** | 562 (inchange) | A decomposer |
| `pages/cards/card_detail_page.dart` | **524** | 524 (inchange) | A decomposer |
| `pages/scans/scanner_page.dart` | **524** | N/A (nouveau) | **NOUVEAU** -- A evaluer |

#### Routeur (1 fichier)

| Fichier | Lignes | Sprint 8 original | Statut |
|---------|--------|-------------------|--------|
| `router/app_router.dart` | **713** | 713 (inchange) | A decomposer |

#### Autres

| Fichier | Lignes | Notes |
|---------|--------|-------|
| `data/database/app_database.dart` | **542** | Config drift -- acceptable |
| `services/scryfall_api_service.dart` | **~480** | Proche du seuil -- surveiller |

---

## 3. Plan de Reprise Actualise

### Sprint 8A : "Nettoyage Profond" (10j)

**Objectif** : Eliminer les issues analyse, extraire/splitter les controllers, reduire les God Files les plus critiques.

#### Phase 1 : Nettoyage Analyse Statique (2j) -- US-8.1

| # | Tache | Critere PASS |
|---|-------|-------------|
| 1 | `dart fix --apply` (single_quotes, const, braces) | Issues automatiques = 0 |
| 2 | Migrer 164 `.withOpacity()` -> `.withValues(alpha:)` | 0 occurrences withOpacity |
| 3 | Corriger `use_build_context_synchronously` | 0 issues manuelles |
| 4 | Corriger remaining (empty_catches, underscores, etc.) | `flutter analyze` = 0 issues |
| **Checkpoint** | `flutter analyze` = **0 issues**, 561 tests PASS | |

#### Phase 2 : Extraire 4 Controllers Widgets Originaux (4j) -- US-8.2

| # | Widget | Lignes | Controller a creer | Tests |
|---|--------|--------|-------------------|-------|
| 5 | deck_card_picker.dart | 774 | DeckCardPickerController | ~8 tests |
| 6 | collection_list_tab.dart | 661 | CollectionListController | ~6 tests |
| 7 | player_zone.dart | 674 | PlayerZoneController | ~5 tests |
| 8 | deck_stats_tab.dart | 612 | DeckStatsController | ~8 tests |
| **Checkpoint** | 4 widgets < 350 lignes, **~27 tests** ajoutes, 12 controllers | |

#### Phase 3 : Splitter God Controllers (3j) -- US-8.2bis (NOUVELLE US)

| # | Controller | Lignes | Action | Tests |
|---|-----------|--------|--------|-------|
| 9 | deck_detail_controller.dart | 958 | Extraire DeckSynergyController (~200 lignes synergy+combos) + DeckImportExportController (~150 lignes) | ~10 tests |
| 10 | card_search_controller.dart | 665 | Extraire ScryfallSyntaxHelper (static methods ~100 lignes) + deplacer filtres dans SearchFiltersController | ~6 tests |
| 11 | deck_suggestions_tab.dart | 771 | Extraire DeckSuggestionsController (logique EDHREC, enrichissement) | ~8 tests |
| **Checkpoint** | 0 controller >500 lignes, 0 widget >500 lignes (hors game_setup_modal), **~24 tests** ajoutes | |

#### Phase 4 : Stabilisation Sprint 8A (1j)

| # | Tache | Critere PASS |
|---|-------|-------------|
| 12 | Verification 0 regression sur tous les tests | 561+ tests PASS |
| 13 | `flutter analyze` = 0 issues confirme | 0 issues |
| 14 | Mise a jour ROADMAP | Sprint 8A TERMINE |

### Cibles Sprint 8A

| KPI | Avant | Cible 8A |
|-----|-------|----------|
| Tests totaux | 561 | **>= 610** (+~50) |
| flutter analyze issues | 1019 | **0** |
| withOpacity | 164 | **0** |
| Controllers Riverpod | 8 | **~15** |
| Fichiers controllers >500 lignes | 4 | **0** |
| Fichiers widgets >500 lignes | 6 | **1** (game_setup_modal seul) |

---

### Sprint 8B : "Architecture & Theme" (10j)

**Objectif** : Decomposer les pages God Files, modulariser le routeur, migrer massivement vers AppColors/AppTextStyles.

#### Phase 5 : Sous-widgets Pages (4j) -- US-8.3

| # | Page | Lignes | Sous-widgets a extraire | Cible |
|---|------|--------|------------------------|-------|
| 15 | set_detail_page.dart | 1039 | FilterModal, CardTile, StatsBar, BottomBar, ControlBar | <400 |
| 16 | deck_detail_page.dart | 656 | TabBarHeader, CommanderSection, ActionButtons | <400 |
| 17 | card_search_page.dart | 562 | SearchBar, ResultGrid, FilterChips | <400 |
| 18 | card_detail_page.dart | 524 | ImageSection, PrintsSection, PricesSection | <400 |
| 19 | scanner_page.dart | 524 | CameraPreview, ScanResults, ScanActions | <400 |
| **Checkpoint** | 0 page >500 lignes, 0 regression | |

#### Phase 6 : Routeur Modulaire (1.5j) -- US-8.4

| # | Tache | Critere PASS |
|---|-------|-------------|
| 20 | Creer sous-routeurs par domaine (cards_routes, decks_routes, collections_routes, life_counter_routes, settings_routes, tools_routes) | Fichiers existent |
| 21 | Migrer app_router.dart vers imports de sous-routeurs | <200 lignes |
| 22 | Verifier 23+ routes fonctionnelles | Navigation OK |
| **Checkpoint** | app_router.dart <200 lignes, navigation intacte | |

#### Phase 7 : Migration Theme Massive (3.5j) -- US-8.5

| # | Tache | Avant | Cible | Methode |
|---|-------|-------|-------|---------|
| 23 | Migrer GoogleFonts.cinzel -> AppTextStyles | 342 | **<30** | Search/replace + verification visuelle |
| 24 | Migrer GoogleFonts (autres) -> AppTextStyles | 23 restants | **<5** | Manuel |
| 25 | Migrer Colors. hardcodes -> AppColors | 1609 | **<200** | Par fichier, verification visuelle |
| 26 | Tests theme (constantes, coherence) | 0 | **~5 tests** | Unitaire |
| **Checkpoint** | GoogleFonts <30, Colors. <200, AppColors/AppTextStyles utilises partout | |

#### Phase 8 : Validation Finale Sprint 8B (1j)

| # | Tache | Critere PASS |
|---|-------|-------------|
| 27 | Verification 0 regression | Tous tests PASS |
| 28 | flutter analyze = 0 | Confirme |
| 29 | Verification visuelle 5 ecrans principaux | Pas de changement visuel |
| 30 | Mise a jour ROADMAP | Sprint 8 complet TERMINE |

### Cibles Sprint 8B

| KPI | Avant (fin 8A) | Cible 8B |
|-----|-----------------|----------|
| Tests totaux | >= 610 | **>= 630** (+~20) |
| Fichiers pages >500 lignes | 5 | **0** |
| app_router.dart | 713 | **<200** |
| GoogleFonts directs | 365 | **<30** |
| Colors. hardcodes | 1609 | **<200** |
| Score qualite global | 9.0/10 | **9.5/10** |

---

## 4. Arbitrages Actualises

| Conflit | Decision Originale (Sprint 8) | Decision Actualisee | Justification |
|---------|-------------------------------|---------------------|---------------|
| US-8.5 scope Colors | Reportee Sprint 9 | **Incluse dans Sprint 8B** (Phase 7) | AppColors existe deja, 561 tests = filet solide. Plus on attend, plus la dette croit (+73 en 4 sprints). Il faut migrer maintenant. |
| game_setup_modal | Hors scope | **Reste hors scope** pour 8A, reevalue en 8B | Le Sprint 12 a cree GameSetupController mais le modal reste a 511 lignes. Priorite inferieure aux 5 pages >500. |
| deck_detail_controller (958 lignes) | N'existait pas a ce niveau | **NOUVELLE priorite P0** dans Phase 3 | Plus gros fichier applicatif du projet. Doit etre splitte avant toute evolution future. |
| deck_suggestions_tab (771 lignes) | N'existait pas | **Inclus dans Sprint 8A** Phase 3 | God Widget cree au Sprint 11, contient logique EDHREC melangee avec UI. |
| card_search_controller (665 lignes) | N'existait pas a ce niveau | **Inclus dans Sprint 8A** Phase 3 | A grossi avec syntaxe Scryfall (Sprint 12). Logique syntax helper extractible. |
| Split Sprint 8 en 8A + 8B | Sprint unique 15j | **Sprint scinde en 2 x 10j** | La dette a double depuis la pause. 15j ne suffit plus. 2 sprints distincts avec checkpoints clairs. |

---

## 5. Graphe de Dependances (Chemin Critique)

```
SPRINT 8A (10j)
================
Phase 1 (2j) ──> Phase 2 (4j) ──> Phase 3 (3j) ──> Phase 4 (1j)
[Analyse]        [4 Controllers]   [Split God Ctrl]  [Stabilisation]

SPRINT 8B (10j)
================
Phase 5 (4j) ──> Phase 6 (1.5j) ──> Phase 7 (3.5j) ──> Phase 8 (1j)
[Pages]          [Routeur]           [Theme]             [Validation]
```

**Sprint 8A chemin critique** : 10j (sequentiel, pas de parallelisme)
**Sprint 8B chemin critique** : 10j (Phase 6 pourrait etre parallele a Phase 5)

---

## 6. Registre de Risques Actualise

| ID | Risque | Prob. | Impact | Mitigation |
|----|--------|-------|--------|------------|
| R-8.1 | Regression UI extraction sous-widgets set_detail_page (1039 lignes) | Moyen | Haut | Extraire 1 widget a la fois, test apres chaque extraction |
| R-8.2 | DeckCardPicker casse recherche/pagination | Moyen | Haut | 8 tests unitaires, verification manuelle |
| R-8.3 | withOpacity -> withValues casse visuels | Faible | Moyen | Verification visuelle 5 ecrans cles |
| R-8.4 | Split deck_detail_controller casse synergy/combos | Moyen | Haut | **NOUVEAU** -- Tests Sprint 11 (12 tests) comme filet de securite |
| R-8.5 | Migration Colors. massive (1609 occ.) introduit des regressions visuelles | Moyen | Haut | **NOUVEAU** -- Par fichier, verification visuelle, AppColors constants deja definies |
| R-8.6 | Routeur casse navigation Shell | Moyen | Haut | Garder ShellRoute dans fichier principal, tester toutes les routes |
| R-8.7 | Budget 10j insuffisant pour Sprint 8A ou 8B | Faible | Moyen | Phases ordonnees par priorite -- si depassement, derniere phase reportee |

---

## 7. Ce Qui a Change Depuis la Pause -- Resume

### Acquis positifs des Sprints 9-12

1. **561 tests** (vs 273) -- Filet de securite 2x plus large pour le refactoring
2. **AppColors + AppTextStyles crees** (Sprint 12) -- La fondation theme existe, reste a migrer
3. **GameSetupController cree** (Sprint 12) -- 1 des 5 God Widgets originaux partiellement traite
4. **deck_list_controller cree** -- +1 controller extrait
5. **Pattern etabli** pour les controllers StateNotifier -- 8 controllers existants comme modeles

### Dettes accumulees par les Sprints 9-12

1. **deck_detail_controller : 450 -> 958 lignes** (+508 lignes de features EDHREC/import/export)
2. **deck_suggestions_tab : 287 -> 771 lignes** (+484 lignes de themes/synergy/combos UI)
3. **card_search_controller : ~350 -> 665 lignes** (+315 lignes de syntaxe Scryfall)
4. **+32 GoogleFonts directs** (333 -> 365)
5. **+73 Colors. hardcodes** (1536 -> 1609)
6. **+16 withOpacity** (148 -> 164)
7. **scanner_page.dart : nouveau a 524 lignes** (OCR multi-langues Sprint 9)

---

## 8. Top 5 Actions Immediates (Sprint 8A)

1. **Lancer** `dart fix --apply` sur tout le projet pour corriger ~700 issues automatiques (Phase 1, etape 1)

2. **Migrer** les 164 `.withOpacity()` vers `.withValues(alpha:)` (Phase 1, etape 2)

3. **Extraire** `DeckCardPickerController` du widget le plus gros (774 lignes) (Phase 2, premiere extraction)

4. **Splitter** `deck_detail_controller.dart` (958 lignes) en 3 fichiers (Phase 3, priorite critique)

5. **Verifier** 0 regression avec les 561 tests apres chaque phase

---

## 9. Metriques de Succes Globales (Sprint 8A + 8B)

| Metrique | Avant pause | Aujourd'hui | Cible fin 8A | Cible fin 8B |
|----------|-------------|-------------|--------------|--------------|
| Tests totaux | 273 | 561 | >= 610 | >= 630 |
| flutter analyze | 1041 | 1019 | **0** | 0 |
| withOpacity | 148 | 164 | **0** | 0 |
| GoogleFonts directs | 333 | 365 | 365 (inchange) | **<30** |
| Colors. hardcodes | 1536 | 1609 | 1609 (inchange) | **<200** |
| Fichiers >500 lignes | 10 | 17 | **<= 6** (pages) | **0** |
| Controllers Riverpod | 6 | 8 | **~15** | ~15 |
| app_router.dart | 713 | 713 | 713 (inchange) | **<200** |
| Score qualite | 9.0/10 | 9.0/10 | 9.2/10 | **9.5/10** |

---

*"Ca fait 4 sprints qu'on a mis la salle des machines en pause pour construire de nouveaux canons sur le Sunny. Les canons sont magnifiques, mais la salle des machines prend l'eau ! Le Sprint 8A va colmater les breches et nettoyer la cale, le Sprint 8B va remettre chaque piece a sa place. Pas de nouvelle fonctionnalite tant que le navire n'est pas solide -- c'est l'ordre du Capitaine !"* -- Luffy, Capitaine
