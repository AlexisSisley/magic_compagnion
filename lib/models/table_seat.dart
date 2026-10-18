/// Côté de la table où un joueur est assis, l'appareil étant posé à plat.
enum TableSide { top, right, bottom, left }

/// Façon dont les sièges sont répartis sur l'écran.
///
/// Introduit pour que la DISPOSITION et la ROTATION aient une seule origine
/// commune : `TableSeat.quarterTurns` dérive de `side`, et `side` dérive de
/// l'arrangement. Auparavant la rotation d'un joueur était stockée sur le
/// modèle et la disposition calculée à part, d'où des orientations qui ne
/// correspondaient pas à la grille affichée.
enum TableArrangement {
  /// Moitié haute à 180°, moitié basse à 0°. Zones plus larges que hautes.
  faceToFace,

  /// Deux colonnes : celle de gauche à 90°, celle de droite à 270°.
  /// Zones plus hautes que larges — la rotation leur rend leur grand côté.
  columnPairs,

  /// Un joueur par bord, avec colonnes latérales. 5 et 6 joueurs.
  around,
}

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
  /// Déléguée à `TableSide.quarterTurns`, seule table côté → rotation.
  int get quarterTurns => side.quarterTurns;
}

/// LA correspondance côté → rotation, unique dans tout le code.
///
/// Tâche 8a (Ruling 49) : le sélecteur à quatre flèches avait recopié cette
/// table en dur ; deux tables, c'est deux sources de vérité sur la rotation,
/// la classe de défaut du double-pivotement du lot 6. `TableSeat.quarterTurns`
/// et `OrientationPicker` lisent désormais tous deux celle-ci.
extension TableSideRotation on TableSide {
  /// `RotatedBox` tourne dans le sens HORAIRE : un quart de tour envoie le
  /// bord gauche de l'enfant sur le bord haut de l'écran. Un joueur assis à
  /// gauche regarde vers la droite, sa main gauche pointe donc vers le haut
  /// de l'écran — d'où `left => 1`.
  int get quarterTurns => switch (this) {
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

/// Sièges pour un [arrangement] donné.
///
/// Seul `tableLayoutFor` appelle cette fonction : c'est lui qui décide de
/// l'arrangement, via `arrangementFor`.
List<TableSeat> seatsForArrangement(
  int playerCount,
  TableArrangement arrangement,
) =>
    switch (arrangement) {
      TableArrangement.faceToFace => _faceToFace(playerCount),
      TableArrangement.columnPairs => _columnPairs(playerCount),
      TableArrangement.around => seatsFor(playerCount),
    };

/// Deux colonnes de hauteur ÉGALE, remplies en alternance gauche/droite.
///
/// Ruling 24 (18/10/2026) : exige un effectif PAIR. Des colonnes inégales
/// (effectif impair) n'ont pas de frontière horizontale commune entre leurs
/// rangées : `AdaptiveGrid` écarterait alors silencieusement la bande
/// d'actions au profit du hub, même quand `barKind` vaut `band` -- la
/// dégradation silencieuse que le §4.3 de la spec table multijoueur v2
/// interdit. Depuis le ruling 23, `arrangementFor` ne produit `columnPairs`
/// qu'à 4 joueurs (toujours pair), ce qui rend le cas impair inatteignable
/// en pratique -- cette assertion le verrouille plutôt que de laisser un cas
/// mort silencieux : un futur appelant qui assouplirait `arrangementFor`
/// sans relire cette garde échouerait bruyamment, pas en production.
List<TableSeat> _columnPairs(int playerCount) {
  assert(
    playerCount.isEven,
    'columnPairs suppose deux colonnes de même hauteur (spec §4.3) : un '
    'effectif impair produirait des colonnes inégales et ferait disparaître '
    'la bande silencieusement (voir adaptive_grid.dart).',
  );
  return _withSlots([
    for (int i = 0; i < playerCount; i++)
      i.isEven ? TableSide.left : TableSide.right,
  ]);
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
