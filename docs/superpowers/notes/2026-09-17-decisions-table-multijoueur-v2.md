# Décisions prises pendant le lot « table multijoueur v2 »

**Branche :** `feat/life-counter-table-v2` · **Spec :** `docs/superpowers/specs/2026-09-17-life-counter-table-multijoueur-v2-design.md` · **Plan :** `docs/superpowers/plans/2026-09-17-life-counter-table-multijoueur-v2.md`
**Maquette de référence :** https://claude.ai/artifact/UvvoPP5qqB3fF79F9Q81XD

## Pourquoi ce fichier existe

Ces décisions vivaient dans un journal d'exécution git-ignoré, qui disparaît avec le worktree. La moitié d'entre elles portent des raisons qu'aucun code ne dit — pourquoi `kActionWidth` vaut 48, pourquoi deux entrées du tiroir sont placées là et pas ailleurs, pourquoi un `LayoutBuilder` est à l'intérieur d'un `RotatedBox` alors qu'aucun test ne peut le garder.

Chaque décision porte **ce qu'elle coûte si elle est fausse**. Une décision sans ce coût n'est pas révisable.

## Le motif qui a dominé ce lot

**Six fois, un test s'est révélé vert sur un chemin que personne n'emprunte.** La règle de budget testée sur un écran en portrait, rejeté avant par la condition de forme. La retombée de migration testée sur un `playerOrder` identité, où les deux branches coïncident. La largeur de colonne testée à une taille où la formule correcte et la formule naïve donnent le même nombre. Un glissé vers un palier testé à plat, alors que le bouton visé est en bas. Le geste tactile entier testé avec un `moveTo` unique sans `pump()` — il passait les tests et ne fonctionnait pas sur la vraie page.

La parade qui a marché à chaque fois : **exiger une mutation nommée par test**, et vérifier que le chemin emprunté par le test est celui qu'emprunte un utilisateur.

**Le corollaire, qui a coûté un revert complet de la version précédente :** un lot qui déplace des pixels ne se clôt pas sur des tests verts. Il se clôt sur une capture regardée par un humain. Les tests prouvent qu'on a construit ce qu'on a décrit ; ils ne prouvent jamais qu'on a décrit la bonne chose.

**Et une chose qu'aucun test ne voit :** deux fois, une réorganisation d'affichage a failli supprimer une fonction sans supprimer son code — la rotation d'une zone au cran minimal, les infos de partie sur petit écran. La fonction existait toujours, simplement plus personne ne l'atteignait. La couverture ne mesure pas l'accessibilité.

---

## Les vingt-deux décisions

**Ruling 1 : `actionHub` est introduit en T4 avec un `const SizedBox.shrink()` provisoire dans `life_counter_page.dart`, remplacé en T6.**
Motif : le plan le prévoit déjà dans son auto-revue, mais seulement en prose ; sans cette instruction portée dans le brief de T4, l'implémenteur de T4 laisse la suite rouge et la revue de T4 signale une régression qui n'en est pas une. Le paramètre reste `required` : un défaut nul serait un piège permanent.
Coût si j'ai tort : un widget vide rendu au centre entre T4 et T6, invisible, corrigé en T6. Négligeable.

**Ruling 2 : T2 est étendue — elle crée le contrat de densité ET le câble dans `PlayerZone`.**
Motif : le scan montre que `tierFor` n'a aucun consommateur dans tout le plan. J'avais écrit dans mon auto-revue que §6 de la spec était couverte par T2 ; c'est faux, T2 ne crée que le contrat. Un contrat sans appelant est du code mort, et la revue de tâche le signalerait à juste titre. La spec §6 exige que les zones affichent leur contenu selon le cran. Les fichiers qui changent ensemble vivent ensemble : le contrat et son application restent dans la même tâche.
Concrètement, T2 ajoute : `PlayerZone` calcule `tierFor(Size(...))` sur ses contraintes **dans son repère** (donc après `RotatedBox`), masque le nom au cran `minimal`, les compteurs secondaires sous `comfort`, et lit `handleHeightFor(tier)` pour la hauteur réservée de la poignée.
Coût si j'ai tort : T2 devient la tâche la plus lourde du plan et peut demander une ronde de correction de plus. Le risque inverse — livrer un contrat de densité que rien n'applique — reproduirait exactement l'erreur du lot 6, du code correct qui ne change rien à l'écran.

