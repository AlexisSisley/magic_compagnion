// Fichier : test/widgets/life_counter/elimination_overlay_test.dart
// Task 13: TDD tests for EliminationOverlay widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/elimination_overlay.dart';

void main() {
  group('EliminationOverlay', () {
    Widget buildWidget({
      required bool isEliminated,
      VoidCallback? onAnimationComplete,
      Widget child = const SizedBox(
        key: Key('child'),
        width: 100,
        height: 100,
      ),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: EliminationOverlay(
              isEliminated: isEliminated,
              onAnimationComplete: onAnimationComplete,
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets('non-eliminated state shows child', (tester) async {
      await tester.pumpWidget(buildWidget(isEliminated: false));
      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('non-eliminated state does not show skull icon', (tester) async {
      await tester.pumpWidget(buildWidget(isEliminated: false));
      await tester.pump();
      expect(find.byIcon(EliminationOverlay.eliminationIcon), findsNothing);
    });

    testWidgets('contains child widget when not eliminated', (tester) async {
      const childKey = Key('my_child');
      await tester.pumpWidget(buildWidget(
        isEliminated: false,
        child: const Text('Player 1', key: childKey),
      ));
      expect(find.byKey(childKey), findsOneWidget);
    });

    testWidgets('eliminated state eventually shows elimination icon after animation', (tester) async {
      await tester.pumpWidget(buildWidget(isEliminated: true));

      // Pump through all animation phases (900ms total)
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));

      // After animation completes, elimination icon should be visible
      expect(find.byIcon(EliminationOverlay.eliminationIcon), findsOneWidget);
    });

    testWidgets('child is still present when eliminated', (tester) async {
      const childKey = Key('child_under');
      await tester.pumpWidget(buildWidget(
        isEliminated: true,
        child: const SizedBox(key: childKey, width: 100, height: 100),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(childKey), findsOneWidget);
    });

    testWidgets('onAnimationComplete callback is called after animation', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildWidget(
        isEliminated: true,
        onAnimationComplete: () => called = true,
      ));

      // Pump through all 900ms of animation
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 100));

      expect(called, isTrue);
    });

    testWidgets('widget can switch from eliminated to not-eliminated', (tester) async {
      bool isEliminated = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: EliminationOverlay(
                        isEliminated: isEliminated,
                        child: const SizedBox(width: 100, height: 100),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => isEliminated = false),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.byIcon(EliminationOverlay.eliminationIcon), findsNothing);
    });

    testWidgets('EliminationOverlay widget exists in tree', (tester) async {
      await tester.pumpWidget(buildWidget(isEliminated: false));
      expect(find.byType(EliminationOverlay), findsOneWidget);
    });
  });
}
