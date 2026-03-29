# Life Counter v2 — Design Spec

> **Date** : 2026-03-29
> **Scope** : Refonte du système de comptage de points de vie, création de partie, profils joueurs, animations, stats
> **Approche** : Refactoring progressif du module existant

---

## 1. Vue d'ensemble

Refonte complète de l'expérience Life Counter de Magic Companion. Objectifs :

- **Ergonomie** : Quick Start en 2 taps, layout adaptatif selon le nombre de joueurs, drag & drop des zones
- **Flexibilité** : Presets de formats + mode Custom, compteurs configurables, commanders liés au format
- **Immersion** : Animations dramatiques selon l'ampleur, seuils critiques visuels, historique des variations
- **Données** : Stats & Analytics par deck, adversaire, format. Migration persistance vers Drift
- **Profils** : Distinction Owner (lié aux decks/collection) vs Guest (profil rapide invité)

---

## 2. Modèle de données

### 2.1 GameFormat (Presets + Custom)

```
GameFormat
├── id: String (uuid)
├── name: String ("Commander", "Standard", "Oathbreaker", "Custom"...)
├── startingLife: int (40, 20, 25, ou libre)
├── minPlayers: int
├── maxPlayers: int
├── maxCommanders: int (2 pour Commander, 1 pour Oathbreaker, ∞ pour Custom)
├── enabledCounters: List<CounterType>
├── isBuiltIn: bool (true = preset non supprimable)
```

**Presets intégrés :**

| Format | PV | Joueurs | Commanders | Compteurs spéciaux |
|--------|-----|---------|------------|-------------------|
| Commander | 40 | 2-8 | 2 (partner) | Poison, Energy, Commander Tax, Commander Damage |
| Duel Commander | 30 | 2 | 2 | Poison, Commander Damage |
| Standard | 20 | 2 | 0 | Poison, Energy |
| Oathbreaker | 20 | 2-6 | 1 | Poison, Energy |
| Brawl | 25 | 2-4 | 1 | Poison, Energy, Commander Damage |
| Custom | libre | 2-8 | ∞ | Tout configurable |

### 2.2 CounterType (Classiques + Custom)

```
CounterType
├── id: String
├── name: String ("Poison", "Energy", ou custom: "Storm Count"...)
├── icon: IconData (ou emoji pour les custom)
├── color: Color
├── isBuiltIn: bool
├── maxValue: int? (Poison = 10 létal, sinon null = illimité)
```

### 2.3 PlayerConfig (Owner vs Guest)

```
PlayerConfig
├── id: String
├── name: String
├── type: enum { owner, guest }
├── colorValue: int
├── avatarPath: String?
│
├── // Si owner → lien vers les vrais decks
├── linkedDeckId: String? (FK vers Deck existant)
│   └── hérite automatiquement: commander(s), artwork, couleurs du deck
│
├── // Si guest OU owner sans deck lié → saisie manuelle
├── commanders: List<CommanderInfo>
│   └── CommanderInfo { name, scryfallId?, artCropUrl? }
```

### 2.4 GameSession (État de partie complet)

```
GameSession
├── id: String
├── format: GameFormat
├── players: List<PlayerState>
├── activeCounters: List<CounterType> (classiques du format + customs ajoutés)
├── customCounters: List<CounterType> (les customs ajoutés pour cette partie)
├── startedAt: DateTime?
├── duration: Duration
├── isActive: bool
├── eliminationOrder: List<int> (player ids dans l'ordre d'élimination)
├── playerOrder: List<int> (ordre des zones après drag & drop)
├── tag: String? (ex: "soirée chez Max")

PlayerState
├── playerId: int
├── config: PlayerConfig
├── life: int
├── counters: Map<String, int> (counterId → valeur)
├── commanderDamageReceived: Map<int, int> (opponentId → damage)
├── isEliminated: bool
├── eliminatedAt: Duration? (timestamp relatif au début de partie)
├── isMonarch: bool
├── quarterTurns: int (rotation de la zone)
├── lifeHistory: List<LifeEvent> (pour l'historique visuel)

LifeEvent
├── delta: int (+5, -3, -21...)
├── source: String? ("Commander: Atraxa", "Poison", ou null pour PV normaux)
├── timestamp: Duration (relatif au début de partie)
```

---

## 3. Système d'animations et feedback visuel

