# Cartographie Architecture - Rapport Robin
> Agent : Robin (Archeologue / Architecture) | Date : 28/02/2026
> Cartographie complete de l'architecture Magic Companion post-Sprint 6

---

## 1. Vue d'Ensemble

Magic Companion est une application Flutter multi-fonctionnalites organisee en **6 couches** :

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRESENTATION (UI)                             │
│  19 pages + 20+ widgets                                         │
│  24 ConsumerStatefulWidget | 17 StatefulWidget | 16 Stateless   │
├─────────────────────────────────────────────────────────────────┤
│                    NAVIGATION                                    │
│  go_router (14 routes declaratives)                              │
│  + 23 Navigator.push residuels (15 fichiers)                     │
├─────────────────────────────────────────────────────────────────┤
│                    STATE MANAGEMENT                               │
│  Riverpod (ProviderScope)                                        │
│  6 fichiers providers | 14 providers actifs                      │
│  0 controllers (cible Sprint 7 : 6)                              │
├─────────────────────────────────────────────────────────────────┤
│                    SERVICES (Logique metier)                      │
│  14 fichiers services                                            │
│  Injection via Riverpod providers                                │
├─────────────────────────────────────────────────────────────────┤
│                    DATA ACCESS                                    │
│  drift SQLite (10 tables, 1 fichier monolithique)                │
│  Migration SharedPrefs → drift (service dedie)                   │
│  ScryfallApiService (Dio + cache + rate limiting)                │
├─────────────────────────────────────────────────────────────────┤
│                    EXTERNAL                                       │
│  Scryfall API | Firebase | Google Drive | EDHRec                 │
│  ML Kit OCR | Camera                                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Arborescence des Fichiers

