# Sprint 9 - Architecture Technique : Quick Wins Features
> Agent : Sanji (Architecte) | Date : 01/03/2026

---

## Phase 1 : Comprehension du Probleme & Perimetre

### Perimetre fonctionnel
- **Inclus** : 5 features utilisateur (indicateur collection, tri prix, bouton ajout deck, filtre budget, tokens deck)
- **Exclu** : Refactoring technique, i18n, import/export, chiffrement BDD, extraction controllers widgets (Sprint 8 backlog)

### Stack existante (inchangee)
- **Langage** : Dart 3.9+ / Flutter 3.35.6
- **State Management** : Riverpod (StateNotifier + AutoDispose)
- **Base de donnees** : drift (SQLite)
- **Navigation** : go_router (23 routes)
- **HTTP** : Dio + cache memoire + rate limiting (ScryfallApiService)
- **CI/CD** : GitHub Actions
- **Tests** : 273 tests, flutter_test

### NFR
- 0 regression fonctionnelle
- 273 tests verts en permanence
- Performances inchangees (lookup collection O(1))
- Budget API Scryfall : respecter le rate limit 10 req/sec

### Projet existant
**PROJECT_PATH** = `C:/Users/Alexi/Documents/projet/magic_compagnion/`

Ce sprint ne cree PAS de nouveau projet. Il ajoute des features au projet existant.

---

## Phase 2 : Choix Techniques

| Choix | Decision | Justification |
|-------|----------|---------------|
| Lookup collection | `Set<String>` en memoire dans CardSearchState | O(1) au lieu de O(n) pour chaque carte affichee |
| Tri par prix API | Parametre `order: 'eur'` de l'API Scryfall | Natif, pas de tri cote client pour les resultats API |
| Tri par prix local | Comparateur Dart sur `prices['eur']` | Base locale ne supporte pas le tri par prix, traitement cote client |
| Filtre prix max | Ajout a `SearchFilters` + filtre cote client | L'API Scryfall supporte `eur<=X` dans la query mais la syntaxe est complexe -- filtre cote client plus simple et unifie API/local |
| Tokens | Parse `all_parts` dans `ScryfallCard.fromJson` + requete API pour les images | `all_parts` donne les references, une requete `/cards/collection` recupere les details |
| Bouton ajout deck | Reutilisation de `DeckPickerModal` existant | Zero code nouveau pour le modal, juste un bouton dans la UI |

---

## Phase 3 : Architecture des Changements

### 3.1 US-9.1 : Indicateur de Collection

#### Modification du modele de donnees

Aucune modification de `ScryfallCard` ni de `DeckCard`. On utilise les donnees existantes.

#### Modification de `CardSearchState`

Ajout d'un index rapide pour la collection :

```dart
// Dans card_search_controller.dart - CardSearchState
class CardSearchState {
  // ... champs existants ...
  final Map<String, int> collectionIndex;      // scryfallId -> quantite normale
  final Map<String, int> collectionFoilIndex;  // scryfallId -> quantite foil
  final Set<String> wishlistCardNames;          // noms des cartes en wishlist

  // Computed property
  CollectionBadge? getBadge(String scryfallId, String cardName) {
    final normal = collectionIndex[scryfallId] ?? 0;
    final foil = collectionFoilIndex[scryfallId] ?? 0;
    final inWishlist = wishlistCardNames.contains(cardName);
    if (normal == 0 && foil == 0 && !inWishlist) return null;
    return CollectionBadge(normalCount: normal, foilCount: foil, inWishlist: inWishlist);
  }
}

class CollectionBadge {
  final int normalCount;
  final int foilCount;
  final bool inWishlist;
  int get totalCount => normalCount + foilCount;
  bool get isOwned => totalCount > 0;
  const CollectionBadge({this.normalCount = 0, this.foilCount = 0, this.inWishlist = false});
}
```

#### Modification de `CardSearchController.loadLocalData()`

```dart
Future<void> loadLocalData() async {
  final collection = await _collectionService.loadCollection();
  final wishlists = await _wishlistService.loadWishlists();
  final allWishlistCards = wishlists.expand((w) => w.cards).toList();

  // Index rapide pour le badge
  final Map<String, int> collIdx = {};
  final Map<String, int> foilIdx = {};
  for (final card in collection) {
    if (card.isFoil) {
      foilIdx[card.scryfallId] = (foilIdx[card.scryfallId] ?? 0) + card.quantity;
    } else {
      collIdx[card.scryfallId] = (collIdx[card.scryfallId] ?? 0) + card.quantity;
    }
  }
  final wishlistNames = allWishlistCards.map((c) => c.name).toSet();

  if (!mounted) return;
  state = state.copyWith(
    collection: collection,
    flatWishlist: allWishlistCards,
    collectionIndex: collIdx,
    collectionFoilIndex: foilIdx,
    wishlistCardNames: wishlistNames,
  );
}
```

