// Fichier : lib/router/decks_routes.dart
// Routes liees aux decks (liste, detail).

import 'package:go_router/go_router.dart';

import '../models/deck_model.dart';
import '../pages/decks/deck_detail_page.dart';
import '../pages/decks/deck_list_page.dart';
import 'app_routes.dart';

/// Routes de detail pour les decks (push par-dessus le shell).
List<RouteBase> deckDetailRoutes() {
  return [
    GoRoute(
      path: AppRoutes.deckDetail,
      builder: (context, state) {
        final deck = state.extra as Deck;
        return DeckDetailPage(deck: deck);
      },
    ),
  ];
}

/// Route shell pour l'onglet decks.
GoRoute deckShellRoute() {
  return GoRoute(
    path: '/decks',
    pageBuilder: (context, state) => const NoTransitionPage(
      child: DeckListPage(),
    ),
  );
}
