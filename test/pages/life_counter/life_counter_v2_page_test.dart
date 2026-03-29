// Fichier : test/pages/life_counter/life_counter_v2_page_test.dart
// Task 18: Tests for LifeCounterV2Page integration

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/pages/life_counter/life_counter_v2_page.dart';
import 'package:magic_companion/models/game_format.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LifeCounterV2Page', () {
    testWidgets('shows Quick Start page on initial load', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: LifeCounterV2Page()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quick Start page should be visible
      expect(find.text('Quick Start'), findsOneWidget);
      expect(find.text('Start Game'), findsOneWidget);
    });

    testWidgets('format chips are visible on setup', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: LifeCounterV2Page()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Commander'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Standard'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping Start Game transitions to game view', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: LifeCounterV2Page()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Start Game
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Quick Start should be gone, game should show PlayerZone(s)
      expect(find.text('Quick Start'), findsNothing);
    });

    testWidgets('game control bar shows after starting game', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: LifeCounterV2Page()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Control bar icons should be visible
      expect(find.byIcon(Icons.casino), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    });
  });
}
