// Fichier : lib/router/app_routes.dart
// Constantes de chemins de routes et helper de navigation.

/// Noms de routes pour navigation type-safe.
class AppRoutes {
  // Onglets principaux (shell)
  static const String lifeCounter = '/';
  static const String scanner = '/scanner';
  static const String search = '/search';
  static const String decks = '/decks';
  static const String collection = '/collection';

  // Drawer routes
  static const String gameHistory = '/game-history';
  static const String tournament = '/tournament';
  static const String oracle = '/oracle';
  static const String grimoire = '/grimoire';
  static const String calculator = '/calculator';
  static const String glossary = '/glossary';
  static const String turnGuide = '/glossary/turn-guide';
  static const String profiles = '/profiles';
  static const String settings = '/settings';

  // Detail routes (push par-dessus le shell)
  static const String cardDetail = '/cards/detail';
  static const String glossaryDetail = '/glossary/detail';
  static const String globalStats = '/collection/stats';
  static const String setDetail = '/collection/set';
  static const String setStats = '/collection/set/stats';
  static const String wishlistDetail = '/wishlists/detail';
  static const String deckDetail = '/decks/detail';
  static const String gameHistoryDetail = '/game-history/detail';
  static const String scanHistory = '/scanner/history';
}

/// Index des onglets dans le BottomNavigationBar.
int locationToTabIndex(String location) {
  if (location.startsWith('/scanner')) return 1;
  if (location.startsWith('/search')) return 2;
  if (location.startsWith('/decks')) return 3;
  if (location.startsWith('/collection')) return 4;
  return 0;
}
