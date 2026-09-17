// test/widgets/life_counter/zone/conditional_handle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';

const _poison = CounterType(
  id: 'poison',
  name: 'Poison',
  emoji: '☠️',
  color: 0xFF4CAF50,
  isBuiltIn: true,
  maxValue: 10,
);

const _energy = CounterType(
  id: 'energy',
  name: 'Énergie',
  emoji: '⚡',
  color: 0xFFFF9800,
  isBuiltIn: true,
);

/// Compteur PERSONNALISÉ quelconque -- ni "poison" ni aucun intégré -- pour
/// prouver que `CounterSummary` ne connaît aucun nom de compteur en dur
/// (lot 5, tâche 3b : avant cette tâche, un compteur personnalisé ne
/// pouvait structurellement jamais apparaître sur la poignée).
const _custom = CounterType(
  id: 'custom_rage',
  name: 'Rage',
  emoji: '🔥',
  color: 0xFF8B0000,
);

Future<void> pumpHandle(
  WidgetTester tester,
  CounterSummary summary, {
  int? maxVisibleChips,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: ConditionalHandle(
              summary: summary,
              maxVisibleChips: maxVisibleChips ?? 4,
            ),
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
    expect(const CounterSummary(counters: [MapEntry(_poison, 1)]).isCalm,
        isFalse);
    expect(const CounterSummary(worstCommanderDamage: 7).isCalm, isFalse);
  });

  test(
      'isCalm reste vrai quand tous les compteurs sont à zéro, même s\'il y '
      'en a beaucoup', () {
    expect(
      const CounterSummary(
        counters: [
          MapEntry(_poison, 0),
          MapEntry(_energy, 0),
          MapEntry(_custom, 0),
        ],
      ).isCalm,
      isTrue,
    );
  });

  testWidgets('à l\'état calme, la poignée n\'affiche aucun chiffre',
      (tester) async {
    await pumpHandle(tester, const CounterSummary());
    expect(find.textContaining('0'), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets(
      'un compteur PERSONNALISÉ non nul (ni poison ni aucun intégré) rend la '
      'poignée non calme et affiche sa puce', (tester) async {
    await pumpHandle(
      tester,
      const CounterSummary(counters: [MapEntry(_custom, 3)]),
    );
    expect(find.textContaining('3'), findsOneWidget);
    expect(find.textContaining('🔥'), findsOneWidget);
  });

  testWidgets('n\'affiche que les compteurs non nuls', (tester) async {
    await pumpHandle(
      tester,
      const CounterSummary(
        counters: [MapEntry(_poison, 3), MapEntry(_energy, 0)],
        worstCommanderDamage: 12,
      ),
    );
    expect(find.textContaining('3'), findsOneWidget);
    expect(find.textContaining('12'), findsOneWidget);
    // L'énergie est à zéro : elle ne doit pas apparaître.
    expect(find.textContaining('⚡'), findsNothing);
  });

  testWidgets('la puce du pire dégât de commandant est inchangée',
      (tester) async {
    await pumpHandle(tester, const CounterSummary(worstCommanderDamage: 12));
    expect(find.text('⚔ 12'), findsOneWidget);
  });

  testWidgets('la hauteur est identique au repos et en alerte', (tester) async {
    await pumpHandle(tester, const CounterSummary());
    final calme = tester.getSize(find.byType(ConditionalHandle)).height;

    await pumpHandle(
      tester,
      const CounterSummary(
        counters: [MapEntry(_poison, 3), MapEntry(_energy, 2)],
      ),
    );
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
            summary: const CounterSummary(counters: [MapEntry(_poison, 1)]),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ConditionalHandle));
    expect(tapped, isTrue);
  });

  // --- Débordement : la poignée peut désormais recevoir N compteurs
  // (compteurs personnalisés). Le défaut câblé ici est PROVISOIRE (voir le
  // rapport de tâche 3 du lot 5) : priorisation par gravité (valeur
  // décroissante) puis troncature "+N", et `maxVisibleChips` est
  // paramétrable pour que la session qui refond la disposition de la table
  // puisse le trancher par cran de densité sans toucher ce fichier.

  testWidgets(
      'au-delà de maxVisibleChips, les compteurs les plus graves sont '
      'affichés et le reste est compté dans un "+N"', (tester) async {
    const summary = CounterSummary(
      counters: [
        MapEntry(_poison, 2),
        MapEntry(_energy, 9),
        MapEntry(_custom, 5),
      ],
      worstCommanderDamage: 20,
    );
    // 4 entrées non nulles, maxVisibleChips: 3 -> les 2 plus graves (20, 9)
    // affichées, les 2 restantes (5, 2) comptées dans un "+2".
    await pumpHandle(tester, summary, maxVisibleChips: 3);

    expect(find.text('⚔ 20'), findsOneWidget);
    expect(find.text('⚡ 9'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('🔥 5'), findsNothing,
        reason: 'la 3e valeur la plus grave doit être comptée dans le +N, '
            'pas affichée à côté');
    expect(find.text('☠️ 2'), findsNothing,
        reason: 'idem pour la valeur la plus faible');
  });

  testWidgets(
      'maxVisibleChips est paramétrable : un cran de densité différent '
      'change combien de puces s\'affichent avant troncature', (tester) async {
    const summary = CounterSummary(
      counters: [MapEntry(_poison, 4), MapEntry(_energy, 3)],
      worstCommanderDamage: 5,
    );
    // 3 entrées non nulles, maxVisibleChips: 2 -> une seule puce (la plus
    // grave, 5) puis un "+2" -- un AUTRE cran (maxVisibleChips: 3 dans le
    // test précédent) aurait laissé passer une puce de plus, ce qui prouve
    // que c'est bien ce paramètre qui pilote la troncature, pas une
    // constante figée dans ce fichier.
    await pumpHandle(tester, summary, maxVisibleChips: 2);

    expect(find.text('⚔ 5'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('☠️ 4'), findsNothing);
    expect(find.text('⚡ 3'), findsNothing);
  });

  testWidgets(
      'un débordement ne défile jamais -- un contenu qui ne tient pas se '
      'compte, il ne se cache pas', (tester) async {
    const summary = CounterSummary(
      counters: [
        MapEntry(_poison, 1),
        MapEntry(_energy, 2),
        MapEntry(_custom, 3),
      ],
      worstCommanderDamage: 4,
    );
    await pumpHandle(tester, summary, maxVisibleChips: 2);

    expect(find.byType(Scrollable), findsNothing,
        reason: 'lot 6 a été reverté pour exactement ce mécanisme : une '
            'bande scrollable de 30px cachait des icônes sans aucune '
            'affordance -- la poignée ne doit jamais reproduire ce défaut');
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });
}
