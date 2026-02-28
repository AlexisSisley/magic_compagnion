# Sprint 7 - Plan QA : Refactoring God Files & Qualite
> Agent : Nami (QA Lead) | Date : 28/02/2026

---

## PHASE V1 - Criteres de Validation par User Story

### V1.1 - US-7.1 : SetDetailController (set_detail_page.dart : 1003 → <400 lignes)

| # | Critere | Methode de verification |
|---|---------|------------------------|
| 1 | `lib/controllers/set_detail_controller.dart` existe | Glob fichier |
| 2 | Controller est un AsyncNotifier Riverpod | Inspect code : `extends _$SetDetailController` ou `extends AsyncNotifier` |
| 3 | Logique extraite : chargement cartes, pagination, filtres, ajout collection/wishlist | Grep methodes dans controller |
| 4 | `set_detail_page.dart` ne contient que du code UI | Grep : 0 `ScryfallApiService` direct, 0 `_db`, 0 business logic |
| 5 | `set_detail_page.dart` < 400 lignes | `wc -l` |
| 6 | Pas de regression : build + analyze + test | `flutter analyze` 0 erreurs, `flutter test` 165+ pass |
| 7 | Tests unitaires controller >= 5 | Grep test file, count tests |

### V1.2 - US-7.2 : DeckDetailController (deck_detail_page.dart : 850 → <400 lignes)

| # | Critere | Methode de verification |
|---|---------|------------------------|
| 1 | `lib/controllers/deck_detail_controller.dart` existe | Glob fichier |
| 2 | Controller gere les 4 zones : mainboard, sideboard, considering, wishlist | Inspect code |
| 3 | Batch fetch Scryfall dans le controller (pas dans la page) | Grep `fetchCollection` dans controller |
| 4 | `deck_detail_page.dart` < 400 lignes | `wc -l` |
| 5 | Tests unitaires controller >= 5 | Count tests |

### V1.3 - US-7.3 : CardSearchController (card_search_page.dart : 830 → <350 lignes)

| # | Critere | Methode de verification |
|---|---------|------------------------|
| 1 | `lib/controllers/card_search_controller.dart` existe | Glob fichier |
| 2 | Logique extraite : recherche API, recherche locale, pagination, filtres, tri | Grep methodes |
| 3 | `card_search_page.dart` < 350 lignes | `wc -l` |
| 4 | Tests unitaires controller >= 5 | Count tests |

### V1.4 - US-7.4 : CardDetailController (card_detail_page.dart : 773 → <400 lignes)

| # | Critere | Methode de verification |
|---|---------|------------------------|
| 1 | `lib/controllers/card_detail_controller.dart` existe | Glob fichier |
| 2 | Logique extraite : fetch card, rulings, ajout collection/deck/wishlist | Grep methodes |
| 3 | `card_detail_page.dart` < 400 lignes | `wc -l` |
| 4 | Tests unitaires controller >= 4 | Count tests |

### V1.5 - US-7.5 : DeckListController + CollectionController

| # | Critere | Methode de verification |
|---|---------|------------------------|
| 1 | `lib/controllers/deck_list_controller.dart` existe | Glob fichier |
| 2 | `lib/controllers/collection_controller.dart` existe | Glob fichier |
| 3 | `deck_list_page.dart` < 300 lignes | `wc -l` |
| 4 | `collection_page.dart` < 300 lignes | `wc -l` |
| 5 | Tests unitaires >= 4 par controller (total >= 8) | Count tests |

### V1.6 - US-7.6 : Mixin CardListUpsert

| # | Critere | Methode de verification |
|---|---------|------------------------|
| 1 | `lib/utils/card_list_upsert_mixin.dart` existe | Glob fichier |
| 2 | collection_service utilise le mixin | Grep `with CardListUpsertMixin` |
| 3 | deck_service utilise le mixin | Grep `with CardListUpsertMixin` |
| 4 | wishlist_service utilise le mixin | Grep `with CardListUpsertMixin` |
| 5 | 165 tests existants toujours verts | `flutter test` |
| 6 | Tests du mixin >= 3 | Count tests |

