// Fichier : lib/router/app_router.dart
// Configuration centralis\u00e9e go_router (Sprint 5)
// Les routes sont d\u00e9compos\u00e9es dans des fichiers domaine-sp\u00e9cifiques.

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'app_shell_scaffold.dart';
import 'cards_routes.dart';
import 'collections_routes.dart';
import 'decks_routes.dart';
import 'life_counter_routes.dart';
import 'scanner_routes.dart';
import 'settings_routes.dart';
import 'tools_routes.dart';

// Re-export AppRoutes pour que les fichiers existants qui importent
// app_router.dart continuent de fonctionner.
export 'app_routes.dart';

/// Cr\u00e9e et configure le GoRouter de l'application.
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.lifeCounter,
    debugLogDiagnostics: kDebugMode,
    routes: [
      // Shell route pour le BottomNavigationBar + Drawer
      ShellRoute(
        builder: (context, state, child) {
          return AppShellScaffold(
            currentLocation: state.uri.toString(),
            child: child,
          );
        },
        routes: [
          lifeCounterShellRoute(),
          scannerShellRoute(),
          cardSearchShellRoute(),
          deckShellRoute(),
          collectionShellRoute(),
        ],
      ),

      // --- Routes par domaine (push par-dessus le shell) ---
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
