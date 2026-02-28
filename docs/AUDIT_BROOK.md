# Documentation & Changelog - Rapport Brook
> Agent : Brook (Musicien / Documentation) | Date : 28/02/2026
> Changelog complet des modifications non commitees + notes de version

---

## 1. Etat du Repository

| Metrique | Valeur |
|----------|--------|
| Branche | `main` |
| Dernier commit | `c30fbcb` - Notes de version Build Beta |
| Fichiers modifies (non commites) | **51 fichiers** |
| Lignes ajoutees | **+1 401** |
| Lignes supprimees | **-1 131** |
| Delta net | **+270 lignes** |
| Fichiers non trackes (nouveaux) | **~20** (docs/, data/, providers/, router/, etc.) |

---

## 2. Changelog Detaille (depuis le dernier commit)

### 2.1 - Architecture & Infrastructure

#### NOUVEAU : Couche Database drift SQLite
- **`lib/data/database/app_database.dart`** (+542 lignes) -- Schema complet avec 10 tables drift
- **`lib/data/database/app_database.g.dart`** (+223K, genere) -- Code genere drift
- **`lib/data/migration/migration_service.dart`** (+327 lignes) -- Migration transparente SharedPrefs → drift
- **Tables** : CollectionCards, Decks, DeckCards, Wishlists, WishlistCards, Profiles, GameHistoryItems, ScanHistoryItems, CollectionValueHistory, AppSettings

#### NOUVEAU : Providers Riverpod
- **`lib/providers/service_providers.dart`** (+85 lignes) -- 14 providers (DB singleton, API, services)
- **`lib/providers/collection_provider.dart`** -- AsyncNotifier collection
- **`lib/providers/deck_provider.dart`** -- AsyncNotifier decks
- **`lib/providers/wishlist_provider.dart`** -- AsyncNotifier wishlists
- **`lib/providers/profile_provider.dart`** -- AsyncNotifier profils
- **`lib/providers/game_history_provider.dart`** -- AsyncNotifier historique

#### NOUVEAU : Navigation go_router
- **`lib/router/app_router.dart`** (+613 lignes) -- 14 routes declaratives, ShellRoute, drawer

#### NOUVEAU : Client HTTP centralise
- **`lib/services/scryfall_api_service.dart`** -- Dio + cache memoire + rate limiting 10 req/sec
- **`lib/services/scryfall_api.dart`** -- Constantes API Scryfall

#### NOUVEAU : Widget image cache
- **`lib/widgets/cards/scryfall_image.dart`** -- Widget CachedNetworkImage Scryfall

### 2.2 - Services Refactores (42 fichiers modifies)

| Service | Changement | Lignes +/- |
|---------|-----------|------------|
| `collection_service.dart` | Migration SharedPrefs → drift, injection DI, fix upsert | +163/-50 |
| `deck_service.dart` | Migration SharedPrefs → drift, 4 zones board | +257/-80 |
| `wishlist_service.dart` | Migration SharedPrefs → drift, migration v1→v2 | +157/-40 |
| `backup_service.dart` | Refactoring export/import via drift | +297/-50 |
| `profile_service.dart` | Migration vers drift | +42/-10 |
| `game_history_service.dart` | Migration vers drift | +48/-10 |
| `scan_history_service.dart` | Migration vers drift | +54/-10 |
| `set_service.dart` | Injection ScryfallApiService | +30/-10 |
| `edhrec_service.dart` | Cleanup | +72/-30 |

### 2.3 - Pages Modifiees

| Page | Changement principal | Lignes +/- |
|------|---------------------|------------|
| `main.dart` | Reduction massive : Firebase + migration + ProviderScope | +76/-446 (net -370) |
| `card_search_page.dart` | Migration HTTP → ScryfallApiService, ConsumerStatefulWidget | +156/-100 |
| `card_detail_page.dart` | Migration HTTP → ScryfallApiService, ConsumerStatefulWidget | +98/-60 |
| `deck_detail_page.dart` | Migration HTTP → ScryfallApiService, ConsumerStatefulWidget | +58/-30 |
| `deck_list_page.dart` | ConsumerStatefulWidget, injection DI | +37/-20 |
| `collection_page.dart` | Migration HTTP, ConsumerStatefulWidget | +35/-15 |
| `set_detail_page.dart` | Migration HTTP, passage apiService en parametre | +35/-15 |
| `scanner_page.dart` | ConsumerStatefulWidget | +24/-12 |
| `life_counter_page.dart` | ConsumerStatefulWidget | +10/-5 |
| Autres pages (8) | Adaptation ConsumerStatefulWidget + providers | ~+100/-80 |

