# Audit Produit & Strategie UX - Magic Companion
### Par Vivi - Product Manager & UX Strategist
### Date : 8 mars 2026

---

## Table des matieres

1. [Phase 1 : Analyse Marche & Concurrence](#phase-1--analyse-marche--concurrence)
2. [Phase 2 : Personas & Recherche Utilisateur](#phase-2--personas--recherche-utilisateur)
3. [Phase 3 : User Flows & Parcours](#phase-3--user-flows--parcours)
4. [Phase 4 : Wireframes Conceptuels](#phase-4--wireframes-conceptuels)
5. [Phase 5 : Prioritisation Features](#phase-5--prioritisation-features)
6. [Phase 6 : Metriques Produit](#phase-6--metriques-produit)
7. [Phase 7 : Plan d'Experimentation](#phase-7--plan-dexperimentation)

---

## Etat des Lieux - Magic Companion (Sprint 13)

**Stack :** Flutter/Dart, Riverpod, go_router, drift/SQLite, Firebase, Scryfall API, EDHRec
**Code :** 144 fichiers Dart, ~40 154 lignes de code
**Pages :** cards, collections, decks, glossary, life_counter, oracle, scans, settings, tools, tournaments, wishlists

### Fonctionnalites actuelles

| Module | Fonctionnalites |
|--------|----------------|
| **Life Counter** | Multi-joueurs (2-6), timer de partie, damage commander, profils joueurs, historique parties, dice roll, wakelock |
| **Scanner** | OCR via google_mlkit, historique scans, recherche manuelle fallback |
| **Recherche** | ~27 000 cartes locales (Isolate), filtres avances, syntaxe Scryfall, vue grille/liste |
| **Decks** | Detail, edition, stats (courbe mana, fl_chart), suggestions EDHRec, import/export, partage visuel, tokens, combos, legalite, power level, synergies, simulateur de tirage |
| **Collections** | Par set, stats globales, badges, progression, ajout rapide |
| **Wishlists** | Multi-wishlists, detail |
| **Oracle IA** | Chat IA via Firebase Cloud Functions |
| **Tournois** | Gestion tournois |
| **Glossaire** | FR/EN, guide des tours |
| **Outils** | Calculateur hypergeometrique |
| **Settings** | Profils, sauvegarde Google Drive, outils dev |

---

## Phase 1 : Analyse Marche & Concurrence

### 1.1 Taille du Marche

| Segment | Estimation | Source |
|---------|-----------|--------|
| **TAM** (Total Addressable Market) | 50M+ joueurs MTG dans le monde, marche $1.2B+ (2023) | Hasbro Investor Relations |
| **SAM** (Serviceable Available Market) | ~20M joueurs mobile actifs (joueurs papier + Arena utilisant des apps compagnon) | Estimation basee sur 45% NA + croissance APAC |
| **SOM** (Serviceable Obtainable Market) | 50K-200K utilisateurs (niche francophone + early adopters internationaux) | Hypothese a valider |

**Demographique cle :** 38% des joueurs ont 18-24 ans, age moyen tabletop ~30 ans, 28% de femmes (en hausse).

### 1.2 Cartographie Concurrentielle

#### Apps Mobiles Natives (Concurrents directs)

| Attribut | **Magic Companion** | **ManaBox** | **TopDecked** | **Delver Lens** | **Dragon Shield** |
|----------|-------------------|-------------|--------------|----------------|-------------------|
| **Cible** | Joueurs FR papier | Joueurs papier toutes langues | Joueurs competitifs | Collectionneurs scanners | Collectionneurs/traders |
| **Proposition valeur** | All-in-one FR + Oracle IA | Scanner + collection + decks | Metagame + life counter + prix | Scanner rapide + export multi | Scanner + social + trading |
| **Pricing** | Gratuit | Freemium (Premium) | Freemium (Abo mensuel/annuel) | Freemium | Gratuit |
| **Scanner** | OCR texte (MLKit) | Scanner par artwork (rapide) | Non | Scanner par artwork (reference) | Scanner multi-langues (avance) |
| **Life Counter** | Oui (2-6j, commander dmg, timer) | Basique | Oui (jusqu'a 6j, commander, monarch, infect) | Non | Non |
| **Deck Builder** | Oui (import/export, stats) | Oui (simulateur) | Oui (basique) | Basique | Oui (basique) |
| **Collection** | Oui (par set, stats) | Oui (binders, bulk actions) | Oui (cloud sync) | Oui (export multi-plateformes) | Oui (folders, valeur) |
| **Prix cartes** | Non | Oui (multi-sources) | Oui (trends quotidiens) | Oui (TCG, CK, CM, CH) | Oui (TCG, CM, historique 30j) |
| **Social** | Non | Partage basique | Non | Sync multi-devices | Amis, wishlists, trade lists |
| **Offline** | Oui (DB locale 27K cartes) | Partiel | Partiel | Oui (sync a la reconnexion) | Partiel |
| **IA** | Oui (Oracle Firebase) | Non | Non | Non | Non |
| **Forces** | All-in-one, Oracle IA, offline, FR | Scanner artwork excellent, UX polish | Metagame data, articles | Export universel, precision scan | Social features, multi-langues |
| **Faiblesses** | Pas de prix, scanner OCR (lent), pas de social | Peu de features avancees | UX datee, payant | Android only (longtemps), pas de life counter | Pas de life counter, basique |

#### Plateformes Web (Concurrents indirects)

| Attribut | **Moxfield** | **Archidekt** | **MTGGoldfish** | **Scryfall** | **TCGPlayer** |
|----------|-------------|--------------|----------------|-------------|---------------|
| **Cible** | Deckbuilders serieux | Joueurs visuels Commander | Competitifs/investisseurs | Devs/joueurs avances | Acheteurs/vendeurs |
| **Force cle** | Collaboration temps reel, UX moderne | Drag-and-drop visuel, EDHREC integration | Metagame data, Super Brew, prix historiques | API reference, syntaxe recherche | Marketplace, scanner rapide |
| **App mobile** | Web responsive | App native (recente) | Non (web only) | Non (web only) | App native |
| **Prix cartes** | TCG, CK | TCG, CK, CM, CH | Oui (historiques) | Oui (multi-sources) | Source de reference |

### 1.3 Differentiateurs Cles

#### Ce que Magic Companion fait MIEUX que tous les autres

1. **Oracle IA integre** - Aucun concurrent n'a d'assistant IA natif capable de repondre aux questions de regles, suggerer des cartes, analyser des strategies. C'est un avantage competitif majeur et unique.
2. **All-in-one offline FR** - La combinaison life counter + scanner + decks + collection + wishlists + glossaire FR dans une seule app mobile offline est rare. ManaBox s'en approche mais sans le glossaire FR ni l'Oracle IA.
3. **Glossaire FR/EN avec guide des tours** - Aucun concurrent ne propose un glossaire bilingue integre avec guide des phases de tour.

#### Ce qui MANQUE sur le marche (Opportunites)

- **Scanner par artwork** (pas par OCR texte) - Plus rapide, plus fiable, ce que font ManaBox et Delver Lens
- **Prix en temps reel integres** - Tous les concurrents serieux l'ont, Magic Companion non
- **Mode playtest/goldfish** - Moxfield et Archidekt l'ont, pas nous
- **Social/communautaire** - Dragon Shield a des amis/trade lists, aucun concurrent mobile n'a de vrai social
- **Metagame data** - TopDecked et MTGGoldfish dominent, aucune app all-in-one ne l'integre bien
- **Suivi de valeur collection** - Manque critique pour les collectionneurs

#### Notre Unfair Advantage

- **Oracle IA (Firebase Cloud Functions)** - Difficile a repliquer, necessite infrastructure backend + prompt engineering MTG
- **Base locale 27K cartes + Isolate** - Performance offline superieure
- **Stack Flutter** - Deploiement cross-platform (Android + iOS) avec un seul codebase
- **Agilite** - Pas de legacy code massif, sprints rapides, capacite a innover vite

---

## Phase 2 : Personas & Recherche Utilisateur

### Persona 1 : Thomas - Le Commandant du Vendredi Soir

| Attribut | Detail |
|----------|--------|
| **Role** | Joueur Commander casual, participe a la Commander Night hebdomadaire |
| **Age / Experience** | 28 ans, joue depuis 5 ans, 3-4 decks Commander |
| **Objectifs** | Tracker ses parties, gerer ses decks, trouver des upgrades abordables |
| **Frustrations** | Jongle entre 3-4 apps (Moxfield pour les decks, ManaBox pour scanner, une app life counter), perd du temps a chercher les prix |
| **Comportement actuel** | Utilise Moxfield sur PC, ManaBox pour scanner ses achats, l'app officielle WotC pour les events |
| **Citation typique** | "J'aimerais une seule app qui fasse tout, sans payer un abo" |
| **Critere de decision** | Gratuit, tout-en-un, fonctionne offline en LGS, rapide |
| **Willingness to pay** | 0-3EUR/mois max, prefere gratuit avec pub acceptable |

### Persona 2 : Sophie - La Collectionneuse Methodique

| Attribut | Detail |
|----------|--------|
| **Role** | Collectionneuse serieuse, suit la valeur de sa collection, trade regulierement |
| **Age / Experience** | 34 ans, joue depuis 12 ans, 2000+ cartes en collection |
| **Objectifs** | Savoir combien vaut sa collection, identifier les cartes a trader, suivre les prix |
| **Frustrations** | Scanner ses cartes prend trop de temps, pas de suivi de valeur en temps reel, export complique |
| **Comportement actuel** | Utilise Delver Lens pour scanner, un tableur Excel pour le suivi prix, TCGPlayer pour les valeurs |
| **Citation typique** | "Je veux savoir instantanement combien vaut ma collection et quoi trader" |
| **Critere de decision** | Scanner rapide et fiable, prix integres, export facile |
| **Willingness to pay** | 5-10EUR/mois pour un outil complet de gestion de collection |

### Persona 3 : Maxime - Le Competitif Ambitieux

| Attribut | Detail |
|----------|--------|
| **Role** | Joueur competitif Modern/Standard, participe a des tournois RCQ/Pro Tour Qualifier |
| **Age / Experience** | 22 ans, joue depuis 3 ans, focus formats competitifs |
| **Objectifs** | Suivre le metagame, optimiser ses decks, tester ses mains de depart, tracker ses resultats de tournoi |
| **Frustrations** | Doit consulter MTGGoldfish pour le meta, Moxfield pour le deck, une autre app pour le playtest |
| **Comportement actuel** | MTGGoldfish pour le metagame, Moxfield pour deckbuild, notes papier pour ses resultats |
| **Citation typique** | "Je veux savoir si mon deck est bien positionne dans le meta actuel" |
| **Critere de decision** | Donnees metagame a jour, simulateur de tirage, stats de tournoi |
| **Willingness to pay** | 5-8EUR/mois pour un avantage competitif |

### Persona 4 : Julie - La Debutante Curieuse

| Attribut | Detail |
|----------|--------|
| **Role** | Nouvelle joueuse, initiee par des amis, joue en casual Kitchen Table |
| **Age / Experience** | 19 ans, joue depuis 3 mois, 1 deck pre-construit |
| **Objectifs** | Comprendre les regles, identifier les cartes qu'elle recoit, construire son premier deck |
| **Frustrations** | Le jargon MTG est incomprehensible, ne sait pas quelles cartes sont bonnes, intimidee par la communaute |
| **Comportement actuel** | Google chaque mot-cle, demande a ses amis, regarde des videos YouTube |
| **Citation typique** | "C'est quoi le 'trample' deja ? Et cette carte, elle est rare ?" |
| **Critere de decision** | Simple a utiliser, explications claires en francais, pas besoin de connaitre le jargon |
| **Willingness to pay** | 0EUR, gratuit uniquement |

### Persona 5 : Antoine - Le Joueur de Cuisine Nostalgique

| Attribut | Detail |
|----------|--------|
| **Role** | Joueur casual, reprend MTG apres 10 ans d'arret, joue en famille |
| **Age / Experience** | 42 ans, jouait en 2005-2012, reprend avec ses enfants ados |
| **Objectifs** | Retrouver la valeur de ses vieilles cartes, construire des decks pour jouer en famille, comprendre les nouvelles regles |
| **Frustrations** | Le jeu a beaucoup change, ses cartes sont peut-etre devenues illegales, ne sait pas quoi garder |
| **Comportement actuel** | A des boites de vieilles cartes, cherche sur eBay pour les prix |
| **Citation typique** | "Est-ce que mes vieilles cartes valent quelque chose ? On peut encore jouer avec ?" |
| **Critere de decision** | Facile a comprendre, scanner ses vieilles cartes, voir la legalite |
| **Willingness to pay** | 3-5EUR ponctuellement |

### Jobs-to-be-Done (JTBD)

| Quand... | Je veux... | Pour que... |
|----------|-----------|------------|
| Je suis en partie Commander | Tracker les vies de tout le monde facilement | On ne perde pas le fil de la partie |
| Je recois un booster | Scanner mes cartes rapidement | Je sache ce que j'ai obtenu et sa valeur |
| Je construis un deck | Voir les stats et les suggestions | Mon deck soit optimise pour mon budget |
| Je suis au LGS sans WiFi | Acceder a toute l'app | Je puisse jouer et chercher sans connexion |
| Je ne comprends pas une regle | Demander a l'Oracle IA | J'aie une reponse claire instantanement |
| Je veux savoir si mon deck est bon | Voir ou il se situe dans le meta | Je sache si je suis bien positionne pour le tournoi |
| Je veux trader | Voir la valeur de mes cartes et de mes wants | Je fasse des trades equitables |
| Je veux ameliorer mon deck | Voir quelles cartes ajouter/retirer | Mon deck soit plus performant sans me ruiner |
| Je debute | Comprendre les termes et les mecaniques | Je puisse jouer sans poser trop de questions |

---

## Phase 3 : User Flows & Parcours

### Flow 1 : Premiere Utilisation (Onboarding)

```
[Splash Screen] --> [Choix Langue FR/EN] --> [Onboarding 3 ecrans]
                                                    |
                                              [Ecran 1: Scanner]
                                              "Scannez vos cartes"
                                                    |
                                              [Ecran 2: Decks]
                                              "Gerez vos decks"
                                                    |
                                              [Ecran 3: Oracle]
                                              "Posez vos questions"
                                                    |
                                            [Creation Profil]  --> [Home Dashboard]
                                            (Nom, avatar, format)        |
                                                                   [Aha! Moment]
                                                                   Scanner 1ere carte
```

**Points de friction :** Pas d'onboarding actuel, l'utilisateur arrive directement sur le life counter sans comprendre les features.
**Aha! Moment :** Scanner sa premiere carte et voir toutes les infos + l'ajouter a la collection.
**Time-to-Value :** Cible < 60 secondes (scan premiere carte).

### Flow 2 : Session de Jeu Commander

```
[Home] --> [Life Counter] --> [Game Setup Modal]
                                    |
                              [Choix joueurs: 2-6]
                              [Choix vie: 20/30/40]
                              [Choix profils]
                                    |
                              [Partie en cours]
                              [+1/-1, long tap +10/-10]
                              [Commander damage]
                              [Timer]
                                    |
                    ┌───────────────┼───────────────┐
                    |               |               |
              [Dice Roll]    [Monarch/Infect]  [Fin partie]
                                                    |
                                              [Recap partie]
                                              [Sauvegarder?]
                                                    |
                                              [Historique]
```

**Points de friction :** Pas de raccourci pour relancer une partie avec les memes joueurs. Pas de compteurs poison/energy visibles.
**Aha! Moment :** Le timer automatique + l'historique qui se sauvegarde.
**Time-to-Value :** < 15 secondes pour commencer a jouer.

### Flow 3 : Scan & Ajout Collection

```
[Home] --> [Scanner] --> [Camera active]
                              |
                        [OCR detecte texte]
                        [Recherche carte]
                              |
                    ┌─────────┼─────────┐
                    |                   |
              [Carte trouvee]    [Non trouvee]
              [Afficher detail]  [Recherche manuelle]
                    |                   |
              [Actions rapides]   [Modal recherche]
              ┌─────┼─────┐           |
              |     |     |     [Resultats]
         [+Coll] [+Deck] [+Wish]     |
              |                 [Selection]
              |                       |
              └───────────────────────┘
                        |
                  [Confirmation]
                  [Continuer scan]
```

**Points de friction :** L'OCR texte est lent et peu fiable vs scanner par artwork. Pas de mode batch/rapide.
**Aha! Moment :** La carte est reconnue et ajoutee en un tap.
**Time-to-Value :** Actuellement ~5-10s/carte (cible: < 2s avec scan artwork).

### Flow 4 : Construction/Edition de Deck

```
[Home] --> [Mes Decks] --> [+ Nouveau Deck]
                                 |
                           [Infos deck]
                           (Nom, format, commander)
                                 |
                           [Deck Detail Page]
                           [Tabs: Cartes | Stats | Suggestions | Tokens | Legalite]
                                 |
                    ┌────────────┼────────────┐
                    |            |            |
              [Card Picker]  [Stats Tab]  [Suggestions]
              [Recherche]    [Mana curve] [EDHRec]
              [Ajout carte]  [Type dist]  [Cartes suggerees]
                    |            |            |
                    └────────────┼────────────┘
                                 |
                           [Export/Partage]
                           [Moxfield, texte, image]
```

**Points de friction :** Pas de suggestions de remplacement budget. Pas de validation de legalite en temps reel pendant l'ajout. Pas de playtest.
**Aha! Moment :** Les suggestions EDHRec qui montrent quoi ajouter.
**Time-to-Value :** ~5 min pour un deck de base (cible: < 3 min avec IA).

---

## Phase 4 : Wireframes Conceptuels - Nouvelles Features

### 4.1 Ecran : Dashboard Home (NOUVEAU)

**Objectif :** Point d'entree unique qui montre l'essentiel et oriente vers l'action

```
┌─────────────────────────────────────────────┐
│  [Logo MC]              [Profil] [Notifs 3] │
├─────────────────────────────────────────────┤
│                                             │
│  Bonjour Thomas !                   [Scan]  │
│  "Prochaine Commander Night: Vendredi"      │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Cartes   │  │ Valeur   │  │ Decks    │  │
│  │ 1,247    │  │ 342 EUR  │  │ 5        │  │
│  │ +12 sem. │  │ +8% mois │  │ actifs   │  │
│  └──────────┘  └──────────┘  └──────────┘  │
│                                             │
│  -- Activite Recente --                     │
│  [Partie Commander 45min - Victoire!]       │
│  [Scan: Black Lotus... non, Swamp x4]       │
│  [Deck "Atraxa" modifie]                    │
│                                             │
│  -- Acces Rapide --                         │
│  [Life Counter] [Scanner] [Oracle] [Decks]  │
│                                             │
│  -- Carte du Jour --                        │
│  [Image carte aleatoire de la collection]   │
│  "Saviez-vous que..." (fun fact Oracle IA)  │
│                                             │
└─────────────────────────────────────────────┘
│ [Home] [Cartes] [Scan] [Decks] [Plus]       │
└─────────────────────────────────────────────┘
```

**Elements cles :**
- CTA principal : Bouton Scan flottant (action la plus frequente)
- Donnees affichees : Stats collection, activite recente, carte du jour
- Interactions : Pull-to-refresh, tap sur metriques pour naviguer, carte du jour swipeable

### 4.2 Ecran : Prix & Valeur Collection (NOUVEAU)

**Objectif :** Voir la valeur de sa collection et suivre les tendances de prix

```
┌─────────────────────────────────────────────┐
│  [<] Valeur Collection        [Filtre] [Tri]│
├─────────────────────────────────────────────┤
│                                             │
│  Valeur Totale                              │
│  ┌─────────────────────────────────────┐    │
│  │        EUR 342.50  (+8.2%)          │    │
│  │  [Graphique evolution 30j/90j/1an]  │    │
│  │  ~~~~~~~~~/\~~~~~~~/\~~~            │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  -- Top Cartes par Valeur --                │
│  ┌─────┬────────────────────┬────────┐      │
│  │ Img │ Rhystic Study      │ 45 EUR │      │
│  │     │ Prophet's Prophecy │ +12%   │      │
│  ├─────┼────────────────────┼────────┤      │
│  │ Img │ Cyclonic Rift      │ 32 EUR │      │
│  │     │ Commander 2024     │ -3%    │      │
│  ├─────┼────────────────────┼────────┤      │
│  │ Img │ Smothering Tithe   │ 28 EUR │      │
│  │     │ Ravnica Allegiance │ +5%    │      │
│  └─────┴────────────────────┴────────┘      │
│                                             │
│  -- Movers (24h) --                         │
│  [Hausse]  Carte A +15%  |  Carte B +8%    │
│  [Baisse]  Carte C -10%  |  Carte D -5%    │
│                                             │
└─────────────────────────────────────────────┘
```

**Elements cles :**
- CTA : Tap sur carte pour voir detail prix
- Donnees : Prix TCGPlayer/CardMarket, evolution, top cartes
- Interactions : Graphique interactif (pinch-to-zoom), swipe entre periodes, tri par valeur/evolution

### 4.3 Ecran : Playtest / Goldfish Mode (NOUVEAU)

**Objectif :** Tester un deck en solitaire, simuler des mains de depart

```
┌─────────────────────────────────────────────┐
│  [<] Playtest: Atraxa Counters    [Reset]   │
├─────────────────────────────────────────────┤
│                                             │
│  Main (7)                          Tour: 1  │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐             │
│  │Card│ │Card│ │Card│ │Card│ ...          │
│  │ 1  │ │ 2  │ │ 3  │ │ 4  │             │
│  └────┘ └────┘ └────┘ └────┘             │
│                                             │
│  [Mulligan]  [Garder]  [Piocher]           │
│                                             │
│  -- Zones --                                │
│  Champ de bataille:  [drop zone]            │
│  Cimetiere: (0)    Exil: (0)               │
│  Bibliotheque: (92)                         │
│                                             │
│  -- Stats en Direct --                      │
│  Mana disponible: 0                         │
│  Cartes en main: 7                          │
│  Probabilite prochaine terre: 42%           │
│                                             │
│  [Passer au tour suivant -->]               │
│                                             │
└─────────────────────────────────────────────┘
```

**Elements cles :**
- CTA : Piocher, Mulligan, Jouer une carte
- Interactions : Drag-and-drop cartes entre zones, tap pour voir detail, undo/redo

### 4.4 Ecran : Trade Helper (NOUVEAU)

**Objectif :** Faciliter les echanges equitables entre joueurs

```
┌─────────────────────────────────────────────┐
│  [<] Trade Helper                    [Fair?]│
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  MOI                    PARTENAIRE  │    │
│  │                                     │    │
│  │  [+ Ajouter carte]  [+ Ajouter]    │    │
│  │                                     │    │
│  │  Rhystic Study     Dockside Extort  │    │
│  │  45.00 EUR         62.00 EUR        │    │
│  │                                     │    │
│  │  Sol Ring           Mana Crypt      │    │
│  │  3.50 EUR          28.00 EUR        │    │
│  │                                     │    │
│  │  ─────────────────────────────────  │    │
│  │  Total: 48.50 EUR  Total: 90.00 EUR│    │
│  │                                     │    │
│  │  [Difference: -41.50 EUR]           │    │
│  │  [Pas equitable]                    │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Suggestions pour equilibrer:               │
│  "Ajoutez Fierce Guardianship (38 EUR)"     │
│                                             │
│  [Scanner carte] [Rechercher] [Valider]     │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Phase 5 : Prioritisation Features

### 5.1 Fonctionnalites Manquantes vs Concurrence (Gap Analysis)

| Feature | Moxfield | ManaBox | TopDecked | Delver Lens | Dragon Shield | **Magic Companion** |
|---------|----------|---------|-----------|-------------|---------------|-------------------|
| Prix cartes temps reel | Oui | Oui | Oui | Oui | Oui | **NON** |
| Scanner par artwork | N/A | Oui | N/A | Oui | Oui | **NON (OCR)** |
| Mode playtest/goldfish | Oui | Oui | Non | Non | Non | **NON** |
| Compteurs poison/energy | N/A | N/A | Oui | N/A | N/A | **NON** |
| Import/Export deck multi-format | Oui | Oui | Oui | Export 12+ | Oui | **PARTIEL** |
| Social (amis, partage) | Oui (commentaires) | Basique | Non | Non | Oui (amis) | **NON** |
| Metagame data | Non | Non | Oui | Non | Non | **NON** |
| Valeur collection temps reel | Non | Oui | Oui | Oui | Oui | **NON** |
| Mode batch scan | N/A | Oui | N/A | Oui | Oui | **NON** |
| Historique prix | Non | Oui | Oui | Non | Oui (30j) | **NON** |
| Recommandations IA | Non | Non | Non | Non | Non | **OUI (Oracle)** |
| Glossaire bilingue | Non | Non | Non | Non | Non | **OUI** |
| Calculateur hypergeometrique | Non | Non | Non | Non | Non | **OUI** |
| Dashboard home | N/A | Oui | Oui | Non | Non | **NON** |
| Onboarding | N/A | Oui | Oui | Non | Oui | **NON** |
| Notifications (spoilers, prix) | Non | Non | Non | Non | Non | **NON** |
| Multi-format deck validation | Oui | Oui | Oui | Non | Non | **OUI** |

### 5.2 Matrice Impact/Effort (RICE)

**Reach** : % de users impactes (1-10)
**Impact** : Benefice pour l'utilisateur (1-10)
**Confidence** : Confiance dans l'estimation (0.5-1.0)
**Effort** : Sprints necessaires (1-10)

| # | Feature | Reach | Impact | Confidence | Effort | Score RICE | Priorite |
|---|---------|-------|--------|------------|--------|-----------|----------|
| 1 | **Prix cartes integres (Scryfall API)** | 9 | 9 | 0.9 | 3 | **24.3** | P0 |
| 2 | **Compteurs poison/energy/monarch** (life counter) | 8 | 7 | 0.9 | 1 | **50.4** | P0 |
| 3 | **Dashboard Home** | 10 | 6 | 0.8 | 2 | **24.0** | P0 |
| 4 | **Onboarding 3 ecrans** | 10 | 5 | 0.8 | 1 | **40.0** | P0 |
| 5 | **Mode playtest/goldfish** | 6 | 8 | 0.7 | 5 | **6.7** | P1 |
| 6 | **Valeur collection temps reel** | 7 | 8 | 0.8 | 4 | **11.2** | P1 |
| 7 | **Trade Helper** | 5 | 7 | 0.6 | 3 | **7.0** | P1 |
| 8 | **Amelioration scanner (artwork)** | 8 | 9 | 0.5 | 8 | **4.5** | P2 |
| 9 | **Metagame data integration** | 4 | 7 | 0.6 | 6 | **2.8** | P2 |
| 10 | **Mode batch scan** | 6 | 6 | 0.7 | 4 | **6.3** | P1 |
| 11 | **Social features (amis, partage decks)** | 5 | 5 | 0.5 | 7 | **1.8** | P3 |
| 12 | **Notifications prix/spoilers** | 6 | 4 | 0.6 | 3 | **4.8** | P2 |
| 13 | **Oracle IA - suggestions deck auto** | 7 | 8 | 0.7 | 4 | **9.8** | P1 |
| 14 | **Historique prix 30j/90j** | 6 | 5 | 0.8 | 2 | **12.0** | P1 |
| 15 | **Export multi-plateformes** | 5 | 4 | 0.9 | 2 | **9.0** | P1 |

### 5.3 Feature Map par Release

| Release | Features | Objectif | Critere de succes |
|---------|----------|----------|-------------------|
| **Sprint 14 (Quick Wins)** | Onboarding, Dashboard Home, Compteurs poison/energy/monarch, Prix cartes (Scryfall prices) | Time-to-value < 60s, gap concurrentiel reduit | 80% completion onboarding, +30% retention J7 |
| **Sprint 15-16 (Collection+)** | Valeur collection, Historique prix, Mode batch scan, Export multi-plateformes | Devenir le meilleur tracker de collection mobile | 50% users activent collection, +20% DAU |
| **Sprint 17-18 (Deck Master)** | Mode playtest/goldfish, Oracle IA suggestions deck, Trade Helper | Deckbuilding superieur a la concurrence | 30% users utilisent playtest, +15% sessions/user |
| **Sprint 19-20 (Social & Meta)** | Metagame data, Social features, Notifications | Retention long terme et viralite | NPS > 50, viral coefficient > 0.5 |
| **Sprint 21+ (Moon Shot)** | Scanner artwork (ML), AR card overlay, Mode draft simulator | Differenciation radicale | 2s/scan, +40% acquisition |

---

## Phase 5bis : Idees de Features Innovantes

### 5bis.1 Features "Waouh" - Innovations non presentes chez les concurrents

| # | Feature | Description | Pourquoi c'est innovant |
|---|---------|-------------|------------------------|
| 1 | **Oracle IA - Analyse de Board State** | Prendre une photo du plateau de jeu, l'IA identifie les cartes et suggere le meilleur coup | Aucun concurrent ne fait ca. Combine scanner + IA |
| 2 | **Mode "Budget Upgrade"** | L'Oracle IA analyse un deck et propose des upgrades par palier de budget (5EUR, 20EUR, 50EUR) | ManaBox et les autres n'ont pas de budget optimizer |
| 3 | **"Deck Doctor"** | Soumettre un deck a l'Oracle IA qui fait un diagnostic complet : mana base, courbe, synergies, faiblesses, et propose un plan d'amelioration | Combine EDHRec data + IA pour un conseil personalise |
| 4 | **Mode "Collection Challenge"** | Gamification : challenges hebdomadaires ("Scannez 10 cartes cette semaine", "Construisez un deck mono-rouge") avec badges et progression | Personne ne gamifie la gestion de collection |
| 5 | **"What's in the Pack?" Simulator** | Simuler l'ouverture de boosters avec les vraies probabilites de rarete, pour decider si ca vaut le coup d'acheter | Fun + utile pour les collectionneurs |
| 6 | **Mode "Proxy Generator"** | A partir d'un deck, generer des proxies imprimables (images formatees pour impression A4 a decouper) | Les joueurs budget adoreraient ca |
| 7 | **"Rule Judge" Live** | Pendant une partie (life counter actif), bouton rapide "Question de regles" qui ouvre l'Oracle IA avec le contexte des cartes en jeu | Integration contextuelle life counter + Oracle |
| 8 | **"Price Alert"** | Definir des alertes de prix sur des cartes de la wishlist ("Previens-moi si Rhystic Study passe sous 30EUR") | Dragon Shield a les prix mais pas les alertes |
| 9 | **"Deck Matchup Simulator"** | Comparer 2 decks en termes de probabilites statistiques (qui a le meilleur curve, qui a plus de removal, etc.) | Analyse statistique avancee, aucun concurrent mobile |
| 10 | **"Collection Binder View"** | Vue type classeur de collection physique avec pages de 9 cartes, swipe entre les pages, possibilite de reorganiser | Nostalgie + UX satisfaisante |

### 5bis.2 Features IA Avancees (Leveraging Oracle)

| # | Feature | Prompt IA type |
|---|---------|---------------|
| 1 | **"Explain Like I'm New"** | "Explique cette carte comme si je debutais au MTG" - simplification du texte pour les debutants |
| 2 | **"What beats this?"** | "Quelles cartes/strategies countre [carte X] ?" - aide tactique |
| 3 | **"Build Around"** | "Construis-moi un deck autour de [carte X] en format [Y] avec un budget de [Z]EUR" |
| 4 | **"Flavor Lore"** | "Raconte-moi l'histoire/lore de cette carte et de ce personnage" - engagement storytelling |
| 5 | **"Trade Advisor"** | "Est-ce un bon moment pour trader/vendre [carte X] ? Tendance des prix ?" |

---

## Phase 6 : Animations & Micro-Interactions "Waouh"

### 6.1 Life Counter - Animations

| Animation | Description | Implementation Flutter |
|-----------|-------------|----------------------|
| **Pulse de Vie** | Quand la vie change, le chiffre pulse (scale up puis down) avec une couleur verte (+) ou rouge (-) | `AnimatedScale` + `ColorTween` |
| **Shake de Degats** | Quand la vie diminue, la zone du joueur tremble legerement | `Transform.translate` avec `sin()` oscillation sur `AnimationController` |
| **Explosion de Particules** | A 0 PV, explosion de particules rouges depuis le compteur du joueur elimine | Custom `CustomPainter` avec `Particle` system ou package `confetti` |
| **Dice Roll 3D** | Animation de de qui roule avec rotation 3D avant de reveler le resultat | `Transform` avec `Matrix4.rotationX/Y` + `AnimationController` |
| **Glow Monarch** | Le joueur Monarch a un contour dore qui pulse doucement | `AnimatedContainer` avec `BoxShadow` anime, couleur or |
| **Poison Drip** | Quand le compteur poison augmente, animation de goutte violette qui coule | `CustomPainter` avec bezier curve animee |
| **Counter Tick** | Chaque changement de vie, petit son + vibration haptique | `HapticFeedback.lightImpact()` + audio |
| **Victory Crown** | Quand un joueur gagne, couronne animee qui descend sur son nom | `SlideTransition` + `RotationTransition` |

### 6.2 Scanner - Animations

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Scan Line** | Ligne laser qui balaye la carte de haut en bas pendant la detection | `AnimatedPositioned` ou `CustomPainter` avec `LinearGradient` |
| **Card Reveal** | Quand la carte est detectee, elle "apparait" avec un effet de materialisation (fade + scale depuis le centre) | `AnimatedOpacity` + `AnimatedScale` + `AnimatedAlign` |
| **Shimmer Loading** | Pendant la recherche, le placeholder de la carte a un effet shimmer (reflet qui passe) | Package `shimmer` ou custom `ShaderMask` avec `LinearGradient` anime |
| **Success Checkmark** | Apres ajout a la collection, checkmark vert anime qui se dessine | `CustomPainter` avec `Path` + `PathMetric` anime |
| **Card Stack** | En mode batch, les cartes scannees s'empilent visuellement avec un leger offset et rotation | `Stack` + `Transform.rotate` avec index-based offset |

### 6.3 Cartes - Animations & Effets

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Foil Shimmer** | Les cartes foil ont un reflet holographique qui bouge avec le gyroscope du telephone | `sensors_plus` pour gyroscope + `ShaderMask` avec `LinearGradient` anime par les donnees accelerometre |
| **Card Flip** | Tap sur une carte double-face = animation de retournement 3D | `AnimatedSwitcher` custom avec `Transform(transform: Matrix4.rotationY(angle))` |
| **Parallax Scroll** | Dans la liste de cartes, l'artwork a un leger effet de parallaxe au scroll | `NotificationListener<ScrollNotification>` + `Transform.translate` proportionnel au scroll |
| **Card Zoom Hero** | Tap sur une carte = transition Hero avec zoom fluide vers la page detail | `Hero` widget natif Flutter avec `flightShuttleBuilder` custom |
| **Rarity Glow** | Les cartes Mythic ont un glow orange, Rare un glow dore, autour de la bordure | `BoxDecoration` avec `BoxShadow` colore selon rarete |
| **Tap to Peek** | Long press sur une carte dans le deck = preview en overlay semi-transparent | `Overlay` + `AnimatedOpacity` positionne sous le doigt |
| **Swipe to Add** | Dans la recherche, swipe droite pour ajouter a la collection, swipe gauche pour wishlist | `Dismissible` avec `background` colore et icone |

### 6.4 Navigation & UI Globale

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Page Transitions** | Transitions de page avec un fade + slide subtil plutot que le push standard | `CustomTransitionPage` dans `go_router` avec `FadeTransition` + `SlideTransition` |
| **Bottom Nav Morph** | L'icone active de la bottom nav s'anime (scale + couleur) avec un indicateur qui slide | `AnimatedContainer` pour l'indicateur + `TweenAnimationBuilder` pour les icones |
| **Pull-to-Refresh Mana** | Au pull-to-refresh, animation de symboles de mana qui tombent/tournent | Custom `RefreshIndicator` avec `CustomPainter` de symboles mana |
| **Skeleton Loading** | Au chargement, squelette anime des elements a venir (pas un simple spinner) | Package `skeletonizer` ou custom `ShimmerEffect` |
| **Snackbar Toast Anime** | Les confirmations (carte ajoutee, deck sauvegarde) avec slide-in depuis le bas + icone animee | `ScaffoldMessenger` custom avec `AnimatedSlide` |
| **FAB Expansion** | Le bouton flottant s'expand en menu avec les options (deja Speed Dial, mais ajouter animations d'entree pour chaque option) | `flutter_speed_dial` customise avec `staggeredAnimation` |
| **Theme Transition** | Si passage dark/light mode, transition fluide (pas de flash) | `AnimatedTheme` wrapping `MaterialApp` |
| **Empty State Illustrations** | Les ecrans vides (pas de decks, pas de cartes) avec illustration animee SVG/Lottie | Package `lottie` avec animations custom |

### 6.5 Deck Builder - Animations

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Mana Curve Build** | La courbe de mana s'anime quand on arrive sur l'onglet Stats (barres qui montent une par une) | `fl_chart` avec `animationDuration` + staggered delay |
| **Card Count Badge** | Quand on ajoute une carte au deck, le badge compteur bounce | `AnimatedScale` avec curve `Curves.elasticOut` |
| **Drag Reorder** | Reorganiser les cartes par drag-and-drop avec animation de "pickup" (carte qui s'eleve et a une ombre) | `ReorderableListView` avec `proxyDecorator` custom ajoute elevation + rotation |
| **Power Level Gauge** | Le badge power level s'anime comme une jauge qui se remplit | Custom `CustomPainter` avec arc anime + `AnimationController` |
| **Suggestion Appear** | Les suggestions EDHRec arrivent en cascade (staggered animation) | `AnimatedList` avec `SlideTransition` et delay incremental |

### 6.6 Collection - Animations

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Completion Ring** | Le pourcentage de completion d'un set s'anime en cercle progressif | `CustomPainter` avec arc + `Tween<double>` |
| **Badge Unlock** | Quand un badge est debloque, animation speciale (shine + bounce + confetti) | `confetti` package + custom `AnimatedScale` + `ShaderMask` |
| **Value Counter** | La valeur totale de la collection s'anime en "counting up" | `TweenAnimationBuilder<double>` avec formattage nombre |
| **Set Grid Stagger** | La grille de sets apparait avec une animation staggered (chaque set arrive avec un leger delay) | `AnimatedGrid` ou `SliverList` avec `AnimatedBuilder` et delay par index |

---

## Phase 7 : Idees UI/UX pour Moderniser l'App

### 7.1 Design System & Theming

| Aspect | Etat Actuel | Proposition |
|--------|-------------|-------------|
| **Palette couleurs** | app_colors.dart basique | Palette etendue avec couleurs semantiques MTG (blanc, bleu, noir, rouge, vert + incolore + multi) |
| **Typography** | Google Fonts | Hierarchie typographique stricte : Display (Cinzel pour le cote "fantaisie MTG"), Body (Inter/Roboto), Mono (pour les stats) |
| **Spacing** | Ad hoc | Systeme de spacing 4/8/12/16/24/32/48 avec constantes nommees |
| **Composants** | Widgets custom eparpilles | Design system unifie avec MtgCard, MtgButton, MtgBadge, MtgInput comme composants de base |
| **Icones** | Material Icons | Mix Material + icones custom MTG (symboles mana, symboles set) en SVG |
| **Mode sombre** | Probablement oui | Vrai dark mode OLED (noir pur #000) avec accents lumineux |

### 7.2 Patterns UX Modernes a Adopter

| Pattern | Description | Ou l'appliquer |
|---------|-------------|---------------|
| **Bottom Sheet > Dialog** | Remplacer les dialogs par des bottom sheets (plus mobile-friendly) | Filtres, confirmations, options |
| **Swipe Actions** | Actions contextuelles par swipe sur les listes | Collection (supprimer, deplacer), Decks (editer, dupliquer) |
| **Contextual FAB** | Le FAB change selon la page (Scan sur home, + sur decks, dice sur life counter) | Navigation globale |
| **Search Everywhere** | Barre de recherche universelle accessible depuis n'importe quel ecran | AppBar globale avec raccourci recherche |
| **Smart Defaults** | Pre-remplir les formulaires avec les choix les plus probables | Nouveau deck (dernier format utilise), Game setup (derniere config) |
| **Progressive Disclosure** | Cacher la complexite, reveler progressivement | Filtres de recherche (basique visible, avance en expansion) |
| **Inline Editing** | Editer sans changer de page | Nom de deck, quantite cartes (tap sur nombre) |
| **Gesture Shortcuts** | Double-tap, long press, pinch pour actions rapides | Double-tap carte = preview, long press = actions, pinch = zoom grille |
| **Haptic Feedback** | Retour haptique sur les actions cles | Ajout carte, changement vie, dice roll, scan reussi |
| **Adaptive Layout** | Layout qui s'adapte a la taille d'ecran (tablette = 2 colonnes) | Recherche cartes, detail deck |

### 7.3 Refonte de Pages Existantes

#### Life Counter - Ameliorations UX

1. **Compteurs secondaires visibles** : Poison, Energy, Experience, Commander Tax toujours accessibles (pas caches dans un menu)
2. **Themes de couleur par joueur** : Chaque joueur choisit sa couleur et un symbole de guilde/clan
3. **Mode paysage optimise** : Layout special pour les tablettes et le mode paysage
4. **Raccourci relance** : Bouton "Nouvelle partie, memes joueurs" en 1 tap
5. **Gestures** : Swipe up = +1, swipe down = -1, double tap = reset

#### Scanner - Ameliorations UX

1. **Mode continu** : Pas besoin de valider chaque carte, scan en continu avec confirmation audio
2. **Overlay d'informations** : Prix et rarete affiches directement sur l'overlay camera
3. **File d'attente** : Les cartes scannees s'empilent dans une file visible en bas
4. **Undo rapide** : Dernier scan annulable par swipe

#### Recherche - Ameliorations UX

1. **Recherche vocale** : "Cherche Rhystic Study" par commande vocale
2. **Historique recherches** : Acces rapide aux dernieres recherches
3. **Recherche par photo** : Pointer la camera sur une carte pour lancer la recherche
4. **Suggestions auto** : Autocomplete intelligent base sur la popularite

#### Decks - Ameliorations UX

1. **Vue "Board"** : Visualisation du deck comme s'il etait etale sur une table (grid draggable)
2. **Comparaison de decks** : Side-by-side de 2 decks avec diff
3. **Version history** : Historique des modifications du deck (git-like)
4. **Partage par QR code** : Generer un QR code pour partager un deck

---

## Phase 6 : Metriques Produit

### North Star Metric

- **Metrique :** Nombre de sessions actives par semaine par utilisateur
- **Pourquoi :** Correle directement avec la valeur percue (un joueur qui revient utilise l'app pendant ses parties, pour gerer sa collection, pour construire des decks). C'est le meilleur proxy de la "valeur delivree".

### Funnel Metrics

| Etape | Metrique | Cible | Outil de mesure |
|-------|----------|-------|-----------------|
| **Acquisition** | Telechargements/mois | 1 000/mois (annee 1) | Firebase Analytics + Store Analytics |
| **Activation** | Completion onboarding + 1ere action | 70% des installs | Firebase Analytics (events custom) |
| **Engagement** | Sessions/semaine, cartes scannees, parties jouees | 3+ sessions/sem | Firebase Analytics |
| **Retention** | Retention J1/J7/J30 | 60% / 30% / 15% | Cohort analysis Firebase |
| **Revenue** | MRR (si premium) / ARPU | 0 (gratuit) puis 500EUR/mois | In-app purchases tracking |
| **Referral** | Partages de decks, invitations | 1 partage/user/mois | Events de partage |

### Health Metrics (Guardrails)

| Metrique | Cible | Alerte si |
|----------|-------|-----------|
| Crash rate | < 1% | > 2% |
| App start time | < 2s | > 4s |
| Taille APK | < 50MB | > 80MB |
| Recherche locale (Isolate) | < 500ms | > 2s |
| Scan OCR | < 3s | > 8s |
| Note Store | > 4.2/5 | < 3.8/5 |
| Consommation batterie | Raisonnable | Plaintes users |

### Metriques par Feature

| Feature | Metrique primaire | Metrique secondaire |
|---------|------------------|---------------------|
| Life Counter | Parties completees/semaine | Duree moyenne partie |
| Scanner | Cartes scannees/session | Taux de reconnaissance |
| Decks | Decks crees, cartes ajoutees | Temps de construction |
| Collection | Cartes en collection | % sets completes |
| Oracle IA | Questions posees/semaine | Taux satisfaction reponse |
| Wishlists | Cartes en wishlist | Taux conversion wishlist->collection |

---

## Phase 7 : Plan d'Experimentation

### Hypotheses a Valider

| # | Hypothese | Experience | Metrique | Seuil de succes | Duree |
|---|-----------|------------|----------|-----------------|-------|
| 1 | "Les users veulent les prix dans l'app" | Feature flag : afficher/cacher prix sur page detail carte | Tap rate sur prix, temps passe page detail | +20% temps sur page detail | 2 sprints |
| 2 | "Un onboarding augmente la retention" | A/B : avec/sans onboarding pour nouveaux users | Retention J7 | +15% retention J7 | 4 semaines |
| 3 | "Le dashboard home augmente l'engagement" | A/B : home = dashboard vs home = life counter (actuel) | Sessions/semaine, features decouvertes | +10% features utilisees | 3 semaines |
| 4 | "Les compteurs poison/energy sont attendus" | Fake door : bouton "Compteurs avances" dans life counter, mesurer les taps | Tap rate sur le bouton | > 15% des users cliquent | 1 semaine |
| 5 | "Le playtest mode augmente l'usage decks" | Lancer MVP playtest (main de depart + mulligan) | % users deck qui utilisent playtest | > 20% des deckbuilders l'essaient | 3 semaines |
| 6 | "L'Oracle IA pour les decks est utile" | Ajouter bouton "Demander a l'Oracle" sur page deck | Utilisation Oracle depuis deck vs Oracle global | +30% questions Oracle | 2 semaines |
| 7 | "Les animations ameliorent la satisfaction" | A/B : life counter avec/sans animations (pulse, shake) | Session duration, note qualitative (survey) | +10% session time | 3 semaines |

### Structure d'Experience Type

**Hypothese 1 - Prix Integres**
1. **Hypothese :** Si on affiche les prix des cartes (Scryfall), alors les utilisateurs passeront plus de temps sur les pages detail et scanneront plus de cartes, parce que connaitre la valeur est une motivation primaire des collectionneurs.
2. **Test design :** Feature flag via Firebase Remote Config. 50% des users voient les prix, 50% non.
3. **Sample size :** Minimum 200 users par groupe (significativite 95%, puissance 80%).
4. **Decision framework :**
   - **Ship** si +20% temps page detail ET +10% scans/session
   - **Iterate** si +10-20% temps mais pas d'impact sur scans
   - **Kill** si < +10% sur les deux metriques

---

## Synthese & Recommandations

### Top 5 Actions Immediates (Sprint 14)

1. **Integrer les prix Scryfall** sur la page detail carte et dans la collection - c'est le gap #1 vs tous les concurrents
2. **Ajouter compteurs Poison/Energy/Monarch** au life counter - quick win a fort impact, 1 sprint max
3. **Creer un onboarding** 3 ecrans - critique pour la retention des nouveaux utilisateurs
4. **Ajouter un Dashboard Home** - orienter les utilisateurs et montrer la valeur de l'app des le lancement
5. **Implementer les animations de base** du life counter (pulse de vie, shake de degats) - differenciation UX immediate

### Avantage Strategique : L'Oracle IA

L'Oracle IA est l'atout majeur de Magic Companion. Aucun concurrent n'a d'IA integree. La strategie devrait etre de **deployer l'IA partout** :
- Dans les decks (suggestions, diagnostic)
- Dans le scanner (identification + info contextuelle)
- Dans le life counter (judge rapide)
- Dans la collection (conseils trade/vente)
- Sur le dashboard (carte du jour, fun facts)

C'est l'Oracle IA qui transforme Magic Companion d'un "un de plus" en **l'app MTG la plus intelligente du marche**.

### Positionnement Recommande

> **Magic Companion : L'app MTG tout-en-un avec un Oracle IA integre.**
> Gerez vos parties, vos decks et votre collection avec l'aide d'une intelligence artificielle qui connait Magic mieux que personne.

---

*Document genere par Vivi - Product Manager & UX Strategist*
*Derniere mise a jour : 8 mars 2026*

---

## Sources

- [Moxfield - MTG Deck Builder](https://moxfield.com/)
- [Moxfield: The Ultimate Magic: The Gathering Deck-Building Tool](https://wizzydigitalorgg.com/moxfield/)
- [MTG Deck Builder - Archidekt](https://archidekt.com/)
- [How To Use Archidekt - EDHREC](https://edhrec.com/guides/how-to-use-archidekt-the-mtg-deckbuilding-site)
- [ManaBox MTG - Google Play](https://play.google.com/store/apps/details?id=skilldevs.com.manabox&hl=en_US)
- [ManaBox - Getting Started](https://manabox.app/guides/scanner/getting-started/)
- [MTG Scanner - Delver Lens](https://www.delverlab.com/)
- [MTG Card Scanner Delver Lens - Google Play](https://play.google.com/store/apps/details?id=delverlab.delverlens&hl=en_US)
- [TopDecked MTG - App Store](https://apps.apple.com/us/app/topdecked-mtg/id1173388234)
- [TopDeck.gg - Magic Tournaments & Events](https://topdeck.gg/magic-the-gathering)
- [TCGplayer App - App Store](https://apps.apple.com/us/app/tcgplayer/id1247645833)
- [TCGplayer Mobile App Update](https://seller.tcgplayer.com/blog/tcgplayer-mobile-app-update)
- [MTGGoldfish](https://www.mtggoldfish.com/)
- [Dragon Shield - Digital Card Manager](https://www.dragonshield.com/en-us/card-manager)
- [Dragon Shield - New Features](https://about.dragonshield.com/gaming-inspiration/new-features-now-available-on-card-manager/)
- [MTG Companion App - Wizards of the Coast](https://magic.wizards.com/en/products/companion-app)
- [The MTG Companion app is getting major changes in 2026 - Wargamer](https://www.wargamer.com/magic-the-gathering/companion-app-update)
- [8 Great Apps For MTG Players - Inked Gaming](https://www.inkedgaming.com/blogs/news/8-great-apps-for-mtg-players)
- [Top 11 Life Counter Apps for Magic - Draftsim](https://draftsim.com/best-mtg-life-counter-app/)
- [11 Best MTG Collection Tracker Apps - Draftsim](https://draftsim.com/mtg-collection-tracker/)
- [Hasbro Investor Relations - Magic: The Gathering](https://investor.hasbro.com/magic-gathering)
- [Magic Industry Statistics: Market Data Report 2026](https://gitnux.org/magic-industry-statistics/)
- [KrakenTheMeta: AI MTG Deck Builder](https://krakenthemeta.com/)
- [Flutter Animations & Micro-Interactions Guide](https://medium.com/@flutter-app/animations-micro-interactions-in-flutter-make-your-ui-delightful-592fb9da6e11)
- [Top Flutter UI/UX Trends](https://arccusinc.com/blog/top-flutter-ui-ux-trends-redefining-mobile-experiences/)
