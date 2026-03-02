// Fichier : lib/router/cards_routes.dart
// Routes liees aux cartes (recherche, detail).

import 'package:go_router/go_router.dart';

import '../pages/cards/card_detail_page.dart';
import '../pages/cards/card_search_page.dart';
import 'app_routes.dart';

/// Routes de detail pour les cartes (push par-dessus le shell).
List<RouteBase> cardDetailRoutes() {
  return [
    GoRoute(
      path: AppRoutes.cardDetail,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return RecognitionResultPage(
          cardName: extra?['cardName'] as String?,
          imagePath: extra?['imagePath'] as String?,
          isContinuousScan: extra?['isContinuousScan'] as bool? ?? false,
        );
      },
    ),
  ];
}

/// Route shell pour l'onglet recherche de cartes.
GoRoute cardSearchShellRoute() {
  return GoRoute(
    path: '/search',
    pageBuilder: (context, state) => const NoTransitionPage(
      child: CardSearchPage(),
    ),
  );
}
