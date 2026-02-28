# Strategie de Tests - Rapport Nami
> Agent : Nami (QA Lead / Navigatrice) | Date : 28/02/2026
> Analyse de la couverture existante et plan de tests pour Sprint 7+

---

## 1. Etat des Lieux : Tests Existants

### 1.1 - Resume

| Metrique | Valeur |
|----------|--------|
| Tests totaux | **165** (tous verts) |
| Fichiers de test | **14** |
| Lignes de test | **2 947** |
| Couverture estimee | **~40%** (services + modeles + database) |
| Widget tests | **1** (smoke test MagicCompanionApp) |
| Integration tests | **0** |
| Tests E2E | **0** |

### 1.2 - Repartition par couche

| Couche | Fichiers | Tests | Lignes | Couverture |
|--------|----------|-------|--------|------------|
| **Database (drift)** | 1 (`app_database_test.dart`) | ~32 | 444 | ~80% DAO |
| **Services** | 7 fichiers | ~108 | 1 734 | ~60% services |
| **Modeles** | 4 fichiers | ~24 | 459 | ~90% serialisation |
| **Router** | 1 (`app_router_test.dart`) | ~6 | 87 | ~30% routes |
| **Widgets** | 0 | 0 | 0 | **0%** |
| **Pages** | 0 | 0 | 0 | **0%** |
| **Providers** | 0 | 0 | 0 | **0%** |
| **Total** | **14** | **165** | **2 947** | **~40%** |

### 1.3 - Detail par fichier de test

| Fichier | Lignes | Sujet teste |
|---------|--------|-------------|
| `collection_service_test.dart` | 483 | CRUD collection, upsert, batch, import |
| `app_database_test.dart` | 444 | 10 tables DAO drift (in-memory) |
| `deck_service_test.dart` | 370 | CRUD decks, zones, moveCard |
| `wishlist_service_test.dart` | 301 | CRUD wishlists, migration v1→v2 |
| `local_card_search_test.dart` | 295 | Recherche locale, smart match, filtres |
| `scryfall_api_service_test.dart` | 268 | Client Dio mock, cache, rate limiting |
| `scryfall_card_model_test.dart` | 155 | Serialisation/deserialisation ScryfallCard |
| `backup_service_test.dart` | 145 | Export JSON, restoration |
| `deck_model_test.dart` | 128 | Serialisation Deck, DeckCard |
| `profile_model_test.dart` | 93 | Serialisation Profile |
| `app_router_test.dart` | 87 | Routes existantes, redirection |
| `wishlist_model_test.dart` | 83 | Serialisation Wishlist |
| `set_service_test.dart` | 77 | SetService + API mock |
| `widget_test.dart` | 18 | Smoke test (app builds) |

---

## 2. Zones Non Testees (Risques)

### 2.1 - CRITIQUE : Methode `recordDailyValue` (fix recent)

**Contexte** : Le bug SQLite UNIQUE constraint a ete corrige par un upsert manuel, mais le test existant dans `app_database_test.dart` ne couvre pas le cas du **double appel** avec la meme `dateKey`.

**Tests manquants** :

```
recordDailyValue : appel unique cree une entree
recordDailyValue : double appel meme dateKey met a jour la valeur (pas d'exception)
recordDailyValue : 31 entrees → les plus anciennes sont supprimees (>30 jours)
recordDailyValue : valeur negative acceptee
recordDailyValue : dateKey format different (YYYY-M-D vs YYYY-MM-DD)
```

**Priorite** : P0 (le bug a ete un crash en production)

### 2.2 - CRITIQUE : Providers Riverpod (0 tests)

Aucun test ne verifie que les providers sont correctement configures et fournissent les bonnes instances.

**Tests manquants** :
```
appDatabaseProvider : retourne une instance AppDatabase
scryfallApiServiceProvider : retourne un singleton
collectionServiceProvider : recoit la bonne database et API
deckServiceProvider : recoit la bonne database
localCardsInitProvider : charge les cartes au demarrage
```

**Priorite** : P1

### 2.3 - HAUTE : Navigation (partielle)

`app_router_test.dart` ne teste que 6 routes sur 14+. Les routes ajoutees apres Sprint 5 ne sont pas couvertes.

**Routes non testees** :
- Routes vers SetDetailPage, GlobalStatsPage
- Routes avec parametres dynamiques
- Redirections et guards
- Deep links

### 2.4 - HAUTE : Widgets (0 tests)

