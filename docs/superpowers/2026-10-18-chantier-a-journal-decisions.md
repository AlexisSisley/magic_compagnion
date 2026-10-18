# SDD ledger — plan: docs/superpowers/plans/2026-10-18-chantier-a-life-counter.md

Spec: docs/superpowers/specs/2026-10-18-mythic-moxfield-design.md (lue)
Worktree: .claude/worktrees/life-counter-chantier-a, branche worktree-life-counter-chantier-a
Base: 2d3d633 (main local mergé en ff, spec + plan présents)
oracle-cards.json : lien dur créé (166 Mo), sans quoi le build d'assets casse.

## Scan de pré-vol

### Paires de tâches partageant un fichier ou une interface

| A | B | Fichier / interface partagé | A produit | B consomme | Constat |
|---|---|---|---|---|---|
| T2 | T5 | `zone/life_dial.dart` | T2 déplace `kLongPressTimeout` vers `tuning.dart` | T5 ajoute l'état de pression et les repères | Pas de conflit : séquentiel, zones du fichier disjointes. T5 doit importer `../tuning.dart`, déjà fait par T2. |
| T2 | T6 | `tuning.dart` → `kDamageBufferWindow` | T2 définit la constante | T6 l'utilise pour la fenêtre d'accumulation | Cohérent. T6 strictement après T2. |
| T3 | T4 | `TableSeat.quarterTurns`, `seatsForArrangement` | T3 produit l'arrangement et les sièges | T4 sème les rotations depuis ces sièges | Cohérent. |
| T3 | T8 | `table_layout.dart` → `kActionCount` | T3 touche `barKind`, `kSideColumnNeed` | T8 passe `kActionCount` 9 → 10 | Pas de conflit : lignes distinctes. T8 doit relire le fichier après T3. |
| T4 | T8 | `game_session_notifier.dart` | T4 ajoute `seedRotationsFromSeats` | T8 ajoute `applyOrientationPreset` | Pas de conflit. Mais voir Ruling 3. |
| T4 | T8 | `life_counter_page.dart` | T4 ajoute l'appel post-frame | T8 ajoute `_isReorganising` et la barre | Pas de conflit : zones distinctes du `build`. |
| T6 | T7 | `player_zone.dart` | T6 monte `PendingDelta` et appelle `accumulate` | T7 propage `quarterTurns` aux deux modales | Pas de conflit. |
| T1 | T6 | `app_colors.dart` | T1 n'y touche pas | T6 ajoute `feedbackDanger`/`feedbackSuccess` | Pas de conflit. Le grep de T1 ne couvre que les chemins contenant `life_counter` ; `app_colors.dart` en est exclu, donc ses `Colors.*` ne déclenchent pas de faux positif. |

### Cohérence interne de chaque tâche

| Tâche | Ses tests contre son code | Ses fichiers contre ceux qu'elle touche ensuite | Constat |
|---|---|---|---|
| T1 | Le grep exige l'absence de `Colors.*.shade800\|900` sous `life_counter` ; les steps 5-6 retirent les deux listes | `player_skins.dart` créé puis importé par les deux fichiers modifiés | Cohérent |
| T2 | Les bornes du test encadrent les valeurs écrites au step 3 | — | Cohérent |
| T3 | `arrangementFor(390×844,4)=columnPairs` / `(840×700,4)=faceToFace` correspond à `zone.height > zone.width` | `kSideColumnNeed` relevé au step 6, utilisé au step 5 | **Défaut 1** (voir Ruling 1) |
| T4 | La table `expected` reproduit la convention de `TableSeat.quarterTurns` | — | Cohérent |
| T5 | Les clés `life-dial-highlight-*` du test sont celles posées au step 4 | — | **Défaut 2** (voir Ruling 2) |
| T6 | Les quatre tests couvrent cumul, annulation, expiration, relance | `pending_delta.dart` créé puis monté au step 7 | Cohérent |
| T7 | Les deux tests couvrent siège retourné et siège du bas | — | Cohérent |
| T8 | Les deux tests couvrent inertie hors mode et présence du sélecteur | `kActionCount` modifié au step 7 | Cohérent |

### Rulings de pré-vol

Ruling 1: l'extrait de test de T3 utilise `tierFor`, `DensityTier` et `ActionBarKind` sans les importer — Décision : défaut de rédaction du plan, pas de conception ; l'implémenteur ajoute `import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';` et l'import de `table_layout.dart` qui porte déjà `ActionBarKind`. Coût si faux : nul, l'erreur de compilation le dirait immédiatement.

Ruling 2: T5 ne relève pas la signature réelle de `LifeDial` — Décision : le plan le dit déjà explicitement et demande de l'ouvrir avant de lancer ; je laisse la note telle quelle plutôt que de la résoudre ici, parce que la lire coûte un fichier à l'implémenteur et zéro à moi. Coût si faux : un aller-retour de compilation dans la tâche 5.

Ruling 3: `seatsFor(n)` reste une façade publique alors que `seatsForArrangement` devient le vrai point d'entrée — Décision : garder `seatsFor` inchangée pour ne casser aucun appelant existant, et faire vérifier par T3 qu'aucun appelant hors `tableLayoutFor` ne dépend des colonnes à 4 joueurs. Coût si faux : un appelant oublié conserve l'ancienne géométrie, ce que les tests d'équité de T3 ne verraient pas s'il vit hors de `tableLayoutFor`.

---

## Progression

### Tâche 1

- Baseline avant tâche : 1432 tests, 6 skippés, vert. BASE = 2d3d633.
- Implémenteur (sonnet) → DONE_WITH_CONCERNS, commit dd1f4d3, 1435 tests / 6 skippés, analyze inchangé (166 issues préexistantes).
- 4 préoccupations remontées. Le plan annonçait 2 listes de couleurs divergentes ; il y en a 5.

