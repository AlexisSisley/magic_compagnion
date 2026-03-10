// Fichier : lib/router/life_counter_routes.dart
// Routes liees au compteur de vie et a l'historique des parties.
// Sprint 15, US-LC01 : LifeCounter redevient un shell tab (tab0).
// US-LC02 : Mode fullscreen sans AppBar dans le shell.

import 'package:go_router/go_router.dart';

import '../models/game_history_model.dart';
import '../pages/life_counter/game_history_detail_page.dart';
import '../pages/life_counter/game_history_page.dart';
import '../pages/life_counter/life_counter_page.dart';
import 'app_routes.dart';
import 'page_transitions.dart';

/// Route shell pour l'onglet Life Counter (tab0).
/// US-LC01 : Life Counter comme ecran d'accueil.
GoRoute lifeCounterShellRoute() {
  return GoRoute(
    path: '/',
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const LifeCounterPage(isInShell: true),
    ),
  );
}

/// Routes detail pour le life counter (push par-dessus le shell).
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