### 2.4 - Widgets Modifies

| Widget | Changement | Lignes +/- |
|--------|-----------|------------|
| `deck_card_picker.dart` | Migration HTTP → provider | +80/-50 |
| `versions_selector_sheet.dart` | Migration HTTP → provider | +63/-30 |
| `collection_sets_tab.dart` | Fix ref.read deactivated widget | +30/-15 |
| `player_zone.dart` | Adaptation ConsumerStatefulWidget | +49/-25 |
| `game_setup_modal.dart` | Adaptation profils via provider | +38/-20 |
| Autres widgets (4) | Adaptations mineures | ~+30/-20 |

### 2.5 - Tests

| Fichier | Status | Tests |
|---------|--------|-------|
| `test/widget_test.dart` | Corrige (MyApp → MagicCompanionApp) | 1 |
| `test/data/app_database_test.dart` | **NOUVEAU** | ~32 tests drift in-memory |
| `test/models/deck_model_test.dart` | **NOUVEAU** | ~12 tests serialisation |
| `test/models/scryfall_card_model_test.dart` | **NOUVEAU** | ~15 tests serialisation |
| `test/models/profile_model_test.dart` | **NOUVEAU** | ~8 tests serialisation |
| `test/models/wishlist_model_test.dart` | **NOUVEAU** | ~6 tests serialisation |
| `test/services/collection_service_test.dart` | **NOUVEAU** | ~30 tests CRUD |
| `test/services/deck_service_test.dart` | **NOUVEAU** | ~25 tests CRUD |
| `test/services/wishlist_service_test.dart` | **NOUVEAU** | ~15 tests CRUD |
| `test/services/local_card_search_test.dart` | **NOUVEAU** | ~20 tests recherche |
| `test/services/backup_service_test.dart` | **NOUVEAU** | ~10 tests export/import |
| `test/services/scryfall_api_service_test.dart` | **NOUVEAU** | ~18 tests Dio mock |
| `test/services/set_service_test.dart` | **NOUVEAU** | ~5 tests |
| `test/router/app_router_test.dart` | **NOUVEAU** | ~6 tests navigation |
| **Total** | **14 fichiers** | **165 tests** |

### 2.6 - Configuration

| Fichier | Changement |
|---------|-----------|
| `pubspec.yaml` | +drift, +drift_flutter, +sqlite3_flutter_libs, +go_router, +logger, +dio, +cached_network_image, +flutter_riverpod |
| `analysis_options.yaml` | Regles strictes activees |
| `.github/workflows/build-main.yml` | +flutter analyze, +flutter test |
| `.gitignore` | Mise a jour |

### 2.7 - Documentation

| Document | Status |
|----------|--------|
| `docs/DOCUMENTATION.md` | Existant (documentation generale) |
| `docs/SCRYFALL_API_REFERENCE.md` | Existant (reference API Scryfall) |
| `docs/AUDIT_NAMI.md` | Existant (premier audit QA) |
| `docs/SPRINT1_*.md` → `docs/SPRINT7_*.md` | Sprints 1 a 7 documentes |
| `docs/ROADMAP_MUGIWARA.md` | Roadmap globale a jour |
| `docs/AUDIT_FRANKY.md` | **NOUVEAU** (audit code qualite) |
| `docs/AUDIT_NAMI_TESTS.md` | **NOUVEAU** (strategie de tests) |
| `docs/AUDIT_ROBIN.md` | **NOUVEAU** (cartographie architecture) |

---

## 3. Bugs Corriges (non commites)

| # | Bug | Fichier | Fix |
|---|-----|---------|-----|
| 1 | UNIQUE constraint failed sur collection_value_history.date_key | `app_database.dart:245` | Upsert manuel SELECT + UPDATE/INSERT |
| 2 | Deactivated widget ancestor lookup | `collection_sets_tab.dart:298` | Capture ref.read avant Navigator.push |

---

## 4. Notes de Version Proposees

### Magic Companion v2.0.0-beta -- "Grand Line Edition"

**Architecture** :
- Migration complete de SharedPreferences vers drift SQLite (10 tables)
- State management Riverpod (14 providers, injection DI centralisee)
- Navigation declarative go_router (14 routes)
- Client HTTP centralise Dio avec cache memoire et rate limiting
- Pipeline CI/CD avec analyse statique et tests automatises

**Qualite** :
- De 0 a 165 tests automatises (services, modeles, database, router)
- De ~30 warnings a 0 erreurs/warnings dans flutter analyze
- Migration transparente des donnees utilisateur (one-shot au premier lancement)
- 13 appels HTTP directs migres vers ScryfallApiService

