# Life counter « Mythic » et decks « Moxfield » — Design

*18 octobre 2026*

## 0. Pourquoi cette spec existe

L'utilisateur a testé l'application sur un Pixel Fold et a formulé deux
demandes : rapprocher le life counter de la fluidité de Mythic Tool, et
rapprocher la page des decks de l'expérience Moxfield (filtres,
catégorisation, commandant mis en avant).

Avant d'écrire, l'application a été lancée et observée. Ce constat visuel
est la base de la spec, et il a déplacé le périmètre : le life counter a
déjà été refondu quatre fois (specs v2, v3, v4, lot 6, table multijoueur
v2) et son geste de vie est conforme. Ce qui ne va pas est ailleurs.

**Ce qui a été vu, et qui fonde chaque décision ci-dessous :**

| Observation | Où | Conséquence |
|---|---|---|
| À 4 joueurs sur grand écran, 2 zones prennent ~67 % de la largeur chacune, 2 autres ~13 % | capture 700×1550 | §1.1 |
| Les 2 joueurs en colonne n'ont ni nom, ni compteurs, ni poignée (cran `minimal`) | idem | §1.1 |
| La bande d'actions coupe la table en deux et vole de la hauteur | idem | §1.2 |
| Couleurs joueur = `Colors.*.shade900` Material bruts, en dur, **dans deux listes divergentes** | `game_setup_modal.dart:53`, `player_skin_picker.dart:29` | §1.3 |
| Un deck occupe une bande de 100 px dans 1 250 px de vide ; une seule colonne quelle que soit la largeur | capture 835×1550 | §2.1, §2.2 |
| L'art du commandant est une pastille ronde de 50 px | `deck_list_card.dart` | §2.1 |
| La texture de fond est présente sur Decks | capture | §2.5 |
| Aucun `DisplayFeature` dans `lib/` | recherche | §4 |

**Retours utilisateur recueillis après le constat :** disposition « pas
hyper propre », couleurs de base évoquant « un crapaud venimeux »,
orientation par défaut « malformée », et modale de dégâts de commandant
« pas logique ».

---

## 1. Chantier A — Life counter : géométrie, couleur, orientation

### 1.1 Équité des surfaces

**Règle.** Jusqu'à 4 joueurs, il n'y a plus de colonnes latérales. La
table est découpée en zones de surface égale, chacune pivotée vers son
siège.

| Joueurs | Disposition | Colonnes latérales |
|---|---|---|
| 2 | face-à-face, 2 zones égales | non |
| 3 | 3 zones égales en bandes, la 3ᵉ pivotée vers son siège | non |
| 4 | quatre quadrants égaux : deux à 180° en haut, deux à 0° en bas | non |
| 5 – 6 | face-à-face central + colonnes | oui, si payées (ci-dessous) |

Les colonnes latérales ne subsistent qu'à 5 et 6 joueurs, où une grille
égale n'est pas réalisable, et sous une condition durcie : une colonne
n'est accordée que si elle peut tenir le cran `compact` — nom, PV,
poignée. Le cran `minimal` cesse d'être un résultat acceptable pour une
colonne latérale ; il reste admissible pour une zone de grille sur très
petit écran.

`kSideColumnNeed` est recalculé à partir de l'exigence `compact` au lieu
du plancher `kZoneShortEdgeFloor`, et le commentaire qui l'accompagne dit
de quelle exigence il dérive.

**Pourquoi.** Un joueur sur une bande de 70 px sans nom ni compteurs ne
joue pas dans les mêmes conditions que son voisin cinq fois plus large.
L'équité des surfaces est la propriété qui distingue une table d'une
liste, et c'est ce que fait Mythic Tool.

### 1.2 Accès aux actions

`ActionBarKind.band` ne s'applique plus qu'aux dispositions qui
comportent une frontière horizontale traversant toute la table, où une
bande ne retire de surface à personne : le face-à-face à 2 joueurs sur
grand écran, et les dispositions à 5-6 joueurs avec colonnes latérales,
où la bande s'insère entre les deux rangées centrales.