```
lib/ (84 fichiers Dart, 22 099 lignes hors genere)
│
├── main.dart                      (76 lignes) -- Point d'entree, Firebase, migration, ProviderScope
├── firebase_options.dart          -- Config Firebase (genere)
├── chat_screen.dart               (344 lignes) -- Oracle IA chat screen
│
├── data/
│   ├── database/
│   │   ├── app_database.dart      (542 lignes) -- Schema drift + toutes requetes DAO
│   │   ├── app_database.g.dart    (223K, genere) -- Code genere drift
│   │   └── daos/                  (VIDE -- prevu pour extraction)
│   ├── migration/
│   │   └── migration_service.dart (327 lignes) -- Migration SharedPrefs → drift
│   ├── glossary_data.dart         -- Donnees glossaire statiques
│   └── secondary_breakfast.dart   -- Donnees secondaires
│
├── models/ (10 fichiers)
│   ├── deck_model.dart            -- Deck, DeckCard, DeckZone
│   ├── scryfall_card_model.dart   -- ScryfallCard (API mapping)
│   ├── profile_model.dart         -- Profil joueur
│   ├── game_history_model.dart    -- Historique de parties
│   ├── player_model.dart          -- Joueur (life counter)
│   ├── wishlist_model.dart        -- Wishlist, WishlistCard
│   ├── scan_history_model.dart    -- Historique de scans OCR
│   ├── search_filters.dart        -- Filtres de recherche
│   ├── scryfall_set_model.dart    -- Set MTG
│   └── scryfall_ruling.dart       -- Rulings MTG
│
├── services/ (14 fichiers, 2 900+ lignes)
│   ├── scryfall_api_service.dart  -- Client HTTP centralise (Dio + cache memoire + rate limit 10/s)
│   ├── scryfall_api.dart          -- Constantes API Scryfall (URLs, endpoints)
│   ├── collection_service.dart    -- CRUD collection (via drift)
│   ├── deck_service.dart          (356 lignes) -- CRUD decks (via drift)
│   ├── wishlist_service.dart      -- CRUD wishlists (via drift)
│   ├── profile_service.dart       -- CRUD profils joueurs (via drift)
│   ├── game_history_service.dart  -- CRUD historique parties (via drift)
│   ├── scan_history_service.dart  -- CRUD historique scans (via drift)
│   ├── local_card_service.dart    -- Recherche locale (oracle-cards.json, Isolate)
│   ├── set_service.dart           -- Gestion des sets MTG (via API)
│   ├── backup_service.dart        (347 lignes) -- Export/import JSON complet
│   ├── google_drive_service.dart  -- Sauvegarde Google Drive
│   ├── oracle_service.dart        -- Oracle IA (Firebase Cloud Functions)
│   └── edhrec_service.dart        -- Suggestions EDHRec (web scraping)
│
├── providers/ (6 fichiers)
│   ├── service_providers.dart     -- 14 providers (DB singleton, API, tous les services)
│   ├── collection_provider.dart   -- AsyncNotifier collection
│   ├── deck_provider.dart         -- AsyncNotifier decks
│   ├── wishlist_provider.dart     -- AsyncNotifier wishlists
│   ├── profile_provider.dart      -- AsyncNotifier profils
│   └── game_history_provider.dart -- AsyncNotifier historique
│
├── router/
│   └── app_router.dart            (613 lignes) -- go_router config + ShellRoute + drawer
│
├── pages/ (19 fichiers dans 8 sous-dossiers)
│   ├── cards/
│   │   ├── card_search_page.dart  (830 lignes) ★ GOD FILE
│   │   ├── card_detail_page.dart  (773 lignes) ★ GOD FILE
│   │   └── set_list_page.dart
│   ├── collections/
│   │   ├── collection_page.dart   (521 lignes) ★ GOD FILE
│   │   ├── set_detail_page.dart   (1003 lignes) ★ GOD FILE (le plus gros)
│   │   ├── set_stats_page.dart    (339 lignes)
│   │   ├── global_stats_page.dart (310 lignes)
│   │   └── wishlist_tab.dart      (321 lignes)
│   ├── decks/
│   │   ├── deck_list_page.dart    (731 lignes) ★ GOD FILE
│   │   └── deck_detail_page.dart  (850 lignes) ★ GOD FILE
│   ├── life_counter/
│   │   ├── life_counter_page.dart (469 lignes)
│   │   ├── game_history_page.dart
│   │   └── game_history_detail_page.dart
│   ├── scans/
│   │   ├── scanner_page.dart      (531 lignes)
│   │   └── scan_history_page.dart
│   ├── glossary/
│   │   ├── glossary_page.dart
│   │   ├── glossary_detail_page.dart
│   │   └── turn_guide_page.dart
│   ├── oracle/
│   │   └── magic_oracle_page.dart
│   ├── settings/
│   │   ├── settings_page.dart
│   │   ├── dev_tools_page.dart
│   │   └── profile_management_page.dart
│   ├── tools/
│   │   └── hypergeometric_page.dart
│   ├── tournaments/
│   │   └── tournament_page.dart   (298 lignes)
│   └── wishlists/
│       └── wishlist_detail_page.dart (289 lignes)
│
└── widgets/ (20+ fichiers dans 5 sous-dossiers)
    ├── cards/
    │   ├── scryfall_image.dart     -- Widget image cache Scryfall
    │   └── versions_selector_sheet.dart
    ├── collection/
    │   ├── collection_list_tab.dart (715 lignes) ★ GROS WIDGET
    │   ├── collection_sets_tab.dart (468 lignes)
    │   └── quick_add_view.dart
    ├── decks/
    │   ├── deck_card_picker.dart   (774 lignes) ★ GROS WIDGET
    │   ├── deck_card_list_tab.dart (420 lignes)
    │   ├── deck_card_title.dart
    │   ├── deck_financial_sheet.dart
    │   ├── deck_picker_modal.dart
    │   ├── deck_share_preview.dart
    │   ├── deck_stats_tab.dart     (612 lignes) ★ GROS WIDGET
    │   ├── deck_suggestions_tab.dart
    │   ├── deck_visual_share_list.dart (435 lignes)
    │   └── draw_test_simulator.dart (298 lignes)
    ├── life_counter/
    │   ├── player_zone.dart        (674 lignes) ★ GROS WIDGET
    │   ├── game_setup_modal.dart   (507 lignes) ★ GROS WIDGET
    │   └── dice_roll_dialog.dart
    ├── search/
    │   ├── search_filter_modal.dart
    │   ├── universal_filter_modal.dart (325 lignes)
    │   └── skyrim_sneak_loader.dart
    └── ia/
```

---

## 3. Diagramme de Dependances

### 3.1 - Flux Principal (Injection)

```
main.dart
  │
  ├── Firebase.initializeApp()
  ├── MigrationService(AppDatabase).migrateIfNeeded()
  │
  └── ProviderScope(overrides: [appDatabaseProvider → db])
       │
       └── MagicCompanionApp
            │
            └── MaterialApp.router(routerConfig: createAppRouter())
                 │
                 └── ShellRoute (app_router.dart)
                      │
                      ├── LifeCounterPage
                      ├── ScannerPage
                      ├── CardSearchPage ─── ref.read(scryfallApiServiceProvider)
                      ├── DeckListPage ───── ref.read(deckServiceProvider)
                      └── CollectionPage ─── ref.read(collectionServiceProvider)
```

### 3.2 - Graphe des Providers

