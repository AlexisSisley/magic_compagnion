# Life counter — table multijoueur, v2

**Date :** 2026-09-17
**Statut :** validé sur maquette par l'utilisateur, prêt pour un plan d'implémentation
**Maquette de référence :** https://claude.ai/artifact/UvvoPP5qqB3fF79F9Q81XD
**Remplace :** `2026-09-16-life-counter-v4-lot6-table-multijoueur-design.md` (livré, puis reverté)

---

## 0. Pourquoi cette spec existe

Le lot 6 a été livré avec 1028 tests verts, `flutter analyze` propre, deux revues de code
et une re-revue scopée. Il était **inutilisable**, et l'utilisateur l'a vu en trente
secondes sur une build Windows.

La cause n'est pas un défaut de rigueur. C'est un défaut de nature : toute la rigueur
portait sur des propriétés que les tests savent mesurer — des contraintes, des rotations,
des migrations — et aucune sur la seule propriété qui comptait, la lisibilité à l'écran.
`AdaptiveGrid` donnait 30 % de la largeur à chaque colonne latérale. Sur un écran large,
deux joueurs mangeaient 60 % de la surface, et les 40 % restants devaient contenir les
deux moitiés **et** la barre d'actions. Cette barre étant une `Row` scrollable de huit
icônes, elle se réduisait silencieusement à ses deux premières : le choix du nombre de
joueurs et les options de jeu partaient hors champ sans qu'aucune affordance ne le signale.

**Règle qui sort de cet échec, et qui lie cette spec :**

> Un lot qui déplace des pixels ne se clôt pas sur des tests verts. Il se clôt sur une
> capture d'écran regardée par un humain. Les tests prouvent qu'on a construit ce qu'on a
> décrit ; ils ne prouvent jamais qu'on a décrit la bonne chose.

Cette spec a donc été validée sur maquette interactive **avant** d'exister, et son
§7 fait de la vérification visuelle un critère de sortie bloquant, pas une formalité.

---

## 1. Problème et intention