Ruling 4: `lib/providers/game_setup_notifier.dart` (lignes 105-112) porte une liste de couleurs de joueur en littéraux hexadécimaux, avec les noms Material en commentaire — invisible au garde-fou du plan, qui cherche `Colors.*.shade*`. Décision : la basculer sur `kPlayerSkins` et étendre le test à cette forme, contre le périmètre écrit du brief. Motif : un garde-fou aveugle à la forme la plus répandue du défaut ne garde rien, et la tâche 1 manquerait sa cible — la tâche 8 (presets d'orientation) hériterait alors d'une attribution de couleurs incohérente. Coût si faux : périmètre de la tâche 1 élargi d'un fichier, et un test plus bavard à maintenir.

Ruling 5: `lib/pages/life_counter/game_history_page.dart` conserve le passage de `Colors.red.shade900` à `AppColors.error` (fond de swipe-to-delete, pas une couleur de joueur), fait par l'implémenteur sur faux positif du garde-fou. Décision : garder. Motif : un littéral remplacé par un jeton existant est une amélioration ; le revert coûte plus qu'il ne rapporte. Coût si faux : une nuance de rouge change sur l'écran d'historique — visible, trivialement réversible.

Ruling 6: les cibles tactiles 48x48 ajoutées aux deux galeries de couleurs sont conservées, bien qu'absentes du brief. Motif : contrainte globale explicite du plan ; son absence du brief était un oubli de rédaction. Coût si faux : nul.

- Fix round 1/5 dispatché (resume de l'implémenteur) : Rulings 4-6 + question sur le chemin réel d'attribution des couleurs au démarrage d'une partie.
- Fix round 1/5 rendu : commit b0b1766, 1436 tests / 6 skippés, analyze inchangé. Rulings 4-6 appliqués. Réponse à la question : `kPlayerSkins` n'était PAS la source effective du chemin principal.

Ruling 7: `lib/pages/play/play_setup_page.dart._couleursParDefaut` entre dans le périmètre de la tâche 1, contre le brief. Vérifié par moi-même, pas sur parole de l'agent : `AppRoutes.playSetup` est documenté (`app_routes.dart:25`) comme l'entrée du mode Jeu ; les quatre valeurs sont des Material **500** (`0xFF4CAF50` = vert Material 500), les plus saturées du dépôt, donc très probablement celles que l'utilisateur a décrites comme « un crapaud venimeux » ; et le doc-comment « alignees sur celles de LifeCounterPage » est devenu faux au commit dd1f4d3. Décision : brancher sur `kPlayerSkins` et étendre le garde-fou à la forme `<int>[...]` sans annotation. Motif : sans cela, le chantier entier ne change rien à ce que l'utilisateur voit en démarrant une partie — son but unique. Coût si faux : la tâche 1 touche deux fichiers hors de son périmètre écrit, dans une page de configuration que le reste du chantier ne retouche pas.

Ruling 8: `lib/pages/settings/profile_management_page.dart._defaultColors` entre aussi dans le périmètre. Motif : la couleur d'un profil DEVIENT la couleur de sa zone (`profils[i]?.colorValue`, lu juste au-dessus de `_couleursParDefaut`) ; une palette Material dans les Réglages et une palette Grimoire en partie recréeraient la divergence que cette tâche supprime. Coût si faux : un écran de Réglages change de palette sans que la spec l'ait demandé.

Ruling 9: `lib/data/migration/migration_service.dart:222` reste inchangé. Motif : repli dans une migration one-shot de données déjà écrites ; changer la couleur attribuée rétroactivement réécrirait l'historique de parties de l'utilisateur pour un gain nul. Documenté dans le doc-comment du test pour qu'il ne soit pas « corrigé » par réflexe. Coût si faux : d'anciennes parties gardent une couleur Material dans l'historique.

- Fix round 2/5 dispatché : Rulings 7-9 + demande de la liste exhaustive des chemins d'attribution de couleur.
- Fix round 2/5 rendu : commit 8de050b, 1437 tests / 6 skippés, analyze inchangé. Liste exhaustive fournie : tous les chemins qui DÉCIDENT d'une couleur par défaut sont branchés sur `kPlayerSkins`. Le garde-fou couvre désormais 3 formes de déclaration, en noms anglais et français.

Ruling 10: `lib/models/player_config.dart:85` et `lib/models/profile_model.dart:78` (replis `?? 0xFF2196F3` en désérialisation, bleu Material 500) restent inchangés. Vérifié moi-même. Décision : ne pas les brancher. Motif : `player_skins.dart` vit dans `lib/widgets/` ; brancher ces replis ferait importer `lib/widgets/` par `lib/models/`, une inversion de couches qui coûte plus cher que le défaut qu'elle corrige — un repli qui ne se déclenche que sur une donnée dont le champ `colorValue` manque. Coût si faux : une zone affiche un bleu Material criard au milieu de zones Grimoire, uniquement sur une donnée corrompue ou issue d'un schéma plus ancien.

- Note de dette (pas un ruling) : `game_setup_notifier.defaultProfileColorValues` est branché sur `kPlayerSkins` mais serait du code mort selon l'implémenteur (zéro appelant hors de son test). À confirmer en relecture ; si avéré, candidat à suppression hors de ce chantier.
- Relecture de tâche dispatchée (sonnet) : diff 2d3d633..8de050b, 12 fichiers, +302/-112.
- Relecture rendue : SPEC conforme. QUALITÉ à corriger — 1 critique, 2 importants, 2 mineurs. Le relecteur a vérifié par recherche directe (pas sur parole du rapport) que `defaultProfileColorValues` est bien du code mort et que `profile_management_page.dart` ne contient plus de couleur en dur.

Ruling 11: le filtre `entity.path.contains('life_counter')` du test 1 est retiré ; les trois gardes scannent le même périmètre (tout `lib/`), avec des exemptions NOMMÉES et commentées à la place. Motif : le filtre laissait `lib/pages/settings/profile_management_page.dart` — le fichier que la tâche venait de corriger — sans aucune protection contre la réintroduction du bug d'origine sous sa forme d'origine. Une exemption nommée documente un choix ; un filtre de chemin cache un trou. Coût si faux : le test devient bavard et réclame une exemption de plus à chaque palette non liée aux joueurs.

Ruling 12: la 4e forme (littéral scalaire hors liste) est gardée sur le DOMAINE, pas sur le chemin : tout fichier de `lib/` mentionnant `colorValue`, `PlayerSkin` ou `kPlayerSkins` ne doit pas contenir de littéral de couleur, sauf quatre exemptions commentées (`player_skins.dart`, `player_config.dart`, `profile_model.dart`, `migration_service.dart`). Motif : couvrir cette forme sur tout `lib/` sans critère noierait le test sous les faux positifs ; la restreindre par chemin recréerait le trou du Ruling 11. Coût si faux : un fichier manipulant `colorValue` se voit refuser un littéral de couleur légitime et réclame une exemption.

Ruling 13: l'assertion `'first color matches kPlayerSkins first entry'` de `game_setup_notifier_test.dart` est remplacée par la valeur Grimoire figée en dur. Motif : `defaultProfileColorValues` EST `kPlayerSkins.map(...)` ; comparer l'élément 0 du mapping à l'élément 0 de la source ne teste presque rien. Un test a le devoir de figer ce que le code produit. Coût si faux : le test devra être mis à jour si la première teinte change — ce qui est précisément son rôle.

- Mineur (différé, pas corrigé) : `defaultSkinForSeat(1)` est utilisé comme couleur de nouveau profil dans `game_setup_modal.dart` (~614, ~720) et `profile_management_page.dart` (~257) ; le nom de la fonction, indexée par siège, ment un peu sur cet appel. À trier par la revue finale.
- Non vérifiable depuis le diff, à porter à la validation visuelle : rendu des 4 galeries après passage des cibles à 48x48 (le disque du skin picker passe de 45 à 48), et rendu d'`AppColors.error` dans `game_history_page.dart`.
- Fix round 3/5 dispatché : Rulings 11-13.
- Fix round 3/5 rendu : commit f9d5d13, 1438 tests / 6 skippés, analyze inchangé. Rulings 11-13 appliqués. 21 exemptions nommées issues d'un run réel du test, pas d'une liste devinée. Effet de bord amusant et révélateur : un commentaire de l'implémenteur citant littéralement « Colors.red.shade900 » se faisait flaguer par son propre garde.

Ruling 14: les deux exemptions Drift ajoutées de son chef par l'implémenteur (`app_database.dart`, `app_database.g.dart`) sont acceptées, portant le compte à six au lieu des quatre que j'avais nommées. Motif : ce sont des défauts de colonnes ; les changer exigerait une migration de schéma, exactement le raisonnement des Rulings 9 et 10. Un fichier généré (`.g.dart`) n'est de toute façon pas un endroit où corriger quoi que ce soit à la main. Coût si faux : deux défauts de colonne gardent une couleur Material, visible seulement sur une ligne créée sans couleur explicite.

Ruling 15: le passage de `Player.colorValue` de `= 0xFF000000` à `required` (`lib/models/player_model.dart:61`) est accepté, bien que demandé nulle part. Vérifié moi-même : un seul site construit un `Player` (`life_counter_page.dart:196`, via `_toLegacyPlayer`), et il fournit la valeur. Motif : un défaut noir jamais lu est un piège silencieux ; `required` le supprime à coût nul. Coût si faux : un futur appelant devra fournir le champ — ce qui est le but.

- Re-relecture ciblée dispatchée sur le diff du correctif (8de050b..f9d5d13).
- Re-relecture rendue : les 3 constats TRAITÉS, aucune casse nouvelle. Le relecteur a relu le contenu réel des 21 exemptions : aucune ne touche à une couleur de joueur. Changements (a) et (b) jugés acceptable et sûr, avec vérification indépendante des deux.

Ruling 16: la limite structurelle du garde par domaine est acceptée, pas corrigée. Le relecteur montre qu'on peut le contourner en scindant déclaration et usage entre deux fichiers (le littéral dans un fichier sans marqueur de domaine, l'affectation dans un fichier sans littéral). Décision : ne pas couvrir ce cas. Motif : le couvrir exigerait une analyse inter-fichiers avec résolution d'imports, disproportionnée face à un défaut qui ne survient pas par accident — on ne scinde pas une constante en deux fichiers par distraction. Coût si faux : une couleur de joueur introduite délibérément de cette façon échapperait au garde.

- Mineur différé : l'exemption est par FICHIER et non par ligne ; une valeur ajoutée plus tard dans un fichier exempté échapperait au garde. Même mode pour les six. À trier par la revue finale.

Tâche 1: complete (commits 2d3d633..f9d5d13, 4 commits, re-relecture propre, 2 mineurs différés)

### Tâche 2

- BASE = f9d5d13. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, commit 18ae270, 1439 tests / 6 skippés, analyze inchangé. Trois écarts entre le brief et le code réel signalés au lieu d'être masqués.

Ruling 17: `kLongPressTimeout` vaut 500 ms, pas les 350 ms de mon plan. Motif : la définition locale que le brief disait « sortir » n'a jamais existé — `life_dial.dart` dépendait implicitement de la constante du SDK Flutter (500 ms). Les 350 ms étaient une valeur que j'avais inventée en rédigeant le plan. Une tâche de regroupement ne doit pas changer la sensation sous le doigt. L'implémenteur a résolu la collision de noms par `hide kLongPressTimeout` sur l'import `gestures.dart` — bonne réponse. Coût si faux : nul, c'est le comportement actuel qui est préservé.

Ruling 18: `kWheelPixelsPerStep` et `kWheelAcceleration` sont supprimées et remplacées par les VRAIES constantes, déplacées depuis `player_zone_notifier.dart:78,81` (`wheelPixelsPerUnit = 8.0`, `wheelAccelerationThreshold = 120.0`). Motif : mes deux constantes étaient inventées et supposaient un facteur d'accélération continu, alors que le code fait un seuil puis un doublement. Un fichier de calibrage qui expose des réglages fictifs pendant que les vrais restent dispersés est précisément l'échec que la tâche devait corriger — même piège qu'à la tâche 1. Coût si faux : la tâche 2 touche `player_zone_notifier.dart`, hors de son périmètre écrit, un fichier que la tâche 6 retouchera.

- Fix round 1/5 dispatché : Rulings 17-18.
- Fix round 1/5 rendu : DONE, commit f614e63, 1439 tests / 6 skippés, analyze inchangé. Les vraies constantes sont dans `tuning.dart`, aucune ligne de logique de `handleWheelDrag` touchée, aucun test ne référençait le chemin de classe. Origine de 8.0 et 120.0 : recherchée dans l'historique git, introuvable — signalé comme inconnu dans le doc-comment, ce qui est exactement ce que ce fichier doit rendre visible.

Ruling 19: le facteur de doublement `* 2` de `handleWheelDrag` est extrait lui aussi, en `wheelAcceleratedMultiplier`. Motif : la spec §1.6 nomme « sensibilité ET accélération » parmi les réglages à rendre calibrables ; avec le seuil sorti mais le facteur en dur, on peut régler à partir de quand ça accélère, pas de combien. Un réglage à moitié sorti ne se retrouve pas six mois plus tard. Coût si faux : une ligne de plus dans `handleWheelDrag`, logique inchangée.

- Fix round 2/5 dispatché : Ruling 19.
- Fix round 2/5 rendu : DONE, commit 4f5a8bd, 1439 tests / 6 skippés, analyze inchangé. Écart signalé et accepté : le littéral `2` existait à DEUX endroits mathématiquement couplés dans `handleWheelDrag` (conversion en avant et son inverse pour le résidu) ; substituer un seul aurait fait dériver le reliquat d'un geste à l'autre le jour où la constante change. Substitution aux deux. Origine de 2.0 cherchée dans l'historique (commit 4612cbb3) : le commit justifie l'existence d'une accélération, jamais le choix de doubler — signalée inconnue, comme 8.0 et 120.0.
- Relecture de tâche dispatchée (sonnet) : diff f9d5d13..4f5a8bd. Point prioritaire demandé : vérifier QUELLE constante `kLongPressTimeout` est effectivement liée au `Timer` de `life_dial.dart` — celle de `tuning.dart` ou celle du SDK. Les deux valent 500 ms, donc un test vert ne prouve rien ; si c'est la mauvaise qui est liée, calibrer n'aurait aucun effet et personne ne le verrait.
- Relecture rendue : SPEC conforme, QUALITÉ approuvée. 1 important, 2 mineurs. Réponse au point prioritaire : c'est bien la constante de `tuning.dart` qui est liée — preuve STRUCTURELLE, pas comportementale : `kLongPressTimeout` n'est défini que dans `gestures/constants.dart` et exporté par le seul `gestures.dart` ; ni `material.dart` ni `widgets.dart` ne le réexportent (exports du SDK 3.35.6 vérifiés directement). Le `hide` suffit. Les deux substitutions du facteur dans `handleWheelDrag` sont mathématiquement identiques à l'original (`*2` et `/2` en Dart donnent le même double), vérifié en plus par exécution ciblée des 17 tests de `player_zone_notifier_test.dart`, dont le test Critical d'accélération. Doc-comments jugés honnêtes : les deux commits cités (276719d4, 4612cbb3) ont été vérifiés réels par `git show`.

Ruling 20: les trois fichiers de test qui importent `kLongPressTimeout` depuis `package:flutter/gestures.dart` (`life_dial_test.dart`, `player_zone_test.dart`, `life_counter_page_test.dart`) sont repointés sur `tuning.dart`. Motif : aujourd'hui les deux constantes valent 500 ms et rien ne se voit ; au premier recalibrage réel — ce que ce fichier existe pour permettre — ces tests attendraient 500 ms pendant que le widget déclencherait sur la nouvelle valeur, produisant des échecs sans rapport apparent avec la cause. Coût si faux : trois imports modifiés, aucune assertion touchée.

- Fix round 3/5 dispatché : Ruling 20 + avertissement à ajouter au doc-comment.
- Fix round 3/5 rendu : DONE, commit 9c1b9c4, 108 tests ciblés + suite complète 1439 / 6 skippés, analyze inchangé. Aucun `hide` nécessaire : les trois fichiers n'utilisaient aucun autre symbole réel de `gestures.dart`.
- Re-relecture ciblée (haiku) : correctif ADRESSÉ, aucune casse. Imports seuls modifiés, doc-comment protecteur en place, aucun symbole résiduel de `gestures.dart` utilisé pour de vrai.

Tâche 2: complete (commits f9d5d13..9c1b9c4, 4 commits, re-relecture propre, 0 parké)

### Tâche 3

- BASE = 9c1b9c4. Implémenteur dispatché (sonnet). Rulings de pré-vol 1 et 3 transmis dans le dispatch (imports manquants dans l'extrait de test ; vérifier les appelants de `seatsFor`).
- Trois questions posées pour le rapport : les rotations obtenues à 4 joueurs en 390x844 et 840x700 ; un éventuel appelant de `seatsFor` dépendant des colonnes à 4 joueurs ; l'effet du changement de `barKind` sur les cas à 2 et 5-6 joueurs.
- Rendu : DONE_WITH_CONCERNS, AUCUN commit (suite non verte : 1422/6/14). L'implémenteur s'est arrêté avant de réécrire 14 tests sans mandat — exactement ce qui lui était demandé. Discriminance de la règle du grand côté prouvée : inversion de la comparaison → exactement 2 échecs nommant 390x844 et 840x700.

Ruling 21: l'étape 3bis (restriction de `barKind`) est ABANDONNÉE, et la spec §1.2 amendée en conséquence. C'était MON ajout, fait en relisant mon propre plan, et il était faux. Motif : le raisonnement « la bande coupe la table et vole de la hauteur » venait d'une capture où la table était inéquitable (67 % / 13 %) ; une fois le §1.1 appliqué et les zones égalisées, la bande retire la même hauteur à chacun et ne lèse personne. Le défaut tenait à l'inéquité, pas à la bande. Coût de l'erreur si elle était passée : la bande porte l'affichage permanent du chrono de partie, supprimé à 3 et 4 joueurs — les effectifs Commander les plus courants — sans mandat, et sur un élément qui ne figurait pas sur la maquette validée par l'utilisateur. Les 14 tests en échec redeviennent verts d'eux-mêmes ; aucun ne sera réécrit. Coût si faux : la bande reste présente à 3-4 joueurs sur grand écran, ce que la maquette validée ne montrait pas.

Ruling 22: la correction d'`adaptive_grid.dart`, hors du périmètre écrit du brief, est acceptée. Motif : sans elle, l'arrangement `columnPairs` faisait disparaître les quatre joueurs de l'écran replié — une régression bien pire que le défaut d'origine. Livrer une disposition sans le rendu qui sait l'afficher n'a pas de sens. Coût si faux : un fichier de plus dans le diff de la tâche 3, à juger par le relecteur sur pièces.

- Fix round 1/5 dispatché : Rulings 21-22.
- Fix round 1/5 rendu : DONE, commit 5700ace, suite complète 1448 / 6 skippés / 0 échec, analyze inchangé.
  - Ruling 21 appliqué : `barKind` restauré. 8 des 14 tests rouges sont redevenus verts seuls, comme prévu.
  - Les 6 restants n'étaient PAS causés par mon étape 3bis mais par l'équité des surfaces elle-même : ils encodaient l'ancien modèle à colonnes latérales permanentes à 4 joueurs. Mis à jour sans suppression.
  - Affinage d'`adaptive_grid.dart` : sa PREMIÈRE correction forçait le hub partout où `columnPairs` s'applique, ce qui coupait silencieusement la bande — donc le chrono — sur un écran réel de 600x900 à 4 joueurs. C'est précisément la dégradation silencieuse que la spec table multijoueur v2 §4.3 interdit. La bande se loge désormais entre les deux colonnes quand elles sont alignées et pairées.
  - **Réponse à la question centrale : 390x844 → [1,3,1,3] (left, right, left, right), barKind=hub ; 840x700 → [2,2,0,0] (top, top, bottom, bottom), barKind=band.** C'est exactement la règle formulée par l'utilisateur.
- Spec amendée et commitée de mon côté : 3ced6f9.
- Relecture de tâche dispatchée (sonnet) : diff 9c1b9c4..3ced6f9. Points prioritaires : vérifier les rotations DEPUIS LE CODE et non sur parole ; chercher s'il reste une taille d'écran où la barre d'actions dégraderait en silence ; juger un par un les six tests modifiés (sains ou affaiblis) ; cas limites (1 joueur, 7-8 joueurs, écran carré).
- Relecture rendue : SPEC NON CONFORME, QUALITÉ à corriger. 2 critiques, 1 important, 2 mineurs. Relecture de grande qualité : rotations confirmées depuis le code par test ciblé écrit puis supprimé, six tests modifiés jugés SAINS un par un avec recalcul indépendant de chaque géométrie, et deux défauts trouvés que ni l'implémenteur ni moi n'avions vus.

Ruling 23: `arrangementFor` ne retourne `columnPairs` que pour `playerCount == 4`. Pour `n <= 3`, `faceToFace` (comportement existant préservé) ; pour `n > 4`, `around`. Motif : MON Step 4 écrivait la règle du grand côté pour tout `playerCount <= 4`, alors que la spec §1.1 fige 2 joueurs en face-à-face et 3 joueurs en bandes égales, indépendamment de la forme de l'écran — seul le §1.4 rattache la règle aux 4 joueurs, et l'utilisateur n'a parlé que de ce cas. Conséquence de l'erreur, vérifiée par le relecteur sur 390x844, 412x915 et 360x800 : un duel à 2 joueurs sur téléphone portrait — le cas d'usage le plus fréquent de l'app — passait en colonnes gauche/droite au lieu du face-à-face. Aucun test ne l'attrapait : le harnais tourne en 800x600 paysage. Coût si faux : la règle du grand côté ne s'applique pas à 2-3 joueurs sur un écran où elle aurait pu servir.

Ruling 24: une assertion est ajoutée dans `_columnPairs` exigeant un effectif pair, avec un commentaire disant ce qu'elle empêche. Motif : le second critique (colonnes déséquilibrées → bande écartée en silence, §4.3 violé) devient inatteignable grâce au Ruling 23, mais un cas mort silencieux se réveille un jour ; une garde qui explique vaut mieux. La correction d'`adaptive_grid.dart` reste en place en défense de profondeur. Coût si faux : une assertion de plus en mode debug.

- Duplication de la règle §4.3 dans mon amendement de spec : corrigée de mon côté, et enrichie — cette règle a servi DEUX fois pendant l'implémentation de cette tâche (bande écartée sur 600x900, puis sur colonnes déséquilibrées). Une spec qui écrit ses interdits les rend attrapables.
- Mineur différé : `kCompactShortEdge = 110.0` duplique en dur le seuil de `tierFor`, par choix documenté ; test croisé seulement à 6 joueurs.
- Fix round 2/5 dispatché : Rulings 23-24.
- Fix round 2/5 rendu : DONE, commit 7c43954 (+ 616d507 pour la spec), 1452 tests / 6 skippés / 0 échec, analyze inchangé.
- Re-relecture ciblée rendue : les 2 constats ADRESSÉS, aucune casse, aucune incohérence spec/code. Le relecteur a REFAIT les calculs de géométrie à la main plutôt que de relire les affirmations : il confirme que les 4 nouveaux tests échouent bien contre l'ancienne formule (donc discriminants, pas recopiés), et que les rotations à 4 joueurs sont structurellement inchangées — la branche `playerCount == 4` fait exactement le même calcul qu'avant.

Tâche 3: complete (commits 9c1b9c4..616d507, 4 commits dont 2 de spec, re-relecture propre, 1 mineur différé)

### Tâche 4

- BASE = 616d507. Implémenteur dispatché (sonnet).
- **Contradiction repérée dans mon propre brief avant dispatch** : le texte dit d'appeler `seedRotationsFromSeats` « à chaque fois que `tableLayoutFor` renvoie un layout dont les sièges diffèrent du précédent », mais le code que je fournis pose un `addPostFrameCallback` INCONDITIONNEL, donc à chaque frame. Avec la tâche 8 (choix manuel de l'orientation par flèches), ce semis écraserait le choix de l'utilisateur en continu. Transmis à l'implémenteur comme point à résoudre, avec consigne de ne pas suivre mon code à la lettre.
- Rendu : DONE, commit d179b56, 1464 tests / 6 skippés / 0 échec (+12 tests), analyze inchangé. Discriminance prouvée deux fois par sabotage/restauration.

Ruling 25: la signature de `seedRotationsFromSeats` prend `(order, seats)` et non la seule liste de sièges indexée sur `state.players`. Motif : mon brief indexait par position canonique, alors qu'`AdaptiveGrid` place les zones par ordre d'AFFICHAGE. Après un réordonnancement, mon code aurait fait tourner le mauvais joueur — un bug que j'aurais livré. Coût si faux : une signature à deux paramètres au lieu d'un.

Ruling 26: le semis « rotation / pliage » est restreint aux parties créées par cette instance de page (`_hasOwnFreshSession`). Une partie rouverte après fermeture de l'application garde ses `quarterTurns` persistés. Motif : un semis générique cassait deux tests préexistants et protégés qui exigent qu'une partie reprise depuis un snapshot ne soit jamais auto-resemée — comportement déjà livré et testé, qu'on ne casse pas depuis cette tâche. Coût si faux : une partie reprise après avoir plié l'appareil garde des rotations calculées pour l'autre format ; l'utilisateur doit réorienter à la main, ce que la tâche 8 lui permettra.

Ruling 28 (REMPLACE le Ruling 27, sur décision de l'utilisateur) : une orientation choisie à la main SURVIT à tout changement de disposition, pliage compris. Mot pour mot : « orientations réglées à la main survivent au pliage du Fold ». Motif retenu et inscrit dans la spec : le réglage décrit où les gens sont assis autour de la table physique, et déplier un téléphone ne déplace personne — la forme de la zone change, la géométrie de la table non. Implémenté par `PlayerState.manualRotation`, délibérément NON persisté : l'implémenteur a VÉRIFIÉ (grep, pas supposition) qu'il n'existe qu'un seul appelant du semis et qu'il est derrière la garde `_hasOwnFreshSession`, donc l'absence de persistance n'est observable nulle part. Évite une migration Drift. Coût si faux : un marqueur perdu à la réouverture de l'app, sans effet tant que la garde tient.

Ruling 29: un réordonnancement ne pose PAS le marqueur et EFFACE celui des zones déplacées. `updateRotation` gagne `{bool manual = true}`. Motif : échanger deux joueurs de place n'est pas choisir un angle ; la rotation appliquée alors n'est que le défaut du nouveau siège. Et un joueur qui change de place change de situation — son ancien choix décrivait son ancienne place, il ne décrit plus rien. Le défaut `true` est délibéré : un appelant futur qui oublie marquera, et le pire est qu'une zone garde un angle ; l'erreur inverse ferait perdre un réglage posé par l'utilisateur, bien plus désagréable. Coût si faux : après un reorder, deux zones se réorientent au pliage alors que l'utilisateur aurait voulu les figer.

Ruling 30: le semis doit s'armer pour toute partie NEUVE, quel que soit l'écran qui l'a créée — `PlaySetupPage` signale explicitement la nouveauté au moment de naviguer, et le champ est renommé pour dire ce qu'il signifie. Motif : le relecteur a montré que `_hasOwnFreshSession` confond « cette page a créé la session » et « cette session est neuve ». `play_setup_page.dart:94-107` écrit le snapshot PUIS navigue, donc `LifeCounterPage` monte sur la branche « restauration » comme pour une vraie reprise, et le semis ne s'exécute JAMAIS sur le parcours normal Accueil → Jouer → Démarrer. Reproduit : partie à 4 joueurs figée à `[0,0,0,0]`, les deux joueurs d'en face lisant à l'envers — exactement le défaut que l'utilisateur a signalé et que cette tâche existe pour éliminer. Coût si faux : un paramètre de navigation de plus, et un champ renommé.

**Leçon, DEUXIÈME occurrence** : `play_setup_page.dart` porte le chemin réel de démarrage d'une partie. La tâche 1 y avait déjà trouvé la liste de couleurs que personne n'avait vue ; la tâche 4 y trouve le montage qui contourne le semis. Dans ce dépôt, le chemin qu'emprunte l'utilisateur n'est pas celui qu'on croit — à vérifier d'office pour toute tâche qui touche au démarrage d'une partie.

- Mineurs différés : `_setScreenSize` dupliquée dans trois fichiers de test ; `tableLayoutFor` recalculé à chaque post-frame (coût négligeable, non nul).
- Fix round 3/5 dispatché : Ruling 30.
- Fix round 3/5 rendu : DONE, commit 1f99d67, 1467 tests / 6 skippés / 0 échec, analyze inchangé. `extra: true` à la navigation, lu par `play_routes.dart`, champ renommé `_sessionIsFresh`. Test de bout en bout `play_setup_seeds_rotations_test.dart` : GoRouter réel avec les vraies routes, vraie `PlaySetupPage`, tap réel sur « LANCER LA PARTIE », vérification de `[2,2,0,0]`. Discriminance : retrait du signal → le test reproduit exactement le défaut (`Expected [2,2,0,0], Actual [0,0,0,0]`).
- Re-relecture ciblée rendue : constat critique ADRESSÉ, aucune casse. Le relecteur a vérifié lui-même les TROIS autres appelants de la route (bouton Jouer de l'accueil, bouton Reprendre, bascule d'onglet du shell) : aucun ne signale « partie neuve » par accident. Partie reprise protégée, vérifié par exécution. Test jugé réellement de bout en bout, sans raccourci.
- **Mineur résiduel, groupé avec la tâche 5** : `lib/models/game_session.dart:51` cite encore `_hasOwnFreshSession` dans un commentaire. Référence à un champ qui n'existe plus. Non trivial sur le principe — c'est un nom trompeur qui a causé le critique de cette tâche.

Tâche 4: complete (commits 616d507..1f99d67, 5 commits dont 1 de spec, re-relecture propre, 1 mineur groupé avec T5, 2 mineurs différés)

### Tâche 5

- BASE = 1f99d67. Implémenteur dispatché (sonnet).
- Rendu : DONE, commit c21cf60, 1469 tests / 6 skippés / 0 échec, analyze inchangé. Les 33 tests préexistants de `life_dial_test.dart` restent verts, dont les 8 de rotation. Tâche annexe (commentaire obsolète de `game_session.dart`) faite.
- Relecture rendue : SPEC conforme, QUALITÉ approuvée. Aucun critique. Le relecteur a confirmé par lecture structurelle — pas seulement par les tests — qu'un sous-arbre sous `IgnorePointer` est exclu du hit-test quel que soit l'ordre de peinture, donc la couche de repères ne peut pas voler d'événement à l'arène de gestes. Il a énuméré les chemins de sortie de `_pressedHalf` : aucun ne laisse une moitié éclairée en permanence.

Ruling 31: la limite multi-touch de `_pressedHalf` est DOCUMENTÉE, pas corrigée. Avec deux doigts sur les deux moitiés d'un même cadran, le second écrase l'affichage du premier et un lever dans le mauvais ordre éteint la surbrillance restante. Décision : ne pas migrer vers un `Set`. Motif : le défaut est cosmétique, auto-réparateur au relâchement, et l'émission des deltas reste correcte puisqu'elle repose sur `_pendingTaps`, qui est un `Set` précisément pour cette raison. Mais ce fichier documente chaque cas limite — `_pendingTaps` explique pourquoi il est un `Set` — et un silence ici ferait croire à un oubli : quelqu'un « corrigerait » un jour en touchant à l'arène de gestes. Coût si faux : une surbrillance fausse pendant qu'un joueur tient ses deux pouces sur sa propre zone.

- Mineur corrigé au passage : `dispose()` ne remettait pas `_pressedHalf` à zéro alors qu'il le fait pour les trois autres champs de geste. Sans conséquence, mais l'incohérence fait douter un lecteur.
- Mineurs refusés (broutilles héritées de mon brief) : clés de test en tiret au lieu de snake_case, duplication des valeurs d'opacité, apostrophe manquante dans un nom de test.
- **Pour la validation visuelle** : les repères restent affichés au cran de densité le plus serré, avec une taille de police fixe non mise à l'échelle — sur une très petite zone ils pourraient encombrer. Et le rendu sous rotation 90°/180° n'est établi que par déduction structurelle.
- Fix round 1/5 dispatché : Ruling 31.
- Fix round 1/5 rendu : DONE, commit e0fd2de, 1469 / 6 / 0 inchangé. Doc-comment complété, `dispose()` corrigé, rien d'autre touché.
- Re-relecture ciblée (haiku) : ADRESSÉ. Les trois points du doc-comment couverts, `dispose()` corrigé, diff limité à ces deux changements, aucune casse.

Tâche 5: complete (commits 1f99d67..e0fd2de, 2 commits, re-relecture propre, 0 parké)

### Tâche 6

- BASE = e0fd2de. Implémenteur dispatché (sonnet).
- Transmis : la distinction entre `LifeLog` (l'ÉVÉNEMENT, qui monte et s'efface) et `PendingDelta` (le BILAN cumulé, qui reste pendant la salve) ; `kDamageBufferWindow` existe depuis la tâche 2 et attend son premier consommateur ; interdiction de réutiliser `AppColors.error`/`success`, qui partagent leurs valeurs avec les couleurs de mana ; et consigne de venir me voir si le garde-fou des couleurs se déclenche plutôt que de l'affaiblir.
- Rendu : DONE_WITH_CONCERNS, commit be1cf1f, 1474 / 6 / 0, analyze inchangé. Trois hypothèses fausses de MON brief signalées et adaptées (constructeur du notifier, `dispose()` surchargeable, nom de la variable de taille).

Ruling 32: on CONSOLIDE. Le badge `zone_pending_badge` de `life_counter_page.dart:1306` affiche déjà le cumul en attente, à 14 px dans le coin haut-droit — c'est littéralement l'élément que l'utilisateur décrit comme pas assez visible. Vérifié moi-même dans le code. Décisions : la source unique reste `_pendingDamage` (existante, testée, portant la logique d'attribution des dégâts de commandant) ; `pendingDelta`/`accumulate`/`clearPendingDelta` ajoutés au notifier par cette tâche sont RETIRÉS ; le widget `PendingDelta` est conservé mais alimenté par un paramètre venu de la page ; le rendu du petit badge est supprimé. Motif : garder les deux afficherait deux fois la même valeur, dont une illisible — et surtout créerait une SECONDE SOURCE pour la même donnée, le motif qui a déjà coûté trois rondes sur ce chantier (cinq listes de couleurs en tâche 1, deux sources de rotation en tâche 4). Bénéfice supplémentaire : `PendingDelta` vit dans `PlayerZone`, donc hérite du `RotatedBox` — le badge actuel, posé au niveau de la page, ne tournait pas, et le joueur d'en face lisait son propre bilan à l'envers. Coût si faux : du travail de cette tâche défait, et un paramètre de plus traversant la page vers la zone.

- Fix round 1/5 dispatché : Ruling 32.
- Fix round 1/5 rendu : DONE, commit 2a91479, 1469 / 6 / 0 — exactement la baseline d'avant la tâche. Aucun test existant à adapter : en conservant la valeur source et le format texte, les assertions retrouvent le nouveau rendu.
- Relecture rendue : SPEC conforme, QUALITÉ approuvée. Le relecteur a prouvé par `git diff` ciblé que `player_zone_notifier.dart` est revenu à l'identique (diff VIDE) et que la logique d'attribution des dégâts de commandant est inchangée octet pour octet. Chaîne de rotation confirmée : `RotatedBox` → `LayoutBuilder` → `buildContent` → `PendingDelta`. L'argument du Ruling 32 tient : l'ancien badge était hors de toute rotation.
- Mineur différé : pas de test unitaire isolé pour le widget `PendingDelta` (le cas `delta == 0` n'est couvert qu'indirectement).
- **Défaut PRÉ-EXISTANT confirmé, à remonter à l'utilisateur** : `life_counter_page.dart:427-432`, `dispose()` annule les minuteurs du buffer sans appliquer le dégât en attente. Quitter l'écran dans les 2 s suivant un geste perd ce dégât, silencieusement. Antérieur au chantier, vérifié identique avant la tâche 6. Relecteur : gravité faible à modérée, fenêtre d'exposition courte mais perte muette pouvant fausser une partie. Classé « ticket dédié ».

Tâche 6: complete (commits e0fd2de..2a91479, 2 commits, relecture propre, 1 mineur différé)

### Tâche 7

- BASE = 2a91479. Implémenteur dispatché (sonnet).

Ruling 27 (ANNULÉ par le Ruling 28, conservé pour mémoire) : un changement de disposition ÉCRASE un choix manuel d'orientation antérieur. Décidé par l'implémenteur, accepté, et son argument est meilleur que ma question : un pliage change la FORME de la zone (colonne étroite → quadrant large), donc un angle choisi pour l'ancienne forme n'a souvent plus de sens ; alors qu'un réordonnancement ne change la forme de personne, d'où la décision opposée déjà en place pour ce cas. Préserver sélectivement un choix manuel exigerait un drapeau par joueur, une migration de modèle et une règle de réinitialisation — portée très supérieure à cette tâche, et territoire de la tâche 8. **Point le plus contestable du chantier jusqu'ici : à soumettre explicitement à l'utilisateur.** Coût si faux : un joueur qui a orienté sa zone pour sa table physique la voit sauter si l'appareil se déplie en cours de partie.


- **Session perdue (2026-10-18)** après le dispatch de l'implémenteur de la tâche 7. Code retrouvé non commité dans le worktree, sans rapport. Reprise par une nouvelle session contrôleur.
- Reprise : suite complète lancée → 1 échec, `player_drawer_test.dart` « l'action monarque change de libellé selon l'état ». Cause : le test fermait la feuille par `tapAt(10,10)`, qui tombait dans la marge de l'ancien bottom sheet M3 plafonné à 640 px ; la feuille assise est pleine largeur (choix de l'implémenteur, `ConstrainedBox.tightFor`) et pleine hauteur sur 800×600. Test adapté : fermeture par `handlePopRoute()` (retour système). 1471 / 6 / 0, analyze sans erreur.
- Commit fd4a256 fait par le contrôleur (contre la règle « pas de fix contrôleur », imposé par la reprise) — d'où relecture complète de la tâche à suivre. Fichiers de plugins générés linux/macos/windows laissés hors commit (bruit de `flutter run`).
- Écart au plan noté : le plan disait `player_zone.dart` passe `quarterTurns` ; l'implémentation le capture par fermeture dans `life_counter_page.dart` (`_buildPlayerZone`, `p.quarterTurns`).
- Relecture rendue (sonnet) : SPEC ❌, QUALITÉ « Needs fixes ». 0 critique, 5 importants : glissade depuis le bas physique (plan-mandated), clavier non géré, SafeArea lue en repère physique dans le RotatedBox, hauteur non bornée en latéral, tests peu discriminants ; et « comportement inchangé pour le siège du bas » non tenu (couleur/rayon).

