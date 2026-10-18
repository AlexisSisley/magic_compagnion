import 'package:flutter/material.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';

/// Place les zones joueur autour de la table.
///
/// Cette classe ne décide de RIEN : `tableLayoutFor` tranche la disposition,
/// `seatsFor` tranche la géométrie. Et surtout, elle ne PIVOTE rien — la
/// rotation appartient à `PlayerZone` et à lui seul. Au lot 6, la grille
/// pivotait la moitié haute pendant que le siège écrivait la même rotation dans
/// l'état : 180° + 180° = 360°, table inversée, tous les tests verts.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.playerZones,
    required this.centralBar,
    required this.actionHub,
  });

  final List<Widget> playerZones;

  /// Bande horizontale des huit actions. Rendue sur grand écran.
  final Widget centralBar;

  /// Bouton rond central qui ouvre la feuille des actions. Rendu sur petit
  /// écran, où une bande lisible ne tient pas sans voler leur place aux zones.
  final Widget actionHub;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = tableLayoutFor(
          Size(constraints.maxWidth, constraints.maxHeight),
          playerZones.length,
        );
        final seats = layout.seats;

        List<Widget> zonesOn(TableSide side) {
          final indexed = <int>[];
          for (int i = 0; i < seats.length; i++) {
            if (seats[i].side == side) indexed.add(i);
          }
          indexed.sort((a, b) => seats[a].slot.compareTo(seats[b].slot));
          return [
            for (final i in indexed)
              Padding(
                key: ValueKey('grid_slot_$i'),
                padding: const EdgeInsets.all(2),
                child: playerZones[i],
              ),
          ];
        }

        final top = zonesOn(TableSide.top);
        final bottom = zonesOn(TableSide.bottom);
        final left = zonesOn(TableSide.left);
        final right = zonesOn(TableSide.right);
        final subGrid = playerZones.length == 8;

        // Tâche 3 (spec §1.4) : `TableArrangement.columnPairs` met TOUS les
        // sièges sur `left`/`right`, sans aucun `top`/`bottom` -- un cas que
        // cette grille ne connaissait pas avant cette tâche, où `left`/
        // `right` n'existaient qu'en complément d'un centre `top`/`bottom`
        // (la disposition `around`, 5-6 joueurs, `useSideColumns == true`).
        // Sans cette branche, `top`/`bottom` vides produisaient un centre
        // entièrement blanc et le `if (!layout.useSideColumns) return
        // withHub;` ci-dessous jetait `left`/`right` sans les avoir jamais
        // posés dans l'arbre : les joueurs disparaissaient purement et
        // simplement sur un écran replié à 4 joueurs -- pire que le défaut
        // que la tâche 3 corrige.
        final hasCentreRows = top.isNotEmpty || bottom.isNotEmpty;

        // Révision (ruling 21) : la bande suppose une frontière HORIZONTALE
        // qui traverse toute la table sans voler de hauteur à personne (spec
        // §1.2). `columnPairs` en fournit une quand ses deux colonnes ont le
        // MÊME nombre de sièges ET en ont au moins deux chacune : à 4
        // joueurs (2 + 2), la première paire (un siège à gauche, un à
        // droite) et la seconde partagent alors la même frontière -- poser
        // la bande entre les deux coûte la même hauteur aux QUATRE joueurs,
        // exactement comme entre `top` et `bottom` ailleurs. Une première
        // version de cette correction forçait le hub dès que `top`/`bottom`
        // étaient vides, par excès de prudence -- un test réel l'a prise en
        // défaut : à 4 joueurs sur un écran large mais plus haut que large
        // (ex. 600×900), cela coupait silencieusement la bande (et donc le
        // chrono de partie qu'elle porte) sans aucune raison de surface,
        // exactement la dégradation silencieuse que le §4.3 de la spec table
        // multijoueur v2 interdit. À 2 et 3 joueurs, `_columnPairs` ne
        // produit jamais deux colonnes égales d'au moins deux sièges (1
        // contre 1 sans rangée à séparer, ou 2 contre 1) : le hub reste alors
        // la seule forme.
        final alignedColumnRows = left.length == right.length && left.length >= 2;

        final Widget centre;
        if (hasCentreRows) {
          centre = Column(
            children: [
              Expanded(child: _half(top, subGrid: subGrid)),
              if (layout.barKind == ActionBarKind.band)
                KeyedSubtree(
                    key: const ValueKey('action_band'), child: centralBar),
              Expanded(child: _half(bottom, subGrid: subGrid)),
            ],
          );
        } else if (alignedColumnRows) {
          // Même géométrie que `Row([column(left), column(right)])` quand
          // aucune bande n'est insérée -- quatre cellules de taille et de
          // position identiques, seulement réparties en deux rangées de deux
          // plutôt qu'en deux colonnes de deux, pour que la bande ait une
          // rangée où se loger.
          centre = Column(
            children: [
              Expanded(
                  child: Row(children: [
                Expanded(child: left[0]),
                Expanded(child: right[0]),
              ])),
              if (layout.barKind == ActionBarKind.band)
                KeyedSubtree(
                    key: const ValueKey('action_band'), child: centralBar),
              Expanded(
                  child: Row(children: [
                Expanded(child: left[1]),
                Expanded(child: right[1]),
              ])),
            ],
          );
        } else {
          centre = Row(
            children: [
              Expanded(child: _column(left)),
              Expanded(child: _column(right)),
            ],
          );
        }

        final hasNaturalSeam = hasCentreRows || alignedColumnRows;
        final withHub = !hasNaturalSeam || layout.barKind == ActionBarKind.hub
            ? Stack(
                alignment: Alignment.center,
                children: [
                  centre,
                  KeyedSubtree(
                      key: const ValueKey('action_hub'), child: actionHub),
                ],
              )
            : centre;

        if (!layout.useSideColumns) return withHub;

        return Row(
          children: [
            SizedBox(width: layout.sideWidth, child: _column(left)),
            Expanded(child: withHub),
            SizedBox(width: layout.sideWidth, child: _column(right)),
          ],
        );
      },
    );
  }

  static Widget _column(List<Widget> zones) =>
      Column(children: [for (final zone in zones) Expanded(child: zone)]);

  static Widget _half(List<Widget> zones, {required bool subGrid}) {
    if (zones.isEmpty) return const SizedBox.shrink();
    if (subGrid && zones.length == 4) {
      return Column(
        children: [
          Expanded(
              child: Row(children: [
            for (int i = 0; i < 2; i++) Expanded(child: zones[i]),
          ])),
          Expanded(
              child: Row(children: [
            for (int i = 2; i < 4; i++) Expanded(child: zones[i]),
          ])),
        ],
      );
    }
    return Row(children: [for (final zone in zones) Expanded(child: zone)]);
  }
}