### V1.7 - US-7.7 : Migration Navigator.push

| # | Critere | Methode de verification |
|---|---------|------------------------|
| 1 | 0 `Navigator.push` dans lib/ (hors app_router.dart et showDialog) | Grep |
| 2 | Routes ajoutees dans app_router.dart | Inspect routes |
| 3 | `Navigator.pop` conserves uniquement pour dialogs/modales | Grep + review |
| 4 | Navigation fonctionnelle : test manuel chaque flux | Checklist manuelle |

### V1.8 - US-7.8 : Suppression package http

| # | Critere | Methode de verification |
|---|---------|------------------------|
| 1 | Ligne `http:` absente de pubspec.yaml | Grep pubspec.yaml |
| 2 | `flutter pub get` reussit | Bash |
| 3 | `flutter analyze` : 0 erreurs | Bash |
| 4 | `flutter test` : 165+ pass | Bash |

### V1.9 - US-7.9 : Widget Tests

| # | Critere | Methode de verification |
|---|---------|------------------------|
| 1 | Widget test `PlayerZone` existe | Glob test file |
| 2 | Widget test `ScryfallImage` existe | Glob test file |
| 3 | Widget test `DeckCardListTab` existe | Glob test file |
| 4 | Widget test `GameSetupModal` existe | Glob test file |
| 5 | Total tests >= 200 | `flutter test` count |
| 6 | Couverture > 60% | `flutter test --coverage` |

---

## PHASE V2 - Metriques Cibles Sprint 7

| Metrique | Avant Sprint 7 | Cible Sprint 7 | Methode |
|----------|----------------|-----------------|---------|
| Tests totaux | 165 | >= 200 | `flutter test` |
| Couverture tests | ~40% (estimee) | > 60% | `flutter test --coverage` |
| Fichiers > 500 lignes (pages) | 6 | **0** | `wc -l` sur les 6 God Files |
| Fichiers > 500 lignes (total) | 12 (hors genere) | <= 7 (widgets hors scope) | `wc -l` all files |
| Navigator.push | 23 (15 fichiers) | **0** | Grep |
| Package `http` dans pubspec | Oui | **Non** | Grep pubspec.yaml |
| Logique upsert dupliquee | 3 services | **1 mixin** | Code review |
| Controllers Riverpod | 0 | **6** | Glob `lib/controllers/` |
| flutter analyze erreurs | 0 | **0** | `flutter analyze` |

---

## PHASE V3 - Matrice de Tests

### Tests unitaires des controllers (nouveaux)

| Controller | Tests a ecrire | Priorite |
|------------|---------------|----------|
| SetDetailController | loadSetCards, filterCards, nextPage, addToCollection, addToWishlist | P0 |
| DeckDetailController | loadDeck, addCard, removeCard, moveCard, batchFetch | P0 |
| CardSearchController | searchApi, searchLocal, nextPage, applyFilters, sortResults | P0 |
| CardDetailController | fetchCard, fetchRulings, addToCollection, addToDeck | P0 |
| DeckListController | loadDecks, createDeck, deleteDeck, importDecklist | P0 |
| CollectionController | loadCollection, batchFetch, switchTab, exportCollection | P0 |

### Widget tests (nouveaux)

| Widget | Tests a ecrire | Priorite |
|--------|---------------|----------|
| PlayerZone | renders name, life total increments, life total decrements, color change, commander damage | P2 |
| ScryfallImage | loads image from URL, shows placeholder on loading, shows error on failure | P2 |
| DeckCardListTab | renders card list, long press context menu, move card action, quantity change | P2 |
| GameSetupModal | format selection, player count, start game enabled/disabled | P2 |

### Tests existants (non-regression)

| Suite | Count | Attendu Sprint 7 |
|-------|-------|-------------------|
| Sprint 3 : Modeles + Services SharedPrefs | 108 | 108 (vert) |
| Sprint 4 : drift in-memory | 32 | 32 (vert) |
| Sprint 5 : ScryfallApiService + Router + SetService | 25 | 25 (vert) |
| Widget test basique | 1 (MagicCompanionApp builds) | 1 (vert) |
| **Total existant** | **165** (verifie) | **165** (vert, 0 regression) |

