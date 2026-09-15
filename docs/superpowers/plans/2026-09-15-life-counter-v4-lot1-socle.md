# Life Counter V4 — Lot 1 : Socle — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire passer l'état du life counter sous un `Notifier` Riverpod clé par `playerId`, en corrigeant au passage deux bugs de perte/corruption d'état, et couvrir la page de tests pour la première fois.

**Architecture:** Refactor par strangulation in-place. `GameSessionController` devient un `Notifier<GameSession?>` ; `LifeCounterPage` cesse de tenir une copie locale de la session et de la resynchroniser à la main. Aucun changement visible pour le joueur : ce lot est le filet qui rend les lots 2 à 5 sûrs.

**Tech Stack:** Flutter (SDK ^3.9.2), `flutter_riverpod` ^3.0.3, Drift, `shared_preferences` ^2.2.3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md`

## Global Constraints

- Dart SDK `^3.9.2`, `flutter_riverpod` `^3.0.3` — ne pas ajouter de dépendance.
- Style maison des notifiers : `class XNotifier extends Notifier<T>` avec `T build()`, exposé par `final xProvider = NotifierProvider<XNotifier, T>(XNotifier.new);`. Référence : `lib/providers/collection_value_provider.dart:65` et `:194`.
- Les tests existants sont des tests unitaires purs sans Riverpod. **Ce lot introduit `ProviderContainer` dans les tests — il n'y a aucun précédent dans `test/`.** Les tâches concernées donnent le squelette complet.
- Commandes : `flutter test <chemin>` pour un fichier, `flutter analyze` avant chaque commit.
- Aucun changement visible pour l'utilisateur dans tout ce lot. Toute modification d'UI est hors périmètre.
- Les 18 fichiers de tests existants de la zone doivent rester verts à chaque commit.

---

## État des lieux vérifié

Deux bugs ont été confirmés par lecture du code. Le second n'apparaît pas dans l'audit initial et il est plus grave que le premier.

### Bug A — perte de la partie restaurée après un crash (critique)

`lib/pages/life_counter/life_counter_page.dart:178-192`, méthode `_loadGame()` :

```dart
if (await sessionService.hasActiveGame()) {
  final snapshot = await sessionService.loadSnapshot();
  if (snapshot != null) {
    _controller = GameSessionController();   // <- contrôleur neuf, _session interne = null
    setState(() {
      _session = snapshot;                   // <- seule la copie de la page reçoit le snapshot
      _currentFormat = snapshot.format;
      _isLoading = false;
    });
    return;
  }
}
```

Le contrôleur ne reçoit jamais le snapshot : `restoreSession()` n'est appelé qu'aux lignes 459, 480, 900 et 915, qui correspondent au changement de couleur, au changement de skin, à l'undo d'élimination et au reorder — jamais au chargement.

Conséquence : après une reprise de partie, la première action qui passe par le contrôleur le fait sortir immédiatement (`if (_session == null) return;` dans `game_session_controller.dart:25`), puis la page écrase sa propre copie avec le `null` du contrôleur :

```dart
_controller.updateLife(playerId, pending, gameDuration: _gameDuration);  // no-op
_pendingDamage.remove(playerId);
_pendingTimers.remove(playerId);
setState(() => _session = _controller.session);   // _session <- null : la partie disparaît
```

Chemins touchés : `_applyPendingDamage` (`:442-445`), `_updatePlayerRotation` (`:466-467`), `toggleMonarch` (`:837-838`), le reset de compteurs (`:873-876`), `_updateCounter` (`:940-941`), les presets d'orientation (`:1145-1147`) et `addCommanderDamage` (`:557-563`, `:571-577`).

**Reproduction :** lancer une partie, tuer l'application, la rouvrir (la partie se restaure), puis toucher les PV d'un joueur et attendre 2 secondes. La partie s'efface.

### Bug B — badge et flash sur la mauvaise zone après un reorder

`_pendingDamage` est **écrit** par `playerId` (`:426`) et lu par `playerId` dans `_toLegacyPlayer` (`:102`), mais le rendu le lit par **index d'affichage** (`:781`). Idem pour `_commanderDamageFlash`, alimenté avec un `playerId` (`:579`) et testé contre un index (`:758`).

Tant que `playerId == index`, rien ne se voit. `_onReorderPlayers` (`:905-918`) permute physiquement la liste sans toucher aux `playerId` : après un reorder, le badge de dégâts en attente et le flash rouge de commander damage s'affichent sur une autre zone que celle concernée.

---

## File Structure

**Créés :**

| Fichier | Responsabilité |
|---|---|
| `lib/providers/game_session_notifier.dart` | `GameSessionNotifier extends Notifier<GameSession?>` — toute la logique de mutation de session, reprise de `GameSessionController`. |
| `test/providers/game_session_notifier_test.dart` | Tests unitaires du notifier via `ProviderContainer`. |
| `test/pages/life_counter/life_counter_page_test.dart` | Premiers tests d'orchestration de la page : reprise après crash, buffer de dégâts, reorder. |

**Modifiés :**

| Fichier | Nature |
|---|---|
| `lib/pages/life_counter/life_counter_page.dart` | Suppression de `_session`, du champ `_controller`, des 15 resynchros et des 4 `restoreSession()`. État transitoire clé par `playerId`. Durée et timer déplacés dans la session. |
| `lib/providers/game_session_provider.dart` | Remplace le `Provider<GameSessionController>` non consommé par un alias vers le nouveau provider. |
| `lib/controllers/game_session_controller.dart` | Supprimé en fin de lot (tâche 7), une fois sans consommateur. |
| `test/controllers/game_session_controller_test.dart` | Porté sur le notifier puis renommé (tâche 2). |

---

## Task 1 : Corriger la perte de partie à la reprise (Bug A)

Ce correctif est indépendant de la migration Riverpod et doit partir en premier : c'est une perte de données en production. Une ligne de correctif, mais le test qui l'accompagne est le premier test de la page et sert de fondation aux tâches suivantes.

**Files:**
- Create: `test/pages/life_counter/life_counter_page_test.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart:184`

**Interfaces:**
- Consumes: `GameSessionController.restoreSession(GameSession)` (`lib/controllers/game_session_controller.dart:121`), `GameSessionService.saveSnapshot/loadSnapshot` (`lib/services/game_session_service.dart:9,15`).
- Produces: `pumpLifeCounter(WidgetTester, {GameSession? snapshot})` — helper montant la page avec un snapshot pré-chargé. Les tâches suivantes montent la page via un `ProviderContainer` explicite, dont elles ont besoin pour lire l'état : ce helper reste réservé aux tests qui partent d'un snapshot.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/pages/life_counter/life_counter_page_test.dart` :