**Ruling 3 : T7 enveloppe le `Stack` de `LifeDial.build` dans un `LayoutBuilder`.**
Motif : le plan écrit `_stepRow(constraints.maxWidth)` alors qu'aucun `constraints` n'existe à cet endroit — `LifeDial.build` (ligne 112) n'a pas de `LayoutBuilder`. Le code du plan ne compilerait pas. C'est un défaut de mon plan, pas une ambiguïté.
Alternative écartée : passer la largeur en paramètre depuis `PlayerZone`. Rejetée parce qu'elle fait traverser une information de mise en page à une frontière de widget sans raison, alors que `LifeDial` peut la lire lui-même.
Coût si j'ai tort : un `LayoutBuilder` de plus dans l'arbre, donc un rebuild supplémentaire sur redimensionnement. Négligeable devant une rangée qui ne sait pas sa propre largeur.

**Ruling 4 : T8 crée `docs/superpowers/notes/` si le dossier n'existe pas, et son commit n'est pas bloquant.**
Motif : l'étape 4 de T8 commite un dossier absent de ce worktree. Le livrable de T8 est le verdict de l'utilisateur sur des captures, pas un fichier.
Coût si j'ai tort : aucun — au pire une note de vérification non versionnée.

**Ruling 5 : les tâches T1 à T7 s'exécutent en continu ; T8 s'arrête et rend la main.**
Motif : T8 exige le verdict d'un humain sur des captures d'écran, ce qu'aucun sous-agent ne peut produire. C'est un arrêt prévu par la spec §7.2, pas un blocage.
Coût si j'ai tort : aucun. L'inverse — fusionner sans la porte visuelle — est exactement la faute du lot 6.

---

## Journal d'exécution