#### Modification de `SetDetailController`

Le `SetDetailController` charge deja la collection pour les stats. Ajouter le meme index :

```dart
// Dans set_detail_controller.dart - SetDetailState
final Map<String, int> collectionIndex;
final Map<String, int> collectionFoilIndex;
```

#### Nouveau widget : `CollectionBadgeWidget`

```
lib/widgets/common/collection_badge.dart (~60 lignes)
```

```dart
class CollectionBadgeWidget extends StatelessWidget {
  final CollectionBadge? badge;
  const CollectionBadgeWidget({super.key, this.badge});

  @override
  Widget build(BuildContext context) {
    if (badge == null) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (badge!.isOwned)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('x${badge!.totalCount}', style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      if (badge!.inWishlist)
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.favorite, color: Colors.pinkAccent, size: 14),
        ),
    ]);
  }
}
```

#### Points d'integration UI

| Fichier | Modification |
|---------|-------------|
| `card_search_page.dart` | Ajouter `CollectionBadgeWidget` sur chaque tuile de resultat |
| `set_detail_page.dart` | Ajouter `CollectionBadgeWidget` sur chaque tuile de carte du set |
| `card_detail_page.dart` | Afficher "Dans ma collection : X normaux + Y foils" dans la section info |

---

### 3.2 US-9.2 : Tri par Prix

#### Modification de `CardSearchController`

Le controller a deja un champ `sortBy` et une methode de tri. Ajouter les options de tri par prix :

```dart
// Ajout dans la methode de tri existante (sortResults ou equivalent)
case 'price_desc':
  results.sort((a, b) =>
    (double.tryParse(b.prices['eur']?.toString() ?? '0') ?? 0)
        .compareTo(double.tryParse(a.prices['eur']?.toString() ?? '0') ?? 0));
  break;
case 'price_asc':
  results.sort((a, b) =>
    (double.tryParse(a.prices['eur']?.toString() ?? '0') ?? 0)
        .compareTo(double.tryParse(b.prices['eur']?.toString() ?? '0') ?? 0));
  break;
```

#### Modification de la recherche API

L'API Scryfall supporte le tri par prix nativement :

```dart
// Dans CardSearchController._performApiSearch()
String? apiOrder;
String? apiDir;
if (state.sortBy == 'price_desc') { apiOrder = 'eur'; apiDir = 'desc'; }
if (state.sortBy == 'price_asc') { apiOrder = 'eur'; apiDir = 'asc'; }

final result = await _apiService.searchCards(query, order: apiOrder, dir: apiDir);
```

#### Modification UI

| Fichier | Modification |
|---------|-------------|
| `card_search_page.dart` | Ajouter les options "Prix (cher -> pas cher)" et "Prix (pas cher -> cher)" dans le dropdown de tri |
| `collection_list_tab.dart` | Ajouter l'option tri par prix dans le widget collection (si pas deja fait dans collection_controller) |

**Note** : Le `collection_controller.dart` a deja un tri par prix (`case 'price'` dans `_applySort`). Il faut juste s'assurer que l'UI offre le bouton.

---

### 3.3 US-9.3 : Bouton "Ajouter au Deck"

#### Modification de `card_detail_page.dart`

Ajouter un bouton dans la barre d'actions existante :

```dart
// Dans la methode build de _RecognitionResultPageState
// A cote des boutons existants (collection, wishlist)
IconButton(
  icon: const Icon(Icons.playlist_add, color: Colors.white),
  tooltip: 'Ajouter au deck',
  onPressed: () {
    if (state.foundCard != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => DeckPickerModal(
          deckService: controller.deckService,
          cardToAdd: state.foundCard!,
          onCardAdded: (deckName, cardName) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$cardName ajoutee a $deckName')),
            );
          },
        ),
      );
    }
  },
),
```

**Effort** : ~15 lignes de code. Le `DeckPickerModal` existe deja et fonctionne.

**Note** : Le `DeckPickerModal` utilise actuellement `Navigator.pop(context)` (ligne 80 de deck_picker_modal.dart). Cela fonctionne avec `showModalBottomSheet` donc pas de modification necessaire.