```dart
// test/pages/life_counter/life_counter_page_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/pages/life_counter/life_counter_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final commanderFormat =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

final testConfigs = [
  PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
  PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
  PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
  PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
];

/// Monte la page avec un snapshot pré-chargé dans SharedPreferences.
/// `GameHistoryService()` sans base retombe sur SharedPreferences
/// (voir lib/services/game_history_service.dart:12), donc aucun Drift en test.
Future<void> pumpLifeCounter(
  WidgetTester tester, {
  GameSession? snapshot,
}) async {
  SharedPreferences.setMockInitialValues({
    if (snapshot != null) 'active_game_snapshot': json.encode(snapshot.toJson()),
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
      ],
      child: const MaterialApp(home: LifeCounterPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'la partie restaurée survit à une modification de PV (régression bug A)',
      (tester) async {
    // Une partie en cours : Alex a déjà perdu 6 PV.
    final restored = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    ).copyWith(
      players: [
        GameSession.newGame(
          format: commanderFormat,
          playerConfigs: testConfigs,
        ).players[0].copyWith(life: 34),
        ...GameSession.newGame(
          format: commanderFormat,
          playerConfigs: testConfigs,
        ).players.sublist(1),
      ],
    );

    await pumpLifeCounter(tester, snapshot: restored);

    // La partie restaurée est bien affichée.
    expect(find.text('34'), findsOneWidget);

    // On retire 1 PV au joueur 0 et on laisse le buffer de 2 s s'appliquer.
    final state = tester.state<dynamic>(find.byType(LifeCounterPage));
    // ignore: invalid_use_of_protected_member
    state.updateLifeForTest(0, -1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Avant correctif : la session est écrasée par le null du contrôleur.
    expect(find.text('33'), findsOneWidget,
        reason: 'la partie restaurée ne doit pas être effacée');
  });
}
```

Le test appelle `updateLifeForTest`, qui n'existe pas encore. Ajouter dans `_LifeCounterPageState` de `lib/pages/life_counter/life_counter_page.dart`, juste au-dessus de `void _updateLife(` :

```dart
  /// Point d'entrée de test pour piloter le buffer de dégâts sans simuler de tap
  /// (les zones sont pivotées par AdaptiveGrid, ce qui rend le tap fragile en test).
  @visibleForTesting
  void updateLifeForTest(int playerId, int change) => _updateLife(playerId, change);
```

et ajouter l'import `import 'package:flutter/foundation.dart';` en tête de fichier s'il est absent.

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: FAIL — `find.text('33')` ne trouve rien, la session ayant été remplacée par `null`.

- [ ] **Step 3: Corriger**

Dans `lib/pages/life_counter/life_counter_page.dart`, méthode `_loadGame()`, remplacer :

```dart
        _controller = GameSessionController();
```

par :

```dart
        _controller = GameSessionController();
        // Sans ceci le contrôleur démarre avec une session nulle : la première
        // mutation est un no-op et écrase la partie restaurée (bug A).
        _controller.restoreSession(snapshot);
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: PASS

Run: `flutter test test/controllers/ test/models/ test/services/ test/widgets/life_counter/`
Expected: PASS — aucune régression sur les 18 fichiers existants.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add test/pages/life_counter/life_counter_page_test.dart lib/pages/life_counter/life_counter_page.dart
git commit -m "fix: restore controller session on crash recovery

La partie restaurée depuis le snapshot n'était donnée qu'à la copie locale
de la page, jamais au contrôleur. La première mutation était donc un no-op
et la page écrasait ensuite sa session avec le null du contrôleur, effaçant
la partie en cours.

Premier test de LifeCounterPage.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2 : Créer `GameSessionNotifier`

Portage à l'identique de la logique de `GameSessionController` dans un `Notifier<GameSession?>`. Aucun consommateur n'y est branché à cette tâche — la page bascule en tâche 3.

**Files:**
- Create: `lib/providers/game_session_notifier.dart`
- Create: `test/providers/game_session_notifier_test.dart`
- Test: `test/controllers/game_session_controller_test.dart` (doit rester vert)

**Interfaces:**
- Consumes: `GameSession`, `PlayerState`, `LifeEvent` (`lib/models/game_session.dart`), `GameFormat`, `PlayerConfig`.
- Produces:
  - `class GameSessionNotifier extends Notifier<GameSession?>`
  - `final gameSessionNotifierProvider = NotifierProvider<GameSessionNotifier, GameSession?>(GameSessionNotifier.new);`
  - Méthodes, signatures identiques à l'ancien contrôleur : `startNewGame({required GameFormat format, required List<PlayerConfig> playerConfigs, List<String>? extraCounterIds, String? tag})`, `updateLife(int playerId, int delta, {required Duration gameDuration})`, `updateCounter(int playerId, String counterId, int value)`, `addCommanderDamage({required int targetPlayerId, required int sourcePlayerId, required int damage, required Duration gameDuration})`, `eliminatePlayer(int playerId, {required Duration atDuration})`, `toggleMonarch(int playerId)`, `reorderPlayers(List<int> newOrder)`, `updateRotation(int playerId, int quarterTurns)`, `endGame()`, `restoreSession(GameSession session)`, `clear()`.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/providers/game_session_notifier_test.dart` :