Aucun widget n'est teste. Les composants suivants sont critiques :

| Widget | Lignes | Interactions utilisateur | Risque |
|--------|--------|------------------------|--------|
| `player_zone.dart` | 674 | Gestes +1/-1, long press, couleurs | Eleve |
| `game_setup_modal.dart` | 507 | Selection format, joueurs, validation | Eleve |
| `collection_list_tab.dart` | 715 | Filtres, tri, actions contextuelles | Moyen |
| `deck_card_picker.dart` | 774 | Recherche, selection multi | Moyen |
| `deck_stats_tab.dart` | 612 | Graphiques, calculs | Moyen |
| `scryfall_image.dart` | ~100 | Chargement, placeholder, erreur | Faible |

### 2.5 - MOYENNE : Services partiellement testes

| Service | Teste | Methodes non couvertes |
|---------|-------|----------------------|
| `collection_service.dart` | Oui | `recordDailyValue`, `getCollectionEvolution`, prix batch |
| `game_history_service.dart` | Non | Tout (CRUD, stats) |
| `scan_history_service.dart` | Non | Tout (CRUD) |
| `profile_service.dart` | Non | Tout (sauf via database test) |
| `google_drive_service.dart` | Non | Backup/restore cloud (complexe, mock Google API) |
| `oracle_service.dart` | Non | Appels Firebase Cloud Functions |
| `edhrec_service.dart` | Non | Web scraping EDHRec |

---

## 3. Plan de Tests Sprint 7

### 3.1 - Tests a ajouter (par priorite)

#### P0 - Tests du fix recordDailyValue (0.5j)

| # | Test | Fichier |
|---|------|---------|
| 1 | `recordDailyValue` double appel meme dateKey → update sans exception | `app_database_test.dart` |
| 2 | `recordDailyValue` 31 entrees → nettoyage anciennes | `app_database_test.dart` |
| 3 | `recordDailyValue` appel concurrent (si applicable) | `app_database_test.dart` |

#### P0 - Tests des 6 Controllers (Sprint 7, 3j)

| Controller | Tests minimum | Effort |
|------------|---------------|--------|
| SetDetailController | loadSetCards, filterCards, nextPage, addToCollection, addToWishlist | 0.5j |
| DeckDetailController | loadDeck, addCard, removeCard, moveCard, batchFetch | 0.5j |
| CardSearchController | searchApi, searchLocal, nextPage, applyFilters, sortResults | 0.5j |
| CardDetailController | fetchCard, fetchRulings, addToCollection, addToDeck | 0.5j |
| DeckListController | loadDecks, createDeck, deleteDeck, importDecklist | 0.5j |
| CollectionController | loadCollection, batchFetch, switchTab, exportCollection | 0.5j |

**Total** : ~30 tests, ~6 fichiers dans `test/controllers/`

#### P1 - Tests des Providers (0.5j)

| Test | Verifie |
|------|---------|
| `appDatabaseProvider` retourne AppDatabase | Instance non null |
| `collectionServiceProvider` injecte correctement | database + api |
| `deckServiceProvider` injecte correctement | database |
| `localCardsInitProvider` complete | Chargement OK |

**Fichier** : `test/providers/service_providers_test.dart`

#### P2 - Widget Tests (2j)

| Widget | Tests | Effort |
|--------|-------|--------|
| PlayerZone | Renders name, life +1/-1, commander damage, color change | 0.5j |
| ScryfallImage | Loads URL, placeholder, error state | 0.5j |
| GameSetupModal | Format selection, player count, start enabled/disabled | 0.5j |
| DeckCardListTab | Renders list, long press menu, move card | 0.5j |

**Total** : ~20 tests, 4 fichiers dans `test/widgets/`

#### P2 - Services non testes (1.5j)

| Service | Tests | Effort |
|---------|-------|--------|
| `game_history_service.dart` | CRUD, stats, filtres | 0.5j |
| `scan_history_service.dart` | CRUD, cleanup | 0.25j |
| `profile_service.dart` | CRUD, commander, couleur | 0.25j |

---

## 4. Metriques Cibles

