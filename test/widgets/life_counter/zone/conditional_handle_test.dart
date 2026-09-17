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

/// Deux compteurs personnalisés de plus, pour le cas combiné (ronde de
/// correction 2, Mineur 3) qui a besoin de plus d'entrées distinctes que
/// `_poison`/`_energy`/`_custom` seuls n'en fournissent.
const _alpha = CounterType(id: 'alpha', name: 'Alpha', emoji: '◆', color: 0xFF00FF00);
const _beta = CounterType(id: 'beta', name: 'Beta', emoji: '◇', color: 0xFF0000FF);

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

  // --- Ronde de correction 1 : `maxVisibleChips` limite le NOMBRE de puces,
  // mais rien ne garantissait qu'elles tiennent en LARGEUR une fois ce
  // nombre autorisé. Une session qui monte ce paramètre pour un cran de
  // densité peut se retrouver avec plus de puces que la largeur réelle ne
  // permet -- exactement l'usage pour lequel il a été rendu paramétrable.

  testWidgets(
      'même quand maxVisibleChips laisse passer plus de puces que la '
      'largeur réelle ne permet, aucun débordement ne se produit -- la '
      'bande réduit encore le nombre de puces rendues, et le "+N" compte '
      'TOUTES celles qui manquent (pas seulement celles que maxVisibleChips '
      'aurait écartées)', (tester) async {
    // maxVisibleChips volontairement généreux (10, largement au-dessus des
    // 4 entrées non nulles) : ici, c'est la LARGEUR, pas le nombre, qui doit
    // forcer la troncature.
    const summary = CounterSummary(
      counters: [
        MapEntry(_poison, 9),
        MapEntry(_energy, 8),
        MapEntry(_custom, 7),
      ],
      worstCommanderDamage: 6,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              // Largeur volontairement bien trop étroite pour 4 puces.
              width: 60,
              child: ConditionalHandle(
                summary: summary,
                maxVisibleChips: 10,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'aucun débordement, à AUCUNE largeur -- pas de '
            'RenderFlex overflowed, même silencieux en release : c\'est '
            'exactement le mécanisme qui a fait revenir en arrière le lot 6');

    final overflowFinder = find.textContaining('+');
    expect(overflowFinder, findsOneWidget,
        reason: 'à 60px, 4 puces ne tiennent pas : la largeur doit forcer '
            'un "+N", même si maxVisibleChips (10) ne l\'exigeait pas');

    final overflowText = tester.widget<Text>(overflowFinder).data!;
    final hiddenCount = int.parse(overflowText.substring(1));
    final visibleChipsCount =
        tester.widgetList<Text>(find.byType(Text)).length - 1; // - le "+N"

    expect(visibleChipsCount + hiddenCount, 4,
        reason: 'le "+N" doit compter TOUTES les puces manquantes, pas '
            'seulement celles que maxVisibleChips aurait écartées');
  });

  // --- Ronde de correction 2, Critical 1 : la boucle de réduction protège
  // la transition VERS le "+N", mais rien ne vérifiait que le "+N" LUI-MÊME
  // tienne dans maxWidth une fois qu'il est le seul contenu restant. Deux
  // reproductions distinctes, toutes deux données par la revue.

  testWidgets(
      'même quand le "+N" lui-même ne tiendrait pas (largeur extrême, '
      'plusieurs entrées), aucun débordement ne se produit -- un marqueur '
      'minimal non textuel prend le relais', (tester) async {
    const summary = CounterSummary(
      counters: [
        MapEntry(_poison, 9),
        MapEntry(_energy, 8),
        MapEntry(_custom, 7),
      ],
      worstCommanderDamage: 6,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 5,
              child: ConditionalHandle(summary: summary),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'aucun débordement, à AUCUNE largeur -- même quand il n\'y a '
            'plus la place de compter, "+N" compris');
    expect(find.byKey(ConditionalHandle.overflowMarkerKey), findsOneWidget,
        reason: 'un contenu qui ne tient nulle part ne doit ni déborder ni '
            'disparaître sans rien signaler : un marqueur minimal, non '
            'textuel, prend le relais du "+N" quand celui-ci ne tient plus');
  });

  testWidgets(
      'même quand le "+N" lui-même ne tiendrait pas (une seule entrée à '
      'valeur énorme, largeur très étroite), aucun débordement ne se '
      'produit', (tester) async {
    const summary = CounterSummary(
      counters: [MapEntry(_poison, 999999999)],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 20,
              child: ConditionalHandle(summary: summary),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'la puce cède la place au "+1", qui ne doit pas déborder à '
            'son tour');
    expect(find.byKey(ConditionalHandle.overflowMarkerKey), findsOneWidget);
  });

  // --- Ronde de correction 2, Critical 2 : TextPainter mesurait à l\'échelle
  // 1.0 alors que les Text réellement rendus héritent du TextScaler ambiant
  // (MediaQuery) -- un réglage d\'accessibilité "grand texte" débordait donc
  // même quand la mesure à l\'échelle 1.0 affirmait que ça tenait.

  testWidgets(
      'sous un TextScaler agrandi (réglage d\'accessibilité "grand texte"), '
      'aucun débordement ne se produit', (tester) async {
    const summary = CounterSummary(
      counters: [MapEntry(_poison, 3)],
      worstCommanderDamage: 9,
    );

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 100,
                child: ConditionalHandle(summary: summary),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'la mesure des puces doit suivre le TextScaler ambiant -- '
            'un TextPainter mesuré à l\'échelle 1.0 alors que le texte '
            'rendu est agrandi sous-estime la largeur réelle et laisse '
            'passer un débordement');
  });

  // --- Ronde de correction 2, Mineur 3 : le test de débordement par largeur
  // fixait maxVisibleChips à une valeur inopérante (10), donc ne prouvait
  // que la troncature par largeur SEULE. Cas combiné : assez d'entrées pour
  // que maxVisibleChips coupe d'abord, puis une largeur qui coupe encore --
  // et vérifie que le compte total reste juste (pas de double comptage).

  testWidgets(
      'cas combiné : maxVisibleChips coupe d\'abord, la largeur coupe '
      'encore ensuite -- le compte du "+N" reste juste (pas de double '
      'comptage)', (tester) async {
    // 6 entrées non nulles, maxVisibleChips: 4 -> maxVisibleChips coupe
    // d'abord à 3 puces affichées + "+3". Une largeur encore plus étroite
    // que ce que ces 3 puces + "+3" nécessitent force une seconde coupe.
    const summary = CounterSummary(
      counters: [
        MapEntry(_poison, 90),
        MapEntry(_energy, 80),
        MapEntry(_custom, 70),
        MapEntry(_alpha, 60),
        MapEntry(_beta, 50),
      ],
      worstCommanderDamage: 100,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 90,
              child: ConditionalHandle(summary: summary, maxVisibleChips: 4),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final overflowFinder = find.textContaining('+');
    expect(overflowFinder, findsOneWidget);
    final overflowText = tester.widget<Text>(overflowFinder).data!;
    final hiddenCount = int.parse(overflowText.substring(1));

    // Total : commanderDamage + poison + energy + custom + alpha + beta = 6.
    final visibleChipsCount =
        tester.widgetList<Text>(find.byType(Text)).length - 1; // - le "+N"
    expect(visibleChipsCount + hiddenCount, 6,
        reason: 'le compte doit rester juste même quand les deux causes de '
            'troncature (maxVisibleChips ET largeur) jouent ensemble');
    expect(hiddenCount, greaterThan(3),
        reason: 'maxVisibleChips seul aurait caché 3 entrées ("+3") ; si '
            'hiddenCount vaut encore 3 ici, c\'est que la coupe par largeur '
            'n\'a pas eu lieu -- ce test ne prouverait alors que le cas '
            'maxVisibleChips déjà couvert par un autre test');
  });
}
