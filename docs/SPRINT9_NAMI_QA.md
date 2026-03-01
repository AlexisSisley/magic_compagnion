# Sprint 9 - Plan QA : Quick Wins Features
> Agent : Nami (QA Lead) | Date : 01/03/2026
> Mode : Verification Active + Conseil

---

## VERDICT PRE-SPRINT : PASS CONDITIONNEL

### Resume
- Stack detectee : Flutter / Dart 3.9.2 (Flutter 3.35.6)
- Tests : **273/273 PASS**
- flutter analyze : 0 errors, **75 warnings**, **890 infos** (965 total)
- Controllers existants : **6** (Sprint 7)
- Providers actifs : **20+**
- Base drift SQLite : operationnelle

### Constat de Sante Avant Sprint 9

| Metrique | Valeur | Statut |
|----------|--------|--------|
| flutter test | 273/273 PASS | OK |
| flutter analyze errors | 0 | OK |
| flutter analyze warnings | 75 | NON BLOQUANT (Sprint 8 backlog) |
| flutter analyze infos | 890 | NON BLOQUANT (Sprint 8 backlog) |
| DeckPickerModal | Fonctionnel | OK pour reutilisation |
| collectionProvider | Fonctionnel | OK pour index |
| ScryfallApiService | Fonctionnel + cache + rate limit | OK pour tokens |

### Avertissement

Le Sprint 8 technique n'est pas termine (965 issues analyze, 4 controllers widgets non extraits, routeur non decoupe, theme non centralise). Le Sprint 9 ajoute des features **par-dessus** l'etat actuel. Risque principal : ajout de code sans avoir fait le nettoyage planifie. Ce risque est **acceptable** car les features sont legeres et n'aggravent pas significativement la dette technique.

---

## 1. Analyse de Testabilite

| Dimension | Note | Explication |
|-----------|------|-------------|
| Observabilite | **Haute** | Riverpod expose l'etat ; les index collection sont des structures testables ; les prix sont des valeurs deterministes |
| Controlabilite | **Haute** | Les services sont injectables ; les controllers ont des methodes publiques ; les filtres sont parametrables |
| Decomposabilite | **Haute** | Chaque feature est independante et testable isolement (sauf US-9.4 qui depend de US-9.2) |
| Stabilite | **Haute** | L'API Scryfall est stable ; les modeles sont figes depuis Sprint 4 ; la modification de ScryfallCard est additive |
| Comprehensibilite | **Haute** | Specs Zorro completes ; architecture Sanji detaillee ; chaque US a des criteres d'acceptation Gherkin |

**Implications** : Le Sprint 9 est hautement testable. Les features utilisent des donnees deterministes (prix, collection, tokens) et des composants existants bien testes. La modification du modele ScryfallCard est additive (ajout de champ optionnel) et ne presente aucun risque de regression.

---

## 2. Matrice de Risques

| Zone / US | Risque Business | Risque Technique | Priorite Test | Profondeur |
|-----------|-----------------|------------------|---------------|------------|
| US-9.1 : Indicateur collection | Haut (feature la plus visible) | Moyen (performance index) | P0 | Profond |
| US-9.2 : Tri par prix | Moyen (UX standard) | Faible (deja un tri existant) | P1 | Moyen |
| US-9.3 : Bouton ajout deck | Moyen (workflow deckbuilding) | Tres faible (reutilisation) | P2 | Leger |
| US-9.4 : Filtre budget | Moyen (feature recherche) | Faible (filtre cote client) | P1 | Moyen |
| US-9.5 : Tokens deck | Faible (feature Commander niche) | Moyen (parsing all_parts + API) | P1 | Moyen |
| Modification ScryfallCard | Bas | Moyen (regression parsing) | P0 | Profond |

### Top 3 Risques Majeurs

1. **Performance badge collection dans le scroll** : Si l'index n'est pas precalcule, chaque tuile de carte fait un O(n) sur la collection. Avec 175 resultats de recherche et 5000+ cartes en collection, cela peut creer des micro-lags.
2. **Regression parsing ScryfallCard** : L'ajout de `allParts` dans `fromJson` doit etre retrocompatible (default `const []`). Un bug ici casserait TOUTE l'application.
3. **Prix EUR absent** : De nombreuses cartes anciennes ou digitales n'ont pas de prix EUR. Le tri et le filtre doivent gerer gracieusement les `null`.