Ruling 33: la glissade passe DANS le repère du siège (RotatedBox autour du SlideTransition) — le code du plan glissait en repère écran, contraire à la spec §1.5 « surgit depuis SON bord ». Coût si faux : nul, c'est la lettre de la spec.

Ruling 34: les insets physiques (clavier, encoche, barre de geste) s'appliquent HORS du RotatedBox, et sont retirés du MediaQuery vu par le contenu. Motif : un inset est une propriété de l'écran, pas du siège. Coût si faux : marges incorrectes sur un bord, visibles en validation visuelle.

Ruling 35: la feuille reprend l'habillage de l'ancien tiroir (greyShade800, rayon 18), contre le code du plan (dialogBackground, 14). Motif : la spec §1.5 exige un comportement observable inchangé pour le siège du bas. Coût si faux : une teinte de fond.

Ruling 36: le mineur « aucun test ne vérifie que la page transmet p.quarterTurns » est promu dans le round. Motif : leçon répétée du chantier (paramètre correct, testé, sans appelant testé — trois fois). Coût si faux : un test de plus.

- Implémenteur d'origine perdu → round 1 confié à un implémenteur neuf (opus, géométrie de rotation délicate). Constats : task-7-fix1-findings.md.

### Tâche 8 — pré-analyse (pendant le round 1 de la tâche 7)

