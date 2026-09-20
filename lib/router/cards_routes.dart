// Fichier : lib/router/cards_routes.dart
// Routes liees aux cartes.
//
// La fiche carte n'est plus ici : elle n'a plus d'adresse absolue, et vit
// desormais en sous-route relative dans chacune des cinq branches du shell
// (lib/router/card_detail_route.dart).

import 'package:go_router/go_router.dart';

import '../pages/cards/card_search_page.dart';
import 'page_transitions.dart';

/// Route shell pour l'onglet recherche de cartes.
GoRoute cardSearchShellRoute() {
  return GoRoute(
    path: '/search',
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const CardSearchPage(),
    ),
  );
}
