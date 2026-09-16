// test/pages/life_counter/table_view_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/pages/life_counter/table_view_page.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';

final commanderFormat =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

final testConfigs = [
  const PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
  const PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
  const PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
  const PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
];

/// Quatre joueurs aux états contrastés (spec §2.3) :
/// - Alex (0) : monarque, calme (aucun compteur non nul).
/// - Max (1) : éliminé.
/// - Sarah (2) : du poison (3), mais de l'énergie explicitement à 0 —
///   présente dans la map, pas seulement absente, pour prouver que le
///   filtre exclut bien une entrée à zéro et pas seulement une clé absente.
/// - Leo (3) : de la taxe de commandant (2), rien d'autre.
GameSession _fourContrastedPlayers() {
  final base = GameSession.newGame(
    format: commanderFormat,
    playerConfigs: testConfigs,
  );
  return base.copyWith(players: [
    base.players[0].copyWith(life: 40, isMonarch: true),
    base.players[1].copyWith(life: -3, isEliminated: true),
    base.players[2].copyWith(
      life: 22,
      counters: const {'poison': 3, 'energy': 0},
    ),
    base.players[3].copyWith(life: 15, counters: const {'commander_tax': 2}),
  ]);
}

Future<ProviderContainer> _pumpTableView(
  WidgetTester tester, {
  GameSession? session,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (session != null) {
    container.read(gameSessionNotifierProvider.notifier).restoreSession(session);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TableViewPage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

String? _textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data;

void main() {
  testWidgets('affiche une ligne par joueur, avec ses PV', (tester) async {
    await _pumpTableView(tester, session: _fourContrastedPlayers());

    for (var id = 0; id < 4; id++) {
      expect(find.byKey(ValueKey('table-view-row-$id')), findsOneWidget,
          reason: 'joueur $id doit avoir sa propre ligne');
    }

    expect(_textOf(tester, const ValueKey('table-view-life-0')), '40');
    expect(_textOf(tester, const ValueKey('table-view-life-1')), '-3');
    expect(_textOf(tester, const ValueKey('table-view-life-2')), '22');
    expect(_textOf(tester, const ValueKey('table-view-life-3')), '15');
  });

  testWidgets('les compteurs à zéro n\'apparaissent pas', (tester) async {
    await _pumpTableView(tester, session: _fourContrastedPlayers());

    // Sarah (2) : le poison (non nul) apparaît, l'énergie (explicitement à
    // zéro dans la map) n'apparaît pas.
    expect(find.byKey(const ValueKey('table-view-counter-2-poison')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('table-view-counter-2-energy')),
        findsNothing);

    // Leo (3) : sa taxe de commandant apparaît.
    expect(find.byKey(const ValueKey('table-view-counter-3-commander_tax')),
        findsOneWidget);

    // Alex (0) : calme, aucun compteur affiché.
    expect(find.byKey(const ValueKey('table-view-counter-0-poison')),
        findsNothing);
    expect(find.byKey(const ValueKey('table-view-counter-0-energy')),
        findsNothing);
    expect(find.byKey(const ValueKey('table-view-counter-0-commander_tax')),
        findsNothing);
  });

  testWidgets('le monarque est signalé', (tester) async {
    await _pumpTableView(tester, session: _fourContrastedPlayers());

    expect(find.byKey(const ValueKey('table-view-monarch-0')), findsOneWidget,
        reason: 'Alex est le monarque de cette session de test');
    for (final id in [1, 2, 3]) {
      expect(find.byKey(ValueKey('table-view-monarch-$id')), findsNothing);
    }
  });

  testWidgets('un joueur éliminé est distingué', (tester) async {
    await _pumpTableView(tester, session: _fourContrastedPlayers());

    expect(
        find.byKey(const ValueKey('table-view-eliminated-1')), findsOneWidget,
        reason: 'Max est éliminé dans cette session de test');
    for (final id in [0, 2, 3]) {
      expect(find.byKey(ValueKey('table-view-eliminated-$id')), findsNothing);
    }
  });

  testWidgets('aucune partie en cours : la vue reste lisible, sans ligne',
      (tester) async {
    await _pumpTableView(tester);

    expect(find.byKey(const ValueKey('table-view-row-0')), findsNothing);
    expect(find.text('Aucune partie en cours'), findsOneWidget);
  });
}