---

## 3. Strategie de Test Globale

### Pyramide de Tests Sprint 9

```
                    /\
                   /  \     1 test manuel navigation
                  / E2E\    (bouton ajout deck)
                 /------\
                /        \   ~4 tests integration
               / Integr.  \  (controller + service mock)
              /------------\
             /              \  ~14 tests unitaires
            /   Unitaires    \  (modele, badge, tri, filtre, tokens)
           /------------------\
```

### Niveaux de Test

| Niveau | Quoi | Comment | Cible |
|--------|------|---------|-------|
| Unitaire | CollectionBadge (6 cas) | flutter_test | Toutes les combinaisons owned/foil/wishlist |
| Unitaire | ScryfallCard.fromJson allParts (3 cas) | flutter_test | Parse, empty, isToken |
| Unitaire | SearchFilters.maxPrice (2 cas) | flutter_test | copyWith, hasActiveFilters |
| Unitaire | Tri par prix (2 cas) | flutter_test | asc, desc avec nulls |
| Unitaire | Filtre prix max (3 cas) | flutter_test | filtre actif, null prices, combined |
| Integration | CardSearchController index collection | flutter_test + mock | Index correct apres loadLocalData |
| Integration | DeckDetailController tokens | flutter_test + mock | Tokens extraits correctement |
| Manuel | Bouton ajout deck | Test app | Modal s'ouvre, ajout fonctionne |

### Criteres d'Entree Sprint 9
- 273 tests PASS (confirme)
- flutter analyze : 0 errors (confirme)
- CollectionService + DeckService + ScryfallApiService fonctionnels (confirme)
- DeckPickerModal fonctionnel (confirme)

### Criteres de Sortie Sprint 9
- **>= 290 tests** PASS (273 + ~18 nouveaux)
- **flutter analyze : 0 errors** (les warnings/infos pre-existants sont toleres)
- **5 features** deployables et fonctionnelles
- **Badge collection** visible sur recherche + set detail
- **Tri par prix** fonctionne en mode API et local
- **Bouton ajout deck** accessible depuis le detail carte
- **Filtre prix max** fonctionne dans le modal de filtres
- **Tokens** affiches dans le detail du deck

---

## 4. Scenarios de Test

### Chemin Nominal (Happy Path)

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-9.01 | Badge collection affiche sur carte possedee | Unit | 9.1 | Collection avec "Lightning Bolt" x3 (2 normal + 1 foil) | Appeler getBadge("lb-id", "Lightning Bolt") | Badge(normalCount: 2, foilCount: 1, inWishlist: false) | P0 |
| T-9.02 | Badge wishlist affiche sur carte en wishlist | Unit | 9.1 | "Counterspell" en wishlist | Appeler getBadge("cs-id", "Counterspell") | Badge(normalCount: 0, foilCount: 0, inWishlist: true) | P0 |
| T-9.03 | Index collection construit correctement | Integ | 9.1 | Collection mock 5 cartes | Appeler loadLocalData() | collectionIndex contient 5 entries avec bonnes quantites | P0 |
| T-9.04 | Tri prix decroissant | Unit | 9.2 | Liste [carte 1.00, carte 5.00, carte 2.50] | Tri price_desc | [5.00, 2.50, 1.00] | P1 |
| T-9.05 | Tri prix croissant | Unit | 9.2 | Meme liste | Tri price_asc | [1.00, 2.50, 5.00] | P1 |
| T-9.06 | Filtre prix max 3.00 | Unit | 9.4 | Liste avec prix [1.00, 5.00, 2.50, 10.00] | Appliquer maxPrice: 3.00 | [1.00, 2.50] | P1 |
| T-9.07 | Parse allParts avec tokens | Unit | 9.5 | JSON Scryfall avec all_parts contenant 2 tokens | ScryfallCard.fromJson(json) | allParts.length == 2, allParts[0].isToken == true | P0 |
| T-9.08 | Tokens extraits du deck | Integ | 9.5 | Deck mock avec 2 cartes ayant des tokens | Appeler computeDeckTokens() | Liste de 2+ tokens uniques | P1 |
| T-9.09 | Bouton ajout deck ouvre le modal | Manuel | 9.3 | Page detail carte ouverte | Tap sur le bouton "Ajouter au deck" | DeckPickerModal s'ouvre avec la liste des decks | P1 |

