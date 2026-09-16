import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/table_seat.dart';

void main() {
  group('TableSeat.quarterTurns', () {
    // Convention : RotatedBox tourne dans le sens horaire, et le haut du texte
    // d'un joueur pointe a l'oppose de lui.
    test('bas = 0, gauche = 1, haut = 2, droite = 3', () {
      expect(const TableSeat(side: TableSide.bottom, slot: 0, slotCount: 1).quarterTurns, 0);
      expect(const TableSeat(side: TableSide.left, slot: 0, slotCount: 1).quarterTurns, 1);
      expect(const TableSeat(side: TableSide.top, slot: 0, slotCount: 1).quarterTurns, 2);
      expect(const TableSeat(side: TableSide.right, slot: 0, slotCount: 1).quarterTurns, 3);
    });
  });

  group('seatsFor', () {
    test('retourne exactement un siege par joueur, de 2 a 8', () {
      for (int n = 2; n <= 8; n++) {
        expect(seatsFor(n).length, n, reason: '$n joueurs');
      }
    });

    test('2 joueurs : haut, bas', () {
      final seats = seatsFor(2);
      expect(seats.map((s) => s.side).toList(), [TableSide.top, TableSide.bottom]);
      expect(seats.map((s) => s.quarterTurns).toList(), [2, 0]);
    });

    test('3 joueurs : 1 haut, 2 bas', () {
      final seats = seatsFor(3);
      expect(seats.map((s) => s.side).toList(),
          [TableSide.top, TableSide.bottom, TableSide.bottom]);
      expect(seats[1].slotCount, 2);
      expect(seats[1].slot, 0);
      expect(seats[2].slot, 1);
    });

    test('4 joueurs : un par cote, dans l ordre haut/droite/bas/gauche', () {
      final seats = seatsFor(4);
      expect(seats.map((s) => s.side).toList(),
          [TableSide.top, TableSide.right, TableSide.bottom, TableSide.left]);
      expect(seats.map((s) => s.quarterTurns).toList(), [2, 3, 0, 1]);
      expect(seats.every((s) => s.slotCount == 1), isTrue);
    });

    test('5 joueurs : 2 haut, 1 droite, 1 bas, 1 gauche', () {
      final seats = seatsFor(5);
      expect(seats.map((s) => s.side).toList(), [
        TableSide.top,
        TableSide.top,
        TableSide.right,
        TableSide.bottom,
        TableSide.left,
      ]);
      expect(seats[0].slotCount, 2);
      expect(seats[1].slot, 1);
    });

    test('6 joueurs : 2 haut, 1 droite, 2 bas, 1 gauche', () {
      final seats = seatsFor(6);
      expect(seats.map((s) => s.side).toList(), [
        TableSide.top,
        TableSide.top,
        TableSide.right,
        TableSide.bottom,
        TableSide.bottom,
        TableSide.left,
      ]);
      expect(seats[3].slotCount, 2);
      expect(seats[4].slot, 1);
    });

    test('7 joueurs : retour au face-a-face, 3 haut 4 bas', () {
      final seats = seatsFor(7);
      expect(seats.where((s) => s.side == TableSide.top).length, 3);
      expect(seats.where((s) => s.side == TableSide.bottom).length, 4);
      expect(
          seats.any((s) => s.side == TableSide.left || s.side == TableSide.right),
          isFalse,
          reason: 'au-dela de 6, les sieges lateraux deviennent illisibles');
    });

    test('8 joueurs : 4 haut 4 bas, aucun siege lateral', () {
      final seats = seatsFor(8);
      expect(seats.where((s) => s.side == TableSide.top).length, 4);
      expect(seats.where((s) => s.side == TableSide.bottom).length, 4);
      expect(
          seats.any((s) => s.side == TableSide.left || s.side == TableSide.right),
          isFalse);
    });

    test('les slots d un meme cote sont contigus et commencent a zero', () {
      for (int n = 2; n <= 8; n++) {
        final seats = seatsFor(n);
        for (final side in TableSide.values) {
          final onSide = seats.where((s) => s.side == side).toList();
          if (onSide.isEmpty) continue;
          final slots = onSide.map((s) => s.slot).toList()..sort();
          expect(slots, List.generate(onSide.length, (i) => i),
              reason: '$n joueurs, cote $side');
          expect(onSide.every((s) => s.slotCount == onSide.length), isTrue,
              reason: '$n joueurs, cote $side : slotCount incoherent');
        }
      }
    });

    test('1 joueur ou moins : un seul siege en bas, pas de crash', () {
      expect(seatsFor(1).length, 1);
      expect(seatsFor(1).single.side, TableSide.bottom);
      expect(seatsFor(0), isEmpty);
    });
  });
}
