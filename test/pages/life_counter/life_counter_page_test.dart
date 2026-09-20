// test/pages/life_counter/life_counter_page_test.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/pages/life_counter/life_counter_page.dart';
import 'package:magic_companion/pages/life_counter/table_view_page.dart';
import 'package:magic_companion/router/app_router.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/counter_type_service.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:magic_companion/services/game_session_service.dart';
import 'package:magic_companion/widgets/life_counter/death_confirmation_overlay.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';
import 'package:magic_companion/widgets/life_counter/zone/commander_damage_grid.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Double de test : bloque `saveSnapshot()` jusqu'à `releaseGate()`, pour
/// rendre déterministe la fenêtre de course entre un flush de débounce déjà
/// en vol et `clearSnapshot()` — le mock SharedPreferences ne fournit aucun
/// vrai délai d'E/S sur lequel s'appuyer pour reproduire cette course.
class _GatedGameSessionService extends GameSessionService {
  final Completer<void> _gate = Completer<void>();
  bool saveStarted = false;

  void releaseGate() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<void> saveSnapshot(GameSession session) async {
    saveStarted = true;
    await _gate.future;
    await super.saveSnapshot(session);
  }
}

final commanderFormat =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

final testConfigs = [
  const PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
  const PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
  const PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
  const PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
];

/// Configs pour un effectif arbitraire, pour les tests de presets
/// d'orientation qui ont besoin de 2, 3, 5, 6 ou 7 joueurs.
List<PlayerConfig> playerConfigsFor(int count) => [
      for (int i = 0; i < count; i++)
        PlayerConfig(
          id: 'p${i + 1}',
          name: 'Joueur ${i + 1}',
          type: i == 0 ? PlayerType.owner : PlayerType.guest,
        ),
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
      // En production, LifeCounterPage est toujours montée à l'intérieur du
      // Scaffold de AppShellScaffold (lib/router/app_shell_scaffold.dart), qui
      // lui fournit son ancêtre Material. La page elle-même n'en fournit pas
      // (son build() renvoie directement un AdaptiveGrid) : sans ce Scaffold
      // minimal, les InkWell de la barre centrale lèvent "No Material widget
      // found" dès le premier pump. Ceci reproduit le contexte de montage réel.
      child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
    ),
  );
  await tester.pumpAndSettle();
}

/// Repère la zone du joueur [playerId] (ordre CANONIQUE, jamais d'affichage
/// ni d'arbre) : `life_counter_page.dart` pose un
/// `KeyedSubtree(key: ValueKey('player_zone_<playerId>'))` autour de chaque
/// zone précisément pour ça.
Finder _playerZone(int playerId) =>
    find.byKey(ValueKey('player_zone_$playerId'));

/// Tape `count` fois la moitié gauche VISUELLE (−1) du cadran (`LifeDial`)
/// du joueur [playerId], avec un `pump()` entre chaque tap pour laisser
/// chaque geste se résoudre avant le suivant.
///
/// Repéré par identité (voir `_playerZone`), jamais par position dans
/// l'arbre : depuis la tâche 4, `AdaptiveGrid` place les zones selon
/// `tableLayoutFor`/`seatsFor`, dont l'ordre ne suit ni l'ordre d'affichage
/// ni l'ordre canonique de façon fixe (colonnes latérales, sous-grille 8
/// joueurs, reorder...). Un repérage ordinal (`.at(zoneIndex)`) se
/// retrouvait donc à cibler un joueur différent de celui voulu selon la
/// géométrie du moment — exactement le défaut que ce projet a déjà vu
/// neuf fois.
///
/// La rotation elle-même reste observée sur l'arbre plutôt que déduite :
/// depuis la tâche 4, `AdaptiveGrid` ne pivote plus jamais rien (voir
/// `adaptive_grid.dart`) ; seul `PlayerZone` pivote sa zone, via le
/// `RotatedBox(quarterTurns: player.quarterTurns)` qu'il pose autour de son
/// contenu (`player_zone.dart` ~ligne 458). La rotation effective d'un
/// cadran donné dépend donc uniquement de l'état du joueur.
Future<void> tapMinusHalf(
  WidgetTester tester,
  int playerId,
  int count,
) async {
  final dialFinder = find.descendant(
    of: _playerZone(playerId),
    matching: find.byType(LifeDial),
  );
  final quarterTurns = _quarterTurnsAbove(dialFinder);
  final dial = tester.getRect(dialFinder);
  // `RotatedBox` tourne dans le sens HORAIRE (voir table_seat.dart) : la
  // moitié décrément (visuellement "gauche" depuis la chaise du joueur) se
  // trouve à dx inférieur pour 0, dy inférieur pour 1, dx supérieur pour 2,
  // dy supérieur pour 3. Depuis la tâche 5, un siège latéral peut porter
  // `quarterTurns == 1` ou `3` (pas seulement 0/2) : le repérage doit donc
  // couvrir les quatre valeurs, pas seulement détecter un demi-tour.
  final point = switch (quarterTurns) {
    1 => Offset(dial.center.dx, dial.top + dial.height * 0.25),
    2 => Offset(dial.left + dial.width * 0.75, dial.center.dy),
    3 => Offset(dial.center.dx, dial.top + dial.height * 0.75),
    _ => Offset(dial.left + dial.width * 0.25, dial.center.dy),
  };
  for (var i = 0; i < count; i++) {
    await tester.tapAt(point);
    await tester.pump();
  }
}

/// Le `quarterTurns` réellement appliqué au-dessus de [descendant], déduit
/// de l'arbre (jamais de l'état) — voir la docstring de `tapMinusHalf`.
int _quarterTurnsAbove(Finder descendant) {
  for (final qt in const [1, 2, 3]) {
    final ancestor = find.ancestor(
      of: descendant,
      matching: find.byWidgetPredicate((w) => w is RotatedBox && w.quarterTurns == qt),
    );
    if (ancestor.evaluate().isNotEmpty) return qt;
  }
  return 0;
}

/// Impose une taille d'écran logique pour la durée du test (restaurée par
/// `addTearDown`).
///
/// Ronde de correction 1 (tâche 4) : épingler la taille d'écran pour figer
/// l'ORDRE d'affichage des zones était le mauvais remède — cet ordre reste
/// une position dans l'arbre, et redevient faux au prochain ajustement de
/// `seatsFor` ou de `kLargeScreenShortEdge`. Les repérages par identité
/// (`_playerZone`, voir plus haut) n'en ont plus besoin. N'utilise cette
/// fonction que là où le FORMAT de l'écran fait partie de ce que le test
/// veut dire (bascule bande/hub, colonnes latérales...), jamais pour
/// stabiliser un ordre de traversée.
void _setScreenSize(WidgetTester tester, Size size) {
  final originalSize = tester.view.physicalSize;
  final originalDpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.physicalSize = originalSize;
    tester.view.devicePixelRatio = originalDpr;
  });
}

