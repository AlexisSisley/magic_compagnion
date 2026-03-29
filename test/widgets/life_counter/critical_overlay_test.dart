// Fichier : test/widgets/life_counter/critical_overlay_test.dart
// Task 13: TDD tests for CriticalOverlay widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/critical_overlay.dart';
import 'package:magic_companion/widgets/life_counter/animations/animation_service.dart';

void main() {
  group('CriticalOverlay', () {
    Widget buildWidget({
      required CriticalLevel level,
      Widget child = const SizedBox(width: 100, height: 100),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: CriticalOverlay(
            level: level,
            child: child,
          ),
        ),
      );
    }

    testWidgets('wraps child content', (tester) async {
      const childKey = Key('child');
      await tester.pumpWidget(buildWidget(
        level: CriticalLevel.safe,
        child: const SizedBox(key: childKey, width: 100, height: 100),
      ));
      expect(find.byKey(childKey), findsOneWidget);
    });

    testWidgets('safe level renders transparent overlay (no colored border)', (tester) async {
      await tester.pumpWidget(buildWidget(level: CriticalLevel.safe));
      await tester.pump();

      // Find CriticalOverlay widget
      expect(find.byType(CriticalOverlay), findsOneWidget);

      // For safe level the overlay color should be transparent
      final criticalOverlay = tester.widget<CriticalOverlay>(find.byType(CriticalOverlay));
      expect(criticalOverlay.level, CriticalLevel.safe);
    });

    testWidgets('warning level has amber/yellow border color', (tester) async {
      await tester.pumpWidget(buildWidget(level: CriticalLevel.warning));
      await tester.pump();

      final criticalOverlay = tester.widget<CriticalOverlay>(find.byType(CriticalOverlay));
      expect(criticalOverlay.level, CriticalLevel.warning);
      expect(CriticalOverlay.borderColorForLevel(CriticalLevel.warning), isA<Color>());

      // Warning border should be amber/yellow hue
      final color = CriticalOverlay.borderColorForLevel(CriticalLevel.warning);
      // Amber/orange hue: red channel high, green channel medium/high, blue channel low
      expect(color.r, greaterThan(0.5));
      expect(color.b, lessThan(0.5));
    });

    testWidgets('danger level has red border color', (tester) async {
      await tester.pumpWidget(buildWidget(level: CriticalLevel.danger));
      await tester.pump();

      final criticalOverlay = tester.widget<CriticalOverlay>(find.byType(CriticalOverlay));
      expect(criticalOverlay.level, CriticalLevel.danger);

      final color = CriticalOverlay.borderColorForLevel(CriticalLevel.danger);
      // Red: high red channel, low green
      expect(color.r, greaterThan(0.5));
      expect(color.g, lessThan(0.5));
    });

    testWidgets('lethal level has deep red border color', (tester) async {
      await tester.pumpWidget(buildWidget(level: CriticalLevel.lethal));
      await tester.pump();

      final criticalOverlay = tester.widget<CriticalOverlay>(find.byType(CriticalOverlay));
      expect(criticalOverlay.level, CriticalLevel.lethal);

      final color = CriticalOverlay.borderColorForLevel(CriticalLevel.lethal);
      expect(color, isA<Color>());
      // Deep red: red channel dominant
      expect(color.r, greaterThan(0.3));
    });

    testWidgets('safe level produces transparent border color', (tester) async {
      await tester.pumpWidget(buildWidget(level: CriticalLevel.safe));
      await tester.pump();

      final color = CriticalOverlay.borderColorForLevel(CriticalLevel.safe);
      expect(color.a, equals(0.0));
    });

    testWidgets('animation duration varies by level', (tester) async {
      expect(CriticalOverlay.durationForLevel(CriticalLevel.safe), const Duration(milliseconds: 1500));
      expect(CriticalOverlay.durationForLevel(CriticalLevel.warning), const Duration(milliseconds: 1500));
      expect(CriticalOverlay.durationForLevel(CriticalLevel.danger), const Duration(milliseconds: 1000));
      expect(CriticalOverlay.durationForLevel(CriticalLevel.lethal), const Duration(milliseconds: 600));
    });

    testWidgets('warning level starts animation', (tester) async {
      await tester.pumpWidget(buildWidget(level: CriticalLevel.warning));
      await tester.pump();
      // Widget is present and no errors thrown
      expect(find.byType(CriticalOverlay), findsOneWidget);
    });

    testWidgets('level can change from safe to danger', (tester) async {
      CriticalLevel level = CriticalLevel.safe;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    CriticalOverlay(
                      level: level,
                      child: const SizedBox(width: 100, height: 100),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => level = CriticalLevel.danger),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.byType(CriticalOverlay), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pump();
      expect(find.byType(CriticalOverlay), findsOneWidget);
    });
  });
}