L'appareil est **posé à plat au centre de la table**, les joueurs assis autour. À partir
de 4 joueurs, la disposition face-à-face historique (moitié haute pivotée à 180°, moitié
basse à l'endroit) impose à deux personnes au moins de lire de travers.

Intention : que **chaque joueur lise son compteur à l'endroit depuis sa chaise**, sans que
cela coûte l'accès aux actions ni la lisibilité des zones.

Le lot 6 attaquait le bon problème. Son arithmétique était fausse.

---

## 2. Modèle de sièges

Inchangé par rapport au lot 6 — c'est la partie qui était juste, et elle est récupérable
telle quelle depuis la branche `lot6-archive` (commit `feeb53f`).

```dart
enum TableSide { top, right, bottom, left }

class TableSeat {
  const TableSeat({required this.side, required this.slot, required this.slotCount});
  final TableSide side;
  final int slot;
  final int slotCount;

  int get quarterTurns => switch (side) {
        TableSide.bottom => 0,
        TableSide.left   => 1,
        TableSide.top    => 2,
        TableSide.right  => 3,
      };
}

List<TableSeat> seatsFor(int playerCount);
```

Répartition :

| Joueurs | Sièges | Rotations (`quarterTurns`) |
|---|---|---|
| 2 | bas, haut | 0, 2 |
| 3 | haut, bas, bas | 2, 0, 0 |
| 4 | haut, droite, bas, gauche | 2, 3, 0, 1 |
| 5 | haut, haut, droite, bas, gauche | 2, 2, 3, 0, 1 |
| 6 | haut, haut, droite, bas, bas, gauche | 2, 2, 3, 0, 0, 1 |
| 7-8 | repli face-à-face | 2…, 0… |

### 2.1 La rotation n'a qu'un seul propriétaire

`PlayerZone` applique `PlayerState.quarterTurns`, et lui seul. `AdaptiveGrid` est
**purement positionnelle** : elle ne contient aucune `RotatedBox`.

Cette règle n'est pas esthétique. Au lot 6, la grille pivotait *et* le siège écrivait sa
rotation dans l'état : 180° + 180° = 360°, table inversée, **tous les tests verts**. Un
test verrouille donc l'absence de `RotatedBox` sous `AdaptiveGrid`.

### 2.2 Convention de rotation

`RotatedBox` tourne dans le **sens horaire**. Un quart de tour envoie donc le bord
**gauche** de l'enfant sur le bord **haut** de l'écran.

| `quarterTurns` | Siège | Où se trouve la moitié « décrément » |
|---|---|---|
| 0 | bas | `dx` inférieur (à gauche) |
| 1 | gauche | `dy` **inférieur** (en haut) |
| 2 | haut | `dx` supérieur (à droite) |
| 3 | droite | `dy` **supérieur** (en bas) |

Vérification par le sens physique : un joueur assis à l'ouest regarde vers l'est ; sa main
gauche pointe vers le nord, soit le haut de l'écran. Cohérent.

Cette table a été dérivée indépendamment trois fois et une consigne écrite à son sujet
était fausse. **Elle se teste géométriquement** (§6.2), jamais par un tap ciblé par clé.

---

## 3. Règle d'abordabilité des colonnes latérales

**C'est le cœur de cette spec, et ce que le lot 6 avait faux.**

Une colonne latérale n'existe que si l'écran peut la payer. Deux conditions, toutes deux
nécessaires :

### 3.1 Condition de forme

```
sidesAllowed = (width > height) || (min(width, height) >= 600)
```

En clair : **paysage, ou petit côté d'au moins 600 px logiques.**

| Appareil | Dimensions | Colonnes latérales |
|---|---|---|
| Téléphone portrait | 390 × 844 | **non** — face à face strict |
| Téléphone paysage | 844 × 390 | oui |
| Tablette portrait | 820 × 1180 | oui |
| Tablette paysage | 1180 × 820 | oui |

Décision utilisateur, prise sur maquette : sur un téléphone en portrait, une colonne
latérale donne une bande verticale trop étroite pour être lisible même quand elle passe le
plancher numérique. Le seuil de 600 px est celui qui reproduit exactement ce jugement sur
les quatre formats testés.

### 3.2 Condition de budget

Même quand la forme l'autorise, la colonne doit tenir **en entier** :

```
kSideColumnNeed = kZoneHeightFloor + 26   // 96 px
centreNeed      = barKind == centre ? 324 : 160
sidesAffordable = width - 2 * kSideColumnNeed >= centreNeed
```

`324 = 8 actions × (36 + 4) + 4`, la largeur naturelle de la bande d'actions.

### 3.3 En cas de refus : on renonce, on ne rétrécit pas

Si l'une des deux conditions échoue, **il n'y a pas de colonne latérale du tout** et la
disposition repasse en face-à-face strict pour ce nombre de joueurs.

C'est la différence de fond avec le lot 6, qui rabotait la colonne jusqu'à 33 px plutôt
que d'y renoncer. Une bande de 33 px passe tous les tests de contrainte et n'affiche rien.

### 3.4 Largeur retenue quand les colonnes existent

```dart
sideWidth = max(kSideColumnNeed, min(width * 0.17, (width - centreNeed) / 2));
```

`0.17` est un réglage esthétique pour les grands écrans, **jamais** la garantie du
plancher : celle-ci est portée par `max(kSideColumnNeed, …)`, en dur.

---

## 4. Barre d'actions

### 4.1 Elle n'est jamais la variable d'ajustement

Au lot 6, la barre vivait dans la colonne centrale et encaissait tout ce que les colonnes
latérales lui laissaient. Elle porte la navigation de la feature : le nombre de joueurs,
les options, la remise à zéro. **Elle est servie en premier** ; c'est la géométrie des
zones qui cède, pas elle.

### 4.2 Deux formes selon l'appareil

```
barKind = min(width, height) < 600 ? hub : centre
```

- **Hub central (téléphone)** — un bouton rond de 54 px au centre de la table, qui ouvre
  une feuille contenant les huit actions. Il ne coûte que son diamètre, donc il ne prend
  jamais la place des zones sur petit écran, et une feuille est lisible quelle que soit la
  chaise depuis laquelle on l'ouvre.
- **Bande centrale (tablette)** — la bande horizontale actuelle, entre les deux moitiés,
  qui dispose de la largeur nécessaire à ses huit actions.

### 4.3 Interdiction de dégradation silencieuse

La bande ne doit **jamais** défiler horizontalement pour cacher des actions. Si les huit
n'entrent pas dans la largeur disponible, c'est le hub qui est rendu. Le comportement
actuel — `SingleChildScrollView` qui rogne sans le dire — est la mécanique exacte du bug
et disparaît.

---

## 5. Zone joueur : le mode ajustement

### 5.1 Le geste retenu

Appui long → les paliers −10 / −5 / +5 / +10 apparaissent → on **glisse** sur celui qu'on
veut → on **relâche** pour l'appliquer. Relâcher hors des paliers n'applique rien et ferme
le mode.

**Le mode ne survit pas au doigt.** Un seul geste continu, du doigt posé au doigt levé.

### 5.2 Ce que ça corrige

Le mode actuel persiste après le relâchement et se ferme par un tap ailleurs. La rangée de
paliers étant une `Row` de quatre `Expanded`, elle occupe toute la largeur en bas de la
zone — exactement là où le pouce retombe. L'utilisateur, en voulant fermer, touche un
palier et modifie ses PV par accident.

Avec la fermeture au relâchement, le problème disparaît **par construction** : il n'y a
plus rien d'armé à fermer.

### 5.3 L'objection du lot 2, et pourquoi elle tombe

La spec V4 §2.5 avait été amendée exprès pour **écarter** « relâcher ferme », au motif que
les paliers deviendraient inatteignables.

Cette objection ne vaut que s'il faut **lever le doigt pour taper**. Avec un glissé-relâché,
les paliers restent atteignables sans jamais rompre le contact. L'amendement du lot 2 est
donc levé, et le présent paragraphe le remplace.

**Risque assumé, à éprouver au pouce (§7) :** atteindre une cible de 30 px de haut en bout
de course d'un appui long, sans lever, n'est pas prouvé confortable. Si l'usage réel le
dément, le repli est la §5.4 seule, avec le mode persistant conservé.

### 5.4 Rangée resserrée

Les quatre paliers n'occupent plus toute la largeur : ils sont resserrés au centre, avec
une marge libre de chaque côté (≈ 18 % de la largeur de la zone par côté).

Cette décision tient **indépendamment** de la §5.1 : elle réduit la surface d'erreur dans
les deux modèles de geste.

---

## 6. Contrat de densité

Récupérable depuis `lot6-archive` (`density_tier.dart`), avec une correction de nommage.

```dart
enum DensityTier { comfort, compact, minimal }

const double kZoneHeaderHeight = 40.0;
const double kZoneHandleHeight = 30.0;
const double kZoneShortEdgeFloor = kZoneHeaderHeight + kZoneHandleHeight;  // 70.0
```

**Renommage obligatoire :** le lot 6 appelait cette constante `kZoneHeightFloor` alors
qu'elle sert aussi de largeur minimale de colonne latérale — correct géométriquement (la
largeur avant rotation devient la hauteur après), mais le nom mentait. `kZoneShortEdgeFloor`
dit ce qu'elle est : le plancher du **petit côté** d'une zone, dans son propre repère.