```
appDatabaseProvider (singleton)
  │
  ├── collectionServiceProvider ← appDatabaseProvider + scryfallApiServiceProvider
  │     └── collectionProvider (AsyncNotifier)
  │
  ├── deckServiceProvider ← appDatabaseProvider
  │     └── deckProvider (AsyncNotifier)
  │
  ├── wishlistServiceProvider ← appDatabaseProvider
  │     └── wishlistProvider (AsyncNotifier)
  │
  ├── profileServiceProvider ← appDatabaseProvider
  │     └── profileProvider (AsyncNotifier)
  │
  ├── gameHistoryServiceProvider ← appDatabaseProvider
  │     └── gameHistoryProvider (AsyncNotifier)
  │
  └── scanHistoryServiceProvider ← appDatabaseProvider

scryfallApiServiceProvider (singleton)
  │
  ├── collectionServiceProvider (ci-dessus)
  └── setServiceProvider ← scryfallApiServiceProvider

localCardServiceProvider (standalone)
  └── localCardsInitProvider (FutureProvider)

edhrecServiceProvider (standalone)
backupServiceProvider (standalone)
googleDriveServiceProvider (standalone)
oracleServiceProvider (standalone)
```

### 3.3 - Flux de Donnees

```
                                  ┌──────────────┐
                                  │  Scryfall API │
                                  │  (scryfall.com)│
                                  └──────┬───────┘
                                         │
                              ┌──────────▼──────────┐
                              │  ScryfallApiService   │
                              │  Dio + cache memoire  │
                              │  Rate limit 10 req/s  │
                              └──────────┬──────────┘
                                         │
              ┌──────────────────────────┼──────────────────────┐
              │                          │                      │
    ┌─────────▼─────────┐   ┌───────────▼──────────┐   ┌──────▼──────────┐
    │ CollectionService  │   │    SetService        │   │ Pages directes  │
    │ (drift + API)      │   │    (API only)        │   │ (via provider)  │
    └─────────┬─────────┘   └──────────────────────┘   └─────────────────┘
              │
    ┌─────────▼─────────┐
    │   AppDatabase      │
    │   (drift SQLite)   │
    │   10 tables        │
    └─────────┬─────────┘
              │
    ┌─────────▼─────────────────────────────────────────────┐
    │  Tables : CollectionCards, Decks, DeckCards,           │
    │  Wishlists, WishlistCards, Profiles, GameHistoryItems, │
    │  ScanHistoryItems, CollectionValueHistory, AppSettings │
    └───────────────────────────────────────────────────────┘
```

---

## 4. Navigation

### 4.1 - Routes go_router (14 declaratives)

| Route | Page | Onglet |
|-------|------|--------|
| `/` | LifeCounterPage | Compteur |
| `/scanner` | ScannerPage | Scanner |
| `/search` | CardSearchPage | Recherche |
| `/decks` | DeckListPage | Decks |
| `/collection` | CollectionPage | Collection |
| `/game-history` | GameHistoryPage | Drawer |
| `/tournament` | TournamentPage | Drawer |
| `/oracle` | MagicOraclePage | Drawer |
| `/grimoire` | ChatScreen | Drawer |
| `/calculator` | HypergeometricPage | Drawer |
| `/glossary` | GlossaryPage | Drawer |
| `/glossary/turn-guide` | TurnGuidePage | Drawer |
| `/profiles` | ProfileManagementPage | Drawer |
| `/settings` | SettingsPage | Drawer |

### 4.2 - Navigator.push residuels (23 dans 15 fichiers)

| Destination | Occurrences | Depuis |
|-------------|-------------|--------|
| RecognitionResultPage | 10 | 7 fichiers (search, collection, deck, scanner) |
| CardDetailPage | 4 | set_detail, scanner, scan_history |
| WishlistDetailPage | 1 | wishlist_tab |
| DeckDetailPage | 1 | deck_list_page |
| SetDetailPage | 1 | collection_sets_tab |
| GlossaryDetailPage | 2 | card_detail, glossary_page |
| GlobalStatsPage | 1 | collection_page |
| TournamentPage | 1 | life_counter_page |
| GameHistoryDetailPage | 1 | game_history_page |
| ScanHistoryPage | 1 | scanner_page |

### 4.3 - Routes manquantes pour migration

| Route proposee | Page cible | Parametres |
|---------------|------------|------------|
| `/cards/recognize/:name` | RecognitionResultPage | cardName |
| `/cards/detail` | CardDetailPage | card (objet via extra) |
| `/collection/set/:code` | SetDetailPage | set (objet via extra) |
| `/collection/stats` | GlobalStatsPage | data via extra |
| `/glossary/:keyword` | GlossaryDetailPage | keyword |
| `/game-history/:id` | GameHistoryDetailPage | gameId |
| `/scanner/history` | ScanHistoryPage | - |
| `/wishlists/:id` | WishlistDetailPage | wishlist (via extra) |