### Cas aux Limites (Edge Cases)

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-9.10 | Badge pour carte non possedee ni en wishlist | Unit | 9.1 | Collection vide, wishlist vide | Appeler getBadge("any-id", "Any Card") | null (pas de badge) | P0 |
| T-9.11 | Tri prix avec carte sans prix EUR | Unit | 9.2 | Liste contient carte avec prices['eur'] == null | Tri price_desc | Carte sans prix en dernier | P0 |
| T-9.12 | Filtre prix max avec carte sans prix | Unit | 9.4 | Carte avec prices['eur'] == null | Appliquer maxPrice: 5.00 | Carte exclue (pas de prix = pas dans le budget) | P1 |
| T-9.13 | Parse allParts absent du JSON | Unit | 9.5 | JSON sans champ "all_parts" | ScryfallCard.fromJson(json) | allParts == [] (liste vide, pas de crash) | P0 |
| T-9.14 | Tokens avec deck vide | Unit | 9.5 | Deck sans cartes dans mainboard | Appeler computeDeckTokens() | Liste vide, pas d'erreur | P1 |
| T-9.15 | Badge avec carte foil uniquement | Unit | 9.1 | Collection : "Sol Ring" x1 foil, 0 normal | Appeler getBadge("sr-id", "Sol Ring") | Badge(normalCount: 0, foilCount: 1, inWishlist: false) | P1 |
| T-9.16 | Filtre prix max = 0 | Unit | 9.4 | maxPrice = 0.0 | Appliquer filtre | Seules les cartes gratuites (prix 0.00) passent | P2 |
| T-9.17 | Collection tres large (5000+ cartes) | Perf | 9.1 | Mock collection 5000 cartes | Construire l'index | Temps < 50ms | P1 |
| T-9.18 | Tokens dedupliques | Unit | 9.5 | 2 cartes creent le meme token "Soldier 1/1" | computeDeckTokens() | 1 seul token "Soldier" dans la liste | P1 |

### Tests Negatifs

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-9.20 | ScryfallCard.fromJson avec all_parts invalide | Unit | 9.5 | JSON avec all_parts = "invalid" (pas un array) | ScryfallCard.fromJson(json) | allParts == [] ou exception gracieuse, pas de crash | P0 |
| T-9.21 | Prix EUR format invalide | Unit | 9.2 | Carte avec prices['eur'] = "abc" | Tri par prix | Carte traitee comme prix 0, pas de crash | P1 |
| T-9.22 | Filtre prix max negatif | Unit | 9.4 | maxPrice = -1.0 | Appliquer filtre | Aucune carte ne passe (ou ignore le filtre), pas de crash | P2 |
| T-9.23 | Ajout au deck quand foundCard est null | Unit | 9.3 | Page detail carte en etat loading (foundCard == null) | Tap sur bouton ajout deck | Bouton desactive ou tap ignore, pas de crash | P1 |

---

## 5. Specifications BDD/Gherkin Detaillees

### Scenario 1 : Index de collection performant

```gherkin
Fonctionnalite: Index de collection pour badges
  Contexte:
    Etant donne que la collection contient :
      | scryfallId | name | quantity | isFoil |
      | lb-001 | Lightning Bolt | 2 | false |
      | lb-001 | Lightning Bolt | 1 | true |
      | sr-001 | Sol Ring | 4 | false |
    Et que la wishlist contient :
      | name |
      | Black Lotus |

  Scenario: Index construit apres loadLocalData
    Quand loadLocalData() est appele
    Alors collectionIndex["lb-001"] == 2
    Et collectionFoilIndex["lb-001"] == 1
    Et collectionIndex["sr-001"] == 4
    Et wishlistCardNames contient "Black Lotus"

  Scenario: Badge pour carte possedee et en wishlist
    Etant donne qu'on ajoute "Lightning Bolt" a la wishlist
    Quand getBadge("lb-001", "Lightning Bolt") est appele
    Alors le badge a normalCount == 2, foilCount == 1, inWishlist == true
```

