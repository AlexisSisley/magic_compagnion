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

    // Relève l'instant (temps écoulé depuis le tap down) de chaque delta,
    // par petits pas, pour reconstituer la suite des intervalles entre
    // répétitions. Un test qui se contente de compter les deltas dans deux
    // fenêtres de 500 ms ne prouve pas l'accélération : une cadence
    // constante suffisamment rapide produit aussi plus d'événements dans la
    // seconde fenêtre (la première n'a que ~100 ms de répétition utile,
    // le reste étant mangé par le délai initial de 400 ms).
    const step = Duration(milliseconds: 10);
    const totalDuration = Duration(milliseconds: 1500);
    var elapsed = Duration.zero;
    var lastCount = deltas.length; // le tap down a déjà émis un premier delta
    final timestamps = <Duration>[elapsed];

    while (elapsed < totalDuration) {
      await tester.pump(step);
      elapsed += step;
      while (deltas.length > lastCount) {
        timestamps.add(elapsed);
        lastCount++;
      }
    }

    await gesture.up();
    await tester.pumpAndSettle();

    expect(timestamps.length, greaterThanOrEqualTo(4),
        reason: 'pas assez de répétitions capturées pour juger de l\'accélération');

    // intervals[0] est le délai initial (à part) ; le reste est la suite des
    // écarts entre répétitions successives.
    final intervals = <int>[
      for (var i = 1; i < timestamps.length; i++)
        (timestamps[i] - timestamps[i - 1]).inMilliseconds,
    ];
    final repeatIntervals = intervals.sublist(1);
    expect(repeatIntervals.length, greaterThanOrEqualTo(2),
        reason: 'pas assez d\'intervalles de répétition pour comparer');

    expect(
      repeatIntervals.last,
      lessThan(repeatIntervals.first),
      reason: 'la répétition doit accélérer : l\'écart entre les deux '
          'derniers deltas doit être strictement inférieur à celui entre '
          'les deux premiers deltas de répétition (une cadence constante, '
          'quelle qu\'elle soit, ne doit pas satisfaire ce test)',
    );
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

      // 8 px par point : 40 px vers le bas = −5.
      await tester.drag(find.byType(LifeDial), const Offset(0, 40));
      await tester.pumpAndSettle();

      expect(deltas, isNotEmpty);
      expect(deltas.reduce((a, b) => a + b), lessThan(0),
          reason: 'glisser vers le bas doit retirer des PV');
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
