// Fichier : test/pages/home/home_page_test.dart
// L'Accueil : ce qu'on voit hors partie, et la porte d'entree du mode Jeu.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/pages/home/home_page.dart';
import 'package:magic_companion/providers/active_game_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/router/app_routes.dart';
import 'package:magic_companion/router/home_routes.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_game_session.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  /// Surface haute : l'Accueil empile un en-tete, le tableau de bord et un
  /// bouton. Sur un gabarit telephone, le bouton du bas deborderait et le
  /// test echouerait pour une raison sans rapport avec ce qu'il mesure.
  void surfaceHaute(WidgetTester tester) {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget harness({required Future<GameSession?> Function() partie}) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeGameProvider.overrideWith((ref) async => partie()),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
      );

  testWidgets('sans partie en cours, propose de lancer une partie',
      (tester) async {
    surfaceHaute(tester);
    await tester.pumpWidget(harness(partie: () async => null));
    await tester.pump();

    expect(find.text('Lancer une partie'), findsOneWidget);
    expect(find.text('Reprendre la partie'), findsNothing);
  });

  testWidgets('avec une partie en cours, propose de la reprendre',
      (tester) async {
    surfaceHaute(tester);
    await tester.pumpWidget(harness(partie: () async => buildTestSession()));
    await tester.pump();

    expect(find.text('Reprendre la partie'), findsOneWidget);
    expect(find.text('Lancer une partie'), findsNothing,
        reason: 'une seule action principale : reprendre OU lancer');
  });

  testWidgets('porte un acces aux reglages', (tester) async {
    surfaceHaute(tester);
    await tester.pumpWidget(harness(partie: () async => null));
    await tester.pump();

    expect(find.byTooltip('Reglages'), findsOneWidget);
  });

  test('la branche Accueil est greffee a la racine du router', () {
    // Sans ca, HomePage serait un ecran que rien n'ouvre.
    final route = homeBranchRoute();

    expect(route.path, AppRoutes.home);
    final sousRoutes =
        route.routes.whereType<GoRoute>().map((r) => r.path).toList();
    expect(sousRoutes, contains('card'),
        reason: "la fiche carte doit etre greffee dans la branche Accueil, "
            "sinon l'ouvrir depuis l'historique sortirait du shell");
    expect(sousRoutes, contains('game-history'));
  });

  testWidgets('les trois outils de regles sont atteignables hors partie',
      (tester) async {
    // Sans cette rangee, poser une question de regles exigerait de creer ou
    // de reprendre une partie : les outils ne vivent que sous /play.
    surfaceHaute(tester);
    await tester.pumpWidget(harness(partie: () async => null));
    await tester.pump();

    for (final outil in ['Oracle', 'Règles', 'Probas']) {
      expect(find.text(outil), findsOneWidget,
          reason: "$outil doit etre atteignable depuis l'Accueil");
    }
  });
}
