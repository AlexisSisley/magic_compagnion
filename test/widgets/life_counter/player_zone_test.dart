// test/widgets/life_counter/player_zone_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';
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
    // Lot 5, tâche 4 (câblage manquant) : `PlayerZone` construit désormais
    // `CounterSummary` depuis `Player.counters` (générique), plus depuis
    // `Player.poison`/`Player.energy` directement -- ce fixture doit donc
    // porter les mêmes valeurs dans les deux, sans quoi la poignée
    // resterait toujours muette ici, quel que soit `poison`/`energy` reçus.
    counters: {'poison': poison, 'energy': energy},
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

  // Round de correction 3 (tâche 7) : un glissement descendant réaliste vers
  // un palier traverse la zone active de la molette (LifeDial l'annule au
  // relâchement pour que le net reste exactement le palier). Cette
  // annulation doit rester SILENCIEUSE au niveau visuel/haptique : sans le
  // paramètre `silent` propagé jusqu'ici, `_triggerChange` afficherait une
  // bulle et jouerait pulsation/haptique pour CE delta interne aussi, en
  // plus de celui du palier -- ce que l'utilisateur (et les autres joueurs,
  // sur un appareil posé à plat) verraient sur l'écran.
  testWidgets(
      'un glissement descendant vers un palier n\'affiche qu\'UNE bulle, '
      'portant la valeur du palier, et ne joue qu\'UN retour haptique',
      (tester) async {
    final hapticCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

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

    // Appui long au centre du cadran (position naturelle), puis glissement
    // en plusieurs incréments, descendant réellement, vers le bouton "-5" :
    // un vrai doigt émet des dizaines d'événements, pas un seul saut.
    final center = tester.getCenter(find.byType(LifeDial));
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    // L'entrée en mode ajustement joue son propre `HapticFeedback.
    // mediumImpact()` (légitime, sans rapport avec ce round) : on ne compte
    // les retours haptiques qu'à partir d'ici, pour isoler ceux du
    // glissement puis du relâchement.
    hapticCalls.clear();

    final target = tester.getCenter(find.descendant(
      of: find.byType(LifeDial),
      matching: find.byKey(const ValueKey('life_step_-5')),
    ));

    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      await gesture.moveTo(Offset.lerp(center, target, t)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    final floatingNumbers =
        container.read(playerZoneNotifierProvider(player.id)).floatingNumbers;
    expect(floatingNumbers, hasLength(1),
        reason: 'un seul geste, un seul effet visible -- pas de bulle pour '
            'la molette annulée en route');
    expect(floatingNumbers.single.text, '-5');

    expect(hapticCalls, hasLength(1),
        reason: 'un seul retour haptique au lever, pas un par delta '
            'interne (palier + annulation)');

    // Purge les Timer internes de la bulle avant la fin du test.
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
    // Lot 5, tâche 3b : `CounterSummary` n'a plus de champ nommé `poison` --
    // le résumé porte désormais une collection (CounterType, valeur).
    final poisonEntry = handle.summary.counters
        .firstWhere((entry) => entry.key.id == 'poison');
    expect(poisonEntry.value, 3);
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

  // ===========================================================================
  // Revue finale, IMPORTANT #2 (ruling 22) — le jumeau du garde-fou de
  // `kActionWidth` (ruling 16), qui MESURE un bouton rendu au lieu de
  // supposer.
  //
  // `PlayerHeader` contient un `IconButton` Material nu, qui mesure 48 px au
  // minimum (`kMinInteractiveDimension`). `kZoneHeaderHeight` valait 40 :
  // débordement de 8 px, rogné en silence par le `clipBehavior` de la zone.
  // La cible tactile effective tombait à 48×40, sous le minimum, et les 8 px
  // manquants étaient absorbés par le `LifeDial` en dessous — le tap donnait
  // +1 PV au lieu d'ouvrir le sélecteur de couleur.
  //
  // Repérage par GÉOMÉTRIE, parce que la propriété testée EST une position :
  // le bouton doit tenir en entier dans la bande réservée à l'en-tête.
  // ===========================================================================
  group('kZoneHeaderHeight reflète la vraie hauteur rendue (ruling 22)', () {
    testWidgets(
        'le bouton palette de PlayerHeader tient entièrement dans la bande '
        'réservée par kZoneHeaderHeight', (tester) async {
      await pumpZone(tester, buildPlayer());

      final header = find.byKey(const ValueKey('player-zone-header'));
      expect(header, findsOneWidget,
          reason: 'précondition : une zone de 340×340 est bien au-dessus du '
              'cran minimal, donc son en-tête est monté');

      final headerRect = tester.getRect(header);
      expect(headerRect.height, kZoneHeaderHeight,
          reason: 'la bande réservée doit mesurer exactement ce que la '
              'constante annonce');

      final paletteButton = find.descendant(
        of: header,
        matching: find.widgetWithIcon(IconButton, Icons.palette),
      );
      expect(paletteButton, findsOneWidget);
      final buttonRect = tester.getRect(paletteButton);

      expect(buttonRect.height, lessThanOrEqualTo(headerRect.height),
          reason: 'hauteur RÉELLEMENT rendue du bouton palette '
              '(${buttonRect.height}px) vs bande réservée '
              '(${headerRect.height}px) — si le bouton est plus haut, le '
              'surplus est rogné par le clipBehavior de la zone, sa cible '
              'tactile passe sous le minimum de Material, et les pixels '
              'manquants sont absorbés par le LifeDial en dessous : le tap '
              'donne +1 PV au lieu d ouvrir le sélecteur de couleur');
      expect(buttonRect.bottom, lessThanOrEqualTo(headerRect.bottom),
          reason: 'le bouton ne doit pas déborder sous la bande, où le '
              'cadran de vie prend le hit-test');
    });
  });
}