```dart
// test/providers/game_session_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';

void main() {
  late ProviderContainer container;

  final commanderFormat =
      GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');
  final configs = [
    PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
    PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
    PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
    PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
  ];

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  GameSessionNotifier get notifier =>
      container.read(gameSessionNotifierProvider.notifier);

  test('build() démarre sans session', () {
    expect(container.read(gameSessionNotifierProvider), isNull);
  });

  test('startNewGame place une session dans le state', () {
    notifier.startNewGame(format: commanderFormat, playerConfigs: configs);
    final session = container.read(gameSessionNotifierProvider);
    expect(session, isNotNull);
    expect(session!.players, hasLength(4));
    expect(session.players[0].life, 40);
  });

  test('updateLife notifie les écoutants', () {
    notifier.startNewGame(format: commanderFormat, playerConfigs: configs);

    final seen = <int?>[];
    container.listen(
      gameSessionNotifierProvider,
      (_, next) => seen.add(next?.players[0].life),
      fireImmediately: false,
    );

    notifier.updateLife(0, -6, gameDuration: const Duration(minutes: 1));

    expect(seen, [34]);
    expect(container.read(gameSessionNotifierProvider)!.players[0].lifeHistory,
        hasLength(1));
  });

  test('addCommanderDamage retire les PV et journalise la source', () {
    notifier.startNewGame(format: commanderFormat, playerConfigs: configs);
    notifier.addCommanderDamage(
      targetPlayerId: 0,
      sourcePlayerId: 2,
      damage: 7,
      gameDuration: const Duration(minutes: 3),
    );

    final target = container.read(gameSessionNotifierProvider)!.players[0];
    expect(target.life, 33);
    expect(target.commanderDamageReceived[2], 7);
    expect(target.lifeHistory.last.source, 'Commander: Sarah');
  });

  test('toggleMonarch est exclusif', () {
    notifier.startNewGame(format: commanderFormat, playerConfigs: configs);
    notifier.toggleMonarch(1);
    notifier.toggleMonarch(3);

    final players = container.read(gameSessionNotifierProvider)!.players;
    expect(players.where((p) => p.isMonarch).map((p) => p.playerId), [3]);
  });

  test('les mutations sans session sont sans effet', () {
    notifier.updateLife(0, -5, gameDuration: Duration.zero);
    expect(container.read(gameSessionNotifierProvider), isNull);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/providers/game_session_notifier_test.dart`
Expected: FAIL à la compilation — `game_session_notifier.dart` n'existe pas.

- [ ] **Step 3: Écrire le notifier**

Créer `lib/providers/game_session_notifier.dart` :

```dart
// lib/providers/game_session_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';

/// Source de vérité unique de la partie en cours.
///
/// Remplace GameSessionController, que la page instanciait à la main tout en
/// gardant une copie locale resynchronisée manuellement. Ici l'état vit dans
/// le notifier et nulle part ailleurs.
class GameSessionNotifier extends Notifier<GameSession?> {
  @override
  GameSession? build() => null;

  void startNewGame({
    required GameFormat format,
    required List<PlayerConfig> playerConfigs,
    List<String>? extraCounterIds,
    String? tag,
  }) {
    state = GameSession.newGame(
      format: format,
      playerConfigs: playerConfigs,
      extraCounterIds: extraCounterIds,
      tag: tag,
    );
  }

  void updateLife(int playerId, int delta, {required Duration gameDuration}) {
    final session = state;
    if (session == null) return;
    final players = session.players.map((p) {
      if (p.playerId == playerId) {
        final event = LifeEvent(delta: delta, timestamp: gameDuration);
        return p.copyWith(
          life: p.life + delta,
          lifeHistory: [...p.lifeHistory, event],
        );
      }
      return p;
    }).toList();
    state = session.copyWith(players: players);
  }

  void updateCounter(int playerId, String counterId, int value) {
    final session = state;
    if (session == null) return;
    final players = session.players.map((p) {
      if (p.playerId == playerId) {
        final counters = Map<String, int>.from(p.counters);
        counters[counterId] = value;
        return p.copyWith(counters: counters);
      }
      return p;
    }).toList();
    state = session.copyWith(players: players);
  }

  void addCommanderDamage({
    required int targetPlayerId,
    required int sourcePlayerId,
    required int damage,
    required Duration gameDuration,
  }) {
    final session = state;
    if (session == null) return;
    final sourcePlayer =
        session.players.where((p) => p.playerId == sourcePlayerId).firstOrNull;
    if (sourcePlayer == null) return;
    final sourceName = sourcePlayer.config.name;
    final players = session.players.map((p) {
      if (p.playerId == targetPlayerId) {
        final cmdDamage = Map<int, int>.from(p.commanderDamageReceived);
        cmdDamage[sourcePlayerId] = (cmdDamage[sourcePlayerId] ?? 0) + damage;
        final event = LifeEvent(
          delta: -damage,
          source: 'Commander: $sourceName',
          timestamp: gameDuration,
        );
        return p.copyWith(
          life: p.life - damage,
          commanderDamageReceived: cmdDamage,
          lifeHistory: [...p.lifeHistory, event],
        );
      }
      return p;
    }).toList();
    state = session.copyWith(players: players);
  }

  void eliminatePlayer(int playerId, {required Duration atDuration}) {
    final session = state;
    if (session == null) return;
    state = session.eliminatePlayer(playerId, atDuration: atDuration);
  }

  void toggleMonarch(int playerId) {
    final session = state;
    if (session == null) return;
    final currentMonarch =
        session.players.any((p) => p.playerId == playerId && p.isMonarch);
    final players = session.players.map((p) {
      if (p.playerId == playerId) return p.copyWith(isMonarch: !currentMonarch);
      return p.copyWith(isMonarch: false);
    }).toList();
    state = session.copyWith(players: players);
  }

  void reorderPlayers(List<int> newOrder) {
    final session = state;
    if (session == null) return;
    state = session.reorderPlayers(newOrder);
  }

  void updateRotation(int playerId, int quarterTurns) {
    final session = state;
    if (session == null) return;
    final players = session.players.map((p) {
      if (p.playerId == playerId) return p.copyWith(quarterTurns: quarterTurns);
      return p;
    }).toList();
    state = session.copyWith(players: players);
  }

  void endGame() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(isActive: false);
  }

  /// Remplace la session courante (reprise après crash, chargement de snapshot).
  void restoreSession(GameSession session) {
    state = session;
  }

  void clear() {
    state = null;
  }
}

final gameSessionNotifierProvider =
    NotifierProvider<GameSessionNotifier, GameSession?>(
  GameSessionNotifier.new,
);
```