/// Réordonne par une mutation directe du provider — PAS par un vrai geste de
/// glisser-déposer.
///
/// Un vrai drag a été tenté d'abord (appui long 1s sur la vraie
/// `DraggablePlayerZone`, puis déplacement, puis relâchement, mode édition
/// activé au préalable via le bouton "build" de la barre centrale — la
/// même séquence qu'un joueur suivrait réellement). Il a révélé un défaut
/// réel de production, sans rapport avec ce que ces tests vérifient
/// (l'ordre d'affichage) : dès que le long-press déclenche l'aperçu de
/// drag, `Column:life_dial.dart:213` (`LifeDial._readout`) déborde de 68px
/// — reproductible à chaque tentative, y compris sur une session neuve sans
/// aucun overlay ni dégât en attente. La cause : `feedback` dans
/// draggable_player_zone.dart fige la zone entière (avec tout son contenu,
/// dont le cadran de vie) dans une `SizedBox` de hauteur FIXE (130px),
/// bien plus petite que la hauteur réelle d'une zone dans la grille — voir
/// le rapport de tâche pour le signalement complet. Ce défaut n'est PAS
/// corrigé ici : il est hors périmètre de cette tâche (retirer deux hooks
/// de test), qui n'a pas mandat pour modifier `DraggablePlayerZone`.
///
/// Ce helper reproduit fidèlement le calcul de swap fait par
/// `_onReorderPlayers` (life_counter_page.dart) à partir de l'ordre
/// d'affichage courant de la session, puis appelle directement
/// `GameSessionNotifier.reorderPlayers` — mais il NE PASSE PAS par
/// `LongPressDraggable`/`DragTarget`/`DraggablePlayerZone`, et ne prouve
/// donc rien de leur câblage réel ni de l'accessibilité du geste de
/// réordonnancement lui-même.
Future<void> reorderPlayersViaContainer(
  ProviderContainer container,
  WidgetTester tester,
  int oldIndex,
  int newIndex,
) async {
  final session = container.read(gameSessionNotifierProvider)!;
  final order = session.playerOrder.isEmpty
      ? List<int>.generate(session.players.length, (i) => i)
      : List<int>.from(session.playerOrder);
  final temp = order[oldIndex];
  order[oldIndex] = order[newIndex];
  order[newIndex] = temp;
  container.read(gameSessionNotifierProvider.notifier).reorderPlayers(order);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'la partie restaurée survit à une modification de PV (régression bug A)',
      (tester) async {
    // Une partie en cours : Alex a déjà perdu 6 PV.
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    final restored = baseSession.copyWith(
      players: [
        baseSession.players[0].copyWith(life: 34),
        ...baseSession.players.sublist(1),
      ],
    );

    await pumpLifeCounter(tester, snapshot: restored);

    // La partie restaurée est bien affichée.
    expect(find.text('34'), findsOneWidget);

    // On retire 1 PV au joueur 0 par un vrai tap sur son cadran (zone
    // d'index 0 ; `tapMinusHalf` détecte lui-même sa rotation réelle, voir
    // sa docstring), et on laisse le buffer de 2 s s'appliquer.
    await tapMinusHalf(tester, 0, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Avant correctif : la session est écrasée par le null du contrôleur.
    expect(find.text('33'), findsOneWidget,
        reason: 'la partie restaurée ne doit pas être effacée');
  });

  testWidgets(
      'une session restaurée active relance le chronomètre (contrat de reprise)',
      (tester) async {
    // Une partie en cours, chrono déjà à 5s au moment du snapshot.
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    final restored = baseSession.copyWith(
      isActive: true,
      duration: const Duration(seconds: 5),
      startedAt: DateTime.now(),
    );

    await pumpLifeCounter(tester, snapshot: restored);

    // La durée restaurée est affichée dès le chargement : elle vient de la
    // session, pas d'un champ de page réinitialisé à zéro.
    expect(find.text('00:05'), findsOneWidget);

    // `_loadGame` doit avoir relancé le `Timer.periodic` local qui pousse des
    // `tick()` vers le notifier. Si la reprise du chrono avait été oubliée
    // (pas de Timer relancé), la durée resterait figée à 5s après ce pump.
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('00:07'), findsOneWidget,
        reason: 'le chronomètre relancé au chargement doit avoir avancé de '
            '2s depuis la valeur restaurée');
    expect(find.text('00:05'), findsNothing);
  });

  testWidgets('la session vit dans le provider, pas dans la page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
      ],
    );
    addTearDown(container.dispose);

    // En production, LifeCounterPage est toujours montée à l'intérieur du
    // Scaffold de AppShellScaffold, qui lui fournit son ancêtre Material.
    // Voir la note dans pumpLifeCounter ci-dessus : sans ce Scaffold minimal,
    // les InkWell de la barre centrale lèvent "No Material widget found".
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
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
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    // On réordonne via une mutation directe du provider (voir le doc-comment
    // de `reorderPlayersViaContainer` : le vrai drag s'est avéré
    // impraticable ici) : `reorderPlayers` n'écrit que `playerOrder`, que
    // rien dans lib/ ne lisait avant la tâche 4b, qui corrige ce point.
    // Ce swap déplace le joueur CANONIQUE 0 de la position d'affichage 0 à
    // la position 3.
    await reorderPlayersViaContainer(container, tester, 0, 3);

    // 5 vrais taps sur la moitié −1 du cadran du joueur 0 (Alex) — repéré
    // par identité (`tapMinusHalf` cherche `player_zone_0`), PAS par
    // position d'affichage : c'est justement ce déplacement par le reorder
    // que ce test doit vérifier, pas le présupposer.
    await tapMinusHalf(tester, 0, 5);
    await tester.pump(const Duration(milliseconds: 100));

    // Un seul badge, et il doit être celui du joueur 0.
    expect(find.text('-5'), findsOneWidget);

    // Ronde de correction 1 (tâche 4) : `find.byType(PlayerZone).last`
    // n'était correct qu'en apparence — après ce même swap, sur l'ambiant
    // de test (colonnes latérales déclenchées à 4 joueurs), le DERNIER
    // `PlayerZone` de l'arbre coïncide avec la colonne de droite, PAS
    // forcément avec le joueur 0 : le test aurait pu rester vert en tapant
    // et en vérifiant le même mauvais joueur des deux côtés, sans jamais
    // prouver que le badge suit RÉELLEMENT le joueur déplacé. On vérifie
    // donc une inclusion géométrique dans le rectangle de la zone du
    // joueur 0 elle-même, repérée par identité.
    final badge = tester.getCenter(find.text('-5'));
    final zoneRect = tester.getRect(_playerZone(0));
    expect(
      zoneRect.contains(badge),
      isTrue,
      reason: 'le badge doit être dans la zone du joueur 0, pas dans une autre',
    );

    // Purge les minuteurs de nombres flottants encore en vol (600ms, un par
    // tap réel -- voir `_PlayerZoneState._showFloatingNumber`) avant la fin
    // du test, sous peine de l'assertion `!timersPending` du binding.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

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
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    await reorderPlayersViaContainer(container, tester, 0, 3);

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

  testWidgets(
      "l'historique de fin de partie garde l'ordre canonique des joueurs, "
      'pas l\'ordre d\'affichage',
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
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    // On réordonne l'affichage : le joueur 0 passe en dernière position.
    // Si `_finalizeGameSave` lisait encore l'ordre d'affichage (régression
    // de catégorisation métier/rendu), l'historique sauvegarderait les noms
    // dans l'ordre [3, 1, 2, 0] plutôt que l'ordre canonique [0, 1, 2, 3].
    await reorderPlayersViaContainer(container, tester, 0, 3);

    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    await (state as dynamic).finalizeGameSaveForTest(0, 'normal');
    await tester.pumpAndSettle();

    final history = await GameHistoryService().loadHistory();
    expect(history, isNotEmpty);
    expect(
      history.first.playerStates.map((p) => p.name).toList(),
      ['Joueur 1', 'Joueur 2', 'Joueur 3', 'Joueur 4'],
      reason: "la sauvegarde doit suivre l'ordre canonique des playerId, "
          "pas l'ordre d'affichage issu du reorder",
    );
  });

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
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = container.read(gameSessionNotifierProvider.notifier);
    final state = tester.state(find.byType(LifeCounterPage));

    // Dix mutations coup sur coup.
    for (var i = 0; i < 10; i++) {
      notifier.updateLife(0, -1, gameDuration: Duration.zero);
      // ignore: avoid_dynamic_calls
      (state as dynamic).saveSnapshotForTest();
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

  testWidgets(
      "clearSnapshot() en fin de partie n'est pas ressuscité par un flush "
      'de débounce retardataire',
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
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    // Une mutation programme une écriture différée (500 ms)...
    final notifier = container.read(gameSessionNotifierProvider.notifier);
    notifier.updateLife(0, -1, gameDuration: Duration.zero);
    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (state as dynamic).saveSnapshotForTest();

    // ...mais la partie se termine avant l'expiration du débounce : le
    // débounce en attente doit être annulé avant `clearSnapshot()`.
    // ignore: avoid_dynamic_calls
    await (state as dynamic).finalizeGameSaveForTest(0, 'normal');
    await tester.pumpAndSettle();

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_game_snapshot'), isNull,
        reason: 'clearSnapshot doit avoir supprimé le snapshot');

    // Même après l'expiration de la fenêtre de débounce, rien ne doit
    // ressusciter la partie terminée.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_game_snapshot'), isNull,
        reason: 'un flush retardataire ne doit pas ressusciter une partie '
            'terminée');
  });

  testWidgets(
      'dispose() avec un débounce en attente écrit le dernier état avant de '
      'partir',
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
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    // Une mutation programme une écriture différée (500 ms)...
    final notifier = container.read(gameSessionNotifierProvider.notifier);
    notifier.updateLife(0, -1, gameDuration: Duration.zero);
    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (state as dynamic).saveSnapshotForTest();

    // ...mais la page est démontée avant l'expiration du débounce : on
    // remplace l'arbre par un widget qui ne contient plus LifeCounterPage,
    // ce qui déclenche dispose() pendant que le débounce est encore actif.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      ),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('active_game_snapshot');
    expect(raw, isNotNull,
        reason: 'dispose() doit flusher la dernière session en attente '
            'avant de partir, sans quoi cette mutation serait perdue');
    expect(
      GameSession.fromJson(json.decode(raw!)).players[0].life,
      39,
      reason: "l'écriture de dispose() doit porter l'état le plus récent "
          '(40 - 1), pas un état périmé',
    );
  });

  testWidgets(
      'une écriture de débounce déjà en vol ne doit pas ressusciter la '
      'partie après clearSnapshot() (race résiduelle)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final gatedService = _GatedGameSessionService();
    final container = ProviderContainer(
      overrides: [
        gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
        gameSessionServiceProvider.overrideWithValue(gatedService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = container.read(gameSessionNotifierProvider.notifier);
    notifier.updateLife(0, -1, gameDuration: Duration.zero);
    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (state as dynamic).saveSnapshotForTest();

    // Le débounce expire : `_flushSnapshot()` démarre et se bloque dans
    // `saveSnapshot()`, en plein vol — la porte n'est pas encore ouverte.
    await tester.pump(const Duration(milliseconds: 500));
    expect(gatedService.saveStarted, isTrue,
        reason: "le flush doit avoir démarré son écriture avant qu'on "
            'termine la partie, pour reproduire la course');

    // La partie se termine PENDANT que cette écriture est en vol :
    // `_finalizeGameSave` doit désormais attendre cette écriture avant
    // d'appeler `clearSnapshot()`.
    // ignore: avoid_dynamic_calls
    final finalizeFuture =
        (state as dynamic).finalizeGameSaveForTest(0, 'normal') as Future<void>;
    await finalizeFuture;

    // Laisse tourner ce qui peut tourner sans dépendre de la porte
    // (ex. l'écriture de l'historique de partie).
    await tester.pump(const Duration(milliseconds: 50));

    // On libère enfin l'écriture en vol.
    gatedService.releaseGate();
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_game_snapshot'), isNull,
        reason: "l'écriture en vol ne doit pas pouvoir ressusciter la "
            "partie terminée en s'exécutant après clearSnapshot()");
  });

  testWidgets(
      '_startGame() persiste isActive avant toute autre mutation (I-4, cas a)',
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
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (state as dynamic).startGameForTest();

    // Un crash juste après le lancement du chrono, avant toute autre
    // mutation et avant l'expiration du débounce de 500 ms : on démonte la
    // page pour déclencher dispose() dans cette fenêtre.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      ),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('active_game_snapshot');
    expect(raw, isNotNull);
    expect(
      GameSession.fromJson(json.decode(raw!)).isActive,
      isTrue,
      reason: 'le chrono démarré doit être persisté même sans aucune autre '
          'mutation, pour reprendre correctement après un crash',
    );
  });

  testWidgets(
      'un chrono actif persiste périodiquement même sans mutation de PV '
      '(I-4, cas b — compromis)',
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
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (state as dynamic).startGameForTest();

    // 30 s de chrono actif sans aucune mutation de PV (partie en pause),
    // puis la fenêtre de débounce pour laisser la persistance périodique
    // s'écrire.
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 600));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('active_game_snapshot');
    expect(raw, isNotNull);
    final persisted = GameSession.fromJson(json.decode(raw!));
    expect(persisted.isActive, isTrue);
    expect(
      persisted.duration.inSeconds,
      greaterThanOrEqualTo(30),
      reason: 'une partie en pause 30 s doit avoir persisté sa durée, pas '
          'seulement son démarrage, pour borner la perte en cas de crash',
    );
  });

  testWidgets(
      'le tirage du premier joueur met en surbrillance le même joueur que '
      'celui annoncé, même après un reorder (I-2)',
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
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();

    // Reorder d'affichage : le joueur 0 passe en dernière position.
    await reorderPlayersViaContainer(container, tester, 0, 3);

    // Lance le tirage (spin) : la boucle interne utilise des délais
    // aléatoires croissants (~3.3 s au total pour 20 tours), que le fake
    // clock du test traverse en un seul `pump`.
    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    unawaited((state as dynamic).pickStartingPlayerForTest() as Future<void>);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Le dialogue de résultat est affiché : on identifie le joueur annoncé
    // par le nom rendu dans l'AlertDialog (recherche scopée : les noms des
    // joueurs restent aussi affichés dans les zones, en arrière-plan).
    final session = container.read(gameSessionNotifierProvider)!;
    int? announcedPlayerId;
    for (final player in session.players) {
      final matches = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(player.config.name),
      );
      if (matches.evaluate().isNotEmpty) {
        announcedPlayerId = player.playerId;
        break;
      }
    }

    expect(announcedPlayerId, isNotNull,
        reason: 'le dialogue doit annoncer un joueur par son nom');
    // ignore: avoid_dynamic_calls
    final highlighted = (state as dynamic).highlightedPlayerIdForTest as int?;
    expect(
      highlighted,
      announcedPlayerId,
      reason: 'la zone mise en surbrillance en fin de tirage doit désigner '
          'le même joueur que celui annoncé dans le dialogue, même après '
          'un reorder',
    );
  });

  // --- Dette remboursée : le tiroir (showPlayerDrawer) rebranche 4 actions
  // rendues injoignables par la suppression du menu radial (tâche 5). Ces
  // quatre tests vérifient que chacune produit bien son effet sur la session,
  // déclenchée depuis le tiroir (ouvert via la poignée conditionnelle de la
  // zone du joueur 0), pas en appelant le contrôleur directement.

  /// Monte la page avec un `container` explicite (pour lire l'état ensuite)
  /// et un snapshot optionnel, comme `pumpLifeCounter` mais en exposant le
  /// `ProviderContainer` — nécessaire ici pour vérifier l'effet des actions
  /// du tiroir sur la session après coup.
  Future<ProviderContainer> pumpWithContainer(
    WidgetTester tester, {
    GameSession? snapshot,
    Map<String, Object>? extraPrefs,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (snapshot != null) 'active_game_snapshot': json.encode(snapshot.toJson()),
      ...?extraPrefs,
    });
    final container = ProviderContainer(
      overrides: [
        gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Ouvre le tiroir du joueur 0 en tapant réellement sa poignée
  /// conditionnelle, repérée par identité (`_playerZone(0)`) — jamais par
  /// position dans l'arbre, qui ne coïncide plus de façon fiable avec
  /// l'ordre canonique depuis la tâche 4 (colonnes latérales, sous-grille...).
  ///
  /// Un vrai `tester.tap` plutôt qu'un appel direct à `onTap` : sinon ces
  /// tests ne verrouilleraient que le câblage logique, pas l'accessibilité
  /// réelle du geste — si la poignée devenait un jour non tapable (recouverte,
  /// `HitTestBehavior` changé, hauteur nulle), ils resteraient verts alors que
  /// les quatre actions redeviendraient injoignables dans l'app.
  Future<void> openDrawerForPlayerZero(WidgetTester tester) async {
    await tester.tap(find.descendant(
      of: _playerZone(0),
      matching: find.byType(ConditionalHandle),
    ));
    await tester.pumpAndSettle();
  }

  /// Ouvre la feuille des presets d'orientation par un vrai tap sur son
  /// bouton (`action-orientation-presets`) — nécessite un écran assez large
  /// pour que `AdaptiveGrid` choisisse la bande (voir `TableLayout`) : sur
  /// un écran étroit, ce bouton n'existe pas, remplacé par le hub.
  Future<void> openOrientationSheet(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('action-orientation-presets')),
    );
    await tester.pumpAndSettle();
  }

  /// Sélectionne le preset [label] dans la feuille ouverte par
  /// `openOrientationSheet`, par un vrai tap sur son étiquette (unique dans
  /// la feuille, jamais un repérage ordinal).
  Future<void> selectOrientationPreset(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'DETTE 1/4 — le toggle monarque depuis le tiroir atteint la session',
      (tester) async {
    final container = await pumpWithContainer(tester);

    await openDrawerForPlayerZero(tester);
    // Tourner + Couleur (ronde de correction 1, tâche 2) allongent le
    // tiroir : sur la taille d'écran de test, "action-monarch" n'est plus
    // visible sans défiler (même raison que "action-reset" plus bas).
    await tester.ensureVisible(find.byKey(const ValueKey('action-monarch')));
    await tester.tap(find.byKey(const ValueKey('action-monarch')));
    // Pas de `pumpAndSettle()` ici : devenir monarque relance le glow du
    // cadre de la zone (`_glowController.repeat()`, US-14.3), une animation
    // en boucle infinie qui ferait timeout `pumpAndSettle`. Quelques frames
    // bornées suffisent à laisser le tiroir se refermer et la mutation
    // s'appliquer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.players[0].isMonarch, isTrue,
        reason: 'toggleMonarch() doit être atteignable depuis le tiroir, '
            'seul point d\'accès restant depuis la suppression du menu '
            'radial');
  });

  testWidgets(
      "DETTE 2/4 — l'élimination volontaire depuis le tiroir atteint la "
      'session',
      (tester) async {
    final container = await pumpWithContainer(tester);

    await openDrawerForPlayerZero(tester);
    // Lot 5, tâche 4 : la nouvelle ligne "Nouveau compteur" allonge le
    // tiroir -- même raison que le `ensureVisible` déjà utilisé plus bas
    // pour "action-reset" (DETTE 4/4).
    await tester.ensureVisible(find.byKey(const ValueKey('action-eliminate')));
    await tester.tap(find.byKey(const ValueKey('action-eliminate')));
    await tester.pumpAndSettle();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.players[0].isEliminated, isTrue,
        reason: "s'éliminer volontairement (hors détection de mort "
            'automatique) doit rester possible depuis le tiroir');
    expect(session.eliminationOrder, contains(0));
  });

  testWidgets(
      "DETTE 3/4 — annuler l'élimination depuis le tiroir restaure le "
      'joueur',
      (tester) async {
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    final eliminated = baseSession.eliminatePlayer(0, atDuration: Duration.zero);
    final container = await pumpWithContainer(tester, snapshot: eliminated);

    // Précondition : le joueur 0 est bien éliminé au chargement.
    expect(
      container.read(gameSessionNotifierProvider)!.players[0].isEliminated,
      isTrue,
    );

    await openDrawerForPlayerZero(tester);
    // Le libellé de l'action bascule sur "Annuler l'élimination" pour un
    // joueur déjà éliminé (voir player_drawer.dart) ; la clé reste la même.
    // Lot 5, tâche 4 : même raison de `ensureVisible` que ci-dessus.
    await tester.ensureVisible(find.byKey(const ValueKey('action-eliminate')));
    await tester.tap(find.byKey(const ValueKey('action-eliminate')));
    await tester.pumpAndSettle();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.players[0].isEliminated, isFalse,
        reason: '_undoElimination doit être recréée : le joueur redevient '
            'vivant');
    expect(session.eliminationOrder, isNot(contains(0)),
        reason: 'le joueur annulé doit être retiré de eliminationOrder');
  });

  testWidgets(
      'DETTE 4/4 — réinitialiser les compteurs depuis le tiroir ne touche '
      'pas la vie',
      (tester) async {
    final container = await pumpWithContainer(tester);
    final notifier = container.read(gameSessionNotifierProvider.notifier);

    // Vie entamée et les trois compteurs non nuls avant reset.
    notifier.updateLife(0, -10, gameDuration: Duration.zero);
    notifier.updateCounter(0, 'poison', 3);
    notifier.updateCounter(0, 'energy', 2);
    notifier.updateCounter(0, 'commander_tax', 1);

    await openDrawerForPlayerZero(tester);
    // La grille de dégâts de commandant (lot 3) allonge le tiroir : sur la
    // taille d'écran de test, "action-reset" (la dernière action) n'est
    // plus visible sans défiler.
    await tester.ensureVisible(find.byKey(const ValueKey('action-reset')));
    await tester.tap(find.byKey(const ValueKey('action-reset')));
    await tester.pumpAndSettle();

    final session = container.read(gameSessionNotifierProvider)!;
    final player0 = session.players[0];
    expect(player0.counters['poison'], 0);
    expect(player0.counters['energy'], 0);
    expect(player0.counters['commander_tax'], 0);
    expect(
      player0.life,
      30,
      reason: 'décision produit : onResetCounters ne remet que les '
          'compteurs à zéro, jamais la vie (rétrécissement délibéré du '
          "comportement de l'ancien menu radial)",
    );
  });

  // --- Lot 5, tâche 4 (AJOUT 1, câblage manquant) : avant ce correctif,
  // `_toLegacyPlayer` ne lisait que `ps.counters['poison']`/`['energy']`/
  // `['commander_tax']` vers trois champs `int` nommés de `Player`, et
  // `PlayerZone` ne construisait `CounterSummary` qu'à partir de CES TROIS
  // champs -- un `ps.counters['custom_shield']` n'avait donc AUCUN chemin
  // jusqu'à la poignée, bien que `CounterSummary`/`ConditionalHandle`
  // sachent déjà en afficher un (prouvé par `conditional_handle_test.dart`,
  // qui construit un `CounterSummary` directement et saute tout ce câblage).
  // Ce test-ci traverse le VRAI enchaînement, de bout en bout :
  // `GameSession.activeCounterIds` -> `PlayerState.counters` ->
  // `_toLegacyPlayer` -> `PlayerZone` -> poignée.
  testWidgets(
      'un compteur personnalisé actif dans la session atteint réellement la '
      'poignée du joueur, de GameSession jusqu\'à ConditionalHandle',
      (tester) async {
    const custom = CounterType(
      id: 'custom_shield',
      name: 'Bouclier',
      emoji: '🛡️',
      color: 0xFF2196F3,
      isBuiltIn: false,
    );

    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
      extraCounterIds: ['custom_shield'],
    );
    // Valeur NON NULLE (7) : une valeur à zéro ne distinguerait pas « le
    // compteur transite et vaut 0 » de « il ne transite pas du tout ».
    final players = [...baseSession.players];
    players[0] = players[0].copyWith(counters: {'custom_shield': 7});
    final session = baseSession.copyWith(players: players);

    await pumpWithContainer(
      tester,
      snapshot: session,
      extraPrefs: {
        'custom_counter_types': json.encode([custom.toJson()]),
      },
    );

    // Preuve de bout en bout : la donnée est bien arrivée jusqu'au
    // `CounterSummary` que porte la `ConditionalHandle` DU JOUEUR 0.
    //
    // Repéré par identité (`_playerZone(0)`), jamais par `.first` : depuis
    // la table v2, `AdaptiveGrid` place les zones selon
    // `tableLayoutFor`/`seatsFor`, et l'ordre dans l'arbre ne suit plus ni
    // l'ordre d'affichage ni l'ordre canonique. `.first` désignait ici la
    // poignée d'un autre joueur -- dont le compteur vaut bien 0, ce qui
    // rendait l'échec parfaitement crédible sans rien dire du câblage
    // testé.
    final handle = tester.widget<ConditionalHandle>(
      find.descendant(
        of: _playerZone(0),
        matching: find.byType(ConditionalHandle),
      ),
    );
    final shieldEntry = handle.summary.counters
        .firstWhere((entry) => entry.key.id == 'custom_shield');
    expect(shieldEntry.value, 7,
        reason: 'PlayerState.counters["custom_shield"] doit traverser '
            '_toLegacyPlayer puis PlayerZone jusqu\'au CounterSummary de la '
            'poignée -- pas seulement être construit directement dans un '
            'test qui saute ce câblage');

    // Et la puce est bien VISIBLE à l'écran (pas seulement présente dans la
    // donnée du widget) : c'est elle que le joueur doit voir apparaître.
    expect(find.text('🛡️ 7'), findsOneWidget,
        reason: 'le compteur personnalisé actif doit se voir sur la '
            'poignée, en jeu réel, pas seulement dans un CounterSummary '
            'construit à la main');
  });

  // --- Lot 3, tâche 2 : la grille de dégâts de commandant reçus, dans le
  // tiroir. Remplace la ligne provisoire du lot 2 (le sélecteur plein écran
  // orienté à l'envers) et corrige son sens : la grille liste les
  // adversaires comme SOURCES des dégâts REÇUS par le joueur dont le tiroir
  // est ouvert. Quatre joueurs aux identifiants distincts (0-3) : une
  // inversion playerId <-> sourcePlayerId serait détectée par les
  // assertions croisées ci-dessous.

  testWidgets(
      'la grille du tiroir écrit les dégâts sur le joueur DONT LE TIROIR '
      'EST OUVERT, avec la ligne tapée comme SOURCE — pas l\'inverse',
      (tester) async {
    final container = await pumpWithContainer(tester);

    // Tiroir du joueur 0 (Alex), ouvert par un vrai tap sur sa poignée.
    await openDrawerForPlayerZero(tester);

    // La grille liste les trois autres joueurs (1, 2, 3) comme sources.
    // On tape sur la ligne du joueur 2 (Sarah).
    //
    // `ensureVisible` d'abord : le tiroir s'est allongé des deux côtés de la
    // fusion (« Tourner », « Couleur » et « Historique du joueur » de la
    // table v2 ; les lignes de compteur du lot 5), et la grille de dégâts de
    // commandant, qui vient APRÈS elles, n'entre plus dans la feuille sans
    // défiler à cette taille d'écran -- même raison que pour
    // « action-monarch » et « action-reset » plus haut. Le tap reste un vrai
    // tap sur le vrai bouton ; seul le défilement qu'un doigt ferait de
    // lui-même est rendu explicite.
    await tester.ensureVisible(
      find.byKey(const ValueKey('commander-damage-2-plus')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('commander-damage-2-plus')));
    await tester.pump();
    // Laisse le minuteur du flash de dégâts de commandant (600ms) se purger
    // avant la fin du test (même contrainte que les autres tests de flash).
    await tester.pump(const Duration(milliseconds: 600));

    final session = container.read(gameSessionNotifierProvider)!;
    final player0 = session.players[0];
    final player2 = session.players[2];

    expect(
      player0.commanderDamageReceived[2],
      1,
      reason: 'le joueur DONT LE TIROIR EST OUVERT (0) doit recevoir le '
          'dégât, la ligne tapée (2, Sarah) en étant la SOURCE',
    );
    expect(player0.life, 39,
        reason: 'le joueur du tiroir perd 1 PV (40 -> 39)');

    expect(
      player2.commanderDamageReceived[0],
      isNull,
      reason: 'une grille inversée écrirait ce dégât sur la source (2) '
          'plutôt que sur le joueur du tiroir (0)',
    );
    expect(player2.life, 40,
        reason: 'la source ne doit perdre aucun PV — seul le joueur du '
            'tiroir en perd');
    expect(player0.commanderDamageReceived[1] ?? 0, 0,
        reason: 'seule la ligne tapée (2) doit être affectée, pas les '
            'autres adversaires (1, 3) listés dans la même grille');
    expect(player0.commanderDamageReceived[3] ?? 0, 0);
  });

  testWidgets(
      'la grille du tiroir liste bien tous les adversaires (pas le joueur '
      'du tiroir lui-même) avec leur total déjà reçu',
      (tester) async {
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    // Le joueur 0 a déjà reçu 5 dégâts du joueur 3 avant l'ouverture du tiroir.
    final withDamage = baseSession.copyWith(
      players: [
        baseSession.players[0].copyWith(
          life: 35,
          commanderDamageReceived: {3: 5},
        ),
        ...baseSession.players.sublist(1),
      ],
    );
    await pumpWithContainer(tester, snapshot: withDamage);

    await openDrawerForPlayerZero(tester);

    // Les trois adversaires (Max=1, Sarah=2, Leo=3) apparaissent comme
    // sources dans la grille, et le total déjà reçu de Leo (3) est affiché.
    // Recherche bornée à la grille : le nom d'un adversaire est aussi
    // affiché sur sa propre zone, ailleurs dans l'arbre.
    final grid = find.byType(CommanderDamageGrid);
    expect(grid, findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('Max')),
        findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('Sarah')),
        findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('Leo')),
        findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('5')),
        findsOneWidget,
        reason: 'le total déjà reçu de la source 3 doit être affiché');
  });

  // Point mineur de la ronde de correction 1 : « adversaire éliminé toujours
  // listé » n'était vérifié qu'au niveau du widget isolé (le type ne porte
  // aucune info d'élimination). Ce test couvre le vrai scénario produit :
  // un joueur réellement éliminé reste une source corrigeable après coup
  // dans le tiroir d'un autre joueur.
  testWidgets(
      'un adversaire réellement éliminé reste listé dans la grille du '
      'tiroir, avec son total corrigeable', (tester) async {
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    // Leo (3) est éliminé, mais avait déjà infligé 2 dégâts de commandant à
    // Alex (0) avant son élimination.
    final eliminated = baseSession.eliminatePlayer(3, atDuration: Duration.zero);
    final withDamage = eliminated.copyWith(
      players: [
        eliminated.players[0].copyWith(
          life: 38,
          commanderDamageReceived: {3: 2},
        ),
        ...eliminated.players.sublist(1),
      ],
    );
    final container = await pumpWithContainer(tester, snapshot: withDamage);

    // Précondition : Leo est bien éliminé au chargement.
    expect(
      container.read(gameSessionNotifierProvider)!.players[3].isEliminated,
      isTrue,
    );

    await openDrawerForPlayerZero(tester);

    final grid = find.byType(CommanderDamageGrid);
    expect(
      find.descendant(of: grid, matching: find.text('Leo')),
      findsOneWidget,
      reason: 'un adversaire éliminé doit rester listé comme source, pas '
          'disparaître de la grille',
    );
    expect(find.descendant(of: grid, matching: find.text('2')),
        findsOneWidget,
        reason: 'son total déjà reçu reste consultable');

    // Le total reste corrigeable : un tap sur sa ligne l'incrémente comme
    // n'importe quel autre adversaire. « Historique du joueur » (revue
    // finale, IMPORTANT #1) a allongé le tiroir d'une entrée : la grille
    // passe sous le pli sur cette taille de fenêtre, il faut défiler avant
    // de taper, comme un vrai doigt le ferait.
    await tester
        .ensureVisible(find.byKey(const ValueKey('commander-damage-3-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('commander-damage-3-plus')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final player0 = container.read(gameSessionNotifierProvider)!.players[0];
    expect(player0.commanderDamageReceived[3], 3,
        reason: 'le total attribué à un adversaire éliminé reste '
            'incrémentable depuis le tiroir');
    expect(player0.life, 37);
  });

  testWidgets(
      "PlayerZoneNotifier.reset() est câblé sur le démarrage d'une nouvelle "
      'partie (ronde de correction 1 de la tâche 1) : le mode ajustement '
      'ne doit pas survivre',
      (tester) async {
    final container = await pumpWithContainer(tester);

    // État transitoire simulé directement sur le notifier — ce test vérifie
    // uniquement que `_startNewGame` le purge, pas comment on y entre (déjà
    // couvert par player_zone_test.dart / life_dial_test.dart).
    container.read(playerZoneNotifierProvider(0).notifier).enterAdjustMode();
    expect(
      container.read(playerZoneNotifierProvider(0)).isAdjusting,
      isTrue,
      reason: 'précondition : la zone du joueur 0 est en mode ajustement',
    );

    // Bouton « refresh » de la barre centrale : un vrai tap, qui appelle
    // _resetGame() -> _startNewGame(), pas un appel direct à une méthode.
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(
      container.read(playerZoneNotifierProvider(0)).isAdjusting,
      isFalse,
      reason: 'PlayerZoneNotifier.reset() doit être appelé pour chaque '
          "joueur au démarrage d'une nouvelle partie : le provider n'étant "
          'pas autoDispose, une zone pouvait sinon revenir en mode '
          "ajustement au retour, sans que l'utilisateur ait rien fait",
    );
  });

  // --- Lot 3, tâche 3 : attribution à la volée (spec §2.6). Pendant que le
  // buffer de dégâts tourne sur un joueur, une rangée d'avatars adverses
  // apparaît ; un tap dessus convertit le dégât en attente en dégâts de
  // commandant de l'avatar tapé. Tous les gestes ci-dessous sont de vrais
  // `tester.tapAt` sur le cadran réel (LifeDial), pas des appels directs au
  // callback -- voir « la leçon des lots 1 et 2 » du plan.
  //
  // Joueur d'indice 2 (Sarah) choisi comme émetteur du buffer : avec 4
  // joueurs, `AdaptiveGrid` pivote à 180° les zones du haut (indices 0-1) et
  // laisse celles du bas (indices 2-3) droites -- Sarah (index 2) n'a donc
  // pas besoin de compensation de rotation pour ces tests (`tapMinusHalf`,
  // désormais définie au niveau du fichier, la calcule de toute façon).

  testWidgets(
      'en format Commander, la rangée d\'attribution apparaît pendant que '
      'le buffer tourne, avec un avatar par adversaire (pas le joueur '
      'lui-même)', (tester) async {
    await pumpWithContainer(tester);

    // Deux taps (pas un seul) : un tap unique laisserait le nombre flottant
    // du geste ("-1", voir player_zone._showFloatingNumber) coexister avec
    // le badge cumulé du buffer, qui affiche aussi "-1" après un seul tap —
    // ambigu pour l'assertion de précondition ci-dessous.
    await tapMinusHalf(tester, 2, 2);

    expect(find.text('-2'), findsOneWidget,
        reason: 'précondition : le buffer tourne bien sur le joueur 2');
    expect(find.byKey(const ValueKey('damage-attribution-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('damage-attribution-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('damage-attribution-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('damage-attribution-2')), findsNothing,
        reason:
            'le joueur dont le buffer tourne ne doit pas s\'auto-proposer '
            'comme cible de sa propre attribution');

    // Purge les minuteurs de nombres flottants encore en vol (600ms) avant
    // la fin du test, sous peine de l'assertion `!timersPending` du binding.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'taper un avatar CONVERTIT le dégât en attente en dégât de '
      'commandant : la vie ne baisse qu\'une seule fois, aucun dégât '
      'générique ne s\'ajoute en plus (test le plus important de la tâche)',
      (tester) async {
    // Sarah (2) a déjà reçu 2 dégâts de commandant d'Alex (0) avant le
    // buffer testé ici : un bug de signe qui passerait le pending brut
    // (négatif) plutôt que sa valeur absolue ferait alors REMONTER sa vie
    // (le plancher à 0 de `addCommanderDamage` masquerait le bug si on
    // partait de 0 dégât déjà reçu) -- voir le commentaire de
    // `_attributeCommanderDamage`.
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    final withPriorDamage = baseSession.copyWith(
      players: [
        baseSession.players[0],
        baseSession.players[1],
        baseSession.players[2]
            .copyWith(life: 38, commanderDamageReceived: {0: 2}),
        baseSession.players[3],
      ],
    );
    final container =
        await pumpWithContainer(tester, snapshot: withPriorDamage);

    // Cinq taps −1 sur le cadran de Sarah (2) : 5 dégâts en attente.
    await tapMinusHalf(tester, 2, 5);
    expect(find.text('-5'), findsOneWidget,
        reason: 'précondition : 5 dégâts en attente avant toute attribution');

    // Attribution à Alex (0), pendant que le buffer tourne encore.
    await tester.tap(find.byKey(const ValueKey('damage-attribution-0')));
    await tester.pump();

    var session = container.read(gameSessionNotifierProvider)!;
    expect(session.players[2].commanderDamageReceived[0], 7,
        reason: 'les 5 dégâts en attente doivent s\'ajouter aux 2 déjà '
            'reçus d\'Alex (0), comme un dégât de commandant normal');
    expect(session.players[2].life, 33,
        reason: 'la vie ne doit baisser qu\'une seule fois, du montant '
            'tapé (38 -> 33) -- pas 38 -> 33 puis -5 supplémentaires, et '
            'surtout pas remontée par une erreur de signe');

    // Ronde de correction 1 (Important #3) : même signal visuel que
    // l'attribution depuis le tiroir (`_onDrawerCommanderDamage`), pour le
    // même événement.
    expect(find.byIcon(Icons.shield), findsOneWidget,
        reason: 'le flash de dégâts de commandant doit se déclencher sur ce '
            'chemin aussi, pas seulement depuis la grille du tiroir');

    // Le minuteur en attente devait être annulé et l'entrée retirée du
    // buffer : laisser largement passer sa fenêtre de 2s ne doit produire
    // aucune seconde application.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    session = container.read(gameSessionNotifierProvider)!;
    expect(session.players[2].life, 33,
        reason: 'si le minuteur en attente n\'avait pas été annulé, il '
            'aurait appliqué un second dégât générique de 5 ici (33 -> 28)');
    expect(session.players[2].commanderDamageReceived[0], 7);
    expect(find.text('-5'), findsNothing,
        reason: 'aucun badge de buffer ne doit subsister après attribution');
  });

  testWidgets(
      'sans tap sur un avatar, le dégât en attente reste générique une '
      'fois le buffer expiré', (tester) async {
    final container = await pumpWithContainer(tester);

    await tapMinusHalf(tester, 2, 3);
    expect(find.text('-3'), findsOneWidget);
    // La rangée est bien visible pendant le buffer, sans quoi ce test ne
    // prouverait rien de l'absence d'attribution volontaire.
    expect(find.byKey(const ValueKey('damage-attribution-0')), findsOneWidget);

    // Aucun tap sur un avatar : le buffer expire normalement.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.players[2].life, 37, reason: '40 - 3, dégât générique');
    expect(session.players[2].commanderDamageReceived, isEmpty,
        reason: 'sans attribution, le dégât reste générique : aucun dégât '
            'de commandant ne doit apparaître');
  });

  testWidgets(
      'en format Standard (le vrai preset, maxCommanderDamage == 0), la '
      'rangée d\'attribution n\'apparaît jamais',
      (tester) async {
    // Ronde de correction 1 (Important #4) : le preset `standard` réel, pas
    // un format bricolé par `copyWith` — ce dernier ne prouvait que le
    // garde fonctionne quand ON LUI DONNE 0, jamais que le preset livré
    // vaut bien 0 (voir aussi le correctif de `lib/models/game_format.dart`,
    // qui héritait de 21 avant ce lot).
    final standardFormat =
        GameFormat.builtInFormats.firstWhere((f) => f.id == 'standard');
    expect(standardFormat.maxCommanderDamage, 0,
        reason: 'précondition : le preset Standard doit bien être à 0 '
            '(régression du correctif de game_format.dart)');
    final baseSession = GameSession.newGame(
      format: standardFormat,
      playerConfigs: testConfigs,
    );
    await pumpWithContainer(tester, snapshot: baseSession);

    await tapMinusHalf(tester, 2, 3);

    expect(find.text('-3'), findsOneWidget,
        reason: 'précondition : le buffer tourne bien malgré le format');
    expect(find.byKey(const ValueKey('damage-attribution-0')), findsNothing);
    expect(find.byKey(const ValueKey('damage-attribution-1')), findsNothing);
    expect(find.byKey(const ValueKey('damage-attribution-3')), findsNothing);

    // Purge les minuteurs de nombres flottants encore en vol (600ms) avant
    // la fin du test, sous peine de l'assertion `!timersPending` du binding.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'ronde de correction 1 (Critical #1) — un buffer POSITIF (lifelink) '
      'ne fait jamais apparaître la rangée d\'attribution',
      (tester) async {
    await pumpWithContainer(tester);

    // Deux taps +1 (moitié droite du cadran de Sarah, playerId 2, non
    // pivoté) : un gain de vie en attente, jamais un dégât. Repéré par
    // identité, pas par position dans l'arbre.
    final dial = tester.getRect(find.descendant(
      of: _playerZone(2),
      matching: find.byType(LifeDial),
    ));
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(Offset(dial.left + dial.width * 0.75, dial.center.dy));
      await tester.pump();
    }

    expect(find.text('+2'), findsOneWidget,
        reason: 'précondition : le buffer tourne bien, positif, sur Sarah');
    expect(find.byKey(const ValueKey('damage-attribution-0')), findsNothing,
        reason: 'un gain de vie en attente ne doit jamais proposer '
            'd\'attribution : ce serait transformer +2 PV en −2 PV plus 2 '
            'dégâts de commandant fantômes');
    expect(find.byKey(const ValueKey('damage-attribution-1')), findsNothing);
    expect(find.byKey(const ValueKey('damage-attribution-3')), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'ronde de correction 1 (Important #2) — un buffer ramené à zéro '
      '(−1 puis +1) fait disparaître la rangée en même temps que le badge',
      (tester) async {
    await pumpWithContainer(tester);

    // Deux taps −1 (pas un seul) : un unique tap laisserait le nombre
    // flottant du geste ("-1") coexister avec le badge cumulé, tout aussi
    // "-1" après un seul tap — même ambiguïté que dans le test de
    // visibilité initial, voir son commentaire.
    await tapMinusHalf(tester, 2, 2);
    expect(find.text('-2'), findsOneWidget,
        reason: 'précondition : le buffer est bien à -2');
    expect(find.byKey(const ValueKey('damage-attribution-0')), findsOneWidget,
        reason: 'précondition : la rangée est bien visible sur un buffer '
            'négatif, sans quoi ce test ne prouverait rien de sa '
            'disparition');

    // Les deux +1 qui suivent ramènent le buffer net à 0, avant expiration
    // des 2s. Repéré par identité (Sarah, playerId 2).
    final dial = tester.getRect(find.descendant(
      of: _playerZone(2),
      matching: find.byType(LifeDial),
    ));
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(Offset(dial.left + dial.width * 0.75, dial.center.dy));
      await tester.pump();
    }

    expect(find.text('-2'), findsNothing,
        reason: 'le badge de buffer doit disparaître à 0, comme avant ce '
            'lot');
    expect(find.byKey(const ValueKey('damage-attribution-0')), findsNothing,
        reason: 'la rangée doit disparaître EN MÊME TEMPS que le badge : '
            'rien à attribuer sur un buffer revenu à 0');

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'un vrai tap sur le bouton de la barre centrale ouvre la vue table '
      '(tâche 4, ronde de correction 1) via une route GoRouter — pas de '
      'geste à deux doigts sur les zones',
      (tester) async {
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    SharedPreferences.setMockInitialValues({
      'active_game_snapshot': json.encode(baseSession.toJson()),
    });

    // Ronde de correction 1 : `_showTableView` pousse désormais
    // `AppRoutes.tableView` via `context.push` (GoRouter), comme toutes les
    // autres pages plein-écran empilées par-dessus le shell — un simple
    // `MaterialApp` (sans GoRouter) ne suffit donc plus pour ce test. Les
    // deux routes ci-dessous reproduisent le strict nécessaire de
    // `life_counter_routes.dart` : le shell (ici juste un `Scaffold`, voir
    // la note de `pumpLifeCounter`) et la route détail visée.
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) =>
              const Scaffold(body: LifeCounterPage()),
        ),
        GoRoute(
          path: AppRoutes.tableView,
          builder: (context, state) => const TableViewPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TableViewPage), findsNothing,
        reason: 'précondition : la vue table n\'est pas encore ouverte');

    // Un VRAI tap (tester.tap), pas un appel de méthode direct — voir « la
    // leçon des lots 1 et 2 » du plan : un callback appelé à la main ne
    // prouve rien du geste que l'appareil produit réellement.
    await tester.tap(find.byKey(const ValueKey('action-table-view')));
    await tester.pumpAndSettle();

    expect(find.byType(TableViewPage), findsOneWidget);
  });

  testWidgets(
      'ronde de correction 1 (Important) — la barre centrale ne déborde pas '
      'sur un téléphone étroit ; son 8e bouton (vue table) est déplacé dans '
      'le hub (tâche 4)',
      (tester) async {
    // 320px logiques : le plus étroit des téléphones courants. La barre
    // centrale comptait déjà 7 enfants de taille fixe (dont un cercle de
    // 50×50) avant le bouton de la tâche 4, qui porte le total à 8 — sans
    // protection, `Row(spaceEvenly)` seul dépasse ici et lève une erreur de
    // rendu (RenderFlex overflow), invisible sur un simulateur large.
    //
    // Tâche 4 (AdaptiveGrid) : `tableLayoutFor` choisit maintenant le HUB
    // (pas la bande) sous `kLargeScreenShortEdge` (600) — un téléphone
    // étroit n'affiche donc plus jamais la bande à 8 boutons ; le risque de
    // dépassement qu'elle posait ne s'y produit plus PAR CONSTRUCTION,
    // puisque `AdaptiveGrid` ne la monte plus du tout dans ce cas.
    //
    // Revue finale (M2) : le hub n'est plus un placeholder -- la tâche 6 est
    // livrée, `AdaptiveGrid` monte un vrai `ActionHub`. L'atteignabilité des
    // actions depuis le hub est couverte ailleurs dans ce fichier (« les
    // infos de partie sont aussi atteignables depuis le hub, sur petit
    // écran ») et par `test/widgets/life_counter/zone/action_hub_test.dart`.
    // Ce test-ci ne porte que sur l'ABSENCE de débordement de la bande.
    _setScreenSize(tester, const Size(320, 640));

    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    await pumpLifeCounter(tester, snapshot: baseSession);

    // Le cœur du test : sans protection, la bande à 8 boutons aurait déjà
    // capturé une exception de dépassement à ce stade si elle était montée.
    expect(tester.takeException(), isNull,
        reason: 'la barre centrale ne doit jamais déborder, même sur un '
            'écran étroit');

    // La bande (et son 8e bouton) n'est plus montée du tout sur un écran
    // aussi étroit : c'est le hub qui prend sa place (voir AdaptiveGrid,
    // tâche 4).
    expect(find.byKey(const ValueKey('action-table-view')), findsNothing,
        reason: 'sur téléphone étroit, la bande centrale (et son bouton '
            '« vue table ») cède la place au hub, elle ne déborde plus '
            'jamais par construction');
    expect(find.byKey(const ValueKey('action_hub')), findsOneWidget,
        reason: 'AdaptiveGrid doit choisir le hub, pas la bande, sous le '
            'seuil de grand écran');
  });

  testWidgets(
      'ronde de correction 1 (Important, revue) — à la largeur la plus '
      'étroite où la bande est encore choisie, elle ne déborde pas et son '
      'dernier bouton reste atteignable',
      (tester) async {
    // Le test ci-dessus prouve qu'un téléphone étroit échappe à la bande
    // (hub à la place) : ça ne dit rien de la bande elle-même. Elle n'est
    // montée qu'à partir de 600px de petit côté (`kLargeScreenShortEdge`) ;
    // c'est là, et seulement là, qu'il faut vérifier qu'elle ne déborde
    // toujours pas -- sous peine de laisser un vrai trou de couverture,
    // exactement celui que la ronde de revue a mis en évidence (le garde-fou
    // de `_buildCentralBar` peut être supprimé en pur sans qu'aucun test
    // n'en dise rien).
    //
    // À 4 joueurs et 600px de large, `tableLayoutFor` choisit encore la
    // bande, mais SANS colonnes latérales depuis la ronde de correction 1
    // (option C) : `kActionWidth` (largeur supposée d'un bouton d'action)
    // est passé de 36 à 48 -- la vraie taille minimale d'un `IconButton`
    // Material, mesurée en pratique ; 36 était faux depuis l'origine de la
    // bande. `kBandNeed` en dérive : 9 × (48 + 4) + 4 = 472px. Le budget des
    // colonnes latérales à cette largeur (600 - 192 = 408px) ne loge plus
    // les deux à la fois : les colonnes cèdent (§6, "on renonce, on ne
    // rétrécit pas"), la bande garde toute la largeur de l'écran (600px),
    // qui loge large ses 9 vrais boutons (432px de contenu minimum).
    _setScreenSize(tester, const Size(600, 900));

    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    await pumpLifeCounter(tester, snapshot: baseSession);

    expect(find.byKey(const ValueKey('action_band')), findsOneWidget,
        reason: 'à cette largeur, AdaptiveGrid doit choisir la bande, pas '
            'le hub -- sans quoi ce test ne vérifie rien de la bande');
    expect(tester.takeException(), isNull,
        reason: 'la bande ne doit jamais déborder, même à sa largeur la '
            'plus contrainte');

    // "Game setup" et le dernier bouton de la bande ("Infos de partie",
    // depuis la ronde de correction 1) doivent rester réellement
    // atteignables, pas seulement présents hors champ derrière un
    // `ConstrainedBox` mal borné.
    await tester.ensureVisible(
      find.byKey(const ValueKey('action-game-setup')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('action-game-info')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ===========================================================================
  // Revue finale, IMPORTANT #3 — le LIEN entre les trois choses qui devaient
  // rester d'accord et que rien ne reliait : `kActionCount` (saisi à la main
  // dans `table_layout.dart`, et dont `kBandNeed` dérive), `_gameActions` (la
  // source unique), et la bande (qui câblait neuf boutons À L'INDEX).
  //
  // Scénario du défaut réarmé : quelqu'un ajoute une dixième action. Le hub
  // l'affiche (il itère), la bande l'ignore (elle s'arrêtait à l'index 8), et
  // `kBandNeed` sous-estime la largeur — les deux mécaniques exactes du
  // défaut d'origine (rulings 15 et 16).
  //
  // `kActionCount` ne peut pas être dérivé de `_gameActions` : il vit dans
  // `table_layout.dart`, que la page importe et qui ne peut pas importer la
  // page en retour. Ces tests SONT le lien.
  // ===========================================================================
  group('la bande, le hub et kActionCount comptent la même chose (IMPORTANT #3)',
      () {
    testWidgets(
        'la bande rend exactement kActionCount boutons, et autant que le hub '
        'rend d entrées', (tester) async {
      final baseSession = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: testConfigs,
      );

      // --- La bande (taille de test par défaut : shortEdge 600, donc bande).
      await pumpLifeCounter(tester, snapshot: baseSession);
      final band = find.byKey(const ValueKey('action_band'));
      expect(band, findsOneWidget,
          reason: 'précondition : sans bande, ce test ne dit rien');

      // Repérage par `ValueKey('action-<id>')` : chaque action de
      // `_gameActions` en pose une, y compris les trois rendus bespoke.
      // Aucun repérage ordinal, et aucun comptage par type de widget (le
      // chrono n est pas un `IconButton`).
      final bandButtons = find.descendant(
        of: band,
        matching: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('action-'),
        ),
      );
      final bandCount = bandButtons.evaluate().length;
      expect(bandCount, kActionCount,
          reason: 'la bande rend $bandCount boutons pour kActionCount='
              '$kActionCount : si elles divergent, kBandNeed calcule la '
              'largeur de la bande sur un compte faux');

      // --- Le hub, sur petit écran, sur la MÊME liste d actions.
      _setScreenSize(tester, const Size(400, 700));
      await pumpLifeCounter(tester, snapshot: baseSession);
      expect(find.byKey(const ValueKey('action_hub')), findsOneWidget,
          reason: 'précondition : sur cet écran, le hub remplace la bande');
      await tester.tap(find.byKey(const ValueKey('action_hub_button')));
      await tester.pumpAndSettle();

      final hubEntries = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('hub-action-'),
      );
      final hubCount = hubEntries.evaluate().length;
      expect(hubCount, bandCount,
          reason: 'le hub rend $hubCount entrées et la bande $bandCount '
              'boutons : une action joignable dans une forme et pas dans '
              'l autre est exactement le défaut que la tâche 6 existe pour '
              'éliminer');
    });
  });

  testWidgets(
      'ronde de correction 1 (tâche 6) — les infos de partie sont '
      'atteignables depuis la bande, par un tap ordinaire sur leur propre '
      'action',
      (tester) async {
    // Taille de test par défaut : shortEdge 600 >= kLargeScreenShortEdge,
    // donc `tableLayoutFor` choisit la bande (voir `TableLayout.barKind`).
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    await pumpLifeCounter(tester, snapshot: baseSession);

    expect(find.byKey(const ValueKey('action_band')), findsOneWidget,
        reason: 'précondition : ce test ne vérifie rien de la bande sinon');
    expect(find.text('Infos Partie'), findsNothing,
        reason: 'précondition : la feuille n\'est pas encore ouverte');

    // Un vrai tap sur l'action dédiée, PAS l'appui long caché sur le
    // bouton d'orientation : c'est justement ce chemin caché que la ronde
    // de correction 1 remplace par un accès de plein droit.
    await tester.tap(find.byKey(const ValueKey('action-game-info')));
    await tester.pumpAndSettle();

    expect(find.text('Infos Partie'), findsOneWidget,
        reason: 'un tap ordinaire sur "Infos de partie" doit ouvrir la '
            'feuille des infos de partie');
  });

  testWidgets(
      'ronde de correction 1 (tâche 6) — les infos de partie sont aussi '
      'atteignables depuis le hub, sur petit écran',
      (tester) async {
    // 320px logiques : sous kLargeScreenShortEdge, `tableLayoutFor` choisit
    // le hub -- la bande (et son action "Infos de partie") n'existe pas du
    // tout à cette largeur.
    _setScreenSize(tester, const Size(320, 640));

    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    await pumpLifeCounter(tester, snapshot: baseSession);

    expect(find.byKey(const ValueKey('action_hub')), findsOneWidget,
        reason: 'précondition : ce test ne vérifie rien du hub sinon');

    await tester.tap(find.byKey(const ValueKey('action_hub_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Infos de partie'));
    await tester.pumpAndSettle();

    expect(find.text('Infos Partie'), findsOneWidget,
        reason: 'les infos de partie doivent être atteignables depuis le '
            'hub, pas seulement depuis la bande d\'un grand écran');
  });

  // --- Vague de correction finale du lot 3 (Critical #1) : la rangée
  // d'attribution (tâche 3) et les paliers ±5/±10 du mode ajustement (lot 2,
  // spec §2.5) sont tous les deux ancrés au bas de la zone -- sur certaines
  // géométries d'écran ils se superposent, et la rangée, ajoutée après dans
  // le Stack, gagne le hit-test. Aucun test de ce fichier n'entrait en mode
  // ajustement avant celui-ci. Le correctif retenu (le plus simple, et le
  // plus juste : les deux mécanismes servent la même intention -- saisir un
  // montant -- et ne doivent jamais coexister) masque la rangée dès que la
  // zone est en mode ajustement, quel que soit le signe du buffer.
  // Réécrit pour la tâche 7 (encodait l'ancien modèle) : la version
  // précédente sélectionnait le palier "-5" par un TAP SÉPARÉ, après le
  // relâchement de l'appui long -- un mode persistant que la tâche 7
  // supprime (spec §5.1). Il n'existe plus de tap discret sur un palier : la
  // sélection se fait en glissant le doigt de l'appui long jusqu'au palier
  // puis en relâchant (un seul geste continu), qui referme aussitôt le mode.
  // Les DEUX sélections de "-5" sont donc désormais DEUX gestes continus
  // complets et séparés (appui long + glissé + relâché), pas un appui long
  // suivi de deux taps -- ce que ce test vérifie reste inchangé : chaque
  // sélection doit rester un palier, jamais une attribution silencieuse.
  testWidgets(
      'en mode ajustement, la rangée d\'attribution n\'apparaît jamais '
      '(même sur un buffer négatif) : les paliers ±5/±10 restent seuls '
      'maîtres du bas de la zone, atteignables par un second geste continu',
      (tester) async {
    final container = await pumpWithContainer(tester);

    // Appui long réel sur le cadran de Sarah (playerId 2), repéré par
    // identité : bascule en mode ajustement (spec §2.5) -- pas d'appel
    // direct au notifier, voir « la leçon des lots 1 et 2 ».
    Finder sarahDial() => find.descendant(
          of: _playerZone(2),
          matching: find.byType(LifeDial),
        );

    // Le palier "-5", cherché comme DESCENDANT du cadran de Sarah : dès la
    // première sélection, un badge de buffer affichant aussi "-5" apparaît
    // ailleurs dans la zone (hors du LifeDial) -- `find.text('-5')` seul
    // deviendrait ambigu pour la seconde sélection sans cette portée.
    Finder stepMinus5() => find.descendant(
          of: sarahDial(),
          matching: find.text('-5'),
        );

    // Première sélection de "-5" : alimente le buffer à -5, négatif, en
    // format Commander. Vérifié PENDANT la tenue, avant le relâchement : les
    // deux mécanismes ne se recouvrent jamais tant que les paliers sont
    // affichés (`showAttribution` exige `!isAdjusting`, life_counter_page.dart
    // ~ligne 1130).
    var gesture = await tester.startGesture(tester.getCenter(sarahDial()));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('damage-attribution-0')), findsNothing,
        reason: 'la rangée ne doit jamais apparaître tant que les paliers '
            'sont affichés : sur les géométries où elle les recouvrirait, '
            'elle en volerait le hit-test');

    await gesture.moveTo(tester.getCenter(stepMinus5()));
    await gesture.up();
    await tester.pump();

    // Note (tâche 7) : `showAttribution` redevient vrai dès CE relâchement
    // (`isAdjusting` repasse à `false` dans le même geste qui vient de fixer
    // le buffer à -5) -- la rangée peut donc apparaître ICI, entre les deux
    // sélections, ce que l'ancien modèle (mode persistant tant qu'un second
    // tap distinct ne le fermait pas) empêchait. Ce n'est plus un défaut : les
    // paliers ont déjà disparu au moment où elle apparaît (même geste, même
    // frame), donc il n'y a jamais de recouvrement ni de vol de hit-test —
    // seule l'invariante finale (deux paliers cumulés, aucune attribution)
    // reste ce que ce test doit garantir.

    // Seconde sélection de "-5", un geste continu SÉPARÉ (le mode s'est
    // refermé au relâchement précédent, spec §5.1) : doit rester un second
    // palier, jamais une attribution silencieuse à un adversaire.
    gesture = await tester.startGesture(tester.getCenter(sarahDial()));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    // Important #5 (round de correction 1) : c'est ICI, et seulement ici,
    // que la conjonction exacte qui motivait le garde `!isAdjusting` est
    // reproduite -- buffer déjà négatif (-5, de la première sélection) ET
    // mode ajustement de nouveau ouvert. La déplacer sur la première tenue
    // (buffer encore à 0) ne prouvait rien de cette conjonction.
    expect(find.byKey(const ValueKey('damage-attribution-0')), findsNothing,
        reason: 'avec un buffer déjà négatif ET les paliers de nouveau '
            'affichés, la rangée ne doit toujours pas apparaître');

    await gesture.moveTo(tester.getCenter(stepMinus5()));
    await gesture.up();
    await tester.pump();

    // Laisse le buffer de 2s s'appliquer normalement.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.players[2].life, 30,
        reason: 'les deux taps sur le palier -5 doivent cumuler -10 '
            '(40 -> 30), comme deux paliers -- pas -5 générique puis une '
            'attribution silencieuse au second tap');
    expect(session.players[2].commanderDamageReceived, isEmpty,
        reason: 'aucune attribution ne doit avoir eu lieu : le second tap '
            'devait rester un palier, jamais un avatar recouvrant');
  });

  // --- Lot 5, tâche 4 : créer/retirer un compteur depuis le tiroir, câblage
  // réel (CounterCatalogNotifier.saveCustomType + GameSessionNotifier).
  // player_drawer_test.dart couvre déjà la mécanique UI du tiroir avec des
  // doubles de callback ; les tests ci-dessous vérifient que
  // `life_counter_page._openPlayerDrawer` les branche bien sur les vrais
  // notifiers/service, pas sur rien.

  testWidgets(
      'décision 2 : créer un compteur depuis le tiroir l\'active '
      'IMMÉDIATEMENT dans la partie en cours', (tester) async {
    final container = await pumpWithContainer(tester);

    await openDrawerForPlayerZero(tester);
    await tester.tap(find.byKey(const ValueKey('action-create-counter')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')), 'Bouclier');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')), '🛡️');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('counter_editor_submit')));
    await tester.pumpAndSettle();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.activeCounterIds, contains('bouclier'),
        reason: 'un compteur créé doit être actif tout de suite, pas '
            'seulement enregistré dans le catalogue -- on le crée parce '
            'qu\'on en a besoin maintenant');
    expect(session.customCounterIds, contains('bouclier'));
    // La nouvelle ligne est visible dans le MÊME tiroir, sans le rouvrir.
    expect(find.byKey(const ValueKey('counter_row_bouclier')), findsOneWidget);
  });

  testWidgets(
      'le compteur créé est bien PERSISTÉ : un nouveau CounterTypeService '
      '(pas le notifier déjà chargé) le retrouve', (tester) async {
    await pumpWithContainer(tester);

    await openDrawerForPlayerZero(tester);
    await tester.tap(find.byKey(const ValueKey('action-create-counter')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')), 'Bouclier');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')), '🛡️');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('counter_editor_submit')));
    await tester.pumpAndSettle();

    // Un service TOUT NEUF, qui n'a jamais vu le notifier de ce test :
    // preuve que la sauvegarde a bien atteint SharedPreferences, pas
    // seulement l'état en mémoire de counterCatalogProvider.
    final freshTypes = await CounterTypeService().loadCustomTypes();
    expect(freshTypes.map((t) => t.id), contains('bouclier'));
  });

  testWidgets(
      'un refus de création (nom "Poison", usurpant l\'intégré) affiche le '
      'message ET ne change ni activeCounterIds ni customCounterIds',
      (tester) async {
    final container = await pumpWithContainer(tester);
    final before = container.read(gameSessionNotifierProvider)!;
    final activeBefore = List<String>.from(before.activeCounterIds);
    final customBefore = List<String>.from(before.customCounterIds);

    await openDrawerForPlayerZero(tester);
    await tester.tap(find.byKey(const ValueKey('action-create-counter')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')), 'Poison');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')), '☠️');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('counter_editor_submit')));
    await tester.pumpAndSettle();

    // Revue finale (I1) : le message doit être accentué, comme le reste de
    // l'écran ("Réinitialiser les compteurs", "Éliminer"), et ne plus
    // contenir le jargon "usurper l'id" -- il n'y a pas de champ id dans ce
    // dialogue, et ce mot ne dit pas au joueur quoi faire.
    expect(
        find.text(
            'Impossible de créer ce compteur : Ce nom est déjà utilisé '
            'par un compteur intégré. Choisissez-en un autre.'),
        findsOneWidget,
        reason: 'CounterCatalogNotifier.saveCustomType refuse cet id -- son '
            'message doit être affiché, jamais avalé silencieusement, '
            'accentué et compréhensible par un joueur');
    expect(find.textContaining('usurper'), findsNothing);
    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.activeCounterIds, activeBefore);
    expect(session.customCounterIds, customBefore);
  });

  testWidgets(
      'retirer un compteur intégré (poison) des actifs depuis le tiroir '
      'atteint réellement la session (activeCounterIds), tout en gardant '
      'la valeur du joueur', (tester) async {
    final container = await pumpWithContainer(tester);
    container
        .read(gameSessionNotifierProvider.notifier)
        .updateCounter(0, 'poison', 3);

    await openDrawerForPlayerZero(tester);
    await tester.tap(find.byKey(const ValueKey('counter_row_poison_remove')));
    await tester.pump();

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.activeCounterIds, isNot(contains('poison')));
    expect(session.players[0].counters['poison'], 3,
        reason: 'décision 1 : la valeur survit au retrait des actifs');
  });

  // --- Ronde de correction 1 (Critical) : la poignée et l'historique ne
  // racontaient pas la même partie. `_toLegacyPlayer` filtrait `counters`
  // (générique) par `activeCounterIds`, mais lisait `poison`/`energy`/
  // `commanderCastCount` DIRECTEMENT dans `ps.counters`, sans ce filtre --
  // un compteur désactivé (`deactivateCounter`, introduit par cette même
  // tâche) redevenait donc visible dans `PlayerHistorySnapshot` alors que
  // la poignée ne le montrait plus depuis son retrait.
  testWidgets(
      'un compteur legacy (poison) désactivé compte 0 pour '
      '_finalizeGameSave, comme pour la poignée -- l\'historique ne doit '
      'pas raconter une autre partie que ce que le joueur voit à l\'écran',
      (tester) async {
    final container = await pumpWithContainer(tester);
    container
        .read(gameSessionNotifierProvider.notifier)
        .updateCounter(0, 'poison', 3);
    await tester.pump();

    // Avant retrait : la poignée affiche bien 3 -- valeur NON NULLE, sinon
    // ce test ne distinguerait pas "conservée mais filtrée à l'affichage"
    // de "jamais écrite".
    // Repéré par identité (`_playerZone(0)`), jamais par `.first` : depuis
    // la table v2, l'ordre des zones dans l'arbre suit
    // `tableLayoutFor`/`seatsFor` et non l'ordre canonique -- `.first`
    // lisait la poignée d'un joueur SANS poison, ce qui faisait échouer la
    // précondition ci-dessous et, pire, aurait rendu l'assertion `isEmpty`
    // d'après retrait vraie sans rien prouver.
    final beforeHandle = tester.widget<ConditionalHandle>(
      find.descendant(
        of: _playerZone(0),
        matching: find.byType(ConditionalHandle),
      ),
    );
    expect(
      beforeHandle.summary.counters
          .firstWhere((e) => e.key.id == 'poison')
          .value,
      3,
    );

    await openDrawerForPlayerZero(tester);
    await tester.tap(find.byKey(const ValueKey('counter_row_poison_remove')));
    await tester.pump();
    // Ferme le tiroir (tap en dehors du sheet) avant de continuer.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Après retrait : la poignée ne montre plus AUCUNE entrée 'poison'.
    final afterHandle = tester.widget<ConditionalHandle>(
      find.descendant(
        of: _playerZone(0),
        matching: find.byType(ConditionalHandle),
      ),
    );
    expect(
      afterHandle.summary.counters.where((e) => e.key.id == 'poison'),
      isEmpty,
      reason: 'précondition : la poignée doit déjà avoir cessé d\'afficher '
          'poison après son retrait des actifs',
    );

    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    await (state as dynamic).finalizeGameSaveForTest(0, 'normal');
    await tester.pumpAndSettle();

    final history = await GameHistoryService().loadHistory();
    expect(history, isNotEmpty);
    expect(
      history.first.playerStates[0].poison,
      0,
      reason: 'l\'historique doit dire la même chose que la poignée : un '
          'compteur retiré des actifs compte 0 pour TOUS les '
          'consommateurs, y compris PlayerHistorySnapshot -- pas la '
          'valeur brute encore portée par PlayerState.counters (décision '
          '1 : conservée pour une réactivation, jamais pour '
          'l\'historique)',
    );
  });

  // --- Revue finale, Critical 1 : `_getDeathReason` lisait
  // `player.counters['poison']` directement, sans le filtre
  // `activeCounterIds` -- la même asymétrie de lecture corrigée en tâche 4
  // sur `_toLegacyPlayer`, à un troisième site que cette ronde n'avait pas
  // couvert.

  testWidgets(
      'Critical 1 : un poison RETIRÉ des actifs ne tue plus le joueur après '
      'un tap de vie ordinaire', (tester) async {
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    final players = [...baseSession.players];
    // Valeur au-delà du seuil létal (maxPoison par défaut : 10) -- sans
    // quoi ce test ne distinguerait pas "le poison ne tue plus parce qu'il
    // est retiré" de "le poison ne tue plus parce qu'il n'atteint pas le
    // seuil".
    players[0] = players[0].copyWith(counters: {'poison': 10});
    final session = baseSession.copyWith(
      players: players,
      // Poison RETIRÉ des actifs -- décision 1 : la valeur (10) reste dans
      // PlayerState.counters, seule son appartenance à activeCounterIds
      // change.
      activeCounterIds:
          baseSession.activeCounterIds.where((id) => id != 'poison').toList(),
    );

    await pumpWithContainer(tester, snapshot: session);

    // Un tap de vie ORDINAIRE (pas sur le compteur poison) -- exactement le
    // scénario rapporté : le joueur ne touche plus jamais à un compteur
    // qu'il ne voit plus nulle part.
    await tapMinusHalf(tester, 0, 1);
    // Laisse le buffer de dégâts s'appliquer (fenêtre de 2 s) : bornés,
    // jamais `pumpAndSettle` -- si ce test échouait faute de correctif, la
    // zone entrerait en overlay de confirmation de mort, dont les boutons
    // n'ont aucune animation bouclée, mais on reste sur le même principe
    // que le reste de ce fichier.
    await tester.pump(const Duration(seconds: 2));
    // Laisse le minuteur de confirmation de mort (2 s de plus) se
    // déclencher s'il devait l'être.
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(DeathConfirmationOverlay), findsNothing,
        reason: 'un compteur qui n\'existe plus dans la partie (retiré des '
            'actifs) ne doit jamais pouvoir déclencher une mort -- la '
            'valeur conservée dans PlayerState.counters n\'est pas '
            'consultable par le joueur, qui ne peut pas la corriger');
    expect(find.textContaining('Poison'), findsNothing);
  });

  // Le pendant du test ci-dessus, et il vaut plus que lui. La re-revue a
  // muté `_getDeathReason` en `final poison = 0;` -- soit la mort par poison
  // purement et simplement supprimée -- et la suite entière est restée verte
  // à 1031/1031. Aucun test ne couvrait le cas nominal : le test de Critical
  // 1 ne verrouille qu'un `findsNothing`, exactement la moitié qui ne coûte
  // rien à un filtre trop large. Sans ce test, la prochaine main qui touche
  // à cette fonction peut tuer la détection d'élimination sans qu'un seul
  // voyant s'allume.
  testWidgets(
      'Critical 1, sens inverse : un poison ACTIF au seuil létal déclenche '
      'toujours l\'élimination', (tester) async {
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    final players = [...baseSession.players];
    players[0] = players[0].copyWith(counters: {'poison': 10});
    // Seule différence avec le test précédent : `poison` reste dans les
    // actifs. Même valeur, même geste, même attente.
    final session = baseSession.copyWith(players: players);

    await pumpWithContainer(tester, snapshot: session);

    await tapMinusHalf(tester, 0, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(DeathConfirmationOverlay), findsOneWidget,
        reason: 'le filtre par activeCounterIds corrige une lecture, il ne '
            'doit pas supprimer la détection : un joueur qui atteint le '
            'seuil de poison avec le compteur actif doit toujours se voir '
            'proposer l\'élimination');
  });

  // --- Revue finale, Critical 2 : `_resetPlayerCounters` itérait sur une
  // liste écrite à la main (`['poison', 'energy', 'commander_tax']`), pas
  // sur `activeCounterIds` -- un compteur personnalisé actif survivait donc
  // à "Réinitialiser les compteurs".

  testWidgets(
      'Critical 2 : "Réinitialiser les compteurs" remet aussi à zéro un '
      'compteur personnalisé actif, pas seulement les trois intégrés '
      'historiques', (tester) async {
    const rage = CounterType(
      id: 'rage',
      name: 'Rage',
      emoji: '🔥',
      color: 0xFFFF5722,
      isBuiltIn: false,
    );
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
      extraCounterIds: ['rage'],
    );
    final players = [...baseSession.players];
    players[0] = players[0].copyWith(counters: {'rage': 3, 'poison': 4});
    final session = baseSession.copyWith(players: players);

    final container = await pumpWithContainer(
      tester,
      snapshot: session,
      extraPrefs: {'custom_counter_types': json.encode([rage.toJson()])},
    );

    await openDrawerForPlayerZero(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('action-reset')));
    await tester.tap(find.byKey(const ValueKey('action-reset')));
    await tester.pump();

    final updated =
        container.read(gameSessionNotifierProvider)!.players[0].counters;
    expect(updated['poison'], 0);
    expect(updated['rage'], 0,
        reason: '"Réinitialiser les compteurs" doit remettre à zéro TOUS '
            'les compteurs actifs de la session, personnalisés compris -- '
            'pas seulement les trois intégrés historiques codés en dur '
            '(exactement la liste figée que ce lot existe pour supprimer)');
  });

  // --- Revue finale, Critical 3 : un compteur personnalisé créé est
  // écrit dans le catalogue (`custom_counter_types`) mais AUCUNE interface
  // ne permet de l'activer une seconde fois -- il n'est utilisable que
  // pendant la partie où il a été créé, jamais après. Ce test simule
  // exactement ça : le catalogue porte déjà "Rage" (comme l'aurait laissé
  // une partie précédente), mais la SESSION COURANTE (une partie neuve,
  // `GameSession.newGame` sans `extraCounterIds`) ne l'a jamais activé.
  testWidgets(
      'Critical 3 : un compteur du catalogue, inactif dans la partie '
      'courante, est réactivable depuis le tiroir -- récupérable dans la '
      'partie suivante, pas seulement dans celle où il a été créé',
      (tester) async {
    const rage = CounterType(
      id: 'rage',
      name: 'Rage',
      emoji: '🔥',
      color: 0xFFFF5722,
      isBuiltIn: false,
    );
    // Partie neuve : `GameSession.newGame` SANS `extraCounterIds` --
    // `rage` n'est ni dans `activeCounterIds` ni dans `customCounterIds`,
    // exactement l'état d'une partie qui n'a jamais vu ce compteur.
    final session = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: testConfigs,
    );
    expect(session.activeCounterIds, isNot(contains('rage')),
        reason: 'précondition : la partie ne doit PAS déjà connaître Rage, '
            'sans quoi ce test ne prouverait rien sur la réactivation');

    final container = await pumpWithContainer(
      tester,
      snapshot: session,
      // Simule le catalogue persisté par une partie ANTÉRIEURE : c'est la
      // seule trace qui doit survivre entre deux parties (décision D-1 de
      // la spec), la session elle-même reparaît neuve.
      extraPrefs: {'custom_counter_types': json.encode([rage.toJson()])},
    );

    await openDrawerForPlayerZero(tester);

    expect(find.byKey(const ValueKey('counter_reactivate_rage')),
        findsOneWidget,
        reason: 'un compteur du catalogue non actif dans CETTE partie doit '
            'être proposé pour réactivation -- sinon le catalogue '
            'persistant est écrit et jamais relu par personne');

    await tester.ensureVisible(
        find.byKey(const ValueKey('counter_reactivate_rage')));
    await tester.tap(find.byKey(const ValueKey('counter_reactivate_rage')));
    await tester.pump();

    final restoredSession = container.read(gameSessionNotifierProvider)!;
    expect(restoredSession.activeCounterIds, contains('rage'),
        reason: 'réactiver depuis le tiroir doit atteindre réellement la '
            'session, pas seulement l\'affichage local du tiroir');
    expect(restoredSession.customCounterIds, contains('rage'),
        reason: 'un compteur réactivé reste identifié comme personnalisé '
            '(isCustom déduit de !type.isBuiltIn, pas d\'un défaut à '
            'false qui le ferait passer pour un intégré)');
    // La ligne apparaît dans CE tiroir déjà ouvert, sans avoir à le
    // refermer et le rouvrir (même principe que la création, tâche 4).
    expect(find.byKey(const ValueKey('counter_row_rage')), findsOneWidget);
    expect(find.byKey(const ValueKey('counter_reactivate_rage')),
        findsNothing,
        reason: 'un compteur réactivé ne doit plus apparaître dans la '
            'liste des compteurs à réactiver');
  });

  // --- Ronde de correction 4 : LE test qui manquait. Tous les tests du geste
  // d'ajustement (life_dial_test.dart) montaient un harnais minimal — un
  // parent jouet avec un `setState` — jamais la PAGE RÉELLE avec sa grille.
  // Sur `LifeCounterPage`, chaque delta émis par la molette passe par
  // `onLifeChanged` -> `_updateLife` -> `setState()` de toute la page, ce qui
  // reconstruit les quatre zones. Le geste complet (appui long, glissé
  // descendant EN PLUSIEURS incréments avec un `pump()` par pas — c'est-à-dire
  // avec un vrai rendu entre chaque événement, comme sur un appareil —, puis
  // relâchement sur un palier) n'était donc joué nulle part là où cette
  // cascade de rebuilds existe. Il ne marchait pas.
  testWidgets(
      'sur la page réelle à 4 joueurs, un appui long puis un glissé descendant '
      'en plusieurs incréments vers le palier "-5", relâché dessus, retire '
      'exactement 5 PV', (tester) async {
    final container = await pumpWithContainer(tester);

    // Repérage par identité (voir `_playerZone`), jamais ordinal.
    Finder dial() => find.descendant(
          of: _playerZone(0),
          matching: find.byType(LifeDial),
        );
    Finder stepMinus5() => find.descendant(
          of: dial(),
          matching: find.byKey(const ValueKey('life_step_-5')),
        );

    final lifeBefore = container.read(gameSessionNotifierProvider)!
        .players
        .firstWhere((p) => p.playerId == 0)
        .life;

    // Appui long au centre du cadran : entrée en mode ajustement.
    final gesture = await tester.startGesture(tester.getCenter(dial()));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(stepMinus5(), findsOneWidget,
        reason: 'précondition : l\'appui long doit avoir ouvert les paliers');

    // Glissé DESCENDANT réaliste vers le palier, en 10 incréments, avec un
    // rendu entre chaque : la rangée est ancrée en bas, donc le trajet
    // traverse la molette et déclenche la cascade de `setState` de la page.
    final start = tester.getCenter(dial());
    final target = tester.getCenter(stepMinus5());
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(start, target, i / 10)!);
      await tester.pump();
    }

    await gesture.up();
    await tester.pump();

    // Laisse le buffer de 2 s s'appliquer.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final after = container.read(gameSessionNotifierProvider)!
        .players
        .firstWhere((p) => p.playerId == 0)
        .life;
    expect(after, lifeBefore - 5,
        reason: 'le palier relâché doit être le SEUL effet net du geste, '
            'molette traversée en route comprise');
  });

  // --- Revue finale, Critical #2 : LE test qui manquait ENCORE. Le test
  // ci-dessus part de 40 PV en format Commander : la descente de 5 points
  // reste entièrement au-dessus du seuil `safe` (ratio > 0.50, soit > 20 PV),
  // donc `CriticalOverlay` ne change jamais de branche pendant le geste et le
  // défaut restait invisible.
  //
  // `CriticalOverlay` et `EliminationOverlay` portaient le MÊME motif
  // d'enveloppement conditionnel que la ronde 4 avait retiré de la page :
  // `if (safe) return child;` d'un côté, `AnimatedBuilder(...)` de l'autre.
  // Franchir un seuil en plein geste change donc la profondeur de l'arbre,
  // Flutter détruit le sous-arbre, et le `State` de `LifeDial` est recréé
  // avec le doigt encore posé.
  //
  // Mesuré avant correctif, même geste, seule la vie de départ change :
  // 40 -> 35 (attendu 35), 21 -> 20 (attendu 16), 11 -> 6 (attendu 6). La
  // ligne 11 prouve le mécanisme : `warning -> danger` ne change pas la
  // profondeur, le geste survit ; `safe -> warning` la change, il meurt.
  //
  // Les trois vies de départ sont donc jouées, pas seulement celle qui
  // franchit : le test dirait autrement « le geste marche à 21 » sans dire
  // pourquoi il marchait déjà ailleurs.
  for (final startLife in const [40, 21, 11]) {
    testWidgets(
        'sur la page réelle, un glissé vers "-5" depuis $startLife PV retire '
        'exactement 5 PV — y compris quand la descente franchit un seuil '
        'critique (Critical #2)', (tester) async {
      final baseSession = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: testConfigs,
      );
      final seeded = baseSession.copyWith(
        players: [
          baseSession.players[0].copyWith(life: startLife),
          ...baseSession.players.sublist(1),
        ],
      );
      // Montage à pompage BORNÉ plutôt que `pumpWithContainer` : à 11 PV la
      // zone est déjà au cran `danger` au chargement, donc la bordure pulse
      // en boucle et le `pumpAndSettle` de ce helper ne rendrait jamais la
      // main.
      SharedPreferences.setMockInitialValues({
        'active_game_snapshot': json.encode(seeded.toJson()),
      });
      final container = ProviderContainer(
        overrides: [
          gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      Finder dial() => find.descendant(
            of: _playerZone(0),
            matching: find.byType(LifeDial),
          );
      Finder stepMinus5() => find.descendant(
            of: dial(),
            matching: find.byKey(const ValueKey('life_step_-5')),
          );

      final gesture = await tester.startGesture(tester.getCenter(dial()));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(stepMinus5(), findsOneWidget,
          reason: 'précondition : l’appui long doit avoir ouvert les paliers');

      final start = tester.getCenter(dial());
      final target = tester.getCenter(stepMinus5());
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(start, target, i / 10)!);
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      // Pompage BORNÉ, pas `pumpAndSettle` : sous le seuil `safe`, la bordure
      // de `CriticalOverlay` pulse en boucle infinie (`_controller.repeat()`),
      // et `pumpAndSettle` ne rendrait jamais la main pour les vies de départ
      // qui franchissent justement le seuil que ce test existe pour éprouver.
      await tester.pump(const Duration(seconds: 3));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final after = container.read(gameSessionNotifierProvider)!
          .players
          .firstWhere((p) => p.playerId == 0)
          .life;
      expect(after, startLife - 5,
          reason: 'le geste ne doit pas mourir parce que la zone a changé de '
              'niveau critique pendant la descente');
    });
  }

  // --- Ronde de correction 1 de la tâche 4 (Critical #1) : les presets
  // d'orientation posent des `quarterTurns` finaux, SANS compensation.
  // Avant ce correctif, `_applyOrientationPreset` retranchait 2 quarts de
  // tour aux zones de la moitié haute pour compenser la rotation que
  // l'ANCIENNE `AdaptiveGrid` leur appliquait elle-même -- une compensation
  // devenue fausse dès que la tâche 4 a retiré cette rotation :
  // 180° − 180° = 0°, le défaut symétrique de celui que la tâche 4 interdit
  // (180° + 180° = 360°). Aucun test ne couvrait les presets avant ce
  // correctif (`grep -rn "OrientationPreset" test/` ne renvoyait rien).
  const orientationScreenSize = Size(900, 700);

  /// Écran assez large pour que `AdaptiveGrid` choisisse la bande (voir
  /// `TableLayout`) : le bouton d'ouverture de la feuille de presets vit
  /// dans `_buildCentralBar`, absent sur petit écran (hub à la place).
  Future<ProviderContainer> pumpForOrientation(
    WidgetTester tester,
    int playerCount,
  ) async {
    _setScreenSize(tester, orientationScreenSize);
    final baseSession = GameSession.newGame(
      format: commanderFormat,
      playerConfigs: playerConfigsFor(playerCount),
    );
    return pumpWithContainer(tester, snapshot: baseSession);
  }

  Future<void> expectPresetRotations(
    WidgetTester tester,
    ProviderContainer container,
    String label,
    List<int> expectedRotations,
  ) async {
    await openOrientationSheet(tester);
    await selectOrientationPreset(tester, label);

    final session = container.read(gameSessionNotifierProvider)!;
    for (int playerId = 0; playerId < expectedRotations.length; playerId++) {
      final player = session.players.firstWhere((p) => p.playerId == playerId);
      expect(
        player.quarterTurns,
        expectedRotations[playerId],
        reason: 'preset "$label", joueur $playerId (ordre canonique) : '
            'quarterTurns final attendu ${expectedRotations[playerId]}, '
            'posé tel quel, sans compensation',
      );
    }
  }

  // Revue finale, Critical #3 (ruling 20) : les presets sont TOUS dérivés de
  // la géométrie. Les valeurs attendues ci-dessous sont donc celles que la
  // grille rend RÉELLEMENT à `Size(900, 700)`, l'écran de ces tests :
  //
  //   n=2 : [top, bottom]                              -> [2, 0]
  //   n=3 : [top, bottom, bottom]                      -> [2, 0, 0]
  //   n=4 : [top, right, bottom, left]                 -> [2, 3, 0, 1]
  //   n=5 : [top, top, right, bottom, left]            -> [2, 2, 3, 0, 1]
  //   n=6 : [top, top, right, bottom, bottom, left]    -> [2, 2, 3, 0, 0, 1]
  //   n=7 : repli face-à-face (playerCount > 6)        -> [2,2,2,0,0,0,0]
  //
  // Les listes en dur de 2 à 6 joueurs disaient [2,2,0,0] à quatre : AUCUN des
  // cinq presets ne produisait l'orientation juste, et l'aperçu — qui lit déjà
  // la vraie géométrie — dessinait honnêtement le résultat faux.
  //
  // « Côtés », « Triangle » et « Cercle » ont disparu : ils ne décrivaient
  // aucune disposition de sièges. « Face à face » n'est proposé que là où il
  // DIFFÈRE de « Table », donc à 4, 5 et 6 joueurs sur cet écran — les deux
  // tests d'absence ci-dessous verrouillent cette règle.
  group('presets d\'orientation (revue finale — dérivés de la géométrie)', () {
    testWidgets('4 joueurs — "Table" pose la géométrie réelle [2,3,0,1]',
        (tester) async {
      final container = await pumpForOrientation(tester, 4);
      await expectPresetRotations(tester, container, 'Table', [2, 3, 0, 1]);
    });

    testWidgets('4 joueurs — "Face à face" pose le repli [2,2,0,0]',
        (tester) async {
      final container = await pumpForOrientation(tester, 4);
      await expectPresetRotations(
          tester, container, 'Face à face', [2, 2, 0, 0]);
    });

    testWidgets('4 joueurs — "Même sens" pose [0,0,0,0]', (tester) async {
      final container = await pumpForOrientation(tester, 4);
      await expectPresetRotations(tester, container, 'Même sens', [0, 0, 0, 0]);
    });

    testWidgets(
        '4 joueurs — les presets qui ne décrivaient aucune disposition de '
        'sièges ont disparu', (tester) async {
      await pumpForOrientation(tester, 4);
      await openOrientationSheet(tester);
      for (final label in const ['Côtés', 'Cercle', 'Triangle']) {
        expect(find.text(label), findsNothing,
            reason: '"$label" ne correspond à aucune géométrie de sièges et ne '
                'peut donc pas être dérivé honnêtement');
      }
    });

    testWidgets('2 joueurs — "Table" pose [2,0]', (tester) async {
      final container = await pumpForOrientation(tester, 2);
      await expectPresetRotations(tester, container, 'Table', [2, 0]);
    });

    testWidgets('2 joueurs — "Côte à côte" pose [1,3]', (tester) async {
      final container = await pumpForOrientation(tester, 2);
      await expectPresetRotations(tester, container, 'Côte à côte', [1, 3]);
    });

    testWidgets(
        '2 joueurs — "Face à face" n\'est pas proposé : il ne diffère pas '
        'de "Table"', (tester) async {
      await pumpForOrientation(tester, 2);
      await openOrientationSheet(tester);
      expect(find.text('Face à face'), findsNothing);
      expect(find.text('Table'), findsOneWidget);
    });

    testWidgets('3 joueurs — "Table" pose [2,0,0]', (tester) async {
      final container = await pumpForOrientation(tester, 3);
      await expectPresetRotations(tester, container, 'Table', [2, 0, 0]);
    });

    testWidgets('5 joueurs — "Table" pose la géométrie réelle [2,2,3,0,1]',
        (tester) async {
      final container = await pumpForOrientation(tester, 5);
      await expectPresetRotations(
          tester, container, 'Table', [2, 2, 3, 0, 1]);
    });

    testWidgets('5 joueurs — "Face à face" pose le repli [2,2,0,0,0]',
        (tester) async {
      final container = await pumpForOrientation(tester, 5);
      await expectPresetRotations(
          tester, container, 'Face à face', [2, 2, 0, 0, 0]);
    });

    testWidgets('6 joueurs — "Table" pose la géométrie réelle [2,2,3,0,0,1]',
        (tester) async {
      final container = await pumpForOrientation(tester, 6);
      await expectPresetRotations(
          tester, container, 'Table', [2, 2, 3, 0, 0, 1]);
    });

    testWidgets(
        '7 joueurs — "Table" pose le repli géométrique [2,2,2,0,0,0,0] : le '
        'siège réel de chacun, jamais un topCount supposé', (tester) async {
      final container = await pumpForOrientation(tester, 7);
      // `seatsFor` retombe toujours en face-à-face au-delà de 6 joueurs, donc
      // « Table » et le repli coïncident et un seul preset est proposé.
      await expectPresetRotations(
          tester, container, 'Table', [2, 2, 2, 0, 0, 0, 0]);
    });
  });

  // --- Ronde de correction 3 (tâche 5) : `tapMinusHalf` sait depuis la
  // ronde 1 calculer son point de tap pour les quatre valeurs de
  // `quarterTurns` (0/1/2/3, voir sa docstring et `_quarterTurnsAbove`),
  // mais tous les appels existants du fichier portent sur des sessions à
  // `quarterTurns == 0` (le défaut de `GameSession.newGame`) : les branches
  // 1 et 3 de la table n'étaient donc exercées par AUCUN test -- seule
  // l'algèbre avait été relue, pas la couverture. Les deux tests
  // ci-dessous posent explicitement la rotation AVANT de taper, pour que
  // `_quarterTurnsAbove` retourne réellement 1 puis 3.
  group('tapMinusHalf couvre les quatre quarterTurns (ronde de correction 3)',
      () {
    testWidgets(
        'quarterTurns == 1 (siège "left") : le tap sur la moitié '
        'décrément (dy inférieur) baisse la vie de 1', (tester) async {
      final baseSession = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: testConfigs,
      );
      final rotated = baseSession.copyWith(
        players: [
          baseSession.players[0].copyWith(quarterTurns: 1),
          ...baseSession.players.sublist(1),
        ],
      );
      final container = await pumpWithContainer(tester, snapshot: rotated);

      await tapMinusHalf(tester, 0, 1);
      // Laisse le buffer de 2s s'appliquer, comme les autres tests de PV.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(container.read(gameSessionNotifierProvider)!.players[0].life, 39,
          reason: 'un tap sur la moitié décrément doit baisser la vie de 1, '
              'même à quarterTurns == 1 : sans une table à quatre branches '
              'réellement exercées, ce point de tap pouvait tomber sur la '
              'mauvaise moitié (incrément) et faire monter la vie au lieu '
              'de la baisser');
    });

    testWidgets(
        'quarterTurns == 3 (siège "right") : le tap sur la moitié '
        'décrément (dy supérieur) baisse la vie de 1', (tester) async {
      final baseSession = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: testConfigs,
      );
      final rotated = baseSession.copyWith(
        players: [
          baseSession.players[0].copyWith(quarterTurns: 3),
          ...baseSession.players.sublist(1),
        ],
      );
      final container = await pumpWithContainer(tester, snapshot: rotated);

      await tapMinusHalf(tester, 0, 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(container.read(gameSessionNotifierProvider)!.players[0].life, 39,
          reason: 'même exigence qu\'à quarterTurns == 1, pour la moitié '
              'symétrique (dy supérieur)');
    });
  });
}
