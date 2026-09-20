// Fichier : lib/router/collections_routes.dart
// Branche Collection du shell : la collection, ses statistiques, le detail
// d'une edition, une wishlist, et la fiche carte.
//
// `wishlist-detail` est la seule constante dont la VALEUR change :
// '/wishlists/detail' devient '/collection/wishlist-detail'. Une wishlist se
// consulte depuis la collection ; la laisser a la racine la ferait sortir du
// shell, donc disparaitre la barre d'onglets.

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
import 'card_detail_route.dart';
import 'page_transitions.dart';

GoRoute collectionBranchRoute() {
  return GoRoute(
    path: AppRoutes.collection,
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const CollectionPage(),
    ),
    routes: [
      GoRoute(
        path: 'stats',
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
        path: 'set',
        builder: (context, state) =>
            SetDetailPage(set: state.extra as ScryfallSet),
        routes: [
          GoRoute(
            path: 'stats',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return SetStatsPage(
                targetSet: extra['targetSet'] as ScryfallSet,
                myCollection: extra['myCollection'] as List<DeckCard>,
                fullSetData: extra['fullSetData'] as List<ScryfallCard>,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: 'wishlist-detail',
        builder: (context, state) =>
            WishlistDetailPage(wishlist: state.extra as Wishlist),
      ),
      cardDetailRoute(),
    ],
  );
}
