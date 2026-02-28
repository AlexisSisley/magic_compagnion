# Sprint 5 - Rapport QA : Navigation & HTTP
> Agent : Nami (QA Lead) | Date : 27/02/2026

---

## PHASE V1 - Inspection du Code

### V1.1 - ScryfallApiService (Client HTTP centralise)

| Composant | Statut |
|-----------|--------|
| `lib/services/scryfall_api_service.dart` (240 lignes) | PASS |
| Client Dio avec BaseOptions (timeouts, User-Agent) | PASS |
| Cache memoire avec TTL configurable (10min / 24h) | PASS |
| Rate limiting (max 10 req/sec, conforme Scryfall) | PASS |
| Logging structure (dart:developer, avec duree) | PASS |
| Methodes API : searchCards, fetchNextPage, getCardBySetAndNumber, getCardRulings, getCardPrints, fetchCollection, getAllSets | PASS |
| Gestion d'erreurs (DioException rethrown) | PASS |
| Cache invalidation (clearCache, invalidateCache) | PASS |

### V1.2 - go_router Configuration

| Composant | Statut |
|-----------|--------|
| `lib/router/app_router.dart` (~450 lignes) | PASS |
| `AppRoutes` - constantes de routes (14 routes) | PASS |
| `createAppRouter()` - GoRouter avec ShellRoute | PASS |
| ShellRoute pour BottomNavigationBar (5 onglets) | PASS |
| NoTransitionPage pour onglets (pas de transition) | PASS |
| Routes Drawer (9 routes push) | PASS |
| `_AppShellScaffold` - ConsumerStatefulWidget | PASS |
| Drawer migre de main.dart vers app_router.dart | PASS |
| WidgetsBindingObserver pour backup auto | PASS |
| Drive backup/restore logic preservee | PASS |
| `context.go()` pour onglets, `context.push()` pour drawer | PASS |

### V1.3 - Services migres vers Dio

| Service | Avant | Apres | Statut |
|---------|-------|-------|--------|
| SetService | `http.get()` | `ScryfallApiService.getAllSets()` | PASS |
| EdhrecService | `http.get()` | `Dio` direct (API tierce, pas Scryfall) | PASS |
| CollectionService | `http.post()` | `ScryfallApiService.fetchCollection()` | PASS |

### V1.4 - main.dart simplifie

| Composant | Statut |
|-----------|--------|
| `MaterialApp` remplace par `MaterialApp.router` | PASS |
| `routerConfig: createAppRouter()` | PASS |
| AppShell (488 lignes) supprime de main.dart | PASS |
| main.dart reduit a 67 lignes (vs 488 avant) | PASS |
| Imports nettoyes (17 imports supprimes) | PASS |

### V1.5 - Providers mis a jour

| Composant | Statut |
|-----------|--------|
| `scryfallApiServiceProvider` ajoute | PASS |
| `collectionServiceProvider` injecte api | PASS |
| `setServiceProvider` injecte api | PASS |
| Total providers : 14 (13 + scryfallApiServiceProvider) | PASS |

---

## PHASE V2 - Build / Analyse / Tests

### flutter analyze
```
0 errors, 76 warnings (pre-existants : unused_*, deprecated_*), ~949 infos
```

### flutter test
```
165 tests passed, 0 failures
+----- Sprint 3 : 108 tests (modeles + services SharedPreferences)
+----- Sprint 4 : 32 tests (drift in-memory)
+----- Sprint 5 : 25 tests (ScryfallApiService + Router + SetService)
```

### Tests Sprint 5 detailles

| Groupe | Tests | Couverture |
|--------|-------|-----------:|
| ScryfallApiService - Cache | 4 | cache hit/miss, clear, invalidate, cacheSize |
| ScryfallApiService - API Methods | 7 | searchCards params, fetchNextPage, getBySet, rulings, fetchCollection POST, getAllSets cache |
| ScryfallApiService - Rate Limiting | 1 | 10 req/sec |
| ScryfallApiService - Error Handling | 1 | DioException rethrow |
| ScryfallApiService - Constructor | 2 | default, custom Dio injection |
| AppRoutes constants | 4 | paths start with /, unique, tab values, drawer values |
| createAppRouter | 2 | creation, initial location |
| SetService | 4 | parse sets, error handling, empty data, no-arg constructor |

---

## PHASE V3 - Anomalies corrigees

| ID | Description | Correction |
|----|-------------|------------|
| BUG-S5-001 | `HttpClientAdapter` ne peut pas etre `extends` en Dio 5.x | Utilise `implements` dans les tests |
| BUG-S5-002 | `ScryfallSet.fromJson` necessite `id` absent des tests | Ajoute `id` dans les fixtures de test |
| BUG-S5-003 | `withOpacity()` deprecie dans le Drawer | Remplace par `withValues(alpha: 0.1)` |

---

## PHASE V4 - Migration HTTP residuelle

| Fichier | Appels http restants | Raison |
|---------|---------------------|--------|
| card_search_page.dart | 2 (search + pagination) | Logique complexe de pagination liee a l'UI |
| card_detail_page.dart | 3 (set/cn, search, rulings) | Multiple endpoints, refactoring futur |
| deck_detail_page.dart | 1 (collection batch) | POST avec logique complexe |
| deck_list_page.dart | 1 (search) | Search inline |
| set_detail_page.dart | 1 (pagination) | Pagination sets |
| collection_page.dart | 1 (collection batch) | POST batch |
| wishlist_detail_page.dart | 1 (collection batch) | POST batch |
| versions_selector_sheet.dart | 1 (prints search) | Widget avec HTTP direct |
| deck_card_picker.dart | 2 (search + pagination) | Widget avec HTTP direct |

**Note** : Ces 9 fichiers necessitent d'extraire la logique HTTP dans des services dedies avant de supprimer les imports `http`. C'est un refactoring planifie pour un futur sprint.

---

## VERDICT : PASS

| Critere | Statut |
|---------|--------|
| 165 tests passent sans echec | **PASS** |
| flutter analyze : 0 erreurs | **PASS** |
| ScryfallApiService centralise avec cache + rate limiting | **PASS** |
| go_router configure avec ShellRoute + 14 routes | **PASS** |
| main.dart simplifie (488 → 67 lignes) | **PASS** |
| 3 services migres de http vers Dio/ScryfallApiService | **PASS** |
| Providers mis a jour (14 total) | **PASS** |
| 25 nouveaux tests Sprint 5 | **PASS** |
| Drive backup/restore preserve dans le shell | **PASS** |

*"Les routes sont tracees et le client HTTP ne fait plus d'appels sauvages. Reste 9 fichiers a migrer, mais la fondation est solide !"* -- Nami, QA Lead