---

## 5. Base de Donnees (drift SQLite)

### 5.1 - Schema (10 tables)

```
┌──────────────────────┐     ┌─────────────────────┐
│   CollectionCards     │     │   Decks              │
├──────────────────────┤     ├─────────────────────┤
│ id (PK, auto)        │     │ id (PK, auto)        │
│ scryfallId           │     │ name                 │
│ name                 │     │ format               │
│ quantity             │     │ commanderScryfallId   │
│ proxyQuantity        │     │ commanderSecondary... │
│ isFoil               │     │ colors               │
│ tags (JSON)          │     └──────────┬──────────┘
│ setCode              │                │ 1:N
│ setName              │     ┌──────────▼──────────┐
│ collectorNumber      │     │   DeckCards          │
│ price                │     ├─────────────────────┤
│ priceFoil            │     │ id (PK, auto)        │
│ artCropUrl           │     │ deckId (FK → Decks)  │
│ imageUri             │     │ board (enum)         │
└──────────────────────┘     │ scryfallId           │
                              │ quantity             │
┌──────────────────────┐     │ artCropUrl           │
│   Wishlists          │     │ (+ autres champs)    │
├──────────────────────┤     └─────────────────────┘
│ id (PK, auto)        │
│ name                 │     ┌─────────────────────┐
│ dateCreated          │     │   Profiles           │
│ iconScryfallId       │     ├─────────────────────┤
└──────────┬──────────┘     │ id (PK, auto)        │
           │ 1:N            │ name                 │
┌──────────▼──────────┐     │ colorValue           │
│   WishlistCards      │     │ commanderScryfallId   │
├──────────────────────┤     │ commanderName        │
│ id (PK, auto)        │     │ commanderArtCropUrl   │
│ wishlistId (FK)      │     │ defaultLife          │
│ scryfallId           │     │ isDefaultProfile     │
│ quantity             │     └─────────────────────┘
│ (+ autres champs)    │
└──────────────────────┘     ┌─────────────────────┐
                              │ GameHistoryItems     │
┌──────────────────────┐     ├─────────────────────┤
│ CollectionValueHist. │     │ id (PK, auto)        │
├──────────────────────┤     │ date                 │
│ id (PK, auto)        │     │ durationSeconds      │
│ dateKey (UNIQUE)     │     │ winnerName           │
│ totalValue (real)    │     │ format               │
└──────────────────────┘     │ winMethod            │
                              │ playerStates (JSON)  │
┌──────────────────────┐     └─────────────────────┘
│ ScanHistoryItems     │
├──────────────────────┤     ┌─────────────────────┐
│ id (PK, auto)        │     │ AppSettings          │
│ scryfallId           │     ├─────────────────────┤
│ cardName             │     │ key (PK, text)       │
│ imagePath            │     │ value (text)         │
│ timestamp            │     └─────────────────────┘
└──────────────────────┘
```

### 5.2 - Probleme architectural : Monolithe DAO

Toutes les requetes (CRUD pour 10 tables) sont dans `app_database.dart` (542 lignes). Le dossier `lib/data/database/daos/` est **vide**.

**Recommandation** : Extraire les requetes par domaine :
- `daos/collection_dao.dart` → requetes CollectionCards + CollectionValueHistory
- `daos/deck_dao.dart` → requetes Decks + DeckCards
- `daos/wishlist_dao.dart` → requetes Wishlists + WishlistCards
- `daos/profile_dao.dart` → requetes Profiles
- `daos/game_history_dao.dart` → requetes GameHistoryItems
- `daos/scan_history_dao.dart` → requetes ScanHistoryItems

---

## 6. Incoherences Detectees

### 6.1 - Navigation mixte (go_router + Navigator.push)

- **14 routes** dans go_router, mais **23 Navigator.push** coexistent
- Les pages poussees via `Navigator.push` ne sont pas dans le `ShellRoute` → pas de bottom nav, pas de drawer
- Certaines pages (RecognitionResultPage, SetDetailPage) n'ont pas de route go_router correspondante

### 6.2 - SharedPreferences residuels

Malgre la migration vers drift, **8 appels** `SharedPreferences.getInstance()` restent dans 5 pages pour :
- Langue du glossaire (`card_detail_page`, `card_search_page`, `glossary_page`)
- Compteur de vie prefere (`life_counter_page`)
- Tournoi config (`tournament_page`)

