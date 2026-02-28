# Sprint 4 - Analyse Business : Base de Donnees Locale (drift)
> Agent : Zorro (Business Analyst) | Date : 26/02/2026

---

## 1. Contexte

Les Sprints 1 (Fondations), 2 (Riverpod) et 3 (Tests & CI/CD) sont termines. Le projet dispose de :
- 108 tests unitaires avec 75% de couverture sur les services
- 12 providers Riverpod + 5 AsyncNotifiers
- 6 services utilisant SharedPreferences : CollectionService, DeckService, WishlistService, ProfileService, GameHistoryService, ScanHistoryService
- 27 acces SharedPreferences dans 12 fichiers
- Serialisation JSON complete en O(n) a chaque operation (load/save complet)

**Probleme** : SharedPreferences stocke tout en memoire sous forme de strings JSON. Chaque operation CRUD re-serialise et re-ecrit la totalite des donnees. Pour une collection de 500+ cartes, cela genere des latences perceptibles et un risque de perte de donnees en cas de crash pendant l'ecriture.

**Objectif Sprint 4** : Migrer le stockage de SharedPreferences vers une base de donnees locale drift, avec migration transparente des donnees existantes.

---

## 2. Choix Technologique : drift

### Comparatif

| Critere | SharedPreferences | sqflite | drift | isar |
|---------|-------------------|---------|-------|------|
| Typage | Aucun (String) | SQL brut | Type-safe Dart | Type-safe |
| Requetes | Deserialise tout | SQL manuel | Requetes Dart typees | Requetes typees |
| Migration schema | N/A | Manuelle | Automatique | Automatique |
| Relation entre tables | Impossible | Possible | Possible + typee | Possible |
| Tests | SharedPrefs mock | In-memory | In-memory natif | In-memory |
| Maintenance | Active | Active | Active | Abandonne (no null safety 3) |

**Decision : drift** pour les raisons suivantes :
1. **Type-safe** : Les requetes sont verifiees a la compilation
2. **Migration automatique** : `schemaVersion` + `MigrationStrategy`
3. **Tests in-memory** : `NativeDatabase.memory()` pour les tests sans filesystem
4. **Generateur de code** : Tables definies en Dart, code SQL genere automatiquement
5. **Support Flutter** : Package `drift_flutter` officiel

---

## 3. User Stories

### US-S4-01 : Configuration drift et schema de base
**En tant que** developpeur,
**Je veux** une base de donnees drift configuree avec le schema complet,
**Afin de** disposer d'une couche de persistance typee et performante.

**Criteres d'acceptation :**
- [ ] Package `drift`, `drift_flutter`, `drift_dev`, `build_runner` ajoutes au pubspec.yaml
- [ ] Fichier `lib/data/database/app_database.dart` cree avec la definition des 7 tables
- [ ] Fichier genere `app_database.g.dart` compile sans erreur
- [ ] Base de donnees initialisable en mode fichier (production) et in-memory (tests)
- [ ] Schema version 1 defini

**Tables a definir :**
| Table | Colonnes cles | Index |
|-------|--------------|-------|
| `collection_cards` | id (auto), scryfallId, name, quantity, proxyQuantity, isFoil, tags (TEXT JSON) | scryfallId, scryfallId+isFoil |
| `decks` | id (TEXT PK), name, format, commanderScryfallId?, commanderSecondaryScryfallId?, colors (TEXT JSON) | - |
| `deck_cards` | id (auto), deckId (FK), board (TEXT enum), scryfallId, name, quantity, proxyQuantity, isFoil, tags (TEXT JSON) | deckId, deckId+board |
| `wishlists` | id (TEXT PK), name, dateCreated, iconScryfallId? | - |
| `wishlist_cards` | id (auto), wishlistId (FK), scryfallId, name, quantity, proxyQuantity, isFoil, tags (TEXT JSON) | wishlistId |
| `profiles` | id (TEXT PK), name, colorValue, commanderScryfallId?, commanderName?, commanderArtCropUrl?, secondaryCommanderScryfallId?, secondaryCommanderName?, secondaryCommanderArtCropUrl? | - |
| `game_history` | id (TEXT PK), date, durationSeconds, winnerName, format, winMethod, playerStates (TEXT JSON) | date |
| `scan_history` | id (auto), scryfallId, cardName, imagePath?, timestamp | timestamp |
| `collection_value_history` | id (auto), dateKey (TEXT UNIQUE), totalValue (REAL) | dateKey |
| `app_settings` | key (TEXT PK), value (TEXT) | - |

