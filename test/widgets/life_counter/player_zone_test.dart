// test/widgets/life_counter/player_zone_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/widgets/life_counter/player_header.dart';
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

  testWidgets('les nombres flottants viennent du notifier, pas d\'un état local',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final player = buildPlayer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 340,
              child: PlayerZone(
                player: player,
                onLifeChanged: (_) {},
                onColorChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(playerZoneNotifierProvider(player.id)).floatingNumbers,
      isEmpty,
      reason: 'rien ne doit apparaître avant tout tap',
    );

    // Un vrai tap, pas un appel de callback : c'est justement le geste que
    // l'ancienne implémentation en setState ne pouvait pas voir passer par
    // le notifier.
    final dial = tester.getRect(find.byType(LifeDial));
    await tester.tapAt(Offset(dial.left + dial.width * 0.75, dial.center.dy));
    await tester.pump();

    expect(
      container.read(playerZoneNotifierProvider(player.id)).floatingNumbers,
      isNotEmpty,
      reason: 'le tap doit alimenter PlayerZoneState.floatingNumbers, plus un champ local',
    );

    // Purge les deux Timer internes (50 ms puis 600 ms) avant la fin du test.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'la rotation passe par le notifier : sous le seuil elle attend, '
      'au-delà elle tourne et remet l\'accumulateur à zéro', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final player = buildPlayer();
    int? rotatedTo;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 340,
              child: PlayerZone(
                player: player,
                onLifeChanged: (_) {},
                onColorChanged: (_) {},
                onRotationChanged: (v) => rotatedTo = v,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = find.descendant(
      of: find.byType(PlayerHeader),
      matching: find.byIcon(Icons.rotate_right),
    );
    final gesture = await tester.startGesture(tester.getCenter(icon));
    // Laisse le temps au long press d'être reconnu (délai par défaut de
    // LongPressGestureRecognizer, le même que celui utilisé par
    // ConditionalHandle/tester.longPress).
    await tester.pump(const Duration(milliseconds: 500));

    // Un vrai doigt livre ~10 px par PointerMoveEvent (leçon des lots 1/2) :
    // un seul événement de 10 px reste sous le seuil de rotation (40 px),
    // mais l'accumulateur du notifier doit déjà en porter la trace.
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();

    expect(rotatedTo, isNull,
        reason: 'un seul pas de 10px reste sous le seuil de 40px');
    expect(
      container.read(playerZoneNotifierProvider(player.id)).rotationAccumulator,
      isNot(0.0),
      reason: 'le glissement partiel doit déjà être visible dans le notifier',
    );

    // Quatre pas de plus (40px de plus, 50px cumulés) franchissent le seuil.
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await gesture.up();

    expect(rotatedTo, 1,
        reason: 'le glissement cumulé dépasse le seuil et tourne d\'un quart');
    expect(
      container.read(playerZoneNotifierProvider(player.id)).rotationAccumulator,
      0.0,
      reason: 'la rotation consomme l\'accumulateur du notifier',
    );
  });
}