Le plan a été écrit sans voir trois choses déjà présentes dans `life_counter_page.dart` :
- un mode réorganisation existe : `_isEditMode`, action `edit-mode` « Réorganiser les joueurs » (9 actions), qui enveloppe déjà chaque zone dans `DraggablePlayerZone` quand il est vrai ;
- une action `orientation-presets` « Orientation » ouvre une modale de presets (`_showOrientationPresets`, `_getOrientationPresets`, `_applyOrientationPreset`, `_buildOrientationPreview`), DÉRIVÉS de `tableLayoutFor`/`seatsFor` (ruling 20 d'une revue antérieure : listes en dur supprimées parce qu'elles mentaient sur la géométrie), appliqués dans l'ORDRE D'AFFICHAGE via `updateRotation` (donc marqués manuels — Ruling 28 respecté) ;
- le tiroir porte une action `onRotate` (quart de tour par appui), celle que la spec §1.7 dit REMPLACÉE par les quatre flèches.
Maquette lue (artboard Reorganise.dc.html, 390×844, 4 joueurs en colonnes) : voile sombre sur la table, chaque zone à bordure en tirets avec nom, croix 3×3 de flèches (▲ ◀ ▶ ▼, angle « 90° » au centre, flèche active pleine dorée : colonne gauche ◀ à 90°, colonne droite ▶ à 270°), bouton poignée « Déplacer la zone de X » ; barre en pied : « Réorganisation · le décompte est suspendu », pastilles Côtés / Face-à-face / Cercle / Même sens, bouton plein « Terminé ».

