// Fichier : test/widgets/life_counter/radial_menu_test.dart
// Task 14: TDD tests for RadialMenu widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/radial_menu.dart';

void main() {
  group('RadialMenu', () {
    Widget buildMenu({
      VoidCallback? onMonarchToggle,
      VoidCallback? onCommanderDamage,
      VoidCallback? onEliminate,
      VoidCallback? onReset,
      VoidCallback? onClose,
      Offset position = const Offset(200, 200),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const SizedBox(width: 400, height: 400),
              RadialMenu(
                position: position,
                onMonarchToggle: onMonarchToggle ?? () {},
                onCommanderDamage: onCommanderDamage ?? () {},
                onEliminate: onEliminate ?? () {},
                onReset: onReset ?? () {},
                onClose: onClose ?? () {},
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders 4 action buttons when shown', (tester) async {
      await tester.pumpWidget(buildMenu());
      await tester.pumpAndSettle();

      // All 4 action buttons should be present
      expect(find.byType(RadialMenuButton), findsNWidgets(4));
    });

    testWidgets('tapping Monarch button calls onMonarchToggle', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildMenu(
        onMonarchToggle: () => called = true,
        onClose: () {},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('radial_menu_monarch')),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('tapping Commander Damage button calls onCommanderDamage',
        (tester) async {
      bool called = false;
      await tester.pumpWidget(buildMenu(
        onCommanderDamage: () => called = true,
        onClose: () {},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('radial_menu_commander')),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('tapping Eliminate button calls onEliminate', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildMenu(
        onEliminate: () => called = true,
        onClose: () {},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('radial_menu_eliminate')),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('tapping Reset button calls onReset', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildMenu(
        onReset: () => called = true,
        onClose: () {},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('radial_menu_reset')),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('menu items have correct icons', (tester) async {
      await tester.pumpWidget(buildMenu());
      await tester.pumpAndSettle();

      expect(find.byIcon(RadialMenu.monarchIcon), findsOneWidget);
      expect(find.byIcon(RadialMenu.commanderIcon), findsOneWidget);
      expect(find.byIcon(RadialMenu.eliminateIcon), findsOneWidget);
      expect(find.byIcon(RadialMenu.resetIcon), findsOneWidget);
    });

    testWidgets('RadialMenu widget is present in widget tree', (tester) async {
      await tester.pumpWidget(buildMenu());
      await tester.pumpAndSettle();
      expect(find.byType(RadialMenu), findsOneWidget);
    });

    testWidgets('tapping an item calls onClose after the action',
        (tester) async {
      bool closeCalled = false;
      bool actionCalled = false;
      await tester.pumpWidget(buildMenu(
        onReset: () => actionCalled = true,
        onClose: () => closeCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('radial_menu_reset')),
          warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(actionCalled, isTrue);
      expect(closeCalled, isTrue);
    });
  });

  group('RadialMenuTrigger', () {
    testWidgets('renders child widget', (tester) async {
      const childKey = Key('trigger_child');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadialMenuTrigger(
              onMonarchToggle: () {},
              onCommanderDamage: () {},
              onEliminate: () {},
              onReset: () {},
              child: const SizedBox(key: childKey, width: 200, height: 200),
            ),
          ),
        ),
      );

      expect(find.byKey(childKey), findsOneWidget);
    });

    testWidgets('does not show menu before long press', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadialMenuTrigger(
              onMonarchToggle: () {},
              onCommanderDamage: () {},
              onEliminate: () {},
              onReset: () {},
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );

      expect(find.byType(RadialMenu), findsNothing);
    });

    testWidgets('shows RadialMenu after long press', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadialMenuTrigger(
              onMonarchToggle: () {},
              onCommanderDamage: () {},
              onEliminate: () {},
              onReset: () {},
              child: Container(
                width: 200,
                height: 200,
                color: Colors.blue, // needs color for hit-testing
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.byType(RadialMenuTrigger), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(RadialMenu), findsOneWidget);
    });
  });
}
