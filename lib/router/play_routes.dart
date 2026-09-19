// Fichier : lib/router/play_routes.dart
// Routes du mode Jeu. Plein ecran, hors du shell d'onglets : pendant une
// partie, le telephone est pose sur la table et la barre d'onglets n'a rien
// a y faire.
//
// Ces ecrans venaient du Drawer (tournoi, oracle, glossaire, calculateur) ou
// de l'onglet 0 (compteur). Ils sont deplaces, pas reecrits.

import 'package:go_router/go_router.dart';

import '../pages/glossary/glossary_page.dart';
import '../pages/life_counter/life_counter_page.dart';
import '../pages/oracle/magic_oracle_page.dart';
import '../pages/tools/hypergeometric_page.dart';
import '../pages/tournaments/tournament_page.dart';
import 'app_routes.dart';

/// Routes du mode Jeu, greffees a la racine du router (hors ShellRoute).
///
/// Plates pour l'instant : la barre d'outils de partie qui les enveloppera
/// arrive a la tache suivante, et l'ecran de mise en place (`/play/setup`) a
/// celle d'apres. Les cinq outils sont deja atteignables des maintenant, ce
/// qui evite de laisser une tache intermediaire avec des routes qui ne
/// compilent pas.
List<RouteBase> playRoutes() {
  return [
    GoRoute(
      path: AppRoutes.playCounter,
      builder: (context, state) => const LifeCounterPage(isInShell: true),
    ),
    GoRoute(
      path: AppRoutes.playTournament,
      builder: (context, state) => const TournamentPage(),
    ),
    GoRoute(
      path: AppRoutes.playOracle,
      builder: (context, state) => const MagicOraclePage(),
    ),
    GoRoute(
      path: AppRoutes.playGlossary,
      builder: (context, state) => const GlossaryPage(),
    ),
    GoRoute(
      path: AppRoutes.playOdds,
      builder: (context, state) => const HypergeometricPage(),
    ),
  ];
}
