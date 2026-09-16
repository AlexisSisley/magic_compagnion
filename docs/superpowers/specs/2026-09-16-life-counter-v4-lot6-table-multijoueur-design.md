# Life Counter V4 — Lot 6 : Table multijoueur — Design

**Date :** 2026-09-16
**Statut :** validé en brainstorming, prêt pour plan d'implémentation
**Complète :** `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md`
**Ordre d'exécution :** après le lot 3, **avant le lot 4** (voir §5.1)

---

## 1. Pourquoi ce lot

La V4 traite quatre frustrations d'usage. Trois d'entre elles couvrent déjà, pour les
parties à 4 joueurs et plus, l'essentiel du problème :

| Frustration à 4+ joueurs | Traitée par |
|---|---|
| Dégâts de commandant ingérables (12 relations à 4 joueurs) | Lot 3 — attribution à la volée + grille de rattrapage dans le tiroir |
| Trop d'informations secondaires dans une zone minuscule | Lot 2 — poignée conditionnelle et tiroir |
| Taps ratés | Lot 2, partiellement — le minimal gestuel élargit les cibles, mais ne crée pas de surface |

La quatrième ne l'est nulle part. La spec V4 §3.4 gèle explicitement `AdaptiveGrid` et
les presets d'orientation : « sont conservés tels quels ».

Or `AdaptiveGrid` n'applique qu'une seule règle, codée en dur : moitié haute des joueurs
retournée à 180°, moitié basse à l'endroit. C'est un modèle **face-à-face**. Il est juste
à 2 joueurs et devient faux dès 4 autour d'un téléphone posé à plat au centre de la table —
le mode d'usage réel confirmé par l'utilisateur.

Le contournement actuel est manuel : `_showOrientationPresets` (`life_counter_page.dart`)
demande au joueur de choisir lui-même ses rotations, partie après partie. Et le défaut
calculé est inexistant — la spec V4 §3.2 relève que `_calculateDefaultRotation(int id,
int totalPlayers)` ignore ses deux paramètres et retourne toujours `0`.

