// test/pages/life_counter/orientation_presets_test.dart
//
// Revue finale du lot 6, CRITICAL #1 : le chemin « presets d'orientation »
// n'avait AUCUN test. Il posait `[2, 2, 0, 0]` pour le preset « Même sens »
// à 4 joueurs — il soustrayait 2 quarts de tour à la « moitié haute » pour
// compenser une `RotatedBox` qu'`AdaptiveGrid` ne pose plus depuis la
// tâche 2 du lot. Deux zones sur quatre se retrouvaient tête en bas alors
// que l'aperçu montrait quatre flèches identiques.
//
// Ces tests jouent le geste réel (ouverture de la feuille par la clé du
// bouton, tap sur la vignette par sa clé) et lisent les `quarterTurns`
// effectivement posés sur la session. Les valeurs attendues sont écrites en
// dur, jamais recalculées depuis `seatsFor` : un test qui réappliquerait la
// formule du code ne discriminerait rien.
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

GameSession _session(int playerCount) {
  return GameSession.newGame(
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
}

Future<void> _pump(WidgetTester tester, GameSession session) async {
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
}

/// Ouvre la feuille des presets et tape la vignette [label], toutes deux
/// repérées par clé — aucun repérage ordinal, aucune position calculée.
Future<void> _applyPreset(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('orientation_presets_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('orientation_preset_$label')));
  await tester.pumpAndSettle();
}

/// `quarterTurns` de chaque joueur, dans l'ordre canonique `playerId`.
List<int> _rotations(WidgetTester tester) {
  final container =
      ProviderScope.containerOf(tester.element(find.byType(LifeCounterPage)));
  final session = container.read(gameSessionNotifierProvider)!;
  return session.players.map((p) => p.quarterTurns).toList();
}

/// Presets attendus par nombre de joueurs, dans l'ordre d'affichage de la
/// feuille. Convention (`lib/models/table_seat.dart`) : bas = 0, gauche = 1,
/// haut = 2, droite = 3.
///
/// « Table » reprend `seatsFor` : de 4 à 6 joueurs, deux sièges sur quatre
/// sont latéraux. « Face à face » garde la règle historique haut/bas, et
/// n'est proposée que là où elle diffère de « Table ».
const Map<int, Map<String, List<int>>> _expected = {
  2: {
    'Table': [2, 0],
    'Côte à côte': [1, 3],
    'Même sens': [0, 0],
  },
  3: {
    'Table': [2, 0, 0],
    'Même sens': [0, 0, 0],
  },
  4: {
    'Table': [2, 3, 0, 1],
    'Face à face': [2, 2, 0, 0],
    'Même sens': [0, 0, 0, 0],
  },
  5: {
    'Table': [2, 2, 3, 0, 1],
    'Face à face': [2, 2, 0, 0, 0],
    'Même sens': [0, 0, 0, 0, 0],
  },
  6: {
    'Table': [2, 2, 3, 0, 0, 1],
    'Face à face': [2, 2, 2, 0, 0, 0],
    'Même sens': [0, 0, 0, 0, 0, 0],
  },
  7: {
    'Table': [2, 2, 2, 0, 0, 0, 0],
    'Même sens': [0, 0, 0, 0, 0, 0, 0],
  },
  8: {
    'Table': [2, 2, 2, 2, 0, 0, 0, 0],
    'Même sens': [0, 0, 0, 0, 0, 0, 0, 0],
  },
};

void main() {
  group('Presets d\'orientation — quarterTurns posés (revue finale, C#1)', () {
    for (final entry in _expected.entries) {
      final count = entry.key;

      for (final preset in entry.value.entries) {
        testWidgets(
            '$count joueurs, preset « ${preset.key} » : pose '
            '${preset.value}', (tester) async {
          await _pump(tester, _session(count));
          await _applyPreset(tester, preset.key);

          expect(_rotations(tester), preset.value,
              reason: 'les presets décrivent des quarterTurns finaux : '
                  'PlayerZone est le seul à tourner une zone, aucune '
                  'compensation ne doit être appliquée au passage');
        });
      }

      testWidgets(
          '$count joueurs : la feuille ne propose que les presets distincts',
          (tester) async {
        await _pump(tester, _session(count));
        await tester
            .tap(find.byKey(const ValueKey('orientation_presets_button')));
        await tester.pumpAndSettle();

        for (final label in entry.value.keys) {
          expect(find.byKey(ValueKey('orientation_preset_$label')), findsOneWidget,
              reason: '$count joueurs : le preset « $label » doit être proposé');
        }
        // « Face à face » ne doit apparaître QUE là où il diffère de
        // « Table » : à 2-3 joueurs et au-delà de 6, `seatsFor` EST déjà le
        // face-à-face, et deux vignettes identiques mentiraient sur le choix
        // réellement offert.
        if (!entry.value.containsKey('Face à face')) {
          expect(find.byKey(const ValueKey('orientation_preset_Face à face')),
              findsNothing,
              reason: '$count joueurs : « Face à face » est identique à '
                  '« Table », il ne doit pas être proposé deux fois');
        }
      });
    }

    testWidgets(
        '4 joueurs : « Même sens » laisse les quatre zones à zéro, sans '
        'compensation de 180° sur la moitié haute', (tester) async {
      // Le constat CRITICAL #1 dans sa forme exacte : avant correction, ce
      // chemin posait [2, 2, 0, 0].
      await _pump(tester, _session(4));
      await _applyPreset(tester, 'Même sens');
      expect(_rotations(tester), [0, 0, 0, 0]);
    });

    testWidgets(
        '4 joueurs : « Table » et « Face à face » ne posent pas la même '
        'chose', (tester) async {
      // Discrimination : si les deux presets convergeaient, tous les tests
      // ci-dessus passeraient sur un modèle purement haut/bas.
      await _pump(tester, _session(4));
      await _applyPreset(tester, 'Table');
      final table = _rotations(tester);
      await _applyPreset(tester, 'Face à face');
      final faceToFace = _rotations(tester);
      expect(table, isNot(faceToFace));
    });
  });
}