Ruling 37: le mode réorganisation du plan RÉUTILISE l'existant au lieu d'en ajouter un second. `_isEditMode` est renommé `_isReorganising` ; l'action `edit-mode` devient l'unique entrée du mode ; `kActionCount` NE passe PAS à 10. Motif : la spec §1.9 décrit « le bouton de réorganisation » existant qui « ne dit pas dans quel mode on se trouve » — on le rend explicite, on n'en crée pas un deuxième. Coût si faux : aucun, sauf si l'utilisateur voulait deux entrées distinctes.

Ruling 38: l'action `orientation-presets` et sa modale sont retirées ; les presets vivent dans `ReorganiseBar`. `kActionCount` passe de 9 à 8 (kBandNeed reste dérivé). Motif : maquette validée (presets dans la barre) ; deux chemins vers les mêmes presets = deux surfaces à garder cohérentes. Coût si faux : un appui de plus pour atteindre un preset (entrer dans le mode).

Ruling 39: les presets ne sont PAS calculés par arithmétique d'index dans le notifier (code du plan : `i.isEven ? 1 : 3`, `i % 4`…). Ce code viole la contrainte globale « TableSeat.quarterTurns seul calculateur » et l'ordre d'affichage (Ruling 25). Ils sont dérivés de la position RÉELLE de chaque zone rendue → un `TableSide` → `TableSeat.quarterTurns`, dans une fonction pure testable, appliqués dans l'ordre d'affichage, et marquent l'orientation manuelle (spec §1.4). Le notifier n'expose qu'une application groupée (ordre, rotations) s'il en faut une ; il ne connaît pas la géométrie. Coût si faux : interface différente de celle du plan (`applyOrientationPreset(preset)`).

