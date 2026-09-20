// Fichier : test/router/play_routes_test.dart
// Verifie les CONSTANTES d'adresse du mode Jeu : leur forme, leur unicite,
// et qu'elles vivent toutes sous /play.
//
// Ce fichier ne monte aucun routeur et ne prouve donc rien sur l'arbre
// reellement construit -- c'est play_shell_test.dart qui s'en charge, en
// lisant createAppRouter().

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/router/app_routes.dart';

void main() {
  group("constantes d'adresse du mode Jeu", () {
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
