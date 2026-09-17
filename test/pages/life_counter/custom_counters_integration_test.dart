// test/pages/life_counter/custom_counters_integration_test.dart
//
// Lot 5, tâche 5 : le test bout-en-bout des compteurs personnalisés.
//
// Ce que ce fichier refuse de faire (voir le brief de tâche) : construire un
// `CounterSummary` à la main, deviner un index d'arbre pour désigner un
// joueur, ou vérifier un `GameSession` sans jamais l'avoir fait transiter par
// un vrai geste. Chaque étape ci-dessous est un geste réel (tap, saisie de
// texte) sur la page montée telle qu'elle tourne en jeu, et le joueur ciblé
// est désigné par `ValueKey('player_zone_<playerId>')` -- jamais par sa
// position dans l'arbre, qui ne coïncide plus avec son identité dès qu'un
// reorder a eu lieu (voir la session en cours ci-dessous, délibérément
// permutée pour ne PAS coïncider).
//
// `tester.pump()` borné partout, jamais `pumpAndSettle()` sur un geste qui
// pourrait laisser une zone en alerte : `CriticalOverlay` boucle indéfiniment
// au niveau létal, et aucune vie n'est jamais abaissée dans ce scénario --
// mais le principe est appliqué systématiquement plutôt qu'au cas par cas,
// pour ne pas dépendre de cette précondition en silence. `pumpAndSettle()`
// n'est utilisé que pour les transitions de `Navigator` (ouverture/fermeture
// du tiroir et du dialogue), qui n'ont pas d'animation en boucle propre.

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
import 'package:magic_companion/services/counter_type_service.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _commanderFormat =
    GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

final _testConfigs = [
  const PlayerConfig(id: 'p0', name: 'Alex', type: PlayerType.owner),
  const PlayerConfig(id: 'p1', name: 'Max', type: PlayerType.guest),
  const PlayerConfig(id: 'p2', name: 'Sarah', type: PlayerType.guest),
  const PlayerConfig(id: 'p3', name: 'Leo', type: PlayerType.guest),
];

/// Clé de la zone du joueur [playerId] -- pas sa position dans l'arbre (voir
/// le commentaire de fichier).
Key _playerZoneKey(int playerId) => ValueKey('player_zone_$playerId');