Ruling 40: liste des presets par effectif (spec §1.7 : Face-à-face, Côtés, Triangle, Cercle, Même sens ; « seuls ceux qui conviennent ») : 2 → Face-à-face, Côtés, Même sens ; 3 → Face-à-face, Triangle, Même sens ; 4 → Côtés, Face-à-face, Cercle, Même sens (maquette) ; 5-6 → Face-à-face, Cercle, Même sens ; 7-8 → Face-à-face, Même sens. Un preset dont le résultat est identique à un autre sur la disposition courante n'est pas proposé deux fois (règle de la revue antérieure). Pas de preset « Table/Par défaut » : la spec en liste cinq. Coût si faux : un preset manquant ou superflu à un effectif donné, visible en validation visuelle.

Ruling 41: le bouton de rotation par quart de tour du tiroir (`onRotate`) est retiré — spec §1.7 « Il est remplacé par un sélecteur à quatre flèches ». Coût si faux : l'orientation n'est plus réglable hors du mode réorganisation.

Ruling 42: le sélecteur suit la maquette (croix 3×3, angle au centre, flèche active pleine) mais à 48×48 par flèche, pas 34 px (contrainte globale). Il vit HORS du RotatedBox de la zone (repère écran, comme la maquette). Le test « geste de vie inopérant en mode réorganisation, opérant dès la sortie » (spec §6.1) est AJOUTÉ — le plan l'omettait. Coût si faux : nul.

