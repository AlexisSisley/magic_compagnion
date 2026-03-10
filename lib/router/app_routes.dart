// Fichier : lib/router/app_routes.dart
// Constantes de chemins de routes et helper de navigation.
// Sprint 15, US-LC01 : tab0 = Life Counter (initialLocation), Dashboard -> Drawer.

/// Noms de routes pour navigation type-safe.
class AppRoutes {
  // Onboarding (Sprint 14, US-14.4)
  static const String onboarding = '/onboarding';

  // Onglets principaux (shell) - US-LC01 : LifeCounter devient tab0
  static const String lifeCounter = '/';
  static const String scanner = '/scanner';
  static const String search = '/search';
  static const String decks = '/decks';
  static const String collection = '/collection';

  // Drawer routes - US-LC03 : Dashboard descend dans le Drawer
  static const String dashboard = '/dashboard';
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
/// US-LC01 : tab0 = Life Counter, les autres restent identiques.
int locationToTabIndex(String location) {
  if (location.startsWith('/scanner')) return 1;
  if (location.startsWith('/search')) return 2;
  if (location.startsWith('/decks')) return 3;
  if (location.startsWith('/collection')) return 4;
  return 0;
}
