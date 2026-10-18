// test/pages/life_counter/reorder_rotation_test.dart
//
// Tâche 5 : le réordonnancement par glisser-déposer ne doit reposer QUE les
// zones réellement déplacées (jamais toutes), et un preset d'orientation
// appliqué après un tel réordonnancement doit se poser dans l'ordre
// d'AFFICHAGE courant, pas dans l'ordre canonique (`playerId` croissant).
//
// Les trois tests jouent le vrai geste de `DraggablePlayerZone`
// (`LongPressDraggable` + `DragTarget`, delay 1s) plutôt qu'une mutation
// directe du provider : c'est la seule façon de prouver que le câblage réel
// (mode édition -> appui long -> glissement -> relâchement -> callback)
// produit l'effet attendu, pas seulement la logique de `_onReorderPlayers`
// prise isolément.
//
// Ronde de correction 1 (tâche 5) : `_onReorderPlayers` posait ses sièges via
// `seatsFor(order.length)` en direct, sans jamais `allowSideColumns: false` —
// alors que la disposition RÉELLEMENT rendue est décidée par
// `tableLayoutFor(size, playerCount)`. Deux sources de vérité sur la
// géométrie qui divergeaient — la même classe de défaut que le
// double-pivotement du lot 6. Le troisième test verrouille la correction :
// sur un écran portrait étroit, il lit les rotations RÉELLEMENT affichées,
// quelles qu'elles soient.
//
// Tâche 3 (spec §1.4, règle du grand côté) : à 4 joueurs sur un écran
// replié, `tableLayoutFor` pose désormais `columnPairs` (colonnes gauche/
// droite, quarts de tour 1/3) au lieu du repli face-à-face historique — ce
// fichier a été mis à jour en conséquence (quatrième effectif de zones
// égales qui bascule selon la forme de l'écran, pas seulement selon
// l'espace pour des colonnes latérales). Les deux premiers tests, eux,
// tournent sur un écran large (900×700) où la grille à 4 joueurs est
// désormais `faceToFace` (deux quadrants égaux, spec §1.1) plutôt que
// l'ancien modèle à colonnes latérales permanentes.

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
/// du mode réorganisation vit dans `_buildCentralBar`, absente sur petit
/// écran ; les presets d'orientation, dans la barre de ce mode).
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

/// Bascule le mode réorganisation par un vrai tap sur le bouton dédié de la
/// barre centrale (icône `Icons.build`) — seul état où `DraggablePlayerZone`
/// arme le glisser-déposer (voir life_counter_page.dart, `_isReorganising`).
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
    // siège qu'ils occupent désormais. Tâche 3 (spec §1.1) : à 4 joueurs sur
    // cet écran large (900×700, zone 450×350 plus large que haute),
    // `tableLayoutFor` pose `faceToFace` -- `[top, top, bottom, bottom]` ->
    // quarterTurns `[2, 2, 0, 0]` -- et non plus l'ancien modèle à colonnes
    // latérales permanentes. Le joueur 3 atterrit en position 0 (top -> 2,
    // inchangé par rapport à l'ancien modèle, qui mettait aussi `top` en
    // position 0) ; le joueur 0 en position 3 (bottom -> 0, PAS `left` -> 1 :
    // les colonnes latérales à 4 joueurs n'existent plus du tout).
    expect(byId(3).quarterTurns, 2,
        reason: 'joueur 3 déplacé en position 0 (siège "top")');
    expect(byId(0).quarterTurns, 0,
        reason: 'joueur 0 déplacé en position 3 (siège "bottom")');
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

    // Tâche 8a : les presets vivent dans `ReorganiseBar`, en pied du mode
    // réorganisation -- on y est déjà, on y reste.
    // Tâche 3 (spec §1.1) : à 4 joueurs sur cet écran (900×700), la grille
    // réelle est désormais `faceToFace` -- le bouton "Face à face" n'est
    // plus proposé du tout (il n'existe que là où il DIFFÈRE de "Table",
    // voir `_getOrientationPresets`) : les deux presets posent la même
    // géométrie. On tape donc "Table", qui pose [2, 2, 0, 0] dans l'ordre
    // d'AFFICHAGE courant [3, 1, 2, 0] : position0(joueur3)->2,
    // position1(joueur1)->2, position2(joueur2)->0, position3(joueur0)->0 --
    // le même tableau qu'avant cette tâche, seul le nom du bouton change.
    await tester.tap(find.byKey(const ValueKey('reorganise-preset-Table')));
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

  // Tâche 3 (spec §1.4, règle du grand côté) : avant cette tâche, 390×844
  // repliait en face-à-face (aucune colonne latérale ne tenait sur un
  // téléphone en portrait, §3.3 d'origine) -- ce test interdisait alors 1 et
  // 3. La règle du grand côté change ce résultat : la zone d'une grille 2×2
  // y fait 195×422, plus haute que large, donc `tableLayoutFor` pose
  // désormais `columnPairs` (colonnes gauche à 90°, droite à 270°) -- c'est
  // le comportement VOULU par cette tâche, pas un défaut. Le test est
  // retourné pour verrouiller cette nouvelle réalité : un reorder doit lire
  // les rotations RÉELLEMENT affichées (1/3 ici), jamais une valeur figée
  // d'avant cette tâche.
  testWidgets(
      'sur un écran portrait étroit, un reorder pose les rotations '
      'columnPairs réellement affichées (1 ou 3)', (tester) async {
    // Mode édition activé pendant que la bande est visible (écran large) :
    // c'est le seul endroit où vit le bouton "build" tant que le hub
    // d'actions (tâche 6) n'existe pas -- l'état `_isReorganising` survit
    // ensuite au redimensionnement, indépendant de `barKind`.
    final container = await _pumpFourPlayerTable(tester);
    await _toggleEditMode(tester);

    // Redimensionne vers un téléphone en portrait étroit : 390×844, plus
    // petit côté sous `kLargeScreenShortEdge` (600) ET zone 2×2 (195×422)
    // plus haute que large, donc `tableLayoutFor` pose `columnPairs` --
    // `[left, right, left, right]` -> quarterTurns `[1, 3, 1, 3]`.
    _setScreenSize(tester, const Size(390, 844));
    await tester.pumpAndSettle();

    // Échange les positions 1 et 3 : toutes deux sont `right` dans
    // `columnPairs` (indices impairs, voir `_columnPairs`), donc les DEUX
    // joueurs déplacés prennent la même rotation (3), qu'ils aient
    // effectivement échangé de côté ou non -- un reorder entre deux sièges
    // du même côté ne change pas leur orientation, seulement leur ordre.
    await _dragReorder(tester, fromPlayerId: 1, toPlayerId: 3);

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.playerOrder, [0, 3, 2, 1]);

    final rotations = [
      for (int id = 0; id < 4; id++)
        session.players.firstWhere((p) => p.playerId == id).quarterTurns
    ];

    expect(
      rotations,
      [0, 3, 0, 3],
      reason: 'joueur 3 (déplacé en position 1, "right" de columnPairs) '
          'prend 3 ; joueur 1 (déplacé en position 3, "right" aussi) prend '
          '3 également ; joueurs 0 et 2, non déplacés, restent à 0 -- lire '
          'les sièges via `seatsFor` en direct, sans passer par '
          '`tableLayoutFor`, donnerait une disposition différente ici (deux '
          'sources de vérité sur la géométrie qui divergent, comme le '
          'double-pivotement du lot 6)',
    );
  });
}
