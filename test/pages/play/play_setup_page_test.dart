// Fichier : test/pages/play/play_setup_page_test.dart
// L'ecran de mise en place, et surtout : la preuve qu'il est atteignable.
// Un ecran correct que rien ne route est le piege recurrent de ce depot.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/pages/play/play_setup_page.dart';
import 'package:magic_companion/providers/active_game_provider.dart';
import 'package:magic_companion/router/app_router.dart';
import 'package:magic_companion/router/app_routes.dart';
import 'package:magic_companion/theme/app_theme.dart';

import '../../support/test_game_session.dart';

void main() {
  // `Override` n'est pas exporte par flutter_riverpod : la surcharge est donc
  // construite sur place plutot que passee en parametre type.
  Widget harness({required Future<GameSession?> Function() partie}) =>
      ProviderScope(
        overrides: [
          activeGameProvider.overrideWith((ref) async => partie()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const PlaySetupPage(),
        ),
      );

  testWidgets("sans partie en cours, pas de bouton de reprise", (tester) async {
    await tester.pumpWidget(harness(partie: () async => null));
    await tester.pumpAndSettle();

    expect(find.text('Démarrer'), findsOneWidget);
    expect(find.text('Reprendre la partie en cours'), findsNothing);
  });

  testWidgets('avec une partie en cours, la reprise est proposee',
      (tester) async {
    await tester.pumpWidget(harness(partie: () async => buildTestSession()));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre la partie en cours'), findsOneWidget);
    // Le bouton de creation reste : on peut vouloir abandonner et repartir.
    expect(find.text('Démarrer'), findsOneWidget);
  });

  testWidgets("l'ecran porte une sortie vers l'accueil", (tester) async {
    await tester.pumpWidget(harness(partie: () async => null));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Fermer'), findsOneWidget);
  });

  test('/play/setup est bien greffee dans le router', () {
    // Sans ca, PlaySetupPage serait un ecran que rien n'ouvre : teste, correct
    // et invisible a l'execution.
    final racines = createAppRouter()
        .configuration
        .routes
        .whereType<GoRoute>()
        .map((r) => r.path)
        .toList();

    expect(racines, contains(AppRoutes.playSetup));
  });
}