**Priorite** : P0 | **Effort** : 1.5j

---

### US-S4-02 : DAO Collection
**En tant que** developpeur,
**Je veux** un Data Access Object pour la collection,
**Afin de** remplacer les acces SharedPreferences dans CollectionService.

**Criteres d'acceptation :**
- [ ] `CollectionDao` cree dans `lib/data/database/daos/collection_dao.dart`
- [ ] `getAllCards()` retourne `Future<List<CollectionCardEntry>>`
- [ ] `upsertCard(scryfallId, name, quantity, isFoil, tags)` insere ou met a jour
- [ ] `deleteCard(scryfallId, isFoil)` supprime une carte
- [ ] `clearAll()` vide la collection
- [ ] `getAllUniqueTags()` retourne les tags uniques
- [ ] `recordDailyValue(dateKey, value)` stocke dans `collection_value_history`
- [ ] `getValueHistory(daysAgo)` retourne l'historique financier
- [ ] Index sur scryfallId pour recherche rapide

**Priorite** : P1 | **Effort** : 1j

---

### US-S4-03 : DAO Decks
**En tant que** developpeur,
**Je veux** un Data Access Object pour les decks et leurs cartes,
**Afin de** remplacer la serialisation JSON complete a chaque operation.

**Criteres d'acceptation :**
- [ ] `DeckDao` cree dans `lib/data/database/daos/deck_dao.dart`
- [ ] `getAllDecks()` retourne les decks avec leurs cartes (4 boards)
- [ ] `getDeckById(id)` retourne un deck complet
- [ ] `createDeck(name)` insere un nouveau deck
- [ ] `updateDeck(deck)` met a jour les metadonnees du deck
- [ ] `deleteDeck(id)` supprime le deck et ses cartes (cascade)
- [ ] `upsertCard(deckId, board, scryfallId, name, qty, tags, isFoil)` gere les cartes
- [ ] `moveCard(deckId, fromBoard, toBoard, scryfallId)` deplace une carte
- [ ] Relations FK entre `decks` et `deck_cards` avec suppression cascade

**Priorite** : P1 | **Effort** : 1.5j

---

### US-S4-04 : DAO Wishlists
**En tant que** developpeur,
**Je veux** un Data Access Object pour les wishlists,
**Afin de** remplacer les acces SharedPreferences dans WishlistService.

**Criteres d'acceptation :**
- [ ] `WishlistDao` cree dans `lib/data/database/daos/wishlist_dao.dart`
- [ ] `getAllWishlists()` retourne les wishlists avec leurs cartes
- [ ] `createWishlist(name)` cree une wishlist avec date et ID
- [ ] `deleteWishlist(id)` supprime la wishlist et ses cartes (cascade)
- [ ] `renameWishlist(id, newName)` met a jour le nom
- [ ] `setIcon(id, scryfallId)` definit l'icone
- [ ] `upsertCard(wishlistId, scryfallId, name, qty, isFoil)` gere les cartes
- [ ] `clearCards(wishlistId)` vide les cartes sans supprimer la wishlist

**Priorite** : P1 | **Effort** : 1j

---

### US-S4-05 : DAO Profiles, GameHistory, ScanHistory
**En tant que** developpeur,
**Je veux** des DAOs pour les profils, l'historique de parties et l'historique de scans,
**Afin de** completer la migration de tous les services.

