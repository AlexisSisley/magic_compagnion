import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/widgets/life_counter/player_history_sheet.dart';

PlayerState _createTestPlayer() {
  return PlayerState(
    playerId: 0,
    config: const PlayerConfig(
      id: '0', name: 'Alice', type: PlayerType.guest, colorValue: 0xFFFF0000,
    ),
    life: 33,
    lifeHistory: const [
      LifeEvent(delta: -3, timestamp: Duration(minutes: 1, seconds: 30)),
      LifeEvent(delta: -5, source: 'Commander: Bob', timestamp: Duration(minutes: 3)),
      LifeEvent(delta: 1, timestamp: Duration(minutes: 4, seconds: 15)),
    ],
  );
}

void main() {
  group('PlayerHistorySheet', () {
    testWidgets('renders player name in header', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerHistorySheet(
            playerState: _createTestPlayer(),
            startingLife: 40,
          ),
        ),
      ));
      expect(find.textContaining('Alice'), findsOneWidget);
    });

    testWidgets('renders all events for the player', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerHistorySheet(
            playerState: _createTestPlayer(),
            startingLife: 40,
          ),
        ),
      ));
      expect(find.textContaining('-3'), findsOneWidget);
      expect(find.textContaining('-5'), findsOneWidget);
      expect(find.textContaining('+1'), findsOneWidget);
    });

    testWidgets('shows running life total after each event', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerHistorySheet(
            playerState: _createTestPlayer(),
            startingLife: 40,
          ),
        ),
      ));
      // Starting 40, events: -3 (→37), -5 (→32), +1 (→33)
      expect(find.textContaining('37'), findsWidgets);
      expect(find.textContaining('32'), findsWidgets);
      expect(find.textContaining('33'), findsWidgets);
    });

    testWidgets('shows commander source label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerHistorySheet(
            playerState: _createTestPlayer(),
            startingLife: 40,
          ),
        ),
      ));
      expect(find.textContaining('Commander'), findsWidgets);
    });
  });
}
