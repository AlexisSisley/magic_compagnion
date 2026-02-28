# Sprint 7 - Analyse Business : Refactoring God Files & Qualite
> Agent : Zorro (Business Analyst) | Date : 28/02/2026

---

## 1. Contexte

Apres 6 sprints d'amelioration progressive, Magic Companion a atteint un score qualite de **9.0/10** :
- **165 tests** passants, 0 erreurs analyse statique
- **14 providers Riverpod**, 10 tables drift SQLite
- **ScryfallApiService** centralise (Dio + cache + rate limiting) -- 100% des appels HTTP migres
- **go_router** declaratif (14 routes), main.dart reduit a 67 lignes
- 0 import `package:http/` dans les fichiers applicatifs

**Probleme residuel majeur** : 12 fichiers depassent 500 lignes, melangeant logique metier, gestion d'etat et UI dans le meme fichier. Cette architecture "God File" freine la testabilite, la lisibilite et la maintenance. De plus, 23 `Navigator.push` restent dans 15 fichiers au lieu d'utiliser go_router, et le package `http` traine encore dans pubspec.yaml.

**Objectif Sprint 7** : Decomposer les 6 God Files principaux en extrayant des controllers Riverpod, supprimer les dependances obsoletes, migrer les Navigator.push restants, et augmenter la couverture de tests a >60%.

---

## 2. Inventaire des God Files (>500 lignes, hors genere)

| # | Fichier | Lignes | Type | Responsabilites melangees |
|---|---------|--------|------|---------------------------|
| 1 | `set_detail_page.dart` | 1003 | Page | Chargement cartes, pagination, filtres, ajout collection/wishlist, stats, UI |
| 2 | `deck_detail_page.dart` | 850 | Page | CRUD cartes, batch fetch Scryfall, zones (main/side/considering/wishlist), partage, UI |
| 3 | `card_search_page.dart` | 830 | Page | Recherche API, recherche locale, pagination, filtres, tri, ajout collection/deck/wishlist, UI |
| 4 | `deck_card_picker.dart` | 774 | Widget | Recherche, pagination, selection multi, filtres, UI |
| 5 | `card_detail_page.dart` | 773 | Page | Fetch carte, rulings, legality, ajout collection/deck/wishlist, UI |
| 6 | `deck_list_page.dart` | 731 | Page | CRUD decks, import decklist, filtres, tri, stats, UI |
| 7 | `collection_list_tab.dart` | 715 | Widget | Affichage liste, filtres, tri, tags, actions contextuelles, UI |
| 8 | `player_zone.dart` | 674 | Widget | Affichage joueur, compteurs, couleurs, menus, gestes, UI |
| 9 | `app_router.dart` | 613 | Config | Routes, dialogs, drawer, guards |
| 10 | `deck_stats_tab.dart` | 612 | Widget | Calculs statistiques, graphiques, mana curve, UI |
| 11 | `scanner_page.dart` | 531 | Page | Camera, reconnaissance ML Kit, resultat scan, UI |
| 12 | `collection_page.dart` | 521 | Page | Chargement batch, onglets, import/export, stats, UI |
| 13 | `game_setup_modal.dart` | 507 | Widget | Configuration partie, profils, formats, UI |