`firstWhere`/`firstOrNull` sur `Iterable` vient de `package:collection` via l'import existant du modèle ; si `flutter analyze` signale `firstOrNull` comme non défini, ajouter `import 'package:collection/collection.dart';` en tête du fichier.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/providers/game_session_notifier_test.dart`
Expected: PASS (6 tests)

Run: `flutter test test/controllers/game_session_controller_test.dart`
Expected: PASS — l'ancien contrôleur est intact, la page l'utilise toujours.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/providers/game_session_notifier.dart test/providers/game_session_notifier_test.dart
git commit -m "feat: add GameSessionNotifier (Riverpod)

Portage à l'identique de GameSessionController en Notifier<GameSession?>.
Aucun consommateur branché à ce stade : la page bascule à la tâche suivante.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3 : Brancher la page sur le notifier

Le cœur du lot. La page perd sa copie locale et ses resynchros ; le correctif de la tâche 1 devient structurellement inutile, puisqu'il n'y a plus deux sources de vérité à synchroniser.

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart` (champs `:59-60`, `_loadGame` `:178-205`, `_startNewGame` `:230-241`, et les 15 sites listés ci-dessous)
- Modify: `lib/providers/game_session_provider.dart`
- Test: `test/pages/life_counter/life_counter_page_test.dart`

**Interfaces:**
- Consumes: `gameSessionNotifierProvider`, `GameSessionNotifier` (tâche 2).
- Produces: `LifeCounterPage` ne détient plus d'état de session ; `_session` devient un getter dérivé.

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter dans `test/pages/life_counter/life_counter_page_test.dart`, à l'intérieur de `main()` :

```dart
  testWidgets('la session vit dans le provider, pas dans la page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LifeCounterPage()),
      ),
    );
    await tester.pumpAndSettle();

    // La page a démarré une partie par défaut : elle est lisible depuis
    // l'extérieur, ce qui n'est possible que si l'état vit dans le provider.
    final session = container.read(gameSessionNotifierProvider);
    expect(session, isNotNull);
    expect(session!.players, hasLength(4));
    expect(session.players[0].life, 40);

    // Une mutation faite via le provider se reflète dans l'UI.
    container
        .read(gameSessionNotifierProvider.notifier)
        .updateLife(0, -7, gameDuration: Duration.zero);
    await tester.pumpAndSettle();

    expect(find.text('33'), findsOneWidget);
  });
```

Ajouter l'import `import 'package:magic_companion/providers/game_session_notifier.dart';` en tête du fichier de test.

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: FAIL — `container.read(gameSessionNotifierProvider)` vaut `null`, la page tenant encore sa session en local.

- [ ] **Step 3: Brancher la page**

Dans `lib/pages/life_counter/life_counter_page.dart` :

**3a.** Remplacer les champs `:59-60` :

```dart
  GameSessionController _controller = GameSessionController();
  GameSession? _session;
```

par :

```dart
  GameSessionNotifier get _controller =>
      ref.read(gameSessionNotifierProvider.notifier);
  GameSession? get _session => ref.watch(gameSessionNotifierProvider);
```

**3b.** Remplacer l'import `package:magic_companion/controllers/game_session_controller.dart` par `package:magic_companion/providers/game_session_notifier.dart`.

**3c.** Supprimer les 15 resynchros. Chaque occurrence de :

```dart
    setState(() => _session = _controller.session);
```

devient :

```dart
    setState(() {});
```

Sites concernés (numérotation d'origine) : `:241`, `:328`, `:445`, `:467`, `:563`, `:577`, `:838`, `:876`, `:941`, `:1147`.

> `setState(() {})` est conservé volontairement : la page garde d'autres états locaux (overlays de mort, mode édition, sélection de premier joueur) qui doivent être repeints. Leur extraction est le sujet du lot 2, pas de celui-ci.

**3d.** Supprimer les 4 `_controller.restoreSession(_session!)` (`:459`, `:480`, `:900`, `:915`) et remplacer les affectations directes qui les précèdent. Exemple pour `_updatePlayerColor` (`:455-462`) :

```dart
    _session = _session!.copyWith(players: players);
    _controller.restoreSession(_session!);
    setState(() {});
```

devient :

```dart
    _controller.restoreSession(_session!.copyWith(players: players));
    setState(() {});
```

Appliquer la même transformation à `_updatePlayerSkin`, à l'undo d'élimination et au reorder.

**3e.** Dans `_loadGame` (`:178-205`), supprimer `_controller = GameSessionController();` (les deux occurrences, `:184` et `:230`) ainsi que la ligne de correctif ajoutée en tâche 1, et remplacer l'affectation du snapshot :

```dart
        _controller.restoreSession(snapshot);
        setState(() {
          _currentFormat = snapshot.format;
          _isLoading = false;
        });
