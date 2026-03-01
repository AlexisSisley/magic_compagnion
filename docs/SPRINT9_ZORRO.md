# Sprint 9 - Analyse Business : Quick Wins Features
> Agent : Zorro (Business Analyst) | Date : 01/03/2026

---

## 1. Reformulation du Probleme

**Domaine metier** : Application Flutter mobile pour joueurs de Magic: The Gathering (Magic Companion).

**Parties prenantes** : Developpeur solo (Alexis), utilisateurs joueurs MTG (deckbuilders, collectionneurs, joueurs Commander).

**Point de douleur central** : Apres 8 sprints de refactoring (score qualite 5.5 -> 9.0/10), l'application dispose d'une base technique solide mais manque de **features differenciantes a forte valeur ajoutee** identifiees par l'audit Yamato (veille concurrentielle). Les concurrents (Moxfield, ManaBox, Dragon Shield) proposent des fonctionnalites que Magic Companion ne possede pas encore : indicateur de collection sur les cartes, tri par prix, ajout rapide au deck depuis le detail carte, filtre budget, et affichage des tokens requis.

**Objectif Sprint 9** : Implementer les **5 quick wins features** a fort impact utilisateur et faible effort technique, en s'appuyant sur l'infrastructure Riverpod/drift/Dio deja en place. Budget : **5 jours**. Aucun refactoring technique -- uniquement de la valeur utilisateur visible.

---

## 2. Analyse de la Cause Racine

1. **Focalisation technique des sprints 1-8** : Les 8 premiers sprints ont ete entierement dedies a la dette technique (Riverpod, drift, go_router, tests, CI/CD). Aucune feature utilisateur n'a ete ajoutee depuis le Sprint 0. Les joueurs n'ont pas vu d'evolution fonctionnelle.

2. **Donnees deja disponibles mais non exploitees** : Les prix (`prices.eur`, `prices.usd`) sont deja dans le modele `ScryfallCard`. Les `legalities` sont deja parsees. La collection est deja chargee dans `CardSearchController`. Ces donnees ne sont simplement pas surfacees dans l'UX.

3. **Bouton "Ajouter au deck" existe mais mal place** : Le widget `DeckPickerModal` existe deja et fonctionne. Mais il n'est accessible que depuis certains contextes -- pas depuis la page de detail carte principale.

4. **Tokens non modeles** : Le champ `all_parts` de l'API Scryfall (qui liste les tokens/emblemes crees par une carte) n'est pas parse dans le modele `ScryfallCard`. L'information existe dans l'API mais n'est pas exploitee.

5. **Gap concurrentiel mesure** : L'audit Yamato a identifie 3 gaps critiques (import/export, indicateur collection, legalite) et classe les features ci-dessous en Tier S et A. Ne pas les implementer freine l'adoption.

---

## 3. Inventaire des Assets Existants

### Donnees disponibles dans ScryfallCard

| Donnee | Champ | Utilise actuellement | Requis pour Sprint 9 |
|--------|-------|---------------------|---------------------|
| Prix EUR/USD | `prices['eur']`, `prices['usd']` | Oui (set_detail, deck_list, wishlist) | Tri par prix (US-9.2) |
| Prix foil | `prices['eur_foil']`, `prices['usd_foil']` | Oui (set_stats, wishlist) | Filtre budget (US-9.4) |
| Legalites | `legalities` (Map format -> status) | Oui (affichage card_detail_page) | Non (Sprint 10) |
| Tokens/related | `all_parts` dans le JSON Scryfall | **NON PARSE** | Tokens (US-9.5) |

### Infrastructure disponible

| Composant | Etat | Utilite Sprint 9 |
|-----------|------|-----------------|
| `CollectionService` + `collectionProvider` | Operationnel | Indicateur collection (US-9.1) |
| `CardSearchController.isCardInCollection()` | Existe deja | Indicateur dans la recherche (US-9.1) |
| `DeckPickerModal` | Operationnel | Bouton "Ajouter au deck" (US-9.3) |
| `ScryfallApiService.searchCards(order: 'eur')` | Supporte par l'API | Tri par prix (US-9.2) |
| `DeckDetailController` + `DeckService` | Operationnel | Filtre budget (US-9.4) |
| `LocalCardService` (27 000 cartes locales) | Operationnel | Recherche tokens localement |