### 3.1 AnimationService

Service centralisé qui détermine l'animation à jouer selon le contexte et l'amplitude :

```
AnimationService
├── getLifeAnimation(delta, currentLife, startingLife) → AnimationConfig
├── getCounterAnimation(counterType, delta) → AnimationConfig
├── getEliminationAnimation() → AnimationConfig
├── getCriticalThreshold(currentLife, startingLife) → CriticalLevel?
```

### 3.2 Matrice d'animations PV

| Situation | Animation | Durée | Détail |
|-----------|-----------|-------|--------|
| Gain léger (+1 à +5) | Pulse léger | 200ms | Scale 1.0→1.08→1.0 |
| Gain massif (+6 et +) | Pulse fort + particules dorées | 400ms | Scale 1.0→1.15→1.0 + particles ascendantes |
| Perte légère (-1 à -5) | Shake léger | 250ms | Translation X ±4px |
| Perte moyenne (-6 à -10) | Shake moyen + flash rouge | 350ms | Translation X ±8px + fond flash rouge 20% opacité |
| Perte massive (-11 et +) | Shake fort + tremblement + flash | 500ms | Translation X ±12px + vibration haptic + flash rouge 40% |
| Commander damage | Shake + icône commander pulse | 350ms | Shake moyen + portrait commander scale up |
| Poison | Shake + tint vert | 300ms | Shake léger + overlay vert toxique fade |

**Note** : Les animations Commander damage et Poison sont prévues pour évoluer vers des assets riches (GIF/Lottie/Rive) dans une version future. L'architecture inclut une couche d'assets remplaçables (`AnimationAssetProvider`) pour permettre ce swap sans refactor.

### 3.3 Seuils critiques

```
CriticalLevel
├── safe: life > 50% starting     → zone normale
├── warning: life 25-50% starting → bordure pulse orange lent (3s cycle)
├── danger: life 10-25% starting  → bordure rouge pulse rapide (1.5s) + fond assombri
├── lethal: life ≤ 10% starting   → bordure rouge intense (0.8s) + craquelures subtiles
```

Exemples : Commander (40 PV) → warning ≤20, danger ≤10, lethal ≤4. Standard (20 PV) → warning ≤10, danger ≤5, lethal ≤2.

### 3.4 Historique visuel (Life Log)

Mini-log superposé sur la zone joueur :
- 4 dernières variations affichées simultanément maximum
- Chaque variation reste visible 8 secondes puis fade out
- Couleur par type : rouge (perte PV), vert (gain PV), violet (commander damage), vert toxique (poison)
- Double tap sur le log → ouvre l'historique complet de la partie

### 3.5 Animation d'élimination

Séquence en 3 temps :
1. **Flash rouge** (200ms) — toute la zone flash
2. **Fissures** (400ms) — craquelures depuis le centre (CustomPainter, évoluera vers Lottie/Rive)
3. **Overlay sombre** (300ms fade in) — overlay noir 60% + skull + texte "Éliminé"

Zone figée en place, commander damage toujours lisible à travers l'overlay.

---

## 4. Layout adaptatif

### 4.1 LayoutStrategy Pattern

```
LayoutStrategy (abstract)
├── FaceToFaceLayout    → 2 joueurs
├── GridLayout          → 3-4 joueurs
├── FocusLayout         → 5-8 joueurs

LayoutResolver
├── resolve(playerCount, userPreference?) → LayoutStrategy
│   - 2 → FaceToFaceLayout
│   - 3-4 → GridLayout (défaut) ou FocusLayout (switch manuel)
│   - 5-8 → FocusLayout (défaut) ou GridLayout (switch manuel)
```

### 4.2 Détail des layouts

**FaceToFace (2 joueurs)** : Deux zones empilées verticalement. Zone haute rotée 180°. Séparateur central avec boutons menu (dé, timer, settings).

**Grid (3-4 joueurs)** : 4J = grille 2×2, rotation automatique. 3J = grille 2+1 (2 en haut, 1 en bas centré pleine largeur). Chaque zone a les mêmes contrôles.

**Focus (5-8 joueurs)** : Ma zone en bas (~40% écran) avec contrôles complets. Adversaires en bandeau compact scrollable en haut. Tap sur un adversaire → bottom sheet avec sa zone complète.

### 4.3 Drag & Drop des zones

