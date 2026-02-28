# Sprint 5 - Synthese Capitaine : Navigation & HTTP
> Agent : Luffy (Capitaine) | Date : 27/02/2026

---

## Resume Executif

Le Sprint 5 a pose les fondations de deux piliers essentiels : un **client HTTP centralise** (ScryfallApiService avec Dio, cache memoire et rate limiting) et une **navigation declarative** (go_router avec ShellRoute). Les 3 services faisant des appels HTTP ont ete migres vers le nouveau client, tandis que `main.dart` a ete reduit de 488 a 67 lignes grace au routeur. **25 nouveaux tests** portent le total a **165 tests**. Les 9 pages/widgets avec HTTP direct sont documentes pour migration future.

---

## Bilan des 5 Sprints

| Sprint | Objectif | Score Qualite |
|--------|----------|---------------|
| Sprint 1 - Fondations | Anti-patterns, lint, CI, logging | 5.5 → 6.5/10 |
| Sprint 2 - Riverpod | State management, injection deps | 6.5 → 7.0/10 |
| Sprint 3 - Tests & CI | Couverture tests, serialisation | 7.0 → 7.5/10 |
| Sprint 4 - BDD Locale | drift, migration, DAOs, tests integ | 7.5 → 8.0/10 |
| Sprint 5 - Navigation & HTTP | go_router, Dio, cache, rate limiting | 8.0 → **8.5/10** |

### Evolution des metriques

| Metrique | Avant Sprint 1 | Apres Sprint 5 |
|----------|----------------|----------------|
| Tests | 0 (1 casse) | **165** |
| Client HTTP | http eparpille (12 fichiers) | **Dio centralise (ScryfallApiService)** |
| Navigation | Navigator.push imperatif | **go_router declaratif (14 routes)** |
| Stockage | SharedPreferences (O(n)) | **drift SQLite (indexe)** |
| Tables BDD | 0 | **10** |
| Providers Riverpod | 0 | **14** |
| main.dart | 488 lignes (monolithe) | **67 lignes (routeur)** |
| flutter analyze errors | ~5 | **0** |
| CI gates | build only | **analyze + test + coverage** |

---

## Architecture Finale Sprint 5

```
+-----------------------------------------+
|                  UI Pages                |
|  (ConsumerStatefulWidget + ref.read)     |
+-----------------+-----------------------+
                  |
+-----------------v-----------------------+
|            GoRouter                      |
|  ShellRoute → _AppShellScaffold          |
|  ├─ / (LifeCounter)                     |
|  ├─ /scanner                            |
|  ├─ /search                             |
|  ├─ /decks                              |
|  └─ /collection                         |
|  + 9 routes Drawer (push)               |
+-----------------+-----------------------+
                  |
+-----------------v-----------------------+
|           Riverpod Providers             |
|  scryfallApiServiceProvider (singleton)  |
|  appDatabaseProvider → AppDatabase       |
|  collectionServiceProvider(db, api)      |
|  setServiceProvider(api)                 |
|  deckServiceProvider(db)                 |
|  wishlistServiceProvider(db)             |
|  ... (14 providers total)               |
+-----------------+-----------------------+
                  |
       +----------+----------+
       |                     |
+------v------+    +---------v---------+
| ScryfallApi |    | AppDatabase       |
| Service     |    | (drift SQLite)    |
| +---------+ |    | 10 tables         |
| | Dio     | |    | ~30 DAO methods   |
| | Cache   | |    +-------------------+
| | RateLimit|
| +---------+ |
+-------------+
```

---

## Fichiers crees/modifies

### Crees
- `lib/services/scryfall_api_service.dart` (240 lignes) - Client HTTP centralise
- `lib/router/app_router.dart` (~450 lignes) - Configuration go_router + shell
- `test/services/scryfall_api_service_test.dart` (14 tests)
- `test/router/app_router_test.dart` (7 tests)
- `test/services/set_service_test.dart` (4 tests)
- `docs/SPRINT5_ZORRO.md` - Analyse business
- `docs/SPRINT5_NAMI_QA.md` - Rapport QA

### Modifies
- `lib/main.dart` (488 → 67 lignes) - MaterialApp.router, suppression AppShell
- `lib/providers/service_providers.dart` - Ajout scryfallApiServiceProvider, injection API
- `lib/services/set_service.dart` - Migration http → ScryfallApiService
- `lib/services/edhrec_service.dart` - Migration http → Dio direct
- `lib/services/collection_service.dart` - Migration http.post → ScryfallApiService.fetchCollection
- `pubspec.yaml` - Ajout go_router, logger

---

## Risques residuels

| Risque | Impact | Mitigation |
|--------|--------|------------|
| 9 pages/widgets avec HTTP direct (`http` package) | Moyen | ScryfallApiService pret, migration page-par-page planifiee |
| Pages utilisant Navigator.push pour detail pages | Faible | Infrastructure go_router en place, migration incrementale |
| GoRouter ShellRoute ne gere pas le Drawer nativement | Faible | Drawer integre dans _AppShellScaffold, fonctionne |
| Package `http` toujours dans pubspec.yaml | Faible | Sera supprime quand les 9 fichiers restants seront migres |

---

## Prochaines etapes (Sprint 6 : Refactoring Pages & HTTP Migration)

1. **Migrer les 9 pages/widgets restants** vers ScryfallApiService
   - Extraire la logique HTTP des pages dans des services dedies
   - card_search_page → SearchService
   - card_detail_page → CardDetailService
   - deck_detail_page / deck_list_page → enrichir DeckService
   - set_detail_page → enrichir SetService
2. **Migrer les Navigator.push restants** vers context.push/go
   - Detail pages (card, deck, wishlist, game history)
   - Pages avec parametres complexes (SetDetailPage, etc.)
3. **Supprimer le package `http`** de pubspec.yaml
4. **Ajouter des tests de navigation** (GoRouter widget tests)
5. **Refactorer les "God Files"** (>700 lignes) avec des controllers

---

## Top 5 Actions Immediates

1. **Tester manuellement** la navigation (onglets + drawer) sur un appareil
2. **Migrer card_search_page.dart** vers ScryfallApiService (plus gros consommateur HTTP)
3. **Migrer card_detail_page.dart** (3 endpoints a centraliser)
4. **Ajouter les routes detail** dans go_router (deck/:id, card/:id)
5. **Planifier Sprint 6** - refactoring pages + suppression http

*"165 tests, un routeur qui sait ou aller, et un client HTTP qui cache comme un pro. Le Sunny navigue a pleine vitesse !"* -- Luffy, Capitaine
