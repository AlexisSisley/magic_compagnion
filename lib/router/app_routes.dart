// Fichier : lib/router/app_routes.dart
// Constantes de chemins de routes et helper de navigation.
// Sprint 14, US-14.6 : tab0 = Dashboard Home, LifeCounter -> Drawer.

/// Noms de routes pour navigation type-safe.
class AppRoutes {
  // Onboarding (Sprint 14, US-14.4)
  static const String onboarding = '/onboarding';

  // Onglets principaux (shell) - US-14.6 : Dashboard remplace le Compteur
  static const String dashboard = '/';
  static const String scanner = '/scanner';
  static const String search = '/search';
  static const String decks = '/decks';
  static const String collection = '/collection';

  // Drawer routes - US-14.6 : LifeCounter descend dans le Drawer
  static const String lifeCounter = '/life-counter';
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
/// US-14.6 : tab0 = Dashboard, les autres restent identiques.
int locationToTabIndex(String location) {
  if (location.startsWith('/scanner')) return 1;
  if (location.startsWith('/search')) return 2;
  if (location.startsWith('/decks')) return 3;
  if (location.startsWith('/collection')) return 4;
  return 0;
}