- **Activation** : Long press (1s) sur le header → la zone se décolle (scale 1.05 + ombre + transparence 80%)
- **Pendant le drag** : Placeholders en pointillés, illumination au survol
- **Au drop** : Swap avec animation 300ms easeInOut. Hors placeholder → retour spring animation
- **Rotation** : Bouton rotation conservé (tap = +90°) pour ajuster l'orientation
- **Persistance** : Arrangement sauvé dans `GameSession.playerOrder`
- **Par layout** : FaceToFace = swap haut/bas. Grid = swap libre entre 4 positions. Focus = swap entre adversaires + swap avec "moi"

### 4.4 PlayerZone v2 — Décomposition

```
PlayerZone (container)
├── PlayerHeader        → nom, avatar/commander artwork, couleur
├── LifeDisplay         → PV gros au centre, boutons +/- sur les côtés
├── LifeLog             → historique des 4 dernières variations
├── CounterStrip        → swipe horizontal entre compteurs
├── CriticalOverlay     → bordure animée selon seuil
├── EliminationOverlay  → overlay sombre + skull
├── RadialMenu          → long press → actions rapides
```

### 4.5 Barre de contrôle centrale

Barre flottante entre les zones : `[🎲 Dé] [⏱ Timer] [🔄 Switch layout] [⚙️ Settings] [🏁 Fin de partie]`

---

## 5. Game Setup Flow

### 5.1 Quick Start

Écran principal au lancement de partie. Objectif : 2 taps pour démarrer.

- Chips scrollables des presets (Commander, Standard, Duel, Oathbreaker, Brawl, Custom)
- Sélecteur rapide du nombre de joueurs (2, 3, 4, 5+)
- Bouton "LANCER LA PARTIE" toujours visible
- Lien "⚙️ Personnaliser..." vers les settings avancés
- Le preset sélectionné pré-remplit PV et nombre de joueurs recommandé

### 5.2 Settings avancés

Page avec sections collapsibles :
- **Format** : preset sélectionné, PV modifiable, commanders max
- **Joueurs** : liste des slots. Slot "Moi" → choisir un deck lié à la collection. Slots invités → profil rapide (nom, couleur, commander)
- **Compteurs** : checkboxes pour les classiques + bouton "Ajouter compteur custom"
- **Options** : Timer on/off, tag de partie
- Bouton "LANCER LA PARTIE" en bas

### 5.3 Sélection deck (Owner)

Tap sur le slot "Moi" → bottom sheet avec les decks de la collection (artwork commander). Option "Sans deck" pour saisie manuelle.

### 5.4 Édition profil invité

Tap sur un slot invité → bottom sheet : nom, couleur (palette), commander (recherche Scryfall), partner (si format le permet). Bouton "Sauvegarder comme profil" pour réutilisation future.

### 5.5 Profils sauvegardés

Bouton "📋 Profils" sur chaque slot → charger un profil invité déjà sauvegardé (potes réguliers). Stockés dans ProfileService avec type `guest`.

---

## 6. Gestes et interactions

### 6.1 Carte des gestes

| Geste | Zone | Action |
|-------|------|--------|
| Tap bouton +/- | LifeDisplay | ±1 PV |
| Long press bouton +/- | LifeDisplay | ±5 PV, maintenir = incrémentation continue (accélère après 2s) |
| Swipe horizontal | CounterStrip | Naviguer entre compteurs (PV → Poison → Energy → Custom...) |
| Double tap | LifeDisplay | Ouvre détail joueur (historique, commander damage, compteurs) |
| Long press (1s) | PlayerHeader | Active drag & drop de la zone |
| Long press (500ms) | Zone (hors boutons) | Menu radial |
| Tap | Compteur dans CounterStrip | ±1 sur ce compteur (boutons +/- apparaissent) |
| Tap | Adversaire compact (Focus) | Ouvre bottom sheet de l'adversaire |

### 6.2 Menu radial

S'ouvre autour du point de contact :
- **👑 Monarch** : toggle statut (active/désactive glow)
- **☠️ Éliminer** : confirmation → animation d'élimination
- **🔄 Reset** : remet compteurs à zéro (confirmation requise)

Fermeture : tap en dehors ou sélection d'une action.

### 6.3 Résolution de conflits de gestes

