// test/widgets/life_counter/zone/life_dial_affordance_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';

/// Harnais minimal : un `LifeDial` seul, dans une boîte de taille connue.
///
/// `playerId` est requis par le vrai constructeur (absent du brief d'origine,
/// qui ne l'avait pas relevé) -- n'importe quelle valeur convient, aucun
/// test ici ne dépend du provider qu'il indexe. `onDelta` est obligatoire ;
/// on l'ignore ici, ces tests portent sur le rendu et non sur l'émission.
Widget harness() => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: LifeDial(
                playerId: 0,
                life: 40,
                onDelta: (_, {silent = false}) {},
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('chaque moitié porte son repère', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('−'), findsOneWidget); // le signe moins typographique
    expect(find.text('+'), findsOneWidget);
  });

  testWidgets('la moitié touchée s éclaircit tant que le doigt est posé',
      (tester) async {
    await tester.pumpWidget(harness());
    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LifeDial)) - const Offset(40, 0));
    await tester.pump();

    final highlight = tester.widget<Container>(
        find.byKey(const Key('life-dial-highlight-minus')));
    expect((highlight.decoration as BoxDecoration).color?.a, greaterThan(0.0));

    await gesture.up();
    await tester.pumpAndSettle();
    final after = tester.widget<Container>(
        find.byKey(const Key('life-dial-highlight-minus')));
    expect((after.decoration as BoxDecoration).color?.a ?? 0.0, 0.0);
  });
}