Ruling 43: la tâche 8 est DÉCOUPÉE : 8a = mode explicite (renommage, voile, bordure, poignée, sélecteur, barre avec « Terminé », geste de vie désactivé, retrait de `onRotate`, presets EXISTANTS déplacés tels quels dans la barre, retrait de l'action Orientation) ; 8b = refonte des presets selon les Rulings 39-40. Motif : deux surfaces de relecture indépendantes, la seconde purement géométrique. Coût si faux : un aller-retour de dispatch en plus.
- Fix round 1/5 rendu (opus) : DONE_WITH_CONCERNS, commit cafdbe6, 1480 / 6 / 0 (+9 tests), 11 mutations toutes attrapées, analyze inchangé.

Ruling 44: écart au Ruling 34 ACCEPTÉ — le clavier reste traité hors rotation (Padding viewInsets), mais l'encoche et la barre de navigation sont tournées dans le repère du siège (`_toSeatFrame`) au lieu d'un SafeArea extérieur. Motif de l'implémenteur, juste : un SafeArea extérieur ferait flotter la feuille du siège du bas au-dessus de la barre de navigation, contre « comportement inchangé pour le siège du bas » (spec §1.5). Ce n'est pas un second calcul côté→rotation. Coût si faux : marge mal placée sur un siège latéral, à voir en validation visuelle.

Ruling 45: perte du glisser-pour-fermer et largeur bord à bord sur grand écran (l'ancien sheet M3 était plafonné à 640 px) — ACCEPTÉES, renvoyées à la validation visuelle. Motif : la feuille appartient au siège, son bord est celui du joueur ; le retour système et le toucher de barrière ferment toujours. Coût si faux : un geste familier perdu, une feuille très large sur le Fold déplié — ajout d'un plafond trivial si l'utilisateur le demande.
- Re-relecture ciblée (sonnet) : les 7 constats + mineurs ADRESSÉS, aucune casse Critique/Importante. Géométrie de `_toSeatFrame` vérifiée à la main pour 1, 2, 3.
- Tâche 7: minor (deferred): aucun test ne discrimine `_toSeatFrame` ni le sens de glissade pour les sièges 1 et 3 (une inversion 1↔3 passerait) — vérifié à la main par le relecteur.
- Tâche 7: minor (deferred): siège latéral + clavier ouvert : la feuille rétrécit en largeur locale (contenu visible).
- **Pour la validation visuelle** : feuille ouverte depuis chacun des quatre sièges (spec §6.2), glissade, encoche, clavier dans l'éditeur de compteur, largeur sur le Fold déplié.

Tâche 7: complete (commits 2a91479..cafdbe6, 2 commits, re-relecture propre, 0 parké)

### Tâche 8a
- BASE = cafdbe6. Implémenteur dispatché (opus) sur task-8a-brief.md.
- Rendu : DONE_WITH_CONCERNS, commit 8dc9276, 1493 / 6 / 0 (+13 tests dont 3 page), 15 mutations attrapées, analyze inchangé.

Ruling 46: le bouton de rotation de `PlayerHeader` (quart de tour par appui + appui long glisser-pour-tourner) est RETIRÉ, comme celui du tiroir — spec §1.7 « Il est remplacé par un sélecteur à quatre flèches ». Porté dans la tâche 8b (même domaine : orientation). Coût si faux : un raccourci d'orientation hors mode réorganisation perdu.

Ruling 47: la barre du mode est posée SOUS la grille (la grille perd ~155 px pendant le mode, la bande d'actions peut basculer en hub) — ACCEPTÉ. Motif : par-dessus, elle masquait le sélecteur et la poignée des zones du bas. Validation visuelle. Coût si faux : un saut de mise en page à l'entrée du mode.

Ruling 48: « Recommencer » reste accessible pendant le mode, derrière sa confirmation — ACCEPTÉ. Coût si faux : faible, l'action est confirmée.
- Relecture (sonnet) : SPEC ✅, QUALITÉ « Needs fixes ». Risques (a)-(e) tous OK. 1 Important plan-mandated : `orientation_picker.dart` recopie la table 0 bas/1 gauche/2 haut/3 droite de `TableSeat.quarterTurns`.

Ruling 49: le constat plan-mandated est RETENU — la contrainte globale « TableSeat.quarterTurns seul calculateur » prime sur le code du plan. Les flèches sont indexées par `TableSide` et le quart de tour vient de `TableSeat.quarterTurns` (ou d'une fonction statique qu'il expose). Coût si faux : une indirection de plus dans un widget de 4 boutons.

- Tâche 8a: minor (deferred → porté en 8b) : presets calculés dans build() sur `_measuredGridSize`, qui change quand la barre réduit la grille ; `_seedRotationsIfLayoutChanged` pourrait resemer si le verdict de `tableLayoutFor` bascule pendant le mode.
- Tâche 8a: minor (deferred, visuel) : 8 joueurs écran plié, la poignée + nom et la croix réduite peuvent se chevaucher.
- Fix round 1/5 dispatché (resume implémenteur) : Ruling 49 + 2 commentaires inexacts (page ~1204, table_layout « neuvième action »).
- Fix round 1/5 rendu : DONE, commit 47a4d94, 1493 / 6 / 0, mutations M16-M17 ajoutées.
- Re-relecture ciblée (haiku) : 3/3 ADRESSÉS, aucune casse. Une seule correspondance côté→rotation dans lib/ (`extension TableSideRotation`, table_seat.dart).
- Tâche 8a: minor (deferred) : références de rulings/historique dans les commentaires de code (« Ruling 49 », « lot 6 ») — vieillissent mal, à triager en revue finale.

Tâche 8a: complete (commits cafdbe6..47a4d94, 2 commits, re-relecture propre, 0 parké)

### Tâche 8b
- BASE = 47a4d94. Implémenteur dispatché (opus) sur task-8b-brief.md (+ Ruling 46, mineur presets/taille mesurée).
- Rendu : DONE_WITH_CONCERNS, commit b5d3f03, 1507 / 6 / 0, 16 mutations attrapées, analyze inchangé. Bouton de rotation de l'en-tête retiré jusqu'à la page (6 tests dédiés supprimés).

Ruling 50: les trois conventions géométriques de l'implémenteur sont RETENUES et soumises à l'utilisateur : Cercle à 4 tourne en sens horaire (zone haut-gauche → bord haut) ; Cercle à 5-6 sur téléphone = équivalent géométrique sur la grille repliée en deux rangées, pas les sièges `around` littéraux ; Face-à-face à 5-6 sur le Fold envoie les colonnes latérales en bas. Coût si faux : un preset à reprendre, visible en validation visuelle.

Ruling 51: la mesure de la table prise HORS mode (clé sur la Column grille+barre) est ACCEPTÉE : les presets décrivent la table qu'on joue. Coût si faux : près d'un seuil, la grille affichée pendant le mode diffère de celle que les presets décrivent.
- Relecture (opus) : SPEC ✅, QUALITÉ approuvée, 0 critique, 0 important. Risques (a)-(e) vérifiés : un seul mapping côté→rotation, marqueur manuel posé, ordre d'affichage, jeu normal non touché par le déplacement de la clé de mesure, code mort retiré sans orphelin.
- Tâche 8b: minor (deferred) : `zoneCentresFor` réexprime le placement d'`AdaptiveGrid` (verrouillé par un test de rendu réel, mais à deux tailles seulement : ajouter paysage 844×390 et 600×900).
- Tâche 8b: minor (deferred) : après un changement de métriques PENDANT le mode (dépliage/rotation), les presets de la barre sont calculés dans build() sur l'ancienne taille jusqu'au build suivant ; un appui dans la fenêtre poserait en manuel les angles de l'ancienne disposition. Correctif simple : calculer au moment du tap.
- Tâche 8b: minor (deferred) : dédoublonnage testé sur géométrie synthétique seulement (aucune disposition réelle ne produit de doublon).

Tâche 8b: complete (commits 47a4d94..b5d3f03, 1 commit, relecture propre)

## Revue finale
- Merge-base main : 2d3d633. Paquet de revue à suivre.
- Revue finale (opus) : « With fixes ». 0 critique, 5 importants, 8 mineurs, triage des mineurs différés. Décisions détaillées : final-fix-findings.md (F1-F11 à faire, N1-N4 non).

Ruling 52: `manualRotation` est PERSISTÉ (champ absent d'un ancien snapshot = manuel) et la garde `_sessionIsFresh` du semis est levée. Motif : un simple aller-retour d'onglet (PlayShell, context.go, sans conservation d'état) remontait la page en « reprise » et tuait le semis pour le reste de la partie ; replier le Fold réintroduisait alors le défaut d'origine. Cette décision remplace le coût accepté du Ruling 26 et rend superflu le signal du Ruling 30. Coût si faux : un champ de plus dans le snapshot.

Ruling 53: les libellés d'accessibilité du sélecteur disent où le joueur est assis (« Assis à gauche »…), au lieu de « Regarde vers la gauche », qui contredisait le visuel. Coût si faux : un libellé de lecteur d'écran.

Ruling 54: la surface inégale à 3 joueurs (`[top, bottom, bottom]`, 50/25/25), alors que la spec §1.1 dit « bandes égales », n'est PAS corrigée dans ce chantier ; elle est soumise à l'utilisateur. Motif : comportement antérieur au chantier, et trois bandes pleine largeur posent une question d'orientation du joueur du milieu que la spec ne tranche pas. Coût si faux : une table à 3 joueurs inéquitable reste livrée.

Ruling 55: le Ruling 29 (un réordonnancement remet le défaut du siège) est maintenu et soumis à l'utilisateur. Le relecteur propose que l'orientation suive la PLACE plutôt que le joueur. Coût si faux : après « Même sens », échanger deux joueurs les fait basculer à 180°.

- Vague de correction finale dispatchée (opus) : F1-F11.
- Vague finale rendue : DONE_WITH_CONCERNS, 11 commits b5d3f03..217ba33, 1524 / 6 / 0 (+17), analyze 166. Snapshot = JSON SharedPreferences, aucune migration Drift.
- Hors périmètre noté par l'implémenteur : la recherche d'artwork et la galerie de commandants restent des bottom sheets non orientées → à soumettre à l'utilisateur (spec §1.5 « toute surface modale rattachée à un joueur »).
- Re-relecture de la vague finale (sonnet) : F1-F11 ADRESSÉS, un seul mapping côté→rotation confirmé, aucune casse Critique/Importante.
- Parké : Ruling 56: le total peut rétrécir (mode ajustement sur le Fold replié, ~43 px ; zone étroite avec un delta à deux chiffres, échelle ~0,67 au début de salve) — renvoyé à la validation visuelle, non corrigé. Motif : seuls des chiffres sur pièce trancheront ; le correctif (réserver la largeur du delta, ou sortir les paliers du cadran) dépend de ce qu'on voit. Coût si faux : un total qui « respire » à chaque salve.
- Hors périmètre, à soumettre : recherche d'artwork, sélecteur de versions et galerie de commandants restent des bottom sheets non orientées.

Revue finale : propre après une vague (b5d3f03..217ba33).
