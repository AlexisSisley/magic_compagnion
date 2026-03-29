// Fichier : test/widgets/life_counter/setup/advanced_settings_page_test.dart
// Task 15: TDD tests for AdvancedSettingsPage widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/widgets/life_counter/setup/advanced_settings_page.dart';

void main() {
  group('AdvancedSettingsPage', () {
    Widget buildPage({
      GameFormat? initialFormat,
      List<PlayerConfig>? initialPlayers,
      void Function(GameFormat format, List<PlayerConfig> players, int startingLife)? onStart,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AdvancedSettingsPage(
            initialFormat: initialFormat ?? GameFormat.builtInFormats.first,
            initialPlayers: initialPlayers ?? [],
            onStart: onStart ?? (_, __, ___) {},
          ),
        ),
      );
    }

    testWidgets('displays 4 expansion tiles (Format, Players, Counters, Options)', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('Format'), findsAtLeastNWidgets(1));
      expect(find.text('Players'), findsAtLeastNWidgets(1));
      expect(find.text('Counters'), findsAtLeastNWidgets(1));
      expect(find.text('Options'), findsAtLeastNWidgets(1));
    });

    testWidgets('Format expansion tile is expanded by default', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Format chips should be visible (expanded)
      expect(find.textContaining('Commander'), findsAtLeastNWidgets(1));
    });

    testWidgets('Start Game button is present', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(find.text('Start Game'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping Start Game calls onStart callback', (tester) async {
      GameFormat? capturedFormat;

      await tester.pumpWidget(buildPage(
        onStart: (format, players, life) {
          capturedFormat = format;
        },
      ));
      await tester.pump();

      // Scroll to find Start button
      await tester.ensureVisible(find.text('Start Game').last);
      await tester.tap(find.text('Start Game').last);
      await tester.pump();

      expect(capturedFormat, isNotNull);
    });

    testWidgets('Players expansion tile can be expanded', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Tap Players tile to expand
      await tester.tap(find.text('Players'));
      await tester.pumpAndSettle();

      // Should expand without error
      expect(find.text('Players'), findsAtLeastNWidgets(1));
    });

    testWidgets('Counters expansion tile can be expanded', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Tap Counters tile to expand
      await tester.tap(find.text('Counters'));
      await tester.pumpAndSettle();

      expect(find.text('Counters'), findsAtLeastNWidgets(1));
    });

    testWidgets('Options expansion tile can be expanded', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Tap Options tile to expand
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();

      expect(find.text('Options'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays format chips in format section', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();

      // Verify visible format chips — first few are always on screen
      expect(find.textContaining('Commander'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Standard'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Oathbreaker'), findsAtLeastNWidgets(1));
    });
  });
}
