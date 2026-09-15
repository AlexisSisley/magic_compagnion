// test/widgets/life_counter/zone/life_dial_test.dart
import 'package:flutter/gestures.dart';
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

  // Round 3 de revue : la tâche 2 proposait « maintenir une moitié =
  // répétition accélérée » (spec §2.1). La tâche 3 ajoute « appui long =
  // mode ajustement » (§2.5) sur le même geste, sur la même zone : les
  // conserver toutes les deux exigerait de réserver l'appui long à une
  // sous-région de la zone, la séparation spatiale que l'ergonomie du widget
  // écarte explicitement au profit d'un mode unique et global. La répétition
  // au maintien est donc abandonnée (la molette couvre la même plage utile,
  // 8px par point) ; les deux tests suivants vérifient le comportement réel
  // d'un maintien immobile : il bascule en mode ajustement, il ne répète
  // jamais.
  testWidgets(
      'un maintien immobile bascule en mode ajustement au lieu de répéter '
      '(round 2 : l\'appui long prime, zéro delta parasite)', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    final gesture = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(deltas, isEmpty,
        reason: 'un maintien immobile assez long pour déclencher le mode '
            'ajustement ne doit jamais émettre de ±1 de répétition');
    expect(find.text('+10'), findsOneWidget,
        reason: 'le mode ajustement doit bien avoir été déclenché');
  });

  testWidgets(
      'un maintien bref, relâché avant le seuil d\'appui long, émet un seul '
      'delta et rien de plus ensuite', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    final gesture = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(deltas, [-1]);

    await tester.pump(const Duration(seconds: 1));
    expect(deltas, [-1], reason: 'plus aucun delta après le relâchement');
  });

  testWidgets(
      'un second doigt sur la zone ne fait pas ressusciter le delta '
      'parasite de Critical #1 (multi-touch)', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    // Premier doigt : posé sur la moitié gauche, quasi immobile (jitter de
    // 4px, sous kTouchSlop). Second doigt : posé ailleurs sur la zone, comme
    // la paume ou la main d'un adversaire — l'appareil est à plat, à quatre
    // joueurs, un second contact est ordinaire.
    final firstFinger = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    final secondFinger = await tester.startGesture(
      Offset(dial.left + dial.width * 0.75, dial.center.dy),
    );

    // Sans suivi par pointeur, ce jitter du premier doigt serait mesuré
    // depuis la position du second (à ~150px), et annulerait à tort la
    // veille d'appui long du premier sans jamais rejeter son tap : au
    // relâchement, `_confirmTap` émettrait alors le -1 en attente.
    await firstFinger.moveBy(const Offset(0, 4));
    await tester.pump(const Duration(milliseconds: 1500));

    await firstFinger.up();
    await secondFinger.up();
    await tester.pumpAndSettle();

    expect(deltas, isEmpty,
        reason: 'un second doigt ne doit jamais faire échouer la détection '
            'd\'appui long du premier');
    expect(find.text('+10'), findsOneWidget,
        reason: 'le mode ajustement doit tout de même se déclencher pour le '
            'premier doigt');
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

  group('mode ajustement', () {
    testWidgets('les paliers sont cachés au repos', (tester) async {
      await pumpDial(tester);
      expect(find.text('-10'), findsNothing);
      expect(find.text('+10'), findsNothing);
    });

    testWidgets('l\'appui long fait apparaître les paliers', (tester) async {
      await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();
      expect(find.text('-10'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
    });

    testWidgets('un appui long n\'émet aucun delta, et le mode est bien entré',
        (tester) async {
      final deltas = await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();
      expect(deltas, isEmpty,
          reason:
              'un appui long ne doit produire aucun ±1 parasite (Critical #1)');
      expect(find.text('+10'), findsOneWidget);
    });

    testWidgets('maintenir le doigt en mode ajustement ne produit aucun ±1',
        (tester) async {
      final deltas = await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();
      expect(deltas, isEmpty);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LifeDial)),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(deltas, isEmpty,
          reason: 'un doigt immobile en mode ajustement ne doit jamais '
              'émettre de ±1');
    });

    testWidgets(
        'un appui long avec un petit mouvement (4px) entre quand même en '
        'mode ajustement', (tester) async {
      await pumpDial(tester);
      final center = tester.getCenter(find.byType(LifeDial));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('+10'), findsOneWidget,
          reason: 'un micro-mouvement de 4px (sous kTouchSlop = 18px) ne '
              'doit pas annuler l\'appui long');
    });

    testWidgets('un palier émet son delta', (tester) async {
      final deltas = await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();
      await tester.tap(find.text('-10'));
      await tester.pumpAndSettle();
      expect(deltas, contains(-10));
    });

    testWidgets('le glissement vertical en mode ajustement émet des deltas',
        (tester) async {
      final deltas = await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();

      // 8 px par point : 40 px vers le bas = −5. `touchSlop` à zéro pour que
      // `tester.drag` envoie tout le déplacement en un seul événement — sans
      // quoi il le scinde par défaut en deux (le seuil de `kDragSlopDefault`
      // puis le reste), et la molette émettrait deux deltas partiels ([-2,
      // -3]) au lieu d'un seul, ce qui est un artefact du test, pas du
      // comportement réel (un glissement continu sur un appareil produit un
      // flot d'événements bien plus fin que 2 pas).
      await tester.drag(
        find.byType(LifeDial),
        const Offset(0, 40),
        touchSlopX: 0,
        touchSlopY: 0,
      );
      await tester.pumpAndSettle();

      // Durci (round 2, le test était vert par accident) : avec l'appui long
      // qui n'émet plus de delta parasite, `deltas` ne doit contenir que le
      // -5 de la molette, pas [+1, +1, -5] dont la somme passait le test par
      // hasard.
      expect(deltas, [-5]);
    });

    testWidgets(
        'un glissement lent de plus de 500 ms ne perd pas son reste '
        'accumulé (Important #1)', (tester) async {
      final deltas = await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();

      // 7px, puis on attend > 500 ms (au-delà du seuil de l'appui long) avant
      // 7px de plus : 7 < 8px ne bouge rien seul, mais 7+7 = 14px doit passer
      // le seuil de 8px et émettre -1. Si l'appui long se ré-arme et remet
      // `wheelAccumulator` à zéro pendant l'attente (le bug d'Important #1),
      // le premier 7px est perdu et le second 7px, seul, ne suffit plus à
      // franchir le seuil : le test distingue les deux cas sans ambiguïté.
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await gesture.moveBy(const Offset(0, 7));
      await tester.pump(const Duration(milliseconds: 550));
      await gesture.moveBy(const Offset(0, 7));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(deltas, [-1],
          reason: '7px + 7px doivent cumuler à 14px et produire -1, sans '
              'perte due à un ré-armement de l\'appui long en cours de '
              'geste');
    });

    testWidgets('le glissement ne fait rien hors mode ajustement',
        (tester) async {
      final deltas = await pumpDial(tester);
      await tester.drag(find.byType(LifeDial), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(deltas, isEmpty,
          reason: 'hors mode ajustement, un glissement vertical appartient au '
              'tiroir et à la rotation, pas à la molette');
    });

    testWidgets('un tap hors des paliers sort du mode', (tester) async {
      await pumpDial(tester);
      await tester.longPress(find.byType(LifeDial));
      await tester.pumpAndSettle();
      expect(find.text('+10'), findsOneWidget);

      final dial = tester.getRect(find.byType(LifeDial));
      await tester.tapAt(Offset(dial.center.dx, dial.top + 12));
      await tester.pumpAndSettle();
      expect(find.text('+10'), findsNothing);
    });
  });
}
