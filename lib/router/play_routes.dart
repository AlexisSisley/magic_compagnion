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
import '../pages/play/play_setup_page.dart';
import '../pages/tools/hypergeometric_page.dart';
import '../pages/tournaments/tournament_page.dart';
import 'app_routes.dart';
import 'play_shell.dart';

/// Routes du mode Jeu, greffees a la racine du router (hors ShellRoute).
///
/// Les cinq outils vivent dans un ShellRoute qui leur pose la barre d'outils
/// de partie. Cette barre remplace celle de l'app : c'est pour ca que ces
/// routes sont a la racine du router et non dans le shell d'onglets.
///
/// La mise en place, elle, est hors du ShellRoute : il n'y a pas encore de
/// partie, donc pas de barre d'outils de partie a poser.
List<RouteBase> playRoutes() {
  return [
    GoRoute(
      path: AppRoutes.playSetup,
      builder: (context, state) => const PlaySetupPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => PlayShell(
        currentLocation: state.uri.toString(),
        child: child,
      ),
      routes: [
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
      ],
    ),
  ];
}
