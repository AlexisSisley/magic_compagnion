# Note pour la session du lot 4 — Setup

**Date :** 2026-09-16
**Émetteur :** session du lot 6 (table multijoueur)
**Destinataire :** la session qui exécutera le lot 4
**Spec :** `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md` §2.8 et §3.3

Le lot 4 démarre après le merge du lot 6. Voici ce qu'il trouvera changé, et les trois dettes qui l'attendent nommément.

---

## 1. La dette qui t'appartient, et que personne d'autre ne peut solder

### Le toggle « Timer de partie »

La spec V4 §3.2 l'a **délibérément reporté au lot 4** : le réglage existe dans `GameSetupModal` mais n'a jamais été transmis à la page. Le câbler à travers un modal que ce lot supprime aurait été du travail jeté. C'est maintenant à toi, et c'est écrit dans la spec, pas dans une liste de constats mineurs.

### Les parties « Standard » à deux comportements

**C'est le point le plus important de cette note.** Le lot 3 a corrigé un défaut réel : `maxCommanderDamage` valait 21 par défaut sans qu'aucun preset ne le surcharge, si bien qu'en Standard un joueur pouvait être déclaré mort par des dégâts de commandant qui n'existent pas dans ce format.

La correction ne s'applique qu'aux parties **neuves**. Une partie Standard sauvegardée avant le lot 3 garde `21` dans son snapshot et affiche encore la grille de commander damage. Deux parties du même format se comportent donc différemment selon leur date de création.

La session du lot 3 a explicitement renvoyé l'arbitrage ici, parce que c'est le lot qui refait le setup et la reprise de partie. Trois options, à trancher avec l'utilisateur :

1. **Migration au chargement** — le snapshot recalcule `maxCommanderDamage` depuis son format. Propre, mais écrase un réglage Custom volontaire.
2. **Migration seulement si le format n'est pas Custom** — plus sûr, plus de code.
3. **Ne rien faire** — les vieilles parties finissent, le problème s'éteint de lui-même. Défendable si la reprise en un tap (§2.8) ne ressuscite que la dernière partie.

Ne choisis pas seul : c'est un arbitrage produit, pas technique.

### Le réordonnancement par glisser-déposer

L'aperçu de glissement fige la zone à 130 px, ce qui rend le vrai geste intestable en widget test. Reporté depuis le lot 3, **passé en critère de sortie du lot 6** parce que ce lot place des zones sur quatre côtés. Si le lot 6 l'a soldé, cette ligne ne te concerne plus — vérifie le journal du lot 6 avant de t'en inquiéter.

---

## 2. Ce que le lot 6 change pour toi

Le lot 4 fait de la table **l'écran de configuration** (§2.8, setup inline). Il hérite donc directement de la géométrie du lot 6.

- **`seatsFor(playerCount)` (`lib/models/table_seat.dart`) décide de la disposition.** Ton setup inline doit y poser ses cases de joueur, pas réinventer un placement. Un « + » qui ajoute un joueur change le nombre de joueurs, donc **change les sièges de tout le monde** — c'est la propriété à éprouver en premier, et elle est visible : à 3 joueurs on est en face-à-face, à 4 tout le monde bascule sur les quatre côtés.
- **`AdaptiveGrid` ne décide plus rien.** Si tu as besoin d'une disposition particulière pour le setup, elle se décide dans `seatsFor`, jamais dans la grille.
- **La rotation initiale est posée par `GameSession.newGame`** depuis le siège. La rotation choisie par un joueur gagne ensuite et est persistée : ne l'écrase pas en repassant par le setup.
- **Le contrat de densité** (`lib/widgets/life_counter/layouts/density_tier.dart`) décide de ce qu'une zone affiche. En cran minimal, une zone n'affiche que les PV : si ton setup inline veut afficher un nom ou un sélecteur de profil dans la case, il devra le faire **hors** du contrat de densité, ou assumer qu'il disparaît à 7-8 joueurs.
- **La poignée ne descend jamais sous 30 px** et reste le seul point d'entrée du tiroir, quel que soit le cran. C'est une décision corrigée en cours de route, après que la première version de la spec du lot 6 proposait de la supprimer en cran minimal.

**Ce que le lot 6 ne touche pas :** `GameSetupModal`, `GameSetupController`, `StatsTab`, les profils, l'artwork Scryfall, la persistance Drift. Tout le périmètre du lot 4 est intact.

---

