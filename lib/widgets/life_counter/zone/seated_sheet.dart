// lib/widgets/life_counter/zone/seated_sheet.dart
// Surface modale qui appartient à un joueur, et non à l'écran.
//
// Avant : `player_drawer` ouvrait un `showModalBottomSheet` (toujours par
// le bas) et `counter_editor_dialog` un `showDialog` (toujours au centre).
// Ni l'un ni l'autre ne savait à quel siège il appartenait, donc le joueur
// d'en face saisissait ses dégâts de commandant sur un panneau à l'envers,
// ou faisait tourner le téléphone.
//
// Ici, la feuille prend la rotation de son siège et surgit depuis SON bord.
// Pour un joueur du bas (quarterTurns == 0), le comportement observable est
// exactement celui d'avant.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Ouvre [builder] orienté pour un siège à [quarterTurns] quarts de tour.
Future<T?> showSeatedSheet<T>({
  required BuildContext context,
  required int quarterTurns,
  required WidgetBuilder builder,
}) {
  final turns = quarterTurns % 4;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppColors.overlayDark,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return RotatedBox(
        quarterTurns: turns,
        // `LayoutBuilder` vit DANS le `RotatedBox` : les contraintes qu'il
        // lit sont donc déjà celles du repère du siège (`RenderRotatedBox`
        // échange largeur/hauteur pour un quartTurns impair -- même
        // convention que le `RotatedBox` de `PlayerZone`). C'est ce qui
        // permet de forcer une largeur locale PLEINE (bord à bord du point
        // de vue du joueur) sans jamais lire `MediaQuery` directement, qui
        // donnerait la largeur PHYSIQUE de l'écran -- fausse pour un siège
        // latéral (quarterTurns impair), où bord à bord du joueur correspond
        // à la hauteur physique.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                // `Align` seul ne donne que des contraintes LÂCHES à son
                // enfant (0..maxWidth) : sans ce `ConstrainedBox`, le
                // contenu (un `Column` qui ne s'étire que par rapport à SA
                // propre largeur, pas celle de l'écran) se contracterait à
                // la largeur de sa ligne la plus large, laissant un tiroir
                // centré et étroit au lieu d'un tiroir qui occupe tout le
                // bord du joueur -- régression invisible aux tests qui ne
                // vérifient que la présence de texte, visible à l'œil.
                constraints: BoxConstraints.tightFor(
                  width: constraints.maxWidth,
                ),
                child: Material(
                  color: AppColors.dialogBackground,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(top: false, child: builder(context)),
                ),
              ),
            );
          },
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}
