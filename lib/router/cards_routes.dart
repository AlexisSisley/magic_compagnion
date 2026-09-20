// Fichier : lib/router/cards_routes.dart
// Branche Rechercher du shell.
//
// La fiche carte n'a plus d'adresse absolue : elle est greffee en sous-route
// relative dans chacune des cinq branches (lib/router/card_detail_route.dart).

import 'package:go_router/go_router.dart';

import '../pages/cards/card_search_page.dart';
import 'app_routes.dart';
import 'card_detail_route.dart';
import 'page_transitions.dart';

GoRoute searchBranchRoute() {
  return GoRoute(
    path: AppRoutes.search,
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const CardSearchPage(),
    ),
    routes: [
      cardDetailRoute(),
    ],
  );
}
