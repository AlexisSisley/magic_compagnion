// Fichier : lib/widgets/life_counter/zone/pending_delta.dart
// Bilan de la salve en cours (tâche 6), posé contre le total.
//
// Ne pas confondre avec `LifeLog`/`FloatingNumber` : ceux-là montrent chaque
// ÉVÉNEMENT (un `+3` ou un `−5` qui monte et s'efface), celui-ci montre le
// BILAN cumulé depuis le début de la salve (`PlayerZoneNotifier.accumulate`),
// qui reste affiché tant que la fenêtre `kDamageBufferWindow` est ouverte.
// Les deux coexistent à l'écran, voir `player_zone.dart`.
//
// Taille : la MOITIÉ de celle du total (spec §1.8). Le delta cumulé est la
// deuxième information la plus importante de la zone, après le total
// lui-même -- avant cette tâche, le seul retour visible sur un changement de
// vie était `LifeLog`, à 48px fixes et illisible à distance de table sur un
// grand écran (ou disproportionné sur un petit, puisque fixe).

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

class PendingDelta extends StatelessWidget {
  const PendingDelta({
    super.key,
    required this.delta,
    required this.totalFontSize,
  });

  final int delta;

  /// Taille du total auquel ce badge se compare. Le badge se rend à la
  /// MOITIÉ de cette valeur -- voir le commentaire de fichier ci-dessus.
  final double totalFontSize;

  @override
  Widget build(BuildContext context) {
    // Un bilan nul n'apporte aucune information (voir Q1 du rapport de
    // tâche) : il disparaît plutôt que d'afficher "+0", ce qui serait un
    // signal sans valeur occupant une place qui attire l'œil.
    if (delta == 0) return const SizedBox.shrink();

    final bool isLoss = delta < 0;
    return Text(
      isLoss ? '−${-delta}' : '+$delta',
      style: AppTextStyles.lifeBadge(
        fontSize: totalFontSize / 2,
        color: isLoss ? AppColors.feedbackDanger : AppColors.feedbackSuccess,
      ),
    );
  }
}
