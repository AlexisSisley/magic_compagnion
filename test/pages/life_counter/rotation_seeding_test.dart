// test/pages/life_counter/rotation_seeding_test.dart
//
// Tâche 4 : prouve le déclencheur retenu pour `seedRotationsFromSeats`
// directement sur `LifeCounterPage`, pas seulement sur le notifier isolé
// (voir test/providers/game_session_rotation_test.dart) -- la question posée
// par le brief ("quand semer ?") se joue entièrement côté page
// (`_seedRotationsIfLayoutChanged`, `_hasOwnFreshSession`), le notifier ne
// faisant qu'exécuter ce qu'on lui demande.
//
// Question 1 du rapport (déclencheur) : démarrage de partie et changement
// d'effectif passent par `_startNewGame`, qui force un semis immédiat ;
// rotation/dépliage par `didChangeMetrics`, qui force un `build()` dont le
// `addPostFrameCallback` ne resème QUE si la disposition mesurée a changé.
//
// Question 2 (survie d'un choix manuel à une reconstruction) : le test
// "une rotation choisie à la main survit" le prouve.
//
// Question 3 (pliage/dépliage après un choix manuel) : le test "un
// changement de disposition après un choix manuel" montre le choix retenu --
// la disposition gagne, le choix manuel est perdu -- et pourquoi (spec
// game_session_notifier.dart, doc de `seedRotationsFromSeats`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/pages/life_counter/life_counter_page.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Monte `LifeCounterPage` SANS snapshot dans `SharedPreferences` : la page
/// prend alors la branche "aucune partie sauvegardée" de `_loadGame()` et
/// appelle `_startNewGame()` elle-même -- la SEULE façon de monter une
/// session que `_hasOwnFreshSession` reconnaît comme sienne. C'est
/// délibérément différent de `_pumpFourPlayerTable` (reorder_rotation_test),
/// qui pré-charge un snapshot et exerce donc la branche "partie REPRISE".
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

List<int> _quarterTurnsCanonical(GameSession session) => [
      for (final p in List.of(session.players)
        ..sort((a, b) => a.playerId.compareTo(b.playerId)))
        p.quarterTurns,
    ];

void main() {
  testWidgets(
      'démarrage de partie (aucun snapshot) sème les rotations de la '
      'disposition réellement mesurée, pas des zéros', (tester) async {
    final container = await _pumpFreshGame(tester, const Size(390, 844));

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.players, hasLength(4));
    // Écran replié : `columnPairs`, `[left, right, left, right]`.
    expect(_quarterTurnsCanonical(session), [1, 3, 1, 3]);
  });

  testWidgets('une rotation choisie à la main survit à une reconstruction '
      'qui ne change pas la disposition', (tester) async {
    final container = await _pumpFreshGame(tester, const Size(390, 844));
    final notifier = container.read(gameSessionNotifierProvider.notifier);

    // Précondition : le semis de démarrage a bien posé 3 pour le joueur 1.
    expect(container.read(gameSessionNotifierProvider)!.players[1].quarterTurns, 3);

    // Choix manuel : le joueur 1 préfère "Même sens" (0).
    notifier.updateRotation(1, 0);
    expect(container.read(gameSessionNotifierProvider)!.players[1].quarterTurns, 0);

    // Une reconstruction quelconque, qui NE change PAS la disposition
    // (même écran, même effectif) -- ex. une variation de vie, comme le
    // ferait un vrai tap sur la pastille +/- d'une zone.
    notifier.updateLife(0, -3, gameDuration: Duration.zero);
    await tester.pumpAndSettle();

    expect(
      container.read(gameSessionNotifierProvider)!.players[1].quarterTurns,
      0,
      reason: 'le choix manuel doit survivre : la disposition (écran '
          '390×844, 4 joueurs) n\'a pas changé, donc '
          '`_seedRotationsIfLayoutChanged` ne doit rien réécrire',
    );
  });

  testWidgets(
      'un changement de disposition après un choix manuel écrase ce choix '
      '(décision assumée, voir rapport de tâche 4, Q3)', (tester) async {
    final container = await _pumpFreshGame(tester, const Size(390, 844));
    final notifier = container.read(gameSessionNotifierProvider.notifier);

    notifier.updateRotation(1, 0); // choix manuel, diffère du défaut (3)
    expect(container.read(gameSessionNotifierProvider)!.players[1].quarterTurns, 0);

    // L'appareil se déplie : nouvel écran large, `faceToFace` --
    // `[top, top, bottom, bottom]` -> quarterTurns `[2, 2, 0, 0]`.
    _setScreenSize(tester, const Size(840, 700));
    await tester.pumpAndSettle();

    expect(
      _quarterTurnsCanonical(container.read(gameSessionNotifierProvider)!),
      [2, 2, 0, 0],
      reason: 'le dépliage redérive TOUTES les rotations depuis la nouvelle '
          'disposition, y compris celle du joueur 1 qui avait choisi 0 à la '
          'main -- `PlayerState.quarterTurns` reste un cache de la '
          'disposition, jamais une seconde vérité indépendante',
    );
  });
}