**Ruling 6 (T1) : le test « 2 joueurs » du plan était faux, le code avait raison. `seatsFor(2)` vaut `[top, bottom]`.**
Motif : vérifié par le contrôleur dans le code antérieur au lot 6 — `adaptive_grid.dart` à `6e147c7` place les `playerCount ~/ 2` PREMIÈRES zones en haut (« opponents »), le reste en bas (« user's side »). `[top, bottom]` est donc la convention établie du dépôt, et elle est cohérente avec les replis à 3, 4 et 5 joueurs. Mon plan contenait un test qui contredisait son propre code.
L'implémenteur a modifié un test pour le faire passer — geste normalement interdit. Il est accepté ICI et seulement ici parce que le code était la transcription verbatim du plan et que c'est le test qui déviait, ce que j'ai vérifié moi-même plutôt que de le croire sur parole.
Coût si j'ai tort : à 2 joueurs, le propriétaire de l'appareil serait assis en haut au lieu d'en bas — visible immédiatement, et rattrapable en inversant une ligne.

**Ruling 7 (T2) : masquer l'en-tête au cran minimal est conforme à la spec §6, MAIS il faut d'abord déplacer « Tourner » et « Couleur » dans le tiroir.**
Motif : vérifié par le contrôleur dans `player_drawer.dart` — le tiroir ne propose que Monarque, Éliminer et Réinitialiser. `PlayerHeader` porte `onRotate` et `onShowColorPicker`, et il est le SEUL accès à ces deux fonctions. Le masquer au cran minimal, donc à 7-8 joueurs, retire à un joueur toute possibilité de corriger son orientation — précisément la fonction que cette refonte entière existe pour servir. « PV seuls » décrit ce que la zone AFFICHE, pas ce à quoi le joueur a encore accès.
La poignée du tiroir ne descend jamais sous 30 px (contrainte globale) : le tiroir est donc un point d'entrée garanti à tous les crans, et c'est là que ces deux actions doivent vivre.
Coût si j'ai tort : deux entrées de plus dans un tiroir qui en compte déjà trois, et un geste supplémentaire pour tourner sa zone aux crans où l'en-tête reste visible. Faible devant une fonction injoignable.

**Ruling 8 (T2) : la rangée d'attribution suit `handleHeightFor(tier)` plutôt que la constante figée. Choix de l'implémenteur, accepté.**
Motif : la rangée doit se poser au-dessus de la poignée ; suivre sa hauteur réelle est plus juste que supposer 30. La garantie donnée à la session du lot 5 — 30 px réservés en permanence — tient toujours, puisque `handleHeightFor` ne renvoie jamais moins de 30.
Coût si j'ai tort : la rangée d'attribution se décale de 18 px entre le cran confort et les autres. Visible, sans conséquence fonctionnelle.

**Ruling 9 (T2) : le `LayoutBuilder` reste à l'intérieur du `RotatedBox`, mais la garantie est documentée comme non testable au lieu d'être affirmée.**
Motif : le placement est correct et le seul qui resterait juste si `tierFor` devenait asymétrique. Mais il n'a aujourd'hui aucun effet observable, et aucun test — pas même un test à `quarterTurns` impair — ne peut le distinguer. Affirmer l'inverse dans un commentaire, comme je l'avais dicté, est un mensonge dans le code ; ajouter un test pour « couvrir » la contrainte produirait un test vert quoi qu'il arrive, soit exactement le défaut que ce projet a déjà payé quatre fois.
Coût si j'ai tort : si quelqu'un déplace un jour le `LayoutBuilder` hors du `RotatedBox` ET rend `tierFor` asymétrique, rien ne l'arrêtera. Le commentaire est la seule barrière, et il le dit.

**Ruling 10 (T2) : « Tourner » et « Couleur » remontent AVANT la grille de dégâts de commandant, et le test du pire cas s'asservit à la DISTANCE de défilement, pas seulement à l'atteignabilité.**
Motif : la mesure rapportée par l'implémenteur — 371 px, soit la totalité du tiroir — montre que mon ruling 7 avait réglé l'accessibilité sur le papier en créant un problème d'ergonomie à sa place. Une action au fond d'une liste qu'il faut parcourir en entier n'est pas accessible. Ces deux actions sont les seules dont le tiroir est l'UNIQUE point d'entrée au cran minimal ; la grille de dégâts est longue et de taille variable, rien d'essentiel ne doit vivre derrière elle.
Coût si j'ai tort : Monarque, Éliminer et Réinitialiser descendent d'un cran dans une liste où elles étaient déjà en bas. Aucune ne perd d'accès.

**Ruling 11 (T4) : le test de débordement de la bande est conservé bien qu'il ne discrimine pas aujourd'hui.**
Motif : l'implémenteur a lui-même déclaré qu'il ne discrimine pas plutôt que de revendiquer une preuve absente, et le relecteur l'a vérifié (remplacer le garde-fou par un `ClipRect` laisse tout vert). Raison : à 600 px de large, le contenu (~386 px) tient dans le centre (~396 px) avec ou sans défilement. Le test n'est donc pas vide — il a un domaine de défaillance réel : si `kBandNeed`, `kSideColumnNeed` ou le nombre de boutons évoluent, il est le SEUL à virer au rouge. Canari faible, pas test menteur.
Coût si j'ai tort : un test de plus qui donne une fausse impression de couverture sur le mécanisme de défilement. Atténué par le commentaire qui énonce la limite.

**Ruling 12 (T5) : `_onReorderPlayers` tire ses sièges de `tableLayoutFor`, jamais de `seatsFor` en direct.**
Motif : défaut signalé par l'implémenteur, et le snippet de mon plan en était la cause. `seatsFor(order.length)` sans le drapeau ignore le repli face-à-face décidé par `tableLayoutFor`. À 4 joueurs sur téléphone en portrait, la grille affiche [haut, haut, bas, bas] mais le réordonnancement poserait les rotations de [haut, droite, bas, gauche] : deux joueurs pivotés à 90° et 270° dans des cases horizontales, texte couché. C'est la classe de défaut du lot 6 — deux sources de vérité sur la géométrie qui divergent.
Coût si j'ai tort : la taille lue est celle de l'écran et non celle de la zone de grille ; si l'écart franchit un seuil de `tableLayoutFor`, le réordonnancement pourrait poser des sièges d'une disposition voisine. L'implémenteur doit me signaler l'écart plutôt que l'approximer.

**Ruling 13 (T5) : la taille qui décide de la disposition est celle MESURÉE par `AdaptiveGrid`, lue par `GlobalKey`, jamais celle de `MediaQuery`.**
Motif : réponse de l'implémenteur à ma question sur l'origine de la taille. En production `AppShellScaffold` (app_shell_scaffold.dart:174-175) monte la page comme `body` d'un `Scaffold` portant une `bottomNavigationBar` permanente ; le `Scaffold` en retire la hauteur des contraintes du body. `AdaptiveGrid` mesure donc 50 à 80 px de moins que `MediaQuery.sizeOf`. Près de `kLargeScreenShortEdge = 600`, qui compare aussi la hauteur, les deux peuvent choisir des dispositions différentes. Le correctif de la ronde 1 avait ramené deux sources divergentes à deux autres.
Le précédent invoqué (`_getOrientationPresets` utilisant déjà `MediaQuery`) ne valide pas le motif : il porte le même défaut, non regardé jusqu'ici. Il est corrigé au passage, ainsi que `_buildOrientationPreview`.
Lecture par `GlobalKey` plutôt que par état muté pendant le build ou rappel de disposition : le geste survient après la mise en page, c'est donc une lecture pure.
Coût si j'ai tort : la retombée sur `MediaQuery` quand la clé n'a pas encore de contexte redevient la mauvaise source. Exigé explicite et commenté, jamais silencieux.

**Ruling 14 (T5) : le correctif de `_measuredGridSize` est conservé SANS test, parce qu'aucun test ne peut le discriminer aujourd'hui.**
Motif : l'implémenteur a démontré, sonde à l'appui, que le test que j'avais commandé est mathématiquement irréalisable. Une `bottomNavigationBar` ne retranche que de la hauteur ; or `shortEdge >= 600` implique `largeur >= 600`, et à partir de là `tableLayoutFor` ne replie plus jamais quelle que soit la hauteur — `shapeAllows` reste vrai et le budget passe (610-192 = 418 >= 324). Valeurs de sonde : `Size(610,900)`, `(610,630)`, `(610,550)`, `(610,300)` donnent toutes les mêmes `seats`. Seul `barKind` change, ce qui est cosmétique.
Le correctif reste parce qu'il protège contre un widget qui consommerait de la LARGEUR — un `NavigationRail` latéral — cas où la divergence deviendrait réelle. Il ne coûte rien et supprime une source de vérité.
Coût si j'ai tort : du code défensif sans couverture. Préférable au test vide que j'avais commandé et que l'implémenteur a refusé d'écrire — c'était le bon refus.

**Ruling 15 (T6) : les infos de partie deviennent une action à part entière, pas un appui long réservé à la bande.**
Motif : signalé par l'implémenteur, vérifié par le contrôleur — `_showGameInfoSheet` n'a qu'un seul appelant (`life_counter_page.dart:1360`, un `onLongPress`), et `onLongPress` n'apparaît qu'une fois dans toute la page. Sur téléphone, la bande n'est pas montée : la fonction disparaît. Défaut identique à celui de la tâche 2 (rotation et couleur injoignables au cran minimal), même remède.
Refus explicite d'ajouter un champ `onLongPress` à `GameAction` : un geste caché présent dans une seule des deux formes recrée le problème sous un autre nom.
Coût si j'ai tort : une neuvième entrée dans une liste d'actions, et `kActionCount` à porter de 8 à 9 — ce qui élargit `kBandNeed` et peut repousser le seuil où la bande est choisie. Surveillé par le test `Size(600,600)`.

**Ruling 16 (T6) : `kActionWidth` passe de 36 à 48 — la constante mentait depuis le début.**
Motif : l'implémenteur a MESURÉ les boutons rendus (script jetable) au lieu de supposer. Un `IconButton` Material fait 48x48 au minimum ; `kActionWidth = 36` sous-estimait donc `kBandNeed` depuis l'origine, et la « marge de 10 px » à 8 actions n'a jamais existé. La neuvième action n'a rien cassé : elle a révélé un défaut dormant (débordement mesuré de 38 px, bord du dernier bouton à 536 contre bande à 498).
Options écartées : (B) contraindre les boutons sous 48 dp — refusé, 48 dp est la cible tactile minimale et toute cette refonte existe parce que des gens tapent à côté sur un appareil posé à plat ; troquer un bug visible contre un bug de doigt. (A) relever `kLargeScreenShortEdge` — déplace le seuil pour masquer que la constante est fausse ; le prochain qui ajoute une action retombe au même endroit.
Conséquence assumée : à `Size(600,600)`, `600 − 192 = 408 < 472`, donc plus de colonnes latérales — cet écran passe en face-à-face avec la bande. C'est la règle d'abordabilité fonctionnant comme prévu : ce qui compte le plus est servi en premier. Grands écrans inchangés (820 → 628 ≥ 472 ; 1180 → 988 ≥ 472).
Test de garde exigé : comparer `kActionWidth` à la largeur RÉELLEMENT mesurée d'un bouton rendu, pour que ce mensonge ne puisse pas revenir.
Coût si j'ai tort : les écrans autour de 600 px de large perdent leurs colonnes latérales et repassent en face-à-face. Visible, réversible en une constante, et honnête — l'alternative était de continuer à afficher une bande qui déborde.

**Ruling 17 (T7) : la rangée d'attribution qui apparaît brièvement entre deux sélections de palier est acceptée, et inscrite à la porte visuelle T8.**
Motif : signalé par l'implémenteur. Avec le geste continu, chaque sélection de palier est un appui-glissé-relâché distinct ; entre deux, le mode d'ajustement est éteint et le buffer négatif — état dans lequel `showAttribution` (gardé par `!isAdjusting`) fait exactement ce pour quoi il existe. Ce n'est pas un défaut mais un état qui ne pouvait pas se produire avant. Plus aucun recouvrement dangereux : les paliers ont déjà disparu la même frame.
Je refuse d'élargir le périmètre de la tâche pour le masquer sans l'avoir vu. C'est précisément ce que la porte visuelle existe pour trancher.
Coût si j'ai tort : un clignotement visible et agaçant entre deux paliers consécutifs. Détectable en trente secondes à la T8, corrigeable par un délai de grâce sur `showAttribution`.

**Ruling 18 (T7) : le geste est ATOMIQUE — un relâchement sur un palier annule ce que la molette a émis pendant ce geste.**
Motif : signalé par l'implémenteur en fin de rapport, chiffré par le contrôleur. `wheelPixelsPerUnit = 8.0` et la rangée de paliers est EN BAS du cadran : tout glissé vers un palier descend, donc traverse la molette. Sur un cadran de 300 px, le trajet du centre à la rangée fait ~80 px, soit une dizaine de points émis en route avant d'atteindre le bouton. Le bug rapporté par l'utilisateur — modifier ses PV par accident — serait reproduit sous une autre forme.
Le garde `_stepUnder(event.position) == null` ne protège que pendant le SURVOL du bouton, pas pendant le trajet.
Le test n°1 mesurait `[-5]` avec `dy = 0` : un trajet qu'aucun doigt ne fait, puisque atteindre « -5 » exige de descendre. Test vert sur un chemin que personne n'emprunte — le même motif que la règle de budget testée en portrait et la retombée de migration testée sur un ordre identité.
Le relâchement HORS palier ne change rien : la molette garde son effet, c'est son usage normal.
Coût si j'ai tort : une molette dont l'effet s'annule si le doigt finit par erreur sur un palier. Visible, et moins grave que perdre dix points à chaque usage des paliers.

**Ruling 19 (T7) : le silence est étendu à TOUS les pas de molette en mode ajustement, et la question résiduelle est inscrite à la porte visuelle T8.**
Motif : extension signalée par l'implémenteur plutôt que glissée. Elle est nécessaire à la cohérence — exiger « exactement une bulle » est impossible si chaque pas de molette en produit une (on en obtient 9). Mesuré : 9 bulles avant, 1 après ; 2 retours haptiques avant, 1 après.
Ce que je NE peux PAS trancher par le raisonnement : `onLifeChanged` continue de partir à chaque pas, donc le nombre de PV affiché bouge pendant la descente puis se corrige au relâchement. Les bulles ne mentent plus, mais le chiffre peut encore sauter. La seule façon de le savoir est de le regarder.
Inscrit à T8 comme point nommé : « en glissant vers un palier, le chiffre de PV saute-t-il visiblement avant de se stabiliser ? » Si oui, le correctif est de différer l'application de la molette jusqu'au relâchement — geste pleinement atomique — et c'est un lot de suite, pas une ronde de plus ici.
Coût si j'ai tort : un saut de valeur visible pendant un geste. Détectable en trente secondes à la porte, et je préfère le montrer que le deviner.

**Ruling 20 (final) : les presets d'orientation 2 à 6 joueurs sont DÉRIVÉS de la géométrie, et les presets décoratifs sont supprimés.**
Motif : Critical 3. Les listes en dur décrivent la disposition moitié-haute/moitié-basse d'avant la branche. Mesuré à Size(900,700) / 4 joueurs : la disposition rendue est [top,right,bottom,left] = [2,3,0,1], alors que « Face à face » pose [2,2,0,0]. AUCUN des cinq presets ne produit l'orientation juste. Dix tests verts gravent les valeurs fausses.
« Côtés », « Triangle » et « Cercle » ne décrivent aucune disposition de sièges : ils ne peuvent pas être exprimés honnêtement une fois la géométrie dérivée. Ils sont supprimés — c'est la même question que l'utilisateur avait laissée ouverte au lot 6, cette fois avec une raison.
Coût si j'ai tort : l'utilisateur perd trois raccourcis d'orientation. Les rotations restent atteignables une par une par le bouton de rotation de chaque zone.
**Ruling 21 (final) : la migration des rotations pose le REPLI face-à-face, jamais les sièges de table.**
Motif : Important 4. `game_session.dart:316` appelle `seatsFor(effectiveOrder.length)` sans drapeau — ce que le ruling 12 a interdit ailleurs. Le modèle n'a pas accès à la taille de l'écran : il ne peut pas savoir si la disposition rendue aura des colonnes latérales. Un snapshot hérité ouvert sur téléphone en portrait poserait 90° et 270° dans des cases horizontales dès le premier lancement.
Le repli est le seul choix lisible sur TOUS les écrans. Sur tablette, l'utilisateur applique « Table » s'il le souhaite.
Coût si j'ai tort : après mise à jour, les possesseurs de tablette voient une table en face-à-face au lieu des quatre côtés, et doivent appliquer un preset une fois. Lisible partout, plutôt qu'illisible quelque part.
**Ruling 22 (final) : `kZoneHeaderHeight` passe de 40 à 48, mesuré comme `kActionWidth` l'a été.**
Motif : Important 2. `PlayerHeader` contient un `IconButton` Material nu ; `kMinInteractiveDimension` vaut 48. Mesuré : en-tête rendu de 40 px, bouton palette de 48 px, débordement de 8 px rogné par le `clipBehavior` de la zone. La cible tactile tombe à 48x40, sous le minimum, dans une refonte dont le ruling 16 dit que « 48 dp est la cible tactile minimale ». Les 8 px inférieurs sont absorbés par le `LifeDial` : le tap donne +1 PV au lieu d'ouvrir le sélecteur.
Cascade assumée : `kZoneShortEdgeFloor` 70 -> 78, `kSideColumnNeed` 96 -> 104. Vérifié : tablette portrait 820-208 = 612 >= 472, colonnes conservées ; le seuil de 600 reste sans colonnes, déjà le cas.
Coût si j'ai tort : le plancher monte de 8 px, donc quelques écrans limites basculent en face-à-face. Honnête, et cohérent avec le ruling 16.

---

## Résidus de la revue finale — assumés, non corrigés

Le protocole prévoit **une seule** vague de correction après la revue finale, puis une re-revue scopée. Ces trois points sont sortis de cette re-revue et sont assumés tels quels.

**R1 — le correctif du Critical 1 n'est gardé par aucun test. C'est le résidu qui compte.**
`_stepUnder` utilise désormais `globalToLocal`, ce qui est juste. Mais la re-revue a rejoué la mutation (retour à `localToGlobal(Offset.zero) & box.size`) et lancé **toute la suite : 1032 tests verts**, y compris les huit tests « sous rotation du siège ». Le rapport de la vague annonçait « 3 échecs sur 8 » — c'était faux.
Cause : les tests montent un `RotatedBox` **nu**, où le rectangle fantôme coïncide par chance avec le vrai. Une sonde montée sur une vraie `PlayerZone`, elle, attrape le défaut.
**Ce qu'il faut faire :** monter `PlayerZone` (ou au moins décentrer et redimensionner le `RotatedBox`) dans `life_dial_test.dart`, pour que la coïncidence cesse. Le produit est juste aujourd'hui ; rien n'empêche de le re-casser sans un seul test rouge — et c'est exactement le mécanisme qui a produit six tests menteurs dans ce lot.

**R2 — la cascade de `kZoneShortEdgeFloor` (70 → 78) déplace un seuil, hors des appareils réels.**
Matrice mesurée sur 11 tailles × 5 effectifs : **identique ligne pour ligne** avant et après. Mais la première largeur qui conserve les colonnes latérales passe de 664 à 680 px (chemin bande) et de 352 à 368 px (chemin hub). Un écran de 664 à 679 px de large avec un petit côté ≥ 600 — fenêtre d'écran partagé, pliable ouvert — perd ses colonnes. Aucun appareil standard dans cette fenêtre de 16 px.

**R3 — commentaire arithmétiquement faux**, `player_zone_density_test.dart:71` : « le petit côté (72) est sous `kZoneShortEdgeFloor` (70) ». Le plancher vaut 78, et la phrase était déjà fausse avant.

---

## Ce que la porte visuelle doit trancher

Aucun test ne peut répondre à ces questions. Elles sont la raison d'être de la porte.

1. **L'orientation réelle des zones après chaque preset, à 4, 5 et 6 joueurs.** Ces valeurs viennent d'être réécrites et n'ont jamais croisé un œil humain.
2. **Le mot « Table » à 3 et 7 joueurs**, où le bouton pose en fait un face-à-face parce que les deux coïncident à ces effectifs. Correct, potentiellement déroutant.
3. **Le chiffre de PV saute-t-il pendant un glissé vers un palier ?** `onLifeChanged` part à chaque pas de molette, donc la valeur bouge puis se corrige au relâchement. Les bulles ne mentent plus, le chiffre peut encore sauter (ruling 19).
4. **La rangée d'attribution qui apparaît brièvement entre deux sélections de palier** (ruling 17).
5. **L'état d'animation suit désormais le joueur et non sa case** lors d'un réordonnancement — conséquence de la clé d'identité, signalée par la session du lot 5, qu'aucun test ne voit.
6. **Le défilement du tiroir dans le pire cas** : 54,5 % du parcours pour atteindre « Tourner » à 7-8 joueurs. Mesuré acceptable, à sentir au pouce.
7. **L'overflow du `LifeDial` dans l'aperçu de glissement**, non reproduit et toujours inexpliqué.

## Mineurs reportés

Ces points ont été constatés, jugés non bloquants, et laissés en l'état. Ils sont triés par la revue finale de branche.

- minor (deferred): le test « 7 joueurs » n'éprouve que l'absence de siège latéral, pas le partage 3/4. Couvert indirectement par les tests de repli à 2 et 5 joueurs, qui exercent la même `_faceToFace`. Non bloquant.
- minor (deferred): aucun test ne vérifie que la rangée d'attribution reste ancrée juste au-dessus de la poignée à un cran non-confort (30 px au lieu de 48). Une ligne simple, faible valeur à tester isolément.
- minor (deferred): le seuil du test de défilement (75 %) est confortable plutôt que chirurgical — la mesure est à 62,2 %. Justifié : aucune position intermédiaire plausible entre 62 % et 100 % dans cette interface.
- ~~`isRotated` de `tapMinusHalf` ne reconnaît que `quarterTurns == 2`~~ — **RÉSOLU en T5** : le helper gère les quatre valeurs, et deux tests l'exercent sur des rotations impaires.
- minor (deferred): la couverture « toutes les zones montées » pour 2, 3, 5, 6 et 7 joueurs a disparu avec la réécriture du fichier de test.
- minor (deferred): le défaut d'overflow préexistant du LifeDial dans l'aperçu de glissement (documenté dans life_counter_page_test.dart) ne s'est pas reproduit sur 900x700 à 4 joueurs. Divergence inexpliquée, à revoir à la porte visuelle T8.
- minor (deferred): `shapeAllows` traite tout `largeur > hauteur` comme sûr sans regarder `shortEdge` : un écran très aplati (610x300) garde des colonnes latérales. Vérifié sain — la colonne y ferait 103 px, au-dessus du plancher — mais la règle est plus permissive que son intention. À revoir si un format extrême apparaît.
- minor (deferred): le bouton chrono et le surlignage du bouton édition gardent un style bespoke dans la bande, alors que le hub les rend uniformément. Cosmétique.
- minor (deferred): `unnecessary_import` de `dart:ui` dans `table_layout_test.dart` depuis l'ajout de `material.dart`. Nouveau lint non déclaré par le rapport.
- minor (deferred): le bouton chrono est un `InkWell`+`Container` de 50x50, pas un `IconButton` ; le garde-fou ne mesure qu'un `IconButton` générique et ne verrait pas une dérive propre à ce bouton. Antérieur à la tâche.
- minor (deferred): `isAdjusting` capturé à la construction dans la closure `onPointerUp` — si le doigt se lève dans le même tour de boucle que le déclenchement du timer d'appui long, le mode ne se referme pas. Fenêtre de quelques ms, hérité, non introduit par ce lot.
- minor (deferred): `if (_isEditMode) zone = DraggablePlayerZone(...)` dans `build()` est le MÊME motif d'enveloppement conditionnel. Aucun geste ne traverse cette bascule aujourd'hui. Même classe de défaut, à traiter si le glisser-déposer évolue.
- minor (deferred): le geste n'est couvert sur la page réelle que par UN test ; les 24 autres vivent sur le harnais minimal et resteraient verts si la page redevenait hostile autrement.
