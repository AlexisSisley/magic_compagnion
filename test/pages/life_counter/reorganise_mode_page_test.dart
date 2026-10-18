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
// Tâche 8b : le preset en place est mis en évidence, et la table de
// référence des presets et du semis reste celle hors mode (la barre ampute
// la grille, pas la table jouée).
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
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';
import 'package:magic_companion/widgets/life_counter/layouts/orientation_presets.dart';
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

/// Le snapshot tel que l'écrivait le code d'avant `manualRotation` : sans le
/// champ, qui se relit alors `true` pour tous. C'est la partie reprise que
/// ces tests décrivent, celle que le montage ne doit jamais resemer.
String _legacySnapshotJson(GameSession session) {
  final jsonMap = session.toJson();
  for (final player in jsonMap['players'] as List) {
    (player as Map<String, dynamic>).remove('manualRotation');
  }
  return json.encode(jsonMap);
}

Future<ProviderContainer> _pumpFourPlayerTable(WidgetTester tester) async {
  _setScreenSize(tester, const Size(900, 700));
  final session = GameSession.newGame(
    format: _commanderFormat,
    playerConfigs: _testConfigs,
  );
  SharedPreferences.setMockInitialValues({
    'active_game_snapshot': _legacySnapshotJson(session),
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

/// Libellés des presets mis en évidence (bordure dorée) dans la barre.
List<String> _highlighted(WidgetTester tester) => [
      for (final button in tester.widgetList<OutlinedButton>(find.descendant(
        of: find.byType(ReorganiseBar),
        matching: find.byType(OutlinedButton),
      )))
        if (button.style!.side!.resolve(const {})!.color == AppColors.primary)
          (button.child as Text).data!,
    ];

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
      '(« Face-à-face » puis « Même sens ») et devient le preset en évidence',
      (tester) async {
    final container = await _pumpFourPlayerTable(tester);
    await _enterReorganise(tester);

    // Le snapshot démarre tout à 0 : c'est déjà « Même sens », seul preset
    // en évidence à l'entrée.
    expect(_highlighted(tester), ['Même sens']);

    // « Face-à-face » d'abord (géométrie réelle à cet écran : [2,2,0,0]),
    // puis « Même sens ».
    await tester
        .tap(find.byKey(const ValueKey('reorganise-preset-Face-à-face')));
    await tester.pumpAndSettle();
    expect(_turnsByCanonicalId(container), [2, 2, 0, 0]);
    expect(_highlighted(tester), ['Face-à-face'],
        reason: 'la mise en évidence suit les angles en place');

    await tester
        .tap(find.byKey(const ValueKey('reorganise-preset-Même sens')));
    await tester.pumpAndSettle();
    expect(_turnsByCanonicalId(container), [0, 0, 0, 0]);
    expect(_highlighted(tester), ['Même sens']);
    expect(find.byType(ReorganiseBar), findsOneWidget,
        reason: 'un preset ne fait pas sortir du mode : seul « Terminé » '
            'le fait');
  });

  // Tâche 8b : la barre du mode, posée sous la grille, l'ampute d'environ
  // 155 px. À 700×760, une table neuve à 4 joueurs a des zones plus hautes
  // que larges (350×380 : colonnes, [1,3,1,3]) ; amputée, elle passerait à
  // des zones plus larges que hautes (face-à-face, [2,2,0,0]). Si le semis
  // ou les presets lisaient la grille du mode, entrer dans le mode
  // resèmerait une partie neuve et changerait les presets proposés.
  testWidgets(
      'entrer puis sortir du mode ne resème pas une partie neuve, et les '
      'presets décrivent la table jouée, pas la grille amputée par la barre',
      (tester) async {
    _setScreenSize(tester, const Size(700, 760));
    // Aucun snapshot : la page démarre elle-même la partie, donc la session
    // est neuve et le semis automatique est armé (voir rotation_seeding_test).
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
    expect(_turnsByCanonicalId(container), [1, 3, 1, 3],
        reason: 'précondition : semis de démarrage en colonnes');

    await _enterReorganise(tester);
    final grid = tester.getSize(find.byType(AdaptiveGrid));
    expect(grid.height / 2, lessThan(grid.width / 2),
        reason: 'précondition : dans le mode, la grille amputée a des zones '
            'plus larges que hautes -- elle changerait de disposition');

    expect(_turnsByCanonicalId(container), [1, 3, 1, 3],
        reason: 'entrer dans le mode ne doit pas resemer la partie');
    expect(_highlighted(tester), ['Côtés'],
        reason: 'les angles semés sont ceux de « Côtés » sur la table jouée');

    await _tapDone(tester);
    expect(_turnsByCanonicalId(container), [1, 3, 1, 3],
        reason: 'en sortir non plus');
  });

  // La barre se construit sur la taille mesurée à la frame PRÉCÉDENTE. Juste
  // après un pliage, elle porte donc encore la table d'avant ; un preset qui
  // aurait gardé ses angles du build les appliquerait à l'ancienne table.
  // On tape entre la frame du pliage et la suivante, quand la barre est
  // encore celle d'avant.
  testWidgets(
      'un preset touché juste après un pliage pose les angles de la table '
      'courante, pas ceux de la table où la barre a été construite',
      (tester) async {
    const unfolded = Size(900, 700);
    const folded = Size(390, 844);
    _setScreenSize(tester, unfolded);
    final session = GameSession.newGame(
      format: _commanderFormat,
      playerConfigs: [
        for (int i = 0; i < 5; i++)
          PlayerConfig(
            id: 'p$i',
            name: 'Joueur ${i + 1}',
            type: i == 0 ? PlayerType.owner : PlayerType.guest,
          ),
      ],
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
    await _enterReorganise(tester);

    final stale =
        orientationPresetTurns(OrientationPreset.circle, unfolded, 5);
    final current =
        orientationPresetTurns(OrientationPreset.circle, folded, 5);
    expect(current, isNot(stale),
        reason: 'précondition : « Cercle » ne pose pas les mêmes angles sur '
            'les deux tables');

    _setScreenSize(tester, folded);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reorganise-preset-Cercle')));
    await tester.pumpAndSettle();

    final order = container.read(gameSessionNotifierProvider)!.playerOrder;
    final byDisplay = [
      for (final id in order)
        container
            .read(gameSessionNotifierProvider)!
            .players
            .firstWhere((p) => p.playerId == id)
            .quarterTurns,
    ];
    expect(byDisplay, current,
        reason: "les angles sont recalculés à l'appui, sur la table pliée");
  });
}
