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
import 'package:magic_companion/widgets/life_counter/player_zone.dart';
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

    // On réordonne par le chemin réel de la page (mode édition), et non par
    // le notifier : `reorderPlayers` n'écrit que `playerOrder`, que rien dans
    // lib/ ne lisait avant la tâche 4b, qui corrige ce point.
    final reorderState = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (reorderState as dynamic).reorderForTest(0, 3);
    await tester.pumpAndSettle();

    // Dégâts en attente sur le joueur 0 (affiché en dernière position).
    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (state as dynamic).updateLifeForTest(0, -5);
    await tester.pump(const Duration(milliseconds: 100));

    // Un seul badge, et il doit être celui du joueur 0.
    expect(find.text('-5'), findsOneWidget);

    // L'assertion de proximité de centres proposée à l'origine est fragile :
    // les zones du haut de la grille sont pivotées à 180° par AdaptiveGrid,
    // ce qui peut rapprocher géométriquement deux centres de zones distinctes
    // sans qu'elles soient la même zone. On vérifie donc une inclusion
    // géométrique réelle : le centre du badge tombe dans le rectangle de la
    // zone du joueur 0, affichée en dernière position après le swap 0<->3
    // sur ces 4 joueurs.
    final badge = tester.getCenter(find.text('-5'));
    final zoneRect = tester.getRect(find.byType(PlayerZone).last);
    expect(
      zoneRect.contains(badge),
      isTrue,
      reason: 'le badge doit être dans la zone du joueur 0, pas dans une autre',
    );
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

    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (state as dynamic).reorderForTest(0, 3);
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
    final state = tester.state(find.byType(LifeCounterPage));
    // ignore: avoid_dynamic_calls
    (state as dynamic).reorderForTest(0, 3);
    await tester.pumpAndSettle();

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
}
