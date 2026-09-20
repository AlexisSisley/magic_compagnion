// Fichier : lib/router/home_routes.dart
// Branche Accueil du shell : la racine, plus l'historique des parties, qui
// s'y consulte apres avoir joue.

import 'package:go_router/go_router.dart';

import '../models/game_history_model.dart';
import '../pages/home/home_page.dart';
import '../pages/life_counter/game_history_detail_page.dart';
import '../pages/life_counter/game_history_page.dart';
import 'app_routes.dart';
import 'card_detail_route.dart';
import 'page_transitions.dart';

GoRoute homeBranchRoute() {
  return GoRoute(
    path: AppRoutes.home,
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const HomePage(),
    ),
    routes: [
      GoRoute(
        path: 'game-history',
        builder: (context, state) => const GameHistoryPage(),
        routes: [
          GoRoute(
            path: 'detail',
            builder: (context, state) =>
                GameHistoryDetailPage(game: state.extra as GameHistoryItem),
          ),
        ],
      ),
      // La fiche carte s'ouvre aussi depuis l'historique d'une partie : sans
      // elle ici, ce chemin sortirait du shell.
      cardDetailRoute(),
    ],
  );
}
