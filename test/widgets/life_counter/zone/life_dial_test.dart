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

    // Réécrit en geste continu unique (comme ses voisins) : l'ancienne
    // version entrait en mode via `tester.longPress()` (relâché à son terme)
    // PUIS tenait un second doigt séparé -- depuis la tâche 7, le premier
    // relâchement referme déjà le mode, si bien que ce test n'exerçait plus
    // sa propriété que par coïncidence (le second maintien ne faisait que
    // ré-ouvrir puis refermer le mode sans que rien ne dépende de l'ancien
    // mécanisme).
    testWidgets('maintenir le doigt en mode ajustement ne produit aucun ±1',
        (tester) async {
      final deltas = await pumpDial(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LifeDial)),
      );
      await tester.pump(const Duration(milliseconds: 800));

      expect(deltas, isEmpty,
          reason: 'un doigt immobile en mode ajustement ne doit jamais '
              'émettre de ±1');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(deltas, isEmpty);
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

      // Égalité stricte (round de correction 1) : `contains(-10)` laissait
      // passer un delta de molette parasite en plus du palier attendu.
      expect(deltas, [-10]);
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
    //
    // Round de correction 1 (Important #4) : avant la correction sur
    // `onPointerUp`, ce test était vert par accident -- le mouvement de ~138px
    // dépassait `kTouchSlop` et fermait déjà le mode via `onTapCancel`, avant
    // même que `gesture.up()` ne s'exécute ; l'assertion aurait été vraie que
    // `up()` fasse quelque chose ou non. Depuis la correction (résolution
    // uniquement sur l'événement brut de relâchement), le mode survit au
    // déplacement et ne se ferme qu'au `up()` : ce test exerce désormais
    // réellement ce qu'il annonce, distinct de « relâcher hors des paliers
    // ferme le mode sans rien appliquer » (aucun déplacement).
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

    // Round de correction 1 : le vrai motif qui distingue le code correct du
    // code cassé est le glissement en PLUSIEURS événements, pas un unique
    // `moveTo` qui saute directement sur la cible (un seul `PointerMoveEvent`
    // masque le bug : `_stepUnder` voit tout de suite la position finale).
    // Un vrai doigt émet des dizaines d'événements de suivi.
    //
    // Round de correction 2 (Critical, découvert par la revue) : la première
    // version de ce test partait d'un point déjà au niveau vertical de la
    // rangée pour glisser À PLAT (dy=0) jusqu'à "-5" -- un trajet qu'un doigt
    // réel ne fait jamais, puisque la rangée est ANCRÉE EN BAS du cadran :
    // pour l'atteindre depuis le centre (là où un appui long se pose
    // naturellement), il faut DESCENDRE d'environ 80px, exactement la
    // direction de la molette (8px/point). Ce test descend donc réellement
    // du centre du cadran jusqu'au bouton, traversant la zone "molette" en
    // chemin -- et vérifie que le geste reste néanmoins atomique : le
    // palier est le SEUL effet net, la molette croisée en route est annulée
    // (spec, round de correction 2 : « le geste est atomique, doigt posé au
    // doigt levé, pour le résultat aussi »).
    testWidgets(
        'un glissement descendant réaliste, en plusieurs événements, vers un '
        'palier applique CE palier, sans perte au passage', (tester) async {
      final deltas = await pumpDial(tester);
      final start = tester.getCenter(find.byType(LifeDial));
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(find.text('-5'), findsOneWidget);

      final target =
          tester.getCenter(find.byKey(const ValueKey('life_step_-5')));

      // Au moins 8 incréments, en descendant réellement du centre du cadran
      // vers le bouton (interpolation linéaire, dy != 0 à chaque pas) :
      // chaque pas croise la zone active de la molette avant d'entrer dans
      // celle du bouton.
      const steps = 10;
      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        await gesture.moveTo(Offset.lerp(start, target, t)!);
        // Un `pump()` par pas : un vrai doigt fait avancer des frames au fur
        // et à mesure, ce qui laisse l'arbre se reconstruire si le mode a
        // basculé en cours de route (c'est précisément ce qu'une fermeture
        // prématurée, ex. sur `onTapCancel`, romprait : la rangée se
        // démonterait, ses `GlobalKey` ne résoudraient plus rien).
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Somme stricte : sans l'annulation de la molette croisée en route
      // (round de correction 2), ce même trajet cumulerait environ -15 (le
      // palier -5, PLUS une dizaine de points de molette pris pendant la
      // descente vers la rangée) au lieu de -5 net.
      expect(deltas.fold<int>(0, (sum, d) => sum + d), -5,
          reason: 'le geste est atomique : un glissement vers un palier ne '
              'doit faire perdre aucun point de vie supplémentaire au '
              'passage, même s\'il traverse la zone de la molette en '
              'chemin');
    });

    // Round de correction 1 : symétrique du test précédent, côté molette.
    // Reste franchement hors de la rangée de paliers (dy total < distance au
    // sommet de la rangée) pour isoler la propriété sous test (l'accumulation
    // continue) de l'interaction volontaire molette/palier.
    testWidgets(
        'un glissement molette en plusieurs événements accumule sur tout le '
        'trajet, pas seulement le premier pas', (tester) async {
      final deltas = await pumpDial(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(LifeDial)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

      // 7 incréments de 10px = 70px, largement au-delà de kTouchSlop (18px)
      // dès le second pas, et encore loin du sommet mesuré de la rangée
      // (environ 80px plus bas que le centre du cadran) : la molette doit
      // pouvoir accumuler sur la totalité du trajet.
      for (var i = 0; i < 7; i++) {
        await gesture.moveBy(const Offset(0, 10));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // 70px / 8px par point = 8 (sous le seuil d'accélération de 120px).
      // Avec l'ancien câblage, le mode se serait refermé au second incrément
      // (18px dépassés), et le reste du trajet (5 incréments, 50px) n'aurait
      // plus jamais atteint la molette.
      expect(deltas.fold<int>(0, (sum, d) => sum + d), -8,
          reason: 'la molette doit accumuler sur tout le trajet (70px), pas '
              'seulement jusqu\'au dépassement de kTouchSlop');
    });
  });
}
