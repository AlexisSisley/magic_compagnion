# Audit Concurrentiel - Magic Companion
# Pipeline Pluton - Yamato (Veilleur Technologique)

> **Date** : 08/03/2026
> **Scope** : 11 concurrents analyses (Manabox, Delver Lens, MTG Familiar, Archidekt, Moxfield, TopDecked, CardCastle, TCGplayer, Dragon Shield, Deckbox, MTGGoldfish)
> **Objectif** : Identifier les gaps fonctionnels, opportunites UX et axes de differenciation pour Magic Companion

---

## 0. Etat des lieux Magic Companion (features actuelles)

| Domaine | Features implementees |
|---------|----------------------|
| **Collection** | Gestion par set, stats de completion, badges collection (normal/foil/wishlist), filtres avancés, quick-add, export |
| **Decks** | Builder, import/export, mana curve, power level, synergies, combos (EDHRec), tokens, legalite multi-format, suggestions IA, partage |
| **Scanner OCR** | Scan camera multi-langues, historique de scans, recherche manuelle fallback |
| **Life Counter** | Multi-joueurs, historique de parties, lance de des, commander damage, wakelock |
| **Recherche** | Recherche locale sur ~27 000 cartes (Isolate), syntaxe Scryfall, filtres universels |
| **Prix** | Integration Scryfall (prix TCGplayer/Cardmarket), tri par prix, filtre budget |
| **Oracle IA** | Chat IA pour regles et conseils (Firebase Cloud Functions) |
| **Glossaire** | Termes MTG, guide de tour |
| **Outils** | Calculateur hypergeometrique, tournois |
| **Backup** | Google Drive automatique |
| **Wishlists** | Wishlists multiples, detail par wishlist |
| **Profil** | Gestion de profils, onboarding |
| **Statistiques** | Stats globales collection, stats par set |

---

## 1. Matrice Concurrentielle Detaillee

### 1.1 Manabox
**Plateforme** : iOS, Android | **Modele** : Freemium ($2.49/mois, $22.99/an) | **Note** : 4.3/5 (8.6k avis)

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| Scanner rapide back-to-back | Tap pour scanner la meme carte en serie | Partiel (scan unitaire) |
| Dossiers de decks | Organisation hierarchique en folders | NON |
| Deck simulator (goldfish) | Pioche simulee, test de main de depart | NON |
| Trade tool | Comparaison de cartes pour echanges equitables | NON |
| Lien de deck partageable (web) | Ouvre dans n'importe quel navigateur | Partiel (share text) |
| Prix multi-marketplaces | TCGplayer, Cardmarket, etc. en simultane | Partiel (Scryfall seulement) |
| Mana Curve + Mana Production stats | Double analyse mana | Partiel (curve seulement) |
| Import CSV vendeurs Cardmarket | Pour les vendeurs/revendeurs | NON |
| Groupement printings dans les sets | Vue groupee des reimpressions | NON |
| Filtres monocolor/multicolor avances | Nombre exact de couleurs | Partiel |

**Faiblesses Manabox** :
- Interface mobile parfois encommbree sur les recherches avancees
- Problemes de lag camera apres certaines MAJ
- Pas d'integration EDHRec directe
- Necessite abonnement pour features avancees

**Opportunites pour Magic Companion** :
- Notre Oracle IA est unique -- aucun concurrent n'a ca
- Notre integration EDHRec (combos, suggestions) est un avantage
- Scanner OCR multi-langues deja en place

---

### 1.2 Moxfield
**Plateforme** : Web (responsive mobile) | **Modele** : Gratuit + Patreon | **Note** : Reference communautaire

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| Playtester/Goldfish | Simulation de partie solo avec hotkeys | NON |
| Packages de cartes | Groupes de cartes reutilisables entre decks | NON |
| Mode Analyse | Mana curve, distribution couleurs, types | OUI (partiel) |
| Mode Upgrade | Suggestions amelioration via EDHREC | OUI (via suggestions controller) |
| Mode Compare | Diff entre 2 versions d'un deck | NON |
| Collaboration temps reel | Plusieurs users editent un deck | NON |
| Auto-completion recherche | Suggestions temps reel | Partiel |
| Support 30+ formats | Validation legalite tous formats | OUI (legality service) |
| Custom tagging | Tags libres sur les decks | OUI |

