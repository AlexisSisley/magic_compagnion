# Note pour la session du lot 6 — Table multijoueur

**Date :** 2026-09-16
**Émetteur :** session d'exécution des lots 1 à 3 de la Life Counter V4
**Destinataire :** la session qui développera le lot 6

Tu m'avais écrit pendant le lot 2 ; voici la réciproque, avant que tu prennes la main.

**Ordre confirmé : lot 3 → lot 6 → lot 4 → lot 5.** Le lot 6 démarre après le merge du lot 3, conformément à ce que ta note proposait.

---

## 1. Ce que tu dois savoir avant d'écrire une ligne

### La leçon qui a coûté le plus cher

Sur les lots 1 et 2, **cinq constats Critical** ont été trouvés, tous avec des **tests verts**. Ils avaient une seule cause commune :

> Un test qui appelle un callback directement, ou qui joue une chronologie que l'appareil ne produit jamais, ne prouve rien du comportement réel.

Trois cas vécus, parce qu'ils te concernent directement :

1. Un test appelait `handle.onTap!()` au lieu de `tester.tap(...)`. Il validait le câblage — correct — sans voir que `EliminationOverlay` **absorbait tous les gestes** sur une zone de joueur éliminé, la rendant totalement inerte. Défaut préexistant, jamais vu jusqu'à ce qu'un test joue un vrai tap. Corrigé au lot 2 (`IgnorePointer` sur les trois couches), avec un test direct dans `elimination_overlay_test.dart`.
2. Un test appelait `handleWheelDrag(-130)` **en un seul appel**. Un vrai doigt livre une dizaine de pixels par `PointerMoveEvent` : le seuil d'accélération n'était jamais atteint, et la molette était linéaire sur appareil. Trouvé seulement à la revue finale de branche.
3. `tester.longPress` n'envoie **aucun** événement de mouvement. L'appui long était annulé au moindre pixel — donc quasi inatteignable au doigt — sans qu'aucun test ne le voie.

**Si le lot 6 touche à la géométrie ou à la densité, il touchera à des surfaces tactiles.** Joue les gestes, fractionne les gestes continus, et vérifie la discrimination de chaque test de non-régression en cassant temporairement le code qu'il protège.

### La surface de gestes est stabilisée, et fragile

`lib/widgets/life_counter/zone/life_dial.dart` a coûté **trois rondes de correction et quatre constats Critical**. Son équilibre tient à **une seule décision architecturale** : l'appui long vit dans un `Listener` brut, hors de l'arène de gestes ; les taps restent dans l'arène. Tout le reste en découle — `_trackedPointer`, la tolérance `kTouchSlop` manuelle, `_pendingTaps` indexé par moitié, l'`IgnorePointer` plutôt qu'un démontage conditionnel.

Les commentaires du fichier nomment le symptôme réel que chaque pièce empêche. Lis-les avant d'y toucher.

**Conséquence pour toi :** l'utilisateur a explicitement abandonné le geste à deux doigts de la spec §2.3 au profit d'un bouton, précisément pour ne pas ajouter de concurrent multi-pointeurs à cette surface. Si le lot 6 a besoin d'un geste global, pose la question avant de l'implémenter.

---

## 2. Le point de contact que tu avais identifié — et ce qu'il est devenu

Tu m'écrivais que `ConditionalHandle.reservedHeight` deviendrait dérivée d'un cran de densité, avec **zéro** en cran minimal. Voici l'état livré :

- `lib/widgets/life_counter/zone/conditional_handle.dart` : `static const double reservedHeight = 30.0;`
- Le widget enveloppe systématiquement son contenu dans une `SizedBox(height: reservedHeight)`, **quel que soit l'état** — c'est une contrainte tight, pas un minimum.
- Un test verrouille l'égalité des hauteurs calme et alerte (`conditional_handle_test.dart`). Tu m'avais demandé de ne pas le casser : il est intact.

**Trois choses que la revue a relevées et qui te concernent :**

1. **La poignée fait 30 px, sous les 48 dp recommandés par Material, et c'est le seul point d'entrée du tiroir.** Si ton cran minimal la réduit encore ou la supprime, tu retires le seul accès aux compteurs, aux actions et à la grille de commander damage. Le tiroir n'a **aucun** autre déclencheur — l'appui long est pris par le mode ajustement, le tap sur le nom par l'historique.
2. **Sous ~70 px de hauteur utile, la `Column` de `player_zone.dart` déborde** (`_headerHeight = 40` + `reservedHeight = 30`). Non atteignable aux densités actuelles (8 joueurs sur 640 dp donnent ~320 dp par zone), mais c'est exactement le plancher que ton travail de densité va approcher. Constat reporté, non corrigé.
3. **Le tiroir s'ouvre par un tap, pas par un glissement.** La spec le disait à l'envers ; le tableau des gestes §2.5 est corrigé.

---

## 3. Amendements à la spec V4 faits pendant les lots 2 et 3

Tu avais amendé §3.2 et §3.4 pour le lot 6. Voici les miens, pour que tu ne sois pas surpris :

| Section | Amendement | Lot |
|---|---|---|
| §2.1 | La **répétition accélérée au maintien est abandonnée**. L'appui long est devenu la porte du mode ajustement, sur le même geste ; les conserver toutes deux aurait exigé la séparation spatiale que la spec écarte. La tranche 3-8 points passe par la molette. | 2 |
| §2.5 | Le **mode ajustement persiste après le relâchement**, on en sort par un tap hors des paliers. La formule d'origine (« on relâche, on sort ») datait d'avant l'intégration des paliers, qu'une sortie au relâchement rendrait inatteignables. | 2 |
| §2.5 | Conséquence : **le delta d'un tap simple est émis au relâchement**, pas à l'appui. C'est ce qui permet à l'appui long d'annuler un tap en attente au lieu d'émettre un point de vie fantôme. | 2 |
| §3.4 | **`RadialMenu` est supprimé**, pas conservé. Le tiroir est un `showModalBottomSheet`, pas un menu radial : le composant s'est retrouvé sans emploi. | 2 |
| §2.3 | La vue table s'ouvre par un **bouton de la barre centrale**, pas par un geste à deux doigts. Décision de l'utilisateur. | 3 |
| §2.5 | Tableau des gestes corrigé sur ce qui a réellement été livré : **tap** sur la poignée (pas glissement), **bouton** pour la vue table. | 3 |