---

## 4. User Stories

| Priorite | ID | En tant que... | Je veux... | Afin de... | MoSCoW | Story Points | Ref Yamato |
|----------|----|----------------|------------|------------|--------|-------------|------------|
| 1 | US-9.1 | Joueur collectionneur | voir un indicateur visuel (badge/icone) sur chaque carte indiquant si je la possede, combien j'en ai, et si elle est dans ma wishlist | savoir instantanement si une carte m'interesse ou si je l'ai deja quand je navigue dans la recherche ou un set | Must | 3 | M10 |
| 2 | US-9.2 | Joueur budget | pouvoir trier les resultats de recherche et ma collection par prix (croissant/decroissant) | trouver rapidement les cartes les plus/moins cheres et gerer mon budget | Must | 2 | M9 |
| 3 | US-9.3 | Deckbuilder | avoir un bouton "Ajouter au deck" directement sur la page de detail d'une carte | ajouter rapidement une carte a un de mes decks sans quitter la page de detail | Should | 1 | E-A4 |
| 4 | US-9.4 | Joueur budget | pouvoir filtrer les suggestions de cartes et la recherche par prix maximum | construire un deck qui respecte mon budget sans devoir verifier chaque carte | Should | 2 | E4 |
| 5 | US-9.5 | Joueur Commander | voir la liste des tokens/emblemes requis par mon deck | preparer physiquement les tokens necessaires avant une partie | Could | 3 | M13 |

**Total : 11 Story Points (~5 jours)**

---

## 5. Criteres d'Acceptation (Gherkin/BDD)

### US-9.1 : Indicateur de collection sur chaque carte

```gherkin
Fonctionnalite: Indicateur de possession sur les cartes
  Contexte:
    Etant donne que l'utilisateur possede 3 exemplaires de "Lightning Bolt" (2 normaux, 1 foil)
    Et que "Counterspell" est dans sa wishlist
    Et que "Black Lotus" n'est ni dans sa collection ni dans sa wishlist

  Scenario: Badge de possession dans la recherche
    Quand l'utilisateur recherche "Lightning"
    Alors la carte "Lightning Bolt" affiche un badge "x3" avec une icone de collection
    Et le badge indique "2 + 1 foil"

  Scenario: Badge wishlist dans la recherche
    Quand l'utilisateur recherche "Counterspell"
    Alors la carte "Counterspell" affiche une icone coeur/etoile de wishlist

  Scenario: Pas de badge pour carte non possedee
    Quand l'utilisateur recherche "Black Lotus"
    Alors la carte "Black Lotus" n'affiche aucun badge de collection ni de wishlist

  Scenario: Badge dans la page detail set
    Quand l'utilisateur consulte un set contenant "Lightning Bolt"
    Alors la tuile de "Lightning Bolt" affiche le badge de collection "x3"

  Scenario: Badge dans la page detail carte
    Quand l'utilisateur ouvre le detail de "Lightning Bolt"
    Alors la section info affiche "Dans ma collection : 2 normaux + 1 foil"
```

### US-9.2 : Tri par prix dans recherche et collection

