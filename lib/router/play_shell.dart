// Fichier : lib/router/play_shell.dart
// Shell du mode Jeu : barre d'outils de partie a la place de la barre
// d'onglets de l'app.
//
// La sortie est libre et sans confirmation (spec, decision du 19/09) : la
// partie reste en cours dans GameSessionService, et l'Accueil affiche
// "Reprendre la partie". Confirmer une sortie protegerait la partie d'un
// geste accidentel, mais couterait une friction a chaque fois qu'on va
// verifier un prix en plein milieu d'une game.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_text_styles.dart';
import '../theme/magic_palette.dart';
import 'app_routes.dart';

/// Index de l'outil actif dans la barre de partie.
int playToolIndex(String location) {
  if (location.startsWith(AppRoutes.playTournament)) return 1;
  if (location.startsWith(AppRoutes.playOracle)) return 2;
  if (location.startsWith(AppRoutes.playGlossary)) return 3;
  if (location.startsWith(AppRoutes.playOdds)) return 4;
  return 0;
}

class PlayShell extends StatelessWidget {
  const PlayShell({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  /// Les cinq outils, dans l'ordre que [playToolIndex] renvoie.
  ///
  /// Probabilites y figure bien : sans lui, `/play/odds` serait une route
  /// sans bouton, et l'index 4 rendu par [playToolIndex] ne designerait
  /// aucune entree -- etre sur le calculateur n'allumerait rien.
  static const _tools = <({String label, IconData icon, String route})>[
    (label: 'Vies', icon: Icons.favorite, route: AppRoutes.playCounter),
    (
      label: 'Tournoi',
      icon: Icons.emoji_events_outlined,
      route: AppRoutes.playTournament
    ),
    (label: 'Oracle', icon: Icons.all_inclusive, route: AppRoutes.playOracle),
    (label: 'Règles', icon: Icons.menu_book, route: AppRoutes.playGlossary),
    (label: 'Probas', icon: Icons.calculate_outlined, route: AppRoutes.playOdds),
  ];

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    final active = playToolIndex(currentLocation);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: p.raised,
            border: Border(top: BorderSide(color: p.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < _tools.length; i++)
                Expanded(
                  child: _ToolButton(
                    label: _tools[i].label,
                    icon: _tools[i].icon,
                    selected: i == active,
                    onTap: () => context.go(_tools[i].route),
                  ),
                ),
              // Separateur : "Fin" n'est pas un sixieme outil, c'est la
              // sortie. Sans cette barre, elle se lit comme une destination
              // de plus dans la rangee.
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: p.line,
              ),
              Expanded(
                child: _ToolButton(
                  label: 'Fin',
                  icon: Icons.flag_outlined,
                  selected: false,
                  // En `danger`, jamais en `accent` : "Fin" n'a pas d'etat
                  // actif, elle n'est pas une destination ou l'on reste.
                  color: p.danger,
                  // Vers la mise en place, PAS vers `home` -- et c'est une
                  // correction de fuite, pas une preference.
                  //
                  // Tant que `home` vaut '/', cette racine sert encore
                  // LifeCounterPage. Or le `initState` de la page d'arrivee
                  // s'execute AVANT le `dispose` de celle qu'on quitte
                  // (mesure par sonde) : la nouvelle instance activerait le
                  // wakelock, puis l'ancienne le desactiverait en mourant.
                  // On sortirait donc du compteur vers le compteur, wakelock
                  // coupe et barres systeme revenues -- ecran libre de
                  // s'eteindre en pleine partie.
                  //
                  // A repointer sur `AppRoutes.home` a la Task 12, quand '/'
                  // deviendra l'Accueil et que les deux instances cesseront
                  // de se chevaucher.
                  onTap: () => context.go(AppRoutes.playSetup),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// Couleur imposee, qui court-circuite le jeu actif/inactif.
  ///
  /// Sert a "Fin", qui doit rester lisible comme une sortie quelle que soit
  /// la page ouverte -- elle n'a pas d'etat actif a signaler.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    final color = this.color ?? (selected ? p.accent : p.inkSecondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.text(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
