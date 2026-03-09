// Fichier : lib/router/app_router.dart
// Configuration centralisee go_router (Sprint 5)
// Sprint 14, US-14.6 : Dashboard Home remplace LifeCounter en tab0.
// Sprint 14, US-14.8 : Transitions FadeThrough (tabs) et SharedAxis (push).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/onboarding/onboarding_page.dart';
import 'app_routes.dart';
import 'app_shell_scaffold.dart';
import 'cards_routes.dart';
import 'collections_routes.dart';
import 'dashboard_routes.dart';
import 'decks_routes.dart';
import 'life_counter_routes.dart';
import 'scanner_routes.dart';
import 'settings_routes.dart';
import 'tools_routes.dart';

// Re-export AppRoutes pour que les fichiers existants qui importent
// app_router.dart continuent de fonctionner.
export 'app_routes.dart';

/// Cree et configure le GoRouter de l'application.
/// US-14.4 : Ajoute la route onboarding et le redirect conditionnel.
/// US-14.6 : Dashboard Home en tab0, LifeCounter dans le Drawer.
GoRouter createAppRouter() {
  // --- Egg: Log Pose --- Message secret au demarrage du routeur (debug only)
  assert(() {
    debugPrint('');
    debugPrint('  [LOG POSE] Cap sur la prochaine ile...');
    debugPrint('  [LOG POSE] Routes chargees. Le Grand Line est ouvert.');
    debugPrint('  [LOG POSE] "La mer est vaste, et les routes sont infinies."');
    debugPrint('');
    return true;
  }());

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: kDebugMode,
    redirect: _onboardingRedirect,
    routes: [
      // US-14.4 : Route onboarding
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),

      // Shell route pour le BottomNavigationBar + Drawer
      ShellRoute(
        builder: (context, state, child) {
          return AppShellScaffold(
            currentLocation: state.uri.toString(),
            child: child,
          );
        },
        routes: [
          // US-14.6 : Dashboard Home en tab0 (remplace lifeCounterShellRoute)
          dashboardShellRoute(),
          scannerShellRoute(),
          cardSearchShellRoute(),
          deckShellRoute(),
          collectionShellRoute(),
        ],
      ),

      // --- Routes par domaine (push par-dessus le shell) ---
      // US-14.6 : LifeCounter est maintenant une route Drawer (dans lifeCounterRoutes)
      ...lifeCounterRoutes(),
      ...toolsRoutes(),
      ...settingsRoutes(),
      ...cardDetailRoutes(),
      ...scannerDetailRoutes(),
      ...collectionDetailRoutes(),
      ...deckDetailRoutes(),
    ],
  );
}

/// Cache du statut onboarding pour eviter les lectures SharedPreferences repetees.
bool? _hasSeenOnboardingCache;

/// Redirect conditionnel vers l'onboarding si l'utilisateur ne l'a pas encore vu.
Future<String?> _onboardingRedirect(
    BuildContext context, GoRouterState state) async {
  // Si on est deja sur la page onboarding, pas de redirect
  if (state.uri.toString() == AppRoutes.onboarding) return null;

  // Utilise le cache en memoire pour eviter les I/O repetees
  if (_hasSeenOnboardingCache == true) return null;

  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool(kHasSeenOnboarding) ?? false;
  _hasSeenOnboardingCache = hasSeenOnboarding;

  if (!hasSeenOnboarding) return AppRoutes.onboarding;
  return null;
}
