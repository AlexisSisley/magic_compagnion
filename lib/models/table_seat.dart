// lib/models/table_seat.dart
// Geometrie de table du lot 6 (spec lot 6 §2).
//
// Cette fonction est le SEUL endroit ou la disposition des joueurs est decidee.
// AdaptiveGrid ne fait que rendre ce qu'elle retourne : si une disposition doit
// changer, elle change ici, jamais dans le widget.

/// Cote de la table ou un joueur est assis.
enum TableSide { top, right, bottom, left }

/// La place d'un joueur autour de l'appareil pose a plat.
class TableSeat {
  const TableSeat({
    required this.side,
    required this.slot,
    required this.slotCount,
  });

  final TableSide side;

  /// Position sur ce cote, de 0 a `slotCount - 1`.
  final int slot;

  /// Nombre de joueurs qui partagent ce cote.
  final int slotCount;

  /// Rotation a appliquer via `RotatedBox`, qui tourne dans le sens HORAIRE.
  ///
  /// Le haut du texte d'un joueur pointe a l'oppose de lui : un joueur assis a
  /// l'est lit un texte dont le haut pointe vers l'ouest, soit un quart de tour
  /// anti-horaire, soit trois quarts de tour horaires.
  int get quarterTurns => switch (side) {
        TableSide.bottom => 0,
        TableSide.left => 1,
        TableSide.top => 2,
        TableSide.right => 3,
      };

  @override
  String toString() => 'TableSeat($side, $slot/$slotCount)';
}

/// Sieges par defaut pour [playerCount] joueurs, indexes comme `playerOrder`.
///
/// De 4 a 6 joueurs, les quatre cotes sont utilises : c'est le mode d'usage
/// reel, l'appareil pose a plat au centre de la table. Au-dela de 6, on repasse
/// en face-a-face — quatre cotes ne suffisent plus, et un cote latéral partage
/// a trois devient illisible.
List<TableSeat> seatsFor(int playerCount) {
  if (playerCount <= 0) return const [];

  // Repartition par cote, dans l'ordre d'affectation des joueurs.
  final List<TableSide> sides = switch (playerCount) {
    1 => [TableSide.bottom],
    2 => [TableSide.top, TableSide.bottom],
    3 => [TableSide.top, TableSide.bottom, TableSide.bottom],
    4 => [TableSide.top, TableSide.right, TableSide.bottom, TableSide.left],
    5 => [
        TableSide.top,
        TableSide.top,
        TableSide.right,
        TableSide.bottom,
        TableSide.left,
      ],
    6 => [
        TableSide.top,
        TableSide.top,
        TableSide.right,
        TableSide.bottom,
        TableSide.bottom,
        TableSide.left,
      ],
    _ => _faceToFace(playerCount),
  };

  final counts = <TableSide, int>{};
  for (final side in sides) {
    counts[side] = (counts[side] ?? 0) + 1;
  }

  final used = <TableSide, int>{};
  return sides.map((side) {
    final slot = used[side] ?? 0;
    used[side] = slot + 1;
    return TableSeat(side: side, slot: slot, slotCount: counts[side]!);
  }).toList(growable: false);
}

/// Regle historique conservee au-dela de 6 joueurs : moitie haute en face,
/// moitie basse du cote de l'utilisateur, l'impair allant en bas.
List<TableSide> _faceToFace(int playerCount) {
  final topCount = playerCount ~/ 2;
  return [
    for (int i = 0; i < topCount; i++) TableSide.top,
    for (int i = topCount; i < playerCount; i++) TableSide.bottom,
  ];
}
