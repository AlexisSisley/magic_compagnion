// test/pages/life_counter/reorder_rotation_test.dart
//
// Revue finale du lot 6, IMPORTANT #1 : `_onReorderPlayers` ne permutait que
// `playerOrder`. La zone changeait donc de siège en gardant la rotation de
// l'ancien — déplacée du haut vers le siège gauche, son texte restait à 180°,
// illisible depuis cette chaise.
//
// Décision utilisateur : après un réordonnancement, chaque zone prend
// l'orientation par défaut de son NOUVEAU siège. Une rotation choisie à la
// main sur une zone déplacée est perdue, et c'est assumé.
//
// Ce test joue le VRAI geste (appui long d'une seconde puis glissement en
// incréments, spec §6.2-3), pas un appel direct à `reorderPlayers` : le
// helper `reorderPlayersViaContainer` de `life_counter_page_test.dart`
// court-circuite justement `_onReorderPlayers`, et ne verrait donc rien de
// ce correctif.
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

final _commander =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

GameSession _session(int playerCount) => GameSession.newGame(
      format: _commander,
      playerConfigs: List.generate(
        playerCount,
        (i) => PlayerConfig(
          id: 'p$i',
          name: 'Joueur $i',
          type: i == 0 ? PlayerType.owner : PlayerType.guest,
        ),
      ),
    );

Future<ProviderContainer> _pump(WidgetTester tester, GameSession session) async {
  SharedPreferences.setMockInitialValues({
    'active_game_snapshot': json.encode(session.toJson()),
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
      ],
      child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(LifeCounterPage)));
}

List<int> _rotations(ProviderContainer container) => container
    .read(gameSessionNotifierProvider)!
    .players
    .map((p) => p.quarterTurns)
    .toList();