Elle est **dérivée**, jamais recopiée : si l'en-tête ou la poignée change, le plancher suit.

Par cran :

| Cran | Contenu de la zone |
|---|---|
| `comfort` | PV, nom, compteurs secondaires, poignée 48 px |
| `compact` | PV, nom, poignée 30 px |
| `minimal` | PV seuls, poignée 30 px |

**La poignée du tiroir ne descend jamais sous 30 px** et reste le seul point d'entrée du
tiroir, quel que soit le cran. La couche d'alerte (critique / létal) traverse tous les
crans sans exception.

---

## 7. Critères de sortie

### 7.1 Automatiques

- Suite complète verte.
- `flutter analyze` sans erreur ni avertissement nouveau.
- Chaque test ajouté vérifié **discriminant** : une mutation nommée du code de production
  le fait échouer, et la mutation est restaurée.

### 7.2 Visuels — bloquants, et c'est nouveau

**Aucun merge sans ces captures, regardées par l'utilisateur.** Elles ne sont pas une
formalité : elles sont la seule preuve que les tests ne savent pas produire.

1. **4 joueurs, téléphone en portrait** — face-à-face strict, aucune colonne latérale, le
   hub central atteignable.
2. **4 joueurs, tablette en paysage, à plat sur une table** — depuis **chacune des quatre
   chaises** : le chiffre se lit à l'endroit, la moitié gauche décrémente *telle que ce
   joueur-là la voit*, la poignée s'atteint au doigt.