```gherkin
Fonctionnalite: Tri par prix
  Contexte:
    Etant donne que l'utilisateur a des resultats de recherche contenant des cartes avec des prix varies

  Scenario: Tri prix decroissant dans la recherche API
    Quand l'utilisateur selectionne le tri "Prix (cher -> pas cher)"
    Alors les resultats sont tries par prix EUR decroissant
    Et les cartes sans prix sont affichees en dernier

  Scenario: Tri prix croissant dans la recherche locale
    Quand l'utilisateur est en mode recherche locale
    Et selectionne le tri "Prix (pas cher -> cher)"
    Alors les resultats locaux sont tries par prix EUR croissant

  Scenario: Tri prix dans la collection
    Quand l'utilisateur est dans l'onglet Collection
    Et selectionne le tri par prix
    Alors les cartes de la collection sont triees par prix EUR

  Scenario: Carte sans prix
    Etant donne qu'une carte n'a pas de prix EUR (prices['eur'] == null)
    Quand le tri par prix est actif
    Alors la carte est positionnee en fin de liste avec l'indication "Prix N/A"
```

### US-9.3 : Bouton "Ajouter au deck" depuis le detail carte

```gherkin
Fonctionnalite: Ajout rapide au deck depuis le detail carte
  Contexte:
    Etant donne que l'utilisateur est sur la page de detail d'une carte "Sol Ring"
    Et qu'il possede 2 decks ("Commander Deck" et "Modern Deck")

  Scenario: Bouton visible sur la page detail
    Alors un bouton "Ajouter au deck" est visible dans la barre d'actions
    Et le bouton utilise une icone explicite (style_outlined ou add_to_queue)

  Scenario: Modal de selection du deck
    Quand l'utilisateur appuie sur "Ajouter au deck"
    Alors le DeckPickerModal s'ouvre avec la liste des decks
    Et l'utilisateur peut choisir un deck ou en creer un nouveau

  Scenario: Confirmation d'ajout
    Quand l'utilisateur selectionne "Commander Deck"
    Alors la carte "Sol Ring" est ajoutee au mainboard de "Commander Deck"
    Et un SnackBar confirme "Sol Ring ajoutee a Commander Deck"
    Et le modal se ferme

  Scenario: Carte deja presente dans le deck
    Etant donne que "Sol Ring" est deja dans "Commander Deck" (quantite 1)
    Quand l'utilisateur ajoute "Sol Ring" a "Commander Deck"
    Alors la quantite passe a 2
    Et le SnackBar confirme "Sol Ring (x2) dans Commander Deck"
```

### US-9.4 : Filtre budget pour la construction de deck

```gherkin
Fonctionnalite: Filtre par prix maximum
  Contexte:
    Etant donne que l'utilisateur est dans la recherche de cartes

  Scenario: Ajout du filtre prix max dans le modal de filtres
    Quand l'utilisateur ouvre le modal de filtres
    Alors un champ "Prix max (EUR)" est disponible
    Et il peut saisir un montant (ex: 5.00)

  Scenario: Recherche API filtree par prix
    Etant donne que le filtre "Prix max 5.00 EUR" est actif
    Quand l'utilisateur effectue une recherche
    Alors seules les cartes avec un prix EUR <= 5.00 sont affichees

  Scenario: Recherche locale filtree par prix
    Etant donne que le filtre prix max est actif
    Et que l'utilisateur est en mode recherche locale
    Quand les resultats sont affiches
    Alors seules les cartes locales avec un prix <= 5.00 apparaissent

  Scenario: Filtre prix combine avec autres filtres
    Etant donne que le filtre prix max 3.00 EUR et le filtre type "Creature" sont actifs
    Quand l'utilisateur recherche
    Alors seules les creatures avec un prix <= 3.00 EUR apparaissent

  Scenario: Indicateur filtre actif
    Quand le filtre prix max est actif
    Alors le bouton de filtre affiche un badge indiquant un filtre actif
    Et le filtre prix est visible dans le resume des filtres
```

### US-9.5 : Affichage des tokens requis par le deck

