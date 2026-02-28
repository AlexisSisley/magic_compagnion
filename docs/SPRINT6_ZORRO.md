# Sprint 6 - Analyse Business : Migration HTTP Pages & Refactoring God Files
> Agent : Zorro (Business Analyst) | Date : 28/02/2026

---

## 1. Contexte

Apres 5 sprints d'amelioration (fondations, Riverpod, tests, drift, go_router+Dio), Magic Companion dispose de :
- **165 tests** passants, 0 erreurs analyse
- **14 providers Riverpod** avec injection AppDatabase + ScryfallApiService
- **ScryfallApiService** centralise (cache memoire, rate limiting 10 req/sec, logging)
- **go_router** avec ShellRoute (14 routes, main.dart 67 lignes)
- Score qualite : **8.5/10**

**Probleme residuel majeur** : 9 fichiers (pages + widgets) font encore des appels HTTP directs via le package `http`, contournant le ScryfallApiService. De plus, 6 fichiers "God Files" depassent 500 lignes, melant logique metier et UI.

**Objectif Sprint 6** : Eliminer tous les appels HTTP directs des pages/widgets et migrer vers ScryfallApiService. Viser 9.0/10 en qualite.

---

## 2. Inventaire des appels HTTP directs (9 fichiers, 13 appels)

| Fichier | Appels | Type | Detail |
|---------|--------|------|--------|
| `card_search_page.dart` | 2 | GET | search + pagination next_page |
| `card_detail_page.dart` | 3 | GET | exact card by set/cn, search candidates, rulings |
| `deck_detail_page.dart` | 1 | POST | collection batch (identifiers par id) |
| `deck_list_page.dart` | 1 | GET | search pour import decklist |
| `set_detail_page.dart` | 1+ | GET | pagination set cards (boucle while) |
| `collection_page.dart` | 1 | POST | collection batch (identifiers par id) |
| `wishlist_detail_page.dart` | 1 | POST | collection batch (identifiers par id) |
| `versions_selector_sheet.dart` | 1 | GET | search par oracle_id unique=prints |
| `deck_card_picker.dart` | 2 | GET | search + pagination next_page |

---

## 3. User Stories

### US-6.1 : Migration HTTP card_search_page
**En tant que** developpeur,
**je veux** migrer les 2 appels HTTP de card_search_page vers ScryfallApiService,
**afin de** beneficier du cache, rate limiting et logging centralise.

**Criteres d'acceptation :**
- [ ] `_searchCardsApi()` utilise `ScryfallApiService.searchCards()` au lieu de `http.get()`
- [ ] `_loadMoreApiResults()` utilise `ScryfallApiService.fetchNextPage()` au lieu de `http.get()`
- [ ] Import `http` supprime du fichier
- [ ] Fonctionnement identique (pagination, filtres, tri)

**Priorite** : P0 | **Effort** : 0.5j

---

### US-6.2 : Migration HTTP card_detail_page
**En tant que** developpeur,
**je veux** migrer les 3 appels HTTP de card_detail_page vers ScryfallApiService,
**afin de** centraliser tous les appels Scryfall.

**Criteres d'acceptation :**
- [ ] `_fetchExactCard()` utilise `ScryfallApiService.getCardBySetAndNumber()`
- [ ] `_searchForCandidates()` utilise `ScryfallApiService.searchCards()`
- [ ] `_fetchRulings()` utilise `ScryfallApiService.getCardRulings()`
- [ ] Import `http` supprime du fichier
- [ ] Import `dart:convert` supprime si plus utilise (Dio parse auto le JSON)

**Priorite** : P0 | **Effort** : 0.5j

---

### US-6.3 : Migration HTTP pages batch (deck_detail, collection, wishlist_detail)
**En tant que** developpeur,
**je veux** migrer les appels POST `/cards/collection` dans 3 fichiers,
**afin d'** unifier les requetes batch via ScryfallApiService.

**Criteres d'acceptation :**
- [ ] `deck_detail_page.dart` : `_loadFullCardData()` utilise `ScryfallApiService.fetchCollection()`
- [ ] `collection_page.dart` : `_loadFullCardData()` utilise `ScryfallApiService.fetchCollection()`
- [ ] `wishlist_detail_page.dart` : `_loadFullCardData()` utilise `ScryfallApiService.fetchCollection()`
- [ ] Import `http` supprime des 3 fichiers
- [ ] Logique de chunking (75 par batch) preservee

**Priorite** : P0 | **Effort** : 0.5j