---

### 3.4 US-9.4 : Filtre Budget (Prix Maximum)

#### Modification de `SearchFilters`

```dart
// Dans lib/models/search_filters.dart
class SearchFilters {
  // ... champs existants ...
  final double? maxPrice;  // NOUVEAU : prix max EUR

  SearchFilters({
    // ... existants ...
    this.maxPrice,
  });

  SearchFilters copyWith({
    // ... existants ...
    double? maxPrice,
    bool clearMaxPrice = false,
  }) {
    return SearchFilters(
      // ... existants ...
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
    );
  }
}
```

#### Modification de `CardSearchController`

Ajouter le filtre cote client apres reception des resultats (API ou local) :

```dart
List<ScryfallCard> _applyPriceFilter(List<ScryfallCard> cards) {
  final maxPrice = state.activeFilters.maxPrice;
  if (maxPrice == null) return cards;
  return cards.where((card) {
    final priceStr = card.prices['eur']?.toString();
    if (priceStr == null) return false; // Exclure les cartes sans prix
    final price = double.tryParse(priceStr) ?? 0;
    return price <= maxPrice;
  }).toList();
}
```

#### Modification du `hasActiveFilters`

```dart
// Dans CardSearchState
bool get hasActiveFilters =>
    activeFilters.setCode != null ||
    activeFilters.cardType != null ||
    activeFilters.colors.isNotEmpty ||
    activeFilters.minCmc != null ||
    activeFilters.maxCmc != null ||
    activeFilters.rarity != null ||
    activeFilters.keyword != null ||
    activeFilters.maxPrice != null;  // NOUVEAU
```

#### Modification UI

| Fichier | Modification |
|---------|-------------|
| `search_filter_modal.dart` ou `universal_filter_modal.dart` | Ajouter un champ `TextField` pour le prix max avec un `InputDecoration` "Prix max (EUR)" |
| `card_search_page.dart` | Passer le filtre `maxPrice` a la methode de recherche |

---

### 3.5 US-9.5 : Tokens Requis par le Deck

#### Modification du modele `ScryfallCard`

Ajouter le parsing du champ `all_parts` de l'API Scryfall :

```dart
// Dans lib/models/scryfall_card_model.dart
class ScryfallCard {
  // ... champs existants ...
  final List<RelatedCard> allParts;  // NOUVEAU

  ScryfallCard({
    // ... existants ...
    this.allParts = const [],
  });

  factory ScryfallCard.fromJson(Map<String, dynamic> json) {
    // ... parsing existant ...

    // Parse all_parts (tokens, emblemes, meld parts)
    final List<RelatedCard> parts = [];
    if (json['all_parts'] != null) {
      for (final part in json['all_parts'] as List) {
        parts.add(RelatedCard.fromJson(part as Map<String, dynamic>));
      }
    }

    return ScryfallCard(
      // ... existants ...
      allParts: parts,
    );
  }
}

/// Carte reliee (token, embleme, meld part)
class RelatedCard {
  final String id;
  final String component; // "token", "meld_part", "meld_result", "combo_piece"
  final String name;
  final String typeLine;
  final String uri;

  const RelatedCard({
    required this.id,
    required this.component,
    required this.name,
    required this.typeLine,
    required this.uri,
  });

  factory RelatedCard.fromJson(Map<String, dynamic> json) {
    return RelatedCard(
      id: json['id'] ?? '',
      component: json['component'] ?? '',
      name: json['name'] ?? '',
      typeLine: json['type_line'] ?? '',
      uri: json['uri'] ?? '',
    );
  }

  bool get isToken => component == 'token';
}
```

#### Nouveau service : logique d'extraction des tokens du deck

Pas de nouveau service -- on ajoute une methode dans `DeckDetailController` :

```dart
// Dans deck_detail_controller.dart
Future<List<TokenInfo>> computeDeckTokens() async {
  final deck = state.currentDeck;
  final allCards = [...deck.mainboard, ...deck.sideboard];
  final uniqueIds = allCards.map((c) => c.scryfallId).where((id) => !id.startsWith('LOCAL:')).toSet();

  // Charger les ScryfallCard pour chaque carte du deck
  final Map<String, ScryfallCard> cardData = state.cardData;

  // Extraire les tokens uniques
  final Map<String, RelatedCard> tokenMap = {};
  for (final entry in cardData.entries) {
    for (final part in entry.value.allParts) {
      if (part.isToken && !tokenMap.containsKey(part.id)) {
        tokenMap[part.id] = part;
      }
    }
  }

  return tokenMap.values.map((t) => TokenInfo(
    id: t.id,
    name: t.name,
    typeLine: t.typeLine,
  )).toList();
}
```

