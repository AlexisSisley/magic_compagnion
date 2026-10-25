// Tests du bandeau du commandant : hauteur constante, rangée de stats, repli
// d'art et absence de débordement sur petite largeur.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/edhrec_models.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/theme/magic_palette.dart';
import 'package:magic_companion/widgets/cards/scryfall_image.dart';
import 'package:magic_companion/widgets/decks/deck_commander_header.dart';

void main() {
  Deck deck({
    String? commander,
    String? partner,
    List<String> colors = const ['W', 'U'],
  }) => Deck(
    id: 'd',
    name: 'Atraxa',
    colors: colors,
    commanderScryfallId: commander,
    commanderSecondaryScryfallId: partner,
  );

  const power = DeckPowerLevel(score: 7, label: 'Optimized', factors: {});

  Widget header(
    Deck d, {
    DeckPowerLevel? powerLevel = power,
    double cmc = 3.24,
    double price = 289,
    double width = 840,
  }) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DeckCommanderHeader(
            deck: d,
            fullCardData: const [],
            cardCount: 107,
            averageManaValue: cmc,
            powerLevel: powerLevel,
            totalPrice: price,
          ),
        ),
      ),
    ),
  );

  // Le chargement réseau de l'art échoue en test : on absorbe l'erreur.
  // La fenêtre de test fait 800 de large par défaut : on la cale sur la
  // largeur de la maquette (840) ou du téléphone (390).
  Future<void> pump(WidgetTester tester, Widget w, {double width = 840}) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await runZonedGuarded(() async {
      await tester.pumpWidget(w);
      await tester.pump();
    }, (e, s) {});
  }

  testWidgets('même hauteur (180) avec un commandant, deux et aucun', (
    tester,
  ) async {
    await pump(tester, header(deck(commander: 'a')));
    final one = tester.getSize(find.byType(DeckCommanderHeader)).height;
    await pump(tester, header(deck(commander: 'a', partner: 'b')));
    final two = tester.getSize(find.byType(DeckCommanderHeader)).height;
    await pump(tester, header(deck()));
    final none = tester.getSize(find.byType(DeckCommanderHeader)).height;

    expect([one, two, none], [180, 180, 180]);
  });

  testWidgets('sans commandant : message et fond neutre, aucune image', (
    tester,
  ) async {
    await pump(tester, header(deck()));
    expect(find.text('Aucun commandant défini'), findsOneWidget);
    expect(find.byType(ScryfallImage), findsNothing);
    final palette = MagicPalette.of(
      tester.element(find.byType(DeckCommanderHeader)),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == palette.raised,
      ),
      findsOneWidget,
    );
  });

  testWidgets('un partenaire donne deux arts, chacun sur la moitié', (
    tester,
  ) async {
    await pump(tester, header(deck(commander: 'a', partner: 'b')));
    final images = find.byType(ScryfallImage);
    expect(images, findsNWidgets(2));
    expect(tester.getSize(images.at(0)).width, 420);
    expect(tester.getSize(images.at(1)).width, 420);
  });

  testWidgets('un seul commandant : un art plein cadre', (tester) async {
    await pump(tester, header(deck(commander: 'a')));
    expect(find.byType(ScryfallImage), findsOneWidget);
    expect(tester.getSize(find.byType(ScryfallImage)).width, 840);
  });

  testWidgets('commandant « LOCAL: » : aucune image demandée', (tester) async {
    await pump(tester, header(deck(commander: 'LOCAL:Atraxa')));
    expect(find.byType(ScryfallImage), findsNothing);
  });

  testWidgets('l\'art reçoit un repli neutre, pas l\'icône d\'image cassée', (
    tester,
  ) async {
    await pump(tester, header(deck(commander: 'abc-123')));
    final image = tester.widget<ScryfallImage>(find.byType(ScryfallImage));
    final palette = MagicPalette.of(
      tester.element(find.byType(DeckCommanderHeader)),
    );
    expect(image.errorWidget, isA<ColoredBox>());
    expect((image.errorWidget! as ColoredBox).color, palette.raised);
  });

  testWidgets('la rangée finit par le prix, à droite', (tester) async {
    await pump(tester, header(deck(commander: 'a')));
    double dx(String t) => tester.getTopLeft(find.text(t)).dx;

    final order = [
      dx('107 cartes'),
      dx('CMC moyen 3,2'),
      dx('Power 7'),
      dx('289 €'),
    ];
    expect(order, orderedEquals([...order]..sort()));
    expect(order.toSet().length, 4);
    // Poussé au bord droit, pas collé aux autres.
    expect(tester.getTopRight(find.text('289 €')).dx, greaterThan(800));
  });

  testWidgets('« CMC moyen 3,2 » porte la virgule', (tester) async {
    await pump(tester, header(deck(commander: 'a')));
    expect(find.text('CMC moyen 3,2'), findsOneWidget);
    expect(find.textContaining('3.2'), findsNothing);
  });

  testWidgets('pas de pilule Power sans power level', (tester) async {
    await pump(tester, header(deck(commander: 'a'), powerLevel: null));
    expect(find.textContaining('Power'), findsNothing);
  });

  testWidgets('la pilule Power est à bordure et texte or', (tester) async {
    await pump(tester, header(deck(commander: 'a')));
    final text = tester.widget<Text>(find.text('Power 7'));
    expect(text.style!.color, AppColors.primary);
    final pill = tester.widget<Container>(
      find.ancestor(of: find.text('Power 7'), matching: find.byType(Container)),
    );
    final border = (pill.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppColors.primary);
  });

  testWidgets('les pastilles de couleur font 14 px', (tester) async {
    await pump(tester, header(deck(commander: 'a', colors: ['W', 'U', 'B'])));
    final pips = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('deck-color-pip-'),
    );
    expect(pips, findsNWidgets(3));
    final disc = find.descendant(
      of: pips.first,
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(disc), const Size(14, 14));
  });

  testWidgets('à 390 de large la rangée passe à la ligne sans déborder, '
      'le prix reste en dernier', (tester) async {
    await pump(
      tester,
      header(
        deck(commander: 'a', colors: ['W', 'U', 'B', 'R', 'G']),
        width: 390,
      ),
      width: 390,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(DeckCommanderHeader)).height, 180);
    // La rangée a bien dû passer à la ligne : le test ne prouverait rien sinon.
    expect(
      tester.getTopLeft(find.text('Power 7')).dy,
      greaterThan(tester.getTopLeft(find.text('107 cartes')).dy),
    );
    final power = tester.getTopLeft(find.text('Power 7'));
    final price = tester.getTopLeft(find.text('289 €'));
    expect(price.dx, greaterThan(power.dx));
  });
}
