# Life Counter V4 — Lot 3 : Commander damage et tiroir — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre la saisie des dégâts de commandant quasi gratuite — un tap pendant le buffer de dégâts — et donner au tiroir son contenu définitif, plus une vue d'ensemble de la table.

**Architecture:** Le tiroir reçoit la grille de commander damage **reçu**, qui remplace la ligne provisoire du lot 2. L'attribution à la volée se greffe sur le buffer de dégâts existant, sans coût de geste supplémentaire. La vue table est un écran plein, ouvert par un bouton de la barre centrale. Le lot solde aussi la dette de `PlayerZoneNotifier`, laissée à moitié orpheline par le lot 2.

**Tech Stack:** Flutter (SDK ^3.9.2), `flutter_riverpod` ^3.0.3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md` (§2.3, §2.6, §2.7, §3.3)

## Global Constraints

- Dart SDK `^3.9.2`, `flutter_riverpod` `^3.0.3` — ne pas ajouter de dépendance.
- Branche à créer depuis `main` (lot 2 mergé à `7821c6c`).
- **Couleurs et typographie via `AppColors` et `AppTextStyles` uniquement.** `AppTextStyles` expose des **méthodes** (`cardTitle()`, `body()`, `label()`, `lifeNumeral()`, `lifeBadge()`, `lifeStepLabel()`, `lifeHandleChip()`), jamais des constantes. `AppColors.greyShade800` est un **getter**, inutilisable en expression `const`.
- **`ref.watch(gameSessionNotifierProvider)` doit rester la toute première instruction de `build()`** dans `life_counter_page.dart`. Un avertissement est en place à cet endroit : ne pas le supprimer.
- **`ref` ne doit jamais être utilisé dans `dispose()`** d'un `ConsumerState`, ni directement, ni via un getter qui le lit.
- Aucun nouveau hook `@visibleForTesting`. Le fichier `life_counter_page.dart` en compte 7, tous hérités du lot 1 ; ce lot en **retire** deux (tâche 5).
- `flutter analyze` sans erreur ni avertissement sur les fichiers touchés ; `flutter test` vert (**901 tests** au départ).
- Pas de `// ignore_for_file:` ; seulement des `// ignore:` ciblés ligne à ligne.
- **`git add` avec chemins explicites uniquement, jamais `-A` ni `git commit -a`.** Le répertoire de travail est partagé avec une autre session qui y laisse des fichiers de documentation non commités. Vérifier avec `git status -s` avant et `git show --stat` après.
- Messages de commit terminés par : `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

## La leçon des lots 1 et 2, à appliquer partout dans celui-ci

Les défauts les plus graves des deux lots précédents — quatre constats Critical sur la surface de gestes, plus un cinquième à la revue finale — avaient tous **des tests verts**. Ils partageaient une seule cause :

> **Un test qui appelle un callback directement, ou qui joue une chronologie que l'appareil ne produit jamais, ne prouve rien du comportement réel.**

Trois exemples vécus, à garder en tête :

1. Un test appelait `handle.onTap!()` au lieu de `tester.tap(...)`. Il validait le câblage — correct — sans voir que `EliminationOverlay` absorbait tous les gestes, rendant la zone d'un joueur éliminé totalement inerte. Défaut préexistant, jamais vu jusqu'à ce que le test joue un vrai tap.
2. Un test appelait `handleWheelDrag(-130)` en **un seul appel**. Un vrai doigt livre une dizaine de pixels par événement : le seuil d'accélération n'était jamais atteint, et la molette était linéaire sur appareil.
3. `tester.longPress` n'envoie aucun événement de mouvement. L'appui long était annulé au moindre pixel, donc quasi inatteignable au doigt, sans qu'aucun test ne le voie.

**Règles pour ce lot :**
- Un test d'interaction **joue le geste** (`tester.tap`, `tester.drag`, `tester.startGesture`), il n'appelle pas le callback.
- Un test de geste continu le **fractionne** en événements de la taille que produit un appareil (~10 px par `PointerMoveEvent`).
- Pour chaque test de non-régression, **casser temporairement le code cible** et vérifier que le test échoue, avant de le déclarer bon.

## Note sur la forme de ce plan — déviation assumée

Les plans des lots 1 et 2 donnaient le code des tests **verbatim**. C'est ce que prescrit la méthode, et ce n'est pas ce que fait celui-ci : les tests y sont décrits par leurs **assertions exactes et leurs cas limites**, pas par leur code.

La raison est empirique. Sur les deux lots précédents, le code que j'ai écrit de mémoire a introduit **au moins six défauts** qu'il a fallu corriger avant de pouvoir avancer : un constructeur `Player` dont un paramètre requis manquait, des méthodes `AppTextStyles` inventées, un getter utilisé dans une expression `const`, une API `NotifierProvider.family` mal employée, une comparaison de `MapEntry` qui ne pouvait pas passer, un identifiant accentué illégal en Dart, une formule d'accélération dont le test échouait de façon déterministe. Chaque fois, l'implémenteur a dû diagnostiquer mon erreur avant de faire son travail.

Les descriptions de ce plan sont donc **précises sur ce qui doit être vérifié** — valeurs attendues, cas limites, nombre minimal de joueurs pour qu'une inversion soit détectable — et muettes sur la syntaxe. Chaque tâche demande explicitement de lire les signatures réelles dans le dépôt avant d'écrire.

Si cette forme gêne un implémenteur, qu'il le dise dans son rapport : c'est un arbitrage, pas une certitude.

---

## Dettes reportées du lot 2, à solder ici

**D1 — La moitié de `PlayerZoneNotifier` n'a aucun appelant.** `showFloatingNumber`, `animateFloatingNumber`, `removeFloatingNumber`, `handleRotationDrag`, `rotate90Degrees`, `reset()`, la classe `FloatingNumber` et les champs `floatingNumbers` / `nextNumberId` / `rotationAccumulator` ne sont appelés que par leurs propres tests. Pendant ce temps `player_zone.dart` réimplémente les nombres flottants (`:62-64`, `:171-188`) et la rotation (`:65-67`, `:189-209`) en `setState`, avec un type `FloatingNumberData` distinct dans `life_log.dart`.

C'est **exactement le motif que la spec §1 dénonce** — du code écrit, testé, jamais branché — reproduit à l'échelle d'un fichier : le lot 2 a remplacé un contrôleur orphelin de 241 lignes par un notifier dont la moitié est orpheline. Tâche 1.

**D2 — Le sélecteur de dégâts de commandant est orienté à l'envers.** `_showCommanderDamageSelector(Player attacker)` liste les **adversaires** et leur inflige des dégâts **depuis** le joueur ouvert. Or la poignée du même joueur affiche `worstCommanderDamage` **reçu**. Pour corriger ce que la poignée de Bob affiche, il faut ouvrir le tiroir d'Alice. La spec §2.7 demande « grille de commander damage **reçu** ». Tâche 2.

**D3 — Deux hooks de test dont la justification est démentie.** `updateLifeForTest` et `reorderForTest` se justifient par « les zones sont pivotées par `AdaptiveGrid`, le tap est fragile en test ». La tâche 6 du lot 2 a tapé réellement à travers la grille pivotée, et c'est ce durcissement qui a révélé le défaut de `EliminationOverlay`. Tâche 5.

---

## File Structure

**Créés :**

| Fichier | Responsabilité |
|---|---|
| `lib/widgets/life_counter/zone/commander_damage_grid.dart` | Grille des dégâts de commandant **reçus** par un joueur, une ligne par adversaire avec ses `±`. Encastrée dans le tiroir. |
| `lib/widgets/life_counter/zone/damage_attribution_row.dart` | Rangée d'avatars « de qui ? » affichée sous le chiffre pendant le buffer de dégâts. |
| `lib/pages/life_counter/table_view_page.dart` | Vue table : une ligne par joueur, tout son état lisible d'un coup. |
| Leurs trois fichiers de test | |

**Modifiés :**

| Fichier | Nature |
|---|---|
| `lib/widgets/life_counter/zone/player_drawer.dart` | La ligne provisoire « Dégâts de commandant » est remplacée par la grille (tâche 2). |
| `lib/widgets/life_counter/player_zone.dart` | Branché sur `PlayerZoneNotifier` ; perd ses champs `setState` de flottants et de rotation (tâche 1). |
| `lib/widgets/life_counter/life_log.dart` | `FloatingNumberData` supprimé au profit de `FloatingNumber` du notifier (tâche 1). |
| `lib/pages/life_counter/life_counter_page.dart` | Attribution à la volée (tâche 3), geste d'ouverture de la vue table (tâche 4), retrait de deux hooks (tâche 5). |

---

## Task 1 : Solder la dette — brancher `PlayerZone` sur son notifier

**Files:**
- Modify: `lib/widgets/life_counter/player_zone.dart`
- Modify: `lib/widgets/life_counter/life_log.dart`
- Modify: `lib/providers/player_zone_notifier.dart` (si des méthodes doivent être ajustées pour l'usage réel)
- Test: `test/widgets/life_counter/player_zone_test.dart`, `test/providers/player_zone_notifier_test.dart`

**Interfaces:**
- Consumes: `playerZoneNotifierProvider` (`.family` par `playerId`), `PlayerZoneState.floatingNumbers`, `showFloatingNumber(int delta)`, `animateFloatingNumber(int id)`, `removeFloatingNumber(int id)`, `handleRotationDrag(double delta, int currentQuarterTurns)`, `rotate90Degrees(int currentQuarterTurns)`.
- Produces: `LifeLog` consomme désormais `List<FloatingNumber>` (du notifier) au lieu de `List<FloatingNumberData>`.

> **Lis les signatures réelles dans `lib/providers/player_zone_notifier.dart` avant d'écrire.** Ce plan les décrit de mémoire ; le fichier fait foi. Si une signature ne correspond pas à l'usage que `PlayerZone` en a besoin, dis-le dans ton rapport plutôt que de contorsionner l'appelant.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/widgets/life_counter/player_zone_test.dart`, ajouter deux tests :

