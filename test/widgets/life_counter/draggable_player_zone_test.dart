// Fichier : test/widgets/life_counter/draggable_player_zone_test.dart
// Task 17: Tests for DraggablePlayerZone

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/draggable_player_zone.dart';

void main() {
  group('DraggablePlayerZone', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DraggablePlayerZone(
            index: 0,
            onReorder: (_, __) {},
            child: const Text('Player 1'),
          ),
        ),
      ));

      expect(find.text('Player 1'), findsOneWidget);
    });

    testWidgets('contains a LongPressDraggable', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DraggablePlayerZone(
            index: 0,
            onReorder: (_, __) {},
            child: const Text('Player 1'),
          ),
        ),
      ));

      expect(find.byType(LongPressDraggable<int>), findsOneWidget);
    });

    testWidgets('contains a DragTarget', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DraggablePlayerZone(
            index: 0,
            onReorder: (_, __) {},
            child: const Text('Player 1'),
          ),
        ),
      ));

      expect(find.byType(DragTarget<int>), findsOneWidget);
    });

    testWidgets('multiple zones render without error', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: DraggablePlayerZone(
                  index: 0,
                  onReorder: (_, __) {},
                  child: const Text('P1'),
                ),
              ),
              Expanded(
                child: DraggablePlayerZone(
                  index: 1,
                  onReorder: (_, __) {},
                  child: const Text('P2'),
                ),
              ),
            ],
          ),
        ),
      ));

      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P2'), findsOneWidget);
    });
  });
}
