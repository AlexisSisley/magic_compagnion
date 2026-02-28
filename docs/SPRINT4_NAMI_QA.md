# Sprint 4 - Rapport QA : Base de Données Locale
> Agent : Nami (QA Lead) | Date : 27/02/2026

---

## PHASE V1 - Inspection du Code

### V1.1 - Base de données drift

| Composant | Statut |
|-----------|--------|
| `lib/data/database/app_database.dart` (531 lignes) | PASS |
| `lib/data/database/app_database.g.dart` (généré) | PASS |
| 10 tables définies (CollectionCards, Decks, DeckCards, Wishlists, WishlistCards, Profiles, GameHistoryItems, ScanHistoryItems, CollectionValueHistory, AppSettings) | PASS |
| DAO methods complets pour chaque table | PASS |
| `driftDatabase()` pour la connexion (corrigé depuis `DriftNativeDatabase`) | PASS |

### V1.2 - Migration Service

| Composant | Statut |
|-----------|--------|
| `lib/data/migration/migration_service.dart` (327 lignes) | PASS |
| Migration Collection | PASS |
| Migration Decks (4 boards) | PASS |
| Migration Wishlists (+ legacy v1→v2) | PASS |
| Migration Profiles | PASS |
| Migration GameHistory | PASS |
| Migration ScanHistory | PASS |
| Migration CollectionValueHistory | PASS |
| Migration Settings (glossaryLang, playerCount, startingLife) | PASS |
| Flag `drift_migration_completed` | PASS |
| Retry on failure (ne marque pas si erreur) | PASS |

### V1.3 - Services migrés (6/6)

| Service | Pattern drift | Fallback SharedPreferences | Statut |
|---------|--------------|---------------------------|--------|
| CollectionService | `if (_db != null)` | Oui | PASS |
| DeckService | `if (_db != null)` | Oui | PASS |
| WishlistService | `if (_db != null)` | Oui | PASS |
| ProfileService | `if (_db != null)` | Oui | PASS |
| GameHistoryService | `if (_db != null)` | Oui | PASS |
| ScanHistoryService | `if (_db != null)` | Oui | PASS |

### V1.4 - Providers et wiring

| Composant | Statut |
|-----------|--------|
| `appDatabaseProvider` dans service_providers.dart | PASS |
| 6 services injectés avec `ref.watch(appDatabaseProvider)` | PASS |
| `main.dart` : AppDatabase créé + MigrationService appelé | PASS |
| `ProviderScope` avec `overrides` pour le DB singleton | PASS |

---

## PHASE V2 - Build / Analyse / Tests

### flutter analyze
```
0 errors, 0 warnings, ~989 infos (préexistants)
```

### flutter test
```
140 tests passed, 0 failures
├── Sprint 3 : 108 tests (modèles + services SharedPreferences)
└── Sprint 4 : 32 tests (drift in-memory)
```

### Tests drift détaillés

| Groupe | Tests | Couverture |
|--------|-------|-----------|
| Collection DAO | 8 | CRUD, foil, tags, clear, unique tags |
| Collection Value History | 3 | record, evolution, limit 30 |
| Deck DAO | 5 | insert, upsert cards, delete cascade, update, clear |
| Wishlist DAO | 4 | insert, upsert, delete cascade, clear cards |
| Profile DAO | 3 | upsert, update, delete |
| Game History DAO | 2 | insert/retrieve, clear |
| Scan History DAO | 3 | insert, limit 50, clear |
| App Settings | 4 | string, int, null, overwrite |

---

## PHASE V3 - Anomalies corrigées

| ID | Description | Correction |
|----|-------------|------------|
| BUG-S4-001 | `DriftNativeDatabase` inexistant dans drift_flutter v0.2.x | Remplacé par `driftDatabase(name: 'magic_companion')` |
| BUG-S4-002 | Conflit `isNull`/`isNotNull` entre drift et matcher dans tests | Ajout `hide isNull, isNotNull` sur import drift |

---

## VERDICT : PASS

| Critère | Statut |
|---------|--------|
| 140 tests passent sans échec | **PASS** |
| flutter analyze : 0 erreurs | **PASS** |
| 10 tables drift définies et fonctionnelles | **PASS** |
| Migration SharedPreferences → drift complète | **PASS** |
| 6 services injectés avec AppDatabase | **PASS** |
| Tests d'intégration drift (32 tests in-memory) | **PASS** |
| Fallback SharedPreferences préservé | **PASS** |

*"La migration est terminée sans perdre un seul berry de données !"* -- Nami, QA Lead
