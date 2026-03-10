// Tests pour la configuration go_router (Sprint 5)

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/router/app_router.dart';

void main() {
  group('AppRoutes constants', () {
    test('all route paths start with /', () {
      final routes = [
        AppRoutes.dashboard,
        AppRoutes.lifeCounter,
        AppRoutes.scanner,
        AppRoutes.search,
        AppRoutes.decks,
        AppRoutes.collection,
        AppRoutes.gameHistory,
        AppRoutes.tournament,
        AppRoutes.oracle,
        AppRoutes.grimoire,
        AppRoutes.calculator,
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
        AppRoutes.dashboard,
        AppRoutes.lifeCounter,
        AppRoutes.scanner,
        AppRoutes.search,
        AppRoutes.decks,
        AppRoutes.collection,
        AppRoutes.gameHistory,
        AppRoutes.tournament,
        AppRoutes.oracle,
        AppRoutes.grimoire,
        AppRoutes.calculator,
        AppRoutes.glossary,
        AppRoutes.turnGuide,
        AppRoutes.profiles,
        AppRoutes.settings,
      ];

      final uniqueRoutes = routes.toSet();
      expect(uniqueRoutes.length, routes.length, reason: 'All routes should be unique');
    });

    test('tab routes match expected paths', () {
      // US-LC01 : LifeCounter est tab0 (route '/'), Dashboard est dans le Drawer
      expect(AppRoutes.lifeCounter, '/');
      expect(AppRoutes.scanner, '/scanner');
      expect(AppRoutes.search, '/search');
      expect(AppRoutes.decks, '/decks');
      expect(AppRoutes.collection, '/collection');
    });

    test('drawer routes have meaningful paths', () {
      expect(AppRoutes.dashboard, '/dashboard');
      expect(AppRoutes.gameHistory, '/game-history');
      expect(AppRoutes.tournament, '/tournament');
      expect(AppRoutes.oracle, '/oracle');
      expect(AppRoutes.calculator, '/calculator');
      expect(AppRoutes.glossary, '/glossary');
      expect(AppRoutes.profiles, '/profiles');
      expect(AppRoutes.settings, '/settings');
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

    test('initial location is life counter', () {
      final router = createAppRouter();
      expect(router.routeInformationProvider.value.uri.path, '/');
    });
  });
}
