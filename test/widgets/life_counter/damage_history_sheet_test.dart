import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/widgets/life_counter/damage_history_sheet.dart';

GameSession _createTestSession() {
  final format = GameFormat.builtInFormats.first; // Commander
  final configs = [
    const PlayerConfig(id: '0', name: 'Alice', type: PlayerType.guest, colorValue: 0xFFFF0000),
    const PlayerConfig(id: '1', name: 'Bob', type: PlayerType.guest, colorValue: 0xFF0000FF),
  ];
  var session = GameSession.newGame(format: format, playerConfigs: configs);
  final players = session.players.map((p) {
    if (p.playerId == 0) {
      return p.copyWith(
        life: 37,
        lifeHistory: [
          const LifeEvent(delta: -3, timestamp: Duration(minutes: 2)),
        ],
      );
    }
    if (p.playerId == 1) {
      return p.copyWith(
        life: 35,
        lifeHistory: [
          const LifeEvent(delta: -5, source: 'Commander: Alice', timestamp: Duration(minutes: 3)),
        ],
      );
    }
    return p;
  }).toList();
  return session.copyWith(players: players);
}

void main() {
  group('DamageHistorySheet', () {
    testWidgets('renders header', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (_) {},
          ),
        ),
      ));
      expect(find.textContaining('Damage Log'), findsOneWidget);
    });

    testWidgets('renders all events when no filter', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (_) {},
          ),
        ),
      ));
      expect(find.textContaining('-3'), findsOneWidget);
      expect(find.textContaining('-5'), findsOneWidget);
    });

    testWidgets('filters events by player', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: 0,
            onFilterChanged: (_) {},
          ),
        ),
      ));
      expect(find.textContaining('-3'), findsOneWidget);
      expect(find.textContaining('-5'), findsNothing);
    });

    testWidgets('renders filter chips for each player', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (_) {},
          ),
        ),
      ));
      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Bob'), findsWidgets);
    });

    testWidgets('shows commander source label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (_) {},
          ),
        ),
      ));
      expect(find.textContaining('Commander'), findsWidgets);
    });

    testWidgets('tapping filter chip calls onFilterChanged', (tester) async {
      int? selectedFilter;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DamageHistorySheet(
            session: _createTestSession(),
            filterPlayerId: null,
            onFilterChanged: (id) => selectedFilter = id,
          ),
        ),
      ));
      final aliceChips = find.text('Alice');
      if (aliceChips.evaluate().length > 1) {
        await tester.tap(aliceChips.last);
      } else {
        await tester.tap(aliceChips);
      }
      expect(selectedFilter, equals(0));
    });
  });
}