- **Les nombres flottants viennent du notifier.** Monter une `PlayerZone` dans un `ProviderScope` avec un `ProviderContainer` accessible, taper sur une moitié du cadran (un **vrai** `tester.tap`), puis vérifier que `container.read(playerZoneNotifierProvider(0)).floatingNumbers` n'est plus vide. Ce test échoue tant que la zone garde sa liste locale.
- **La rotation passe par le notifier.** Provoquer une rotation (par le bouton de l'en-tête, avec un vrai tap) et vérifier que le callback `onRotationChanged` reçoit la valeur attendue **et** que l'accumulateur du notifier a été utilisé. Formule l'assertion sur ce qui est observable ; si l'état de rotation n'est pas lisible depuis le notifier après un tap simple, teste plutôt le glissement fractionné.

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/player_zone_test.dart`
Expected: FAIL — la zone utilise encore ses champs locaux.

- [ ] **Step 3: Brancher**

Dans `lib/widgets/life_counter/player_zone.dart` :
- supprimer les champs `_floatingNumbers`, `_nextNumberId`, `_dragAccumulator`, `_rotationThreshold` ;
- supprimer les méthodes `_showFloatingNumber`, `_handleRotationDrag`, `_rotate90Degrees`, et appeler à leur place les méthodes du notifier ;
- lire `floatingNumbers` depuis le notifier pour alimenter `LifeLog`.

Dans `lib/widgets/life_counter/life_log.dart` : supprimer `FloatingNumberData` et faire consommer `FloatingNumber` (importé du notifier). Adapter les usages.

**Attention au cycle de vie :** les minuteurs qui animent puis retirent un nombre flottant ne doivent pas appeler `ref` après démontage. Le notifier survit au démontage de la zone (le provider n'est pas `autoDispose`), donc un appel tardif ne plantera pas — mais il écrirait dans l'état d'une zone qui n'existe plus. Garde les `if (!mounted) return;`.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/widgets/life_counter/player_zone_test.dart test/providers/player_zone_notifier_test.dart`
Expected: PASS.

Vérifier que plus rien n'est orphelin :

```bash
grep -rn "FloatingNumberData" lib/ test/
grep -rn "showFloatingNumber\|handleRotationDrag\|rotate90Degrees" lib/ --include=*.dart | grep -v player_zone_notifier.dart
```

Le premier doit être vide. Le second doit montrer des appels depuis `player_zone.dart`.

Run: `flutter test` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/widgets/life_counter/player_zone.dart lib/widgets/life_counter/life_log.dart lib/providers/player_zone_notifier.dart test/widgets/life_counter/player_zone_test.dart test/providers/player_zone_notifier_test.dart
git commit -m "refactor: wire PlayerZone floating numbers and rotation to its notifier

Solde la dette du lot 2 : la moitie de PlayerZoneNotifier n'avait aucun
appelant pendant que PlayerZone reimplementait la meme chose en setState,
avec un type FloatingNumberData duplique. C'est le motif que la spec §1
denonce, reproduit a l'echelle d'un fichier.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2 : La grille de commander damage reçu, dans le tiroir

**Files:**
- Create: `lib/widgets/life_counter/zone/commander_damage_grid.dart`
- Create: `test/widgets/life_counter/zone/commander_damage_grid_test.dart`
- Modify: `lib/widgets/life_counter/zone/player_drawer.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart`
- Test: `test/widgets/life_counter/zone/player_drawer_test.dart`, `test/pages/life_counter/life_counter_page_test.dart`

**Interfaces:**
- Produces :
  ```dart
  class CommanderDamageOpponent {
    const CommanderDamageOpponent({required this.playerId, required this.name, required this.colorValue, required this.damage});
    final int playerId;
    final String name;
    final int colorValue;
    final int damage;
  }

  class CommanderDamageGrid extends StatelessWidget {
    const CommanderDamageGrid({super.key, required this.opponents, required this.lethalThreshold, required this.onDelta});
    final List<CommanderDamageOpponent> opponents;
    final int lethalThreshold;
    final void Function(int sourcePlayerId, int delta) onDelta;
  }
  ```
- `showPlayerDrawer` perd `onCommanderDamage` et gagne `List<CommanderDamageOpponent> commanderDamage` + `void Function(int sourcePlayerId, int delta) onCommanderDamageDelta` + `int lethalCommanderDamage`.

> **Le sens compte, c'est toute la dette D2.** La grille liste les adversaires en tant que **sources** de dégâts reçus par le joueur dont le tiroir est ouvert. `onDelta(sourcePlayerId, delta)` doit se câbler sur `GameSessionNotifier.addCommanderDamage(targetPlayerId: <joueur du tiroir>, sourcePlayerId: <ligne touchée>, damage: delta, ...)`. Si tu écris l'inverse, la poignée continuera d'afficher un chiffre que le tiroir ne corrige pas.

> **La ligne provisoire du lot 2 disparaît**, ainsi que le callback `onCommanderDamage` et, s'il n'a plus d'appelant, la méthode `_showCommanderDamageSelector` de la page. Vérifie ses appelants avant de la supprimer ; si le dé ou un autre chemin l'utilise encore, garde-la et dis-le.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/widgets/life_counter/zone/commander_damage_grid_test.dart` :
- la grille affiche une ligne par adversaire, avec son nom et son total actuel ;
- taper « + » sur une ligne émet `onDelta(<playerId de cette ligne>, 1)` — **et pas** l'identifiant d'une autre ligne. Utilise au moins trois adversaires avec des identifiants distincts, sans quoi une inversion passerait inaperçue ;
- une source ayant atteint le seuil létal est signalée visuellement (vérifie une propriété observable, pas une couleur exacte) ;
- un adversaire éliminé apparaît quand même, son total restant consultable.

Dans `test/pages/life_counter/life_counter_page_test.dart`, un test d'intégration : ouvrir le tiroir d'un joueur par un **vrai tap** sur sa poignée, incrémenter une ligne de la grille, et vérifier dans la session que `commanderDamageReceived` du **joueur du tiroir** a augmenté pour la **bonne source**, et que ses points de vie ont baissé d'autant.

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/zone/commander_damage_grid_test.dart test/pages/life_counter/life_counter_page_test.dart`
Expected: FAIL — le widget n'existe pas.

- [ ] **Step 3: Écrire la grille et la câbler**

Créer `CommanderDamageGrid` : une ligne par adversaire, pastille de couleur, nom, total, boutons `−` et `+`. Aucun `TextStyle` brut, aucune couleur littérale.

Dans `player_drawer.dart` : remplacer la ligne d'action provisoire par la grille, sous les compteurs et au-dessus des actions (spec §2.7 : compteurs, puis grille, puis actions).

Dans `life_counter_page.dart` : construire la liste des adversaires depuis la session (tous les joueurs sauf celui du tiroir), avec leurs dégâts déjà reçus, et câbler `onCommanderDamageDelta` sur `addCommanderDamage` dans le bon sens.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test`
Expected: PASS. Les tests du tiroir du lot 2 doivent être adaptés à la nouvelle signature, mais **aucune de leurs assertions ne doit être affaiblie** — ils verrouillent les quatre actions rétablies au lot 2.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/widgets/life_counter/zone/commander_damage_grid.dart test/widgets/life_counter/zone/commander_damage_grid_test.dart lib/widgets/life_counter/zone/player_drawer.dart lib/pages/life_counter/life_counter_page.dart test/widgets/life_counter/zone/player_drawer_test.dart test/pages/life_counter/life_counter_page_test.dart
git commit -m "feat: add received commander damage grid to the player drawer

Remplace la ligne provisoire du lot 2 et corrige son orientation : la
grille liste les adversaires comme SOURCES des degats recus par le joueur
dont le tiroir est ouvert, ce que la poignee affichait deja sans pouvoir
le corriger.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3 : Attribution à la volée

**Files:**
- Create: `lib/widgets/life_counter/zone/damage_attribution_row.dart`
- Create: `test/widgets/life_counter/zone/damage_attribution_row_test.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart`
- Test: `test/pages/life_counter/life_counter_page_test.dart`

**Interfaces:**
- Consumes: le buffer de dégâts existant (`_pendingDamage`, `_pendingTimers`, `_updateLife`, `_applyPendingDamage` dans `life_counter_page.dart`), `GameFormat.maxCommanderDamage`.
- Produces :
  ```dart
  class DamageAttributionRow extends StatelessWidget {
    const DamageAttributionRow({super.key, required this.opponents, required this.onAttribute});
    final List<CommanderDamageOpponent> opponents; // réutilise le type de la tâche 2
    final void Function(int sourcePlayerId) onAttribute;
  }
  ```

> **Spec §2.6.** Pendant que le buffer tourne, une rangée d'avatars adverses apparaît sous le chiffre. Un tap dessus transforme le dégât en cours en commander damage de ce joueur. Aucun tap : dégât générique. Coût : **un seul tap, et seulement quand il s'agit de commandant.**

> **Déclenchement :** uniquement quand `_currentFormat.maxCommanderDamage > 0`. En Standard, la rangée n'apparaît jamais.

> **Le point délicat :** l'attribution doit consommer le dégât **en attente**, pas en ajouter un nouveau. Si le joueur a tapé cinq fois `−1` puis attribue à Sam, le résultat doit être « 5 dégâts de commandant de Sam », pas « 5 dégâts génériques **plus** 5 de Sam ». Annule le minuteur en attente, retire l'entrée de `_pendingDamage`, et applique le tout via `addCommanderDamage`, qui ajuste déjà les points de vie.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/widgets/life_counter/zone/damage_attribution_row_test.dart` : la rangée affiche un avatar par adversaire ; un tap émet le bon `sourcePlayerId` (au moins trois adversaires, identifiants distincts).

Dans `test/pages/life_counter/life_counter_page_test.dart`, trois tests d'intégration, tous avec de **vrais gestes** :
- en format Commander, après des taps sur une moitié du cadran, la rangée d'attribution est visible ;
- taper un avatar convertit le dégât en attente : `commanderDamageReceived[<source>]` vaut le montant tapé, les points de vie ont baissé **une seule fois** du même montant, et `_pendingDamage` est vide ;
- ne pas taper : après expiration du buffer, le dégât est générique et `commanderDamageReceived` reste vide ;
- en format Standard (`maxCommanderDamage == 0`), la rangée n'apparaît jamais.

Le deuxième test est le plus important : il verrouille l'absence de double application.

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/widgets/life_counter/zone/damage_attribution_row_test.dart test/pages/life_counter/life_counter_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

Créer `DamageAttributionRow`, puis l'afficher dans la page sous le chiffre de la zone concernée, conditionnée à `_pendingDamage[playerId] != null && _currentFormat.maxCommanderDamage > 0`.

L'attribution : annuler `_pendingTimers[playerId]`, retirer `_pendingDamage[playerId]`, appeler `addCommanderDamage(targetPlayerId: playerId, sourcePlayerId: <avatar tapé>, damage: <montant absolu du pending>, gameDuration: ...)`, puis `_saveSnapshot()` et la vérification de condition de mort, comme le fait `_applyPendingDamage`.

**Attention au signe :** le pending est négatif pour des dégâts. `addCommanderDamage` prend un `damage` positif et retire les PV lui-même. Une erreur de signe ici rendrait des points de vie au lieu d'en retirer — écris le test pour qu'il l'attrape.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/widgets/life_counter/zone/damage_attribution_row.dart test/widgets/life_counter/zone/damage_attribution_row_test.dart lib/pages/life_counter/life_counter_page.dart test/pages/life_counter/life_counter_page_test.dart
git commit -m "feat: attribute buffered damage to a commander in one tap

Corrige le defaut de fond du systeme actuel, ou retirer les PV et
enregistrer les degats de commandant sont deux actions separees qu'on
oublie de synchroniser.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4 : La vue table

**Files:**
- Create: `lib/pages/life_counter/table_view_page.dart`
- Create: `test/pages/life_counter/table_view_page_test.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart`

**Interfaces:**
- Consumes: `gameSessionNotifierProvider`, `GameSession`, `PlayerState`.
- Produces: `Future<void> showTableView(BuildContext context, WidgetRef ref)` ou un widget de route — choisis selon ce qui s'intègre le mieux, et documente ton choix. Plus un bouton dans la barre centrale de `life_counter_page.dart`, à côté des actions globales existantes.

> **Spec §2.3.** Une liste compacte, une ligne par joueur : PV, compteurs non nuls, monarque, état d'élimination. Elle répond au moment où l'on veut lire **toute** la table, typiquement avant d'attaquer.

> **L'ouverture se fait par un bouton dans la barre centrale — pas par un geste à deux doigts.** La spec §2.3 prévoyait « un geste global à deux doigts » ; il est abandonné par décision explicite, et §2.3 est amendée en ce sens.
>
> Raison : un détecteur à deux pointeurs entrerait en concurrence avec la surface de gestes de `LifeDial`, qui a coûté **trois rondes de correction et quatre constats Critical** au lot 2, et dont l'équilibre tient à une seule décision architecturale (l'appui long vit hors de l'arène de gestes). Y ajouter un concurrent multi-pointeurs, c'est rouvrir précisément ce qui vient d'être stabilisé, pour un confort marginal. La barre centrale existe déjà et porte les actions globales.
>
> **N'ajoute aucun détecteur de geste sur les zones joueur dans cette tâche.** Les 20 tests de `life_dial_test.dart` doivent rester verts sans modification — c'est le garde-fou.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/pages/life_counter/table_view_page_test.dart` : la vue affiche une ligne par joueur, avec ses PV ; les compteurs à zéro n'apparaissent pas ; le monarque est signalé ; un joueur éliminé est distingué. Construis une session à quatre joueurs aux états contrastés.

Dans `test/pages/life_counter/life_counter_page_test.dart` : un **vrai tap** sur le bouton de la barre centrale affiche la vue.

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/pages/life_counter/table_view_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

Écrire la vue, puis le bouton de la barre centrale qui l'ouvre. Dans cet ordre : la vue est testable seule.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test`
Expected: PASS, **y compris les 20 tests de `life_dial_test.dart` sans modification**. S'ils cassent, tu as touché à la surface de gestes des zones, ce que cette tâche interdit.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/pages/life_counter/table_view_page.dart test/pages/life_counter/table_view_page_test.dart lib/pages/life_counter/life_counter_page.dart test/pages/life_counter/life_counter_page_test.dart
git commit -m "feat: add table view showing every player's state at a glance

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 : Solder la dette — retirer deux hooks de test

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart`
- Modify: `test/pages/life_counter/life_counter_page_test.dart`

**Interfaces:** aucune nouvelle.

> **D3.** `updateLifeForTest` et `reorderForTest` se justifient par « les zones sont pivotées par `AdaptiveGrid`, le tap est fragile en test ». Le lot 2 a démenti cette justification en tapant réellement à travers la grille pivotée — et ce durcissement a révélé un défaut qu'aucun test ne voyait.

- [ ] **Step 1: Remplacer les usages par de vrais gestes**

Dans `test/pages/life_counter/life_counter_page_test.dart`, remplacer chaque appel à `updateLifeForTest` par un vrai tap sur la moitié correspondante du `LifeDial` du joueur visé, et chaque appel à `reorderForTest` par le geste de réordonnancement réel, ou à défaut par une mutation de la session via le container suivie d'un `pump` — **en disant lequel tu as choisi et pourquoi**.

Les zones étant pivotées, viser la bonne moitié demande de calculer la position depuis le rectangle de la zone. Le lot 2 l'a fait pour la poignée (`tester.tap(find.byType(ConditionalHandle).first)`) : inspire-t'en.

- [ ] **Step 2: Lancer les tests**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: PASS. **Si un test casse au passage au vrai geste, ne l'affaiblis pas** : c'est peut-être un défaut réel, comme au lot 2. Signale-le.

- [ ] **Step 3: Supprimer les hooks**

Retirer `updateLifeForTest` et `reorderForTest` de `life_counter_page.dart`. Vérifier :

```bash
grep -c "@visibleForTesting" lib/pages/life_counter/life_counter_page.dart
```

Attendu : **5**.

- [ ] **Step 4: Lancer la suite complète**

Run: `flutter analyze` — Expected: aucune erreur.
Run: `flutter test` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/life_counter/life_counter_page.dart test/pages/life_counter/life_counter_page_test.dart
git commit -m "test: replace two test hooks with real gestures

Leur justification — les zones pivotees rendraient le tap fragile en test —
a ete dementie au lot 2, ou taper reellement a travers la grille pivotee a
revele un defaut de hit-testing qu'aucun test ne voyait.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Critères de sortie du lot

- [ ] `flutter test` vert sur toute la suite.
- [ ] `flutter analyze` sans erreur ni avertissement sur les fichiers touchés.
- [ ] `grep -rn "FloatingNumberData" lib/ test/` ne retourne rien.
- [ ] Aucune méthode de `PlayerZoneNotifier` n'est sans appelant hors de ses tests.
- [ ] `grep -c "@visibleForTesting" lib/pages/life_counter/life_counter_page.dart` retourne **5**.
- [ ] `grep -rn "onCommanderDamage\b" lib/` ne retourne rien (la ligne provisoire du lot 2 a disparu).
- [ ] Les 20 tests de `life_dial_test.dart` sont verts **sans modification**.
- [ ] **Vérification manuelle — attribution.** Partie Commander à 4 : taper 7 dégâts sur un joueur, attribuer à un adversaire, vérifier que les PV ont baissé **une seule fois** de 7 et que le total de cette source est bien 7.
- [ ] **Vérification manuelle — sens de la grille.** Ouvrir le tiroir d'un joueur, corriger un total dans la grille, et vérifier que c'est bien la poignée **de ce joueur** qui change.
- [ ] **Vérification manuelle — vue table.** Ouvrir la vue à 4 joueurs depuis le bouton de la barre centrale et vérifier que l'état lu correspond aux zones.

## Ce que ce lot ne fait pas

- **Le setup** (reprise en un tap, setup inline) — lot 4.
- **Les compteurs personnalisés** — lot 5. Le tiroir code toujours les trois compteurs en dur.
- **La géométrie de table et la densité d'affichage** — lot 6, dont la spec est `docs/superpowers/specs/2026-09-16-life-counter-v4-lot6-table-multijoueur-design.md`. L'ordre d'exécution retenu place le lot 6 juste après celui-ci.
