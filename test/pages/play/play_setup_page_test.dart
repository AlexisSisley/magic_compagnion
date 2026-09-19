// Fichier : test/pages/play/play_setup_page_test.dart
// L'ecran de mise en place, et surtout : la preuve qu'il est atteignable.
// Un ecran correct que rien ne route est le piege recurrent de ce depot.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/pages/play/play_setup_page.dart';
import 'package:magic_companion/providers/active_game_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/router/app_router.dart';
import 'package:magic_companion/router/app_routes.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/life_counter/game_setup_modal.dart';

import '../../support/test_game_session.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // La feuille de configuration, ouverte au montage, lit les profils donc
    // la base. Sans cette surcharge, chaque test construit une AppDatabase
    // reelle -- drift proteste, et le test touche le disque pour rien.
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  // `Override` n'est pas exporte par flutter_riverpod : la surcharge est donc
  // construite sur place plutot que passee en parametre type.
  Widget harness({required Future<GameSession?> Function() partie}) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
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

    // La feuille de configuration s'ouvre au montage (ruling 14) : on la
    // referme pour retrouver l'etat vide de la page derriere elle.
    await _fermerLaFeuille(tester);

    expect(find.text('Configurer la partie'), findsOneWidget);
    expect(find.text('Reprendre la partie en cours'), findsNothing);
  });

  testWidgets('avec une partie en cours, la reprise est proposee',
      (tester) async {
    await tester.pumpWidget(harness(partie: () async => buildTestSession()));
    await tester.pumpAndSettle();

    await _fermerLaFeuille(tester);

    expect(find.text('Reprendre la partie en cours'), findsOneWidget);
    // Le bouton de configuration reste : on peut vouloir repartir de zero.
    expect(find.text('Configurer la partie'), findsOneWidget);
  });

  testWidgets("l'ecran porte une sortie vers l'accueil", (tester) async {
    await tester.pumpWidget(harness(partie: () async => null));
    await tester.pumpAndSettle();
    await _fermerLaFeuille(tester);

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

  testWidgets("la feuille de configuration s'ouvre au montage",
      (tester) async {
    // Ruling 14 : sans ca, l'ecran annonce une configuration qu'il n'offre
    // aucun moyen de faire.
    await tester.pumpWidget(harness(partie: () async => null));
    await tester.pumpAndSettle();

    expect(find.byType(GameSetupModal), findsOneWidget);
  });
}

/// Referme la feuille ouverte au montage, pour inspecter la page derriere.
Future<void> _fermerLaFeuille(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
  navigator.pop();
  await tester.pumpAndSettle();
}
