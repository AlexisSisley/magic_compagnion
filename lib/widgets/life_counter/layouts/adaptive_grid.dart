import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';

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

  /// Part de largeur prise par une colonne laterale quand elle existe, sur
  /// les ecrans assez larges pour que ce ratio suffise a lui seul.
  ///
  /// Un siege lateral pivote a 90/270 (tache 3 du lot 6) : `RotatedBox`
  /// echange largeur et hauteur pour son contenu, donc la largeur de cette
  /// colonne devient la hauteur DISPONIBLE pour la Column de
  /// `player_zone.dart` (en-tete 40 + poignee, au moins `kZoneHeightFloor`
  /// au total). Cette fraction n'est plus, a elle seule, ce qui protege ce
  /// plancher : tache 4 du lot 6, ruling 13 -- `build()` ci-dessous applique
  /// `kZoneHeightFloor` (le contrat de densite, `density_tier.dart`) comme
  /// largeur minimale absolue de la colonne. 0.30 redevient donc un simple
  /// reglage esthetique pour les ecrans larges, jamais la seule garantie
  /// contre l'overflow decouvert a la tache 3 sur un telephone de 320 de
  /// large.
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
        // Plancher absolu (tache 4, ruling 13) : quel que soit l'ecran, la
        // colonne laterale ne doit jamais descendre sous `kZoneHeightFloor`
        // -- sans quoi, une fois pivotee par `PlayerZone`, elle offre a la
        // Column (en-tete + poignee) moins que ce dont celle-ci a besoin.
        final sideWidth = math.max(
          constraints.maxWidth * sideColumnFraction,
          kZoneHeightFloor,
        );
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
