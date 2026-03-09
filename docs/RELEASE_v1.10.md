# Release Notes - Magic Companion v1.10

## Audit Produit & Strategie UX

**Date :** 8 mars 2026
**Responsable :** Vivi - Product Manager & UX Strategist
**Base :** Sprint 13 (144 fichiers Dart, ~40 154 lignes de code)

---

## Table des matieres

1. [Vue d'ensemble](#vue-densemble)
2. [Audit concurrentiel](#audit-concurrentiel)
3. [Gaps critiques identifies](#gaps-critiques-identifies)
4. [Avantage competitif unique](#avantage-competitif-unique)
5. [Roadmap priorisee (RICE)](#roadmap-priorisee-rice)
6. [Catalogue d'animations](#catalogue-danimations)
7. [Personas & Jobs-to-be-Done](#personas--jobs-to-be-done)
8. [Metriques & Experimentation](#metriques--experimentation)
9. [Prochaines etapes](#prochaines-etapes)

---

## Vue d'ensemble

La v1.10 marque un tournant strategique pour Magic Companion. Vivi a realise un audit produit exhaustif couvrant l'ensemble du marche des apps MTG (10+ concurrents analyses), l'identification de 5 gaps critiques face a la concurrence, la definition de 5 personas utilisateurs, la priorisation de 15 features par methode RICE, et la specification de 40+ animations pour transformer l'experience utilisateur.

Ce document constitue la feuille de route produit qui guidera les sprints 14 a 21+.

---

## Audit concurrentiel

### Apps analysees

Dix applications concurrentes ont ete evaluees fonctionnalite par fonctionnalite :

| Categorie | Application | Force principale |
|-----------|-------------|-----------------|
| **Mobile native** | ManaBox | Scanner artwork rapide, UX soignee |
| **Mobile native** | TopDecked | Donnees metagame, life counter avance |
| **Mobile native** | Delver Lens | Scanner de reference, export universel (12+ formats) |
| **Mobile native** | Dragon Shield | Social (amis, trade lists), multi-langues |
| **Web** | Moxfield | Collaboration temps reel, UX moderne |
| **Web** | Archidekt | Drag-and-drop visuel, integration EDHREC |
| **Web** | MTGGoldfish | Metagame analytics, historique prix |
| **Web** | Scryfall | API de reference, syntaxe de recherche avancee |
| **Marketplace** | TCGPlayer | Marketplace, scanner rapide |
| **Officielle** | App WotC | Gestion events officiels |

### Matrice de comparaison synthetique

| Fonctionnalite | Concurrents qui l'ont | Magic Companion |
|---------------|----------------------|-----------------|
| Prix cartes temps reel | ManaBox, TopDecked, Delver Lens, Dragon Shield, Scryfall, TCGPlayer | **Absent** |
| Scanner par artwork | ManaBox, Delver Lens, Dragon Shield | **OCR texte uniquement** |
| Mode playtest/goldfish | Moxfield, ManaBox | **Absent** |
| Compteurs poison/energy/monarch | TopDecked | **Absent** |
| Valeur collection temps reel | ManaBox, TopDecked, Delver Lens, Dragon Shield | **Absent** |
| Mode batch scan | ManaBox, Delver Lens, Dragon Shield | **Absent** |
| Recommandations IA | Aucun | **Oracle IA (exclusif)** |
| Glossaire bilingue FR/EN | Aucun | **Present (exclusif)** |
| Calculateur hypergeometrique | Aucun | **Present (exclusif)** |

---

## Gaps critiques identifies

Cinq manques majeurs separent Magic Companion de ses concurrents directs :

### 1. Prix de cartes en temps reel

**Impact :** Tous les concurrents serieux affichent les prix. C'est le gap #1.

- Source identifiee : API Scryfall (champs `prices.eur`, `prices.usd`)
- Affichage cible : page detail carte, liste collection, scanner overlay
- Sous-features : historique 30j/90j, alertes de prix, top movers

### 2. Scanner par artwork

**Impact :** Le scan OCR texte actuel (~5-10s/carte) est lent et peu fiable. ManaBox et Delver Lens scannent par reconnaissance d'image en < 2s.

- Technologie cible : modele ML de reconnaissance d'artwork
- Gain attendu : temps de scan divise par 3 minimum
- Effort estime : P2 (8 sprints) -- investissement lourd mais strategique

### 3. Compteurs poison / energy / monarch

**Impact :** Fonctionnalites attendues par les joueurs Commander et competitifs. TopDecked les propose deja.

- Compteur poison (0-10, elimination a 10)
- Compteur energy (Kaladesh+)
- Marqueur monarch (indicateur visuel)
- Commander tax tracker
- Effort estime : P0, 1 sprint -- quick win a fort impact

### 4. Mode playtest / goldfish

**Impact :** Tester un deck en solitaire (main de depart, mulligan, simulation de tours). Moxfield et ManaBox le proposent.

- Zones : main, champ de bataille, cimetiere, exil, bibliotheque
- Interactions : piocher, mulligan, drag-and-drop entre zones
- Stats live : mana disponible, probabilite prochaine terre
- Effort estime : P1 (5 sprints)

### 5. Valeur monetaire de la collection

**Impact :** Impossible de connaitre la valeur totale de sa collection. Tous les concurrents collection-oriented le proposent.

- Valeur totale avec evolution 30j/90j/1an
- Top cartes par valeur
- Movers quotidiens (hausses/baisses)
- Effort estime : P1 (4 sprints, depend de l'integration prix)

---

## Avantage competitif unique

### L'Oracle IA : le differenciateur #1

**Aucun concurrent** ne dispose d'un assistant IA integre capable de :

- Repondre aux questions de regles en temps reel
- Suggerer des cartes pour un deck
- Analyser des strategies
- Expliquer des mecaniques aux debutants

**Strategie recommandee : deployer l'Oracle IA dans tous les modules**

| Module | Integration IA proposee |
|--------|------------------------|
| **Decks** | Suggestions d'amelioration, diagnostic deck, budget optimizer |
| **Scanner** | Identification contextuelle, infos enrichies |
| **Life Counter** | "Rule Judge" rapide pendant une partie |
| **Collection** | Conseils trade/vente, tendances |
| **Dashboard** | Carte du jour, fun facts, quiz |
| **Recherche** | "Explain Like I'm New", "What beats this?" |

### Positionnement cible

> **Magic Companion : L'app MTG tout-en-un avec un Oracle IA integre.**
> Gerez vos parties, vos decks et votre collection avec l'aide d'une intelligence artificielle qui connait Magic mieux que personne.

---

## Roadmap priorisee (RICE)

### Methode de scoring

- **Reach** : pourcentage d'utilisateurs impactes (1-10)
- **Impact** : benefice utilisateur (1-10)
- **Confidence** : fiabilite de l'estimation (0.5-1.0)
- **Effort** : nombre de sprints (1-10)
- **Score RICE** = (Reach x Impact x Confidence) / Effort

### Top 15 features

| Priorite | Feature | RICE | Sprint cible |
|----------|---------|------|-------------|
| **P0** | Compteurs poison/energy/monarch | 50.4 | Sprint 14 |
| **P0** | Onboarding 3 ecrans | 40.0 | Sprint 14 |
| **P0** | Prix cartes integres (Scryfall) | 24.3 | Sprint 14 |
| **P0** | Dashboard Home | 24.0 | Sprint 14 |
| P1 | Historique prix 30j/90j | 12.0 | Sprint 15-16 |
| P1 | Valeur collection temps reel | 11.2 | Sprint 15-16 |
| P1 | Oracle IA - suggestions deck auto | 9.8 | Sprint 17-18 |
| P1 | Export multi-plateformes | 9.0 | Sprint 15-16 |
| P1 | Trade Helper | 7.0 | Sprint 17-18 |
| P1 | Mode playtest/goldfish | 6.7 | Sprint 17-18 |
| P1 | Mode batch scan | 6.3 | Sprint 15-16 |
| P2 | Notifications prix/spoilers | 4.8 | Sprint 19-20 |
| P2 | Amelioration scanner (artwork ML) | 4.5 | Sprint 21+ |
| P2 | Metagame data integration | 2.8 | Sprint 19-20 |
| P3 | Social features (amis, partage) | 1.8 | Sprint 19-20 |

### Plan de releases

| Release | Objectif | Critere de succes |
|---------|----------|-------------------|
| **Sprint 14** (Quick Wins) | Time-to-value < 60s, gap concurrentiel reduit | 80% completion onboarding, +30% retention J7 |
| **Sprint 15-16** (Collection+) | Meilleur tracker de collection mobile | 50% users activent collection, +20% DAU |
| **Sprint 17-18** (Deck Master) | Deckbuilding superieur a la concurrence | 30% users utilisent playtest, +15% sessions/user |
| **Sprint 19-20** (Social & Meta) | Retention long terme et viralite | NPS > 50, viral coefficient > 0.5 |
| **Sprint 21+** (Moon Shot) | Differenciation radicale (scanner ML, AR) | Scan < 2s, +40% acquisition |

---

## Catalogue d'animations

40+ micro-interactions et animations specifiees pour transformer l'experience utilisateur. Chaque animation inclut sa description fonctionnelle et son implementation Flutter recommandee.

### Life Counter (8 animations)

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Pulse de vie** | Le chiffre pulse en vert (+) ou rouge (-) a chaque changement | `AnimatedScale` + `ColorTween` |
| **Shake de degats** | La zone du joueur tremble quand la vie diminue | `Transform.translate` avec oscillation `sin()` |
| **Explosion de particules** | Particules rouges a 0 PV (elimination) | `CustomPainter` particle system ou `confetti` |
| **Dice Roll 3D** | Rotation 3D du de avant le resultat | `Matrix4.rotationX/Y` + `AnimationController` |
| **Glow Monarch** | Contour dore pulsant pour le joueur Monarch | `AnimatedContainer` + `BoxShadow` anime |
| **Poison Drip** | Goutte violette qui coule au gain de poison | `CustomPainter` avec courbe de Bezier animee |
| **Counter Tick** | Son + vibration haptique a chaque changement | `HapticFeedback.lightImpact()` |
| **Victory Crown** | Couronne animee sur le vainqueur | `SlideTransition` + `RotationTransition` |

### Scanner (5 animations)

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Scan Line** | Ligne laser qui balaye la carte pendant la detection | `AnimatedPositioned` + `LinearGradient` |
| **Card Reveal** | Materialisation de la carte detectee (fade + scale) | `AnimatedOpacity` + `AnimatedScale` |
| **Shimmer Loading** | Reflet shimmer sur le placeholder pendant la recherche | Package `shimmer` ou `ShaderMask` custom |
| **Success Checkmark** | Checkmark vert qui se dessine apres ajout | `CustomPainter` + `Path` + `PathMetric` |
| **Card Stack** | Empilement visuel des cartes en mode batch | `Stack` + `Transform.rotate` |

### Cartes (7 animations)

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Foil Shimmer** | Reflet holographique qui suit le gyroscope | `sensors_plus` + `ShaderMask` |
| **Card Flip 3D** | Retournement 3D pour cartes double-face | `Matrix4.rotationY(angle)` |
| **Parallax Scroll** | Effet de parallaxe sur l'artwork au scroll | `ScrollNotification` + `Transform.translate` |
| **Card Zoom Hero** | Transition Hero avec zoom vers la page detail | `Hero` widget + `flightShuttleBuilder` |
| **Rarity Glow** | Glow colore selon la rarete (Mythic orange, Rare or) | `BoxShadow` colore dynamique |
| **Tap to Peek** | Preview en overlay au long press | `Overlay` + `AnimatedOpacity` |
| **Swipe to Add** | Swipe droite = collection, gauche = wishlist | `Dismissible` avec background colore |

### Navigation & UI (8 animations)

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Page Transitions** | Fade + slide subtil entre les pages | `CustomTransitionPage` dans `go_router` |
| **Bottom Nav Morph** | Icone active animee avec indicateur glissant | `AnimatedContainer` + `TweenAnimationBuilder` |
| **Pull-to-Refresh Mana** | Symboles de mana qui tombent au pull-to-refresh | Custom `RefreshIndicator` + `CustomPainter` |
| **Skeleton Loading** | Squelette anime au chargement (pas de spinner) | Package `skeletonizer` |
| **Snackbar Anime** | Confirmations avec slide-in + icone animee | `ScaffoldMessenger` custom |
| **FAB Expansion** | Menu flottant avec entree staggered par option | `flutter_speed_dial` + staggered animation |
| **Theme Transition** | Transition fluide dark/light mode | `AnimatedTheme` |
| **Empty State Illustrations** | Illustrations animees sur les ecrans vides | Package `lottie` |

### Deck Builder (5 animations)

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Mana Curve Build** | Barres qui montent une par une sur l'onglet Stats | `fl_chart` + `animationDuration` staggered |
| **Card Count Badge** | Badge compteur qui bounce a l'ajout | `AnimatedScale` + `Curves.elasticOut` |
| **Drag Reorder** | Carte qui s'eleve avec ombre au drag | `ReorderableListView` + `proxyDecorator` |
| **Power Level Gauge** | Jauge arc qui se remplit | `CustomPainter` arc anime |
| **Suggestion Appear** | Suggestions EDHRec en cascade staggered | `AnimatedList` + `SlideTransition` |

### Collection (4 animations)

| Animation | Description | Implementation |
|-----------|-------------|---------------|
| **Completion Ring** | Cercle progressif pour le % de completion d'un set | `CustomPainter` arc + `Tween<double>` |
| **Badge Unlock** | Shine + bounce + confetti au deblocage | `confetti` + `AnimatedScale` + `ShaderMask` |
| **Value Counter** | Compteur de valeur avec "counting up" anime | `TweenAnimationBuilder<double>` |
| **Set Grid Stagger** | Grille de sets avec apparition staggered | `AnimatedBuilder` avec delay par index |

---

## Personas & Jobs-to-be-Done

Cinq personas definissent les profils cibles de Magic Companion :

| Persona | Profil | Besoin principal | Willingness to pay |
|---------|--------|-----------------|-------------------|
| **Thomas** | Joueur Commander casual, 28 ans | Une seule app tout-en-un, gratuite, offline | 0-3 EUR/mois |
| **Sophie** | Collectionneuse methodique, 34 ans | Scanner rapide, prix integres, suivi de valeur | 5-10 EUR/mois |
| **Maxime** | Competitif Modern/Standard, 22 ans | Metagame, simulateur, stats tournoi | 5-8 EUR/mois |
| **Julie** | Debutante curieuse, 19 ans | Comprendre les regles en francais, simplicite | 0 EUR |
| **Antoine** | Joueur nostalgique reprenant, 42 ans | Retrouver la valeur de ses vieilles cartes | 3-5 EUR ponctuellement |

### Jobs-to-be-Done cles

- **En partie** : tracker les vies sans perdre le fil
- **Apres un booster** : scanner et connaitre la valeur de chaque carte en < 2s
- **En deckbuilding** : voir les stats, les suggestions et le budget
- **Sans connexion au LGS** : acceder a toute l'app offline
- **Face a une regle floue** : obtenir une reponse claire de l'Oracle IA instantanement
- **Pour trader** : connaitre la valeur de ses cartes pour faire un echange equitable

---

## Metriques & Experimentation

### North Star Metric

**Nombre de sessions actives par semaine par utilisateur** -- le meilleur proxy de la valeur delivree.

### Funnel cible

| Etape | Metrique | Cible |
|-------|----------|-------|
| Acquisition | Telechargements/mois | 1 000/mois (annee 1) |
| Activation | Completion onboarding + 1ere action | 70% des installs |
| Engagement | Sessions/semaine | 3+ sessions/semaine |
| Retention | J1 / J7 / J30 | 60% / 30% / 15% |
| Referral | Partages/user/mois | 1 partage/user/mois |

### Plan d'experimentation (7 hypotheses)

| # | Hypothese | Test | Seuil de succes |
|---|-----------|------|----------------|
| 1 | Les prix augmentent le temps sur page detail | Feature flag 50/50 | +20% temps page detail |
| 2 | L'onboarding augmente la retention | A/B avec/sans onboarding | +15% retention J7 |
| 3 | Le dashboard home augmente l'engagement | A/B dashboard vs life counter | +10% features utilisees |
| 4 | Les compteurs avances sont attendus | Fake door (bouton, mesure taps) | > 15% des users cliquent |
| 5 | Le playtest mode augmente l'usage decks | MVP playtest | > 20% des deckbuilders l'essaient |
| 6 | L'Oracle IA contextuel dans les decks est utile | Bouton "Demander a l'Oracle" sur page deck | +30% questions Oracle |
| 7 | Les animations ameliorent la satisfaction | A/B avec/sans animations life counter | +10% session time |

---

## Prochaines etapes

### Sprint 14 -- Actions immediates (P0)

1. **Integrer les prix Scryfall** sur page detail carte et dans la collection
2. **Ajouter compteurs Poison/Energy/Monarch** au life counter
3. **Creer l'onboarding** 3 ecrans (Scan, Decks, Oracle)
4. **Construire le Dashboard Home** avec stats collection, activite recente, carte du jour
5. **Implementer les animations de base** du life counter (pulse de vie, shake de degats)

### Wireframes livres

Quatre nouveaux ecrans ont ete specifies en wireframe dans l'audit :

- **Dashboard Home** : stats collection, activite recente, acces rapide, carte du jour
- **Prix & Valeur Collection** : valeur totale, graphique evolution, top cartes, movers
- **Playtest / Goldfish Mode** : main de depart, zones de jeu, stats live
- **Trade Helper** : comparaison cote-a-cote, calcul d'equite, suggestions

### Features innovantes identifiees

10 features "Waouh" non presentes chez les concurrents ont ete proposees, dont :

- Oracle IA - Analyse de Board State (photo du plateau -> suggestion du meilleur coup)
- Mode "Budget Upgrade" (ameliorations par palier 5/20/50 EUR)
- "Deck Doctor" (diagnostic complet par l'Oracle IA)
- Mode "Collection Challenge" (gamification hebdomadaire)
- "Price Alert" (alertes sur les cartes de la wishlist)

---

## Reference

- **Document source :** `docs/AUDIT_VIVI.md`
- **Sprint de base :** Sprint 13
- **Stack :** Flutter/Dart, Riverpod, go_router, drift/SQLite, Firebase, Scryfall API, EDHRec
- **Codebase :** 144 fichiers Dart, ~40 154 lignes de code
- **Modules existants :** cards, collections, decks, glossary, life_counter, oracle, scans, settings, tools, tournaments, wishlists

---

*Release notes generees par Brook - Technical Writer*
*Source : Audit Produit & Strategie UX par Vivi (8 mars 2026)*