**Correctif** : Migrer vers la table `AppSettings` de drift.

### 6.3 - Widget types non homogenes

| Type | Count | Probleme |
|------|-------|----------|
| ConsumerStatefulWidget | 24 | Correct (acces Riverpod) |
| StatefulWidget | 17 | Pas d'acces direct aux providers |
| StatelessWidget | 16 | OK si pas besoin de state |

Les 17 `StatefulWidget` recoivent les services en parametres au lieu d'utiliser Riverpod. Cela cree du prop drilling.

### 6.4 - Dossier daos/ vide

Cree lors du Sprint 4 pour l'extraction future, mais jamais utilise. Les requetes restent monolithiques dans `app_database.dart`.

### 6.5 - Deux fichiers scryfall_api

- `lib/services/scryfall_api.dart` → Constantes (URLs, endpoints)
- `lib/services/scryfall_api_service.dart` → Client Dio

Noms similaires, roles differents. Renommer `scryfall_api.dart` en `scryfall_constants.dart` pour plus de clarte.

### 6.6 - Import inutilise

- `collection_service.dart` est importe mais non utilise dans `collection_sets_tab.dart`

---

## 7. Metriques Architecturales

| Metrique | Valeur | Cible |
|----------|--------|-------|
| Couplage moyen (imports/fichier) | ~5-8 | < 10 OK |
| Profondeur max des dossiers | 4 niveaux | OK |
| Fichiers > 500 lignes | 13 | Cible Sprint 7 : 7 (pages) |
| Fichiers > 300 lignes | 29 | Sprint 8+ |
| Providers actifs | 14 | Cible Sprint 7 : 20+ |
| Tables drift | 10 | Suffisant |
| Routes go_router | 14 | Cible Sprint 7 : 22+ |
| Services avec injection DI | 12/14 | 2 sans (scryfall_api, local consts) |

---

## 8. Architecture Cible (apres Sprint 7)

```
lib/
  main.dart                        -- 76 lignes (inchange)

  data/
    database/
      app_database.dart            -- Schema uniquement (~200 lignes)
      daos/                        -- 6 fichiers DAO (Sprint 8)
    migration/
      migration_service.dart       -- (inchange)

  models/                          -- 10 fichiers (inchange)

  services/                        -- 14 fichiers (inchange sauf mixin upsert)

  providers/                       -- 6 fichiers existants + 6 controller providers

  controllers/                     -- NOUVEAU (6 fichiers)
    set_detail_controller.dart     -- Extrait de set_detail_page (1003 → ~500 lignes logique)
    deck_detail_controller.dart    -- Extrait de deck_detail_page (850 → ~450 lignes logique)
    card_search_controller.dart    -- Extrait de card_search_page (830 → ~400 lignes logique)
    card_detail_controller.dart    -- Extrait de card_detail_page (773 → ~350 lignes logique)
    deck_list_controller.dart      -- Extrait de deck_list_page (731 → ~350 lignes logique)
    collection_controller.dart     -- Extrait de collection_page (521 → ~250 lignes logique)

  router/
    app_router.dart                -- +8 routes (total ~22)

  pages/                           -- 6 pages allegees (< 400 lignes chacune)

  widgets/                         -- (inchange en Sprint 7, Sprint 8 pour extraction)

  utils/
    card_list_upsert_mixin.dart    -- NOUVEAU (mixin DRY)
```

---

## 9. Verdict Robin

**Ce qui est bien construit** :
- Separation claire services/modeles/pages/widgets
- Riverpod correctement initialise avec injection centralisee
- drift SQLite avec migration automatique
- ScryfallApiService centralise (plus aucun appel HTTP direct)
- CI/CD avec flutter analyze + test

**Ce qui doit etre ameliore** :
- 6 pages "God File" melangent logique et UI (Sprint 7)
- Navigation hybride go_router/Navigator.push (Sprint 7)
- DAO monolithique dans app_database.dart (Sprint 8)
- 17 StatefulWidget sans acces Riverpod (Sprint 8)
- SharedPreferences residuels (Sprint 8)
- Nommage ambigu (scryfall_api vs scryfall_api_service)

**L'architecture est a 70% de sa cible finale.** Le Sprint 7 (controllers + navigation) la fera passer a ~85%. Le Sprint 8 (DAOs, widgets, i18n) l'amenera a ~95%.

*"L'histoire d'un projet se lit dans son architecture. Celle de Magic Companion montre une evolution methodique, sprint apres sprint. Les fondations sont solides -- il reste a dresser les derniers piliers."* -- Robin, Archeologue