**Faiblesses Moxfield** :
- Pas d'app native mobile (web only, UX mobile degradee)
- Playtester limite a 1 joueur (pas de multi)
- Pas de scanner de cartes
- Pas de life counter
- Pas de gestion de collection physique poussee

**Opportunites pour Magic Companion** :
- Moxfield n'a PAS de scanner, life counter ni oracle IA
- L'avantage app native Flutter est enorme sur mobile
- Le mode Compare de decks serait un quick win a implementer

---

### 1.3 Archidekt
**Plateforme** : Web | **Modele** : Gratuit + Premium | **Note** : Populaire pour EDH

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| Drag & drop builder | Construction visuelle par glisser-deposer | NON |
| Tag recommendations auto | Suggestion de tags pour decks Commander legaux | NON |
| Custom Cards | Creation de cartes personnalisees | NON |
| Concours deckbuilding mensuels | Communaute et competitions | NON |
| Donnees EDHREC integrees | Recommandations dans le builder | OUI |
| Prix TCGPlayer + CardKingdom + Cardhoarder + Cardmarket | Multi-sources | Partiel |
| Import Arena/MTGO | Import depuis clients officiels | OUI (import modal) |

**Faiblesses Archidekt** :
- Playtester mediocre (cartes bougent avec le scroll, battlefield encombre)
- Pas d'app native mobile
- Pas de scanner
- Pas de life counter

**Opportunites pour Magic Companion** :
- Builder drag & drop en Flutter est faisable (ReorderableListView)
- Les concours communautaires seraient un levier d'engagement

---

### 1.4 Delver Lens
**Plateforme** : Android (+ PWA iOS) | **Modele** : Gratuit + achats in-app | **Note** : 3.7/5

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| Scan tokens et emblemes | Reconnaissance au-dela des cartes | NON |
| Oracle text offline | Consultation hors ligne | OUI (local cards) |
| Export multi-plateformes | Archidekt, CardSphere, DeckBox, CSV | Partiel |
| Prix TCGplayer + Cardmarket + conversion devises | Multi-devises | Partiel |
| Achat direct Card Kingdom | Lien d'achat dans l'app | NON |
| Export CSV compatible Excel | Pour gestion externe | NON |

**Faiblesses Delver Lens** :
- Precision scanner ~90% (moins bon que TCGplayer)
- Problemes avec cartes foil/etched
- iOS en retard de features vs Android
- Interface datee

**Opportunites pour Magic Companion** :
- Notre scanner multi-langues est un differentiel
- L'export CSV serait trivial a ajouter

---

### 1.5 Dragon Shield MTG Companion
**Plateforme** : iOS, Android | **Modele** : Gratuit | **Note** : Populaire

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| **AR Translation** | Superposition traduction EN sur carte non-EN en realite augmentee (iOS) | NON |
| Scan multi-langues natif | Reconnaissance toutes langues | OUI |
| Prix 4 sources | TCGPlayer, CardMarket, CardKingdom, MTGMintCard | Partiel |
| **Historique prix 30 jours** | Graphique d'evolution de prix | NON |
| **Social : amis, collections partagees** | Voir collections/wishlists/tradelists des amis | NON |
| QR code invitation amis | Partage par QR | NON |
| Dupliquer deck d'un ami | Copie rapide de deck | NON |
| Dossiers custom + images | Organisation collection en dossiers visuels | NON |
| Suivi valeur collection dans le temps | Graphique d'evolution valeur | NON |
| Sideboard support complet | Builder avec sideboard | Partiel |