3. **8 joueurs, petit écran** — le cran minimal reste lisible, la poignée atteignable.
4. **Les huit actions atteignables** dans les deux formes de barre, sans défilement caché.
5. **Le geste de palier au pouce**, sur appareil réel, à la taille de zone d'une partie à
   4 joueurs — le point de §5.3.
6. **Glisser-déposer aux quatre orientations** — dette reportée depuis le lot 3.

### 7.3 Tests dont la forme est imposée

- **Repérage par clé** (`ValueKey('player_zone_<playerId>')`) quand le test porte sur un
  **comportement** joignable par un geste.
- **Repérage géométrique** quand la propriété testée **EST** la disposition — où se trouve
  le widget, quelle moitié est quelle moitié.

Les deux familles se ressemblent (ce sont des `tester.tap` dans des tests de zone joueur).
Ce qui les sépare est **ce que le test prétend prouver**. Chaque famille a produit sa
propre série de tests verts et mensongers sur ce projet : quatre tests de tap ciblés par
clé qui restaient verts moitiés inversées, et neuf repérages ordinaux qui touchaient le
mauvais joueur.

- **Aucune fixture ne part d'un `playerOrder` identité** quand le test porte sur l'ordre :
  les deux ordres y sont indiscernables, et le test est vert et vide.

---

## 8. Migration des données existantes

### 8.1 Marqueur de version, jamais d'heuristique de forme

`toJson` écrit `rotationsMigrated: true` ; `fromJson` ne migre que si le marqueur est
absent.

Sans ce garde-fou, l'heuristique « tous les `quarterTurns` à 0 » confond un choix
délibéré de l'utilisateur (le preset « Même sens » produit exactement `[0,0,0,0]`) avec un
ancien snapshot, et l'écrase **à chaque rechargement**.

### 8.2 Ne jamais deviner ce qu'on ne peut pas distinguer

Corollaire, apparu sur l'arbitrage du format Standard : un réglage utilisateur et un
résidu d'ancien preset peuvent être bit-à-bit identiques. Quand c'est le cas, **on ne
migre pas** — on laisse les anciennes données telles quelles et la nouvelle règle ne vaut
que pour les parties créées ensuite.

### 8.3 Réordonnancement

Une zone **déplacée** prend l'orientation par défaut de son nouveau siège. Une zone que
personne n'a touchée **garde la sienne**.

Reposer toutes les rotations détruisait le preset des joueurs intacts — précisément le
réglage que le marqueur de §8.1 venait protéger au rechargement.

---

## 9. Hors périmètre

- Les presets d'orientation décoratifs « Côtés », « Triangle », « Cercle », supprimés au
  lot 6 sans mandat. Leurs rotations restent atteignables une par une par le bouton de
  rotation de chaque zone. **Question ouverte** laissée à l'utilisateur.
- L'aperçu des presets à 8 joueurs, qui rend une rangée alors que la grille passe en
  sous-grille 2×2.
- La disposition de l'écran de setup. Elle est **le même problème de design** et devra
  être reprise sur la même maquette, mais elle appartient au lot 4 et à l'autre session.

---

## 10. Ce qui est récupérable depuis `lot6-archive` (09e16c7)

| Élément | Commit | État |
|---|---|---|
| `table_seat.dart`, `seatsFor` | `feeb53f` | tel quel |
| Contrat de densité | `3774b74` | renommer la constante (§6) |
| Couche d'alerte traversante | `4471135` | tel quel |
| Marqueur `rotationsMigrated` | `da4e859` | tel quel |
| Sémantique du réordonnancement | `96ff2bb` | tel quel |
| Test géométrique de rotation | `bd61ef5` | tel quel |
| Badge de dégâts dans le repère pivoté | `77f6376` | tel quel |
| **`AdaptiveGrid` et ses 30 %** | `2e252c7` | **à réécrire — c'est le bug** |

Le correctif du nombre flottant (`c85c2c2`) est déjà récupéré sur la branche
`fix/floating-number-and-step-row`.
