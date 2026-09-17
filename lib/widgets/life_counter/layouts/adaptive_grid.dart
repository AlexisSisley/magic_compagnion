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

        final centre = Column(
          children: [
            Expanded(child: _half(top, subGrid: subGrid)),
            if (layout.barKind == ActionBarKind.band)
              KeyedSubtree(
                  key: const ValueKey('action_band'), child: centralBar),
            Expanded(child: _half(bottom, subGrid: subGrid)),
          ],
        );

        final withHub = layout.barKind == ActionBarKind.hub
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