```

**3f.** Dans `_startNewGame` (`:230-241`), supprimer la création du contrôleur ; `startNewGame` porte déjà l'initialisation.

**3g.** Réécrire `lib/providers/game_session_provider.dart` :

```dart
// lib/providers/game_session_provider.dart
//
// Conservé pour compatibilité des imports existants.
// La source de vérité est gameSessionNotifierProvider.
export 'package:magic_companion/providers/game_session_notifier.dart';
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: PASS (2 tests)

Run: `flutter test`
Expected: PASS sur toute la suite.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/pages/life_counter/life_counter_page.dart lib/providers/game_session_provider.dart test/pages/life_counter/life_counter_page_test.dart
git commit -m "refactor: wire LifeCounterPage to GameSessionNotifier

Supprime la copie locale _session, les 15 resynchronisations manuelles et
les 4 restoreSession() de contournement. La session a désormais une seule
source de vérité, ce qui rend le bug de reprise structurellement impossible.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4 : État transitoire clé par `playerId` (Bug B)

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart:758`, `:781`
- Test: `test/pages/life_counter/life_counter_page_test.dart`

**Interfaces:**
- Consumes: `updateLifeForTest(int playerId, int change)` (tâche 1).
- Produces: `reorderForTest(int oldIndex, int newIndex)` sur `_LifeCounterPageState`, consommé aussi par la tâche 4b.

Exposer le point d'entrée de test dans `_LifeCounterPageState`, juste au-dessus de `void _onReorderPlayers(` :

```dart
  @visibleForTesting
  void reorderForTest(int oldIndex, int newIndex) =>
      _onReorderPlayers(oldIndex, newIndex);
```

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter dans `test/pages/life_counter/life_counter_page_test.dart` :

```dart
  testWidgets(
      'le badge de dégâts en attente suit le joueur après un reorder (régression bug B)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LifeCounterPage()),
      ),
    );
    await tester.pumpAndSettle();

    // On réordonne par le chemin réel de la page (mode édition), et non par
    // le notifier : `reorderPlayers` n'écrit que `playerOrder`, que rien dans
    // lib/ ne lit encore. C'est la tâche 4b qui corrige ce point.
    final reorderState = tester.state<dynamic>(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    reorderState.reorderForTest(0, 3);
    await tester.pumpAndSettle();

    // Dégâts en attente sur le joueur 0 (affiché en dernière position).
    final state = tester.state<dynamic>(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    state.updateLifeForTest(0, -5);
    await tester.pump(const Duration(milliseconds: 100));

    // Un seul badge, et il doit être celui du joueur 0.
    expect(find.text('-5'), findsOneWidget);

    final badge = tester.getCenter(find.text('-5'));
    final zone0 = tester.getCenter(find.text('35')); // 40 - 5 affiché en pending
    expect(
      (badge - zone0).distance < 200,
      isTrue,
      reason: 'le badge doit être dans la zone du joueur 0, pas dans une autre',
    );
  });
```

> Si l'assertion de proximité s'avère fragile sur la grille pivotée, la remplacer par une vérification du rectangle : `expect(tester.getRect(find.byType(PlayerZone).last).contains(badge), isTrue);` avec l'import de `PlayerZone`. L'important est que le badge et la valeur du joueur 0 soient dans la même zone.

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: FAIL — le badge est rendu dans la zone d'index 0, alors que le joueur 0 est affiché en dernière position.

- [ ] **Step 3: Corriger la lecture par index**

Dans `lib/pages/life_counter/life_counter_page.dart`, dans le `builder` de zone :

Ligne `:781` :

```dart
    final pending = _pendingDamage[index] ?? 0;
```

devient :

```dart
    final pending = _pendingDamage[playerState.playerId] ?? 0;
```

Ligne `:758` :

```dart
    final isFlashing = _commanderDamageFlash.contains(index);
```

devient :

```dart
    final isFlashing = _commanderDamageFlash.contains(playerState.playerId);
```

Si `playerState` n'est pas dans la portée de ces deux lignes, utiliser `_session!.players[index].playerId`. Vérifier qu'aucune autre lecture de `_pendingDamage` ou `_commanderDamageFlash` n'utilise un index :

```bash
grep -n "_pendingDamage\[\|_commanderDamageFlash" lib/pages/life_counter/life_counter_page.dart
```

Toutes les occurrences doivent porter un `playerId`.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: PASS (3 tests)

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/pages/life_counter/life_counter_page.dart test/pages/life_counter/life_counter_page_test.dart
git commit -m "fix: key pending damage and commander flash by playerId

Les deux étaient écrits par playerId mais lus par index d'affichage : après
un reorder, le badge de dégâts en attente et le flash de commander damage
apparaissaient sur la mauvaise zone.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4b : `playerOrder` comme source de vérité de l'ordre d'affichage

`GameSession.playerOrder` est initialisé (`lib/models/game_session.dart:159`), sérialisé (`:219`) et modifiable via `reorderPlayers` (`:205-207`) — mais **aucun code de `lib/` ne le lit**. La page réordonne en permutant physiquement la liste `players` (`life_counter_page.dart:905-918`), ce qui désolidarise durablement `playerId` de la position dans la liste et rend `reorderPlayers` du modèle inopérant.

C'est la cause profonde du bug B : la tâche 4 corrige les symptômes visibles, celle-ci supprime la divergence.

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart:120-127` (`_legacyPlayers`), `:905-918` (`_onReorderPlayers`)
- Test: `test/providers/game_session_notifier_test.dart`, `test/pages/life_counter/life_counter_page_test.dart`

**Interfaces:**
- Consumes: `GameSession.reorderPlayers(List<int>)`, `GameSession.playerOrder`, `reorderForTest` (tâche 4).
- Produces: `List<PlayerState> get _orderedPlayers` sur `_LifeCounterPageState` — l'ordre d'affichage. `_session!.players` conserve l'ordre canonique, indexé par `playerId`.

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter dans `test/pages/life_counter/life_counter_page_test.dart` :