Dans toute disposition en zones égales sans frontière traversante — 3 et
4 joueurs — les actions reviennent au hub flottant, posé sur le
croisement des zones : il ne retire de surface à personne et se trouve à
distance égale de tous les joueurs.

Sur petit écran (petit côté < `kLargeScreenShortEdge`), le hub reste la
seule forme, quel que soit le nombre de joueurs. Cette règle est
inchangée.

La règle §4.3 de la spec table multijoueur v2 — interdiction de
dégradation silencieuse de la barre d'actions — reste en vigueur sans
changement.

### 1.3 Couleur et habillage des zones

**Les deux listes de couleurs en dur sont supprimées.** `_defaultColors`
(`game_setup_modal.dart`) et `playerSkinColorOptions`
(`player_skin_picker.dart`) sont remplacées par une source unique,
`lib/widgets/life_counter/player_skins.dart`, tirée de la DA Grimoire et
non de la palette Material.

**Habillage par défaut.** Un joueur ne naît plus avec un aplat. Il naît
avec un fond illustré, choisi par index de siège parmi 6 à 8
illustrations embarquées dans `assets/images/player_skins/`.

**Contrainte de droits, explicite.** Ces illustrations sont des visuels
originaux dans l'esprit Grimoire — ambiances de terrain, textures —, et
**jamais des arts de cartes Magic**, qui appartiennent à Wizards of the
Coast et ne peuvent pas être redistribués dans un binaire. L'accès aux
arts Scryfall reste offert par le `player_skin_picker` existant, en
réseau, ce qui est l'usage prévu par Scryfall. Conséquence assumée : hors
ligne, un joueur a un fond embarqué, jamais un art de commandant.

Le poids total des assets ajoutés ne dépasse pas 3 Mo.

### 1.4 Orientation par défaut

Les rotations initiales sont dérivées du modèle de sièges retenu par
`tableLayoutFor`, et d'aucune autre source. Le défaut observé — une
orientation qui ne correspond pas à la grille affichée — vient de ce que
les deux étaient calculées séparément.

Cette règle ne fait que réaffirmer le §2.1 de la spec table multijoueur
v2 (« la rotation n'a qu'un seul propriétaire ») : elle avait été écrite,
elle n'est pas respectée en sortie du changement de grille du §1.1.

Un test géométrique vérifie, pour 2 à 6 joueurs et pour les deux
orientations d'écran, que la rotation de chaque zone correspond au siège
que la grille lui a effectivement donné.

### 1.5 Orientation des modales

**Règle.** Toute surface modale rattachée à un joueur — tiroir, dégâts de
commandant, éditeur de compteur — est orientée vers le siège de ce joueur
et surgit depuis **son** bord, pas depuis le bas de l'écran.

Aujourd'hui `player_drawer.dart:94` appelle `showModalBottomSheet` et
`counter_editor_dialog.dart:46` appelle `showDialog` : l'un arrive
toujours du bas, l'autre toujours au centre, et ni l'un ni l'autre ne
sait à quel siège il appartient.

Un unique `SeatedSheet` remplace les deux appels. Il reçoit le siège,
applique sa rotation, et choisit son bord d'apparition en conséquence.
Pour un joueur du bas, le comportement observable est inchangé.

**Ce que ça corrige en jeu :** le joueur d'en face peut saisir ses propres
dégâts de commandant sans lire un panneau à l'envers, et sans faire
tourner le téléphone.

### 1.6 Réglages de calibrage

Les quatre valeurs que les specs antérieures listaient comme « à calibrer
en usage réel » quittent le code de production pour un fichier unique,
`lib/widgets/life_counter/tuning.dart` : sensibilité et accélération de
la molette, durée de l'appui long, fenêtre du buffer de dégâts (les 2 s
n'ont jamais été validées), plancher de lisibilité de la poignée.

Chaque constante porte sa valeur actuelle et la raison pour laquelle elle
vaut ça. Aucune n'est exposée dans les Réglages : ce fichier existe pour
qu'un ajustement après une vraie partie soit un geste, pas une fouille.

