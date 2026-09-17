// test/widgets/life_counter/zone/life_dial_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/life_dial.dart';

Future<List<int>> pumpDial(
  WidgetTester tester, {
  int life = 40,
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
      '(l\'appui long prime, zéro delta parasite)', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    final gesture = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 1500));

    // Vérifié PENDANT la tenue, avant le relâchement : depuis la tâche 7, le
    // mode ne survit plus au relâchement (relâcher hors des paliers le
    // ferme), donc l'asserter après `gesture.up()` ne prouverait plus rien.
    expect(find.text('+10'), findsOneWidget,
        reason: 'le mode ajustement doit bien avoir été déclenché');

    await gesture.up();
    await tester.pumpAndSettle();

    expect(deltas, isEmpty,
        reason: 'un maintien immobile assez long pour déclencher le mode '
            'ajustement ne doit jamais émettre de ±1 de répétition');
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

    // Vérifié PENDANT la tenue, avant les relâchements : depuis la tâche 7,
    // le mode ne survit plus au relâchement, donc l'asserter après coup ne
    // prouverait plus rien.
    expect(find.text('+10'), findsOneWidget,
        reason: 'le mode ajustement doit tout de même se déclencher pour le '
            'premier doigt');

    await firstFinger.up();
    await secondFinger.up();
    await tester.pumpAndSettle();

    expect(deltas, isEmpty,
        reason: 'un second doigt ne doit jamais faire échouer la détection '
            'd\'appui long du premier');
  });

  testWidgets(
      'le doigt de gauche relâché après celui de droite émet bien son '
      'propre -1, pas perdu (chevauchement multi-touch)', (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    // Les deux doigts se posent pendant que l'un et l'autre sont encore en
    // cours : sans indexation par moitié, le second (droite, +1) écraserait
    // l'état partagé du premier (gauche, -1), qui se perdrait à son
    // relâchement, plus tardif.
    final left = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    final right = await tester.startGesture(
      Offset(dial.left + dial.width * 0.75, dial.center.dy),
    );

    await right.up();
    await tester.pump();
    await left.up();
    await tester.pump();

    expect(deltas, [1, -1]);
  });

  testWidgets(
      'le doigt de gauche relâché avant celui de droite émet -1, pas le +1 '
      'laissé par le doigt de droite (chevauchement multi-touch)',
      (tester) async {
    final deltas = await pumpDial(tester);
    final dial = tester.getRect(find.byType(LifeDial));

    // Le cas le plus grave : sans indexation par moitié, le relâchement du
    // premier doigt (gauche) lirait la valeur laissée par le second (droite,
    // +1) au lieu de son propre -1 — un tap sur « −1 » appliquerait « +1 ».
    final left = await tester.startGesture(
      Offset(dial.left + dial.width * 0.25, dial.center.dy),
    );
    final right = await tester.startGesture(
      Offset(dial.left + dial.width * 0.75, dial.center.dy),
    );

    await left.up();
    await tester.pump();
    await right.up();
    await tester.pump();

    expect(deltas, [-1, 1]);
  });

  group('mode ajustement', () {
    testWidgets('les paliers sont cachés au repos', (tester) async {
      await pumpDial(tester);
      expect(find.text('-10'), findsNothing);
      expect(find.text('+10'), findsNothing);
    });

    // `tester.longPress()` ne convient plus ici : depuis la tâche 7, son
    // relâchement intégré (au centre du cadran, hors des paliers) ferme
    // aussitôt le mode. On garde donc le doigt posé via `startGesture`, et on
    // vérifie PENDANT la tenue plutôt qu'après un relâchement qui aurait déjà
    // tout refermé.
    testWidgets('l\'appui long fait apparaître les paliers', (tester) async {
      await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(find.text('-10'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('un appui long n\'émet aucun delta, et le mode est bien entré',
        (tester) async {
      final deltas = await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(deltas, isEmpty,
          reason:
              'un appui long ne doit produire aucun ±1 parasite (Critical #1)');
      expect(find.text('+10'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
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

      // Vérifié avant le relâchement (voir la note au-dessus du groupe) :
      // depuis la tâche 7, le relâchement referme aussitôt le mode.
      expect(find.text('+10'), findsOneWidget,
          reason: 'un micro-mouvement de 4px (sous kTouchSlop = 18px) ne '
              'doit pas annuler l\'appui long');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    // Réécrit pour la tâche 7 (encodait l'ancien modèle) : un palier ne se
    // « tape » plus par un geste séparé — aucun `GestureDetector` ne reste
    // posé sur les boutons (voir `_stepRow`). La sélection se fait en
    // glissant le doigt de l'appui long jusqu'au palier puis en relâchant,
    // un seul geste continu ; c'est ce que couvre désormais ce test.
    testWidgets('un palier émet son delta', (tester) async {
      final deltas = await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(find.text('-10'), findsOneWidget);

      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('life_step_-10'))),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(deltas, contains(-10));
    });

    // Réécrit pour la tâche 7 (fusion en UN SEUL geste continu) : l'ancienne
    // version entrait en mode via `tester.longPress()` (qui relâche le doigt
    // à son terme) PUIS glissait avec un doigt SÉPARÉ. Depuis la tâche 7, le
    // relâchement de `longPress()` referme aussitôt le mode (spec §5.1), donc
    // ce second glissement s'exécutait hors mode et n'émettait plus rien.
    testWidgets('le glissement vertical en mode ajustement émet des deltas',
        (tester) async {
      final deltas = await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

      // 8 px par point : 40 px vers le bas = −5. Un seul `moveBy` envoie tout
      // le déplacement en un seul événement (pas de scission par touchSlop,
      // propre à `tester.drag`), donc un seul delta de -5, pas deux partiels.
      await gesture.moveBy(const Offset(0, 40));
      await gesture.up();
      await tester.pumpAndSettle();

      // Durci (round 2, le test était vert par accident) : avec l'appui long
      // qui n'émet plus de delta parasite, `deltas` ne doit contenir que le
      // -5 de la molette, pas [+1, +1, -5] dont la somme passait le test par
      // hasard.
      expect(deltas, [-5]);
    });

    // Réécrit pour la tâche 7 (fusion en UN SEUL geste continu) : même raison
    // que le test précédent — la mise en place via `tester.longPress()` puis
    // un second `startGesture` séparé ne survit plus à la fermeture du mode
    // au premier relâchement.
    testWidgets(
        'un glissement lent de plus de 500 ms ne perd pas son reste '
        'accumulé (Important #1)', (tester) async {
      final deltas = await pumpDial(tester);

      // 7px, puis on attend > 500 ms (au-delà du seuil de l'appui long) avant
      // 7px de plus : 7 < 8px ne bouge rien seul, mais 7+7 = 14px doit passer
      // le seuil de 8px et émettre -1. Si l'appui long se ré-arme et remet
      // `wheelAccumulator` à zéro pendant l'attente (le bug d'Important #1),
      // le premier 7px est perdu et le second 7px, seul, ne suffit plus à
      // franchir le seuil : le test distingue les deux cas sans ambiguïté.
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
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

    // Réécrit pour la tâche 7 (encodait l'ancien modèle) : la version
    // précédente fermait le mode par un TAP SÉPARÉ, posé après le relâchement
    // de l'appui long — exactement le geste en deux temps que la tâche 7
    // supprime (spec §5.1, plus de mode persistant). Il n'existe plus de
    // geste de fermeture distinct : ici, on vérifie qu'un glissement vers un
    // point hors des paliers, PUIS un relâchement, ferme le mode dans le même
    // geste continu que celui qui l'a ouvert.
    testWidgets(
        'glisser puis relâcher hors des paliers sort du mode, sans second '
        'geste', (tester) async {
      await pumpDial(tester);
      final dial = tester.getRect(find.byType(LifeDial));
      final gesture = await tester.startGesture(dial.center);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(find.text('+10'), findsOneWidget);

      await gesture.moveTo(Offset(dial.center.dx, dial.top + 12));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('+10'), findsNothing);
    });
  });

  group('paliers resserrés, fermés au relâchement (tâche 7)', () {
    testWidgets('l\'appui long ouvre les paliers', (tester) async {
      await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

      expect(find.text('-10'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'relâcher hors des paliers ferme le mode sans rien appliquer',
        (tester) async {
      final deltas = await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(find.text('+10'), findsOneWidget);

      // Relâché exactement là où le doigt s'est posé (centre du cadran),
      // jamais au-dessus d'un palier (rangée resserrée en bas de zone).
      await gesture.up();
      await tester.pumpAndSettle();

      expect(deltas, isEmpty,
          reason: 'un relâchement hors des paliers ne doit rien appliquer');
      expect(find.text('+10'), findsNothing,
          reason: 'le mode ne doit pas survivre au relâchement');
    });

    testWidgets('glisser sur un palier puis relâcher applique CE palier',
        (tester) async {
      final deltas = await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(find.text('-5'), findsOneWidget);

      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('life_step_-5'))),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(deltas, [-5]);
      expect(find.text('-5'), findsNothing);
    });

    testWidgets('le mode ne survit pas au relâchement', (tester) async {
      final deltas = await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('life_step_-5'))),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(deltas, [-5]);
      expect(find.byKey(const ValueKey('life_step_-5')), findsNothing,
          reason: 'le mode ajustement ne doit pas survivre au relâchement');
    });

    testWidgets('la rangée ne prend pas toute la largeur', (tester) async {
      await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

      final rowWidth =
          tester.getSize(find.byKey(const ValueKey('life_step_row'))).width;
      final dialWidth = tester.getSize(find.byType(LifeDial)).width;

      // Propriété de disposition (spec §5.4) : testée par géométrie, pas par
      // clé, car c'est la position/largeur elle-même qui est sous test.
      expect(rowWidth, lessThan(dialWidth * 0.7),
          reason: 'la rangée pleine largeur retombait exactement là où le '
              'pouce se repose au relâchement — le bug rapporté');

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