```dart
  testWidgets('un reorder ne permute pas la liste canonique des joueurs',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LifeCounterPage()),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<dynamic>(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    state.reorderForTest(0, 3);
    await tester.pumpAndSettle();

    final session = container.read(gameSessionNotifierProvider)!;

    // players garde son ordre canonique : players[i].playerId == i.
    expect(
      session.players.map((p) => p.playerId).toList(),
      [0, 1, 2, 3],
      reason: 'la liste canonique ne doit jamais être permutée',
    );

    // Seul playerOrder porte l'ordre d'affichage.
    expect(session.playerOrder, [3, 1, 2, 0]);
  });
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: FAIL — `session.players` ressort en `[3, 1, 2, 0]` (permutation physique) et `playerOrder` est resté `[0, 1, 2, 3]`.

- [ ] **Step 3: Implémenter**

Dans `lib/pages/life_counter/life_counter_page.dart`, remplacer `_onReorderPlayers` (`:905-918`) :

```dart
  void _onReorderPlayers(int oldIndex, int newIndex) {
    final session = _session;
    if (session == null) return;
    // On ne permute plus la liste canonique : seul l'ordre d'affichage change,
    // ce qui préserve l'invariant players[i].playerId == i.
    final order = session.playerOrder.isEmpty
        ? List<int>.generate(session.players.length, (i) => i)
        : List<int>.from(session.playerOrder);
    if (oldIndex >= order.length || newIndex >= order.length) return;
    final temp = order[oldIndex];
    order[oldIndex] = order[newIndex];
    order[newIndex] = temp;
    _controller.reorderPlayers(order);
    setState(() {});
    _saveSnapshot();
  }
```

Ajouter le getter d'ordre d'affichage, juste au-dessus de `List<Player> get _legacyPlayers` (`:120`) :

```dart
  /// Ordre d'affichage des zones. `_session.players` garde l'ordre canonique
  /// (players[i].playerId == i) ; `playerOrder` porte seul la disposition
  /// choisie par le joueur en mode édition.
  List<PlayerState> get _orderedPlayers {
    final session = _session;
    if (session == null) return const [];
    final order = session.playerOrder;
    if (order.length != session.players.length) return session.players;
    final byId = {for (final p in session.players) p.playerId: p};
    final ordered = <PlayerState>[];
    for (final id in order) {
      final p = byId[id];
      if (p == null) return session.players; // ordre corrompu : repli sûr
      ordered.add(p);
    }
    return ordered;
  }
```

Faire passer `_legacyPlayers` (`:120-127`) par ce getter :

```dart
  List<Player> get _legacyPlayers {
    return _orderedPlayers
        .asMap()
        .entries
        .map((e) => _toLegacyPlayer(e.key, e.value))
        .toList();
  }
```

Vérifier enfin qu'aucun autre site de rendu n'itère `_session!.players` directement :

```bash
grep -n "_session!.players\|_session?.players" lib/pages/life_counter/life_counter_page.dart
```

Les sites de **lecture métier** (détection de mort, dernier survivant, fin de partie) doivent rester sur `_session!.players` — l'ordre n'y a aucune importance. Seuls les sites de **rendu** passent à `_orderedPlayers`. En pratique, le rendu passe déjà par `_legacyPlayers` ; si le `grep` révèle un site de rendu direct, le corriger.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: PASS (4 tests) — dont le test de la tâche 4, qui doit rester vert : l'ordre d'affichage change toujours, seul son mécanisme diffère.

Run: `flutter test`
Expected: PASS — en particulier `test/models/game_session_test.dart`, qui couvre déjà `reorderPlayers`.

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/pages/life_counter/life_counter_page.dart test/pages/life_counter/life_counter_page_test.dart
git commit -m "fix: make playerOrder the source of truth for zone ordering

Le reorder permutait physiquement la liste canonique des joueurs, cassant
l'invariant players[i].playerId == i et rendant inopérant playerOrder, que
le modèle maintenait sans que personne ne le lise.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 : Durée de partie et timer dans la session

`GameSession.duration` et `startedAt` sont modélisés (`lib/models/game_session.dart:118-119`) et sérialisés (`:215-216`) mais jamais renseignés : la durée vit dans `_gameDuration` (`:90`) et est perdue à chaque redémarrage, malgré la restauration du snapshot. Le toggle « Timer de partie » du setup (`game_setup_modal.dart:45,417`) n'est par ailleurs jamais transmis à la page.

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart:89-91`, `_startGame` `:153-163`, `_stopGame` `:165-168`
- Modify: `lib/providers/game_session_notifier.dart` (ajout de deux méthodes)
- Test: `test/providers/game_session_notifier_test.dart`, `test/pages/life_counter/life_counter_page_test.dart`

**Interfaces:**
- Consumes: `GameSession.copyWith({DateTime? startedAt, Duration? duration, bool? isActive})`.
- Produces sur `GameSessionNotifier` :
  - `void startTimer()` — pose `startedAt: DateTime.now()`, `isActive: true`, `duration: Duration.zero`.
  - `void tick()` — incrémente `duration` d'une seconde.
  - `void stopTimer()` — pose `isActive: false` sans toucher à `duration`.

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter dans `test/providers/game_session_notifier_test.dart` :

