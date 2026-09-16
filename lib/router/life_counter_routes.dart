// Fichier : lib/router/life_counter_routes.dart
// Routes liees au compteur de vie et a l'historique des parties.
// Sprint 15, US-LC01 : LifeCounter redevient un shell tab (tab0).
// US-LC02 : Mode fullscreen sans AppBar dans le shell.

import 'package:go_router/go_router.dart';

import '../models/game_history_model.dart';
import '../pages/life_counter/game_history_detail_page.dart';
import '../pages/life_counter/game_history_page.dart';
import '../pages/life_counter/life_counter_page.dart';
import '../pages/life_counter/table_view_page.dart';
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
    // Tache 4 (ronde de correction 1) : route declarative comme le reste des
    // ecrans plein-page pousses par-dessus le shell (game-history, etc.),
    // au lieu d'un Navigator.push/MaterialPageRoute isole. Hors du
    // ShellRoute -- comme ses voisines ci-dessus -- donc aucune chrome de
    // shell (bottom nav) ne s'ajoute par-dessus, et LifeCounterPage reste
    // monte (pas de dispose()) pendant l'empilement : le mode immersif et le
    // wakelock qu'elle pose dans initState() survivent au push/pop, comme
    // ils survivent deja a la navigation vers /game-history.
    GoRoute(
      path: AppRoutes.tableView,
      builder: (context, state) => const TableViewPage(),
    ),
  ];
}