## 3. Les règles de travail que les lots 1 à 3 ont payées

Reprends-les telles quelles, elles ne sont pas négociables :

1. **`git add` avec chemins explicites.** Jamais `git add -A`, jamais `git commit -a`. Le dépôt est partagé entre sessions ; un `add -A` a failli embarquer les documents d'une autre session dans un commit de correction.
2. **Les gestes se jouent, ils ne se simulent pas.** `tester.tap(...)`, jamais un appel direct au callback. C'est ce qui a révélé qu'`EliminationOverlay` absorbait tous les gestes d'une zone éliminée — défaut invisible pendant tout le cycle V3.
3. **Un glissement se livre en incréments**, jamais en un `PointerMoveEvent` unique.
4. **Tout test de non-régression doit être vérifié discriminant** : casse temporairement le code qu'il protège, vérifie qu'il échoue, rétablis.
5. **Les tests de widgets se décrivent par leurs assertions dans les plans, pas en code verbatim.** Le code de test écrit de mémoire a produit **six défauts de compilation** sur les lots 1 et 2 ; le lot 3 est passé aux assertions décrites et n'en a eu aucun. Le plan du lot 6 lui-même en contenait deux, trouvés à la relecture — `GameSession.newGame(playerCount:)` alors que la factory prend `playerConfigs`, et `CriticalOverlay(level: 2)` alors que `level` est un `enum`.
6. **Aucun nouveau geste global** sans le demander d'abord. La surface de gestes de `life_dial.dart` a coûté trois rondes de correction et quatre constats Critical.

---

## 4. Si tu ne dois retenir qu'une chose

Sur trois lots, **aucun des défauts les plus coûteux n'a été trouvé par une revue de code.** Ils l'ont été en remplaçant un appel de callback par un vrai `tester.tap()`, en livrant un glissement en incréments plutôt qu'en un bloc, et en lisant une signature au lieu de l'écrire de mémoire.

Le lot 4 touche au setup, donc à des formulaires et à des listes — moins de surface tactile, mais exactement la même règle : ce que le test ne joue pas, il ne le prouve pas.

---

# Mise à jour — le lot 6 est livré

**Ajoutée le 2026-09-16, après exécution complète du lot 6.**

Les sections ci-dessus ont été écrites AVANT le lot 6, au futur. Voici ce qui a réellement été livré, et ce qui a changé par rapport à ce qui était annoncé.

## État de la branche

`feat/life-counter-v4-lot6-table-multijoueur`, 21 commits depuis `main` à `6458d7c`. **987 tests verts** (846 au départ du lot), `flutter analyze` sans erreur ni avertissement nouveau. Revue finale de branche en cours au moment où ces lignes sont écrites — **ne démarre pas le lot 4 sur `main` avant que le lot 6 y soit mergé**, sinon tu câbleras ton setup inline sur une géométrie qui n'existe plus.

## Ce qui a été livré, tâche par tâche

1. **`lib/models/table_seat.dart`** — `TableSide`, `TableSeat`, `seatsFor(playerCount)`. Fonction pure, seul endroit où la disposition se décide.
2. **`AdaptiveGrid` est devenue purement positionnelle.** Elle ne contient plus AUCUNE `RotatedBox`, et un test verrouille cette absence.
3. **`GameSession.newGame` pose la rotation du siège** dans `PlayerState.quarterTurns`, plus `_migrateLegacyRotation` pour les snapshots antérieurs.
4. **`lib/widgets/life_counter/layouts/density_tier.dart`** — `DensityTier`, `tierFor(Size)`, `handleHeightFor(tier)`, `kZoneHeightFloor`.
5. **La couche d'alerte perce à tous les crans**, étendue au poison et aux dégâts de commandant.
6. **Le badge de dégâts en attente** est rendu dans le repère pivoté de la zone.
7. **Le nombre flottant qui restait affiché indéfiniment** est corrigé — bug signalé par l'utilisateur en cours de lot.

## Le piège n°1 pour toi : la rotation n'a qu'un seul propriétaire

**`PlayerZone` applique la rotation, via `RotatedBox(quarterTurns: widget.player.quarterTurns)`. Personne d'autre.**

C'est la décision structurante du lot, et elle a coûté cher à établir. Le plan d'origine faisait rotationner la grille ET posait la rotation du siège dans l'état du joueur : un joueur du haut aurait cumulé 180° + 180° = 360°, table exactement à l'envers de l'intention, **avec tous les tests verts**. Si ton setup inline ajoute une rotation quelque part, tu reproduiras ce défaut.