void main() {
  /// Une partie Commander EN COURS (`isActive: true`, chrono démarré), à 4
  /// joueurs, dont l'ordre d'AFFICHAGE est délibérément permuté
  /// (`playerOrder: [3, 2, 1, 0]`, l'inverse de l'ordre canonique) : le
  /// joueur ciblé par ce test, `playerId 1` ("Max"), est donc affiché en
  /// 3ᵉ position (index 2) de l'arbre, ni en 1ʳᵉ position (l'ancien
  /// raccourci `find.byType(ConditionalHandle).first` qu'utilisent d'autres
  /// tests de ce fichier voisin) ni à l'index correspondant à son propre id.
  /// Un code qui désignerait "le joueur 1" par une position d'arbre plutôt
  /// que par cette clé toucherait donc le mauvais joueur -- exactement le
  /// défaut que ce test doit pouvoir détecter.
  GameSession buildInProgressSession() {
    final base = GameSession.newGame(
      format: _commanderFormat,
      playerConfigs: _testConfigs,
    );
    return base.copyWith(
      isActive: true,
      startedAt: DateTime.now(),
      playerOrder: const [3, 2, 1, 0],
    );
  }

  Future<ProviderContainer> pumpGame(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'active_game_snapshot':
          json.encode(buildInProgressSession().toJson()),
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

  testWidgets(
      'un compteur personnalisé créé, incrémenté et saturé depuis le tiroir '
      'du joueur 1 (désigné par sa clé, affiché en 3ᵉ position) survit à un '
      'aller-retour toJson/fromJson de la session, sans fuir vers un autre '
      'joueur', (tester) async {
    final container = await pumpGame(tester);

    // --- Précondition : le joueur ciblé n'est PAS le premier de l'arbre ---
    // Verrouille la mise en scène elle-même : si cette assertion échouait,
    // le reste du test ne prouverait rien sur l'indépendance à l'ordre
    // d'affichage qu'il prétend vérifier.
    // Revue finale (petite chose 1) : `expect(zone1Rect, isNotNull)`
    // portait sur un `Rect` non nullable -- assertion vide, aucune mutation
    // ne l'aurait rougie. Retirée : la comparaison ci-dessous
    // (`zone1HandleRect` contre `firstHandleRect`) est la seule qui prouve
    // réellement la précondition de mise en scène.
    final firstHandleRect =
        tester.getRect(find.byType(ConditionalHandle).first);
    final zone1HandleRect = tester.getRect(find.descendant(
      of: find.byKey(_playerZoneKey(1)),
      matching: find.byType(ConditionalHandle),
    ));
    expect(zone1HandleRect, isNot(firstHandleRect),
        reason: 'mise en scène : la poignée du joueur 1 ne doit pas être la '
            'première de l\'arbre, sans quoi ce test retomberait sur le '
            'même raccourci de position que celui qu\'il évite');

    // --- 1. Ouvre le tiroir du JOUEUR 1, désigné par sa clé d'identité ---
    await tester.tap(find.descendant(
      of: find.byKey(_playerZoneKey(1)),
      matching: find.byType(ConditionalHandle),
    ));
    await tester.pumpAndSettle();

    // --- 2. Crée un compteur par de vrais gestes (dialogue), borne = 2 ---
    // Une borne volontairement basse : "saturer sa borne" avec quatre taps
    // reste un test rapide et déterministe, plutôt que 99+ taps pour
    // atteindre le plafond historique non plafonné par le type.
    await tester.tap(find.byKey(const ValueKey('action-create-counter')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')), 'Rage');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')), '🔥');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_max_value')), '2');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('counter_editor_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('counter_row_rage')), findsOneWidget,
        reason: 'la ligne du compteur créé doit apparaître dans CE tiroir, '
            'sans avoir à le refermer et le rouvrir');

    // --- 3. Incrémente par de vrais taps, jusqu'à saturer la borne (2) ---
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('counter_row_rage_plus')));
      await tester.pump();
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('counter_row_rage')),
        matching: find.text('2'),
      ),
      findsOneWidget,
      reason: 'deux taps sur une borne à 2 doivent afficher 2 dans la ligne '
          'du tiroir',
    );

    // --- 4. Sature la borne : deux taps de plus ne doivent RIEN changer,
    // ni dans le tiroir (copie locale d'affichage) ni dans la session ---
    // Défaut réel trouvé par ce test avant correction (voir le rapport de
    // tâche) : `_PlayerDrawerBody._bump` plafonnait sa copie locale à 99 en
    // dur, jamais à `CounterType.maxValue` -- la session, elle, saturait
    // déjà correctement à 2 (`GameSessionNotifier.updateCounter`). Le
    // tiroir affichait donc 3 puis 4 après ces deux taps, alors que la
    // partie réelle restait à 2 : exactement le genre de divergence
    // qu'un test qui ne creuse que le modèle ne peut pas voir.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('counter_row_rage_plus')));
      await tester.pump();
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('counter_row_rage')),
        matching: find.text('2'),
      ),
      findsOneWidget,
      reason: 'la borne doit TENIR à l\'affichage : deux taps de plus après '
          'saturation ne doivent jamais faire apparaître 3 ou 4 dans le '
          'tiroir, même si la session, elle, restait déjà correctement '
          'saturée en interne',
    );
    final sessionAfterSaturation = container.read(gameSessionNotifierProvider)!;
    expect(
      sessionAfterSaturation.players
          .firstWhere((p) => p.playerId == 1)
          .counters['rage'],
      2,
      reason: 'la session elle-même ne doit jamais dépasser la borne, quel '
          'que soit le nombre de taps envoyés',
    );

    // --- 5. Ferme le tiroir : la puce apparaît sur LA POIGNÉE DU JOUEUR 1
    // -- et d'aucun autre joueur. ---
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(_playerZoneKey(1)),
        matching: find.text('🔥 2'),
      ),
      findsOneWidget,
      reason: 'la puce du compteur personnalisé doit apparaître sur la '
          'poignée du joueur qui l\'a créé',
    );
    for (final otherPlayerId in [0, 2, 3]) {
      expect(
        find.descendant(
          of: find.byKey(_playerZoneKey(otherPlayerId)),
          matching: find.text('🔥 2'),
        ),
        findsNothing,
        reason: 'le compteur créé pour le joueur 1 ne doit apparaître sur '
            'AUCUNE autre poignée -- même défaut de famille que le bug du '
            'lot 4 sur le bouton "−" (bon nombre de lignes, mauvais '
            'joueur), ici appliqué à l\'identité du joueur plutôt qu\'au '
            'compteur',
      );
    }

    // --- 6. Le compteur créé survit à un aller-retour toJson/fromJson de
    // la session -- le point qui manquerait le plus en test unitaire : un
    // compteur personnalisé qui disparaîtrait au rechargement après un
    // plantage serait invisible à toute assertion qui ne creuse que l'état
    // en mémoire. ---
    final sessionBeforeRoundTrip =
        container.read(gameSessionNotifierProvider)!;
    final decoded = json.decode(json.encode(sessionBeforeRoundTrip.toJson()))
        as Map<String, dynamic>;
    final restored = GameSession.fromJson(decoded);

    expect(restored.activeCounterIds, contains('rage'),
        reason: 'un compteur actif doit rester actif après relecture');
    expect(restored.customCounterIds, contains('rage'),
        reason: 'GameSession.customCounterIds doit lui aussi survivre '
            '(décision D-1 de la spec : c\'est la liste des actifs de CETTE '
            'partie, pas le catalogue)');
    final restoredPlayer1 =
        restored.players.firstWhere((p) => p.playerId == 1);
    expect(restoredPlayer1.counters['rage'], 2,
        reason: 'la valeur saturée doit survivre telle quelle, pas '
            'retomber à 0 ni remonter au-delà de sa borne');
    // Précondition croisée : le compteur ne doit pas non plus avoir migré
    // vers un autre joueur pendant le round-trip.
    for (final otherPlayerId in [0, 2, 3]) {
      final otherPlayer =
          restored.players.firstWhere((p) => p.playerId == otherPlayerId);
      expect(otherPlayer.counters['rage'], anyOf(isNull, 0),
          reason: 'le compteur "rage" ne doit exister que pour le joueur '
              'qui l\'a créé, même après round-trip');
    }

    // --- 7. Le TYPE lui-même (nom, emoji, borne) est persisté globalement
    // (décision D-1 de la spec), lisible par un service tout neuf -- pas
    // seulement conservé dans l'état en mémoire du catalogue déjà chargé. ---
    final freshTypes = await CounterTypeService().loadCustomTypes();
    final rage = freshTypes.firstWhere((t) => t.id == 'rage');
    expect(rage.name, 'Rage');
    expect(rage.emoji, '🔥');
    expect(rage.maxValue, 2);
  });
}
