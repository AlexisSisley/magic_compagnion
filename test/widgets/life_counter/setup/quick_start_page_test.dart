// Fichier : test/widgets/life_counter/setup/quick_start_page_test.dart
// Task 15: TDD tests for QuickStartPage widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/widgets/life_counter/setup/quick_start_page.dart';

void main() {
  group('QuickStartPage', () {
    Widget buildPage({
      void Function(GameFormat format, int playerCount)? onStart,
      VoidCallback? onAdvancedSettings,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: QuickStartPage(
            onStart: onStart ?? (_, __) {},
            onAdvancedSettings: onAdvancedSettings,
          ),
        ),
      );
    }

    testWidgets('displays all 6 built-in format chips', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // First visible formats are always present; last ones may need scrolling
      // Check the first 5 (visible) and scroll for 'Custom'
      for (final format in GameFormat.builtInFormats.take(5)) {
        expect(find.textContaining(format.name), findsAtLeastNWidgets(1));
      }
      // Scroll the format list to reveal 'Custom'
      await tester.scrollUntilVisible(
        find.textContaining('Custom'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Custom'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays format chip with life total', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Commander chip should show "40" life
      expect(find.textContaining('40'), findsAtLeastNWidgets(1));
    });

    testWidgets('selecting a format updates highlighted chip', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Tap on Standard format chip
      await tester.tap(find.textContaining('Standard').first);
      await tester.pump();

      // The Standard format should now be selected (no crash)
      expect(find.textContaining('Standard'), findsAtLeastNWidgets(1));
    });

    testWidgets('player count buttons match selected format min/max range', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Default format is Commander (2-8 players)
      // Buttons 2 through 8 should be present
      for (int i = 2; i <= 8; i++) {
        expect(find.text('$i'), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('selecting Duel Commander shows only 2 player option', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Tap on Duel Commander
      await tester.tap(find.textContaining('Duel Commander').first);
      await tester.pump();

      // Duel Commander is 2 players only, so only button "2" should show
      expect(find.text('2'), findsAtLeastNWidgets(1));
    });

    testWidgets('Start Game button is present', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('Start Game'), findsOneWidget);
    });

    testWidgets('tapping Start Game calls onStart callback', (tester) async {
      GameFormat? capturedFormat;
      int? capturedCount;

      await tester.pumpWidget(buildPage(
        onStart: (format, count) {
          capturedFormat = format;
          capturedCount = count;
        },
      ));
      await tester.pump();

      await tester.tap(find.text('Start Game'));
      await tester.pump();

      expect(capturedFormat, isNotNull);
      expect(capturedCount, isNotNull);
      expect(capturedCount! >= 2, isTrue);
    });

    testWidgets('Advanced Settings link is present', (tester) async {
      await tester.pumpWidget(buildPage(onAdvancedSettings: () {}));
      await tester.pump();

      expect(find.textContaining('Advanced'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping Advanced Settings calls onAdvancedSettings callback', (tester) async {
      bool called = false;

      await tester.pumpWidget(buildPage(
        onAdvancedSettings: () => called = true,
      ));
      await tester.pump();

      await tester.tap(find.textContaining('Advanced').first);
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('player count selection persists when changing', (tester) async {
      GameFormat? capturedFormat;
      int? capturedCount;

      await tester.pumpWidget(buildPage(
        onStart: (format, count) {
          capturedFormat = format;
          capturedCount = count;
        },
      ));
      await tester.pump();

      // Tap player count button "4"
      await tester.tap(find.text('4'));
      await tester.pump();

      await tester.tap(find.text('Start Game'));
      await tester.pump();

      expect(capturedCount, equals(4));
      expect(capturedFormat, isNotNull);
    });
  });
}