#### Nouveau widget : `DeckTokensTab`

```
lib/widgets/decks/deck_tokens_tab.dart (~120 lignes)
```

Affiche la liste des tokens avec images Scryfall :

```dart
class DeckTokensTab extends ConsumerWidget {
  final String deckId;
  const DeckTokensTab({super.key, required this.deckId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deckDetailControllerProvider(deckId));
    final tokens = state.tokens; // Computed from allParts

    if (tokens.isEmpty) {
      return Center(child: Text('Ce deck ne necessite aucun token'));
    }

    return ListView.builder(
      itemCount: tokens.length,
      itemBuilder: (context, index) {
        final token = tokens[index];
        return ListTile(
          leading: ScryfallImage(imageUrl: token.imageUrl ?? '', size: 50),
          title: Text(token.name),
          subtitle: Text(token.typeLine),
        );
      },
    );
  }
}
```

#### Integration dans le detail du deck

| Fichier | Modification |
|---------|-------------|
| `deck_detail_page.dart` | Ajouter un onglet "Tokens" dans le `TabBar` existant |
| `deck_detail_controller.dart` | Ajouter la propriete `tokens` dans `DeckDetailState` et le calcul dans `_loadDeckData` |

---

## Phase 4 : Architecture Fichiers Modifies/Crees

```
lib/
  models/
    scryfall_card_model.dart      MODIFIE (ajout allParts, RelatedCard)
    search_filters.dart           MODIFIE (ajout maxPrice)

  controllers/
    card_search_controller.dart   MODIFIE (index collection, tri prix, filtre prix)
    card_detail_controller.dart   (inchange - a deja collectionCount)
    set_detail_controller.dart    MODIFIE (ajout index collection pour badges)
    deck_detail_controller.dart   MODIFIE (ajout tokens computed)

  widgets/
    common/
      collection_badge.dart       NOUVEAU (~60 lignes)
    decks/
      deck_tokens_tab.dart        NOUVEAU (~120 lignes)

  pages/
    cards/
      card_detail_page.dart       MODIFIE (ajout bouton "Ajouter au deck" + badge collection)
      card_search_page.dart       MODIFIE (ajout badges collection + options tri prix)
    collections/
      set_detail_page.dart        MODIFIE (ajout badges collection)
    decks/
      deck_detail_page.dart       MODIFIE (ajout onglet Tokens)

  -- FILTRES --
  widgets/search/
    search_filter_modal.dart      MODIFIE (ajout champ prix max)
    ou universal_filter_modal.dart MODIFIE (ajout champ prix max)

test/
  controllers/
    card_search_controller_test.dart  MODIFIE (ajout tests tri prix + filtre + badges)
  models/
    scryfall_card_model_test.dart     MODIFIE (ajout tests allParts parsing)
  widgets/
    collection_badge_test.dart        NOUVEAU (~10 tests)
```

---

## Phase 5 : Risques Techniques & Strategie de Test

### Risques

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| Performance badge : boucle O(n) sur la collection a chaque build | Haut | Moyen | Index `Map<String, int>` precalcule dans le State, lookup O(1) |
| `all_parts` absent de la base locale oracle-cards.json | Moyen | Faible | Le champ existe dans le fichier Oracle de Scryfall. Tester avec une carte connue (Avenger of Zendikar) |
| Modification de `ScryfallCard.fromJson` casse le parsing existant | Haut | Faible | Le champ `allParts` a un default `const []` -- pas de regression si absent du JSON |
| Filtre prix max sur API : Scryfall ne filtre pas par prix dans `q` | Moyen | Faible | Filtrage cote client apres reception des resultats. Performance OK car pagine par 175 |
| Onglet Tokens dans TabBar : overflow si trop d'onglets | Faible | Faible | `TabBar` Flutter est scrollable par defaut avec `isScrollable: true` |

### Strategie de Test

**Nouveaux tests Sprint 9** :

| Fichier test | Tests prevus | Type |
|-------------|-------------|------|
| collection_badge_test.dart | 6 (owned, foil, wishlist, combined, null, empty) | Unit |
| card_search_controller_test.dart | 4 (tri prix asc/desc, filtre prix, index collection) | Unit |
| scryfall_card_model_test.dart | 3 (parse allParts, allParts empty, RelatedCard.isToken) | Unit |
| deck_detail_controller_test.dart | 3 (compute tokens, empty deck, no tokens) | Unit |
| search_filters_test.dart | 2 (maxPrice copyWith, hasActiveFilters) | Unit |
| **Total nouveaux** | **~18** | |
| **Total cumule** | **~291** | **(273 + 18)** |

