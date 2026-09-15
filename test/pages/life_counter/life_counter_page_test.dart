// test/pages/life_counter/life_counter_page_test.dart
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

final commanderFormat =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

final testConfigs = [
  const PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
  const PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
  const PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
  const PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
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

    // On retire 1 PV au joueur 0 et on laisse le buffer de 2 s s'appliquer.
    // `_LifeCounterPageState` est privé : impossible de nommer son type depuis
    // ce fichier de test, d'où le cast dynamique ciblé ci-dessous.
    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (state as dynamic).updateLifeForTest(0, -1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Avant correctif : la session est écrasée par le null du contrôleur.
    expect(find.text('33'), findsOneWidget,
        reason: 'la partie restaurée ne doit pas être effacée');
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
}
