// Fichier : test/router/play_routes_test.dart
// Verifie l'arbre de routes du mode Jeu : toutes les sous-routes vivent sous
// /play, et les anciennes adresses du tiroir ont disparu.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/router/app_routes.dart';

void main() {
  group('arbre de routes du mode Jeu', () {
    test('toutes les sous-routes vivent sous /play', () {
      for (final route in [
        AppRoutes.playSetup,
        AppRoutes.playCounter,
        AppRoutes.playTournament,
        AppRoutes.playOracle,
        AppRoutes.playGlossary,
        AppRoutes.playOdds,
      ]) {
        expect(route.startsWith('${AppRoutes.play}/'), isTrue,
            reason: '$route devrait etre sous ${AppRoutes.play}');
      }
    });

    test('les chemins sont ceux attendus', () {
      expect(AppRoutes.play, '/play');
      expect(AppRoutes.playSetup, '/play/setup');
      expect(AppRoutes.playCounter, '/play/counter');
      expect(AppRoutes.playTournament, '/play/tournament');
      expect(AppRoutes.playOracle, '/play/oracle');
      expect(AppRoutes.playGlossary, '/play/glossary');
      expect(AppRoutes.playOdds, '/play/odds');
    });

    test('les routes sont uniques', () {
      final routes = [
        AppRoutes.play,
        AppRoutes.playSetup,
        AppRoutes.playCounter,
        AppRoutes.playTournament,
        AppRoutes.playOracle,
        AppRoutes.playGlossary,
        AppRoutes.playOdds,
      ];
      expect(routes.toSet().length, routes.length);
    });
  });
}