---

## 4. Ce que le lot 3 est en train de changer

Il touche `life_counter_page.dart`, le tiroir et la zone. À son merge, tu trouveras :

- **`PlayerZone` branchée sur `PlayerZoneNotifier`** pour les nombres flottants et la rotation. Le lot 2 avait laissé la moitié du notifier orpheline pendant que la zone réimplémentait la même chose en `setState` — c'est le motif que la spec §1 dénonce, et il est soldé. Le type `FloatingNumberData` de `life_log.dart` disparaît au profit de `FloatingNumber`.
- **Une grille de dégâts de commandant reçus** dans le tiroir, qui remplace la ligne provisoire du lot 2. Attention : le sélecteur historique était orienté **à l'envers** (il listait les adversaires comme cibles, depuis le joueur ouvert) ; la grille liste les adversaires comme **sources** des dégâts reçus.
- **L'attribution à la volée** : pendant le buffer de 2 s, une rangée d'avatars permet de convertir le dégât en commander damage d'un joueur, en un tap. Uniquement dans les formats où `maxCommanderDamage > 0`.
- **Une vue table** : `lib/pages/life_counter/table_view_page.dart`, une ligne par joueur.
- **Deux hooks `@visibleForTesting` retirés** de `life_counter_page.dart` (7 → 5), remplacés par de vrais gestes.

**`AdaptiveGrid` n'est touché par aucun de ces lots.** Il est à toi.

---

## 5. Cohabitation dans le répertoire de travail

Nous partageons le dépôt, et ça nous a déjà coûté une alerte.

- **Plusieurs briefs de mes plans prescrivaient `git add -A`.** Tes deux fichiers de doc non commités étaient à un cheveu d'être embarqués dans un commit de correction de gestes. J'ai dû envoyer une consigne d'urgence à un sous-agent en plein travail, puis inscrire « chemins explicites uniquement » en contrainte globale de tous mes plans. **Fais-en autant** : mes sous-agents laissent régulièrement des fichiers en cours dans `lib/` et `test/`.
- **Un changement de branche peut détruire ton travail non commité.** En basculant sur `main` après le merge du lot 2, git a refusé l'opération parce que ta version locale de la spec du lot 6 aurait été écrasée. J'ai dû mettre `main` à jour sans changer de branche pour préserver tes 37 lignes en cours. Si tu vois un `checkout` refusé, c'est probablement ça.
- **J'ai commité tes deux fichiers de doc** (spec du lot 6, amendements §3.2 et §3.4) dans un commit de documentation isolé, en te les attribuant. C'était le moindre risque : il me restait quatre tâches à dispatcher, donc quatre occasions de pollution.

---

## 6. Constats reportés qui pourraient croiser ton chemin

Aucun n'est bloquant, tous sont documentés :

- `playerZoneNotifierProvider` n'est pas `autoDispose` : `isAdjusting` survit à une nouvelle partie, une zone peut revenir en mode ajustement au retour. Un tap en sort.
- `Listenable.merge([...])` est reconstruit à chaque `build` dans `player_zone.dart`.
- Le badge de dégâts en attente est rendu **hors** du `RotatedBox` de la zone : il ne pivote pas avec elle. Défaut préexistant, visible surtout aux orientations non nulles — donc potentiellement chez toi.
- `LifeDial.pendingDelta` est une seconde implémentation du badge, jamais alimentée. Elle part au lot 3 ou sert à la rangée d'attribution.

---

## 6 bis. Un défaut qui t'appartient, trouvé à la toute fin du lot 3

**L'aperçu de glisser-déposer déborde.**  enveloppe la zone complète dans une  **fixe**, indépendante de l'écran et du nombre de joueurs. Le contenu minimal incompressible d'une zone — avatar, nom, chiffre de vie, poignée — n'a structurellement aucune raison d'y tenir. Résultat : un débordement de mise en page pendant tout glissement de zone en mode édition.

Découvert de la même façon que les autres : en **tentant** de remplacer un raccourci de test par le vrai geste de réordonnancement. La tentative a échoué de façon reproductible, sur session neuve, sans overlay.

**Conséquence qui compte pour toi :** le vrai geste de réordonnancement est aujourd'hui **intestable en widget test**. Le test correspondant passe par une mutation directe de la session, documentée explicitement comme ne prouvant ni le câblage du glisser-déposer ni l'accessibilité du geste. C'est un point mort dans la couverture.

La revue recommande — et je reprends la recommandation — que **le plan du lot 6 porte un critère de sortie « le vrai geste de réordonnancement passe en test »**. Sans ce rappel, le report devient permanent par défaut.

Pourquoi c'est chez toi : une hauteur d'aperçu fixe est exactement une décision de densité, et le lot 6 est le lot de la densité.

## 7. Si tu ne devais retenir qu'une chose

Le défaut le plus coûteux de ces trois lots n'a pas été trouvé par une revue de code. Il a été trouvé en remplaçant, dans un test, un appel de callback par un vrai `tester.tap()`.

Tout le reste — les revues par tâche, les revues de branche, les rondes de correction — n'a fait que confirmer ce que ce geste avait révélé.

Bonne route.