**Scope Sprint 7** : Les 6 God Files pages principaux (#1-6) seront decomposes. Les widgets (#7-8, #10, #13) et le routeur (#9) sont hors scope (Sprint 8+).

---

## 3. Inventaire des Navigator.push restants

| Fichier | Occurrences push | Detail |
|---------|-----------------|--------|
| `scanner_page.dart` | 3 | Vers ScanHistoryPage, CardDetailPage |
| `wishlist_tab.dart` | 3 | Vers RecognitionResultPage, WishlistDetailPage |
| `collection_list_tab.dart` | 2 | Vers RecognitionResultPage |
| `deck_suggestions_tab.dart` | 2 | Vers RecognitionResultPage |
| `deck_card_list_tab.dart` | 2 | Vers RecognitionResultPage |
| `life_counter_page.dart` | 1 | Vers TournamentPage |
| `card_search_page.dart` | 1 | Vers RecognitionResultPage |
| `card_detail_page.dart` | 1 | Vers GlossaryDetailPage |
| `collection_sets_tab.dart` | 1 | Vers SetDetailPage |
| `deck_list_page.dart` | 1 | Vers DeckDetailPage |
| `collection_page.dart` | 1 | Vers GlobalStatsPage |
| `set_detail_page.dart` | 2 | Vers RecognitionResultPage, CardDetailPage |
| `scan_history_page.dart` | 1 | Vers CardDetailPage |
| `game_history_page.dart` | 1 | Vers GameHistoryDetailPage |
| `glossary_page.dart` | 1 | Vers GlossaryDetailPage |
| **Total** | **23** | **15 fichiers** |

**Note** : Les `Navigator.pop` (117 occurrences, 27 fichiers) sont legitimes pour fermer des dialogs/modales et ne seront pas migres (go_router ne remplace pas Navigator.pop pour les showDialog/showModalBottomSheet).

---

## 4. Inventaire upsert duplique

La logique "chercher par scryfallId, incrementer/remplacer quantite, gerer tags/foil" est repetee dans :

| Service | Methode | Lignes approx |
|---------|---------|---------------|
| `collection_service.dart` | `upsertCardInCollection()` + `_upsertInMemory()` | ~60 lignes |
| `deck_service.dart` | `upsertCardInDeck()` | ~50 lignes |
| `wishlist_service.dart` | `upsertCard()` | ~50 lignes |

Pattern commun : indexWhere(scryfallId) → si existe: update qty/tags → sinon: create. Extractible dans un mixin `CardListUpsertMixin`.

---

## 5. User Stories

### US-7.1 : Extraction SetDetailController
**En tant que** developpeur,
**je veux** extraire la logique metier de `set_detail_page.dart` (1003 lignes) dans un `SetDetailController` Riverpod,
**afin de** separer la logique de chargement/filtrage/pagination du rendu UI.

**Criteres d'acceptation :**
- [ ] `lib/controllers/set_detail_controller.dart` cree avec un AsyncNotifier
- [ ] Logique extraite : chargement des cartes d'un set, pagination, filtres, ajout collection/wishlist
- [ ] `set_detail_page.dart` ne contient que du code UI (build, widgets)
- [ ] `set_detail_page.dart` < 400 lignes
- [ ] Fonctionnement identique (pas de regression visuelle)
- [ ] Tests unitaires du controller (>= 5 tests)

**Priorite** : P0 | **Effort** : 2j

---

### US-7.2 : Extraction DeckDetailController
**En tant que** developpeur,
**je veux** extraire la logique metier de `deck_detail_page.dart` (850 lignes) dans un `DeckDetailController`,
**afin de** pouvoir tester la gestion des zones (mainboard/sideboard/considering/wishlist) isolement.

**Criteres d'acceptation :**
- [ ] `lib/controllers/deck_detail_controller.dart` cree
- [ ] Logique extraite : CRUD cartes dans les 4 zones, batch fetch Scryfall, partage/export
- [ ] `deck_detail_page.dart` < 400 lignes
- [ ] Tests unitaires du controller (>= 5 tests)

**Priorite** : P0 | **Effort** : 2j

---

### US-7.3 : Extraction CardSearchController
**En tant que** developpeur,
**je veux** extraire la logique metier de `card_search_page.dart` (830 lignes) dans un `CardSearchController`,
**afin de** separer recherche API/locale, pagination et filtres du rendu.

**Criteres d'acceptation :**
- [ ] `lib/controllers/card_search_controller.dart` cree
- [ ] Logique extraite : recherche API Scryfall, recherche locale, pagination, filtres, tri, ajout aux collections/decks/wishlists
- [ ] `card_search_page.dart` < 350 lignes
- [ ] Tests unitaires du controller (>= 5 tests)

**Priorite** : P0 | **Effort** : 1.5j

---

### US-7.4 : Extraction CardDetailController
**En tant que** developpeur,
**je veux** extraire la logique metier de `card_detail_page.dart` (773 lignes) dans un `CardDetailController`,
**afin de** separer le fetch carte/rulings/legality du rendu.

**Criteres d'acceptation :**
- [ ] `lib/controllers/card_detail_controller.dart` cree
- [ ] Logique extraite : fetch exact card, search candidates, fetch rulings, ajout collection/deck/wishlist
- [ ] `card_detail_page.dart` < 400 lignes
- [ ] Tests unitaires du controller (>= 4 tests)

**Priorite** : P0 | **Effort** : 1.5j

---

### US-7.5 : Extraction DeckListController + CollectionController
**En tant que** developpeur,
**je veux** extraire la logique metier de `deck_list_page.dart` (731 lignes) et `collection_page.dart` (521 lignes),
**afin de** reduire ces deux fichiers sous 300 lignes.

**Criteres d'acceptation :**
- [ ] `lib/controllers/deck_list_controller.dart` cree
- [ ] `lib/controllers/collection_controller.dart` cree
- [ ] `deck_list_page.dart` < 300 lignes
- [ ] `collection_page.dart` < 300 lignes
- [ ] Tests unitaires des 2 controllers (>= 4 tests chacun)

**Priorite** : P0 | **Effort** : 1.5j

---

### US-7.6 : Mixin CardListUpsert
**En tant que** developpeur,
**je veux** extraire la logique upsert dupliquee dans un mixin commun `CardListUpsertMixin`,
**afin de** supprimer la duplication entre collection_service, deck_service et wishlist_service.

**Criteres d'acceptation :**
- [ ] `lib/utils/card_list_upsert_mixin.dart` cree
- [ ] Logique commune extraite : indexWhere, update qty, create, gestion tags/foil
- [ ] Les 3 services utilisent le mixin au lieu de dupliquer la logique
- [ ] 165 tests existants toujours verts
- [ ] Tests du mixin (>= 3 tests)

**Priorite** : P1 | **Effort** : 1j

---

### US-7.7 : Migration Navigator.push vers go_router
**En tant que** developpeur,
**je veux** migrer les 23 `Navigator.push` restants vers `context.push`/`context.go` de go_router,
**afin d'** unifier la navigation et supporter le deep linking.

**Criteres d'acceptation :**
- [ ] 0 `Navigator.push` dans les fichiers applicatifs (hors showDialog/showModalBottomSheet)
- [ ] Nouvelles routes ajoutees dans `app_router.dart` si necessaires (RecognitionResultPage, GlossaryDetailPage, GlobalStatsPage, TournamentPage, GameHistoryDetailPage, etc.)
- [ ] `Navigator.pop` conserves uniquement pour les dialogs/modales (usage legitime)
- [ ] Navigation fonctionnelle partout (pas de regression)

**Priorite** : P1 | **Effort** : 1.5j

---

### US-7.8 : Suppression package http
**En tant que** developpeur,
**je veux** supprimer le package `http` du pubspec.yaml,
**afin de** confirmer que 100% des appels HTTP passent par Dio/ScryfallApiService.

**Criteres d'acceptation :**
- [ ] Ligne `http: ^1.2.1` supprimee du pubspec.yaml
- [ ] `flutter pub get` reussit sans erreur
- [ ] `flutter analyze` : 0 erreurs
- [ ] `flutter test` : tous les tests passent

**Priorite** : P1 | **Effort** : 0.25j

---

### US-7.9 : Widget Tests composants critiques
**En tant que** developpeur,
**je veux** des widget tests pour les composants les plus utilises,
**afin d'** atteindre >60% de couverture et prevenir les regressions UI.

**Criteres d'acceptation :**
- [ ] Widget tests pour `PlayerZone` (affichage compteurs, gestes +1/-1, changement couleur)
- [ ] Widget tests pour `ScryfallImage` (chargement, placeholder, erreur)
- [ ] Widget tests pour `DeckCardListTab` (affichage liste, actions contextuelles)
- [ ] Widget tests pour `GameSetupModal` (selection format, joueurs)
- [ ] Total tests >= 200
- [ ] Couverture > 60%

**Priorite** : P2 | **Effort** : 2j

---

## 6. Approche technique

### Pattern Controller Riverpod

Chaque God File sera decompose selon le pattern :

```dart
// lib/controllers/xxx_controller.dart
@riverpod
class XxxController extends _$XxxController {
  // Etat : AsyncValue<XxxState>
  // Logique metier : load, search, filter, add, remove, etc.
}

// lib/pages/xxx_page.dart
class XxxPage extends ConsumerStatefulWidget {
  // UI pure : build(), widgets, animations
  // Accede au controller via ref.watch/read(xxxControllerProvider)
}
```

### Ordre d'execution recommande

1. **US-7.8** (suppression http) -- quick win, 0.25j
2. **US-7.6** (mixin upsert) -- prerequis pour certains controllers
3. **US-7.1 a US-7.5** (extraction controllers) -- coeur du sprint, en parallele si possible
4. **US-7.7** (migration Navigator.push) -- apres les controllers pour eviter les conflits
5. **US-7.9** (widget tests) -- a la fin, quand le code est stabilise

### Migration Navigator.push : Routes a ajouter

| Route | Page cible | Parametre |
|-------|-----------|-----------|
| `/cards/:cardName` | RecognitionResultPage | cardName (String) |
| `/glossary/:keyword` | GlossaryDetailPage | keyword (String) |
| `/collection/stats` | GlobalStatsPage | collection data |
| `/tournament` | TournamentPage | - |
| `/game-history/:id` | GameHistoryDetailPage | gameId (String) |

---

## 7. Risques

| ID | Risque | Impact | Probabilite | Mitigation |
|----|--------|--------|-------------|------------|
| R-7.1 | Regression UI lors de l'extraction des controllers | Haut | Moyen | Garder le meme state, ne deplacer que la logique. Test manuel avant/apres |
| R-7.2 | Circular dependency entre controller et page | Moyen | Faible | Controller ne connait jamais la page, seulement les services |
| R-7.3 | Widget tests flaky (async, animations) | Faible | Moyen | pump/pumpAndSettle, mock des services |
| R-7.4 | Migration Navigator.push casse la navigation retour (pop) | Moyen | Moyen | Tester chaque flux de navigation manuellement |
| R-7.5 | Suppression http casse une dep transitive | Faible | Faible | `flutter pub get` + `flutter test` avant/apres |
| R-7.6 | Mixin trop generique, ne couvre pas les cas edge | Faible | Faible | Garder les specialisations dans les services, mixin pour le commun |

---

## 8. Estimation

| User Story | Effort | Priorite |
|------------|--------|----------|
| US-7.1 : SetDetailController | 2j | P0 |
| US-7.2 : DeckDetailController | 2j | P0 |
| US-7.3 : CardSearchController | 1.5j | P0 |
| US-7.4 : CardDetailController | 1.5j | P0 |
| US-7.5 : DeckListController + CollectionController | 1.5j | P0 |
| US-7.6 : Mixin CardListUpsert | 1j | P1 |
| US-7.7 : Migration Navigator.push | 1.5j | P1 |
| US-7.8 : Suppression package http | 0.25j | P1 |
| US-7.9 : Widget Tests | 2j | P2 |
| **Total** | **13.25j** | - |

---

## 9. Hors Scope Sprint 7

- Extraction controllers pour widgets (collection_list_tab, player_zone, deck_stats_tab, game_setup_modal) → Sprint 8
- Refactoring app_router.dart (613 lignes) → Sprint 8
- Chiffrement BDD SQLite
- Migration SharedPreferences residuel (glossaryLang dans card_search_page)
- Internationalisation (i18n)
- Mise a jour automatique base locale (Bulk Data Scryfall)
- Optimisation scanner ML Kit

*"Six God Files, six coups d'epee. Chaque controller sera aussi tranchant que Wado Ichimonji."* -- Zorro