| Metrique | Actuel | Cible Sprint 7 | Cible Sprint 8 |
|----------|--------|-----------------|-----------------|
| Tests totaux | 165 | **>= 200** | >= 250 |
| Fichiers de test | 14 | >= 22 | >= 28 |
| Widget tests | 1 | >= 5 | >= 10 |
| Controller tests | 0 | >= 6 | >= 10 |
| Provider tests | 0 | >= 1 | >= 2 |
| Couverture globale | ~40% | **> 60%** | > 70% |
| Couverture services | ~60% | > 80% | > 90% |
| Couverture modeles | ~90% | > 90% | > 95% |
| Couverture database | ~80% | > 90% | > 95% |

---

## 5. Infrastructure de Test

### 5.1 - Ce qui fonctionne

- **drift in-memory** : Tous les tests database utilisent `NativeDatabase.memory()` → rapide, isole
- **Mocks services** : Les tests services mockent les dependances (pas de vrais appels API)
- **CI pipeline** : `flutter test` execute dans GitHub Actions

### 5.2 - Ce qui manque

| Besoin | Status | Action |
|--------|--------|--------|
| Coverage report dans CI | Manquant | Ajouter `--coverage` + seuil dans workflow |
| Mock Riverpod (ProviderContainer) | Manquant | Necessaire pour tester controllers |
| Mock HTTP (dio_mock) | Existant dans scryfall_api_test | Reutiliser |
| Test fixtures partagees | Partiel | Creer `test/fixtures/` avec des cartes/decks mock |
| Golden tests (screenshots) | Manquant | Sprint 8+ |

### 5.3 - Pattern de test recommande pour Controllers

```dart
// test/controllers/set_detail_controller_test.dart
void main() {
  late ProviderContainer container;
  late MockCollectionService mockCollectionService;
  late MockScryfallApiService mockApiService;

  setUp(() {
    mockCollectionService = MockCollectionService();
    mockApiService = MockScryfallApiService();
    container = ProviderContainer(
      overrides: [
        collectionServiceProvider.overrideWithValue(mockCollectionService),
        scryfallApiServiceProvider.overrideWithValue(mockApiService),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('loadSetCards fetches cards from API', () async {
    // arrange
    when(mockApiService.searchCards(any)).thenAnswer((_) async => [...]);
    // act
    final controller = container.read(setDetailControllerProvider.notifier);
    await controller.loadSetCards('neo');
    // assert
    expect(container.read(setDetailControllerProvider).value?.cards, hasLength(20));
  });
}
```

---

## 6. Ordre d'Execution Recommande

| Etape | Action | Quand | Effort |
|-------|--------|-------|--------|
| 1 | Ajouter tests `recordDailyValue` (fix bug) | **Immediat** | 0.5j |
| 2 | Tests controllers au fur et a mesure de l'extraction | Sprint 7 Phases 3-4 | 3j |
| 3 | Tests providers | Apres extraction | 0.5j |
| 4 | Widget tests | Sprint 7 Phase 6 | 2j |
| 5 | Services manquants (game_history, scan_history, profile) | Sprint 7 ou 8 | 1.5j |
| 6 | Coverage dans CI (`--coverage --min-coverage 60`) | Fin Sprint 7 | 0.25j |

---

## 7. Risques QA

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Controllers non testables (couplage UI) | Haut | Extraire proprement, aucune reference a BuildContext dans le controller |
| Widget tests flaky (animations, async) | Moyen | pump/pumpAndSettle, mock services, pas de vrais timers |
| Regression lors extraction controllers | Haut | Lancer `flutter test` apres chaque extraction |
| Coverage < 60% malgre les efforts | Moyen | Prioriser les fichiers avec le plus de logique metier |

---

## 8. Verdict Nami

**Tresor actuel** : 165 tests, c'est une bonne base mais la couverture est inegale. Les services et modeles sont bien couverts, mais les widgets, providers et controllers (futurs) ne le sont pas du tout.

**Le plus gros manque** : Le fix `recordDailyValue` n'a **aucun test pour le cas du double appel**. C'est le meme bug qui a crashe en prod. Il faut un test de non-regression **maintenant**.

**Objectif Sprint 7** : Passer de 165 a >= 200 tests en ajoutant :
- 3 tests recordDailyValue (fix)
- ~30 tests controllers
- ~4 tests providers
- ~20 tests widgets

**Investissement QA** : ~7 jours (inclus dans le Sprint 7 estime a 13.25j)

*"Chaque test manquant est une dette de 1000 berrys. Avec 0 widget tests, on navigue a l'aveugle dans une tempete. Le fix recordDailyValue sans test de regression, c'est du vol pur et simple !"* -- Nami, QA Lead