Ce lot traite les deux moitiés du problème restant : **la géométrie** (qui est assis où,
dans quel sens) et **la densité** (ce qu'une zone affiche quand elle n'a plus qu'un
sixième d'écran).

---

## 2. Le modèle de sièges

### 2.1 Séparer la position de la rotation

`AdaptiveGrid` mélange aujourd'hui deux décisions : *où* est une zone, et *dans quel sens*
elle est. Les deux sortent de la même règle figée. Ce lot les sépare.

Une fonction pure décide :

```
List<TableSeat> seatsFor(int playerCount)
```

Elle retourne un siège par position de `playerOrder`. Un `TableSeat` porte un côté de
table (`top`, `bottom`, `left`, `right`), la part que le joueur occupe sur ce côté, et la
rotation qui en découle.

`AdaptiveGrid` devient alors un **moteur de rendu** : elle place les zones selon les sièges
qu'on lui donne et ne décide plus rien.

### 2.2 Carte des sièges

| Joueurs | Disposition | Rotations |
|---|---|---|
| 2 | haut / bas | 180° / 0° |
| 3 | haut ×1 / bas ×2 | 180° / 0° / 0° |
| **4** | **un par côté** | **haut 180°, droite 270°, bas 0°, gauche 90°** |
| **5** | **haut ×2, droite ×1, bas ×1, gauche ×1** | par côté |
| **6** | **haut ×2, droite ×1, bas ×2, gauche ×1** | par côté |
| 7 | haut ×3, bas ×4 (rangées simples, règle actuelle) | 180° / 0° |
| 8 | haut ×4, bas ×4 (sous-grille 2×2) | 180° / 0° |

### 2.3 Trois conséquences assumées

**Les sièges latéraux tournent à 90° et 270°.** Leur zone est physiquement haute et
étroite, mais le joueur la lit depuis le côté de la table : dans son repère, elle est large
et basse. Le contenu est donc rendu dans le repère du joueur, pas dans celui de l'écran.
C'est exactement ce que fait déjà `RotatedBox(quarterTurns: 2)` pour la moitié haute,
étendu aux quarts 1 et 3.

**Au-delà de 6 joueurs, on repasse en face-à-face.** Quatre côtés ne suffisent plus, et des
sièges latéraux partagés à trois deviendraient illisibles. La sous-grille 2×2 actuelle
reste la bonne réponse à 7 et 8 : `seatsFor` la retourne, et le code de rendu existant est
conservé plutôt que réécrit.

**Les sièges donnent un défaut, jamais une contrainte.** `seatsFor` fixe la rotation
*initiale* de chaque joueur au démarrage de la partie. Si le joueur la change ensuite — par
les presets d'orientation ou par le glissement sur l'en-tête — sa valeur est écrite dans
`PlayerState.quarterTurns`, persistée, et **gagne sur le défaut du siège**.

Les presets d'orientation ne disparaissent donc pas : ils changent de statut, de mode
normal à réglage de secours.

### 2.4 Branchement sur l'existant

Aucun champ de modèle n'est ajouté :

- `PlayerState.quarterTurns` existe déjà (`game_session.dart:38`) et est persisté.
- `playerOrder` est, depuis le lot 1, la seule source de vérité de la disposition
  (`game_session.dart:122`).

`_calculateDefaultRotation` est **supprimée**, remplacée par `seatsFor`. La spec V4 §3.2
laissait le choix entre la réécrire et la supprimer ; ce lot tranche.

---

## 3. Le contrat de densité

La géométrie règle où regarder. Elle ne règle pas qu'à 6 joueurs, chaque zone ne fait plus
qu'un sixième d'écran.

### 3.1 Le cran se décide sur la taille mesurée

**Pas sur le nombre de joueurs.** Six zones sur une tablette de 11 pouces sont plus
confortables que deux sur un petit téléphone ; indexer la densité sur `playerCount` se
tromperait dans les deux sens.

`PlayerZone` mesure sa propre boîte (`LayoutBuilder`) et choisit son cran via une seconde
fonction pure :

```
DensityTier tierFor(Size sizeInPlayerFrame)
```

La taille est exprimée **dans le repère du joueur**, c'est-à-dire après la rotation du
siège. Sans cela, un siège latéral — haut et étroit à l'écran, large et bas pour son
joueur — serait systématiquement mal classé.

### 3.2 Les trois crans

| Cran | Typiquement | Affichage |
|---|---|---|
| **Confort** | 2-3 joueurs | PV géant, nom, **tous les compteurs actifs du format, même à zéro** — emplacement stable et prévisible |
| **Compact** | 4-6 joueurs | PV dominant, nom réduit, et **uniquement la poignée conditionnelle du lot 2** : elle ne s'épaissit qu'en présence d'un compteur non nul |
| **Minimal** | 7-8 joueurs, ou siège latéral sur petit écran | **PV seul.** Le nom se réduit à la pastille de couleur. Aucun compteur ne perce |

### 3.3 La couche d'alerte est hors crans

Un seuil critique s'affiche à **tous** les crans, y compris minimal :

- vie ≤ 5 ;
- poison ≥ `maxPoison − 2` ;
- 18 dégâts de commandant ou plus d'une même source.

C'est la seule chose autorisée à percer en cran minimal, précisément parce que c'est la
seule qu'on ne peut pas se permettre de rater. Le rendu réutilise `CriticalOverlay`, que la
spec V4 §3.4 conserve.

### 3.4 Le cran ne change jamais en cours de partie

Il est figé au démarrage et ne se recalcule qu'à un changement du nombre de joueurs ou
d'une rotation. Un cran qui basculerait parce qu'un compteur vient d'apparaître ferait
sauter tout l'affichage — exactement ce que le lot 2 évite déjà en réservant dès le départ
la hauteur de la poignée (spec V4 §2.2).

Le contrat de densité étend ce principe : **c'est le cran qui décide de la hauteur
réservée**, et une fois décidée, elle ne bouge plus.

### 3.5 Le seul point de contact avec le lot 2

Le lot 2 écrit `ConditionalHandle` avec une `reservedHeight` constante. Ce lot la dérive du
cran — **dont zéro en cran minimal**, où la poignée disparaît entièrement : le tiroir s'y
ouvre par glissement depuis le bas de la zone, sans affordance visible.

C'est un paramètre ajouté, pas un comportement changé, et c'est le seul fichier du lot 2
que ce lot touche. Il se fait après le merge du lot 2, jamais pendant.

---

## 4. Amendements à la spec V4

Deux passages de `2026-09-15-life-counter-v4-design.md` deviennent faux et sont corrigés
dans le fichier lui-même, pour qu'aucun des deux documents ne contredise l'autre :

**§3.4 — « Ce qui ne bouge pas ».** `AdaptiveGrid` en sort : elle perd sa règle de décision
et devient un moteur de rendu. Les presets d'orientation y restent, avec leur changement de
statut explicité (réglage de secours, plus mode normal).

**§3.2 — tableau des défauts corrigés.** La ligne `_calculateDefaultRotation` est tranchée :
supprimée au profit de `seatsFor`, et non réécrite.

---

## 5. Séquençage

### 5.1 Position dans la V4

**Lot 2 (en cours) → lot 3 → lot 6 → lot 4 → lot 5.**

Le numéro suit l'ordre d'écriture des specs, pas l'ordre d'exécution. Deux raisons à cette
position :

**Avant le lot 4**, parce que le lot 4 fait de la table elle-même l'écran de configuration
(spec V4 §2.8, setup inline) : chaque case de joueur se remplit sur place. Si les sièges
n'existent pas encore, le lot 4 câble son setup sur la géométrie face-à-face, et il faut le
recâbler juste après.

**Après le lot 3**, parce que le lot 3 modifie `life_counter_page.dart` en profondeur
(attribution à la volée, vue table). Passer après lui évite que deux lots se disputent le
même fichier.

### 5.1.1 Prérequis : partir de la surface de gestes corrigée

La tâche 3 du lot 2 a livré trois défauts Critical sur la gestion des gestes, tous
**invisibles en test widget** : un appui long qui émettait un flux de points de vie
fantômes, un appui long annulé au moindre pixel de mouvement alors que le reconnaisseur
Flutter tolère `kTouchSlop` (18 px), et un glissement inerte seulement dans le faux temps
de `flutter_test`.

Le lot 6 hérite de cette surface de gestes : il la fait traverser des rotations de 90° et
270°. Il ne démarre donc **pas avant que ces corrections soient mergées**. Repartir de la
version défectueuse ferait empiler une transformation géométrique sur un reconnaisseur
faux, et rendrait tout diagnostic ultérieur impossible à attribuer.

### 5.2 Découpe en tâches

Chaque tâche est mergeable seule et laisse l'application jouable.

1. **`TableSeat` et `seatsFor`.** Pure, sans UI, entièrement testée avant d'avoir le moindre
   consommateur.
2. **`AdaptiveGrid` en moteur de rendu**, piloté par les sièges. À ce stade elle reproduit
   *exactement* le rendu actuel à 2, 3, 7 et 8 joueurs. C'est le test de non-régression qui
   autorise la suite.
3. **Sièges latéraux à 4-6 joueurs**, et suppression de `_calculateDefaultRotation`.
4. **`tierFor` et le contrat de densité** dans `PlayerZone`, avec la `reservedHeight` de
   `ConditionalHandle` dérivée du cran.
5. **La couche d'alerte hors crans**, branchée sur `CriticalOverlay`.

---

## 6. Tests

L'essentiel de la couverture vit dans les deux fonctions pures, sans monter un seul widget :

- `seatsFor` : les 7 dispositions (2 à 8 joueurs) verrouillées en tests de table.
- `tierFor` : les frontières entre crans, y compris le cas du siège latéral dont la taille
  est exprimée dans le repère du joueur.

S'y ajoutent quatre tests de widget :

- **Non-régression de la tâche 2** : le rendu à 2, 3, 7 et 8 joueurs est inchangé.
- **Un test par cran** : aucun compteur ne perce en cran minimal, et la couche d'alerte y
  perce bien.
- **Priorité de la rotation manuelle** : une rotation choisie par le joueur survit et gagne
  sur le défaut du siège.
- **Stabilité du cran** : il ne bascule pas quand un compteur passe de zéro à non nul.

**Dépendance au test d'intégration V4.** La spec V4 §5 exige un test bout-en-bout de partie
complète. S'il existe au moment de ce lot, il doit tourner **à 4 joueurs** — sinon il valide
une géométrie que plus personne n'utilise.

### 6.1 Ce que les tests widget ne prouveront pas ici

La tâche 3 du lot 2 a produit trois défauts Critical tous verts en test widget (§5.1.1). Le
lot 6 aggrave ce risque plutôt qu'il ne l'évite, et il faut l'écrire avant de commencer
plutôt que de le découvrir en revue.

**Le piège propre à ce lot : le tap sous rotation.** Un tap sur un siège latéral traverse un
`RotatedBox` avant d'atteindre les moitiés de `LifeDial`. Les coordonnées sont transformées :
la moitié « gauche » dans le repère du joueur est la moitié « basse » à l'écran. Un test qui
tape au centre-gauche du rectangle rendu **passera que la transformation soit correcte ou
inversée** — il ne discrimine rien. C'est structurellement le même défaut que ceux du lot 2,
appliqué à la géométrie.

Deux exigences en découlent :

- **Le test de tap sous rotation se formule dans le repère du joueur, pas de l'écran.** Pour
  chacune des quatre orientations, taper la moitié « décrément » telle que le joueur la voit
  et vérifier que le delta est bien négatif. Une orientation dont les deux moitiés sont
  inversées doit faire **échouer** le test — si ce n'est pas le cas, le test est à jeter.
- **Une vérification sur appareil réel à 4 joueurs est un critère de sortie du lot**, pas une
  politesse. Les deux fonctions pures (`seatsFor`, `tierFor`) sont, elles, entièrement
  couvertes en test de table : c'est précisément parce que la géométrie de rendu et les
  gestes ne le sont pas que cette vérification manuelle est nécessaire.

### 6.2 Trois façons dont un test de geste ment, toutes observées au lot 2

Le lot 2 les a rencontrées une par une. Elles sont indépendantes : un test peut être juste
sur l'une et faux sur les deux autres. Aucun test de geste du lot 6 n'est considéré comme
acquis tant que les trois ne sont pas vérifiées.

**1. Le geste est simulé au lieu d'être joué.** Appeler le callback directement plutôt que
`tester.tap()`. C'est ce qui a masqué pendant tout le cycle V3 le fait qu'`EliminationOverlay`
absorbait *tous* les gestes d'une zone éliminée, rendant l'annulation d'élimination
injoignable. Le bug n'a été révélé que par le remplacement de l'appel direct par un vrai tap.

**2. Le geste est joué au mauvais endroit du repère.** Le piège propre à ce lot (§6.1) :
sous rotation de 90° ou 270°, un test qui vise le rectangle écran passe quelle que soit la
transformation.

**3. Le geste est joué au bon endroit, mais mal livré.** L'accélération de la molette était
inerte sur appareil parce que les tests livraient 130 px en un seul appel, là où un doigt en
livre une dizaine de petits incréments. **Tout test de glissement du lot 6 livre ses
`PointerMoveEvent` en incréments réalistes**, jamais en un déplacement unique.

**Conséquence sur la pile de composition.** Le cas `EliminationOverlay` n'est pas une
anecdote : c'est un widget qui absorbe silencieusement les gestes de la couche en dessous.
Le lot 6 insère précisément de nouvelles couches dans cette pile — les `RotatedBox` des
sièges latéraux, et la couche d'alerte hors crans du §3.3 qui doit percer en cran minimal.
**Chaque couche ajoutée par ce lot est vérifiée non-absorbante** : un tap qui la traverse
doit atteindre `LifeDial`, et c'est un test, pas une relecture.

---

## 7. Points à calibrer en usage réel

Ces réglages ne se décident pas sur maquette, et sont délibérément laissés ouverts :

- **Les seuils en pixels** entre les trois crans de densité.
- **La lisibilité d'un siège latéral en cran minimal** sur petit écran — c'est le cas
  limite le plus exposé de tout ce lot.
- **La découverte du tiroir en cran minimal**, où la poignée n'a plus d'affordance visible.

---

## 8. Hors périmètre

- Toute synchronisation multi-appareils (un téléphone par joueur).
- Les tables nommées et enregistrées — déjà écartées par la spec V4 §2.8.
- Un siège « spectateur », et un mode 2v2 en équipes. La géométrie des sièges les rendrait
  faciles à ajouter plus tard ; ce ne sont pas des besoins actuels.
