import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Une action de partie, telle que le hub la présente.
class GameAction {
  const GameAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// Identité stable de l'action, indépendante de sa position dans la liste.
  ///
  /// Revue finale (IMPORTANT #3) : la bande câblait ses neuf boutons À
  /// L'INDEX (`actions[0]` … `actions[8]`) tandis que le hub itérait. Une
  /// dixième action aurait donc été affichée par le hub, ignorée par la
  /// bande, et sous-estimée par `kBandNeed` — les deux mécaniques exactes du
  /// défaut d'origine, réarmées. Les deux formes itèrent désormais sur la
  /// même liste, et cet `id` sert à la fois de clé de test (`action-<id>`) et
  /// de sélecteur pour les trois rendus bespoke de la bande.
  final String id;

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// Accès aux actions de partie sur petit écran (spec §4.2).
///
/// Un bouton rond au centre de la table, qui ouvre une feuille contenant TOUTES
/// les actions. Il ne coûte que son diamètre, donc il ne prend jamais la place
/// des zones — contrairement à la bande, qui sur un écran étroit se réduisait
/// silencieusement à ses deux premières icônes et emportait avec elle le choix
/// du nombre de joueurs et les options de jeu.
class ActionHub extends StatelessWidget {
  const ActionHub({super.key, required this.actions});

  final List<GameAction> actions;

  static const double diameter = 56.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Material(
        key: const ValueKey('action_hub_button'),
        color: AppColors.cardBackground,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      // Ronde de correction 1 (tâche 6) : à neuf actions, la feuille peut
      // dépasser la hauteur d'un petit écran. `isScrollControlled` +
      // `SingleChildScrollView` la rendent défilable plutôt que rognée sans
      // recours -- un défilement DÉCOUVRABLE dans une feuille modale (l'
      // utilisateur sait qu'on peut faire glisser une feuille) n'a rien à
      // voir avec le défilement horizontal interdit de la bande, qui, lui,
      // cachait des actions sans aucune affordance.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Wrap(
              children: [
                for (final action in actions)
                  ListTile(
                    key: ValueKey('hub-action-${action.id}'),
                    leading: Icon(action.icon, color: AppColors.textSecondary),
                    title: Text(action.label),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      action.onPressed();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