Cible : >285 tests (conservateur car certaines features sont principalement UI).

---

## Plan d'Execution

### Phase 1 : Modeles & Infrastructure (0.5j)

| # | Tache | Effort |
|---|-------|--------|
| 1 | Ajouter `RelatedCard` et `allParts` dans `ScryfallCard.fromJson` | 0.25j |
| 2 | Ajouter `maxPrice` dans `SearchFilters` | 0.1j |
| 3 | Tests modeles (parse allParts, RelatedCard, SearchFilters) | 0.15j |

### Phase 2 : US-9.1 Indicateur Collection (1.5j)

| # | Tache | Effort |
|---|-------|--------|
| 4 | Ajouter `collectionIndex`, `collectionFoilIndex`, `wishlistCardNames` dans `CardSearchState` | 0.25j |
| 5 | Modifier `CardSearchController.loadLocalData()` pour construire les index | 0.25j |
| 6 | Creer `CollectionBadgeWidget` dans `lib/widgets/common/` | 0.25j |
| 7 | Integrer le badge dans `card_search_page.dart` | 0.25j |
| 8 | Integrer le badge dans `set_detail_page.dart` (via SetDetailController) | 0.25j |
| 9 | Tests badge widget + tests controller | 0.25j |

### Phase 3 : US-9.2 + US-9.4 Tri & Filtre Prix (1j)

| # | Tache | Effort |
|---|-------|--------|
| 10 | Ajouter options `price_asc`/`price_desc` dans le tri du CardSearchController | 0.15j |
| 11 | Passer `order`/`dir` a l'API Scryfall pour le tri prix | 0.1j |
| 12 | Ajouter le champ "Prix max" dans le modal de filtres | 0.25j |
| 13 | Implementer `_applyPriceFilter` dans le controller | 0.15j |
| 14 | Ajouter les boutons de tri prix dans la UI recherche | 0.15j |
| 15 | Tests tri + filtre | 0.2j |

### Phase 4 : US-9.3 Bouton Ajout Deck (0.5j)

| # | Tache | Effort |
|---|-------|--------|
| 16 | Ajouter le bouton `IconButton` dans `card_detail_page.dart` | 0.15j |
| 17 | Connecter au `DeckPickerModal` existant | 0.1j |
| 18 | Ajouter SnackBar de confirmation | 0.1j |
| 19 | Test d'integration (optionnel, le modal est deja teste) | 0.15j |

### Phase 5 : US-9.5 Tokens Deck (1.5j)

| # | Tache | Effort |
|---|-------|--------|
| 20 | Ajouter `tokens` dans `DeckDetailState` | 0.15j |
| 21 | Implementer `_computeTokens()` dans `DeckDetailController` | 0.35j |
| 22 | Creer `DeckTokensTab` widget | 0.4j |
| 23 | Integrer l'onglet Tokens dans `deck_detail_page.dart` | 0.2j |
| 24 | Charger les images des tokens via API Scryfall (`/cards/collection`) | 0.25j |
| 25 | Tests tokens (3 tests) | 0.15j |

---

## Metriques Cibles Sprint 9

| Metrique | Sprint 8 (actuel) | Cible Sprint 9 |
|----------|-------------------|-----------------|
| Tests | 273 | **>= 290** |
| Fichiers modifies | - | ~10 |
| Fichiers crees | - | 2 (collection_badge.dart, deck_tokens_tab.dart) |
| Features utilisateur | 0 nouvelles depuis Sprint 0 | **5 nouvelles** |
| Champs ScryfallCard | 20 | **21** (allParts) |
| Champs SearchFilters | 7 | **8** (maxPrice) |
| Options de tri | ~5 (name, set, rarity, price, cmc) | **7** (+price_asc, +price_desc) |
| Score qualite | 9.0/10 | **9.0/10** (pas de regression, pas de refactoring technique) |

*"Les meilleurs plats sont ceux qui utilisent des ingredients deja dans le garde-manger. Le prix est dans ScryfallCard, la collection est dans le Provider, le DeckPickerModal est dans le tiroir. Il suffit de cuisiner intelligemment -- et voila 5 features servies en 5 jours."* -- Sanji
