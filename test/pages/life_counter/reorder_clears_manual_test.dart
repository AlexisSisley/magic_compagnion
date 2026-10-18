// test/pages/life_counter/reorder_clears_manual_test.dart
//
// Ruling 29 (révision du ruling 28, lui-même révision de la tâche 4) :
// `_onReorderPlayers` appelle désormais `updateRotation(..., manual: false)`
// pour les deux zones qu'un glisser-déposer déplace -- la rotation posée
// n'est que le défaut du nouveau siège, pas un angle choisi, et l'appel
// EFFACE aussi un éventuel marquage manuel antérieur (une zone qui change de
// place perd la pertinence de son ancien réglage, qui décrivait son
// ANCIENNE place).
//
// Ce fichier verrouille les DEUX moitiés que le ruling demande :
// 1. Après un reorder, les deux zones déplacées redeviennent sensibles au
//    semis automatique -- un pliage qui suit les réoriente.
// 2. Une zone réglée à la main qui n'a PAS été déplacée garde son angle à
//    travers ce même réordonnancement (et le pliage qui suit).
//
// Partie montée SANS snapshot (`_pumpFreshGame`, comme
// rotation_seeding_test.dart) : `_hasOwnFreshSession` doit être vrai pour
// que le semis automatique s'exécute au pliage -- une partie REPRISE
// (`reorder_rotation_test.dart`, tâche 5) n'est jamais auto-resemée, donc ne
// peut pas servir à prouver ce ruling-ci.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/pages/life_counter/life_counter_page.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Monte `LifeCounterPage` SANS snapshot : `_startNewGame` s'exécute, donc
/// `_hasOwnFreshSession == true` (voir life_counter_page.dart).
Future<ProviderContainer> _pumpFreshGame(WidgetTester tester, Size size) async {
  _setScreenSize(tester, size);
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
  return container;
}

Future<void> _toggleEditMode(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.build));
  await tester.pumpAndSettle();
}

/// Rejoue le vrai geste de `DraggablePlayerZone` (voir
/// reorder_rotation_test.dart, tâche 5, pour le détail de ce choix).
Future<void> _dragReorder(
  WidgetTester tester, {
  required int fromPlayerId,
  required int toPlayerId,
}) async {
  final start = tester.getCenter(_playerZone(fromPlayerId));
  final end = tester.getCenter(_playerZone(toPlayerId));

  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();

  const steps = 12;
  for (var i = 1; i <= steps; i++) {
    final t = i / steps;
    await gesture.moveTo(Offset.lerp(start, end, t)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'ruling 29 -- un reorder efface le marqueur des zones déplacées '
      '(sensibles au prochain pliage) et laisse intact celui des zones non '
      'déplacées', (tester) async {
    final container = await _pumpFreshGame(tester, const Size(900, 700));
    final notifier = container.read(gameSessionNotifierProvider.notifier);

    // Écran large, 4 joueurs : `faceToFace`, `[top, top, bottom, bottom]`
    // -> quarterTurns `[2, 2, 0, 0]` (semis de démarrage, non manuel).
    expect(
      container.read(gameSessionNotifierProvider)!.players.map((p) => p.quarterTurns),
      [2, 2, 0, 0],
    );

    // Le joueur 2 (NON déplacé par le reorder qui suit) règle sa zone à la
    // main, sur une valeur qu'aucune disposition de ce test ne dériverait
    // (ni 0/"bottom" à 900×700, ni 1/"left" à 390×844) -- pour que sa
    // survie ne soit pas une coïncidence numérique.
    notifier.updateRotation(2, 3);
    expect(container.read(gameSessionNotifierProvider)!.players[2].manualRotation,
        isTrue);

    // Le joueur 0 (DÉPLACÉ par le reorder qui suit) règle AUSSI sa zone à la
    // main, exprès -- pour prouver que le reorder EFFACE un marqueur
    // préexistant, pas seulement qu'il s'abstient d'en poser un nouveau sur
    // une zone qui n'en avait jamais eu (ce que la seule assertion sur le
    // joueur 3, jamais marqué avant le reorder, ne prouverait pas).
    notifier.updateRotation(0, 1);
    expect(container.read(gameSessionNotifierProvider)!.players[0].manualRotation,
        isTrue);

    await _toggleEditMode(tester);
    // Échange les positions 0 et 3 (joueurs 0 et 3) ; les joueurs 1 et 2 ne
    // bougent pas.
    await _dragReorder(tester, fromPlayerId: 0, toPlayerId: 3);

    final afterReorder = container.read(gameSessionNotifierProvider)!;
    expect(afterReorder.playerOrder, [3, 1, 2, 0]);

    PlayerState byId(int id) =>
        afterReorder.players.firstWhere((p) => p.playerId == id);

    // Moitié 1 (zones déplacées) : rotation posée au défaut du nouveau
    // siège, ET marqueur EFFACÉ -- pas seulement absent, explicitement faux.
    expect(byId(3).quarterTurns, 2, reason: 'joueur 3, affiché en position 0 ("top")');
    expect(byId(3).manualRotation, isFalse,
        reason: 'ruling 29 : le reorder efface le marqueur, il ne se '
            'contente pas de ne pas en poser un');
    expect(byId(0).quarterTurns, 0, reason: 'joueur 0, affiché en position 3 ("bottom")');
    expect(byId(0).manualRotation, isFalse);

    // Moitié 2 (zone non déplacée, réglée à la main) : intacte.
    expect(byId(2).quarterTurns, 3);
    expect(byId(2).manualRotation, isTrue,
        reason: 'un reorder qui ne déplace pas le joueur 2 ne doit rien lui '
            'faire perdre');

    // Pliage : nouvel écran étroit, `columnPairs` --
    // `[left, right, left, right]` sur l'ordre d'AFFICHAGE [3,1,2,0].
    _setScreenSize(tester, const Size(390, 844));
    await tester.pumpAndSettle();

    final afterFold = container.read(gameSessionNotifierProvider)!;
    PlayerState byIdAfterFold(int id) =>
        afterFold.players.firstWhere((p) => p.playerId == id);

    // Moitié 1 : désormais sensibles au semis -- le pliage les réoriente.
    expect(byIdAfterFold(3).quarterTurns, 1,
        reason: 'ruling 29 : marqueur effacé par le reorder -> le pliage '
            'peut de nouveau réorienter cette zone ("left")');
    expect(byIdAfterFold(0).quarterTurns, 3,
        reason: 'idem pour le joueur 0, affiché en position 3 ("right")');

    // Moitié 2 : toujours intacte, y compris à travers le pliage qui suit
    // le reorder.
    expect(byIdAfterFold(2).quarterTurns, 3,
        reason: 'le marqueur du joueur 2 n\'a jamais été touché : il doit '
            'survivre au reorder ET au pliage qui le suit');
  });
}
