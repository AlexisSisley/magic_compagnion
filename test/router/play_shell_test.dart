// Fichier : test/router/play_shell_test.dart
// La barre d'outils de partie remplace la barre d'onglets de l'app pendant
// une partie. Ces tests verrouillent les deux moities de cette phrase : les
// cinq outils sont la, et la barre d'onglets n'y est pas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/router/app_router.dart';
import 'package:magic_companion/router/app_routes.dart';
import 'package:magic_companion/router/play_shell.dart';
import 'package:magic_companion/theme/app_theme.dart';

void main() {
  group('playToolIndex', () {
    test('associe chaque route a son outil', () {
      expect(playToolIndex(AppRoutes.playCounter), 0);
      expect(playToolIndex(AppRoutes.playTournament), 1);
      expect(playToolIndex(AppRoutes.playOracle), 2);
      expect(playToolIndex(AppRoutes.playGlossary), 3);
      expect(playToolIndex(AppRoutes.playOdds), 4);
    });

    test('retombe sur le compteur pour une route inconnue', () {
      expect(playToolIndex('/play/inconnu'), 0);
    });
  });

  testWidgets("PlayShell affiche les cinq outils et aucune barre d'onglets app",
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: PlayShell(
        currentLocation: AppRoutes.playCounter,
        child: const Text('contenu'),
      ),
    ));

    expect(find.text('contenu'), findsOneWidget);
    for (final label in ['Vies', 'Tournoi', 'Oracle', 'Regles', 'Fin']) {
      expect(find.text(label), findsOneWidget,
          reason: "$label manque dans la barre d'outils de partie");
    }
    expect(find.byType(BottomNavigationBar), findsNothing,
        reason: "le mode Jeu ne doit pas porter la barre d'onglets de l'app");
  });

  // Le piege recurrent de ce depot : un widget correct, teste, et jamais
  // branche. Les deux tests ci-dessus passeraient meme si playRoutes()
  // n'enveloppait rien. Celui-ci regarde l'arbre que le router construit
  // vraiment.
  group('PlayShell est bien greffe dans le router', () {
    ShellRoute shellDuModeJeu() {
      for (final route in createAppRouter().configuration.routes) {
        if (route is! ShellRoute) continue;
        final chemins = route.routes.whereType<GoRoute>().map((r) => r.path);
        if (chemins.contains(AppRoutes.playCounter)) return route;
      }
      fail('aucun ShellRoute ne porte ${AppRoutes.playCounter} : le mode Jeu '
          "n'a pas de barre d'outils a l'execution");
    }

    test('les cinq outils vivent sous un ShellRoute', () {
      final chemins = shellDuModeJeu()
          .routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(chemins, [
        AppRoutes.playCounter,
        AppRoutes.playTournament,
        AppRoutes.playOracle,
        AppRoutes.playGlossary,
        AppRoutes.playOdds,
      ]);
    });

    testWidgets('ce ShellRoute construit bien un PlayShell', (tester) async {
      // On appelle le `builder` du ShellRoute sans passer par une vraie
      // navigation : monter /play/counter tirerait LifeCounterPage et toute
      // sa chaine de services. Ce qu'on veut savoir ici est plus etroit --
      // la route monte-t-elle la bonne chose -- et ca se lit sur le type
      // produit.
      final shell = shellDuModeJeu();
      late Widget produit;

      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Builder(builder: (context) {
          produit = shell.builder!(
            context,
            GoRouterState(
              createAppRouter().configuration,
              uri: Uri.parse(AppRoutes.playCounter),
              matchedLocation: AppRoutes.playCounter,
              fullPath: AppRoutes.playCounter,
              pathParameters: const {},
              pageKey: const ValueKey('play'),
            ),
            const SizedBox.shrink(),
          );
          return const SizedBox.shrink();
        }),
      ));

      expect(produit, isA<PlayShell>());
      expect((produit as PlayShell).currentLocation, AppRoutes.playCounter);
    });
  });
}
