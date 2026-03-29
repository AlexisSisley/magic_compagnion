// Fichier : test/widgets/life_counter/layouts/layout_widgets_test.dart
// Task 16: Tests for FaceToFaceLayout, GridLayout, FocusLayout

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/face_to_face_layout.dart';
import 'package:magic_companion/widgets/life_counter/layouts/grid_layout.dart';
import 'package:magic_companion/widgets/life_counter/layouts/focus_layout.dart';
import 'package:magic_companion/widgets/life_counter/player_zone_compact.dart';
import 'package:magic_companion/widgets/life_counter/game_control_bar.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _zone(String label) => Container(
      key: ValueKey(label),
      color: Colors.blue,
      child: Center(child: Text(label)),
    );

void main() {
  group('FaceToFaceLayout', () {
    testWidgets('renders both player zones', (tester) async {
      await tester.pumpWidget(_app(FaceToFaceLayout(
        topPlayer: _zone('P1'),
        bottomPlayer: _zone('P2'),
      )));

      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);
    });

    testWidgets('top player is inside RotatedBox', (tester) async {
      await tester.pumpWidget(_app(FaceToFaceLayout(
        topPlayer: _zone('P1'),
        bottomPlayer: _zone('P2'),
      )));

      expect(find.byType(RotatedBox), findsOneWidget);
    });
  });

  group('GridLayout', () {
    testWidgets('renders 4 player zones in grid', (tester) async {
      await tester.pumpWidget(_app(GridLayout(
        playerZones: [_zone('P1'), _zone('P2'), _zone('P3'), _zone('P4')],
      )));

      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);
      expect(find.text('P3'), findsOneWidget);
      expect(find.text('P4'), findsOneWidget);
    });

    testWidgets('renders 3 players: 2 top, 1 bottom full-width', (tester) async {
      await tester.pumpWidget(_app(GridLayout(
        playerZones: [_zone('P1'), _zone('P2'), _zone('P3')],
      )));

      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);
      expect(find.text('P3'), findsOneWidget);
    });

    testWidgets('top row zones are rotated 180°', (tester) async {
      await tester.pumpWidget(_app(GridLayout(
        playerZones: [_zone('P1'), _zone('P2'), _zone('P3'), _zone('P4')],
      )));

      // Top row has 2 RotatedBox widgets
      expect(find.byType(RotatedBox), findsNWidgets(2));
    });
  });

  group('FocusLayout', () {
    testWidgets('renders owner zone and adversary zones', (tester) async {
      await tester.pumpWidget(_app(FocusLayout(
        ownerZone: _zone('Owner'),
        adversaryZones: [_zone('A1'), _zone('A2'), _zone('A3')],
      )));

      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);
      expect(find.text('A3'), findsOneWidget);
    });

    testWidgets('with 3 or fewer adversaries uses Row layout', (tester) async {
      await tester.pumpWidget(_app(FocusLayout(
        ownerZone: _zone('Owner'),
        adversaryZones: [_zone('A1'), _zone('A2')],
      )));

      // Should not be a horizontal ListView (Row instead)
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);
    });
  });

  group('PlayerZoneCompact', () {
    testWidgets('shows player name and life total', (tester) async {
      await tester.pumpWidget(_app(PlayerZoneCompact(
        playerName: 'Alice',
        lifeTotal: 38,
        playerColor: Colors.blue,
      )));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);
    });

    testWidgets('shows skull when eliminated', (tester) async {
      await tester.pumpWidget(_app(PlayerZoneCompact(
        playerName: 'Bob',
        lifeTotal: 0,
        playerColor: Colors.red,
        isEliminated: true,
      )));

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('☠'), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_app(PlayerZoneCompact(
        playerName: 'Eve',
        lifeTotal: 20,
        playerColor: Colors.green,
        onTap: () => tapped = true,
      )));

      await tester.tap(find.text('Eve'));
      expect(tapped, isTrue);
    });
  });

  group('GameControlBar', () {
    testWidgets('renders all 5 action buttons', (tester) async {
      await tester.pumpWidget(_app(GameControlBar()));

      expect(find.byIcon(Icons.casino), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    });

    testWidgets('shows timer text when provided', (tester) async {
      await tester.pumpWidget(_app(GameControlBar(timerText: '12:34')));

      expect(find.text('12:34'), findsOneWidget);
      // Timer icon should NOT appear when text is shown
      expect(find.byIcon(Icons.timer), findsNothing);
    });

    testWidgets('onEndGame callback fires', (tester) async {
      bool ended = false;
      await tester.pumpWidget(_app(GameControlBar(
        onEndGame: () => ended = true,
      )));

      await tester.tap(find.byIcon(Icons.stop_circle_outlined));
      expect(ended, isTrue);
    });

    testWidgets('onSwitchLayout callback fires', (tester) async {
      bool switched = false;
      await tester.pumpWidget(_app(GameControlBar(
        onSwitchLayout: () => switched = true,
      )));

      await tester.tap(find.byIcon(Icons.grid_view));
      expect(switched, isTrue);
    });
  });
}