**Criteres d'acceptation :**
- [ ] `ProfileDao` : CRUD complet (load, save, delete)
- [ ] `GameHistoryDao` : addGame, loadHistory, clearHistory
- [ ] `ScanHistoryDao` : addScan, loadHistory, clearHistory (limite 50 items)
- [ ] `AppSettingsDao` : getInt, setInt, getString, setString (pour glossaryLang, playerCount, startingLife)

**Priorite** : P1 | **Effort** : 1j

---

### US-S4-06 : Migration SharedPreferences vers drift
**En tant que** utilisateur existant,
**Je veux** que mes donnees soient automatiquement migrees vers la nouvelle base,
**Afin de** ne perdre aucune donnee lors de la mise a jour.

**Criteres d'acceptation :**
- [ ] `MigrationService` cree dans `lib/data/migration/migration_service.dart`
- [ ] Detection automatique : si SharedPreferences contient des donnees ET la BDD est vide -> migration
- [ ] Migration de chaque cle : `user_collection`, `user_decks`, `user_wishlists_v2`, `user_profiles`, `game_history`, `scan_history`, `collection_value_history`
- [ ] Migration des settings : `glossaryLang`, `playerCount`, `startingLife`
- [ ] Gestion de la migration legacy wishlists (`user_wishlist` v1 -> v2 -> BDD)
- [ ] Marqueur `migration_completed` pour ne migrer qu'une seule fois
- [ ] Backup prealable des SharedPreferences avant migration (securite)
- [ ] Logging detaille de chaque etape de migration
- [ ] En cas d'erreur, rollback et conservation des SharedPreferences

**Priorite** : P0 | **Effort** : 1.5j

---

### US-S4-07 : Mise a jour des Services pour utiliser drift
**En tant que** developpeur,
**Je veux** que les services existants utilisent les DAOs drift,
**Afin de** beneficier des performances de la BDD locale.

**Criteres d'acceptation :**
- [ ] `CollectionService` utilise `CollectionDao` au lieu de SharedPreferences
- [ ] `DeckService` utilise `DeckDao` au lieu de SharedPreferences
- [ ] `WishlistService` utilise `WishlistDao` au lieu de SharedPreferences
- [ ] `ProfileService` utilise `ProfileDao` au lieu de SharedPreferences
- [ ] `GameHistoryService` utilise `GameHistoryDao` au lieu de SharedPreferences
- [ ] `ScanHistoryService` utilise `ScanHistoryDao` au lieu de SharedPreferences
- [ ] `BackupService` mis a jour pour exporter/importer depuis drift
- [ ] Plus aucun import de `shared_preferences` dans les services migres
- [ ] Les 108 tests existants passent toujours (ou sont adaptes)

**Priorite** : P1 | **Effort** : 2j

---

### US-S4-08 : Mise a jour des Providers Riverpod
**En tant que** developpeur,
**Je veux** que les providers injectent la database aux services,
**Afin de** maintenir l'injection de dependances propre.

**Criteres d'acceptation :**
- [ ] `databaseProvider` cree : fournit l'instance singleton de `AppDatabase`
- [ ] Les service providers recoivent la base via `ref.watch(databaseProvider)`
- [ ] Les services acceptent la base en parametre constructeur
- [ ] L'initialisation de la base (+ migration) se fait au demarrage de l'app
- [ ] Les AsyncNotifiers existants continuent de fonctionner sans changement

**Priorite** : P1 | **Effort** : 0.5j

---

### US-S4-09 : Tests d'integration couche donnees
**En tant que** developpeur,
**Je veux** des tests validant les DAOs et la migration,
**Afin de** garantir la fiabilite de la couche de persistance.

