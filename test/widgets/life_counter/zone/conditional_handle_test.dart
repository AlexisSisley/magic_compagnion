// test/widgets/life_counter/zone/conditional_handle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';

Future<void> pumpHandle(WidgetTester tester, CounterSummary summary) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: ConditionalHandle(summary: summary),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('isCalm est vrai quand tout est à zéro', () {
    expect(const CounterSummary().isCalm, isTrue);
    expect(const CounterSummary(poison: 1).isCalm, isFalse);
    expect(const CounterSummary(worstCommanderDamage: 7).isCalm, isFalse);
  });

  testWidgets('à l\'état calme, la poignée n\'affiche aucun chiffre',
      (tester) async {
    await pumpHandle(tester, const CounterSummary());
    expect(find.textContaining('0'), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('un compteur non nul fait apparaître le résumé', (tester) async {
    await pumpHandle(tester, const CounterSummary(poison: 3));
    expect(find.textContaining('3'), findsOneWidget);
  });

  testWidgets('n\'affiche que les compteurs non nuls', (tester) async {
    await pumpHandle(
      tester,
      const CounterSummary(poison: 3, worstCommanderDamage: 12),
    );
    expect(find.textContaining('3'), findsOneWidget);
    expect(find.textContaining('12'), findsOneWidget);
    // L'énergie et la taxe sont à zéro : elles ne doivent pas apparaître.
    expect(find.textContaining('⚡'), findsNothing);
  });

  testWidgets('la hauteur est identique au repos et en alerte', (tester) async {
    await pumpHandle(tester, const CounterSummary());
    final calme = tester.getSize(find.byType(ConditionalHandle)).height;

    await pumpHandle(tester, const CounterSummary(poison: 3, energy: 2));
    final alerte = tester.getSize(find.byType(ConditionalHandle)).height;

    expect(alerte, calme,
        reason: 'la hauteur est réservée : le chiffre de PV ne doit jamais se '
            'recaler en cours de partie');
    expect(calme, ConditionalHandle.reservedHeight);
  });

  testWidgets('le tap déclenche le callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConditionalHandle(
            summary: const CounterSummary(poison: 1),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ConditionalHandle));
    expect(tapped, isTrue);
  });
}