```dart
  test('startTimer initialise la durée et marque la partie active', () {
    notifier.startNewGame(format: commanderFormat, playerConfigs: configs);
    notifier.startTimer();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.isActive, isTrue);
    expect(session.duration, Duration.zero);
    expect(session.startedAt, isNotNull);
  });

  test('tick incrémente la durée portée par la session', () {
    notifier.startNewGame(format: commanderFormat, playerConfigs: configs);
    notifier.startTimer();
    notifier.tick();
    notifier.tick();
    notifier.tick();

    expect(container.read(gameSessionNotifierProvider)!.duration,
        const Duration(seconds: 3));
  });

  test('la durée survit à un aller-retour JSON', () {
    notifier.startNewGame(format: commanderFormat, playerConfigs: configs);
    notifier.startTimer();
    notifier.tick();
    notifier.tick();

    final json = container.read(gameSessionNotifierProvider)!.toJson();
    final restored = GameSession.fromJson(json);

    expect(restored.duration, const Duration(seconds: 2));
    expect(restored.isActive, isTrue);
  });

  test('stopTimer conserve la durée accumulée', () {
    notifier.startNewGame(format: commanderFormat, playerConfigs: configs);
    notifier.startTimer();
    notifier.tick();
    notifier.stopTimer();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.isActive, isFalse);
    expect(session.duration, const Duration(seconds: 1));
  });
```

Ajouter l'import `import 'package:magic_companion/models/game_session.dart';` au fichier de test.

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/providers/game_session_notifier_test.dart`
Expected: FAIL à la compilation — `startTimer`, `tick` et `stopTimer` ne sont pas définis.

- [ ] **Step 3: Implémenter**

Dans `lib/providers/game_session_notifier.dart`, ajouter avant `void endGame()` :

```dart
  /// Démarre le chronomètre de la partie. La durée est portée par la session
  /// pour survivre à un redémarrage de l'application (elle vivait auparavant
  /// dans le State de la page et était perdue).
  void startTimer() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      startedAt: DateTime.now(),
      duration: Duration.zero,
      isActive: true,
    );
  }

  /// Avance le chronomètre d'une seconde.
  void tick() {
    final session = state;
    if (session == null || !session.isActive) return;
    state = session.copyWith(
      duration: session.duration + const Duration(seconds: 1),
    );
  }

  void stopTimer() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(isActive: false);
  }
```

Dans `lib/pages/life_counter/life_counter_page.dart` :

Supprimer les champs `_gameDuration` (`:90`) et `_isGameActive` (`:91`), et les remplacer par des getters dérivés placés au même endroit :

```dart
  Duration get _gameDuration => _session?.duration ?? Duration.zero;
  bool get _isGameActive => _session?.isActive ?? false;
```

Réécrire `_startGame` (`:153-163`) :

```dart
  void _startGame() {
    _gameTimer?.cancel();
    _controller.startTimer();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _controller.tick();
    });
    setState(() {});
  }
```

et `_stopGame` (`:165-168`) :

```dart
  void _stopGame() {
    _gameTimer?.cancel();
    _controller.stopTimer();
    setState(() {});
  }
```

Corriger les affectations résiduelles de `_gameDuration` (notamment `_resetGame`, qui posait `_gameDuration = Duration.zero`) : la remise à zéro est désormais portée par `startNewGame` puis `startTimer`. Les localiser avec :

```bash
grep -n "_gameDuration = \|_isGameActive = " lib/pages/life_counter/life_counter_page.dart
```

Après correction, ce `grep` ne doit plus rien retourner.

Enfin, dans `_loadGame`, relancer le chronomètre périodique si la session restaurée est active, juste avant le `return` du chemin de restauration :

```dart
        if (snapshot.isActive) {
          _gameTimer?.cancel();
          _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted) return;
            _controller.tick();
          });
        }
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/providers/game_session_notifier_test.dart`
Expected: PASS (10 tests)

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/providers/game_session_notifier.dart lib/pages/life_counter/life_counter_page.dart test/providers/game_session_notifier_test.dart
git commit -m "fix: move game duration into the session

duration, startedAt et isActive étaient modélisés et sérialisés mais jamais
renseignés : la durée vivait dans le State de la page et disparaissait au
redémarrage malgré la restauration du snapshot. Le chronomètre reprend
désormais là où il s'était arrêté.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 6 : Débouncer l'écriture du snapshot

`_saveSnapshot()` sérialise toute la session en JSON et écrit dans SharedPreferences après chaque mutation — soit à chaque tap, une douzaine de sites d'appel.

**Files:**
- Modify: `lib/pages/life_counter/life_counter_page.dart:251-256` (`_saveSnapshot`), `dispose` `:141-150`
- Test: `test/pages/life_counter/life_counter_page_test.dart`

**Interfaces:**
- Consumes: `GameSessionService.saveSnapshot(GameSession)`.
- Produces: `_saveSnapshot()` garde sa signature `Future<void>` et reste appelable depuis les 12 sites existants — aucun appelant ne change.

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter dans `test/pages/life_counter/life_counter_page_test.dart` :

```dart
  testWidgets('les mutations rapprochées ne produisent qu\'une écriture',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LifeCounterPage()),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = container.read(gameSessionNotifierProvider.notifier);
    final state = tester.state<dynamic>(find.byType(LifeCounterPage));

    // Dix mutations coup sur coup.
    for (var i = 0; i < 10; i++) {
      notifier.updateLife(0, -1, gameDuration: Duration.zero);
      // ignore: avoid_dynamic_calls
      state.saveSnapshotForTest();
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Rien n'est encore écrit : le débounce n'a pas expiré.
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_game_snapshot'), isNull);

    // Après la fenêtre de débounce, une seule écriture, avec l'état final.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('active_game_snapshot');
    expect(raw, isNotNull);
    expect(GameSession.fromJson(json.decode(raw!)).players[0].life, 30);
  });
```

Exposer le point d'entrée de test dans `_LifeCounterPageState`, juste au-dessus de `Future<void> _saveSnapshot()` :

```dart
  @visibleForTesting
  void saveSnapshotForTest() => _saveSnapshot();
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: FAIL — la première assertion tombe, l'écriture étant immédiate.

- [ ] **Step 3: Implémenter le débounce**

Dans `lib/pages/life_counter/life_counter_page.dart`, ajouter un champ à côté des autres timers (`:89`) :