### Scenario 2 : Tri par prix avec gestion des nulls

```gherkin
Fonctionnalite: Tri par prix
  Plan du Scenario: Tri avec prix manquants
    Etant donne les cartes :
      | name | eur |
      | Carte A | 5.00 |
      | Carte B | null |
      | Carte C | 1.50 |
      | Carte D | 10.00 |
    Quand le tri <direction> est applique
    Alors l'ordre est <resultat>

    Exemples:
      | direction | resultat |
      | price_desc | [Carte D, Carte A, Carte C, Carte B] |
      | price_asc | [Carte C, Carte A, Carte D, Carte B] |
```

### Scenario 3 : Filtre prix + tri combines

```gherkin
Fonctionnalite: Filtre et tri par prix combines
  Scenario: Filtre 5 EUR + tri decroissant
    Etant donne les cartes [1.00, 3.00, 7.00, 2.50, null]
    Et que le filtre maxPrice = 5.00 est actif
    Et que le tri price_desc est actif
    Quand les resultats sont filtres puis tries
    Alors les resultats sont [3.00, 2.50, 1.00]
    Et la carte 7.00 est exclue
    Et la carte sans prix est exclue
```

### Scenario 4 : Tokens de deck dedupliques

```gherkin
Fonctionnalite: Extraction des tokens d'un deck
  Scenario: Tokens dedupliques entre cartes
    Etant donne que le deck contient :
      - "Avenger of Zendikar" (token: Plant 0/1, id: t-plant)
      - "Scute Swarm" (token: Insect 1/1, id: t-insect)
      - "Rampaging Baloths" (token: Beast 4/4, id: t-beast)
      - "Avenger of Zendikar" (doublon : meme token Plant)
    Quand computeDeckTokens() est appele
    Alors la liste contient 3 tokens : Plant, Insect, Beast
    Et Plant n'apparait qu'une seule fois
```

---

## 6. Strategie d'Automatisation

### Tests Automatises (CI/CD)

| Type | Framework | Quoi | CI |
|------|-----------|------|----|
| Unitaire modeles | flutter_test | ScryfallCard.fromJson allParts (3 tests) | Oui |
| Unitaire badge | flutter_test | CollectionBadge combinaisons (6 tests) | Oui |
| Unitaire tri/filtre | flutter_test | Tri prix + filtre prix (5 tests) | Oui |
| Unitaire tokens | flutter_test | Token parsing + dedup (3 tests) | Oui |
| Integration controller | flutter_test + mocks | Index collection + tokens deck (4 tests) | Oui |

### Tests Manuels

| Type | Quoi | Quand |
|------|------|-------|
| Visuel | Badges collection sur recherche | Apres US-9.1 |
| Visuel | Badges collection sur set detail | Apres US-9.1 |
| Navigation | Bouton ajout deck -> DeckPickerModal | Apres US-9.3 |
| Fonctionnel | Tri prix dans recherche API et locale | Apres US-9.2 |
| Fonctionnel | Filtre prix max dans modal filtres | Apres US-9.4 |
| Fonctionnel | Onglet Tokens dans deck detail | Apres US-9.5 |

### CI/CD Pipeline

Le pipeline existant (`flutter analyze` + `flutter test`) suffit. Aucune modification necessaire.

---

## 7. Plan de Tests Non-Fonctionnels

### Performance

| Test | Cible | Methode |
|------|-------|---------|
| Construction index collection (5000 cartes) | < 50ms | Stopwatch dans le test |
| Lookup badge par scryfallId | < 1ms (O(1) via Map) | Implicite (structure de donnees) |
| Tri local 175 cartes par prix | < 10ms | Stopwatch |
| Parsing ScryfallCard avec allParts | Pas de regression vs sans | Comparaison avant/apres |

### Compatibilite