---

## PHASE V4 - Checklist de Validation Finale

| # | Check | Commande/Action | Attendu |
|---|-------|-----------------|---------|
| 1 | Build compile | `flutter build apk --debug` | SUCCESS |
| 2 | Analyse statique | `flutter analyze` | 0 errors |
| 3 | Tests unitaires | `flutter test` | >= 200 pass, 0 fail |
| 4 | Couverture | `flutter test --coverage` | > 60% |
| 5 | 0 import http | `grep -r "package:http" lib/` | 0 resultats |
| 6 | 0 Navigator.push | `grep -r "Navigator.push" lib/pages/ lib/widgets/` | 0 resultats (hors dialogs) |
| 7 | God Files pages < 400 lignes | `wc -l` sur 6 fichiers | Tous < 400 |
| 8 | Controllers existent | `ls lib/controllers/` | 6 fichiers |
| 9 | Mixin upsert utilise | `grep -r "CardListUpsertMixin" lib/services/` | 3 fichiers |
| 10 | Widget tests existent | `ls test/widgets/` | >= 4 fichiers |
| 11 | CI pipeline vert | GitHub Actions | analyze + test + coverage |

---

## PHASE V5 - Checklist de Test Manuel (Navigation)

Apres migration Navigator.push vers go_router, tester chaque flux :

| # | Flux | Actions | Attendu |
|---|------|---------|---------|
| 1 | Recherche → Detail carte | Chercher "Black Lotus" → tap resultat | CardDetailPage s'ouvre correctement |
| 2 | Detail carte → Glossaire | Tap mot-cle dans rulings | GlossaryDetailPage s'ouvre |
| 3 | Collection → Stats | Tap icone stats | GlobalStatsPage s'ouvre |
| 4 | Collection → Set detail → Carte | Tap set → tap carte | Navigation 3 niveaux fonctionne |
| 5 | Decks → Detail deck | Tap deck | DeckDetailPage s'ouvre |
| 6 | Scanner → Historique | Tap icone historique | ScanHistoryPage s'ouvre |
| 7 | Scanner → Resultat → Detail | Scanner carte → tap resultat | CardDetailPage s'ouvre |
| 8 | Life counter → Tournoi | Tap icone tournoi | TournamentPage s'ouvre |
| 9 | Game history → Detail | Tap partie | GameHistoryDetailPage s'ouvre |
| 10 | Retour (back button) | Appuyer retour sur chaque page | Retour correct partout |
| 11 | Deep link | Ouvrir URL directe vers une carte | Page s'affiche correctement |

---

## PHASE V6 - Ordre d'Execution des Validations

| Etape | Action QA | Quand |
|-------|-----------|-------|
| 1 | Valider US-7.8 (suppression http) | Immediat apres implementation |
| 2 | Valider US-7.6 (mixin upsert) | Apres extraction, verifier 165 tests verts |
| 3 | Valider US-7.1 a US-7.5 (controllers) un par un | Apres chaque extraction |
| 4 | Run full `flutter test` apres chaque controller | Continu |
| 5 | Valider US-7.7 (Navigator.push migration) | Apres tous les controllers |
| 6 | Test manuel navigation (Phase V5) | Apres migration Navigator |
| 7 | Valider US-7.9 (widget tests) | Fin de sprint |
| 8 | Run checklist finale (Phase V4) | Cloture sprint |

---

## VERDICT ATTENDU : Criteres Go/No-Go

| Critere bloquant | Seuil |
|------------------|-------|
| flutter analyze | 0 erreurs |
| flutter test | 0 failures |
| Tests totaux | >= 200 |
| God Files pages | tous < 400 lignes |
| Navigator.push | 0 dans pages/widgets |
| Package http | absent de pubspec.yaml |

Si **un seul critere bloquant** echoue → **NO-GO**, corriger avant cloture.

*"Chaque berry de dette technique rembourse rapporte 10 berrys de productivite. Ce sprint vaut son pesant d'or !"* -- Nami, QA Lead
