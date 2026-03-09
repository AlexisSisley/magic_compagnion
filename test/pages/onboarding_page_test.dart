// Test : lib/pages/onboarding/onboarding_page.dart (Sprint 14, US-14.4)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/pages/onboarding/onboarding_page.dart';

void main() {
  group('OnboardingPage', () {
    Widget buildTestWidget() {
      return const MaterialApp(
        home: OnboardingPage(),
      );
    }

    testWidgets('affiche le premier ecran avec le titre', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Compteur de Vie'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
      expect(find.text('Passer'), findsOneWidget);
    });

    testWidgets('swipe vers le deuxieme ecran', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Swipe gauche pour passer au 2e ecran
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Scanner & Collection'), findsOneWidget);
    });

    testWidgets('swipe vers le troisieme ecran affiche le bouton final', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Swipe 2 fois
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Decks & Outils'), findsOneWidget);
      expect(find.text("C'est parti !"), findsOneWidget);
    });

    testWidgets('le bouton Suivant avance la page', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Compteur de Vie'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();

      expect(find.text('Scanner & Collection'), findsOneWidget);
    });

    testWidgets('affiche 3 indicateurs de page', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 3 AnimatedContainer pour les dots
      final dots = find.byType(AnimatedContainer);
      expect(dots, findsNWidgets(3));
    });

    testWidgets('affiche les icones correctes', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });

  group('kHasSeenOnboarding', () {
    test('est une constante string', () {
      expect(kHasSeenOnboarding, 'has_seen_onboarding');
    });
  });
}
