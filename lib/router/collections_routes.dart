// Fichier : lib/router/collections_routes.dart
// Routes liees aux collections, sets et wishlists.

import 'package:go_router/go_router.dart';

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../models/scryfall_set_model.dart';
import '../models/wishlist_model.dart';
import '../pages/collections/collection_page.dart';
import '../pages/collections/global_stats_page.dart';
import '../pages/collections/set_detail_page.dart';
import '../pages/collections/set_stats_page.dart';
import '../pages/wishlists/wishlist_detail_page.dart';
import 'app_routes.dart';

/// Routes de detail pour les collections (push par-dessus le shell).
List<RouteBase> collectionDetailRoutes() {
  return [
    GoRoute(
      path: AppRoutes.globalStats,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return GlobalStatsPage(
          collection: extra['collection'] as List<DeckCard>,
          fullCardData: extra['fullCardData'] as List<ScryfallCard>,
          totalValue: extra['totalValue'] as double,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.setDetail,
      builder: (context, state) {
        final set = state.extra as ScryfallSet;
        return SetDetailPage(set: set);
      },
    ),
    GoRoute(
      path: AppRoutes.setStats,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return SetStatsPage(
          targetSet: extra['targetSet'] as ScryfallSet,
          myCollection: extra['myCollection'] as List<DeckCard>,
          fullSetData: extra['fullSetData'] as List<ScryfallCard>,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.wishlistDetail,
      builder: (context, state) {
        final wishlist = state.extra as Wishlist;
        return WishlistDetailPage(wishlist: wishlist);
      },
    ),
  ];
}

/// Route shell pour l'onglet collection.
GoRoute collectionShellRoute() {
  return GoRoute(
    path: '/collection',
    pageBuilder: (context, state) => const NoTransitionPage(
      child: CollectionPage(),
    ),
  );
}