---

### US-6.4 : Migration HTTP widgets (deck_card_picker, versions_selector_sheet)
**En tant que** developpeur,
**je veux** migrer les appels HTTP des 2 widgets,
**afin d'** eliminer les derniers imports `http` du projet.

**Criteres d'acceptation :**
- [ ] `deck_card_picker.dart` : search + pagination via ScryfallApiService
- [ ] `versions_selector_sheet.dart` : search par oracle_id via ScryfallApiService
- [ ] Import `http` supprime des 2 fichiers

**Priorite** : P0 | **Effort** : 0.5j

---

### US-6.5 : Migration HTTP restants (set_detail_page, deck_list_page)
**En tant que** developpeur,
**je veux** migrer les appels HTTP de set_detail_page et deck_list_page,
**afin de** completer la migration HTTP a 100%.

**Criteres d'acceptation :**
- [ ] `set_detail_page.dart` : boucle de pagination utilise ScryfallApiService
- [ ] `deck_list_page.dart` : search import decklist utilise ScryfallApiService
- [ ] Import `http` supprime des 2 fichiers
- [ ] Package `http` supprime du pubspec.yaml

**Priorite** : P0 | **Effort** : 0.5j

---

### US-6.6 : Tests Sprint 6
**En tant que** developpeur,
**je veux** des tests validant la migration HTTP,
**afin de** garantir la non-regression.

**Criteres d'acceptation :**
- [ ] Les 165 tests existants passent toujours
- [ ] Total >= 170 tests
- [ ] Aucun import `package:http/` dans lib/ (sauf si dep transitive)

**Priorite** : P1 | **Effort** : 0.5j

---

## 4. Approche technique

### Migration HTTP : Pattern commun

Chaque page/widget migre doit :
1. **Ajouter** `ScryfallApiService` via `ref.read(scryfallApiServiceProvider)` (pages Consumer) ou via parametre constructeur (widgets StatefulWidget)
2. **Remplacer** `http.get(Uri.parse(...))` par le bon appel ScryfallApiService
3. **Adapter** le parsing : Dio retourne deja un `Map<String, dynamic>` (pas besoin de `json.decode(utf8.decode(response.bodyBytes))`)
4. **Supprimer** les imports `http` et `dart:convert` (si plus utilise)

### Pour les widgets non-Consumer (StatefulWidget)

`versions_selector_sheet.dart` et `set_detail_page.dart` ne sont pas des ConsumerWidget. Options :
- **Option A** : Les convertir en ConsumerStatefulWidget (ajouter ref.read)
- **Option B** : Passer ScryfallApiService en parametre constructeur

→ **Decision : Option A** pour versions_selector_sheet (deja dans un contexte Riverpod).
→ **Decision : Option B** pour set_detail_page (deja passe CollectionService/WishlistService en constructeur).

---

## 5. Risques

| ID | Risque | Impact | Probabilite | Mitigation |
|----|--------|--------|-------------|------------|
| R-6.1 | Regression pagination (next_page) | Moyen | Faible | ScryfallApiService.fetchNextPage() deja teste (Sprint 5) |
| R-6.2 | Dio parse auto JSON different de utf8.decode | Faible | Faible | Dio utilise utf8 par defaut, valide en Sprint 5 |
| R-6.3 | Widgets non-Consumer necessitent refactoring | Faible | Certain | Option B (parametre constructeur) pour minimiser le diff |
| R-6.4 | SharedPreferences residuel dans card_search_page | Faible | Certain | Migrer vers AppSettings drift si temps, sinon documenter |

---

## 6. Estimation

| User Story | Effort | Priorite |
|------------|--------|----------|
| US-6.1 : card_search_page | 0.5j | P0 |
| US-6.2 : card_detail_page | 0.5j | P0 |
| US-6.3 : 3 pages batch | 0.5j | P0 |
| US-6.4 : 2 widgets | 0.5j | P0 |
| US-6.5 : set_detail + deck_list | 0.5j | P0 |
| US-6.6 : Tests | 0.5j | P1 |
| **Total** | **3j** | - |

---

## 7. Hors Scope Sprint 6

- Refactoring des God Files (>500 lignes) → reporte a un futur sprint (scope ajuste)
- Suppression du fallback SharedPreferences dans les services
- Widget tests
- Migration des Navigator.push restants vers go_router
- Chiffrement de la base de donnees

*"Trois epees, treize appels HTTP a trancher. Pas un de plus, pas un de moins."* -- Zorro
