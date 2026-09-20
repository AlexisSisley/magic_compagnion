// Fichier : test/router/shell_branches_test.dart
// Verrouille la structure a cinq branches. Une regression de navigation est
// invisible aux tests unitaires d'ecran : ces assertions sont le seul filet.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/router/app_router.dart';

void main() {
  StatefulShellRoute findShell(List<RouteBase> routes) {
    for (final route in routes) {
      if (route is StatefulShellRoute) return route;
    }
    fail('aucune StatefulShellRoute a la racine du router');
  }

  group('structure du shell', () {
    test('le shell porte exactement cinq branches', () {
      final shell = findShell(createAppRouter().configuration.routes);
      expect(shell.branches.length, 5);
    });

    test("les racines de branche sont dans l'ordre attendu", () {
      final shell = findShell(createAppRouter().configuration.routes);
      final roots =
          shell.branches.map((b) => (b.routes.first as GoRoute).path).toList();

      expect(roots, ['/', '/scanner', '/search', '/decks', '/collection']);
    });

    test('chaque branche porte la sous-route de fiche carte', () {
      final shell = findShell(createAppRouter().configuration.routes);

      for (final branch in shell.branches) {
        final root = branch.routes.first as GoRoute;
        final hasCard =
            root.routes.whereType<GoRoute>().any((r) => r.path == 'card');
        expect(hasCard, isTrue,
            reason: 'la branche ${root.path} ne peut pas ouvrir de fiche carte '
                'sans sortir du shell');
      }
    });
  });

  group('plus aucune route de detail a la racine', () {
    test("les racines sont le shell, l'onboarding et le mode Jeu", () {
      final roots = createAppRouter()
          .configuration
          .routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      for (final leaked in [
        '/dashboard',
        '/game-history',
        '/decks/detail',
        '/collection/set',
        '/cards/detail',
      ]) {
        expect(roots, isNot(contains(leaked)),
            reason: '$leaked doit vivre dans une branche, pas a la racine');
      }
    });
  });
}
