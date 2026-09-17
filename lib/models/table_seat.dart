/// Côté de la table où un joueur est assis, l'appareil étant posé à plat.
enum TableSide { top, right, bottom, left }

/// Siège d'un joueur : son côté, et sa place parmi ceux qui partagent ce côté.
class TableSeat {
  const TableSeat({
    required this.side,
    required this.slot,
    required this.slotCount,
  });

  final TableSide side;
  final int slot;
  final int slotCount;

  /// Rotation à appliquer pour que ce joueur lise à l'endroit depuis sa chaise.
  ///
  /// `RotatedBox` tourne dans le sens HORAIRE : un quart de tour envoie le bord
  /// gauche de l'enfant sur le bord haut de l'écran. Un joueur assis à gauche
  /// regarde vers la droite, sa main gauche pointe donc vers le haut de
  /// l'écran — d'où `left => 1`.
  int get quarterTurns => switch (side) {
        TableSide.bottom => 0,
        TableSide.left => 1,
        TableSide.top => 2,
        TableSide.right => 3,
      };
}

/// Répartition des joueurs autour de la table.
///
/// [allowSideColumns] à `false` impose le repli face-à-face : c'est ainsi que
/// `tableLayoutFor` applique la règle d'abordabilité (spec §3.3) sans que la
/// géométrie soit dupliquée hors de ce fichier.
List<TableSeat> seatsFor(int playerCount, {bool allowSideColumns = true}) {
  if (!allowSideColumns || playerCount <= 3 || playerCount > 6) {
    return _faceToFace(playerCount);
  }
  final sides = switch (playerCount) {
    4 => [TableSide.top, TableSide.right, TableSide.bottom, TableSide.left],
    5 => [
        TableSide.top, TableSide.top, TableSide.right,
        TableSide.bottom, TableSide.left,
      ],
    _ => [
        TableSide.top, TableSide.top, TableSide.right,
        TableSide.bottom, TableSide.bottom, TableSide.left,
      ],
  };
  return _withSlots(sides);
}

/// Moitié haute pivotée à 180°, moitié basse à l'endroit. Le joueur
/// surnuméraire va en bas, du côté de celui qui tient l'appareil.
List<TableSeat> _faceToFace(int playerCount) {
  final topCount = playerCount ~/ 2;
  return _withSlots([
    for (int i = 0; i < playerCount; i++)
      i < topCount ? TableSide.top : TableSide.bottom,
  ]);
}

List<TableSeat> _withSlots(List<TableSide> sides) {
  final counts = <TableSide, int>{};
  for (final side in sides) {
    counts[side] = (counts[side] ?? 0) + 1;
  }
  final used = <TableSide, int>{};
  return [
    for (final side in sides)
      TableSeat(
        side: side,
        slot: used[side] = (used[side] ?? -1) + 1,
        slotCount: counts[side]!,
      ),
  ];
}