Convention, écrite noir sur blanc : `RotatedBox` tourne dans le sens **horaire**, le haut du texte d'un joueur pointe **à l'opposé** de lui. Donc bas=0, gauche=1, haut=2, droite=3.

## Le piège n°2 : l'ordre de l'arbre n'est plus l'ordre d'affichage

À 4 joueurs la grille produit `Row[colonne gauche, colonne centrale, colonne droite]`. La première `PlayerZone` de l'arbre n'est donc PAS le joueur affiché en premier.

**Ce seul point a coûté sept rondes de correction.** Le fichier `test/pages/life_counter/life_counter_page_test.dart` contenait neuf repérages ordinaux (`.first`, `.last`, `.at(n)`) qui supposaient l'inverse, et ils se sont révélés un par un.

Règles qui en découlent, à appliquer sans exception dans le lot 4 :
- **Tout test qui désigne un joueur le fait par sa clé d'identité** : `ValueKey('player_zone_<playerId>')`.
- **Toute position de tap se joue sur le widget par sa clé**, jamais sur un offset calculé — `ValueKey('life_dial_half_minus')` / `'life_dial_half_plus'`. Même quand le `RenderBox` est sous la main et que le calcul paraît juste : sous rotation de 90°, inverser gauche et droite ne suffit pas.
- Un helper qui a besoin de l'ordre d'affichage le récupère par `session.playerOrder[index]`, pas par la position dans l'arbre.

## Ce que ton setup inline doit respecter

- **`seatsFor(playerCount)` décide de la disposition.** Pose tes cases de joueur dessus, ne réinvente pas un placement.
- **Un « + » qui ajoute un joueur change les sièges de TOUT LE MONDE.** C'est la propriété à éprouver en premier, et elle est visible : à 3 joueurs on est en face-à-face, à 4 tout le monde bascule sur les quatre côtés.
- **La rotation du siège n'est qu'un défaut.** Une rotation choisie par un joueur est persistée et doit gagner : ne l'écrase pas en repassant par le setup.
- **Au cran minimal, une zone n'affiche que les PV.** Si ton setup veut montrer un nom ou un sélecteur de profil dans la case, il devra le faire hors du contrat de densité, ou assumer sa disparition à 7-8 joueurs.
- **La poignée du tiroir ne descend jamais sous 30 px** et reste le seul point d'entrée du tiroir, quel que soit le cran.

## Dettes que le lot 6 te laisse, honnêtement

Aucune n'est bloquante, toutes sont au journal `.superpowers/sdd/2026-09-16-life-counter-v4-lot6-table-multijoueur/progress.md` :

- `kZoneHeightFloor = 70.0` est un littéral figé (en-tête 40 + poignée 30) au lieu d'être dérivé de `handleHeightFor(DensityTier.minimal) + _headerHeight`. Si l'une des deux valeurs change, rien ne force le plancher à suivre, et aucun test ne les lie.
- `kZoneHeightFloor` est nommé « hauteur » mais sert aussi de largeur minimale de colonne latérale — correct géométriquement (largeur avant rotation = hauteur après), mais le nom ne le dit pas.
- `CriticalOverlay` boucle son animation indéfiniment au niveau létal : `pumpAndSettle` expire sur une zone en alerte. Contourne par des `pump()` bornés, comme le fait déjà le glow du monarque.
- Deux `tapAt(Offset(dial.left + dial.width * 0.25, ...))` subsistent dans `player_zone_test.dart` (~105 et ~181). Corrects aujourd'hui — ces tests montent un joueur non pivoté — mais c'est le motif éliminé neuf fois ailleurs.

## Vérifications manuelles qui restent dues

Elles ne sont PAS une formalité, et le lot 6 n'est pas clos sans elles :

- À 4 joueurs, appareil posé à plat : depuis chaque siège, le chiffre se lit à l'endroit, la moitié gauche décrémente et la droite incrémente **telles que ce joueur les voit**, la poignée s'atteint au doigt, le badge apparaît à l'endroit sur les deux sièges latéraux.
- À 8 joueurs sur petit écran : le cran minimal reste lisible et la poignée atteignable.
- Le glisser-déposer aux quatre orientations — reporté depuis le lot 3, où l'aperçu de glissement fige la zone à 130 px et rend le vrai geste intestable en widget test.
