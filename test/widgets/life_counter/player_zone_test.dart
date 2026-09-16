// test/widgets/life_counter/player_zone_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/widgets/life_counter/player_zone.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';

/// `commanderDamageReceived` est **requis** dans le constructeur de `Player`
/// (`lib/models/player_model.dart:30`) — ne pas l'omettre.
Player buildPlayer({int life = 40, int poison = 0, int energy = 0}) {
  return Player(
    id: 0,
    name: 'Alexis',
    life: life,
    colorValue: 0xFF880000,
    commanderDamageReceived: const {},
    poison: poison,
    energy: energy,
  );
}

Future<List<int>> pumpZone(WidgetTester tester, Player player) async {
  final deltas = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            height: 340,
            child: PlayerZone(
              player: player,
              onLifeChanged: deltas.add,
              onShowCommanderDamage: () {},
              onColorChanged: (_) {},
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
  testWidgets('la zone affiche les PV et rien d\'autre au calme',
      (tester) async {
    await pumpZone(tester, buildPlayer(life: 34));
    expect(find.text('34'), findsOneWidget);
    expect(find.byType(LifeDial), findsOneWidget);
    expect(find.byType(ConditionalHandle), findsOneWidget);
  });

  testWidgets('un tap à gauche remonte un delta négatif', (tester) async {
    final deltas = await pumpZone(tester, buildPlayer());
    final dial = tester.getRect(find.byType(LifeDial));
    await tester.tapAt(Offset(dial.left + dial.width * 0.25, dial.center.dy));
    expect(deltas, [-1]);
    // Le tap déclenche aussi un nombre flottant ("-1") qui s'efface via deux
    // `Timer` internes (50 ms puis 600 ms) — `pumpAndSettle()` seul ne les
    // atteint pas (aucune frame n'est reprogrammée entre les deux), ce qui
    // laisserait un Timer pendant à la fin du test. On les purge explicitement.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

  testWidgets('la poignée reste muette quand aucun compteur ne bouge',
      (tester) async {
    await pumpZone(tester, buildPlayer(poison: 0, energy: 0));
    final handle = tester.widget<ConditionalHandle>(
      find.byType(ConditionalHandle),
    );
    expect(handle.summary.isCalm, isTrue);
  });

  testWidgets('la poignée parle dès qu\'un compteur bouge', (tester) async {
    await pumpZone(tester, buildPlayer(poison: 3));
    final handle = tester.widget<ConditionalHandle>(
      find.byType(ConditionalHandle),
    );
    expect(handle.summary.isCalm, isFalse);
    expect(handle.summary.poison, 3);
  });

  testWidgets('la hauteur du chiffre ne change pas quand un compteur apparaît',
      (tester) async {
    await pumpZone(tester, buildPlayer(poison: 0));
    final calme = tester.getRect(find.byType(LifeDial));

    await pumpZone(tester, buildPlayer(poison: 3));
    final alerte = tester.getRect(find.byType(LifeDial));

    expect(alerte.height, calme.height,
        reason: 'la hauteur de la poignée est réservée : le chiffre ne bouge pas');
  });
}
