// Fichier : lib/widgets/life_counter/zone/pending_delta.dart
// Bilan de la salve en cours (tâche 6), posé contre le total.
//
// Ne pas confondre avec `LifeLog`/`FloatingNumber` : ceux-là montrent chaque
// ÉVÉNEMENT (un `+3` ou un `−5` qui monte et s'efface), celui-ci montre le
// BILAN cumulé depuis le début de la salve, qui reste affiché tant que la
// fenêtre de buffer est ouverte. Les deux coexistent à l'écran.
//
// Ruling 32 (consolidation, lu après une première version de cette tâche qui
// avait recréé un second compteur cumulé dans `PlayerZoneNotifier`) : LA
// source de ce bilan est `LifeCounterPage._pendingDamage` -- elle existait
// déjà, elle est testée, elle porte la logique d'attribution de dégâts de
// commandant. Ce widget ne fait plus que RENDRE une valeur reçue en
// paramètre depuis `PlayerZone` (elle-même alimentée par la page), il ne
// possède aucun état et ne lit plus aucun provider. Avant ce ruling, la page
// rendait elle-même un second badge équivalent (`zone_pending_badge`, 14px,
// coin haut-droit, posé en `Positioned` au niveau de la page) -- SUPPRIMÉ en
// faveur de celui-ci, pour deux raisons : (1) une seule source affichée à un
// seul endroit, (2) ce widget vit DANS `PlayerZone`, donc DANS le
// `RotatedBox` du siège -- l'ancien badge, posé par-dessus au niveau de la
// page, ne pivotait jamais : le joueur assis en face lisait son bilan à
// l'envers.
//
// Format du texte : ASCII simple ("+2"/"-5"), PAS de signe moins Unicode --
// c'est le format que l'ancien badge de la page utilisait déjà
// (`pendingText` dans `life_counter_page.dart`), repris tel quel pour ne pas
// casser les assertions `find.text('-N')`/`find.text('+N')` déjà écrites
// contre ce comportement.
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
    // signal sans valeur occupant une place qui attire l'œil. Même garde que
    // l'ancien badge de la page (`if (pending != 0)`).
    if (delta == 0) return const SizedBox.shrink();

    final bool isPositive = delta > 0;
    return Text(
      isPositive ? '+$delta' : '$delta',
      style: AppTextStyles.lifeBadge(
        fontSize: totalFontSize / 2,
        color: isPositive ? AppColors.feedbackSuccess : AppColors.feedbackDanger,
      ),
    );
  }
}
