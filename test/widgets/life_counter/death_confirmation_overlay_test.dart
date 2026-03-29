import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/death_confirmation_overlay.dart';

void main() {
  group('DeathConfirmationOverlay', () {
    testWidgets('renders player name and life total', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Alice',
            currentLife: -3,
            onDismiss: () {},
            onConfirmElimination: () {},
          ),
        ),
      ));
      expect(find.textContaining('Alice'), findsOneWidget);
      expect(find.textContaining('-3'), findsOneWidget);
    });

    testWidgets('renders Non and Oui buttons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Bob',
            currentLife: 0,
            onDismiss: () {},
            onConfirmElimination: () {},
          ),
        ),
      ));
      expect(find.textContaining('Non'), findsOneWidget);
      expect(find.textContaining('Oui'), findsOneWidget);
    });

    testWidgets('tapping Non calls onDismiss', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Bob',
            currentLife: 0,
            onDismiss: () => dismissed = true,
            onConfirmElimination: () {},
          ),
        ),
      ));
      await tester.tap(find.textContaining('Non'));
      expect(dismissed, isTrue);
    });

    testWidgets('tapping Oui calls onConfirmElimination', (tester) async {
      bool eliminated = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Bob',
            currentLife: 0,
            onDismiss: () {},
            onConfirmElimination: () => eliminated = true,
          ),
        ),
      ));
      await tester.tap(find.textContaining('Oui'));
      expect(eliminated, isTrue);
    });

    testWidgets('displays skull emoji', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeathConfirmationOverlay(
            playerName: 'Bob',
            currentLife: 0,
            onDismiss: () {},
            onConfirmElimination: () {},
          ),
        ),
      ));
      expect(find.textContaining('\u{1F480}'), findsOneWidget);
    });
  });
}
