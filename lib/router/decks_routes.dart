// Fichier : lib/router/decks_routes.dart
// Branche Decks du shell : la liste, le detail d'un deck, et la fiche carte
// qu'on ouvre depuis une decklist.

import 'package:go_router/go_router.dart';

import '../models/deck_model.dart';
import '../pages/decks/deck_detail_page.dart';
import '../pages/decks/deck_list_page.dart';
import 'app_routes.dart';
import 'card_detail_route.dart';
import 'page_transitions.dart';

GoRoute decksBranchRoute() {
  return GoRoute(
    path: AppRoutes.decks,
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const DeckListPage(),
    ),
    routes: [
      GoRoute(
        path: 'detail',
        builder: (context, state) =>
            DeckDetailPage(deck: state.extra as Deck),
      ),
      cardDetailRoute(),
    ],
  );
}
