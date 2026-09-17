# Note de rebase — lot 5 (compteurs) sur table v2

**Date :** 2026-09-17
**Pour :** la session qui rebasera `feat/life-counter-v4-lot5-compteurs` après le merge de la table v2 sur `main`.
**Pourquoi ce fichier existe :** le journal SDD est git-ignoré. Tout ce qui n'est pas commité disparaît avec le worktree, et ces décisions ont coûté des rondes de correction des deux côtés.

## Ordre de merge, et pourquoi

**Table v2 d'abord, lot 5 rebase ensuite.** Le fichier qui décide est `life_counter_page.dart` : la table v2 le **réécrit** (hub, presets, réordonnancement, géométrie), le lot 5 n'y **ajoute** que du câblage de compteurs. Rebaser de l'additif sur du structurel repose des ajouts dans une page neuve — borné. L'inverse obligerait à rejouer une réécriture profonde par-dessus des ajouts, et ce qu'on y perdrait, aucun test ne le verrait.

Séquence : table v2 franchit sa porte visuelle → merge local sur `main` → le lot 5 rebase, relance la suite complète, vérifie les points ci-dessous → merge. **Rien poussé avant que les deux soient vertes sur `main`.**

---

## Les quatre fichiers en collision

### `player_drawer.dart` — le plus risqué, les deux lots y ajoutent

**À préserver de la table v2 :**
- **« Tourner » et « Couleur » sont placées AVANT la grille de dégâts de commandant**, juste après le bloc des compteurs. Ce n'est pas esthétique : au cran de densité minimal (7-8 joueurs), l'en-tête de zone est masqué et le tiroir devient le **seul** accès à la rotation. En fin de liste, elles exigeaient 371 px de défilement — la totalité du tiroir — dans le seul cas où elles sont indispensables. Clés `action-rotate`, `action-color`.
- Un **test de distance** garde cette garantie : dans le pire cas (7 adversaires, seuil létal actif, trois compteurs non nuls, cran minimal), atteindre « Tourner » doit rester sous **75 % du `maxScrollExtent`**. Mesure au moment de l'écriture : 62,2 %.

> **Le point d'attention n°1 du rebase.** Les lignes de compteur du lot 5 **allongent ce tiroir**. Si ce test tombe après le rebase, **ce n'est pas un test à relâcher** : c'est le signal que les deux actions sont retombées trop bas. Corriger la mise en page, pas le seuil.

**À préserver du lot 5 :**
- Les lignes de compteur viennent de `activeCounterIds` de la session, **dans cet ordre**, jamais de l'ordre du catalogue.
- Retirer un compteur bascule immédiatement vers une ligne « Réactiver » **dans le tiroir encore ouvert** — sinon le joueur doit deviner qu'il faut refermer et rouvrir.
- Clés `counter_row_<id>`, `_plus`, `_minus`, `_remove`, `counter_reactivate_<id>`. Cibles ≥ 48×48.
- Tout refus est **affiché** en SnackBar. Aucun refus muet.

**Dette commune reconnue des deux côtés :** `showPlayerDrawer` dépasse 17 paramètres et 7 callbacks, et les deux lots y ajoutent encore. Le prochain ajout passe par un découpage ou un objet de configuration, pas par un paramètre de plus.

### `conditional_handle.dart`

**De la table v2 :** la hauteur réservée vient de `handleHeightFor(tier)`, qui ne rend **jamais** moins de 30. Au cran confort elle vaut 48, et la rangée d'attribution suit cette hauteur dynamique au lieu d'une constante figée.

**Du lot 5 :**
- `reservedHeight = 30.0` — la table v2 en **dérive** `kZoneShortEdgeFloor`. Réservée en permanence, calme ou non, pour que le chiffre de PV ne saute pas en cours de partie.
- `_layoutSafetyMargin = 2.0` — absorbe l'écart entre un `TextPainter` mesuré isolément et la mise en page réelle d'une `Row` contrainte. Sans elle, débordement réel de 0,5 px dans une bande d'environ 1,5 px. Trois rondes.
- **Aucun `Scrollable`, jamais**, verrouillé par un test. Une bande de 30 px qui défile est indécouvrable — mécanisme exact du revert du lot 6.
- Le `TextScaler` ambiant est transmis au `TextPainter`. Sans lui, un réglage d'accessibilité à 2× fait déborder de 56 px, **et le test ne peut pas le voir** puisqu'il tourne à l'échelle 1.
- `maxVisibleChips` (défaut 4) est paramétrable **exprès pour la table v2** : gravité décroissante puis troncature « +N », marqueur non textuel quand même le « +N » ne tient pas. Garantie honnête : « pas de débordement visible avec une marge de 2 px », **pas** « impossible ».

