// Fichier : lib/router/life_counter_routes.dart
// Routes liees au compteur de vie et a l'historique des parties.

import 'package:go_router/go_router.dart';

import '../models/game_history_model.dart';
import '../pages/life_counter/game_history_detail_page.dart';
import '../pages/life_counter/game_history_page.dart';
import '../pages/life_counter/life_counter_page.dart';
import 'app_routes.dart';

/// Routes drawer et detail pour le compteur de vie.
List<RouteBase> lifeCounterRoutes() {
  return [
    GoRoute(
      path: AppRoutes.gameHistory,
      builder: (context, state) => const GameHistoryPage(),
    ),
    GoRoute(
      path: AppRoutes.gameHistoryDetail,
      builder: (context, state) {
        final game = state.extra as GameHistoryItem;
        return GameHistoryDetailPage(game: game);
      },
    ),
  ];
}

/// Route shell pour l'onglet compteur de vie.
GoRoute lifeCounterShellRoute() {
  return GoRoute(
    path: '/',
    pageBuilder: (context, state) => const NoTransitionPage(
      child: LifeCounterPage(),
    ),
  );
}
