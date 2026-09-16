import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';

Widget _grid(int playerCount) {
  return MaterialApp(
    home: Scaffold(
      body: AdaptiveGrid(
        playerZones: List.generate(
          playerCount,
          (i) => Container(key: ValueKey('player_$i')),
        ),
        centralBar: Container(key: const ValueKey('central_bar'), height: 60),
      ),
    ),
  );
}

Offset _centerOf(WidgetTester tester, int index) =>
    tester.getCenter(find.byKey(ValueKey('player_$index')));

void main() {
  group('AdaptiveGrid — non-regression face-a-face', () {
    testWidgets('2 joueurs : joueur 0 au-dessus du joueur 1',
        (tester) async {
      await tester.pumpWidget(_grid(2));
      expect(_centerOf(tester, 0).dy, lessThan(_centerOf(tester, 1).dy));
    });

    testWidgets('3 joueurs : 1 en haut, 2 en bas cote a cote', (tester) async {
      await tester.pumpWidget(_grid(3));
      expect(_centerOf(tester, 0).dy, lessThan(_centerOf(tester, 1).dy));
      expect(_centerOf(tester, 1).dy, equals(_centerOf(tester, 2).dy));
      expect(_centerOf(tester, 1).dx, lessThan(_centerOf(tester, 2).dx));
    });

    testWidgets('7 joueurs : 3 en haut, 4 en bas', (tester) async {
      await tester.pumpWidget(_grid(7));
      for (int i = 3; i < 7; i++) {
        expect(_centerOf(tester, i).dy, greaterThan(_centerOf(tester, 0).dy), reason: 'joueur $i en bas');
      }
    });

    testWidgets('8 joueurs : deux sous-grilles 2x2', (tester) async {
      await tester.pumpWidget(_grid(8));
      // Moitie haute : 0 et 1 sur une rangee, 2 et 3 sur la suivante.
      expect(_centerOf(tester, 0).dy, equals(_centerOf(tester, 1).dy));
      expect(_centerOf(tester, 0).dy, lessThan(_centerOf(tester, 2).dy));
      expect(_centerOf(tester, 2).dy, equals(_centerOf(tester, 3).dy));
      // Moitie basse.
      expect(_centerOf(tester, 4).dy, equals(_centerOf(tester, 5).dy));
      expect(_centerOf(tester, 4).dy, lessThan(_centerOf(tester, 6).dy));
    });

    testWidgets('la barre centrale est rendue et separe les deux moities',
        (tester) async {
      await tester.pumpWidget(_grid(2));
      final bar = tester.getCenter(find.byKey(const ValueKey('central_bar')));
      expect(_centerOf(tester, 0).dy, lessThan(bar.dy));
      expect(_centerOf(tester, 1).dy, greaterThan(bar.dy));
    });

    testWidgets('AdaptiveGrid ne contient aucune RotatedBox', (tester) async {
      // Verifiez que la grille ne tourne pas — la rotation est appliquee par PlayerZone.
      await tester.pumpWidget(_grid(2));
      expect(
        find.descendant(
          of: find.byType(AdaptiveGrid),
          matching: find.byType(RotatedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('4 joueurs : test presente mais non discriminant', (tester) async {
      await tester.pumpWidget(_grid(4));
      expect(find.byKey(const ValueKey('player_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('player_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('player_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('player_3')), findsOneWidget);
    });
  });
}