### `player_zone.dart`

**De la table v2 :**
- Un `LayoutBuilder` est **à l'intérieur du `RotatedBox`**, pas autour — seul endroit où la `Size` est dans le repère du joueur. **Ce placement n'a aujourd'hui aucun effet observable** (`RenderRotatedBox` retourne déjà les contraintes, `tierFor` repose sur `min(w,h)`, symétrique), donc **aucun test ne peut le garder.** Si le rebase le déplace, rien ne s'allumera.
- Au cran `minimal`, `PlayerHeader` est masqué — c'est ce qui rend le tiroir indispensable pour la rotation.

**Du lot 5 :** `CounterSummary` est construit depuis `player.counters`, résolu via le catalogue. **Aucune `RotatedBox` ajoutée** : la rotation garde son propriétaire unique.

### `life_counter_page.dart`

**De la table v2 — cinq invariantes, toutes payées :**
- **La géométrie a une seule source : la taille MESURÉE par `AdaptiveGrid`, lue par `GlobalKey`** (`_measuredGridSize`), jamais `MediaQuery`. En production, `AppShellScaffold` porte une barre basse : 50 à 80 px d'écart, et près du seuil de 600 px les deux décident différemment. Trois consommateurs : `_onReorderPlayers`, `_getOrientationPresets`, `_buildOrientationPreview`.
- **Aucune compensation de rotation, nulle part.** Pas de `+2`, pas de `-2`. Presets et sièges décrivent des `quarterTurns` **finaux**. Une compensation a déjà produit une table entière à l'envers avec tous les tests verts — deux fois.
- **Un réordonnancement ne repose que les deux zones réellement permutées**, jamais toutes, sinon un preset « Même sens » saute chez des joueurs que personne n'a touchés.
- **`rotationsMigrated: true` en tête de `toJson`**, et `fromJson` ne migre que si le marqueur est **absent**. Sans lui, l'heuristique « tous les `quarterTurns` à 0 » confond le preset « Même sens » avec un ancien snapshot et l'écrase à chaque rechargement.
- **Une seule liste d'actions, `_gameActions`**, consommée par la bande **et** par le hub. La bande ne défile **jamais** horizontalement : si les neuf entrées n'entrent pas, `tableLayoutFor` rend le hub.

**Du lot 5 :**
- **Une seule source, un seul filtre.** Un compteur désactivé compte **0** pour *tous* les consommateurs. Trois sites : `_toLegacyPlayer`, `_getDeathReason`, `_resetPlayerCounters`. Le troisième a été trouvé par la revue finale **après** correction des deux premiers — motif récidiviste, pas oubli isolé.
- `_resetPlayerCounters` itère sur `activeCounterIds` moins `commander_damage`, **jamais sur une liste écrite à la main**.
- `counterCatalogProvider.load()` est appelé dans `initState`.

---

## L'effet de bord à vérifier des deux côtés

`ValueKey('player_zone_<playerId>')` est revenue dans `lib/` (elle avait disparu avec le revert du lot 6). C'est un `KeyedSubtree` : zéro `RenderObject`, zéro pixel déplacé.

**Mais elle change un comportement.** Avec elle, un réordonnancement **re-parente** l'élément existant au lieu de le mettre à jour en place : l'état de `_PlayerZoneState` — contrôleurs d'animation, minuteries — suit désormais le **joueur** et non la **position**. C'est une amélioration, et c'est invisible en test. Porté à la porte visuelle de la table v2 : *une animation en cours sur un joueur déplacé doit le suivre, pas rester sur sa case*.

## Une leçon transversale à appliquer, pas seulement à noter

`kActionWidth` valait 36 alors qu'un `IconButton` Material fait 48 au minimum : la marge qu'on croyait avoir était un déficit, depuis l'origine. Corrigé, et **gardé par un test qui mesure un bouton réellement rendu**.

