# Recommandations UX/Product - Animations, Features & Micro-interactions
### Par Vivi - Product Manager & UX Strategist
### Date : 8 mars 2026

> **Contexte** : Ce document complete l'AUDIT_VIVI.md et le COMPETITIVE_AUDIT_YAMATO.md avec des recommandations concretes et actionnables sur les animations, nouvelles features et micro-interactions a implementer dans Magic Companion.

---

## Table des matieres

1. [Synthese des Priorites](#1-synthese-des-priorites)
2. [Animations "Waouh"](#2-animations-waouh)
3. [Nouvelles Features Innovantes](#3-nouvelles-features-innovantes)
4. [Micro-interactions UX](#4-micro-interactions-ux)
5. [Matrice de Prioritisation RICE](#5-matrice-de-prioritisation-rice)
6. [Roadmap d'Implementation](#6-roadmap-dimplementation)
7. [Specifications Techniques](#7-specifications-techniques)
8. [Metriques de Succes](#8-metriques-de-succes)

---

## 1. Synthese des Priorites

### Etat actuel des animations (deja implementees)

| Element | Status | Fichier |
|---------|--------|---------|
| Life counter : pulse de vie | FAIT | `player_zone.dart` (AnimationController _pulseController) |
| Life counter : shake de degats | FAIT | `player_zone.dart` (AnimationController _shakeController) |
| Life counter : glow aura par couleur | FAIT | `player_zone.dart` (AnimationController _glowController) |
| Haptic feedback (vie +/-) | FAIT | `player_zone.dart` (HapticFeedback.lightImpact/mediumImpact) |
| Scanner : animation de scan | FAIT | `scanner_page.dart` (AnimationController _scanAnimationController) |
| Dice roll animation | FAIT | `dice_roll_dialog.dart` (AnimationController) |
| Onboarding dots animees | FAIT | `onboarding_page.dart` (AnimatedContainer) |
| Loader custom (Skyrim style) | FAIT | `skyrim_sneak_loader.dart` |

### Ce qui manque (par impact)

| Priorite | Categorie | Nb items | Effort total estime |
|----------|-----------|----------|---------------------|
| Quick Win (1-3 jours) | Animations + micro-interactions | 12 | ~15 jours-dev |
| Medium (1-2 semaines) | Animations + features | 10 | ~40 jours-dev |
| Long term (1+ mois) | Features innovantes | 8 | ~80 jours-dev |

---

## 2. Animations "Waouh"

### 2.1 Card Flip 3D (reveler cartes scannees et double-face)

**Priorite : Quick Win** | **Effort : 2 jours** | **Impact UX : Eleve**

**Description :** Quand une carte est detectee par le scanner, elle apparait retournee (dos MTG) puis se retourne en 3D pour reveler la face. Aussi utilise pour les cartes double-face (tap pour retourner).

**Implementation Flutter :**
```
Widget: AnimatedSwitcher custom
Transform: Matrix4.rotationY(angle)
Duration: 600ms
Curve: Curves.easeInOutBack
Trigger: carte detectee par OCR / tap sur carte DFC
```

**Wireframe comportement :**
```
[Dos carte MTG]  -->  rotation Y 0->pi  -->  [Face carte]
     (0ms)              (0-600ms)              (600ms)
                   A mi-rotation (300ms):
                   switch du child widget
```

**Fichiers concernes :** `scanner_page.dart`, `card_detail_page.dart`, `scryfall_image.dart`

**Pourquoi c'est prioritaire :** Chaque scan est un "moment de revelation". L'animation amplifie la dopamine de decouvrir une carte. Les concurrents (ManaBox, Delver Lens) n'ont pas cet effet -- differenciation immediate.

---

### 2.2 Particle Effects (confetti / sparkles sur milestones)

**Priorite : Quick Win** | **Effort : 1 jour** | **Impact UX : Moyen**

**Description :** Explosion de confetti quand l'utilisateur atteint un milestone de collection (set complete a 25%, 50%, 75%, 100%) ou debloque un badge.

**Implementation Flutter :**
```
Package: confetti (pub.dev) -- leger, ~50KB
Trigger: pourcentage de completion franchit un seuil
Duree: 2 secondes
Couleurs: couleurs de mana MTG (blanc, bleu, noir, rouge, vert)
```

**Fichiers concernes :** `set_detail_page.dart`, `collection_badge.dart`, `set_detail_stats_header.dart`

**Seuils de declenchement :**
| Seuil | Effet | Intensite |
|-------|-------|-----------|
| 25% set | Sparkles subtils | Basse (5 particules) |
| 50% set | Confetti moyen | Moyenne (20 particules) |
| 75% set | Confetti genereux | Haute (50 particules) |
| 100% set | Explosion + banner "SET COMPLETE!" | Maximum (100 particules + overlay) |
| Badge debloque | Shine + bounce + mini confetti | Moyenne |

---

### 2.3 Parallax Scrolling dans les listes de cartes

**Priorite : Medium** | **Effort : 3 jours** | **Impact UX : Moyen**

**Description :** Dans la vue grille des cartes (recherche, collection, deck detail), l'artwork des cartes a un leger mouvement de parallaxe au scroll, donnant un effet de profondeur.

**Implementation Flutter :**
```
Widget: NotificationListener<ScrollNotification>
Calcul: offset = scrollPosition * parallaxFactor (0.1-0.3)
Application: Transform.translate(offset: Offset(0, offset))
ClipRect: pour eviter que l'image deborde du conteneur
```

**Fichiers concernes :** `card_search_page.dart`, `set_detail_page.dart`, `deck_detail_page.dart`

**Attention performance :** Limiter a la vue grille (pas la vue liste). Utiliser `RepaintBoundary` autour de chaque carte pour eviter les repaints en cascade. Tester sur device bas de gamme (cible: 60fps maintenu).

---

### 2.4 Transition Hero entre liste et detail carte

**Priorite : Quick Win** | **Effort : 1.5 jours** | **Impact UX : Eleve**

**Description :** Quand l'utilisateur tape sur une carte dans une liste/grille, l'image de la carte "vole" vers la page detail avec une animation fluide (shared element transition).

**Implementation Flutter :**
```
Widget: Hero(tag: 'card-${card.id}')
Enfant liste: ScryfallImage (miniature)
Enfant detail: ScryfallImage (pleine taille)
flightShuttleBuilder: custom pour gerer le borderRadius transition
Duration: 300ms (via pageTransitionsTheme)
```

**Fichiers concernes :**
- `card_search_page.dart` (source grille/liste)
- `set_detail_page.dart` (source collection)
- `card_detail_page.dart` (destination)
- `scryfall_image.dart` (wrapper du Hero)
- Routes go_router : utiliser `CustomTransitionPage`

**Pourquoi c'est prioritaire :** C'est LE pattern mobile le plus attendu pour les apps de contenu visuel. L'absence de Hero transition donne une impression de "V1" a l'app. Toutes les apps concurrentes bien notees (ManaBox 4.3/5) l'implementent.

---

### 2.5 Shimmer / Skeleton Loading

**Priorite : Quick Win** | **Effort : 2 jours** | **Impact UX : Eleve**

**Description :** Remplacer tous les CircularProgressIndicator et loaders generiques par des squelettes animes qui refletent la forme du contenu a venir.

**Templates de squelettes necessaires :**
| Ecran | Squelette |
|-------|-----------|
| Recherche cartes (grille) | Grille de rectangles 2.5:3.5 ratio avec shimmer |
| Detail carte | Image placeholder + lignes de texte shimmer |
| Liste de sets | Lignes avec icone cercle + 2 lignes texte |
| Deck detail | Tabs + liste de cartes skeleton |
| Oracle IA reponse | Bulles de chat avec lignes pulsantes |

**Implementation Flutter :**
```
Option A: Package `skeletonizer` (wrap le widget reel, genere le skeleton auto)
Option B: Package `shimmer` + widgets placeholder custom
Recommandation: Option A pour la vitesse, Option B pour le controle
```

**Fichiers concernes :** Tous les ecrans avec chargement async -- priorite aux plus visites : `card_search_page.dart`, `card_detail_page.dart`, `set_detail_page.dart`, `deck_detail_page.dart`

---

### 2.6 Animations de Deck Building (drag & drop fluide)

**Priorite : Medium** | **Effort : 5 jours** | **Impact UX : Eleve**

**Description :** Suite d'animations pour rendre le deckbuilding plus tactile et satisfaisant.

**Sous-animations :**

| Animation | Description | Implementation |
|-----------|-------------|----------------|
| **Card pickup** | Quand on commence un drag, la carte s'eleve (ombre + scale 1.05) | `LongPressDraggable` avec `feedback` custom + elevation |
| **Snap to zone** | Quand on drop une carte, elle "snape" a sa position avec un bounce | `AnimatedPositioned` + `Curves.elasticOut` |
| **Card count pulse** | Le compteur de cartes bounce quand il change | `AnimatedScale` avec `Curves.elasticOut`, duration 400ms |
| **Category collapse** | Les categories (creatures, instants...) se replient avec animation | `AnimatedCrossFade` ou `AnimatedSize` |
| **Reorder slide** | Les cartes autour glissent pour faire de la place au drag | `ReorderableListView.builder` avec `proxyDecorator` custom |

**Fichiers concernes :** `deck_detail_page.dart`, `card_search_page.dart` (ajout depuis recherche)

---

### 2.7 Life Counter : renforcer les animations existantes

**Priorite : Quick Win** | **Effort : 1 jour** | **Impact UX : Moyen**

**Etat actuel :** Le life counter a deja pulse, shake et glow. Voici les ajouts recommandes.

| Animation | Description | Effort |
|-----------|-------------|--------|
| **Elimination explosion** | A 0 PV, particules rouges + zone qui se grise | 0.5 jour |
| **Victory crown** | Le dernier joueur en vie recoit une couronne animee | 0.5 jour |
| **Commander damage threshold** | A 15+ commander damage, la barre pulse en rouge danger | Deja dans glow, ajuster seuil |
| **Compteur anime** | Le chiffre de vie ne change pas brutalement, il "roule" (CountUp style) | `TweenAnimationBuilder<int>` |

**Fichiers concernes :** `player_zone.dart`, `life_counter_page.dart`

---

### 2.8 Pull-to-Refresh custom theme MTG

**Priorite : Medium** | **Effort : 2 jours** | **Impact UX : Moyen**

**Description :** Remplacer le RefreshIndicator standard par un custom avec symboles de mana qui tournent/tombent.

**Implementation :**
```
Widget: CustomScrollView + custom RefreshIndicator
Animation: 5 symboles de mana (WUBRG) qui tournent en cercle
Etat idle: symboles caches
Etat pull: symboles apparaissent progressivement
Etat refresh: symboles tournent en boucle
Etat complete: symboles explosent vers l'exterieur et disparaissent
Assets: SVG des 5 symboles mana (deja utilises dans l'app via flutter_svg)
```

**Fichiers concernes :** `card_search_page.dart`, `collection_page.dart`, `deck_list_page.dart`

---

### 2.9 Onboarding avec animations Lottie

**Priorite : Quick Win** | **Effort : 2 jours** | **Impact UX : Eleve**

**Etat actuel :** `onboarding_page.dart` existe avec AnimatedContainer pour les dots. Manque des animations riches sur les ecrans.

**Proposition :**
| Ecran | Animation Lottie | Message |
|-------|-----------------|---------|
| 1 - Scanner | Carte qui se materialise (scan effect) | "Scannez vos cartes en un instant" |
| 2 - Collection | Etagere de cartes qui se remplit | "Gerez votre collection" |
| 3 - Decks | Cartes qui s'assemblent en eventail | "Construisez des decks puissants" |
| 4 - Oracle | Bulle de chat avec etoiles | "Posez vos questions a l'Oracle IA" |

**Implementation :**
```
Package: lottie (pub.dev)
Fichiers: assets/lottie/onboarding_scan.json, etc.
Source animations: LottieFiles.com (gratuit) ou custom
Alternative budget: AnimatedBuilder custom avec Transform + Opacity
Taille estimee: ~50-100KB par animation JSON
```

**Fichiers concernes :** `onboarding_page.dart`
**Ajout pubspec.yaml :** `lottie: ^3.x.x`

---

### 2.10 Card Reveal Animation (Pack Opening Simulator)

**Priorite : Medium** | **Effort : 5 jours** | **Impact UX : Eleve (gamification)**

**Description :** Simuler l'ouverture d'un booster pack avec des animations de revelation de cartes. Feature standalone + reutilisable pour le scan batch.

**Sequence d'animation :**
```
[Booster pack ferme]
        |
   (tap pour ouvrir)
        |
[Pack qui se dechire] -- CustomPainter avec clip path anime
        |
[Cartes empilees face cachee]
        |
   (swipe/tap par carte)
        |
[Card flip 3D] --> [Reveal] --> glow selon rarete
        |                           |
   (si Mythic Rare)          (si Common)
        |                           |
[Confetti explosion]          [Subtle shine]
[Screen shake leger]
        |
[Recap: toutes les cartes revelees en grille]
[Valeur totale du pack]
[Bouton: Ajouter a la collection]
```

**Fichiers a creer :** `lib/pages/tools/pack_opening_page.dart`, `lib/widgets/cards/card_reveal_widget.dart`

---

## 3. Nouvelles Features Innovantes

### 3.1 Pack Opening Simulator (Gamification)

**Priorite : Medium** | **Effort : 8 jours** | **Impact : Eleve**

**Description :** Simuler l'ouverture de boosters avec les vraies probabilites de rarete par set. Combine gamification + utilite (estimer la valeur esperee d'un booster).

**Fonctionnalites :**
- Selection du set (liste des sets depuis Scryfall)
- Choix du type de booster (Play, Draft, Set, Collector)
- Simulation avec probabilites reelles de rarete
- Animation card reveal (cf. 2.10)
- Recap avec valeur totale estimee
- Option "Ajouter les cartes a ma collection" (pour ceux qui ouvrent un vrai booster en parallele)
- Historique des ouvertures simulees
- Stats : meilleure carte ouverte, valeur cumulee

**Probabilites types (Draft Booster) :**
| Slot | Rarete | Probabilite |
|------|--------|-------------|
| 1-10 | Common | 100% |
| 11-13 | Uncommon | 100% |
| 14 | Rare | 87.5% |
| 14 | Mythic | 12.5% |
| 15 | Land / Token | 100% |

**Personas cibles :** Thomas (fun entre deux parties), Sophie (evaluer si un booster vaut le coup), Julie (decouvrir les cartes d'un set)

---

### 3.2 Trade Binder (partage collection pour echanges)

**Priorite : Long term** | **Effort : 15 jours** | **Impact : Eleve**

**Description :** Mode "classeur de trade" -- l'utilisateur marque les cartes a echanger, genere un lien/QR code partageable. Le partenaire de trade ouvre le lien et voit les cartes disponibles.

**Fonctionnalites :**
- Tag "For Trade" sur n'importe quelle carte de la collection
- Vue "Trade Binder" : grille paginee 3x3 (type classeur physique)
- Partage par lien web ou QR code
- Vue partagee en lecture seule (web responsive ou deep link)
- Comparaison de valeur (mes trades vs ses trades)
- Integration wishlist : highlight des cartes que le partenaire a dans sa wishlist

**Prerequis :** Prix cartes integres (feature #1 de l'AUDIT_VIVI)

**Wireframe :**
```
┌─────────────────────────────────────────┐
│ [<] Mon Trade Binder       [Partager]   │
├─────────────────────────────────────────┤
│                                         │
│  Page 1/12        [Tri: Valeur v]       │
│                                         │
│  ┌───────┐  ┌───────┐  ┌───────┐       │
│  │ Carte │  │ Carte │  │ Carte │       │
│  │ 45EUR │  │ 32EUR │  │ 28EUR │       │
│  └───────┘  └───────┘  └───────┘       │
│  ┌───────┐  ┌───────┐  ┌───────┐       │
│  │ Carte │  │ Carte │  │ Carte │       │
│  │ 15EUR │  │ 12EUR │  │  8EUR │       │
│  └───────┘  └───────┘  └───────┘       │
│  ┌───────┐  ┌───────┐  ┌───────┐       │
│  │ Carte │  │ Carte │  │ vide  │       │
│  │  5EUR │  │  3EUR │  │ [+]   │       │
│  └───────┘  └───────┘  └───────┘       │
│                                         │
│  [< Page]  ● ○ ○ ○ ○  [Page >]         │
│                                         │
│  Total: 148 EUR  (8 cartes)             │
└─────────────────────────────────────────┘
```

---

### 3.3 Wishlist avec alertes de prix

**Priorite : Quick Win (base) / Medium (alertes)** | **Effort : 3 + 5 jours** | **Impact : Eleve**

**Etat actuel :** Les wishlists existent (`wishlist_service.dart`, `wishlist_detail_page.dart`). Manque : affichage des prix et systeme d'alertes.

**Phase 1 (Quick Win - 3 jours) :**
- Afficher le prix actuel de chaque carte dans la wishlist
- Total de la wishlist
- Tri par prix croissant/decroissant
- Indicateur visuel si le prix a baisse depuis l'ajout

**Phase 2 (Medium - 5 jours) :**
- Definir un prix cible par carte ("M'alerter si < 30EUR")
- Verification periodique en background (WorkManager / background_fetch)
- Notification push quand le seuil est atteint
- Historique de prix dans la fiche wishlist

**Fichiers concernes :** `wishlist_detail_page.dart`, `wishlist_service.dart`, `wishlist_model.dart`, `wishlist_provider.dart`

---

### 3.4 Historique de prix avec graphiques interactifs

**Priorite : Medium** | **Effort : 5 jours** | **Impact : Moyen-Eleve**

**Description :** Graphique d'evolution du prix d'une carte sur 30j/90j/1an avec interactions tactiles.

**Implementation :**
```
Package: fl_chart (deja dans pubspec.yaml)
Source: Scryfall bulk data (prix quotidiens) ou API TCGPlayer/CardMarket
Widget: LineChart avec touchCallback pour afficher le prix au point touche
Periodes: 7j, 30j, 90j, 1an, All time
```

**Wireframe dans card_detail_page :**
```
┌─────────────────────────────────────────┐
│  Prix Cardmarket: 32.50 EUR             │
│  TCGPlayer: $34.99                      │
│                                         │
│  [7j] [30j] [90j] [1an]                │
│  ┌─────────────────────────────────┐    │
│  │        ╱‾‾╲                     │    │
│  │   ╱‾‾‾╱    ╲    ╱╲             │    │
│  │  ╱              ╱  ╲╱╲  ╱╲    │    │
│  │ ╱                        ╲╱    │    │
│  │ 28 EUR ──────────── 34 EUR     │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Min: 28.00  |  Max: 38.50  |  Moy: 33 │
└─────────────────────────────────────────┘
```

**Fichiers concernes :** `card_detail_page.dart` (nouveau widget), `scryfall_api.dart` (endpoint prix)

**Attention :** Scryfall ne fournit PAS d'historique de prix. Options :
1. Stocker les prix localement a chaque consultation (historique personnel)
2. Integrer une API tierce (MTGGoldfish, TCGPlayer)
3. Scrapper les prix (non recommande)
Recommandation : Option 1 en MVP (stocker dans drift), option 2 en V2.

---

### 3.5 Mode sombre automatique

**Priorite : Quick Win** | **Effort : 1.5 jours** | **Impact : Moyen**

**Etat actuel :** L'app semble utiliser un theme sombre par defaut (splash #1A1A1A). Manque : switch auto selon les preferences systeme + option manuelle.

**Implementation :**
```
MaterialApp(
  themeMode: userPreference ?? ThemeMode.system,
  theme: lightTheme,
  darkTheme: darkTheme,
)

Stockage preference: SharedPreferences (deja utilise)
Options: Systeme (auto) | Clair | Sombre | OLED Noir (#000000)
```

**Mode OLED recommande :** Background pur noir (#000000) -- economie batterie sur ecrans AMOLED, majorite des smartphones modernes.

**Fichiers concernes :** `main.dart`, `settings_page.dart`, creer `lib/theme/app_theme.dart`

---

### 3.6 Widget home screen

**Priorite : Medium** | **Effort : 5 jours** | **Impact : Moyen**

**Description :** Widgets pour l'ecran d'accueil du telephone.

**Widgets proposes :**
| Widget | Taille | Contenu |
|--------|--------|---------|
| **Valeur Collection** | Small (2x1) | Valeur totale + variation 24h |
| **Prochaine Partie** | Medium (2x2) | Date/heure, lieu, joueurs |
| **Carte du Jour** | Medium (2x2) | Artwork aleatoire de la collection |
| **Quick Actions** | Small (2x1) | Boutons Scanner, Life Counter, Oracle |

**Implementation Flutter :**
```
Package: home_widget (pub.dev) -- Android + iOS
Mise a jour: toutes les 6h en background
Interaction: tap ouvre l'app sur la page concernee
```

---

### 3.7 Integration calendrier evenements MTG locaux

**Priorite : Long term** | **Effort : 10 jours** | **Impact : Moyen**

**Description :** Voir les evenements MTG proches (FNM, pre-release, tournois) integres dans l'app.

**Sources de donnees :**
- Wizards Event Locator API (si disponible)
- Scraping Companion (companion.wizards.com)
- Donnees communautaires (manual input par l'utilisateur + partage)

**Fonctionnalites :**
- Liste d'evenements par proximite geographique
- Filtre par format (Commander, Modern, Draft, etc.)
- Ajout au calendrier natif du telephone
- Rappel notification avant l'evenement
- Integration avec le life counter (lancer une partie depuis l'evenement)

**Complexite :** Elevee -- necessite geolocalisation, source de donnees fiable, gestion des fuseaux horaires. A lancer uniquement si une API evenements fiable est identifiee.

---

### 3.8 Mode hors-ligne complet avec sync

**Priorite : Quick Win (amelioration)** | **Effort : 3 jours** | **Impact : Eleve**

**Etat actuel :** DB locale de ~27 000 cartes via Isolate, Google Drive backup. Manque : indicateur de statut, sync intelligente, queue d'actions offline.

**Ameliorations :**
| Amelioration | Description | Effort |
|-------------|-------------|--------|
| **Indicateur online/offline** | Badge dans l'AppBar quand hors-ligne | 0.5 jour |
| **Queue d'actions** | Les modifications offline sont mises en queue et sync au retour | 1.5 jours |
| **Cache images agressif** | Pre-charger les images des cartes en collection/deck (pas juste les cherchees) | 0.5 jour |
| **Sync delta** | Ne sync que les changements, pas tout le backup | 0.5 jour |

**Package existant utile :** `connectivity_plus` (deja dans pubspec.yaml)

---

### 3.9 Statistiques avancees de deck

**Priorite : Quick Win (mana curve animee) / Medium (probabilites)** | **Effort : 2 + 5 jours** | **Impact : Eleve**

**Etat actuel :** Mana curve basique via fl_chart, power level, synergies, combos.

**Phase 1 - Mana Curve Animee (Quick Win - 2 jours) :**
- Barres de la courbe de mana qui montent une par une (staggered animation)
- Couleurs par type de carte (creature, instant, sorcery, etc.)
- Animation au switch d'onglet
- `fl_chart` supporte deja `animationDuration` et `swapAnimationCurve`

**Phase 2 - Probabilites de Draw (Medium - 5 jours) :**
| Stat | Description |
|------|-------------|
| **Opening hand simulator** | Probabilite d'avoir X terres / Y cartes specifiques en main de depart |
| **Curve out probability** | Chance de jouer une carte chaque tour 1-5 |
| **Mana color probability** | Chance d'avoir la bonne couleur de mana au bon tour |
| **Draw probability by turn** | Probabilite de piocher une carte specifique avant le tour N |

**Wireframe onglet Stats ameliore :**
```
┌─────────────────────────────────────────┐
│ [Courbe] [Draw %] [Couleurs] [Types]    │
├─────────────────────────────────────────┤
│                                         │
│  Courbe de Mana (anime)                 │
│  ┌──┐                                   │
│  │14│ ┌──┐                              │
│  │  │ │10│ ┌──┐                         │
│  │  │ │  │ │ 8│ ┌──┐                    │
│  │  │ │  │ │  │ │ 5│ ┌──┐ ┌──┐         │
│  │  │ │  │ │  │ │  │ │ 3│ │ 1│         │
│  └──┘ └──┘ └──┘ └──┘ └──┘ └──┘         │
│   1    2    3    4    5    6+   CMC      │
│                                         │
│  Distribution des Types    ┌──────────┐ │
│  Creatures    ████████░░  │ 28 (47%) │ │
│  Instants     ████░░░░░░  │ 12 (20%) │ │
│  Sorceries    ███░░░░░░░  │  8 (13%) │ │
│  Enchantments ██░░░░░░░░  │  5  (8%) │ │
│  Artifacts    ██░░░░░░░░  │  4  (7%) │ │
│  Lands        ███░░░░░░░  │  3  (5%) │ │
│                                         │
│  Cout moyen: 3.2  |  Terres: 36 (60%)  │
└─────────────────────────────────────────┘
```

**Fichiers concernes :** `deck_detail_page.dart`, `hypergeometric_page.dart` (reutiliser la logique)

**Note :** Le calculateur hypergeometrique existe deja dans `hypergeometric_page.dart`. Reutiliser cette logique pour les probabilites de draw intrinseques au deck.

---

### 3.10 Social : profils joueurs, classements, partage de decks

**Priorite : Long term** | **Effort : 20+ jours** | **Impact : Eleve (retention)**

**Description :** Couche sociale pour la retention long terme. A construire incrementalement.

**Phase 1 - Partage enrichi (5 jours) :**
- Partage de deck par lien web (landing page responsive)
- QR code de deck
- Preview riche dans les messageries (Open Graph meta)

**Phase 2 - Profils publics (8 jours) :**
- Page profil avec stats (nb cartes, nb decks, parties jouees)
- Badge de collection affiches
- Decks publics listables
- Backend necessaire (Firebase Firestore)

**Phase 3 - Communaute (10+ jours) :**
- Feed d'activite (amis)
- Classement (plus grosse collection, plus de parties)
- Commentaires sur les decks publics
- Systeme d'amis / follow

**Prerequis :** Backend social (Firebase Firestore), authentification utilisateur robuste, moderation du contenu.

---

## 4. Micro-interactions UX

### 4.1 Haptic Feedback sur actions cles

**Priorite : Quick Win** | **Effort : 0.5 jour** | **Impact : Moyen**

**Etat actuel :** Haptic feedback sur le life counter uniquement. A etendre.

| Action | Type de feedback | Fichier |
|--------|-----------------|---------|
| Carte ajoutee a collection | `HapticFeedback.mediumImpact()` | `card_detail_collection_modal.dart` |
| Carte ajoutee a un deck | `HapticFeedback.lightImpact()` | `card_search_page.dart` |
| Carte ajoutee a wishlist | `HapticFeedback.lightImpact()` | `card_search_wishlist_selector.dart` |
| Scan reussi | `HapticFeedback.heavyImpact()` | `scanner_page.dart` |
| Scan echoue | `HapticFeedback.vibrate()` (pattern court) | `scanner_page.dart` |
| Dice roll | `HapticFeedback.mediumImpact()` | `dice_roll_dialog.dart` |
| Deck sauvegarde | `HapticFeedback.lightImpact()` | `deck_detail_page.dart` |
| Badge debloque | `HapticFeedback.heavyImpact()` | `collection_badge.dart` |
| Pull-to-refresh | `HapticFeedback.selectionClick()` | Global |
| Swipe action | `HapticFeedback.selectionClick()` | Global |

**Implementation :** `import 'package:flutter/services.dart';` -- deja importe dans `player_zone.dart`.

---

### 4.2 Swipe Gestures (archive, favori, suppression)

**Priorite : Quick Win** | **Effort : 2 jours** | **Impact : Eleve**

**Description :** Actions contextuelles par swipe sur les elements de liste.

| Ecran | Swipe Droite | Swipe Gauche |
|-------|-------------|-------------|
| Recherche cartes | Ajouter a collection (vert) | Ajouter a wishlist (bleu) |
| Collection cartes | Marquer "For Trade" (orange) | Retirer de collection (rouge) |
| Deck liste | Dupliquer deck (bleu) | Supprimer deck (rouge) |
| Deck cartes | +1 quantite (vert) | -1 quantite / Retirer (rouge) |
| Wishlist | Ajouter a collection "Achete!" (vert) | Retirer de wishlist (rouge) |
| Historique parties | Voir detail (bleu) | Supprimer (rouge) |

**Implementation Flutter :**
```
Widget: Dismissible (natif Flutter)
confirmDismiss: Future<bool> pour confirmation
background: Container avec icone + couleur
secondaryBackground: Container avec icone + couleur opposee
onDismissed: action
Alternatives: flutter_slidable (package) pour des actions multiples
Recommandation: flutter_slidable pour 2+ actions par direction
```

**Fichiers concernes :** Tous les ecrans de liste

---

### 4.3 Long Press Preview (Peek & Pop style)

**Priorite : Medium** | **Effort : 3 jours** | **Impact : Moyen**

**Description :** Long press sur une carte dans n'importe quelle liste = preview agrandie en overlay sans quitter le contexte.

**Implementation :**
```
Widget: GestureDetector(onLongPress) + Overlay
Animation: Scale de 0.0 a 1.0 + fade in (200ms)
Position: centree sur l'ecran, fond semi-transparent
Dismiss: relacher le doigt ou tap a cote
Contenu: Image carte agrandie + nom + prix + rarete
Actions rapides: boutons en bas du preview (Collection, Deck, Wishlist)
```

**Wireframe :**
```
┌─────────────────────────────────────────┐
│                                         │
│         ┌─────────────────┐             │
│         │                 │             │
│         │   [Image carte  │             │
│         │    agrandie]    │             │
│         │                 │             │
│         │                 │             │
│         ├─────────────────┤             │
│         │ Nom Carte       │             │
│         │ 32.50 EUR  Rare │             │
│         ├─────────────────┤             │
│         │[+Coll][+Deck][+Wish]│         │
│         └─────────────────┘             │
│                                         │
│  (fond: noir 60% opacity)              │
└─────────────────────────────────────────┘
```

---

### 4.4 Badge Notifications animes

**Priorite : Quick Win** | **Effort : 1 jour** | **Impact : Faible-Moyen**

**Description :** Badges numeriques animes sur les onglets de navigation et dans l'app.

| Badge | Emplacement | Trigger |
|-------|-------------|---------|
| Nouvelles cartes scannees | Tab "Collection" | Apres un scan, nombre de cartes ajoutees |
| Prix en baisse wishlist | Tab "Wishlist" | Quand un prix passe sous le seuil |
| Suggestions deck | Tab "Suggestions" dans deck | Nouvelles suggestions EDHRec |
| Parties non sauvegardees | Tab "Historique" | Partie terminee non enregistree |

**Animation :** Le badge apparait avec un bounce (`Curves.elasticOut`) et pulse doucement tant qu'il n'est pas vu.

**Implementation :**
```
Widget: Badge (natif Flutter 3.x) avec AnimatedScale
ou: Stack + Positioned + AnimatedContainer
Etat: Riverpod provider pour le compteur de chaque badge
```

---

### 4.5 Transitions de page fluides (shared element)

**Priorite : Quick Win** | **Effort : 1.5 jours** | **Impact : Eleve**

**Description :** Remplacer les transitions de page par defaut (MaterialPageRoute slide) par des transitions personnalisees plus fluides.

**Transitions recommandees par contexte :**
| Navigation | Transition | Implementation |
|-----------|------------|----------------|
| Tab switch (bottom nav) | Fade crossfade (200ms) | `pageTransitionsTheme` dans ThemeData |
| Liste -> Detail | Fade + scale up (300ms) | `CustomTransitionPage` dans go_router |
| Modal / Bottom sheet | Slide up + fade (250ms) | Deja natif, ajuster la courbe |
| Back navigation | Fade + scale down (200ms) | `CustomTransitionPage` popTransition |
| Push lateral | Slide + fade parallax | Custom avec `SlideTransition` + `FadeTransition` |

**Implementation dans go_router :**
```dart
GoRoute(
  path: '/card/:id',
  pageBuilder: (context, state) => CustomTransitionPage(
    child: CardDetailPage(id: state.pathParameters['id']!),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  ),
),
```

**Fichiers concernes :** `cards_routes.dart`, `collections_routes.dart`, `decks_routes.dart`, `life_counter_routes.dart`, `scanner_routes.dart`

---

## 5. Matrice de Prioritisation RICE

**Reach** : % de users impactes (1-10)
**Impact** : Benefice UX percu (1-10)
**Confidence** : Certitude du resultat (0.5-1.0)
**Effort** : Jours-dev (1-30)
**Score RICE = (Reach x Impact x Confidence) / Effort**

### Animations

| # | Feature | Reach | Impact | Confidence | Effort (j) | RICE | Priorite |
|---|---------|-------|--------|------------|------------|------|----------|
| A1 | Hero transition liste->detail | 10 | 8 | 0.9 | 1.5 | **48.0** | Quick Win |
| A2 | Shimmer/skeleton loading | 10 | 7 | 0.9 | 2 | **31.5** | Quick Win |
| A3 | Card flip 3D (scan + DFC) | 7 | 8 | 0.8 | 2 | **22.4** | Quick Win |
| A4 | Transitions de page fluides | 10 | 6 | 0.9 | 1.5 | **36.0** | Quick Win |
| A5 | Particle effects (milestones) | 6 | 5 | 0.8 | 1 | **24.0** | Quick Win |
| A6 | Onboarding Lottie | 10 | 6 | 0.7 | 2 | **21.0** | Quick Win |
| A7 | Life counter renforcement | 8 | 5 | 0.9 | 1 | **36.0** | Quick Win |
| A8 | Mana curve animee | 6 | 6 | 0.9 | 2 | **16.2** | Quick Win |
| A9 | Parallax scrolling | 8 | 4 | 0.7 | 3 | **7.5** | Medium |
| A10 | Deck drag & drop fluide | 5 | 7 | 0.7 | 5 | **4.9** | Medium |
| A11 | Pull-to-refresh MTG | 8 | 3 | 0.8 | 2 | **9.6** | Medium |
| A12 | Pack opening animation | 5 | 8 | 0.7 | 5 | **5.6** | Medium |

### Features

| # | Feature | Reach | Impact | Confidence | Effort (j) | RICE | Priorite |
|---|---------|-------|--------|------------|------------|------|----------|
| F1 | Wishlist + prix | 7 | 8 | 0.9 | 3 | **16.8** | Quick Win |
| F2 | Mode sombre auto | 10 | 5 | 0.9 | 1.5 | **30.0** | Quick Win |
| F3 | Offline ameliore | 8 | 6 | 0.8 | 3 | **12.8** | Quick Win |
| F4 | Stats deck avancees (proba) | 6 | 7 | 0.8 | 5 | **6.7** | Medium |
| F5 | Pack opening simulator | 5 | 7 | 0.7 | 8 | **3.1** | Medium |
| F6 | Historique prix | 6 | 7 | 0.7 | 5 | **5.9** | Medium |
| F7 | Widget home screen | 4 | 5 | 0.6 | 5 | **2.4** | Medium |
| F8 | Wishlist alertes prix | 5 | 7 | 0.6 | 5 | **4.2** | Medium |
| F9 | Trade binder | 4 | 7 | 0.5 | 15 | **0.9** | Long term |
| F10 | Calendrier events MTG | 3 | 5 | 0.4 | 10 | **0.6** | Long term |
| F11 | Social (profils, classements) | 3 | 6 | 0.4 | 20 | **0.4** | Long term |

### Micro-interactions

| # | Feature | Reach | Impact | Confidence | Effort (j) | RICE | Priorite |
|---|---------|-------|--------|------------|------------|------|----------|
| M1 | Haptic feedback etendu | 10 | 4 | 0.9 | 0.5 | **72.0** | Quick Win |
| M2 | Swipe gestures | 8 | 7 | 0.8 | 2 | **22.4** | Quick Win |
| M3 | Transitions page fluides | 10 | 6 | 0.9 | 1.5 | **36.0** | Quick Win |
| M4 | Badge notifications animes | 6 | 4 | 0.7 | 1 | **16.8** | Quick Win |
| M5 | Long press preview | 7 | 6 | 0.7 | 3 | **9.8** | Medium |

---

## 6. Roadmap d'Implementation

### Sprint N (Quick Wins) -- ~12 jours-dev

**Objectif :** Polish UX immediat, differenciation visuelle

| Jour | Tache | RICE |
|------|-------|------|
| 1 | M1 : Haptic feedback etendu (0.5j) + A7 : Life counter renforcement (0.5j) | 72 + 36 |
| 2-3 | A1 : Hero transition liste->detail (1.5j) | 48 |
| 3-4 | A4/M3 : Transitions de page fluides (1.5j) | 36 |
| 4-5 | F2 : Mode sombre auto (1.5j) | 30 |
| 5-7 | A2 : Shimmer/skeleton loading (2j) | 31.5 |
| 7-8 | A3 : Card flip 3D (2j) | 22.4 |
| 8-9 | M2 : Swipe gestures (2j) | 22.4 |
| 9 | A5 : Particle effects milestones (1j) | 24 |
| 10 | M4 : Badge notifications animes (1j) | 16.8 |

**Criteres de succes :**
- App percue comme "moderne et polie" dans les retours qualitatifs
- +15% session duration (les animations encouragent l'exploration)
- Note store > 4.5/5

### Sprint N+1 (Medium) -- ~20 jours-dev

| Semaine | Tache | Effort |
|---------|-------|--------|
| 1 | F1 : Wishlist + affichage prix (3j) + A8 : Mana curve animee (2j) | 5j |
| 2 | F3 : Offline ameliore (3j) + A11 : Pull-to-refresh MTG (2j) | 5j |
| 3 | M5 : Long press preview (3j) + A9 : Parallax scrolling (2j) | 5j |
| 4 | A10 : Deck drag & drop (5j) | 5j |

### Sprint N+2 (Medium suite) -- ~23 jours-dev

| Semaine | Tache | Effort |
|---------|-------|--------|
| 1 | F4 : Stats deck avancees (5j) | 5j |
| 2 | F5 : Pack opening simulator (5j) + A12 : Pack opening animation | 8j |
| 3 | F6 : Historique prix (5j) | 5j |
| 4 | F7 : Widget home screen (5j) | 5j |

### Long term (trimestre suivant)

| Feature | Effort | Prerequis |
|---------|--------|-----------|
| F8 : Wishlist alertes prix | 5j | F1 (prix integres) |
| F9 : Trade binder | 15j | F1 (prix integres) |
| F10 : Calendrier events | 10j | API evenements identifiee |
| F11 : Social | 20j | Backend Firestore, moderation |
| A6 : Onboarding Lottie | 2j | Assets Lottie crees/achetes |

---

## 7. Specifications Techniques

### Packages a ajouter au pubspec.yaml

| Package | Version | Pour | Taille estimee |
|---------|---------|------|----------------|
| `confetti_widget` | ^0.4.x | Particle effects milestones | ~30KB |
| `shimmer` | ^3.0.x | Skeleton loading | ~15KB |
| `lottie` | ^3.x.x | Onboarding animations | ~50KB (+assets) |
| `flutter_slidable` | ^3.x.x | Swipe gestures | ~40KB |
| `home_widget` | ^0.6.x | Widget home screen | ~100KB |
| `sensors_plus` | ^5.x.x | Foil shimmer gyroscope (futur) | ~20KB |

**Impact sur la taille APK :** ~250KB de packages + ~200KB d'assets Lottie = ~450KB total. Acceptable (APK actuel < 50MB).

### Architecture recommandee pour les animations

```
lib/
  animations/
    card_flip_animation.dart       -- Widget reutilisable card flip 3D
    hero_card_transition.dart      -- Config Hero pour les cartes
    staggered_list_animation.dart  -- Animation d'entree staggered pour les listes
    shimmer_placeholder.dart       -- Templates de skeleton loading
    particle_celebration.dart      -- Wrapper confetti pour milestones
    page_transitions.dart          -- Definitions des transitions go_router
  widgets/
    common/
      swipeable_list_item.dart     -- Widget generique swipe actions
      peek_preview_overlay.dart    -- Long press preview overlay
      animated_badge.dart          -- Badge notification anime
```

### Performance : regles a respecter

| Regle | Detail | Mesure |
|-------|--------|--------|
| 60fps minimum | Toute animation doit maintenir 60fps sur device bas de gamme | Flutter DevTools performance overlay |
| RepaintBoundary | Wrapper chaque carte animee dans un RepaintBoundary | Audit raster cache |
| Dispose controllers | Tous les AnimationController.dispose() dans dispose() | Lint rule |
| Avoid offscreen animations | Ne pas animer les elements hors ecran (parallax) | Visibility check |
| Image cache | Les images Hero doivent etre en cache avant la transition | CachedNetworkImage (deja present) |
| Duration max | Aucune animation > 1 seconde (sauf onboarding/pack opening) | Code review |

---

## 8. Metriques de Succes

### KPIs par categorie

| Categorie | Metrique | Baseline | Cible post-implementation |
|-----------|----------|----------|--------------------------|
| **Animations** | Session duration moyenne | A mesurer | +15% |
| **Animations** | Note store | A mesurer | > 4.5/5 |
| **Animations** | Feedback qualitatif "smooth/fluide" | 0 mentions | > 30% des retours |
| **Features** | Wishlists actives (avec prix) | Existant | +50% creation wishlists |
| **Features** | Pack opening sessions/semaine | 0 | > 1 par user actif |
| **Features** | Taux utilisation mode sombre | 0% configurable | > 40% activent dark mode |
| **Micro-interactions** | Swipe actions utilisees vs tap menu | 0% swipe | > 30% des actions par swipe |
| **Micro-interactions** | Long press preview utilisations | 0 | > 5/session |
| **Global** | Retention J7 | A mesurer | +10% |
| **Global** | NPS | A mesurer | > 50 |

### A/B Tests recommandes

| Test | Variante A | Variante B | Metrique | Duree |
|------|-----------|-----------|----------|-------|
| Hero transition | Sans (actuel) | Avec Hero | Session duration, pages vues | 2 semaines |
| Swipe gestures | Desactives | Actives | Actions/session, erreurs | 3 semaines |
| Skeleton loading | Spinner classique | Shimmer skeleton | Perceived load time (survey) | 2 semaines |
| Pack opening | Non disponible | Disponible | Sessions/semaine, retention | 4 semaines |

---

## Synthese Finale

### Top 5 Quick Wins a implementer en premier (par RICE)

1. **Haptic feedback etendu** (RICE 72) -- 0.5 jour, impact immediat sur la sensation de qualite
2. **Hero transition carte** (RICE 48) -- 1.5 jours, transformation visuelle la plus visible
3. **Transitions de page fluides** (RICE 36) -- 1.5 jours, polish global de la navigation
4. **Shimmer/skeleton loading** (RICE 31.5) -- 2 jours, perception de performance
5. **Mode sombre automatique** (RICE 30) -- 1.5 jours, feature attendue par tous

### Principe directeur

> **Chaque interaction dans Magic Companion doit donner la sensation de manipuler de vraies cartes Magic.**
> Les animations ne sont pas decoratives -- elles renforcent la connexion emotionnelle entre le joueur et sa collection. Un card flip, c'est le frisson d'ouvrir un booster. Un confetti sur un set complet, c'est la fierte du collectionneur. Un haptic feedback sur chaque ajout, c'est la confirmation tactile que cette carte est desormais la sienne.

### Budget total estime

| Phase | Jours-dev | Delai reel (1 dev) |
|-------|-----------|-------------------|
| Quick Wins | ~12 jours | 2-3 semaines |
| Medium | ~43 jours | 8-10 semaines |
| Long term | ~52 jours | 10-12 semaines |
| **Total** | **~107 jours** | **~6 mois** |

---

*Document genere par Vivi - Product Manager & UX Strategist*
*Complement de l'AUDIT_VIVI.md -- Focus Animations, Features & Micro-interactions*
*Derniere mise a jour : 8 mars 2026*
