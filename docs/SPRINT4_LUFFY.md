# Sprint 4 - Synthèse Capitaine : Base de Données Locale
> Agent : Luffy (Capitaine) | Date : 27/02/2026

---

## Résumé Exécutif

Le Sprint 4 a migré le stockage de Magic Companion de SharedPreferences (sérialisation JSON O(n) à chaque opération) vers **drift** (base SQLite performante avec requêtes indexées). Les 6 services core utilisent désormais drift via injection Riverpod, avec fallback SharedPreferences pour compatibilité. Un service de migration transparente convertit automatiquement les données existantes au premier lancement. **32 nouveaux tests d'intégration** valident la couche données, portant le total à **140 tests**.

---

## Bilan des 4 Sprints

| Sprint | Objectif | Score Qualité |
|--------|----------|---------------|
| Sprint 1 - Fondations | Anti-patterns, lint, CI, logging | 5.5 → 6.5/10 |
| Sprint 2 - Riverpod | State management, injection deps | 6.5 → 7.0/10 |
| Sprint 3 - Tests & CI | Couverture tests, sérialisation | 7.0 → 7.5/10 |
| Sprint 4 - BDD Locale | drift, migration, DAOs, tests integ | 7.5 → **8.0/10** |

### Évolution des métriques

| Métrique | Avant Sprint 1 | Après Sprint 4 |
|----------|----------------|----------------|
| Tests | 0 (1 cassé) | **140** |
| Stockage | SharedPreferences (O(n)) | **drift SQLite (indexé)** |
| Tables BDD | 0 | **10** |
| DAO methods | 0 | **~30** |
| Migration auto | Non | **Oui (one-shot)** |
| Providers Riverpod | 0 | **13 (12 + appDatabaseProvider)** |
| flutter analyze errors | ~5 | **0** |
| CI gates | build only | **analyze + test + coverage** |

---

## Architecture Finale Sprint 4

```
┌──────────────────────────────────────────┐
│                  UI Pages                 │
│ (ConsumerStatefulWidget + ref.read)      │
└────────────────────┬─────────────────────┘
                     │
┌────────────────────▼─────────────────────┐
│           Riverpod Providers             │
│  appDatabaseProvider → AppDatabase       │
│  collectionServiceProvider(db: ✓)        │
│  deckServiceProvider(db: ✓)              │
│  wishlistServiceProvider(db: ✓)          │
│  profileServiceProvider(db: ✓)           │
│  gameHistoryServiceProvider(db: ✓)       │
│  scanHistoryServiceProvider(db: ✓)       │
└────────────────────┬─────────────────────┘
                     │
┌────────────────────▼─────────────────────┐
│              Services                     │
│  if (_db != null) → drift path           │
│  else → SharedPreferences fallback       │
└────────────────────┬─────────────────────┘
                     │
┌────────────────────▼─────────────────────┐
│           AppDatabase (drift)             │
│  10 tables, ~30 DAO methods              │
│  SQLite via drift_flutter                │
│  In-memory pour les tests                │
└──────────────────────────────────────────┘
```

### Démarrage de l'app

```
main() → WidgetsFlutterBinding.ensureInitialized()
       → Firebase.initializeApp()
       → AppDatabase() créé
       → MigrationService.migrateIfNeeded()
         ├─ Si pas encore migré + données SP existantes
         │  └─ Migre tout vers drift (one-shot)
         └─ Si déjà migré → skip
       → ProviderScope(overrides: [appDatabaseProvider])
       → MagicCompanionApp()
```

---

## Fichiers créés/modifiés

### Créés (sessions précédentes + cette session)
- `lib/data/database/app_database.dart` (531 lignes) - Schéma + DAOs
- `lib/data/database/app_database.g.dart` (généré) - Code drift auto-généré
- `lib/data/migration/migration_service.dart` (327 lignes) - Migration SP → drift
- `test/data/app_database_test.dart` (32 tests) - Tests intégration drift

### Modifiés (cette session)
- `lib/providers/service_providers.dart` - Ajout `appDatabaseProvider` + injection DB dans 6 services
- `lib/main.dart` - Ajout `AppDatabase` + `MigrationService.migrateIfNeeded()` au démarrage
- `lib/data/database/app_database.dart` - Fix `driftDatabase()` API

### Modifiés (sessions précédentes)
- 6 services : CollectionService, DeckService, WishlistService, ProfileService, GameHistoryService, ScanHistoryService
- `pubspec.yaml` : drift ^2.22.1, drift_flutter ^0.2.4, build_runner ^2.4.14, drift_dev ^2.22.1

---

## Risques résiduels

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Pages UI accédant directement à SharedPreferences (LifeCounter, Tournament, Glossary) | Moyen | Planifié pour un futur sprint (créer des services dédiés) |
| BackupService utilise encore SharedPreferences exclusivement | Moyen | Nécessite un refactoring pour lire depuis drift |
| Fallback SharedPreferences toujours présent dans les services | Faible | Pourra être supprimé une fois tous les users migrés |
| Pas de test de la migration service elle-même | Moyen | Testable avec une base in-memory pré-peuplée |

---

## Prochaines étapes (Sprint 5 : Navigation, HTTP et UX)

Selon la roadmap :
1. Implémenter `go_router` pour la navigation déclarative (152 Navigator.push à migrer)
2. Migrer les appels HTTP de `http` vers `Dio` (unifier le client)
3. Ajouter `dio_cache_interceptor` pour cache HTTP Scryfall
4. Implémenter le rate limiting API global
5. Ajouter un système de logging structuré
6. Améliorer la gestion du mode offline

---

## Top 5 Actions Immédiates

1. **Commit Sprint 4** - database + migration + providers + tests
2. **Tester manuellement** la migration sur un appareil avec données existantes
3. **Refactorer BackupService** pour supporter drift (lire depuis BDD au lieu de SharedPreferences)
4. **Planifier Sprint 5** - navigation go_router + HTTP Dio
5. **Optionnel** : Extraire LifeCounterService et TournamentService pour éliminer les accès SP directs

*"140 tests, une vraie base de données, et la migration se fait toute seule. Le Sunny est en pleine forme !"* -- Luffy, Capitaine