**Corrections** :
- Fix crash SQLite UNIQUE constraint sur l'historique de valeur collection
- Fix crash "deactivated widget" lors de la navigation vers les sets
- Correction de tous les anti-patterns firstWhere/catch
- Suppression du code mort (_isValidating, _manaRegex, etc.)

**Chiffres cles** :
| Avant | Apres |
|-------|-------|
| Score 5.5/10 | Score 8.5/10 |
| 0 tests | 165 tests |
| SharedPreferences (27 acces) | drift SQLite (10 tables) |
| 0 providers | 14 providers Riverpod |
| http brut | Dio + cache + rate limit |
| Navigator.push (152) | go_router (14 routes) + 23 restants |

---

## 5. Recommandation : Commit Strategy

Les 51 fichiers modifies representent le travail des **Sprints 2 a 6** (Riverpod, Tests, Database, Navigation, HTTP migration). Voici la strategie de commit recommandee :

### Option A : Commit unique (pragmatique)
```
feat: major architecture refactor - Riverpod, drift SQLite, go_router, Dio centralization

- Migrate from SharedPreferences to drift SQLite (10 tables)
- Add Riverpod state management (14 providers, 24 ConsumerStatefulWidgets)
- Add go_router declarative navigation (14 routes)
- Centralize HTTP via Dio/ScryfallApiService (13 API calls migrated)
- Add 165 automated tests (services, models, database, router)
- Fix SQLite UNIQUE constraint on collection_value_history
- Fix deactivated widget ancestor in collection_sets_tab
- Add flutter analyze + flutter test to CI pipeline
```

### Option B : Commits atomiques (propre mais complexe)
1. `feat(db): add drift SQLite database with 10 tables and migration`
2. `feat(state): add Riverpod providers and DI`
3. `feat(nav): add go_router with 14 declarative routes`
4. `feat(http): centralize HTTP via Dio/ScryfallApiService`
5. `test: add 165 tests (services, models, database, router)`
6. `fix(db): fix UNIQUE constraint on collection_value_history`
7. `fix(ui): fix deactivated widget in collection_sets_tab`
8. `ci: add flutter analyze and test to pipeline`

**Recommandation** : Option A pour le moment (les changements sont trop interdependants pour etre separes proprement). Commencer les commits atomiques a partir du Sprint 7.

---

## 6. Etat de la Documentation

| Document | Pages | Mis a jour | Pertinent |
|----------|-------|------------|-----------|
| DOCUMENTATION.md | ~200 | Sprint 1 | Partiellement obsolete |
| SCRYFALL_API_REFERENCE.md | ~300 | Sprint 1 | A jour |
| AUDIT_NAMI.md | ~100 | Sprint 1 | Obsolete (remplace par Sprint docs) |
| SPRINT1-7_*.md | 21 fichiers | Sprint 7 | A jour |
| ROADMAP_MUGIWARA.md | ~335 | Sprint 7 | A jour |
| AUDIT_FRANKY.md | ~250 | Aujourd'hui | **NOUVEAU** |
| AUDIT_NAMI_TESTS.md | ~220 | Aujourd'hui | **NOUVEAU** |
| AUDIT_ROBIN.md | ~300 | Aujourd'hui | **NOUVEAU** |

### Documentation manquante

| Besoin | Priorite | Sprint |
|--------|----------|--------|
| README.md a jour (installation, contribution) | P2 | Sprint 8 |
| Guide d'onboarding developpeur | P3 | Sprint 8 |
| Diagramme d'architecture (draw.io/mermaid) | P2 | Sprint 8 |
| API interne (dartdoc) | P3 | Sprint 9+ |
| Guide de release | P3 | Sprint 9+ |

---

## 7. Verdict Brook

**L'histoire est bien ecrite.** Les 22 documents couvrent chaque sprint, chaque audit, chaque decision architecturale. La roadmap est a jour et les metriques sont tracees d'un sprint a l'autre.

**Le chapitre manquant** : Les 51 fichiers modifies ne sont pas commites. C'est comme avoir ecrit un chef-d'oeuvre musical sans l'enregistrer. Il faut commiter avant de continuer le Sprint 7.

**Actions immediates** :
1. Commiter les 51 fichiers (Option A)
2. Mettre a jour DOCUMENTATION.md (partiellement obsolete)
3. Archiver AUDIT_NAMI.md (remplace par les Sprint docs)

*"Yohohoho ! Un changelog sans commit, c'est comme une chanson sans paroles. Mais quelles belles paroles ce seront quand on les enregistrera ! Ah, mais je n'ai pas de cordes vocales... Skull joke !"* -- Brook, Musicien
