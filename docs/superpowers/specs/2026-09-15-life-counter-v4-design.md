# Life Counter V4 — Design

**Date :** 2026-09-15
**Statut :** validé en brainstorming, prêt pour plan d'implémentation
**Remplace :** l'architecture V3 (`docs/superpowers/specs/2026-03-29-life-counter-v3-design.md`)

---

## 1. Pourquoi cette V4

Le life counter fonctionne et couvre déjà beaucoup : 2 à 8 joueurs, 6 formats, poison / énergie / taxe / dégâts de commandant, monarque, détection de mort, historique, dé, animations, profils avec artwork Scryfall.

Il souffre en revanche de quatre problèmes simultanés, tous confirmés par lecture du code :

**Dette structurelle.** `life_counter_page.dart` fait 1319 lignes et gère tout en `setState`. Elle instancie son `GameSessionController` à la main (ce n'est pas un `Notifier`), garde une copie locale `_session`, et la resynchronise manuellement après chaque mutation — une quinzaine de fois, avec des appels `restoreSession()` de contournement commentés « Bug 2 fix ».

**Un bug réel.** `_pendingDamage` et `_commanderDamageFlash` sont écrits par `playerId` mais lus par index d'affichage. Après un reorder, le badge de dégâts en attente et le flash de commander damage s'affichent sur la mauvaise zone.

**Du code écrit, testé, jamais branché.** `GameSetupController` (283 lignes, 704 lignes de tests), `PlayerZoneController` (241 lignes, 202 lignes de tests), `StatsTab` (308 lignes, 267 lignes de tests, accessible depuis aucune route), `CounterType` (85 lignes) et `setup/format_chip.dart` n'ont aucun consommateur en production. C'est le sédiment laissé par les cycles V2 puis V3, dont les plans affichent respectivement 0/59 et 0/75 tâches cochées.

**Des frustrations d'usage en partie réelle**, sur quatre points : la saisie des PV, le setup avant la partie, la lecture de l'état de la table, et le commander damage.

La V4 traite les quatre ensemble. Son principe directeur : **connecter le code déjà écrit et déjà testé plutôt que d'en écrire de nouveau.** La moitié du chantier est déjà payée.

### Approche écartée : reconstruire à côté

Construire une page V4 en parallèle puis basculer la route a été envisagé et rejeté. C'est exactement ce que le projet a fait deux fois — la V2 construite à côté puis abandonnée, la V3 qui l'a remplacée — et le résidu est précisément les ~1500 lignes de controllers orphelins décrites ci-dessus. Une troisième itération du même schéma produirait une troisième couche de sédiment.

La V4 procède donc **par strangulation in-place** : la page existante perd ses responsabilités une par une, l'application reste jouable à chaque étape, et rien n'est jeté.

---

## 2. Design d'interaction

### 2.1 Zone joueur — minimal gestuel

Le chiffre de PV occupe toute la zone. Il n'y a ni rangée de compteurs permanente, ni pastilles fixes.

- **Tap moitié gauche** : −1. **Tap moitié droite** : +1.
- **Maintien sur une moitié** : répétition accélérée. Couvre la tranche 3 à 8 points sans rien ouvrir.
- Le buffer de 2 secondes existant est conservé : les taps s'accumulent, un badge `+N` / `−N` s'affiche, l'application est différée.

### 2.2 Poignée conditionnelle

Une poignée occupe le bas de la zone. Son apparence dépend de l'état :

- **Tous compteurs à zéro** : un simple trait de 3 px. Il ne dit que « ça se tire ».
- **Au moins un compteur non nul** : la poignée s'épaissit en bandeau et affiche le résumé condensé (`☠ 3 · ⚔ 12 · ⚡ 2`).

Ce comportement a une propriété recherchée : **le changement de forme de la zone est lui-même un signal.** Le joueur voit du coin de l'œil qu'il lui est arrivé quelque chose, sans lire un chiffre.

**Contrainte de mise en page :** la hauteur du bandeau est réservée dès le départ et laissée vide à l'état calme. Le chiffre de PV ne se recale donc jamais en cours de partie — sans quoi l'affichage sautillerait à 8 joueurs sur petit écran.

### 2.3 Vue table

Un geste global à deux doigts replie la table en une liste compacte : une ligne par joueur, avec PV, compteurs non nuls, monarque et état d'élimination. Elle répond au moment précis où l'on veut lire toute la table — typiquement avant d'attaquer. On relâche, on revient au jeu.

### 2.4 Saisie de gros montants

Pas de pavé numérique custom : trop de state, de focus et de clavier système à gérer pour le bénéfice. Deux mécanismes se combinent, tous deux dans le **mode ajustement** (§2.5) :

- **Molette verticale** — le doigt glisse, le chiffre défile avec accélération proportionnelle à la distance.
- **Paliers ±5 / ±10** — quatre boutons pour composer un montant.

> **Réserve documentée :** si la précision de la molette s'avère insuffisante en usage réel, le clavier numérique **natif** reste accessible sans coût via `TextField(keyboardType: TextInputType.number)`, qui n'implique aucun clavier custom. Ce n'est pas au périmètre de la V4.

### 2.5 Mode ajustement et budget de gestes

La molette et le tiroir sont tous deux des glissements verticaux, comme la rotation de zone. Ils sont départagés par un **mode explicite** :

**Un appui long fait basculer la zone en mode ajustement.** Les paliers ±5/±10 apparaissent, le glissement pilote la molette dans toute la zone. On relâche, on sort du mode.

**Conséquence assumée :** l'appui long est aujourd'hui occupé par le menu radial (monarque / éliminer / reset). Le tap sur le nom est déjà pris par l'historique du joueur. **Le menu radial déménage donc dans le tiroir**, qui devient le panneau complet du joueur.

Carte des gestes après V4 :

| Geste | Action |
|---|---|
| Tap gauche / droite | −1 / +1 |
| Maintien sur − / + | Répétition accélérée |
| Appui long | Entrée en mode ajustement (molette + paliers) |
| Glissement depuis la poignée | Ouverture du tiroir |
| Glissement sur l'en-tête | Rotation de la zone |
| Deux doigts (global) | Vue table |

Le `RadialMenu` existant (161 lignes) est conservé comme composant ; seul son point d'invocation change.

### 2.6 Commander damage

**Attribution à la volée.** Pendant que le buffer de dégâts tourne, une rangée d'avatars adverses apparaît sous le chiffre : « de qui ? ». Un tap sur un avatar transforme ce dégât en commander damage de ce joueur. Aucun tap : c'est un dégât générique.

Le coût est donc d'**un seul tap, et seulement quand il s'agit de commandant**. Le mécanisme corrige au passage le vrai défaut du système actuel, où retirer les PV et enregistrer le commander damage sont deux actions séparées qu'on oublie de synchroniser.

**Déclenchement :** uniquement dans les formats où le commander damage existe — Commander, Duel Commander, Oathbreaker, Brawl. En Standard et en Custom sans commander damage, la rangée n'apparaît jamais. La condition se lit sur `GameFormat.maxCommanderDamage`.

**Filet de rattrapage.** Le tiroir contient en permanence la grille de tous les adversaires avec leurs `±`, pour corriger une erreur ou saisir à froid. Les PV suivent automatiquement. Ce n'est pas une fonctionnalité supplémentaire : c'est le contenu naturel du tiroir.

> **Écarté :** glisser l'avatar de l'attaquant sur sa victime depuis la vue table. Séduisant, mais les zones sont pivotées dans tous les sens en partie réelle, et le geste n'existerait que dans la vue table — donc jamais pendant le jeu normal.

### 2.7 Contenu du tiroir

Le tiroir rassemble tout ce qui n'est pas le PV :

1. Compteurs : poison, énergie, taxe de commandant, plus les compteurs personnalisés (§3.5).
2. Grille de commander damage reçu, un adversaire par ligne avec `±`.
3. Actions : monarque, éliminer, réinitialiser les compteurs (l'ancien menu radial).

### 2.8 Lancement d'une partie

**Reprise en un tap.** L'écran d'entrée propose d'abord de rejouer la dernière table telle quelle : même format, mêmes joueurs, PV remis à neuf. Le setup complet devient l'option secondaire. Aucune gestion n'est demandée à l'utilisateur — la dernière partie est déjà persistée en `GameHistoryItem`.

**Setup inline.** Le modal de 863 lignes disparaît. La table *est* l'écran de configuration : le format en barre haute, chaque case de joueur se remplissant sur place, un « + » pour ajouter. On commence à jouer sans transition.

> **Écarté :** les tables nommées et enregistrées (« Jeudi soir », « Duel vs Marie »). Elles demandent à l'utilisateur de gérer des presets pour un bénéfice que la reprise en un tap apporte gratuitement dans la quasi-totalité des cas. Elles restent faciles à ajouter plus tard, la reprise ayant déjà créé la notion de table réutilisable.

---

## 3. Architecture

### 3.1 Gestion d'état

`GameSessionController` devient un `Notifier<GameSession?>` Riverpod exposé par `gameSessionControllerProvider` (le provider existe déjà dans `lib/providers/game_session_provider.dart` mais n'est pas consommé).

La page perd :
- sa copie locale `_session` ;
- ses ~15 `setState(() => _session = _controller.session)` ;
- ses appels `restoreSession()` de contournement (undo d'élimination, reorder, changement de couleur, changement de skin).

**Tout l'état transitoire est clé par `playerId`, jamais par index d'affichage.** L'index n'est plus qu'une position de rendu. C'est ce qui fait disparaître le bug du badge et du flash après reorder — mécaniquement, pas par correctif ponctuel.

### 3.2 Défauts corrigés par le passage au notifier

| Défaut actuel | Résolution |
|---|---|
| Badge `_pendingDamage` et flash commander sur la mauvaise zone après reorder | État clé par `playerId` (§3.1) |
| `GameSession.duration` / `startedAt` jamais renseignés ; durée perdue au redémarrage malgré la restauration du snapshot | La durée vit dans la session, plus dans le `State` |
| Toggle « Timer de partie » du setup jamais transmis à la page — réglage sans effet | **Non corrigé par le lot 1.** Reporté au lot 4 (§4) : le réglage n'est câblé que là où `GameSetupModal` sera remplacé par le setup inline (§2.8) — le câbler à travers le modal actuel, voué à la suppression, serait du travail jeté. |
| `_calculateDefaultRotation(int id, int totalPlayers)` ignore ses deux paramètres et retourne toujours `0` | Réécrit avec une vraie logique par nombre de joueurs, ou supprimé au profit des presets d'orientation existants |
| `reorderPlayers` du modèle contourné par une permutation physique de la liste | Le reorder passe par le modèle ; `playerOrder` devient la source de vérité |
| `_saveSnapshot()` appelé en I/O synchrone après chaque tap | Écriture débattue (debounce) sur le cycle du buffer de dégâts |

### 3.3 Découpe

`life_counter_page.dart` : **1319 → ~250 lignes** d'assemblage. Le reste part en controllers dédiés, chacun testable isolément :

- **Buffer de dégâts** — accumulation, fenêtre de 2 s, attribution CD1.
- **Détection de mort** — PV ≤ 0, poison ≥ `maxPoison`, commander damage ≥ 21 d'une source ; overlay de confirmation ; élimination ; undo.
- **Fin de partie** — dernier survivant, choix manuel du gagnant, écriture de l'historique.

`PlayerZone` (734 lignes) est branchée sur `PlayerZoneController` (déjà écrit, déjà testé). Elle perd son `setState` et son `enum CounterMode` dupliqué — l'énumération de `player_zone_controller.dart` devient la seule.

`GameSetupModal` (863 lignes) est **remplacée**, pas réécrite : le setup inline (§2.8) se câble sur `GameSetupController` (déjà écrit, 704 lignes de tests).

`StatsTab` (308 lignes, déjà testée) reçoit enfin une route.

`Player` (modèle legacy mutable, muté en place par `PlayerZone`) est supprimé au profit de `PlayerState` immuable. C'est aujourd'hui une double source de vérité.

`setup/format_chip.dart` est soit utilisé par la barre de formats du setup inline, soit supprimé.

### 3.4 Ce qui ne bouge pas

Sont conservés tels quels : `AdaptiveGrid` et les presets d'orientation, `EliminationOverlay` et `CrackEffect`, `CriticalOverlay`, `AnimationService`, `DiceRollDialog`, `DamageHistorySheet`, `PlayerHistorySheet`, `DeathConfirmationOverlay`, `RadialMenu` (seul son point d'invocation change), le wakelock et le mode immersif, les profils Owner/Guest et la sélection d'artwork Scryfall, la persistance Drift de l'historique et le snapshot de reprise après crash.

### 3.5 Compteurs personnalisés

`CounterType` est modélisé et testé mais inutilisé : les compteurs sont manipulés par clés `String` codées en dur (`'poison'`, `'energy'`, `'commander_tax'`), et `GameSession.activeCounterIds` / `customCounterIds` ne sont jamais lus par l'UI.

La V4 branche `CounterType` et rend les compteurs personnalisés créables depuis le tiroir. Ce travail arrive **en dernier** : le tiroir doit exister d'abord pour leur donner un endroit où vivre.

---

## 4. Séquençage

Quatre lots, plus un cinquième. Chacun est mergeable seul, et l'application reste jouable à chaque étape.

**Lot 1 — Socle.** `Notifier` Riverpod, état clé par `playerId`, bug de reorder, durée et timer, débounce du snapshot. Aucun changement visible pour le joueur. **Ce lot comble d'abord le trou de tests** (§5) : c'est le filet qui rend les lots suivants sûrs.

**Lot 2 — Zone joueur.** Minimal gestuel, poignée conditionnelle, molette, paliers, mode ajustement, menu radial déplacé dans le tiroir, branchement de `PlayerZoneController`.

**Lot 3 — Commander damage et tiroir.** Attribution à la volée, grille du tiroir, vue table.

**Lot 4 — Setup.** Reprise en un tap, setup inline, suppression de `GameSetupModal`, branchement de `GameSetupController`, route vers `StatsTab`. **Inclut le câblage du toggle « Timer de partie »**, délibérément reporté depuis le lot 1 (§3.2) : câbler ce réglage à travers le modal actuel, voué à la suppression par ce même lot, aurait été du travail jeté.

**Lot 5 — Compteurs personnalisés.** Branchement de `CounterType`, création depuis le tiroir.

---

## 5. Tests

L'état actuel : 18 fichiers, ~2800 lignes — mais une part importante couvre du code non branché (704 lignes pour `GameSetupController`, 267 pour `StatsTab`, 202 pour `PlayerZoneController`). Ces tests deviennent utiles dès que la V4 branche leur cible.

**Le trou à combler, aujourd'hui sans aucun test :** `life_counter_page.dart` (les 1319 lignes d'orchestration — buffer, détection de mort, dernier survivant, presets d'orientation, fin de partie), `player_zone.dart`, `game_setup_modal.dart`, `game_history_page.dart`, `game_history_detail_page.dart`, `game_history_service.dart`, `game_history_provider.dart`, `stats_provider.dart`. Aucun test d'intégration de partie complète n'existe.

Le lot 1 écrit les tests d'orchestration **avant** l'extraction, pour que la découpe soit vérifiable plutôt que supposée.

Exigences par lot :
- Chaque controller extrait est testé isolément.
- Un test d'intégration bout-en-bout couvre une partie complète : setup → dégâts → commander damage → élimination → victoire → historique.
- Un test de non-régression couvre explicitement le bug corrigé : reorder puis vérification que badge et flash suivent le bon joueur.

---

## 6. Points à calibrer en usage réel

Ces réglages ne se décident pas sur maquette :

- **Sensibilité et accélération de la molette.** Le compromis vitesse / précision doit être éprouvé sur de gros montants.
- **Durée de l'appui long** d'entrée en mode ajustement : assez court pour ne pas frustrer, assez long pour ne pas se déclencher sur un tap appuyé.
- **Fenêtre du buffer de dégâts** : les 2 s actuelles n'ont jamais été validées, et la rangée d'attribution CD1 vit dans cette fenêtre.
- **Lisibilité de la poignée conditionnelle** à 8 joueurs sur petit écran.

---

## 7. Hors périmètre

- Tables nommées et enregistrées (§2.8).
- Glisser-déposer attaquant → victime (§2.6).
- Pavé numérique, custom ou natif (§2.4).
- Toute modification du système de profils, de la sélection d'artwork Scryfall, ou de la persistance Drift de l'historique.