- Pas de nouveau package ajoute -> aucun risque de compatibilite
- `ScryfallCard.allParts` default `const []` -> retrocompatible avec les JSONs existants
- `SearchFilters.maxPrice` default `null` -> retrocompatible

### Regression

- Les 273 tests existants doivent rester verts a 100%
- Le parsing existant de ScryfallCard ne doit pas etre modifie (seulement ajout)
- Les tris existants (name, set, rarity, cmc, price) ne doivent pas etre affectes

---

## 8. Matrice de Verification par US

| US | Verification Automatisee | Verification Manuelle | Critere PASS |
|----|--------------------------|----------------------|--------------|
| US-9.1 | 6 tests badge + 1 test index | Visuel : badges sur recherche + set | Badges corrects pour owned/foil/wishlist/none |
| US-9.2 | 2 tests tri prix (asc/desc) | Fonctionnel : tri dans recherche | Tri correct avec gestion nulls |
| US-9.3 | - (reutilise tests existants) | Fonctionnel : tap bouton -> modal -> ajout | Carte ajoutee, SnackBar affiche |
| US-9.4 | 3 tests filtre prix | Fonctionnel : saisir prix max dans modal | Seules les cartes dans le budget affichees |
| US-9.5 | 3 tests tokens (parse + dedup + vide) | Fonctionnel : onglet Tokens dans deck detail | Tokens affiches avec images |
| Modele | 3 tests ScryfallCard.fromJson | - | allParts parse, retrocompatible |
| **Total** | **~18 tests automatises** | **5 sessions manuelles** | |

---

## 9. Checklist de Validation Sprint 9

A executer a la fin de chaque US et en fin de sprint :

```bash
# Verification rapide apres chaque modification
flutter analyze                    # Cible : 0 errors (warnings/infos toleres)
flutter test                       # Cible : >= 290 tests, 0 fail

# Verification des features
# US-9.1 : Badges visibles dans la recherche et le set detail
# US-9.2 : Tri par prix fonctionne (API et local)
# US-9.3 : Bouton ajout deck ouvre le modal
# US-9.4 : Filtre prix max fonctionne dans le modal
# US-9.5 : Onglet Tokens affiche les tokens du deck
```

### Criteres d'Acceptation Globaux Sprint 9

| # | Critere | Methode de verification | Cible |
|---|---------|------------------------|-------|
| 1 | flutter test | `flutter test` | >= 290 tests, 0 fail |
| 2 | flutter analyze errors | `flutter analyze` | 0 errors |
| 3 | Badge collection visible | Test visuel recherche | Cartes possedees ont un badge |
| 4 | Tri par prix | Test fonctionnel | Tri fonctionne API + local |
| 5 | Bouton ajout deck | Test fonctionnel | Modal s'ouvre, carte ajoutee |
| 6 | Filtre budget | Test fonctionnel | Filtre prix max fonctionne |
| 7 | Tokens deck | Test fonctionnel | Onglet Tokens dans deck detail |
| 8 | Retrocompatibilite ScryfallCard | Tests unitaires | 273 tests existants toujours verts |
| 9 | Performance index | Test perf (optionnel) | < 50ms pour 5000 cartes |

---

## 10. Strategie de Non-Regression

Le Sprint 9 ajoute du code **nouveau** sans modifier le code existant en profondeur. La strategie de non-regression est donc simple :

1. **Avant chaque US** : Verifier que `flutter test` passe (273 tests)
2. **Apres chaque US** : Verifier que `flutter test` passe (273 + nouveaux tests)
3. **Modification ScryfallCard** : S'assurer que `allParts` a un default `const []` et que le parsing existant n'est PAS touche
4. **Modification SearchFilters** : S'assurer que `maxPrice` a un default `null` et que les filtres existants ne sont PAS touches
5. **Modification CardSearchState** : S'assurer que les nouveaux champs ont des defaults et que le `copyWith` existant fonctionne toujours

*"Chaque berri compte ! 5 features, 18 tests, 0 regression. Le tresor du Sprint 9, c'est la valeur utilisateur -- et cette fois, les joueurs vont voir la difference a chaque ecran."* -- Nami, QA Lead