```gherkin
Fonctionnalite: Liste des tokens requis par un deck
  Contexte:
    Etant donne que l'utilisateur consulte un deck Commander contenant :
      - "Avenger of Zendikar" (cree des tokens Plant 0/1)
      - "Elspeth, Sun's Champion" (cree des tokens Soldier 1/1)
      - "Sol Ring" (ne cree pas de token)

  Scenario: Onglet/section tokens dans le detail du deck
    Quand l'utilisateur consulte le detail du deck
    Alors un onglet ou une section "Tokens" est disponible

  Scenario: Liste des tokens requis
    Quand l'utilisateur ouvre la section "Tokens"
    Alors la liste affiche "Plant 0/1" et "Soldier 1/1 White"
    Et chaque token affiche son image Scryfall si disponible
    Et les tokens sont dedupliques (meme si 2 cartes creent des Soldiers)

  Scenario: Deck sans tokens
    Etant donne un deck qui ne cree aucun token
    Quand l'utilisateur ouvre la section "Tokens"
    Alors un message "Ce deck ne necessite aucun token" est affiche

  Scenario: Token avec image non disponible
    Etant donne qu'un token n'a pas d'image dans la base locale
    Quand la liste des tokens est affichee
    Alors le token affiche un placeholder avec son nom et ses stats
```

---

## 6. Contraintes & Hypotheses

### Contraintes
- **Stack figee** : Flutter/Dart, Riverpod, drift, go_router, Dio -- pas de changement de stack
- **Tests existants** : Les 273 tests doivent rester verts a chaque etape
- **Retrocompatibilite** : Aucune regression fonctionnelle pour l'utilisateur
- **Budget** : 5 jours maximum (sprint court, features a forte valeur)
- **API Scryfall** : Rate limit 10 req/sec, cache HTTP deja en place via Dio
- **Modele ScryfallCard** : Modification mineure autorisee (ajout champ `allParts` pour les tokens)

### Hypotheses
- Le Sprint 8 est suffisamment avance pour que l'infrastructure (controllers, providers) soit stable
- Les donnees de prix EUR sont disponibles pour la majorite des cartes via Scryfall (`prices.eur`)
- Le champ `all_parts` de l'API Scryfall contient les references aux tokens crees par une carte
- Le `DeckPickerModal` existant peut etre reutilise tel quel pour US-9.3
- La collection est chargee en memoire via `collectionProvider` et peut etre consultee rapidement (O(1) via Set/Map)

---

## 7. Evaluation des Risques

| ID | Risque | Probabilite | Impact | Strategie de Mitigation |
|----|--------|-------------|--------|-------------------------|
| R-9.1 | Performance du badge collection : la verification sur 27 000+ cartes ralentit le scroll | Moyenne | Haut | Utiliser un `Set<String>` de scryfallIds en memoire (lookup O(1)) au lieu de scanner la liste |
| R-9.2 | Prix EUR manquant pour de nombreuses cartes (anciennes editions) | Moyenne | Moyen | Fallback vers prix USD si EUR absent, afficher "N/A" sinon |
| R-9.3 | Champ `all_parts` non parse dans le modele existant | Certaine | Moyen | Ajouter le champ au modele (modification mineure de `ScryfallCard.fromJson`) |
| R-9.4 | Filtre prix sur API Scryfall non supporte directement | Faible | Moyen | Utiliser la syntaxe de recherche Scryfall `eur<=5` dans la query, ou filtrer cote client |
| R-9.5 | Tokens non disponibles dans la base locale oracle-cards.json | Moyenne | Moyen | Charger les tokens via API Scryfall a la demande (requete par deck, cachee) |
| R-9.6 | UX surcharge : trop de badges/indicateurs sur les cartes | Faible | Moyen | Design minimaliste : petit badge discret, tooltip pour les details |

---

## 8. Dependances & Carte des Parties Prenantes

### Dependances internes

- **US-9.1 est independante** : utilise uniquement `collectionProvider` et `wishlistProvider` deja existants
- **US-9.2 est independante** : utilise `CardSearchController.sortBy` deja existant + API Scryfall `order=eur`
- **US-9.3 est independante** : reutilise `DeckPickerModal` et `CardDetailController` existants
- **US-9.4 depend de US-9.2** : le filtre prix s'integre dans le meme systeme de filtres que le tri
- **US-9.5 depend du parsing de `all_parts`** : necessite modification du modele `ScryfallCard`