```dart
  Timer? _snapshotDebounce;
```

Remplacer `_saveSnapshot` (`:251-256`) :

```dart
  Future<void> _saveSnapshot() async {
    if (_session == null) return;
    final sessionService = ref.read(gameSessionServiceProvider);
    await sessionService.saveSnapshot(_session!);
  }
```

par :

```dart
  /// Écriture différée : les mutations arrivent par rafales (un tap = une
  /// mutation), et sérialiser toute la session à chaque fois coûte une I/O
  /// par tap. On ne garde que la dernière écriture d'une rafale.
  static const _snapshotDebounceDelay = Duration(milliseconds: 500);

  Future<void> _saveSnapshot() async {
    _snapshotDebounce?.cancel();
    _snapshotDebounce = Timer(_snapshotDebounceDelay, _flushSnapshot);
  }

  Future<void> _flushSnapshot() async {
    _snapshotDebounce?.cancel();
    _snapshotDebounce = null;
    final session = _session;
    if (session == null) return;
    await ref.read(gameSessionServiceProvider).saveSnapshot(session);
  }
```

Dans `dispose()` (`:141-150`), annuler le timer et écrire une dernière fois avant de partir, **avant** `super.dispose()` :

```dart
    _snapshotDebounce?.cancel();
    final pendingSession = _session;
    if (pendingSession != null) {
      // Pas d'await : dispose est synchrone. L'écriture part quand même.
      ref.read(gameSessionServiceProvider).saveSnapshot(pendingSession);
    }
```

> Attention : `clearSnapshot()` est appelé en fin de partie (`:693`). Il doit annuler le débounce en attente, sans quoi une écriture retardataire ressusciterait la partie terminée. Ajouter `_snapshotDebounce?.cancel();` immédiatement avant l'appel à `clearSnapshot()`.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/pages/life_counter/life_counter_page_test.dart`
Expected: PASS (5 tests)

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add lib/pages/life_counter/life_counter_page.dart test/pages/life_counter/life_counter_page_test.dart
git commit -m "perf: debounce snapshot writes

Toute la session était sérialisée et écrite dans SharedPreferences après
chaque tap. Une seule écriture par rafale de 500 ms, plus un flush au dispose.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 7 : Nettoyage final

**Files:**
- Delete: `lib/controllers/game_session_controller.dart`
- Delete: `test/controllers/game_session_controller_test.dart`
- Modify: `lib/pages/life_counter/life_counter_page.dart` (`_calculateDefaultRotation` `:257-263`)

**Interfaces:**
- Consumes: rien de nouveau.
- Produces: `GameSessionController` n'existe plus ; `gameSessionNotifierProvider` est l'unique point d'entrée.

- [ ] **Step 1: Vérifier que le contrôleur n'a plus de consommateur**

```bash
grep -rn "GameSessionController\|game_session_controller" lib/ test/
```

Expected: seules les définitions et leur fichier de test ressortent. Toute autre occurrence doit d'abord être migrée vers `GameSessionNotifier`.

- [ ] **Step 2: Vérifier que `_calculateDefaultRotation` est bien mort**

```bash
grep -n "_calculateDefaultRotation" lib/pages/life_counter/life_counter_page.dart
```

Attendu : la définition (`:257`) et un seul appel (`:237`). La méthode ignore ses deux paramètres et retourne toujours `0` ; les presets d'orientation (`:1084-1202`) couvrent déjà le besoin.

- [ ] **Step 3: Supprimer**

```bash
git rm lib/controllers/game_session_controller.dart
git rm test/controllers/game_session_controller_test.dart
```

Dans `lib/pages/life_counter/life_counter_page.dart`, supprimer la méthode `_calculateDefaultRotation` (`:257-263`) et son appel `:237`. La ligne :

```dart
        _controller.updateRotation(i, _calculateDefaultRotation(i, playerCount));
```

est supprimée : `PlayerState.quarterTurns` vaut déjà `0` par défaut (`lib/models/game_session.dart:50`), la boucle n'apporte rien.

- [ ] **Step 4: Lancer la suite complète**

Run: `flutter analyze`
Expected: aucune erreur, aucun import inutilisé.

Run: `flutter test`
Expected: PASS sur toute la suite.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove GameSessionController and dead rotation helper

Le contrôleur n'a plus de consommateur depuis le passage au notifier. Ses
tests sont couverts par test/providers/game_session_notifier_test.dart.
_calculateDefaultRotation ignorait ses deux paramètres et retournait
toujours 0.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Critères de sortie du lot

- [ ] `flutter test` vert sur toute la suite.
- [ ] `flutter analyze` sans avertissement sur les fichiers touchés.
- [ ] `grep -rn "GameSessionController" lib/ test/` ne retourne rien.
- [ ] `grep -n "_session = " lib/pages/life_counter/life_counter_page.dart` ne retourne rien.
- [ ] Vérification manuelle du bug A : lancer une partie, modifier des PV, tuer l'application, la rouvrir, modifier des PV — la partie et sa durée sont conservées.
- [ ] Vérification manuelle du bug B : lancer une partie à 4, réordonner les zones en mode édition, taper des dégâts — le badge apparaît sur la bonne zone.

## Lots suivants

Chaque lot fera l'objet de son propre plan, rédigé après la livraison du précédent :

- **Lot 2 — Zone joueur** : minimal gestuel, poignée conditionnelle, molette, paliers, mode ajustement, menu radial déplacé dans le tiroir, branchement de `PlayerZoneController`.
- **Lot 3 — Commander damage et tiroir** : attribution à la volée, grille du tiroir, vue table.
- **Lot 4 — Setup** : reprise en un tap, setup inline, suppression de `GameSetupModal`, branchement de `GameSetupController`, route vers `StatsTab`.
- **Lot 5 — Compteurs personnalisés** : branchement de `CounterType`.