C'est la même famille que `_layoutSafetyMargin` du lot 5 : une mesure isolée qui ne vaut pas la mise en page réelle. La marge de 2 px est un pansement honnête, pas une solution. **Si le lot 5 ajoute des puces, qu'il mesure le rendu au lieu de calculer** — c'est ce qui aurait évité trois rondes.

## Procédure

1. `git rebase main` sur la branche du lot 5.
2. Résoudre en relisant **les deux colonnes ci-dessus**, pas seulement le diff.
3. `flutter test` **en entier** et `flutter analyze`.
4. **Vérifier nommément** : le test de distance du tiroir (< 75 %), l'absence de `Scrollable` dans la poignée, `reservedHeight` à 30, l'absence de compensation de rotation, le marqueur `rotationsMigrated`, et les trois sites « une seule source, un seul filtre ».
5. Un merge Dart peut compiler, passer mille tests, et avoir remis deux entrées de tiroir dans leur ordre d'origine. **C'est précisément ce qu'aucun test ne voit.**


---

# Ce que la fusion a réellement appris (écrit après coup)

La fusion a eu lieu le 2026-09-17. `main` est à `b319e2d`, 1128 tests verts. **Aucune décision des deux cartes ci-dessus n'a été perdue**, et aucun conflit de fond n'est apparu : les deux chantiers ont tenu ensemble.

Neuf tests ont échoué après la résolution. Voici ce qu'ils ont enseigné.

## La règle qui manquait aux deux cartes

Les cartes servaient à éviter qu'un merge **annule** une décision. Celui-ci en a **dupliqué** une, et aucune des deux listes ne décrivait cette forme-là.

Les deux chantiers avaient chacun ajouté un `KeyedSubtree(key: ValueKey('player_zone_<playerId>'))` autour de la zone joueur — même intention, même clé, écrits indépendamment. La résolution a gardé les deux côtés, comme partout où ils semblaient purement additifs. Résultat : **deux widgets de clé identique dans le même arbre**, donc tout `find.byKey` ambigu — quatre tests rouges d'un coup (badge après réordonnancement, réordonnancement, presets, repli portrait).

Le symptôme ressemblait à un conflit de fond entre les deux chantiers. C'était l'inverse : **deux fois la même bonne idée.**

> **Dans une résolution de conflit, « les deux côtés sont additifs » n'est pas une raison suffisante de garder les deux.** Il faut se demander si les deux ajouts sont la *même chose dite deux fois*. Deux paramètres différents se cumulent ; deux clés identiques s'annulent.

## Les cinq autres échecs

Tous des tests décrivant le monde d'avant, aucun défaut de production :
- un `.first` sur les zones, qui ne désigne plus le même joueur depuis que l'ordre de l'arbre suit `tableLayoutFor`/`seatsFor` ;
- la grille de dégâts de commandant, qui n'entre plus sans défiler dans un tiroir allongé par les deux côtés ;
- un helper montant un `Player` avec les champs nommés que le lot 5 a remplacés par une collection ;
- un `'☠ 3'` cherché sans le sélecteur de variante emoji que porte `CounterType`.

Aucun seuil relâché, aucune assertion affaiblie. **Le test de distance du tiroir mesure 59,5 %** contre un seuil de 75 % : les lignes de compteur n'ont pas repoussé « Tourner » trop bas.

## Une erreur de méthode, commise deux fois

J'ai annoncé « 0 erreur, 0 avertissement » sur `main`. C'est faux : il y a **1 avertissement** (`_tag` dans `game_setup_modal.dart`, antérieur aux deux chantiers). La cause est un `grep -icE " error | warning "` dont le motif exige une espace **avant** le mot, alors que `flutter analyze` n'en met pas toujours une.

C'est la deuxième fois dans ce lot. La première, la leçon avait été écrite : *vérifier un compte à zéro avec un filtre dont on n'a jamais regardé la sortie brute, c'est se fabriquer une preuve.* Elle a été écrite, puis pas appliquée.

> **Un chiffre de zéro annoncé dans un compte rendu doit avoir été lu en sortie brute au moins une fois.** C'est la ligne sur laquelle quelqu'un finira par s'appuyer.
