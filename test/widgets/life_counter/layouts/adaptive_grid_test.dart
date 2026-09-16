import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';

Widget _buildTestGrid({required int playerCount, bool includeCentralBar = true}) {
  final zones = List.generate(playerCount, (i) => Container(key: ValueKey('player_$i')));
  final bar = includeCentralBar ? Container(key: const ValueKey('central_bar'), height: 60) : null;
  return MaterialApp(
    home: Scaffold(
      body: AdaptiveGrid(
        playerZones: zones,
        centralBar: bar ?? const SizedBox(height: 60),
      ),
    ),
  );
}

void main() {
  group('AdaptiveGrid', () {
    testWidgets('renders 2 players: 1 top + 1 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 2));
      expect(find.byKey(const ValueKey('player_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('player_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('central_bar')), findsOneWidget);
    });

    testWidgets('renders 3 players: 2 top + 1 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 3));
      expect(find.byKey(const ValueKey('player_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('player_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('player_2')), findsOneWidget);
    });

    testWidgets('renders 4 players: 2 top + 2 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      for (int i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('renders 5 players: 3 top + 2 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 5));
      for (int i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('renders 6 players: 3 top + 3 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 6));
      for (int i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('renders 7 players: 4 top + 3 bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 7));
      for (int i = 0; i < 7; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('renders 8 players: 4 top + 4 bottom with sub-grids', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 8));
      for (int i = 0; i < 8; i++) {
        expect(find.byKey(ValueKey('player_$i')), findsOneWidget);
      }
    });

    testWidgets('top row players are rotated 180 degrees', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 2));
      final rotatedBoxes = tester.widgetList<RotatedBox>(find.byType(RotatedBox));
      expect(rotatedBoxes.any((r) => r.quarterTurns == 2), isTrue);
    });

    testWidgets('central bar is rendered between top and bottom', (tester) async {
      await tester.pumpWidget(_buildTestGrid(playerCount: 4));
      expect(find.byKey(const ValueKey('central_bar')), findsOneWidget);
    });
  });
}
