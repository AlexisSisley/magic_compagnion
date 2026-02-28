# Sprint 7 - Synthese Capitaine : Refactoring God Files & Qualite
> Agent : Luffy (Capitaine) | Date : 28/02/2026

---

## Resume Executif

Le Sprint 7 s'attaque au dernier gros chantier de dette technique : les **God Files**. Six pages depassant 500 lignes melangent logique metier et UI, rendant le code difficile a tester, a lire et a maintenir. Ce sprint va **extraire 6 controllers Riverpod**, **supprimer le package http obsolete**, **migrer les 23 Navigator.push restants** vers go_router, et **ajouter des widget tests** pour atteindre > 60% de couverture.

A l'issue de ce sprint, le score qualite cible est **9.5/10**, avec 0 fichier page > 400 lignes et > 200 tests.

---

## Bilan des 7 Sprints

| Sprint | Objectif | Score Qualite |
|--------|----------|---------------|
| Sprint 1 - Fondations | Anti-patterns, lint, CI, logging | 5.5 → 6.5/10 |
| Sprint 2 - Riverpod | State management, injection deps | 6.5 → 7.0/10 |
| Sprint 3 - Tests & CI | Couverture tests, serialisation | 7.0 → 7.5/10 |
| Sprint 4 - BDD Locale | drift, migration, DAOs, tests integ | 7.5 → 8.0/10 |
| Sprint 5 - Navigation & HTTP | go_router, Dio, cache, rate limiting | 8.0 → 8.5/10 |
| Sprint 6 - Migration HTTP Pages | Elimination http direct, centralisation | 8.5 → 9.0/10 |
| **Sprint 7 - Refactoring God Files** | **Controllers, tests, navigation** | **9.0 → 9.5/10** |

### Evolution des metriques cibles

| Metrique | Avant Sprint 1 | Apres Sprint 6 | Cible Sprint 7 |
|----------|----------------|----------------|-----------------|
| Tests | 0 (1 casse) | **165** | **>= 200** |
| Couverture | 0% | ~40% | **> 60%** |
| God Files pages (>500 lignes) | 6 | 6 | **0** |
| Controllers Riverpod | 0 | 0 | **6** |
| Navigator.push | 152 | 23 (15 fichiers) | **0** |
| Package `http` | present | present (inutilise) | **supprime** |
| Logique upsert dupliquee | 3 services | 3 services | **1 mixin** |
| Providers Riverpod | 0 | 14 | **20+** |
| flutter analyze errors | ~5 | 0 | **0** |

---

## Architecture Cible Sprint 7

```
+------------------------------------------+
|                  UI Pages                 |
|  (ConsumerStatefulWidget)                |
|  < 400 lignes chacune                   |
|  0 logique metier, 0 Navigator.push     |
+------------------+-----------------------+
                   |
                   | ref.watch / ref.read
                   |
+------------------v-----------------------+
|          Controllers Riverpod (6)        |
|  SetDetailController                     |
|  DeckDetailController                    |
|  CardSearchController                    |
|  CardDetailController                    |
|  DeckListController                      |
|  CollectionController                    |
|  (AsyncNotifier avec state management)   |
+------------------+-----------------------+
                   |
+------------------v-----------------------+
|            GoRouter (unifie)             |
|  ShellRoute + toutes les routes          |
|  0 Navigator.push, deep linking ready    |
+------------------+-----------------------+
                   |
+------------------v-----------------------+
|           Riverpod Providers (20+)       |
|  scryfallApiServiceProvider (singleton)  |
|  appDatabaseProvider → AppDatabase       |
|  6 services + 6 controllers              |
+------------------+-----------------------+
                   |
        +----------+----------+
        |                     |
+-------v-------+    +--------v----------+
| ScryfallApi   |    | AppDatabase       |
| Service       |    | (drift SQLite)    |
| Dio+Cache+RL  |    | 10 tables         |
+---------------+    +-------------------+
```

### Nouvelle structure fichiers

```
lib/
  controllers/           ← NOUVEAU (6 fichiers)
    set_detail_controller.dart
    deck_detail_controller.dart
    card_search_controller.dart
    card_detail_controller.dart
    deck_list_controller.dart
    collection_controller.dart

  utils/                 ← NOUVEAU (1 fichier)
    card_list_upsert_mixin.dart

  pages/                 ← MODIFIE (6 fichiers allèges)
    collections/
      set_detail_page.dart       (1003 → <400 lignes)
      collection_page.dart       (521 → <300 lignes)
    cards/
      card_search_page.dart      (830 → <350 lignes)
      card_detail_page.dart      (773 → <400 lignes)
    decks/
      deck_detail_page.dart      (850 → <400 lignes)
      deck_list_page.dart        (731 → <300 lignes)

  router/
    app_router.dart      ← MODIFIE (nouvelles routes)

test/
  controllers/           ← NOUVEAU (~30 tests)
  widgets/               ← NOUVEAU (~20 tests)
```

---

## Plan d'Execution

### Phase 1 : Quick Wins (0.25j)

| # | Tache | US | Effort |
|---|-------|----|--------|
| 1 | Supprimer `http: ^1.2.1` du pubspec.yaml | US-7.8 | 0.25j |
| - | Verifier `flutter pub get` + `flutter analyze` + `flutter test` | - | - |