---

## 2. Chantier C — Bibliothèque de decks

### 2.1 La tuile

`DeckListCard` est réécrit. L'art crop du commandant occupe toute la
tuile en fond, en ratio 16:9. Un dégradé sombre en pied porte le nom du
deck, les pips d'identité couleur, le nombre de cartes et le prix.

La pastille ronde de 50 px disparaît.

Un deck sans commandant reçoit un fond neutre Grimoire et conserve
exactement la même structure d'information : la tuile ne change pas de
forme selon les données.

Le `Dismissible` de suppression par glissement est conservé tel quel,
libellé compris.

### 2.2 La grille

| Largeur disponible | Colonnes |
|---|---|
| < 600 dp | 1 |
| 600 – 999 dp | 2 |
| ≥ 1000 dp | 3 |

Le Pixel Fold déplié (≈ 841 dp de petit côté) tombe en 2 colonnes.

### 2.3 Filtres et tri

Les trois pilules tassées en haut à gauche sont remplacées par une barre
de filtres portant un compteur de filtres actifs et ouvrant une feuille
de filtres :

- format,
- identité couleur (l'actuel `deck_identity_filter_modal` est réutilisé),
- tag de deck (§2.4),
- fourchette de prix.

Le tri est étendu à : nom, prix croissant, prix décroissant, date de
modification, nombre de cartes.

`DeckListState` gagne `selectedTags: List<String>` et
`priceRange: (double, double)?`, avec leur prise en compte dans
`copyWith` — y compris la remise à zéro, sur le modèle du `clearIdentity`
existant.

### 2.4 Tags de deck

`Deck` gagne `tags: List<String>`, sérialisé dans `toJson`/`fromJson` et
persisté par une migration Drift. Un deck existant migre avec une liste
vide.

Ce sont les « dossiers » de Moxfield. Ils sont distincts des `tags` déjà
portés par `DeckCard`, qui s'appliquent à une carte dans un deck.

### 2.5 Texture

La texture de fond est retirée de l'écran Decks.

Ce n'est pas une décision nouvelle : la spec « Refonte navigation & DA »
du 19 septembre 2026 (§7.3) prescrit déjà son retrait des écrans denses,
« Collection, Decks, fiche carte ». Le constat visuel montre qu'elle est
toujours là. Cette spec ne fait qu'appliquer la précédente.

---

## 3. Chantier D — Page d'un deck

### 3.1 Le hero du commandant

`DeckCommanderHeader` est réécrit : art du commandant en bandeau plein
cadre, nom du deck en surimpression sur un dégradé, identité couleur, et
une rangée de stats clés — nombre de cartes, prix, power level.

Le cas « deux commandants » (partenaire) partage le bandeau en deux. Le
cas « aucun commandant » conserve son message actuel, sur un fond neutre
de même hauteur : la page ne doit pas changer de géométrie selon les
données.

### 3.2 Catégories de cartes

`_buildGroupedList` cesse d'être figée sur le type.

Un `CardCategoryService` déduit une catégorie à l'ajout et à l'import,
depuis le type line et le texte oracle, parmi : Ramp, Pioche, Removal,
Wipe, Protection, Tuteur, Terrains, Créatures, Win-con, Autres.

**La catégorie est stockée**, dans un champ `category` de `DeckCard`
distinct de `tags`. Les `tags` restent des étiquettes libres de
l'utilisateur ; la catégorie est une taxonomie fermée. Les mélanger
rendrait impossible de distinguer une correction d'un libellé.

Une correction manuelle pose `categoryLocked: true` et **n'est jamais
réécrite** par une déduction ultérieure.

Un sélecteur bascule l'affichage entre « par catégorie » et « par type »,
et ce choix est mémorisé par deck.

Migration : les cartes existantes sont créées avec `category: null` et
`categoryLocked: false`, et reçoivent leur catégorie à la première
ouverture du deck.

### 3.3 Les onglets

Les huit onglets passent à quatre. Rien n'est supprimé ; tout est
regroupé.

| Nouvel onglet | Contenu |
|---|---|
| Liste | Main / Side / Considering / Wishlist, via un sélecteur en tête plutôt que quatre onglets |
| Stats | `DeckStatsTab`, inchangé |
| Suggestions | `DeckSuggestionsTab`, inchangé |
| Infos | Tokens + Légalité |

Les quatre `DragTarget` de dépôt de carte entre boards sont préservés :
le sélecteur de board doit accepter un dépôt exactement comme l'onglet
qu'il remplace. **C'est le point de régression le plus probable de ce
chantier** et il a son test dédié.

---

## 4. Chantier B — La charnière

Un `FoldAwareScaffold` lit `MediaQuery.displayFeatures`, retient le pli
s'il existe, et expose sa position et son orientation.

Deux consommateurs, et deux seulement :

- la table du life counter, qui fait coïncider une frontière entre zones
  avec le pli au lieu de le laisser traverser une zone ;
- la grille de la bibliothèque de decks, dont une gouttière s'aligne sur
  le pli.

En l'absence de pli — tout appareil non pliable — le comportement est
rigoureusement inchangé.

**Risque assumé et non mitigeable en l'état :** ce chantier ne peut pas
être validé sans le Pixel Fold. Aucun émulateur pliable n'est installé
sur la machine de développement, et Flutter web n'a pas pu servir de
substitut (l'application n'atteint jamais `runApp` sur cette cible). La
validation de ce lot est manuelle, sur l'appareil, par l'utilisateur.

---

## 5. Ordre de livraison

A → C → D → B.

A en premier parce que c'est la friction la plus ressentie et qu'il ne
dépend de rien. C et D ensuite, car l'essentiel y est de la
réorganisation d'existant. B en dernier : c'est le seul lot que personne
ne peut vérifier sans l'appareil, et il bénéficie des composants
réécrits en A.

---

## 6. Critères de sortie

### 6.1 Automatiques

- Suite complète verte ; `flutter analyze` sans erreur ni avertissement
  nouveau.
- Chaque test ajouté vérifié **discriminant** : une mutation nommée du
  code de production doit le faire échouer.
- Test géométrique des rotations (§1.4), 2 à 6 joueurs, deux
  orientations.
- Test d'équité des surfaces (§1.1) : à 4 joueurs sur grand écran, les
  quatre zones ont la même aire à 1 % près.
- Test de dépôt sur le sélecteur de board (§3.3).
- Test de non-régression de la migration Drift : un deck d'avant la
  migration s'ouvre, et ses cartes ne perdent ni `tags` ni quantités.
- Test qui balaie `lib/` et échoue si une couleur de joueur est écrite
  en dur hors de `player_skins.dart`.

### 6.2 Visuels — bloquants

Ces points ne se valident pas par un test vert. Chacun demande une
capture, examinée.

- Table 4 joueurs, plié et déplié : quatre quadrants, orientations
  correctes, hub au croisement.
- Tiroir et dégâts de commandant ouverts depuis **chacun** des quatre
  sièges.
- Bibliothèque de decks à 1, 2 et 3 colonnes.
- Page deck avec commandant, avec partenaire, et sans commandant.

Cette exigence vient d'une leçon de ce projet : un lot déplaçant des
pixels a déjà été reverté après 1 028 tests verts.

---

## 7. Hors périmètre

- **Le geste de vie lui-même** — tap ±1, appui long, molette. Il est
  conforme à ce que fait Mythic Tool, et le toucher ne se juge ni sur
  maquette ni à la souris. Si la sensation reste insatisfaisante après
  ce travail, c'est un chantier distinct, à régler sur l'appareil avec
  les constantes du §1.6.
- Les animations de transition, qui se décident une fois la géométrie
  figée.
- Tout réglage de calibrage exposé dans les Réglages.
- La migration des 2 068 sites `AppColors.*` vers `MagicPalette`, qui
  appartient au chantier « Table » annoncé par la spec DA.
- Les arts de cartes Magic embarqués dans le binaire (§1.3).
