// test/pages/life_counter/reorder_rotation_test.dart
//
// Tâche 5 : le réordonnancement par glisser-déposer ne doit reposer QUE les
// zones réellement déplacées (jamais toutes), et un preset d'orientation
// appliqué après un tel réordonnancement doit se poser dans l'ordre
// d'AFFICHAGE courant, pas dans l'ordre canonique (`playerId` croissant).
//
// Les deux tests jouent le vrai geste de `DraggablePlayerZone`
// (`LongPressDraggable` + `DragTarget`, delay 1s) plutôt qu'une mutation
// directe du provider : c'est la seule façon de prouver que le câblage réel
// (mode édition -> appui long -> glissement -> relâchement -> callback)
// produit l'effet attendu, pas seulement la logique de `_onReorderPlayers`
// prise isolément.

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
import 'package:shared_preferences/shared_preferences.dart';

final _commanderFormat =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

final _testConfigs = [
  const PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
  const PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
  const PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
  const PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
];

/// Repère la zone du joueur [playerId] par sa clé d'identité (posée en tâche
/// 4 : `KeyedSubtree(key: ValueKey('player_zone_<playerId>'))`), jamais par
/// position dans l'arbre — `AdaptiveGrid` place les zones selon
/// `tableLayoutFor`/`seatsFor`, dont l'ordre ne suit ni l'ordre d'affichage
/// ni l'ordre canonique de façon fixe.
Finder _playerZone(int playerId) =>
    find.byKey(ValueKey('player_zone_$playerId'));

/// Écran assez large pour que `AdaptiveGrid` choisisse la bande (le bouton
/// de mode édition et celui des presets d'orientation vivent dans
/// `_buildCentralBar`, absents sur petit écran).
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

/// Monte la page avec un `container` explicite (pour lire l'état ensuite)
/// et un snapshot à 4 joueurs, tous à `quarterTurns == 0` (playerOrder
/// identité au départ : c'est le réordonnancement joué par le test qui va
/// le rendre non trivial).
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

/// Bascule le mode édition par un vrai tap sur le bouton dédié de la barre
/// centrale (icône `Icons.build`) — seul état où `DraggablePlayerZone`
/// enveloppe les zones (voir life_counter_page.dart, `_isEditMode`).
Future<void> _toggleEditMode(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.build));
  await tester.pumpAndSettle();
}

/// Rejoue le vrai geste de `DraggablePlayerZone` : appui long d'1s sur la
/// zone [fromPlayerId], puis un glissement livré en incréments (jamais un
/// seul saut) jusqu'au centre de la zone [toPlayerId], puis relâchement.
Future<void> _dragReorder(
  WidgetTester tester, {
  required int fromPlayerId,
  required int toPlayerId,
}) async {
  final start = tester.getCenter(_playerZone(fromPlayerId));
  final end = tester.getCenter(_playerZone(toPlayerId));

  final gesture = await tester.startGesture(start);
  // `LongPressDraggable` n'arme le drag qu'après son `delay` (1s) — voir
  // draggable_player_zone.dart.
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
      'un réordonnancement ne touche que les zones déplacées '
      '(joueurs 1 et 2 restent à 0)', (tester) async {
    final container = await _pumpFourPlayerTable(tester);
    await _toggleEditMode(tester);

    // playerOrder démarre à l'identité [0,1,2,3] : la zone du joueur 0 est
    // donc affichée en position 0, celle du joueur 3 en position 3.
    await _dragReorder(tester, fromPlayerId: 0, toPlayerId: 3);

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.playerOrder, [3, 1, 2, 0],
        reason:
            'positions 0 et 3 échangées, positions 1 et 2 non touchées');

    PlayerState byId(int id) =>
        session.players.firstWhere((p) => p.playerId == id);

    expect(byId(1).quarterTurns, 0,
        reason:
            'le joueur 1 n\'a pas changé de siège : reposer TOUTES les '
            'zones aurait détruit son orientation (un « Même sens » '
            'sauterait au premier glisser-déposer sans rapport)');
    expect(byId(2).quarterTurns, 0,
        reason: 'idem pour le joueur 2, non déplacé');

    // Les joueurs 0 et 3 ont échangé de siège : ils prennent la rotation du
    // siège qu'ils occupent désormais (seatsFor(4) : sides
    // [top, right, bottom, left] -> quarterTurns [2, 3, 0, 1]). Le joueur 3
    // atterrit en position 0 (top -> 2), le joueur 0 en position 3
    // (left -> 1).
    expect(byId(3).quarterTurns, 2,
        reason: 'joueur 3 déplacé en position 0 (siège "top")');
    expect(byId(0).quarterTurns, 1,
        reason: 'joueur 0 déplacé en position 3 (siège "left")');
  });

  testWidgets(
      'un preset se pose dans l\'ordre d\'AFFICHAGE, pas dans l\'ordre '
      'canonique', (tester) async {
    final container = await _pumpFourPlayerTable(tester);
    await _toggleEditMode(tester);

    // Même réordonnancement que le test précédent : playerOrder devient
    // [3, 1, 2, 0], donc bien différent de l'identité — sans ça, poser un
    // preset en ordre d'affichage ou en ordre canonique produirait le même
    // résultat, et ce test ne prouverait rien.
    await _dragReorder(tester, fromPlayerId: 0, toPlayerId: 3);
    expect(container.read(gameSessionNotifierProvider)!.playerOrder,
        [3, 1, 2, 0]);

    // Quitte le mode édition : la feuille de presets d'orientation est
    // accessible dans les deux modes, mais rien ne l'exige active ici.
    await _toggleEditMode(tester);

    await tester.tap(find.byKey(const ValueKey('action-orientation-presets')));
    await tester.pumpAndSettle();
    // "Face à face" à 4 joueurs pose [2, 2, 0, 0] dans l'ordre d'AFFICHAGE
    // courant [3, 1, 2, 0] : position0(joueur3)->2, position1(joueur1)->2,
    // position2(joueur2)->0, position3(joueur0)->0.
    await tester.tap(find.text('Face à face'));
    await tester.pumpAndSettle();

    final session = container.read(gameSessionNotifierProvider)!;
    final rotationsByCanonicalId = [
      for (int id = 0; id < 4; id++)
        session.players.firstWhere((p) => p.playerId == id).quarterTurns
    ];

    expect(
      rotationsByCanonicalId,
      [0, 2, 0, 2],
      reason: 'le preset doit suivre la position d\'AFFICHAGE de chaque '
          'joueur ([3,1,2,0]), pas son playerId canonique : un calcul en '
          'ordre canonique aurait donné [2,2,0,0], le résultat d\'avant '
          'réordonnancement',
    );
  });
}