### Phase 2 : Fondation Mixin (1j)

| # | Tache | US | Effort |
|---|-------|----|--------|
| 2 | Creer `CardListUpsertMixin` avec logique commune | US-7.6 | 0.5j |
| 3 | Integrer dans collection_service, deck_service, wishlist_service | US-7.6 | 0.25j |
| 4 | Tests du mixin | US-7.6 | 0.25j |

### Phase 3 : Extraction Controllers - Vague 1 (5j)

| # | Tache | US | Effort |
|---|-------|----|--------|
| 5 | Extraire SetDetailController + tests | US-7.1 | 2j |
| 6 | Extraire DeckDetailController + tests | US-7.2 | 2j |
| 7 | Extraire CardSearchController + tests | US-7.3 | 1.5j |

**Checkpoint** : `flutter test` vert, 6 God Files pages mesures.

### Phase 4 : Extraction Controllers - Vague 2 (3j)

| # | Tache | US | Effort |
|---|-------|----|--------|
| 8 | Extraire CardDetailController + tests | US-7.4 | 1.5j |
| 9 | Extraire DeckListController + CollectionController + tests | US-7.5 | 1.5j |

**Checkpoint** : 0 God File page > 400 lignes, >= 190 tests.

### Phase 5 : Navigation (1.5j)

| # | Tache | US | Effort |
|---|-------|----|--------|
| 10 | Ajouter routes manquantes dans app_router.dart | US-7.7 | 0.5j |
| 11 | Migrer les 23 Navigator.push vers context.push/go | US-7.7 | 0.75j |
| 12 | Test manuel de chaque flux de navigation | US-7.7 | 0.25j |

### Phase 6 : Widget Tests (2j)

| # | Tache | US | Effort |
|---|-------|----|--------|
| 13 | Widget tests PlayerZone | US-7.9 | 0.5j |
| 14 | Widget tests ScryfallImage | US-7.9 | 0.5j |
| 15 | Widget tests DeckCardListTab | US-7.9 | 0.5j |
| 16 | Widget tests GameSetupModal | US-7.9 | 0.5j |

**Checkpoint final** : >= 200 tests, > 60% couverture.

---

## Risques et Mitigations

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| Regression UI lors extraction controllers | Haut | Moyen | Extraire methode par methode, test intermediaire |
| Widget tests flaky (async, animations) | Faible | Moyen | pump/pumpAndSettle, mock services |
| Migration Navigator.push casse la navigation | Moyen | Moyen | Migrer un fichier a la fois, test manuel |
| Sprint trop ambitieux (13.25j) | Moyen | Moyen | US-7.9 (widget tests) repoussable en Sprint 8 si necessaire |

### Scope ajustable

Si le sprint prend du retard, les US peuvent etre repoussees dans cet ordre :
1. **US-7.9** (widget tests) → Sprint 8 (P2, 2j)
2. **US-7.7** (Navigator.push) → Sprint 8 (P1, mais indepedant des controllers)
3. Les controllers P0 ne sont **pas negociables**

---

## Top 5 Actions Immediates

1. **Supprimer** le package `http` du pubspec.yaml (US-7.8, 15 min)
2. **Creer** le dossier `lib/controllers/` et commencer par `SetDetailController` (le plus gros God File)
3. **Ecrire** le mixin `CardListUpsertMixin` (debloque la simplification des services)
4. **Extraire** les controllers un par un, en verifiant `flutter test` apres chaque extraction
5. **Migrer** les Navigator.push seulement apres que tous les controllers sont en place

---

## Metriques de Succes Sprint 7

| Metrique | Avant | Apres | Status |
|----------|-------|-------|--------|
| Tests totaux | 165 | >= 200 | A valider |
| Couverture tests | ~40% | > 60% | A valider |
| God Files pages > 500 lignes | 6 | 0 | A valider |
| Controllers Riverpod | 0 | 6 | A valider |
| Navigator.push | 23 | 0 | A valider |
| Package `http` | present | supprime | A valider |
| Mixin upsert | 0 | 1 (3 services) | A valider |
| flutter analyze errors | 0 | 0 | A valider |
| Score qualite | 9.0/10 | 9.5/10 | A valider |

---

## Prochaines Etapes (Sprint 8 : Widgets & Polish)

Si Sprint 7 reussit, le Sprint 8 pourrait couvrir :

1. **Extraction controllers pour les widgets** >500 lignes :
   - `collection_list_tab.dart` (715 lignes) → CollectionListController
   - `player_zone.dart` (674 lignes) → PlayerZoneController
   - `deck_stats_tab.dart` (612 lignes) → DeckStatsController
   - `game_setup_modal.dart` (507 lignes) → GameSetupController

2. **Refactoring app_router.dart** (613 lignes) → Decouper en sous-routeurs

3. **Internationalisation (i18n)** → Centraliser les 313 GoogleFonts.cinzel, extraire les strings

4. **Chiffrement BDD** → sqlite3_flutter_libs avec encryption

5. **Objectif** : Score qualite **10/10**, 0 fichier > 500 lignes dans tout le projet

*"Six God Files a dominer, comme six iles du Grand Line. Chaque controller est une victoire vers le One Piece du code parfait ! Le Sunny navigue a 9.5/10 !"* -- Luffy, Capitaine
