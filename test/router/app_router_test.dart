// Tests pour la configuration go_router (Sprint 5)

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/router/app_router.dart';

void main() {
  group('AppRoutes constants', () {
    test('all route paths start with /', () {
      final routes = [
        AppRoutes.home,
        AppRoutes.scanner,
        AppRoutes.search,
        AppRoutes.decks,
        AppRoutes.collection,
        AppRoutes.gameHistory,
        AppRoutes.play,
        AppRoutes.playSetup,
        AppRoutes.playCounter,
        AppRoutes.playTournament,
        AppRoutes.playOracle,
        AppRoutes.playGlossary,
        AppRoutes.playOdds,
        AppRoutes.grimoire,
        AppRoutes.glossary,
        AppRoutes.turnGuide,
        AppRoutes.profiles,
        AppRoutes.settings,
      ];

      for (final route in routes) {
        expect(route.startsWith('/'), isTrue, reason: 'Route $route should start with /');
      }
    });

    test('all route paths are unique', () {
      final routes = [
        AppRoutes.home,
        AppRoutes.scanner,
        AppRoutes.search,
        AppRoutes.decks,
        AppRoutes.collection,
        AppRoutes.gameHistory,
        AppRoutes.play,
        AppRoutes.playSetup,
        AppRoutes.playCounter,
        AppRoutes.playTournament,
        AppRoutes.playOracle,
        AppRoutes.playGlossary,
        AppRoutes.playOdds,
        AppRoutes.grimoire,
        AppRoutes.glossary,
        AppRoutes.turnGuide,
        AppRoutes.profiles,
        AppRoutes.settings,
      ];

      final uniqueRoutes = routes.toSet();
      expect(uniqueRoutes.length, routes.length, reason: 'All routes should be unique');
    });

    test("les routes d'onglet sont celles du shell a cinq branches", () {
      expect(AppRoutes.home, '/');
      expect(AppRoutes.scanner, '/scanner');
      expect(AppRoutes.search, '/search');
      expect(AppRoutes.decks, '/decks');
      expect(AppRoutes.collection, '/collection');
    });

    // Plus de test "drawer routes" : le Drawer n'existe plus. Ces adresses
    // survivent, mais atteintes depuis les Reglages ou l'Accueil.
    test('les ecrans sortis du tiroir ont garde leur adresse', () {
      expect(AppRoutes.gameHistory, '/game-history');
      expect(AppRoutes.glossary, '/glossary');
      expect(AppRoutes.profiles, '/profiles');
      expect(AppRoutes.settings, '/settings');
    });

    // Tournoi, Oracle et Calculateur ont quitte le tiroir pour le mode Jeu :
    // ils ne s'utilisent qu'une partie en cours. Le glossaire, lui, garde sa
    // route hors /play -- il se consulte aussi a froid.
    test('les outils de partie ont demenage sous /play', () {
      expect(AppRoutes.playTournament, '/play/tournament');
      expect(AppRoutes.playOracle, '/play/oracle');
      expect(AppRoutes.playOdds, '/play/odds');
    });

    test('turn guide is nested under glossary', () {
      expect(AppRoutes.turnGuide, startsWith(AppRoutes.glossary));
    });
  });

  group('createAppRouter', () {
    test('router is created successfully', () {
      final router = createAppRouter();
      expect(router, isNotNull);
    });

    test("l'app s'ouvre sur l'Accueil", () {
      final router = createAppRouter();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
    });
  });
}
