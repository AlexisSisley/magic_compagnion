// Fichier : lib/router/life_counter_routes.dart
// Routes liees au compteur de vie et a l'historique des parties.
// Sprint 14, US-14.6 : LifeCounter n'est plus un shell tab,
// c'est une route Drawer (push par-dessus le shell).

import 'package:go_router/go_router.dart';

import '../models/game_history_model.dart';
import '../pages/life_counter/game_history_detail_page.dart';
import '../pages/life_counter/game_history_page.dart';
import '../pages/life_counter/life_counter_page.dart';
import 'app_routes.dart';

/// Routes drawer et detail pour le compteur de vie.
/// US-14.6 : Inclut desormais la route du LifeCounter lui-meme.
List<RouteBase> lifeCounterRoutes() {
  return [
    GoRoute(
      path: AppRoutes.lifeCounter,
      builder: (context, state) => const LifeCounterPage(),
    ),
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
