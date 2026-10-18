// test/pages/life_counter/reorganise_mode_page_test.dart
//
// Tâche 8a (spec §1.7, §1.9, §6.1) : le mode réorganisation sur la VRAIE
// page, pas sur des widgets isolés. Trois promesses :
// - le geste de vie est inopérant dans le mode, et opérant dès qu'on en sort
//   (§6.1, mot pour mot) ;
// - une flèche ne tourne QUE le joueur de sa zone, adressé par `playerId`,
//   y compris après un réordonnancement où l'index d'affichage ne désigne
//   plus le même joueur ;
// - un preset touché dans la barre applique réellement ses rotations.
//
// Même harnais que reorder_rotation_test.dart : snapshot à 4 joueurs, écran
// 900×700 (la bande, donc le bouton du mode, y est visible).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/pages/life_counter/life_counter_page.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:magic_companion/widgets/life_counter/reorganise_bar.dart';
import 'package:magic_companion/widgets/life_counter/tuning.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';
import 'package:magic_companion/widgets/life_counter/zone/orientation_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _commanderFormat =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

final _testConfigs = [
  const PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
  const PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
  const PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
  const PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
];

/// La zone du joueur [playerId], par sa clé d'identité -- jamais par
/// position dans l'arbre (voir reorder_rotation_test.dart).
Finder _playerZone(int playerId) =>
    find.byKey(ValueKey('player_zone_$playerId'));

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

Future<ProviderContainer> _pumpFourPlayerTable(WidgetTester tester) async {
  _setScreenSize(tester, const Size(900, 700));
  final session = GameSession.newGame(
    format: _commanderFormat,
    playerConfigs: _testConfigs,
  );
  SharedPreferences.setMockInitialValues({
    'active_game_snapshot': json.encode(session.toJson()),
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

/// Entre en mode réorganisation par l'unique entrée : l'action `edit-mode`.
Future<void> _enterReorganise(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('action-edit-mode')));
  await tester.pumpAndSettle();
  expect(find.byType(ReorganiseBar), findsOneWidget,
      reason: 'précondition : le mode est bien actif');
}

/// Sort du mode par « Terminé », dans la barre.
Future<void> _tapDone(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('reorganise-done')));
  await tester.pumpAndSettle();
}

int _lifeOf(ProviderContainer container, int playerId) => container
    .read(gameSessionNotifierProvider)!
    .players
    .firstWhere((p) => p.playerId == playerId)
    .life;

List<int> _turnsByCanonicalId(ProviderContainer container) {
  final session = container.read(gameSessionNotifierProvider)!;
  return [
    for (int id = 0; id < session.players.length; id++)
      session.players.firstWhere((p) => p.playerId == id).quarterTurns,
  ];
}

/// Le point « + » du cadran du joueur [playerId] : moitié droite, à
/// mi-hauteur (zone non pivotée -- même repérage que life_counter_page_test).
Offset _plusPoint(WidgetTester tester, int playerId) {
  final dial = tester.getRect(find.descendant(
    of: _playerZone(playerId),
    matching: find.byType(LifeDial),
  ));
  return Offset(dial.left + dial.width * 0.75, dial.center.dy);
}

/// Laisse la fenêtre de regroupement se refermer : la vie n'atteint la
/// session qu'à son terme.
Future<void> _flushBuffer(WidgetTester tester) async {
  await tester.pump(kDamageBufferWindow + const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'en mode réorganisation, un appui sur la moitié « + » ne change pas la '
      'vie ; après « Terminé », le même appui la change (spec §6.1)',
      (tester) async {
    final container = await _pumpFourPlayerTable(tester);
    // Joueur 2 (Sarah) : zone du bas, non pivotée à cet écran.
    final before = _lifeOf(container, 2);

    await _enterReorganise(tester);
    final plus = _plusPoint(tester, 2);
    // Précondition : le point visé n'est PAS sur le sélecteur d'orientation
    // -- sinon une absence de changement de vie ne prouverait rien du voile.
    final picker = tester.getRect(find.descendant(
      of: _playerZone(2),
      matching: find.byType(OrientationPicker),
    ));
    expect(picker.contains(plus), isFalse,
        reason: 'précondition : le « + » visé est hors du sélecteur');

    await tester.tapAt(plus);
    await tester.pump();
    await _flushBuffer(tester);
    expect(_lifeOf(container, 2), before,
        reason: 'le geste de vie est suspendu en mode réorganisation');

    await _tapDone(tester);
    expect(find.byType(ReorganiseBar), findsNothing);
    expect(find.byType(OrientationPicker), findsNothing,
        reason: 'hors mode, les zones sont rendues nues');

    await tester.tapAt(_plusPoint(tester, 2));
    await tester.pump();
    await _flushBuffer(tester);
    expect(_lifeOf(container, 2), before + 1,
        reason: 'dès la sortie du mode, le geste de vie répond de nouveau');
  });

  testWidgets(
      'une flèche tourne le joueur de SA zone et aucun autre, même après un '
      'réordonnancement', (tester) async {
    final container = await _pumpFourPlayerTable(tester);
    await _enterReorganise(tester);

    // Échange les positions d'affichage 0 et 3 (même geste que
    // reorder_rotation_test.dart) : l'index d'affichage 0 désigne désormais
    // le joueur 3. Une flèche adressée par index d'affichage tournerait donc
    // le joueur 0 au lieu du 3.
    final start = tester.getCenter(_playerZone(0));
    final end = tester.getCenter(_playerZone(3));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(gameSessionNotifierProvider)!.playerOrder,
        [3, 1, 2, 0],
        reason: 'précondition : l\'ordre d\'affichage n\'est plus l\'identité');

    final before = _turnsByCanonicalId(container);
    expect(before[3], isNot(1),
        reason: 'précondition : ◀ doit réellement changer le joueur 3');

    await tester.tap(find.descendant(
      of: _playerZone(3),
      matching: find.byKey(const ValueKey('orientation-arrow-1')),
    ));
    await tester.pumpAndSettle();

    final after = _turnsByCanonicalId(container);
    expect(after[3], 1, reason: 'le joueur 3 regarde désormais vers ◀');
    for (final id in const [0, 1, 2]) {
      expect(after[id], before[id], reason: 'joueur $id, non touché');
    }
    expect(
      container
          .read(gameSessionNotifierProvider)!
          .players
          .firstWhere((p) => p.playerId == 3)
          .manualRotation,
      isTrue,
      reason: 'un angle choisi à la flèche est manuel : aucun semis '
          'ultérieur (pliage) ne doit l\'écraser',
    );
  });

  testWidgets(
      'un preset touché dans la barre applique ses rotations '
      '(« Table » puis « Même sens »)', (tester) async {
    final container = await _pumpFourPlayerTable(tester);
    await _enterReorganise(tester);

    // Le snapshot démarre tout à 0 : « Même sens » seul ne prouverait rien.
    // « Table » d'abord (géométrie réelle à cet écran : [2,2,0,0], voir
    // life_counter_page_test.dart), puis « Même sens ».
    await tester.tap(find.byKey(const ValueKey('reorganise-preset-Table')));
    await tester.pumpAndSettle();
    expect(_turnsByCanonicalId(container), [2, 2, 0, 0]);

    await tester
        .tap(find.byKey(const ValueKey('reorganise-preset-Même sens')));
    await tester.pumpAndSettle();
    expect(_turnsByCanonicalId(container), [0, 0, 0, 0]);
    expect(find.byType(ReorganiseBar), findsOneWidget,
        reason: 'un preset ne fait pas sortir du mode : seul « Terminé » '
            'le fait');
  });
}