### Ordre d'execution recommande

```
US-9.1 (Indicateur collection) ─── independant ───> peut commencer immediatement
US-9.2 (Tri par prix)          ─── independant ───> peut commencer immediatement
US-9.3 (Bouton ajout deck)     ─── independant ───> peut commencer immediatement
US-9.4 (Filtre budget)         ─── apres US-9.2 ──> enrichit le systeme de filtres
US-9.5 (Tokens deck)           ─── independant ───> mais plus complexe (modele + API)
```

**Recommandation** : Commencer par US-9.1 (plus grand impact visible) puis US-9.3 (le plus rapide), puis US-9.2/9.4 ensemble, puis US-9.5.

### Parties prenantes

| Partie prenante | Role | Interet | Influence |
|----------------|------|---------|-----------|
| Alexis (dev) | Developpeur unique, mainteneur | Tres haut | Tres haute |
| Joueurs MTG | Utilisateurs finaux | **Tres haut** (premieres features visibles depuis 8 sprints) | Haute |
| CI/CD (GitHub Actions) | Pipeline automatise | Moyen (doit rester vert) | Haute |

---

## 9. Estimation

| User Story | Effort | Priorite | Dependances |
|------------|--------|----------|-------------|
| US-9.1 : Indicateur de collection | 1.5j | P0 | Aucune |
| US-9.2 : Tri par prix | 0.5j | P1 | Aucune |
| US-9.3 : Bouton "Ajouter au deck" | 0.5j | P1 | Aucune |
| US-9.4 : Filtre budget | 1j | P1 | US-9.2 (meme systeme de filtres) |
| US-9.5 : Tokens requis par le deck | 1.5j | P2 | Modification modele ScryfallCard |
| **Total** | **5j** | -- | -- |

### Scope ajustable (si retard)

Si le sprint prend du retard, les US peuvent etre repoussees dans cet ordre :
1. **US-9.5** (tokens) -> Sprint 10 (P2, 1.5j) -- le plus complexe, necessite modification du modele
2. **US-9.4** (filtre budget) -> Sprint 10 (P1, mais depend du tri)
3. Les US-9.1 a US-9.3 sont **P0/P1 et non negociables**

---

## 10. Hors Scope Sprint 9

- Import/Export multi-format (CSV, TXT, Moxfield) -> Sprint 10
- Verification de legalite automatique par format -> Sprint 10
- Tags personnalises sur les cartes -> Sprint 10
- Themes et tribes EDHREC -> Sprint 11
- Synergy score et detection de combos -> Sprint 11
- Centralisation Colors hardcodes -> Sprint 10 (reporte du Sprint 8)
- Extraction GameSetupModalController -> Sprint 10 (reporte du Sprint 8)

---

## 11. Impact Utilisateur Attendu

| Feature | Impact UX | Frequence d'utilisation | Avantage concurrentiel |
|---------|-----------|------------------------|----------------------|
| US-9.1 : Badge collection | **Tres haut** -- l'utilisateur sait instantanement ce qu'il possede | Chaque recherche, chaque consultation de set | Rattrape Moxfield, ManaBox, Dragon Shield |
| US-9.2 : Tri par prix | **Haut** -- gestion de budget facilitee | Frequente (recherche, collection) | Standard chez tous les concurrents |
| US-9.3 : Bouton ajout deck | **Moyen-Haut** -- workflow deckbuilding accelere | A chaque ajout de carte | Moxfield et ManaBox l'ont |
| US-9.4 : Filtre budget | **Moyen** -- construction de decks budget | Ponctuelle (deckbuilding budget) | ManaBox et Archidekt l'ont |
| US-9.5 : Tokens | **Moyen** -- preparation avant partie | Avant chaque partie Commander | Moxfield et EDHREC l'ont |

*"Cinq coupes nettes. Pas de gras, que du muscle. Chaque feature est une lame affutee qui tranche droit dans le gap concurrentiel. Le One Piece du joueur MTG est a portee de katana."* -- Zorro
