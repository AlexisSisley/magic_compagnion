// test/widgets/life_counter/player_zone_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/widgets/life_counter/player_header.dart';
import 'package:magic_companion/widgets/life_counter/player_zone.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';
import 'package:magic_companion/widgets/life_counter/zone/damage_attribution_row.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';

/// `commanderDamageReceived` est **requis** dans le constructeur de `Player`
/// (`lib/models/player_model.dart:30`) — ne pas l'omettre.
Player buildPlayer({
  int life = 40,
  int poison = 0,
  int energy = 0,
  int quarterTurns = 0,
}) {
  return Player(
    id: 0,
    name: 'Alexis',
    life: life,
    colorValue: 0xFF880000,
    commanderDamageReceived: const {},
    poison: poison,
    energy: energy,
    quarterTurns: quarterTurns,
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

const _attributionOpponents = [
  (playerId: 1, name: 'Sam', colorValue: 0xFFFF0000),
  (playerId: 2, name: 'Mia', colorValue: 0xFF00FF00),
];

/// Monte la zone avec la rangée d'attribution (spec S2.6) câblée — voir
/// `pumpZone` ci-dessus pour la variante sans, utilisée par le reste des
/// tests de ce fichier.
Future<List<int>> pumpZoneWithAttribution(
  WidgetTester tester, {
  required Player player,
  List<DamageAttributionOpponent>? attributionOpponents,
}) async {
  final attributed = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            height: 340,
            child: PlayerZone(
              player: player,
              onLifeChanged: (_) {},
              onColorChanged: (_) {},
              attributionOpponents: attributionOpponents,
              onAttributeDamage: attributed.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return attributed;
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

  testWidgets(
      'resetRotationDrag empêche le résidu d\'un geste interrompu de se '
      'combiner avec un second geste sans rapport (ronde de correction 1)',
      (tester) async {
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

    // Premier geste : 30px (3 pas de 10px, comme un vrai doigt), sous le
    // seuil de 40px, relâché sans avoir tourné.
    final first = await tester.startGesture(tester.getCenter(icon));
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 3; i++) {
      await first.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await first.up();
    await tester.pump();

    expect(rotatedTo, isNull, reason: '30px reste sous le seuil de 40px');
    expect(
      container.read(playerZoneNotifierProvider(player.id)).rotationAccumulator,
      30.0,
      reason: 'le résidu du premier geste doit être visible avant le second',
    );

    // Second geste, sans aucun rapport avec le premier (le doigt se repose,
    // potentiellement pour tourner dans l'autre sens) : un seul pas de 15px.
    // Sans `resetRotationDrag()` à l'entrée de ce nouveau geste, le résidu du
    // premier (30px) s'additionnerait (45px, > seuil) et déclencherait une
    // rotation qui ne devrait pas avoir lieu ici.
    final second = await tester.startGesture(tester.getCenter(icon));
    await tester.pump(const Duration(milliseconds: 500));
    await second.moveBy(const Offset(15, 0));
    await tester.pump();

    expect(
      rotatedTo,
      isNull,
      reason: 'resetRotationDrag() doit empêcher le résidu du premier geste '
          'de se combiner avec ce second geste sans rapport',
    );
    expect(
      container.read(playerZoneNotifierProvider(player.id)).rotationAccumulator,
      15.0,
      reason: "l'accumulateur doit repartir de zéro pour ce nouveau geste, "
          'pas continuer depuis le résidu du précédent',
    );

    await second.up();
  });

  // --- Ronde de correction finale du lot 3 (Critical/Important #2) : la
  // rangée d'attribution à la volée (spec S2.6) vit maintenant DANS
  // PlayerZone, à l'intérieur du RotatedBox de `quarterTurns` -- et non plus
  // empilée par-dessus depuis life_counter_page.dart, qui ne pivotait
  // jamais avec la zone (90°/270°, cas normal à 4 joueurs).

  testWidgets(
      'la rangée d\'attribution vit DANS le RotatedBox qui pivote la zone, '
      'pas empilée par-dessus (ronde de correction finale, #2)',
      (tester) async {
    await pumpZoneWithAttribution(
      tester,
      player: buildPlayer(quarterTurns: 2),
      attributionOpponents: _attributionOpponents,
    );

    expect(find.byType(DamageAttributionRow), findsOneWidget);
    final rotatedAncestor = find.ancestor(
      of: find.byType(DamageAttributionRow),
      matching: find.byWidgetPredicate(
          (w) => w is RotatedBox && w.quarterTurns == 2),
    );
    expect(rotatedAncestor, findsOneWidget,
        reason: 'la rangée doit être un descendant du RotatedBox qui pivote '
            'toute la zone, pour pivoter avec elle à 90°/270° -- pas rester '
            'droite pendant que le joueur lit sa zone de côté');
  });

  testWidgets(
      'un tap sur un avatar de la rangée émet le sourcePlayerId de CET '
      'avatar', (tester) async {
    final attributed = await pumpZoneWithAttribution(
      tester,
      player: buildPlayer(),
      attributionOpponents: _attributionOpponents,
    );

    await tester.tap(find.byKey(const ValueKey('damage-attribution-2')));
    await tester.pump();

    expect(attributed, [2]);
  });

  testWidgets(
      'sans adversaires proposés (null ou vide), la rangée ne s\'affiche '
      'jamais', (tester) async {
    await pumpZoneWithAttribution(tester, player: buildPlayer());
    expect(find.byType(DamageAttributionRow), findsNothing);

    await pumpZoneWithAttribution(
      tester,
      player: buildPlayer(),
      attributionOpponents: const [],
    );
    expect(find.byType(DamageAttributionRow), findsNothing);
  });
}
