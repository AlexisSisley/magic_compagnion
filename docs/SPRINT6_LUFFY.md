# Sprint 6 - Synthese Capitaine : Migration HTTP Complete
> Agent : Luffy (Capitaine) | Date : 28/02/2026

---

## Resume Executif

Le Sprint 6 a elimine les **13 derniers appels HTTP directs** (`http.get/post`) repartis dans 9 fichiers (pages + widgets). Tous les appels Scryfall passent desormais par le **ScryfallApiService** centralise (Dio + cache + rate limiting). Le package `http` n'est plus importe dans aucun fichier applicatif de `lib/`. Les **165 tests** existants passent sans regression, avec **0 erreurs** a l'analyse statique.

---

## Bilan des 6 Sprints

| Sprint | Objectif | Score Qualite |
|--------|----------|---------------|
| Sprint 1 - Fondations | Anti-patterns, lint, CI, logging | 5.5 → 6.5/10 |
| Sprint 2 - Riverpod | State management, injection deps | 6.5 → 7.0/10 |
| Sprint 3 - Tests & CI | Couverture tests, serialisation | 7.0 → 7.5/10 |
| Sprint 4 - BDD Locale | drift, migration, DAOs, tests integ | 7.5 → 8.0/10 |
| Sprint 5 - Navigation & HTTP | go_router, Dio, cache, rate limiting | 8.0 → 8.5/10 |
| Sprint 6 - Migration HTTP Pages | Elimination http direct, centralisation | 8.5 → **9.0/10** |

### Evolution des metriques

| Metrique | Avant Sprint 1 | Apres Sprint 6 |
|----------|----------------|----------------|
| Tests | 0 (1 casse) | **165** |
| Client HTTP | http eparpille (12 fichiers) | **Dio centralise (ScryfallApiService) -- 100%** |
| Appels http directs dans pages | 13 (9 fichiers) | **0** |
| Navigation | Navigator.push imperatif | **go_router declaratif (14 routes)** |
| Stockage | SharedPreferences (O(n)) | **drift SQLite (indexe)** |
| Tables BDD | 0 | **10** |
| Providers Riverpod | 0 | **14** |
| main.dart | 488 lignes (monolithe) | **67 lignes (routeur)** |
| flutter analyze errors | ~5 | **0** |
| CI gates | build only | **analyze + test + coverage** |

---

## Architecture Finale Sprint 6

```
+------------------------------------------+
|                  UI Pages                 |
|  (ConsumerStatefulWidget + ref.read)     |
|  0 imports http -- 100% via services     |
+------------------+-----------------------+
                   |
+------------------v-----------------------+
|            GoRouter                       |
|  ShellRoute → _AppShellScaffold           |
|  5 onglets + 9 routes Drawer              |
+------------------+-----------------------+
                   |
+------------------v-----------------------+
|           Riverpod Providers (14)         |
|  scryfallApiServiceProvider (singleton)   |
|  appDatabaseProvider → AppDatabase        |
|  6 services avec DB + API injection       |
+------------------+-----------------------+
                   |
        +----------+----------+
        |                     |
+-------v-------+    +--------v----------+
| ScryfallApi   |    | AppDatabase       |
| Service       |    | (drift SQLite)    |
| +----------+  |    | 10 tables         |
| | Dio      |  |    | ~30 DAO methods   |
| | Cache    |  |    +-------------------+
| | RateLimit|  |
| | Logging  |  |
| +----------+  |
+---------------+
     ^
     | Tous les appels Scryfall
     | (search, batch, sets,
     |  rulings, pagination)
     |
     13 appels migres
     (Sprint 5: 3 services)
     (Sprint 6: 9 pages/widgets)
```

---

## Fichiers modifies

### Migration HTTP (9 fichiers)

| Fichier | Appels migres | Methode ScryfallApiService |
|---------|---------------|---------------------------|
| `card_search_page.dart` | 2 | searchCards, fetchNextPage |
| `card_detail_page.dart` | 3 | getCardBySetAndNumber, searchCards, getCardRulings |
| `deck_detail_page.dart` | 1 | fetchCollection |
| `deck_list_page.dart` | 1 | searchCards |
| `set_detail_page.dart` | 1+ | searchCards, fetchNextPage |
| `collection_page.dart` | 1 | fetchCollection |
| `wishlist_detail_page.dart` | 1 | fetchCollection |
| `versions_selector_sheet.dart` | 1 | searchCards |
| `deck_card_picker.dart` | 2 | searchCards, fetchNextPage |

### Modifications supplementaires

- `collection_sets_tab.dart` : Passe `apiService` au constructeur SetDetailPage
- `versions_selector_sheet.dart` : Converti de StatefulWidget a ConsumerStatefulWidget

### Documents crees

- `docs/SPRINT6_ZORRO.md` - Analyse business
- `docs/SPRINT6_NAMI_QA.md` - Rapport QA
- `docs/SPRINT6_LUFFY.md` - Synthese capitaine

---

## Risques residuels

| Risque | Impact | Mitigation |
|--------|--------|------------|
| God Files (6 fichiers >500 lignes) | Moyen | Planifie Sprint 7 : extraction controllers |
| SharedPreferences residuel dans card_search_page (glossaryLang) | Faible | Migrer vers AppSettings drift dans un futur sprint |
| Package `http` toujours dans pubspec.yaml (dep transitive) | Faible | Supprimable une fois confirme que plus aucun code ne l'utilise |
| Navigator.push restants (detail pages) | Faible | Migration incrementale vers go_router |

---

## Prochaines etapes (Sprint 7 : Refactoring God Files)

Selon la roadmap, le prochain sprint devrait couvrir :

1. **Extraire controllers** pour les 6 God Files :
   - `set_detail_page.dart` (998 lignes) → SetDetailController
   - `deck_detail_page.dart` (858 lignes) → DeckDetailController
   - `card_search_page.dart` (837 lignes) → CardSearchController
   - `card_detail_page.dart` (783 lignes) → CardDetailController
   - `deck_list_page.dart` (734 lignes) → DeckListController
   - `collection_page.dart` (526 lignes) → CollectionController

2. **Supprimer le package `http`** du pubspec.yaml

3. **Migrer les Navigator.push restants** vers context.push/go

4. **Widget tests** pour composants critiques

5. **Objectif** : <300 lignes par fichier, >60% couverture

---

## Top 5 Actions Immediates

1. **Tester manuellement** l'app (recherche, detail carte, decks, collection, wishlists)
2. **Verifier** que le cache Scryfall fonctionne (moins d'appels reseau)
3. **Supprimer** le package `http` du pubspec.yaml
4. **Planifier Sprint 7** - Refactoring God Files avec controllers Riverpod
5. **Optionnel** : Migrer les SharedPreferences restants (glossaryLang, etc.) vers AppSettings drift

*"165 tests, zero appel HTTP sauvage, et le ScryfallApiService controle tout le trafic. Le Sunny est pret pour le Nouveau Monde !"* -- Luffy, Capitaine
