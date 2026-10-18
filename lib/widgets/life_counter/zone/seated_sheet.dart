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
// celui de l'ancien tiroir : même couleur, même rayon, feuille qui monte du
// bas sur sa propre hauteur, fond qui descend jusqu'au bord physique de
// l'écran avec le contenu gardé au-dessus de la barre de navigation.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Ouvre [builder] orienté pour un siège à [quarterTurns] quarts de tour.
///
/// Le contenu de [builder] reçoit des contraintes bornées par la hauteur
/// LOCALE disponible (la largeur physique pour un siège latéral) : s'il peut
/// dépasser, c'est à lui de défiler (les deux appelants le font).
Future<T?> showSeatedSheet<T>({
  required BuildContext context,
  required int quarterTurns,
  required WidgetBuilder builder,
}) {
  // Normalisé ici et non laissé à `RotatedBox` (qui fait son propre `% 4`) :
  // `_toSeatFrame` ci-dessous a besoin d'une valeur dans 0..3.
  final turns = quarterTurns % 4;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppColors.overlayDark,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (routeContext, animation, secondaryAnimation) {
      final media = MediaQuery.of(routeContext);
      // Le `MediaQuery` hérité décrit l'écran PHYSIQUE. Lu tel quel sous le
      // `RotatedBox`, un `SafeArea` appliquerait l'encoche (haut physique)
      // au haut LOCAL -- c'est-à-dire, pour le siège d'en face, au bord
      // opposé à celui où elle se trouve. On donne donc au contenu un
      // `MediaQuery` exprimé dans le repère du siège : insets tournés avec
      // lui, taille échangée pour un siège latéral.
      final seatMedia = media.copyWith(
        size: turns.isOdd ? media.size.flipped : media.size,
        // Haut local retiré, comme le faisait `showModalBottomSheet`
        // (`removeTop`) : le haut d'une feuille n'est contre aucun bord de
        // l'écran tant qu'elle ne le remplit pas, et le `SafeArea` du corps
        // du tiroir ajouterait sinon la hauteur de la barre d'état au-dessus
        // de sa poignée.
        padding: _toSeatFrame(media.padding, turns).copyWith(top: 0),
        viewPadding: _toSeatFrame(media.viewPadding, turns).copyWith(top: 0),
        systemGestureInsets: _toSeatFrame(media.systemGestureInsets, turns),
        // Le clavier est consommé par le `Padding` physique ci-dessous : le
        // laisser ici le ferait appliquer une seconde fois, et au mauvais
        // bord pour un siège qui n'est pas en bas.
        viewInsets: EdgeInsets.zero,
      );
      // `showGeneralDialog`, contrairement à `showDialog`, n'écarte rien du
      // clavier : l'éditeur de compteur, ancré en bas, aurait ses champs
      // recouverts. Le clavier sort toujours du bas PHYSIQUE, d'où ce
      // `Padding` HORS du `RotatedBox` : il réduit la zone où la feuille se
      // place, quel que soit le siège.
      return Padding(
        padding: media.viewInsets,
        child: RotatedBox(
          quarterTurns: turns,
          child: MediaQuery(
            data: seatMedia,
            // `LayoutBuilder` vit DANS le `RotatedBox` : les contraintes
            // qu'il lit sont donc déjà celles du repère du siège
            // (`RenderRotatedBox` échange largeur/hauteur pour un
            // quarterTurns impair -- même convention que le `RotatedBox` de
            // `PlayerZone`). C'est ce qui permet de forcer une largeur locale
            // PLEINE (bord à bord du point de vue du joueur) sans lire la
            // largeur physique de l'écran, fausse pour un siège latéral.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  // La glissade vit elle aussi DANS le `RotatedBox` : son
                  // décalage (0, 1) est exprimé dans le repère du siège,
                  // donc la feuille monte depuis le bord du joueur. Posée
                  // autour du `RotatedBox` (dans `transitionBuilder`), elle
                  // partait du bas PHYSIQUE et traversait l'écran pour les
                  // sièges du haut et des côtés. Le décalage vaut une
                  // hauteur de FEUILLE (pas d'écran), comme l'ancien
                  // `showModalBottomSheet`.
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                    child: ConstrainedBox(
                      // `Align` seul ne donne que des contraintes LÂCHES à
                      // son enfant (0..maxWidth) : sans ce `ConstrainedBox`,
                      // le contenu (un `Column` qui ne s'étire que par
                      // rapport à SA propre largeur) se contracterait à la
                      // largeur de sa ligne la plus large, laissant un
                      // tiroir centré et étroit au lieu d'un tiroir qui
                      // occupe tout le bord du joueur.
                      constraints: BoxConstraints.tightFor(
                        width: constraints.maxWidth,
                      ),
                      // Habillage de l'ancien tiroir (`showModalBottomSheet`
                      // de `player_drawer.dart`) : spec §1.5, « pour un
                      // joueur du bas, le comportement observable est
                      // inchangé ».
                      child: Material(
                        color: AppColors.greyShade800,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        clipBehavior: Clip.antiAlias,
                        // Lit `seatMedia` : écarte le contenu de la barre
                        // de navigation ou de l'encoche qui se trouve
                        // derrière le bord DU SIÈGE, pendant que le fond de
                        // la feuille, lui, descend jusqu'au bord de l'écran.
                        child: SafeArea(child: builder(context)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
    // La glissade est portée par `pageBuilder` (voir plus haut) : ici, on
    // rend l'enfant tel quel, sans le fondu par défaut de
    // `showGeneralDialog` que l'ancien tiroir n'avait pas. La barrière, elle,
    // garde son propre fondu.
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}

/// Exprime des insets PHYSIQUES dans le repère d'un siège tourné de
/// [turns] quarts de tour horaires (0..3).
///
/// Un quart de tour horaire envoie le bord gauche de l'enfant en haut de
/// l'écran (voir `TableSeat.quarterTurns`) : vu du siège, son bord gauche
/// est donc le haut physique, son haut la droite physique, et ainsi de
/// suite. Ce n'est pas une table côté -> rotation (celle-ci reste
/// `TableSeat.quarterTurns`) : c'est l'effet d'une rotation déjà connue sur
/// quatre longueurs.
EdgeInsets _toSeatFrame(EdgeInsets p, int turns) => switch (turns) {
  1 => EdgeInsets.fromLTRB(p.top, p.right, p.bottom, p.left),
  2 => EdgeInsets.fromLTRB(p.right, p.bottom, p.left, p.top),
  3 => EdgeInsets.fromLTRB(p.bottom, p.left, p.top, p.right),
  _ => p,
};
