import 'package:flutter/material.dart';
import 'package:magic_companion/models/table_seat.dart';

/// Moteur de rendu des zones joueur (spec lot 6 §2.1).
///
/// Cette classe ne decide plus de la disposition : elle rend les sieges que
/// `seatsFor` lui donne. Toute question de geometrie se tranche dans
/// `lib/models/table_seat.dart`, pas ici.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.playerZones,
    required this.centralBar,
  });

  final List<Widget> playerZones;
  final Widget centralBar;

  /// Part de largeur prise par une colonne laterale quand elle existe.
  ///
  /// Un siege lateral pivote a 90/270 (tache 3 du lot 6) : `RotatedBox`
  /// echange largeur et hauteur pour son contenu, donc la largeur de cette
  /// colonne devient la hauteur DISPONIBLE pour la Column de
  /// `player_zone.dart` (en-tete 40 + poignee 30 = 70 fixes, avant meme le
  /// cadran). A 0.22, un telephone de 320 de large (le plus etroit courant)
  /// ne laissait que ~64px a cette colonne une fois pivotee : RenderFlex
  /// overflow des que `GameSession.newGame` a commence a poser une vraie
  /// rotation laterale (avant la tache 3, `quarterTurns` valait toujours 0,
  /// donc ce chemin n'etait jamais exerce). 0.30 laisse une marge sur ce
  /// plancher ; le calibrage fin par palier de densite est la tache 4.
  static const double sideColumnFraction = 0.30;

  @override
  Widget build(BuildContext context) {
    final seats = seatsFor(playerZones.length);

    List<Widget> zonesOn(TableSide side) {
      final indexed = <int>[];
      for (int i = 0; i < seats.length; i++) {
        if (seats[i].side == side) indexed.add(i);
      }
      indexed.sort((a, b) => seats[a].slot.compareTo(seats[b].slot));
      return indexed
          .map((i) => Padding(padding: const EdgeInsets.all(2), child: playerZones[i]))
          .toList();
    }

    final top = zonesOn(TableSide.top);
    final bottom = zonesOn(TableSide.bottom);
    final left = zonesOn(TableSide.left);
    final right = zonesOn(TableSide.right);

    final useSubGrid = playerZones.length == 8;

    final centre = Column(
      children: [
        Expanded(child: _half(top, useSubGrid: useSubGrid)),
        centralBar,
        Expanded(child: _half(bottom, useSubGrid: useSubGrid)),
      ],
    );

    if (left.isEmpty && right.isEmpty) return centre;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideWidth = constraints.maxWidth * sideColumnFraction;
        return Row(
          children: [
            if (left.isNotEmpty)
              SizedBox(width: sideWidth, child: _column(left)),
            Expanded(child: centre),
            if (right.isNotEmpty)
              SizedBox(width: sideWidth, child: _column(right)),
          ],
        );
      },
    );
  }

  static Widget _column(List<Widget> zones) {
    return Column(
      children: [for (final zone in zones) Expanded(child: zone)],
    );
  }

  static Widget _half(List<Widget> zones, {required bool useSubGrid}) {
    if (zones.isEmpty) return const SizedBox.shrink();

    if (useSubGrid && zones.length == 4) {
      return Column(
        children: [
          Expanded(child: Row(children: [
            for (int i = 0; i < 2; i++) Expanded(child: zones[i]),
          ])),
          Expanded(child: Row(children: [
            for (int i = 2; i < 4; i++) Expanded(child: zones[i]),
          ])),
        ],
      );
    }

    return Row(children: [for (final zone in zones) Expanded(child: zone)]);
  }
}