/// Glisse la zone du joueur [fromPlayerId] sur celle du joueur [toPlayerId],
/// par le geste réel : appui long d'une seconde (le `delay` de
/// `LongPressDraggable`), puis déplacement livré en incréments, jamais en un
/// seul saut (spec §6.2-3).
///
/// Les deux zones sont repérées par `ValueKey('player_zone_<playerId>')` —
/// aucun repérage ordinal. Le point de départ et le point d'arrivée sont lus
/// sur les widgets eux-mêmes : rien n'est calculé.
Future<void> _dragZoneOnto(
  WidgetTester tester, {
  required int fromPlayerId,
  required int toPlayerId,
}) async {
  final from = tester.getCenter(find.byKey(ValueKey('player_zone_$fromPlayerId')));
  final to = tester.getCenter(find.byKey(ValueKey('player_zone_$toPlayerId')));

  final gesture = await tester.startGesture(from);
  // Franchit le `delay: Duration(seconds: 1)` de `LongPressDraggable`.
  await tester.pump(const Duration(milliseconds: 1100));

  const steps = 12;
  for (var step = 1; step <= steps; step++) {
    await gesture.moveTo(Offset.lerp(from, to, step / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }

  await gesture.up();
  await tester.pumpAndSettle();
}


/// Applique le preset d'orientation [label] par le vrai chemin d'interface.
Future<void> _applyPreset(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('orientation_presets_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('orientation_preset_$label')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      '4 joueurs, swap 0 <-> 3 : chaque zone prend l\'orientation de son '
      'NOUVEAU siège (revue finale, I#1)', (tester) async {
    final container = await _pump(tester, _session(4));

    // seatsFor(4) = [haut, droite, bas, gauche] -> [2, 3, 0, 1].
    expect(_rotations(container), [2, 3, 0, 1],
        reason: 'état de départ : chaque joueur sur son siège par défaut');

    await tester.tap(find.byKey(const ValueKey('action-edit-mode')));
    await tester.pumpAndSettle();

    await _dragZoneOnto(tester, fromPlayerId: 0, toPlayerId: 3);

    final session = container.read(gameSessionNotifierProvider)!;
    expect(session.playerOrder, [3, 1, 2, 0],
        reason: 'le swap 0 <-> 3 doit avoir eu lieu : sans lui, le reste du '
            'test ne prouverait rien');

    // Ordre d'affichage [3, 1, 2, 0] sur les sièges [2, 3, 0, 1] : le joueur
    // 3 hérite du siège haut (2), le joueur 0 du siège gauche (1). Les
    // rotations sont lues dans l'ordre canonique `playerId`.
    expect(_rotations(container), [1, 3, 0, 2],
        reason: 'le joueur 0, parti du haut pour le siège gauche, doit '
            'passer de 2 à 1 quarts de tour — garder 2 le laisserait à 180° '
            'de sa chaise');
  });

  testWidgets(
      '4 joueurs : une rotation choisie à la main sur la zone déplacée est '
      'écrasée par le siège d\'arrivée (comportement assumé)', (tester) async {
    final container = await _pump(tester, _session(4));

    // Le joueur 0 tourne sa zone à la main vers une valeur qu'aucun siège de
    // cette table ne porte deux fois : si elle survivait au déplacement, on
    // la reverrait telle quelle.
    container.read(gameSessionNotifierProvider.notifier).updateRotation(0, 3);
    await tester.pumpAndSettle();
    expect(_rotations(container), [3, 3, 0, 1]);

    await tester.tap(find.byKey(const ValueKey('action-edit-mode')));
    await tester.pumpAndSettle();

    await _dragZoneOnto(tester, fromPlayerId: 0, toPlayerId: 3);

    expect(_rotations(container), [1, 3, 0, 2],
        reason: 'la rotation manuelle du joueur 0 est perdue : le siège '
            'gauche impose 1 quart de tour');
  });

  testWidgets(
      "4 joueurs : un réordonnancement ne touche PAS l'orientation des zones "
      "que personne n'a déplacées (re-revue scopée, R1)", (tester) async {
    final container = await _pump(tester, _session(4));
    final notifier = container.read(gameSessionNotifierProvider.notifier);

    // « Même sens » : les quatre zones à 0. C'est le choix délibéré que le
    // marqueur de migration (CRITICAL #2) protège au rechargement — il ne
    // doit pas sauter au premier glisser-déposer sans rapport.
    for (var playerId = 0; playerId < 4; playerId++) {
      notifier.updateRotation(playerId, 0);
    }
    await tester.pumpAndSettle();
    expect(_rotations(container), [0, 0, 0, 0]);

    await tester.tap(find.byKey(const ValueKey('action-edit-mode')));
    await tester.pumpAndSettle();

    await _dragZoneOnto(tester, fromPlayerId: 0, toPlayerId: 3);

    // Seuls les joueurs 0 et 3 ont changé de siège : ils prennent le leur
    // (gauche = 1 pour le joueur 0, haut = 2 pour le joueur 3). Les joueurs
    // 1 et 2 n'ont pas bougé et gardent le 0 choisi.
    expect(_rotations(container), [1, 0, 0, 2],
        reason: 'reposer TOUTES les rotations remettrait les joueurs 1 et 2 '
            'à 3 et 0, détruisant « Même sens » sur des zones intactes');
  });

  testWidgets(
      "4 joueurs : après un réordonnancement, un preset se pose dans l'ordre "
      "D'AFFICHAGE, pas dans l'ordre canonique (re-revue scopée, R2)",
      (tester) async {
    final container = await _pump(tester, _session(4));

    await tester.tap(find.byKey(const ValueKey('action-edit-mode')));
    await tester.pumpAndSettle();
    await _dragZoneOnto(tester, fromPlayerId: 0, toPlayerId: 3);
    await tester.tap(find.byKey(const ValueKey('action-edit-mode')));
    await tester.pumpAndSettle();

    expect(container.read(gameSessionNotifierProvider)!.playerOrder,
        [3, 1, 2, 0],
        reason: "sans le swap, l'ordre d'affichage vaudrait l'ordre "
            "canonique et le test ne distinguerait plus rien");

    // Tout remettre à plat pour que le preset ait quelque chose à changer.
    final notifier = container.read(gameSessionNotifierProvider.notifier);
    for (var playerId = 0; playerId < 4; playerId++) {
      notifier.updateRotation(playerId, 0);
    }
    await tester.pumpAndSettle();

    await _applyPreset(tester, 'Table');

    // Ordre d'affichage [3, 1, 2, 0] sur les sièges [2, 3, 0, 1].
    // Posé dans l'ordre canonique, on lirait [2, 3, 0, 1] : deux joueurs à
    // l'envers de leur chaise, et l'aperçu montrerait pourtant le bon dessin.
    expect(_rotations(container), [1, 3, 0, 2],
        reason: 'le preset doit suivre `playerOrder`, pas `players`');
  });
}