| Situation | Résolution |
|-----------|-----------|
| Long press sur bouton +/- | Incrémentation continue (pas drag/menu) |
| Long press sur header | Drag & drop (pas menu radial) |
| Long press ailleurs sur zone | Menu radial |
| Swipe horizontal sur CounterStrip | Navigation compteurs (pas scroll page) |
| Double tap sur LifeDisplay | Détail joueur |
| Double tap sur bouton +/- | Deux ±1 rapides |

---

## 7. Stats & Analytics

### 7.1 Données enrichies

GameHistoryItem enrichi avec : format, startingLife, playerCount, tag, winnerDeckName.
PlayerHistorySnapshot enrichi avec : type (owner/guest), deckName, commanderNames, tous compteurs finaux, isEliminated, eliminatedAt, eliminationRank.

### 7.2 Stats calculées (StatsProvider)

**Mes stats (owner)** : winrate global, winrate par deck, winrate par format, deck le plus joué, deck le plus winning (min 3 parties), distribution win methods, durée moyenne par format, streak actuelle et record.

**Stats par adversaire** : parties ensemble, mon winrate contre lui, son winrate, son commander le plus joué, dernier affrontement.

**Stats globales** : total parties, temps total joué, format préféré, joueur le plus fréquent, mois le plus actif.

### 7.3 Écran Stats

Onglet "📊 Stats" ajouté à côté de l'onglet "Historique" existant. Sections : Résumé, Par Deck, Par Adversaire, Par Format. Tap sur une entrée → détail complet.

---

## 8. Persistance et migration

### 8.1 Nouvelles tables Drift

```
game_formats          → id, name, starting_life, min/max_players, max_commanders, enabled_counters (JSON), is_built_in
counter_types         → id, name, icon, color, is_built_in, max_value
player_configs        → id, name, type, color_value, avatar_path, linked_deck_id
player_config_commanders → id, player_config_id (FK), name, scryfall_id, art_crop_url, sort_order
game_history          → enrichi : format_name, starting_life, player_count, tag, winner_deck_name (remplace le JSON)
game_history_players  → enrichi : type, deck_name, commander_names (JSON), tous compteurs, elimination data
```

### 8.2 Migration

1. **GameHistory JSON → Drift** : migration one-shot au premier lancement. Backup JSON conservé 2 versions.
2. **Profils SharedPreferences → player_configs** : migration des profils existants.
3. **Presets GameFormat** : seed au premier lancement, marqués `is_built_in = true`.
4. **État actif** : reste en mémoire (Riverpod `GameSessionNotifier`). Pas dans Drift.

### 8.3 Crash recovery

Snapshot JSON dans SharedPreferences (`active_game_snapshot`) mis à jour à chaque changement. Au lancement : si snapshot existe → propose "Reprendre la partie en cours ?". À la fin de partie → supprime snapshot, sauvegarde dans Drift.

---

## 9. Architecture technique

### 9.1 Approche

Refactoring progressif en 6 couches :
1. Nouveau modèle de données (GameSession, GameFormat, PlayerConfig)
2. Refactor PlayerZone → sous-widgets composables
3. Nouveau GameSetupFlow (Quick Start + Settings avancés)
4. Système d'animations (AnimationService + seuils + historique)
5. Layout adaptatif (LayoutStrategy + drag & drop)
6. Stats & Analytics (enrichir GameHistory + StatsProvider)

### 9.2 Widgets décomposés

Le PlayerZone monolithique (850+ lignes) est découpé en : PlayerHeader, LifeDisplay, LifeLog, CounterStrip, CriticalOverlay, EliminationOverlay, RadialMenu. Chaque widget est autonome et testable.

### 9.3 State management

- `GameSessionNotifier` (Notifier) : état complet de la partie active
- `GameSetupController` (existant, enrichi) : configuration avant lancement
- `PlayerZoneController` (existant, enrichi) : état par zone joueur
- `StatsProvider` (nouveau, AsyncNotifier) : stats calculées depuis Drift
- `GameHistoryNotifier` (existant, enrichi) : historique enrichi

### 9.4 Assets remplaçables

`AnimationAssetProvider` : couche d'abstraction pour les animations. MVP = Flutter natif (CustomPainter, AnimationController). Futur = swap vers Lottie/Rive/GIF pour Commander damage et Poison sans refactor des widgets consommateurs.