**Criteres d'acceptation :**
- [ ] Tests `CollectionDao` : CRUD, upsert, tags, foil/non-foil, historique financier
- [ ] Tests `DeckDao` : CRUD, 4 boards, cascade delete, moveCard
- [ ] Tests `WishlistDao` : CRUD, cascade delete, upsert card
- [ ] Tests `ProfileDao` : CRUD complet
- [ ] Tests `GameHistoryDao` : add, load, clear
- [ ] Tests `ScanHistoryDao` : add, load, clear, limite 50
- [ ] Tests `MigrationService` : migration complete, migration partielle, donnees corrompues
- [ ] Tous les tests utilisent `NativeDatabase.memory()` (pas de fichier)
- [ ] Les 108 tests existants passent toujours

**Priorite** : P1 | **Effort** : 2j

---

## 4. Architecture Cible Sprint 4

```
lib/
  data/
    database/
      app_database.dart              # Definition des tables + AppDatabase
      app_database.g.dart            # Code genere par drift
      daos/
        collection_dao.dart          # DAO Collection + ValueHistory
        deck_dao.dart                # DAO Decks + DeckCards
        wishlist_dao.dart            # DAO Wishlists + WishlistCards
        profile_dao.dart             # DAO Profiles
        game_history_dao.dart        # DAO GameHistory
        scan_history_dao.dart        # DAO ScanHistory
        app_settings_dao.dart        # DAO Settings (glossaryLang, playerCount, etc.)
    migration/
      migration_service.dart         # Migration SharedPreferences -> drift

  providers/
    service_providers.dart           # MODIFIE : ajoute databaseProvider
    collection_provider.dart         # Inchange (delegue au service)
    deck_provider.dart               # Inchange
    wishlist_provider.dart           # Inchange
    profile_provider.dart            # Inchange
    game_history_provider.dart       # Inchange

  services/
    collection_service.dart          # MODIFIE : utilise CollectionDao
    deck_service.dart                # MODIFIE : utilise DeckDao
    wishlist_service.dart            # MODIFIE : utilise WishlistDao
    profile_service.dart             # MODIFIE : utilise ProfileDao
    game_history_service.dart        # MODIFIE : utilise GameHistoryDao
    scan_history_service.dart        # MODIFIE : utilise ScanHistoryDao
    backup_service.dart              # MODIFIE : export/import via DAOs
```

---

## 5. Risques

| ID | Risque | Impact | Probabilite | Mitigation |
|----|--------|--------|-------------|------------|
| R1 | Perte de donnees lors de la migration | Critique | Faible | Backup prealable + marqueur migration_completed + rollback |
| R2 | Performance degradee par drift sur mobile ancien | Moyen | Faible | drift/sqlite est plus rapide que JSON serialization |
| R3 | Regression dans les services existants | Haut | Moyen | 108 tests existants comme filet de securite |
| R4 | Complexite du build_runner (generation de code) | Faible | Moyen | Documentation claire + commande dans le README |
| R5 | BackupService doit supporter les deux formats (JSON SharedPrefs + JSON drift) | Moyen | Certain | Phase transitoire : detecter le format et adapter |
| R6 | Google Drive backup doit rester compatible | Haut | Moyen | Le format JSON de backup reste identique, seul le stockage interne change |

---

## 6. Hors Scope Sprint 4

- Migration de `go_router` (Sprint 5)
- Migration HTTP vers Dio (Sprint 5)
- Refactoring des God Files (Sprint 6)
- Tests de widgets
- Optimisation des requetes (index avances, lazy loading)
- Chiffrement de la base de donnees

---

## 7. Estimation

| User Story | Effort | Priorite |
|------------|--------|----------|
| US-S4-01 : Schema drift | 1.5j | P0 |
| US-S4-02 : DAO Collection | 1j | P1 |
| US-S4-03 : DAO Decks | 1.5j | P1 |
| US-S4-04 : DAO Wishlists | 1j | P1 |
| US-S4-05 : DAO Profiles/History | 1j | P1 |
| US-S4-06 : Migration | 1.5j | P0 |
| US-S4-07 : Services drift | 2j | P1 |
| US-S4-08 : Providers | 0.5j | P1 |
| US-S4-09 : Tests | 2j | P1 |
| **Total** | **12j** | - |
