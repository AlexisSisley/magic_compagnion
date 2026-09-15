// test/widgets/life_counter/zone/life_dial_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';

Future<List<int>> pumpDial(
  WidgetTester tester, {
  int life = 40,
  int pendingDelta = 0,
}) async {
  final deltas = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: LifeDial(
              playerId: 0,
              life: life,
              pendingDelta: pendingDelta,
              onDelta: deltas.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return deltas;
}

void main() {
  testWidgets('affiche les points de vie', (tester) async {
    await pumpDial(tester, life: 34);
    expect(find.text('34'), findsOneWidget);
  });

  testWidgets('un tap à gauche retire un point', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));
    await tester.tapAt(Offset(dial.left + dial.width * 0.25, dial.center.dy));
    await tester.pumpAndSettle();
    expect(deltas, [-1]);
  });

  testWidgets('un tap à droite ajoute un point', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));
    await tester.tapAt(Offset(dial.left + dial.width * 0.75, dial.center.dy));
    await tester.pumpAndSettle();
    expect(deltas, [1]);
  });

  testWidgets('le maintien répète, et de plus en plus vite', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    final gesture = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    // Premier delta immédiat, puis répétition après le délai initial.
    await tester.pump(const Duration(milliseconds: 500));
    final apresDelaiInitial = deltas.length;

    await tester.pump(const Duration(milliseconds: 500));
    final apresUneSeconde = deltas.length;

    await gesture.up();
    await tester.pumpAndSettle();

    expect(apresDelaiInitial, greaterThanOrEqualTo(2),
        reason: 'le maintien doit répéter après le délai initial');
    expect(apresUneSeconde - apresDelaiInitial,
        greaterThan(apresDelaiInitial),
        reason: 'la répétition doit accélérer, pas rester à cadence constante');
    expect(deltas.every((d) => d == -1), isTrue);
  });

  testWidgets('relâcher arrête la répétition', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    final gesture = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();
    final frozen = deltas.length;

    await tester.pump(const Duration(seconds: 1));
    expect(deltas.length, frozen, reason: 'plus aucun delta après le relâchement');
  });

  testWidgets('le badge de dégâts en attente s\'affiche quand il est non nul',
      (tester) async {
    await pumpDial(tester, life: 40, pendingDelta: -5);
    expect(find.text('-5'), findsOneWidget);
  });

  testWidgets('aucun badge quand le delta en attente est nul', (tester) async {
    await pumpDial(tester, life: 40, pendingDelta: 0);
    expect(find.text('0'), findsNothing);
  });
}