**Faiblesses Dragon Shield** :
- AR uniquement iOS
- Analytics limites pour collecteurs serieux
- App mobile only, pas de web
- Tracking prix basique (pas d'historique profond)
- Base de donnees plus petite

**Opportunites pour Magic Companion** :
- La feature AR Translation est la plus "wow" du marche -- Flutter peut l'implementer via camera + Scryfall
- Le social (amis + collections partagees) est un gap critique
- Le suivi de valeur dans le temps est tres demande

---

### 1.6 TopDecked
**Plateforme** : iOS, Android, Web, Desktop | **Modele** : Freemium premium | **Note** : Solide

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| **Sync cross-device cloud** | Phone, tablet, desktop, browser | NON (Google Drive backup != sync) |
| Battlefield simulator | Test sur champ de bataille virtuel | NON |
| Auto-recommendations deck | Suggestions d'amelioration | OUI |
| Commander Bracket Support | Categorie de puissance Commander | OUI (power level) |
| Life Counter customisable (font size) | Personnalisation visuelle | Partiel |
| Partage social media | Integration reseaux sociaux | Partiel |
| Charts mana curve + color distribution | Analyse visuelle complete | OUI |

**Faiblesses TopDecked** :
- Features premium payantes pour l'essentiel
- Interface parfois complexe
- Moins populaire que Manabox/Moxfield

---

### 1.7 TCGplayer
**Plateforme** : iOS, Android | **Modele** : Gratuit | **Note** : Reference prix

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| **Scan multi-TCG** | MTG + Pokemon + YuGiOh + One Piece + 10+ jeux | NON (MTG only) |
| **Scan en sleeve/binder** | Fonctionne avec protections | Partiel |
| **Scan multi-cartes simultane** | Plusieurs cartes en meme temps | NON |
| **Scan cartes non-EN** | Toutes langues | OUI |
| Prix Market temps reel | Base sur transactions reelles | Partiel (via Scryfall) |
| Import scan vers inventaire vendeur | Pour vendeurs pro | NON |
| Vue compacte collection | Affichage dense | Partiel |

**Faiblesses TCGplayer** :
- Pas de deck builder integre
- Pas de life counter
- Focalise marketplace, pas collection
- Organisation basique

---

### 1.8 CardCastle
**Plateforme** : iOS, Android + Web | **Modele** : Freemium

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| Playtester complet | Test de deck avec champ de bataille | NON |
| Prix Card Kingdom | Source de prix additionnelle | NON |
| Deckbuilder web + mobile sync | Coherence multi-device | NON |

**Faiblesses** : Communaute plus petite, moins de features que Manabox.

---

### 1.9 Deckbox
**Plateforme** : Web | **Modele** : Gratuit + Premium

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| **Trading automatique** | Matching automatique de traders compatibles | NON |
| **Systeme de feedback traders** | Reputation et confiance | NON |
| Grade de condition carte | Mint, NM, LP, MP, HP, Damaged | NON |
| Historique prix complet | Prix historiques longue duree | NON |
| Tradelist/Wishlist publique | Visible par la communaute | NON |
| Quick-add optimise | Ajout rapide avec defaults par set | OUI (quick add view) |

**Faiblesses Deckbox** :
- Interface datee et peu ergonomique
- Pas de scanner
- MTG only
- Courbe d'apprentissage elevee
- Pas d'app mobile

---

### 1.10 MTGGoldfish
**Plateforme** : Web (+ mobile responsive) | **Modele** : Gratuit + Premium ($6/mois)

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| **SuperBrew deck finder** | Recherche IA de decks | NON |
| **Price alerts illimites** | Alertes de prix personnalisees | NON |
| **Historique prix telechargeable** | CSV export prix | NON |
| Metagame analysis | Stats meta par format | NON |
| Content editorial | Articles, videos, guides | NON |
| Deck pricer tool | Calcul prix total deck | OUI |

**Faiblesses** : Pas d'app native, pas de scanner, pas de life counter, premium cher.

---

### 1.11 MTG Familiar
**Plateforme** : Android (open source) | **Modele** : Gratuit, sans pub

| Feature | Detail | Magic Companion a ca ? |
|---------|--------|----------------------|
| **Recherche 100% offline** | Aucune connexion requise | OUI (local card service) |
| **Regles completes cherchables** | Comprehensive rules integrales avec liens | NON (glossaire seulement) |
| Des D2-D100 | Full range de des | Partiel (dice roll dialog) |
| Poison counters | Compteur poison dedie | OUI |
| Round timer background | Timer de round en arriere-plan | NON |
| Prix TCGplayer temps reel | Quand connecte | OUI |

**Faiblesses** : Android only, interface tres datee, pas de scanner, pas de collection, pas de deck builder complet.

---

## 2. Features Manquantes - Gap Analysis par Priorite

### P0 - Differentiateurs Critiques (Impact business)

| Feature | Qui l'a | Effort estime | Impact |
|---------|---------|---------------|--------|
| **Deck Goldfish/Playtester** | Manabox, Moxfield, Archidekt, CardCastle, TopDecked | 3-5 sprints | Enorme -- feature #1 demandee |
| **Social : amis + collections partagees** | Dragon Shield, Deckbox | 3-4 sprints | Retention + viralite |
| **Trade Tool** | Manabox, Deckbox, Dragon Shield | 2-3 sprints | Monetisation possible |
| **Historique prix + graphique** | Dragon Shield, Deckbox, MTGGoldfish | 1-2 sprints | Valeur percue elevee |
| **Sync cloud temps reel** | TopDecked, Manabox, CardCastle | 2-3 sprints | Indispensable multi-device |

### P1 - Features a Forte Valeur Ajoutee

| Feature | Qui l'a | Effort estime | Impact |
|---------|---------|---------------|--------|
| **Deck Compare mode** | Moxfield | 1 sprint | Quick win tres utile |
| **Dossiers de decks** | Manabox | 0.5 sprint | Organisation basique |
| **Scan back-to-back rapide** | Manabox | 0.5 sprint | UX scanner amelioree |
| **Grade de condition carte** | Deckbox | 0.5 sprint | Collection serieuse |
| **Regles completes cherchables** | MTG Familiar | 1-2 sprints | Oracle IA deja meilleur |
| **Round timer** | MTG Familiar | 0.5 sprint | Complement life counter |
| **Price alerts** | MTGGoldfish | 1 sprint | Engagement notification |
| **Export CSV collection** | Delver Lens, Deckbox | 0.25 sprint | Trivial a faire |
| **Scan tokens et emblemes** | Delver Lens | 1 sprint | Completude scanner |

### P2 - Nice-to-Have / Innovants

| Feature | Qui l'a | Effort estime | Impact |
|---------|---------|---------------|--------|
| AR Translation cartes non-EN | Dragon Shield | 2-3 sprints | "Wow" factor |
| Custom Cards | Archidekt | 1-2 sprints | Niche |
| Metagame analysis | MTGGoldfish | 2-3 sprints | Competitif |
| Concours deckbuilding | Archidekt | 1 sprint | Communaute |
| Multi-TCG support | TCGplayer | Massif | Hors scope actuel |

---

## 3. Animations et Effets UI/UX Remarquables chez les Concurrents

### 3.1 Effets observes dans l'ecosysteme

| App | Effet | Description |
|-----|-------|-------------|
| Manabox | **Card swipe fluide** | Transition smooth entre cartes avec inertie physique |
| Manabox | **Scan feedback haptic** | Vibration + flash visuel a la detection |
| Dragon Shield | **AR overlay** | Superposition 3D de la traduction sur la carte physique |
| Moxfield | **Playtester drag** | Drag and drop fluide sur le champ de bataille |
| TopDecked | **Cross-fade transitions** | Transitions douces entre vues |
| TCGplayer | **Scan multi-overlay** | Multiples cadres de detection simultanes |
| Archidekt | **Drag & drop builder** | Cards qui suivent le doigt avec shadow |

### 3.2 Tendances UI/UX TCG 2025-2026

- **3D Card Flip** : Rotation perspective 3D au tap sur une carte (double-face)
- **Parallax tilt** : Inclinaison gyroscope pour effet holographique sur les cartes foil
- **Particle effects** : Particules dorees/brillantes sur les cartes mythiques/foil
- **Haptic feedback** : Retour haptique contextuel (scan reussi, ajout collection, etc.)
- **Skeleton loading** : Placeholders animes pendant le chargement d'images
- **Micro-interactions** : Bounce sur ajout au deck, pulse sur ajout collection
- **Swipe gestures** : Navigation entre cartes par swipe horizontal

---

## 4. Points Faibles des Concurrents a Exploiter

### Faiblesse systemique : Aucun concurrent ne combine TOUT

| Concurrent | Ce qui lui manque |
|-----------|-------------------|
| Manabox | Pas d'Oracle IA, pas d'EDHRec combos integre, pas d'hypergeometrique |
| Moxfield | Pas d'app native, pas de scanner, pas de life counter, pas de collection physique |
| Archidekt | Pas d'app native, playtester mediocre, pas de scanner |
| Delver Lens | Interface datee, precision scanner inferieure, pas de deck builder complet |
| Dragon Shield | Analytics limites, pas d'Oracle IA, AR iOS only |
| TopDecked | Premium obligatoire pour l'essentiel, communaute petite |
| TCGplayer | Marketplace only, pas de deckbuilding, pas de life counter |
| CardCastle | Communaute tres petite, features limitees |
| Deckbox | Web only, interface archaique, pas de scanner |
| MTGGoldfish | Web only, pas de scanner, pas de life counter, premium cher |
| MTG Familiar | Android only, interface obsolete, pas de scanner, minimaliste |

### L'avantage unique de Magic Companion

**Aucun concurrent ne propose les 3 piliers ensemble dans une app native mobile** :
1. Scanner OCR multi-langues + Collection complete
2. Life Counter multi-joueurs + Historique de parties
3. Oracle IA conversationnel + EDHRec integre

C'est le positionnement "Swiss Army Knife" -- l'app tout-en-un pour le joueur MTG.

---

## 5. Idees de Features Innovantes pour se Demarquer

### 5.1 IA & Intelligence

| Feature | Description | Differentiel |
|---------|-------------|-------------|
| **Oracle IA Pro** | Analyse de board state par photo (scan du jeu en cours) + conseil tactique | Aucun concurrent |
| **Deck Doctor IA** | Upload un deck, l'IA identifie les faiblesses, suggere des swaps avec budget | MTGGoldfish SuperBrew est web-only |
| **Price Predictor** | IA qui predit les tendances de prix basee sur le metagame et les bans | Aucun concurrent |
| **Draft Helper IA** | Assistant de pick en draft avec scoring temps reel | TopDecked a un mode, mais basique |

### 5.2 Social & Communaute

| Feature | Description | Differentiel |
|---------|-------------|-------------|
| **Playgroups** | Creer un groupe de joueurs, tracker les stats (win rates, decks preferes) | Seul Mythic Tools l'a |
| **Trade Matcher local** | Bluetooth/proximity pour matcher les tradelists entre joueurs presents | Aucun concurrent |
| **Deck Challenges** | Defis hebdomadaires (ex: "construis un deck a moins de 20eur") | Archidekt fait des concours web only |
| **Collection Showroom** | Profil public avec showcase de ses plus belles cartes | Dragon Shield a les collections partagees |
| **Match History Social** | Partager ses resultats de partie avec stats visuelles sur les reseaux | Aucun concurrent natif |

### 5.3 Gamification

| Feature | Description | Differentiel |
|---------|-------------|-------------|
| **Achievements System** | Badges pour milestones (100 cartes scannees, premier deck complet, etc.) | MTG Arena l'a, aucune app companion |
| **Collection Quests** | Quetes dynamiques ("complete 5 sets de Ravnica", "obtiens 10 mythiques noires") | Aucun concurrent |
| **XP & Niveaux** | Systeme de progression basee sur l'utilisation de l'app | Aucun concurrent |
| **Streaks** | Serie de jours consecutifs (scan quotidien, partie quotidienne) | Aucun concurrent |
| **Leaderboard collection** | Classement entre amis par valeur ou completion de collection | Aucun concurrent |

### 5.4 Realite Augmentee & Camera

| Feature | Description | Differentiel |
|---------|-------------|-------------|
| **AR Card Viewer** | Pointer la camera sur une carte = overlay de stats, prix, legalite | Dragon Shield a la traduction AR, mais pas les stats |
| **AR Deck Spread** | Visualiser son deck en AR etale sur une table | Aucun concurrent |
| **Foil Effect Simulator** | Voir l'effet foil/extended/borderless sur ses cartes en AR | Aucun concurrent |
| **Scan & Auto-Deck** | Scanner sa collection physique, l'IA genere un deck optimise | Aucun concurrent |

---

## 6. Animations et Micro-interactions Recommandees

### 6.1 Quick Wins (implementables en 1-2 jours chacun)

| Animation | Ou | Technique Flutter | Impact |
|-----------|-----|-------------------|--------|
| **Card Flip 3D** | Detail carte double-face | `Transform` + `Matrix4.rotationY` | Wow factor immediat |
| **Haptic feedback** | Scan reussi, ajout collection, +/- life | `HapticFeedback.mediumImpact()` | Satisfaction tactile |
| **Bounce add-to-deck** | Bouton ajout deck | `AnimatedScale` avec rebond | Micro-satisfaction |
| **Fade-in staggere** | Liste de cartes | `AnimatedList` + staggered delay | Fluidite percue |
| **Shimmer loading** | Chargement images cartes | Package `shimmer` ou custom | Pro feel |
| **Counter roll animation** | Life counter +/- | `AnimatedSwitcher` avec slide | Dynamisme |
| **Pull-to-refresh spring** | Listes collection/decks | `RefreshIndicator` custom | Standard moderne |

### 6.2 Moyen Terme (1-2 sprints)

| Animation | Ou | Technique Flutter | Impact |
|-----------|-----|-------------------|--------|
| **Parallax card tilt** | Detail carte (gyroscope) | `sensors_plus` + `Transform` | Effet holographique foil |
| **Card reveal animation** | Ouverture de booster virtuel | `AnimationController` + particules | Gamification |
| **Collection milestone celebration** | Set complete a 100% | Confettis (`confetti` package) | Moment memorable |
| **Deck mana curve animated** | Stats deck | `fl_chart` animations natives | Deja en place, ameliorer |
| **Scan success particle burst** | Scanner | `CustomPainter` particules | Satisfaction scan |
| **Hero transitions** | Carte liste -> detail | `Hero` widget natif Flutter | Navigation fluide |
| **Swipe navigation cartes** | Detail carte | `PageView` avec physics custom | Navigation naturelle |

### 6.3 Long Terme (features majeures)

| Animation | Ou | Technique Flutter | Impact |
|-----------|-----|-------------------|--------|
| **Playtester battlefield** | Goldfish mode | Drag & drop + physics engine | Feature majeure |
| **AR overlay** | Scanner augmente | `camera` + overlay Widgets | Differenciant |
| **Booster pack opening** | Gamification | Sequence animee multi-etapes | Viral potential |
| **Deck comparison visual** | Compare mode | Side-by-side animated diff | Utilitaire puissant |
| **Trade animation** | Trade tool | Cartes qui glissent entre 2 zones | UX premium |

---

## 7. Recommandations Priorisees - Plan d'Action

### Sprint 15 (Quick Wins UX) -- 2 semaines

1. **Card Flip 3D** pour cartes double-face -- Effort : 1j, Impact : haut
2. **Haptic feedback** sur scan/collection/life counter -- Effort : 0.5j, Impact : moyen
3. **Shimmer loading** sur toutes les images de cartes -- Effort : 1j, Impact : moyen
4. **Export CSV** de la collection -- Effort : 0.5j, Impact : moyen
5. **Dossiers de decks** (folders simples) -- Effort : 1j, Impact : moyen
6. **Hero transitions** carte liste -> detail -- Effort : 1j, Impact : haut

### Sprint 16 (Social & Prix) -- 2 semaines

1. **Historique prix 30 jours** avec graphique (Scryfall daily) -- Effort : 3j, Impact : haut
2. **Price alerts** (notifications locales) -- Effort : 2j, Impact : moyen
3. **Scan back-to-back** (tap pour rescanner) -- Effort : 1j, Impact : moyen
4. **Round timer** pour tournois -- Effort : 1j, Impact : moyen
5. **Grade condition carte** (Mint/NM/LP/MP/HP) -- Effort : 1j, Impact : moyen

### Sprint 17 (Goldfish & Compare) -- 2 semaines

1. **Deck Compare mode** (diff visuel entre 2 decks) -- Effort : 3j, Impact : haut
2. **Goldfish / Playtester basique** (pioche, mulligan, main de depart) -- Effort : 5j, Impact : tres haut
3. **Packages de cartes reutilisables** -- Effort : 2j, Impact : moyen

### Sprint 18 (Gamification) -- 2 semaines

1. **Achievements system** avec badges visuels -- Effort : 3j, Impact : haut
2. **Collection milestones** avec animations celebrations -- Effort : 2j, Impact : moyen
3. **Streaks** (jours consecutifs d'utilisation) -- Effort : 1j, Impact : moyen
4. **XP & niveaux** de profil joueur -- Effort : 2j, Impact : moyen

### Sprint 19-20 (Social) -- 4 semaines

1. **Systeme d'amis** (ajout QR/lien, liste d'amis) -- Effort : 5j, Impact : tres haut
2. **Collections/wishlists partagees** (visibles entre amis) -- Effort : 3j, Impact : haut
3. **Trade matcher** (match automatique wishlists/tradelists) -- Effort : 4j, Impact : haut
4. **Playgroups** (groupes de joueurs, stats partagees) -- Effort : 3j, Impact : moyen

### Sprint 21+ (Innovation)

1. **AR Card Info Overlay** -- camera + overlay prix/legalite
2. **Booster pack opening** virtuel (gamification)
3. **Deck Doctor IA** (analyse et correction automatique)
4. **Scan & Auto-Deck** (IA genere un deck depuis la collection)

---

## 8. Positionnement Strategique Recommande

```
         SPECIALISTE SCANNER          ALL-IN-ONE
              |                           |
  Delver Lens |                           | <-- Magic Companion (cible)
  TCGplayer   |                           |
              |                           | Manabox
              |                           |
              |         TopDecked         |
              |                           |
  OUTILS      |                           | SOCIAL
  BASIQUES    |     MTG Familiar          | COMMUNAUTE
              |                           |
              |         Deckbox           | Dragon Shield
              |                           |
              |   Archidekt   Moxfield    |
              |                           |
         SPECIALISTE DECKS           MARKETPLACE
              |                           |
              |                    TCGplayer
              |         MTGGoldfish       |
```

**Positionnement cible** : L'app all-in-one la plus complete du marche, differenciee par :
1. **Oracle IA** (unique)
2. **Tout-en-un natif** (scanner + collection + decks + life counter + social)
3. **Gamification** (achievements, quetes, progression)
4. **Social local** (playgroups, trade matcher, partage)

---

## 9. Synthese Executive

### Top 5 Features Manquantes les Plus Critiques
1. **Goldfish / Playtester** -- 5/5 concurrents deck-builders l'ont
2. **Social (amis + partage)** -- Dragon Shield montre que ca fonctionne
3. **Historique prix** -- Demande universelle des collecteurs
4. **Sync cloud temps reel** -- Standard pour le multi-device
5. **Gamification (achievements)** -- Zero concurrent companion l'a

### Top 5 Avantages Actuels a Proteger
1. **Oracle IA** -- Aucun concurrent, avantage massif
2. **EDHRec integre** (combos, suggestions) -- Seul Moxfield/Archidekt l'ont en web
3. **App native Flutter tout-en-un** -- Aucun concurrent ne combine tout
4. **Calculateur hypergeometrique** -- Feature de niche rare
5. **Scanner OCR multi-langues** -- Competitif avec les meilleurs

### Conclusion

Magic Companion est deja parmi les apps les plus completes du marche. Les gaps principaux sont le **goldfish/playtester**, le **social**, et la **gamification**. En ajoutant ces 3 piliers + les animations "wow" recommandees, l'app peut se positionner comme la reference absolue pour le joueur MTG mobile.

L'absence d'Oracle IA chez TOUS les concurrents est un avantage strategique majeur a capitaliser.

---

> **Sources de cette analyse** :
> - [ManaBox - Google Play](https://play.google.com/store/apps/details/ManaBox?id=skilldevs.com.manabox&hl=en_GB)
> - [ManaBox Official](https://manabox.app/)
> - [Delver Lens](https://www.delverlab.com/)
> - [Moxfield](https://moxfield.com/)
> - [Archidekt](https://archidekt.com/)
> - [TopDecked](https://www.topdecked.com/)
> - [TCGplayer App](https://play.google.com/store/apps/details?id=com.tcgplayer.tcgplayer&hl=en_US)
> - [Dragon Shield Card Manager](https://www.dragonshield.com/card-manager)
> - [Deckbox](https://deckbox.org/)
> - [MTGGoldfish](https://www.mtggoldfish.com/)
> - [MTG Familiar - GitHub](https://github.com/AEFeinstein/mtg-familiar)
> - [CardCastle](https://cardcastle.co/)
> - [Draftsim - Best MTG Deck Builder](https://draftsim.com/best-mtg-deck-builder/)
> - [TCG Stacked - Best Collection Apps 2025](https://www.tcgstacked.com/articles/best-trading-card-collection-apps-tools)
> - [Moxfield Playtest Commands - Toxigon](https://toxigon.com/moxfield-playtest-commands)
> - [Wargamer - MTG Companion App 2026](https://www.wargamer.com/magic-the-gathering/companion-app-update)
