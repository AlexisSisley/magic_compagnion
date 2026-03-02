# Sprint 10 - Analyse Business : Import/Export & Legalite
> Agent : Zorro (Business Analyst) | Date : 01/03/2026

---

## 1. Reformulation du Probleme

**Domaine metier** : Application Flutter mobile pour joueurs de Magic: The Gathering (Magic Companion).

**Parties prenantes** : Developpeur solo (Alexis), utilisateurs joueurs MTG (deckbuilders, collectionneurs, joueurs competitifs multi-formats).

**Point de douleur central** : Apres 9 sprints (8 techniques + 1 features), Magic Companion dispose d'une base technique solide (9.0/10) et de 5 features utilisateur (Sprint 9). Cependant, deux **gaps critiques** identifies par l'audit Yamato bloquent l'adoption :

1. **Aucun import/export de decks** (Gap #1, critique) : Les joueurs ne peuvent ni importer leurs decks depuis Moxfield/Archidekt/MTGO, ni exporter vers ces plateformes. C'est le frein n°1 a l'adoption car les joueurs ont des dizaines de decks dans d'autres apps.
2. **Aucune verification de legalite** (Gap #3, critique) : Pas de verification automatique de la legalite d'un deck par format (Standard, Modern, Commander, Pioneer, etc.). Les joueurs competitifs ne peuvent pas valider leurs decks avant un tournoi.
3. **Pas de tags personnalises** (Gap moderate) : Les joueurs ne peuvent pas organiser leurs cartes avec des tags libres (ex: "Ramp", "Win-Con", "Trade", "Budget"). Le champ `tags` existe deja dans `DeckCard` mais n'est pas expose dans l'UX collection.

**Objectif Sprint 10** : Combler les 2 gaps critiques et ajouter les tags collection. Budget : **9 jours**, duree 3 semaines.

---

## 2. Analyse de la Cause Racine

1. **Import/export jamais implemente** : Le Sprint 7 a ajoute `DeckListController.importDeck()` qui parse un format texte basique (`Nx CardName`). Mais il ne supporte qu'un seul format, ne gere pas les sideboard/commander proprement pour tous les formats externes, et n'a aucune capacite d'export. Aucune interoperabilite avec l'ecosysteme MTG.

2. **Legalite connue mais non exploitee** : Le modele `ScryfallCard` parse deja `legalities` (Map<String, String>), et `card_detail_page.dart` affiche la legalite de chaque carte individuelle (standard, commander, modern, pioneer). Mais aucune verification globale n'est faite au niveau du deck. La methode `validateDeckRules()` dans `DeckDetailController` est un placeholder : elle ne verifie que le nombre de cartes Commander et ne consulte pas les legalities Scryfall.

3. **Tags presents mais non surfacees** : Le champ `tags` existe dans `DeckCard` (ajout Sprint 4), avec persistence drift et serialisation JSON. Mais il n'est utilise que dans les decks (via `updateTags` dans `DeckDetailController`), pas dans la collection. L'UX de gestion de tags est minimale.

---

## 3. Inventaire des Assets Existants

### Import/Export

| Composant | Etat | Utilite Sprint 10 |
|-----------|------|-----------------|
| `DeckListController.importDeck()` | Fonctionnel (format simple) | Base pour l'import multi-format |
| `DeckDetailController.generateFullDeckText()` | Fonctionnel | Base pour l'export texte |
| `DeckDetailController.generateConsideringText()` | Fonctionnel | Export considering |
| `DeckDetailController.generateWishlistText()` | Fonctionnel | Export wishlist |
| `BackupService.exportData()` / `importData()` | Fonctionnel | Modele pour file I/O (FilePicker, Share) |
| `ScryfallApiService.fetchCollection()` | Fonctionnel | Resolution Scryfall IDs pour l'import |
| `DeckListController.decklistRegex` | `RegExp(r'^(\d+)x?\s+(.+)$')` | Regex de base pour parser les listes |

### Legalite

| Composant | Etat | Utilite Sprint 10 |
|-----------|------|-----------------|
| `ScryfallCard.legalities` | `Map<String, String>` parse depuis l'API | Donnees de legalite par carte |
| `DeckDetailController.validateDeckRules()` | Placeholder (nombre de cartes seulement) | A remplacer par vraie verification |
| `DeckDetailController.fullCardData` | `List<ScryfallCard>` chargees via API | Donnees completes pour chaque carte du deck |
| `card_detail_page._buildLegalities()` | Affichage legalite carte individuelle | Modele UI pour le rapport deck |
| Formats affiches | `['standard', 'commander', 'modern', 'pioneer']` | Liste de base des formats |

### Tags

| Composant | Etat | Utilite Sprint 10 |
|-----------|------|-----------------|
| `DeckCard.tags` | `List<String>` avec persistence drift | Modele deja pret |
| `CollectionService.getAllUniqueTags()` | Fonctionnel | Recuperer les tags existants |
| `DeckDetailController.updateTags()` | Fonctionnel | UX tags deck existante |
| `SearchFilters.tags` | `Set<String>` dans le filtre | Filtre par tags existant dans le modele |
| `AppDatabase` | Supporte tags JSON dans collection_cards et deck_cards | Persistence OK |

---

## 4. User Stories

| Priorite | ID | En tant que... | Je veux... | Afin de... | MoSCoW | Story Points | Ref Yamato |
|----------|----|----------------|------------|------------|--------|-------------|------------|
| 1 | US-10.1 | Joueur migrant | importer un deck depuis un fichier texte au format Moxfield, Archidekt ou MTGO (TXT/CSV) | recuperer mes decks existants sans tout ressaisir | Must | 5 | M2 |
| 2 | US-10.2 | Joueur social | exporter un deck aux formats texte (TXT compatible Moxfield/MTGO) et CSV | partager mes decks avec d'autres joueurs ou les sauvegarder dans d'autres apps | Must | 3 | M2 |
| 3 | US-10.3 | Joueur competitif | voir un rapport de legalite complet de mon deck par format (Standard, Modern, Pioneer, Commander, Legacy, Vintage, Pauper, Brawl) | savoir si mon deck est legal avant un tournoi et identifier les cartes illegales | Must | 4 | M4 |
| 4 | US-10.4 | Joueur collectionneur | ajouter des tags personnalises a mes cartes de collection (ex: "Trade", "Budget", "Win-Con") et filtrer par tag | organiser ma collection selon mes propres criteres | Should | 2 | M3 |

**Total : 14 Story Points (~9 jours)**

---

## 5. Criteres d'Acceptation (Gherkin/BDD)

### US-10.1 : Import multi-format

```gherkin
Fonctionnalite: Import de decks multi-format
  Contexte:
    Etant donne que l'utilisateur est sur la page "Mes Decks"

  Scenario: Import TXT format Moxfield
    Quand l'utilisateur clique sur "Importer un deck"
    Et choisit un fichier .txt au format Moxfield :
      """
      Commander
      1 Atraxa, Praetors' Voice

      Deck
      1 Sol Ring
      1 Arcane Signet
      1 Command Tower
      35 Plains
      30 Island
      30 Swamp

      Sideboard
      1 Path to Exile
      """
    Alors un nouveau deck "Atraxa" est cree avec :
      - Format Commander
      - Commander = "Atraxa, Praetors' Voice"
      - Mainboard contenant Sol Ring, Arcane Signet, Command Tower, Plains, Island, Swamp
      - Sideboard contenant Path to Exile
    Et les scryfallId sont resolus via l'API Scryfall
    Et un toast confirme "Deck importe avec succes (N cartes)"

  Scenario: Import TXT format MTGO
    Quand l'utilisateur importe un fichier au format MTGO :
      """
      4 Lightning Bolt
      4 Goblin Guide
      4 Monastery Swiftspear
      4 Eidolon of the Great Revel

      Sideboard
      3 Smash to Smithereens
      2 Blood Moon
      """
    Alors un nouveau deck est cree avec :
      - Mainboard avec les quantites correctes
      - Sideboard avec les quantites correctes
      - Format detecte automatiquement (non-Commander car pas de section Commander)

  Scenario: Import CSV
    Quand l'utilisateur importe un fichier .csv avec les colonnes :
      """
      quantity,name,section
      4,Lightning Bolt,mainboard
      4,Goblin Guide,mainboard
      2,Blood Moon,sideboard
      """
    Alors un nouveau deck est cree avec les cartes correctement reparties

  Scenario: Import par collage de texte
    Quand l'utilisateur clique sur "Coller une decklist"
    Et colle le texte suivant dans le champ :
      """
      4 Lightning Bolt
      4 Goblin Guide
      """
    Et valide l'import
    Alors un nouveau deck est cree avec les cartes importees

  Scenario: Gestion des cartes non trouvees
    Quand l'utilisateur importe un fichier avec la carte "Carte Inexistante XYZ"
    Alors la carte est importee avec un scryfallId prefixe "LOCAL:"
    Et un avertissement indique "1 carte non trouvee sur Scryfall"
    Et l'import continue normalement pour les autres cartes

  Scenario: Import Archidekt (CSV avec colonnes supplementaires)
    Quand l'utilisateur importe un fichier CSV Archidekt :
      """
      Quantity,Name,Categories
      1,Sol Ring,"Ramp, Mana Rock"
      1,Arcane Signet,"Ramp, Mana Rock"
      1,Command Tower,"Land"
      """
    Alors les cartes sont importees avec les quantites correctes
    Et les categories sont converties en tags sur les cartes
```

### US-10.2 : Export multi-format

```gherkin
Fonctionnalite: Export de decks multi-format
  Contexte:
    Etant donne que l'utilisateur consulte un deck "Burn" avec :
      - Mainboard : 4 Lightning Bolt, 4 Goblin Guide
      - Sideboard : 2 Blood Moon, 3 Smash to Smithereens
      - Commander : null (format Standard/Modern)

  Scenario: Export TXT (format Moxfield/MTGO compatible)
    Quand l'utilisateur clique sur "Exporter" puis "TXT"
    Alors un fichier .txt est genere au format :
      """
      Deck
      4 Lightning Bolt
      4 Goblin Guide

      Sideboard
      2 Blood Moon
      3 Smash to Smithereens
      """
    Et le fichier est partageable via le sheet de partage systeme

  Scenario: Export TXT deck Commander
    Etant donne un deck Commander avec commander "Atraxa, Praetors' Voice"
    Quand l'utilisateur exporte en TXT
    Alors le fichier commence par :
      """
      Commander
      1 Atraxa, Praetors' Voice

      Deck
      ...
      """

  Scenario: Export CSV
    Quand l'utilisateur clique sur "Exporter" puis "CSV"
    Alors un fichier .csv est genere avec les colonnes :
      """
      quantity,name,section,scryfallId,tags
      4,Lightning Bolt,mainboard,abc-123,"Burn"
      4,Goblin Guide,mainboard,def-456,""
      2,Blood Moon,sideboard,ghi-789,""
      """

  Scenario: Export presse-papiers
    Quand l'utilisateur clique sur "Copier dans le presse-papiers"
    Alors le texte du deck au format TXT est copie dans le clipboard
    Et un toast confirme "Decklist copiee !"

  Scenario: Partage social
    Quand l'utilisateur clique sur "Partager"
    Alors le fichier est propose via le sheet de partage systeme (Share.shareXFiles)
```

### US-10.3 : Verification de legalite

```gherkin
Fonctionnalite: Verification de legalite d'un deck par format
  Contexte:
    Etant donne que l'utilisateur consulte un deck charge avec fullCardData

  Scenario: Deck 100% legal en Modern
    Etant donne que toutes les cartes du deck ont legalities['modern'] == 'legal'
    Et que le deck contient >= 60 cartes mainboard
    Et que le sideboard contient <= 15 cartes
    Et qu'aucune carte (hors terrains de base) n'a > 4 exemplaires
    Quand l'utilisateur consulte le rapport de legalite
    Alors le format "Modern" affiche un badge vert "Legal"
    Et le detail montre "60 cartes, 0 illegale, sideboard 15/15"

  Scenario: Deck avec cartes bannies en Standard
    Etant donne que "Oko, Thief of Crowns" a legalities['standard'] == 'banned'
    Quand l'utilisateur consulte le rapport de legalite
    Alors le format "Standard" affiche un badge rouge "Illegal"
    Et le detail montre "1 carte bannie : Oko, Thief of Crowns"

  Scenario: Deck Commander avec regles speciales
    Etant donne un deck Commander avec 100 cartes et un commandant
    Et que toutes les cartes respectent l'identite de couleur du commandant
    Et qu'aucune carte (sauf terrains de base) n'a plus d'1 exemplaire
    Quand l'utilisateur consulte le rapport de legalite
    Alors le format "Commander" affiche "Legal" si toutes les legalities sont OK
    Et la regle singleton est verifiee
    Et l'identite de couleur est verifiee

  Scenario: Violation identite de couleur Commander
    Etant donne un deck Commander avec commandant Mono-Rouge (identite [R])
    Et que le deck contient "Counterspell" (identite [U])
    Quand l'utilisateur consulte le rapport de legalite
    Alors le format "Commander" affiche "Illegal"
    Et le detail montre "1 carte hors identite de couleur : Counterspell (U vs R)"

  Scenario: Formats verifies
    Quand le rapport de legalite est genere
    Alors les formats suivants sont verifies :
      | Format | Taille min mainboard | Sideboard max | Copies max | Regle speciale |
      | Standard | 60 | 15 | 4 | - |
      | Pioneer | 60 | 15 | 4 | - |
      | Modern | 60 | 15 | 4 | - |
      | Legacy | 60 | 15 | 4 | - |
      | Vintage | 60 | 15 | 4 | Restricted = 1 copie |
      | Pauper | 60 | 15 | 4 | - |
      | Commander | 100 (exact) | 0 | 1 (singleton) | Identite couleur |
      | Brawl | 60 (exact) | 0 | 1 (singleton) | Identite couleur |

  Scenario: Carte restreinte en Vintage
    Etant donne que "Black Lotus" a legalities['vintage'] == 'restricted'
    Et que le deck contient 2 exemplaires de "Black Lotus"
    Quand l'utilisateur consulte la legalite Vintage
    Alors "Vintage" affiche "Illegal"
    Et le detail montre "1 carte restreinte en exces : Black Lotus (2 copies, max 1)"

  Scenario: Rapport visuel integre dans le deck detail
    Quand l'utilisateur est sur la page deck detail
    Alors un onglet ou section "Legalite" est accessible
    Et il affiche un badge par format (vert=legal, rouge=illegal, gris=partiel)
    Et un clic sur un format montre les details des violations
```

### US-10.4 : Tags personnalises collection

```gherkin
Fonctionnalite: Tags personnalises sur les cartes de collection
  Contexte:
    Etant donne que l'utilisateur a des cartes dans sa collection

  Scenario: Ajouter un tag a une carte de collection
    Quand l'utilisateur long-press sur "Lightning Bolt" dans la collection
    Et selectionne "Gerer les tags"
    Alors un dialog s'ouvre avec :
      - La liste des tags existants (auto-complete)
      - Un champ pour creer un nouveau tag
    Quand il ajoute le tag "Trade"
    Alors "Lightning Bolt" a maintenant le tag "Trade"
    Et le tag est sauvegarde dans la base drift

  Scenario: Filtrer la collection par tag
    Etant donne que 5 cartes ont le tag "Trade"
    Quand l'utilisateur active le filtre "Trade" dans les filtres de collection
    Alors seules les 5 cartes avec le tag "Trade" sont affichees

  Scenario: Supprimer un tag
    Quand l'utilisateur retire le tag "Trade" de "Lightning Bolt"
    Alors "Lightning Bolt" n'a plus le tag "Trade"
    Et si aucune autre carte n'a le tag "Trade", il disparait des suggestions

  Scenario: Tags multiples sur une carte
    Quand l'utilisateur ajoute "Trade" et "Budget" a "Sol Ring"
    Alors "Sol Ring" affiche les 2 tags
    Et le filtre "Trade" inclut "Sol Ring"
    Et le filtre "Budget" inclut aussi "Sol Ring"

  Scenario: Tags depuis l'import Archidekt
    Quand un deck est importe depuis un CSV Archidekt avec des categories
    Alors les categories sont converties en tags sur les DeckCards correspondantes
```

---

## 6. Contraintes & Hypotheses

### Contraintes
- **Stack figee** : Flutter/Dart, Riverpod, drift, go_router, Dio
- **Tests existants** : 298 tests doivent rester verts a chaque etape
- **Retrocompatibilite** : Aucune regression fonctionnelle
- **Budget** : 9 jours / 3 semaines
- **API Scryfall** : Rate limit 10 req/sec, cache HTTP via Dio
- **Formats d'import** : TXT (Moxfield/MTGO), CSV (Archidekt), texte colle. Pas de format proprietaire binaire.
- **Legalities deja parsees** : Le champ `ScryfallCard.legalities` contient les donnees, il suffit de les exploiter au niveau deck.

### Hypotheses
- Les joueurs qui importent ont des decks au format texte standard (Nx CardName avec sections)
- L'API Scryfall `/cards/collection` peut resoudre les noms en IDs par batch de 75
- Le champ `legalities` de Scryfall est fiable et a jour pour les formats listes
- Le champ `all_parts` ne contient pas d'info de legalite (uniquement tokens/meld)
- Les tags collection reutilisent le meme champ `tags` que `DeckCard` (deja en base drift)

---

## 7. Evaluation des Risques

| ID | Risque | Probabilite | Impact | Strategie de Mitigation |
|----|--------|-------------|--------|-------------------------|
| R-10.1 | Noms de cartes non resolus a l'import (cartes en francais, typos, double-face) | Haute | Moyen | Fallback "LOCAL:" + fuzzy matching optionnel + avertissement a l'utilisateur |
| R-10.2 | Formats d'import varies (chaque site a ses variantes) | Haute | Moyen | Parser tolerant : detecter les sections par mots-cles, ignorer les lignes vides et commentaires |
| R-10.3 | Legalite incorrecte pour cartes locales (sans scryfallId) | Moyenne | Moyen | Exclure les cartes LOCAL: du rapport de legalite, afficher un avertissement |
| R-10.4 | Performance legalite sur gros decks (100 cartes Commander x 8 formats) | Faible | Faible | Calcul local en memoire (donnees deja chargees), pas de requete API supplementaire |
| R-10.5 | Format CSV non standardise entre apps | Moyenne | Moyen | Detecter les colonnes par header, supporter les variantes courantes |
| R-10.6 | Regression import existant (DeckListController.importDeck) | Faible | Haut | Conserver la methode existante, ajouter un service dedie en parallele |
| R-10.7 | Tags performance si beaucoup de tags (>50 tags uniques) | Faible | Faible | Pagination/scroll dans le dialog de tags, auto-complete avec debounce |

---

## 8. Dependances & Carte des Parties Prenantes

### Dependances internes

- **US-10.1 est independante** : nouveau service d'import, utilise `DeckService` et `ScryfallApiService` existants
- **US-10.2 est independante** : nouveau service d'export, utilise `Deck` model existant
- **US-10.3 est independante** : utilise `DeckDetailController.fullCardData` deja charge
- **US-10.4 est independante** : utilise `CollectionService` et `DeckCard.tags` deja presents
- **US-10.1 et US-10.2 partagent** : le service de parsing de decklists (memes formats)

### Ordre d'execution recommande

```
US-10.1 (Import)  ──────> US-10.2 (Export) ─── partagent le service de formats
                                    |
US-10.3 (Legalite) ──────────────── independant
                                    |
US-10.4 (Tags collection) ──────── independant, le plus simple
```

**Recommandation** : Commencer par US-10.1 (impact maximal), enchainer avec US-10.2 (partage le parsing), puis US-10.3 (legalite), enfin US-10.4 (tags, le plus simple).

### Parties prenantes

| Partie prenante | Role | Interet | Influence |
|----------------|------|---------|-----------|
| Alexis (dev) | Developpeur unique | Tres haut | Tres haute |
| Joueurs MTG migrants | Utilisateurs venant d'autres apps | **Tres haut** (import = adoption) | Haute |
| Joueurs competitifs | Utilisateurs de tournois | **Haut** (legalite = confiance) | Haute |
| CI/CD (GitHub Actions) | Pipeline automatise | Moyen (doit rester vert) | Haute |

---

## 9. Estimation

| User Story | Effort | Priorite | Dependances |
|------------|--------|----------|-------------|
| US-10.1 : Import multi-format | 4j | P0 | Aucune |
| US-10.2 : Export multi-format | 2j | P0 | Partage le parser avec US-10.1 |
| US-10.3 : Verification de legalite | 2j | P0 | Aucune |
| US-10.4 : Tags collection | 1j | P1 | Aucune |
| **Total** | **9j** | -- | -- |

### Scope ajustable (si retard)

1. **US-10.4** (tags collection) -> Sprint 11 (P1, 1j) -- le plus simple, le moins critique
2. **US-10.2 export CSV** -> Sprint 11 (garder export TXT, reporter CSV)
3. Les US-10.1, US-10.2 (TXT), et US-10.3 sont **P0 et non negociables**

---

## 10. Hors Scope Sprint 10

- Import depuis URL (coller un lien Moxfield -> scraper) -> Post-Sprint 12
- Export vers Moxfield API (necessite authentification) -> Post-Sprint 12
- Verification legalite en temps reel (pendant l'edition du deck) -> Sprint 12
- Tags avec couleurs personnalisees -> Sprint 12
- Import depuis fichier .dec ou .dek (formats MTGA/Cockatrice) -> Sprint 12
- EDHREC integration (themes, synergy) -> Sprint 11

---

## 11. Impact Utilisateur Attendu

| Feature | Impact UX | Frequence d'utilisation | Avantage concurrentiel |
|---------|-----------|------------------------|----------------------|
| US-10.1 : Import multi-format | **Tres haut** -- supprime le frein n°1 a l'adoption | A chaque migration/nouveau deck | Rattrape Moxfield, ManaBox, Archidekt |
| US-10.2 : Export multi-format | **Haut** -- partage et interoperabilite | A chaque partage de deck | Standard chez tous les concurrents |
| US-10.3 : Verification legalite | **Tres haut** -- confiance joueur competitif | Avant chaque tournoi/event | Dragon Shield et Moxfield l'ont |
| US-10.4 : Tags collection | **Moyen** -- organisation personnalisee | Frequente (gestion collection) | Archidekt et Dragon Shield l'ont |

*"Quatre coups. L'import brise le mur qui separe Magic Companion des autres apps. L'export ouvre la porte dans l'autre sens. La legalite plante le drapeau de la confiance. Les tags affutent la lame de l'organisation. Apres ce sprint, plus aucune excuse pour ne pas migrer."* -- Zorro
