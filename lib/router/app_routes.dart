// Fichier : lib/router/app_routes.dart
// Constantes de chemins de routes et helper de navigation.
// Sprint 15, US-LC01 : tab0 = Life Counter (initialLocation), Dashboard -> Drawer.

/// Noms de routes pour navigation type-safe.
class AppRoutes {
  // Onboarding (Sprint 14, US-14.4)
  static const String onboarding = '/onboarding';

  // Onglets principaux du shell a cinq branches.
  //
  // `lifeCounter` a disparu : le compteur a quitte la racine pour
  // /play/counter, et l'Accueil l'a prise.
  static const String home = '/';
  static const String scanner = '/scanner';
  static const String search = '/search';
  static const String decks = '/decks';
  static const String collection = '/collection';

  // Mode Jeu (plein ecran, hors shell). Regroupe tout ce qui s'utilise
  // carte en main : le compteur, et les quatre outils qui etaient dans le
  // Drawer.
  /// PREFIXE seulement : aucune GoRoute ne repond a '/play' tout court.
  /// Y naviguer donnerait la page d'erreur de go_router. Le point
  /// d'entree du mode Jeu est [playSetup].
  static const String play = '/play';
  static const String playSetup = '/play/setup';
  static const String playCounter = '/play/counter';
  static const String playTournament = '/play/tournament';
  static const String playOracle = '/play/oracle';
  static const String playGlossary = '/play/glossary';
  static const String playOdds = '/play/odds';

  // Routes hors shell. Le Drawer qui y menait a disparu : elles sont
  // desormais atteintes depuis les Reglages ou l'Accueil.
  static const String gameHistory = '/game-history';
  static const String grimoire = '/grimoire';

  // `glossary` reste : le glossaire est aussi consultable a froid depuis
  // l'onglet Rechercher, pas seulement en partie (spec 6.1). `tournament`,
  // `oracle` et `calculator` ont disparu -- ces trois ecrans ne s'utilisent
  // que sur place, donc uniquement sous /play.
  static const String glossary = '/glossary';
  static const String turnGuide = '/glossary/turn-guide';
  static const String profiles = '/profiles';
  static const String settings = '/settings';

  // Detail routes (push par-dessus le shell)
  //
  // `cardDetail` a disparu : la fiche carte n'a plus d'adresse absolue. Elle
  // est greffee en sous-route relative dans chacune des cinq branches, et se
  // pousse par `pushCardDetail()` (lib/router/card_detail_route.dart).
  static const String glossaryDetail = '/glossary/detail';
  static const String globalStats = '/collection/stats';
  static const String setDetail = '/collection/set';
  static const String setStats = '/collection/set/stats';
  // Passe sous la branche Collection : une wishlist s'ouvre depuis la
  // collection, et la laisser a la racine la ferait sortir du shell.
  static const String wishlistDetail = '/collection/wishlist-detail';
  static const String deckDetail = '/decks/detail';
  static const String gameHistoryDetail = '/game-history/detail';
  static const String scanHistory = '/scanner/history';
  static const String tableView = '/table-view';
}

/// Index des onglets dans le BottomNavigationBar.
/// US-LC01 : tab0 = Life Counter, les autres restent identiques.
int locationToTabIndex(String location) {
  if (location.startsWith('/scanner')) return 1;
  if (location.startsWith('/search')) return 2;
  if (location.startsWith('/decks')) return 3;
  if (location.startsWith('/collection')) return 4;
  return 0;
}
