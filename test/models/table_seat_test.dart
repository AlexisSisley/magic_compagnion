import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';

void main() {
  test('2 joueurs : face à face', () {
    expect(seatsFor(2).map((s) => s.side).toList(),
        [TableSide.top, TableSide.bottom]);
  });

  test('4 joueurs : un siège par côté', () {
    expect(seatsFor(4).map((s) => s.side).toList(),
        [TableSide.top, TableSide.right, TableSide.bottom, TableSide.left]);
  });

  test('4 joueurs : les rotations suivent les sièges', () {
    expect(seatsFor(4).map((s) => s.quarterTurns).toList(), [2, 3, 0, 1]);
  });

  test('5 joueurs : deux en haut, un par côté, un en bas', () {
    expect(seatsFor(5).map((s) => s.side).toList(), [
      TableSide.top, TableSide.top, TableSide.right,
      TableSide.bottom, TableSide.left,
    ]);
  });

  test('6 joueurs : deux en haut, deux en bas, un par côté', () {
    expect(seatsFor(6).map((s) => s.side).toList(), [
      TableSide.top, TableSide.top, TableSide.right,
      TableSide.bottom, TableSide.bottom, TableSide.left,
    ]);
  });

  test('7 joueurs : repli face à face, aucun siège latéral', () {
    final sides = seatsFor(7).map((s) => s.side).toSet();
    expect(sides.contains(TableSide.left), isFalse);
    expect(sides.contains(TableSide.right), isFalse);
  });

  test('allowSideColumns: false force le face à face même à 4 joueurs', () {
    expect(seatsFor(4, allowSideColumns: false).map((s) => s.side).toList(),
        [TableSide.top, TableSide.top, TableSide.bottom, TableSide.bottom]);
  });

  test('le repli met le joueur surnuméraire en bas, du côté utilisateur', () {
    expect(seatsFor(5, allowSideColumns: false).map((s) => s.side).toList(), [
      TableSide.top, TableSide.top,
      TableSide.bottom, TableSide.bottom, TableSide.bottom,
    ]);
  });

  test('les slots d\'un même côté sont numérotés de 0 à slotCount-1', () {
    final tops = seatsFor(6).where((s) => s.side == TableSide.top).toList();
    expect(tops.map((s) => s.slot).toList(), [0, 1]);
    expect(tops.every((s) => s.slotCount == 2), isTrue);
  });
}
