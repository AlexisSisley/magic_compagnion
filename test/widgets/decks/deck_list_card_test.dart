// Tests widget de la tuile de deck : forme constante, badge, compte, prix,
// pastilles, glissement de suppression et appui long.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/cards/scryfall_image.dart';
import 'package:magic_companion/widgets/decks/deck_list_card.dart';

void main() {
  Deck deck({
    String name = 'Atraxa',
    String format = 'Commander',
    String? commander,
    List<String> colors = const [],
    List<DeckCard>? mainboard,
  }) =>
      Deck(
        id: name,
        name: name,
        format: format,
        colors: colors,
        commanderScryfallId: commander,
        mainboard: mainboard,
      );

  Widget host(Widget tile, {double width = 360}) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: tile),
          ),
        ),
      );

  DeckListCard card(
    Deck d, {
    double price = 289,
    VoidCallback? onLongPress,
    Future<bool?> Function(DismissDirection)? confirm,
  }) =>
      DeckListCard(
        deck: d,
        totalPrice: price,
        onTap: () {},
        onLongPress: onLongPress,
        confirmDismiss: confirm ?? (_) async => false,
        onDismissed: () {},
      );

  final pips = find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('deck-color-pip-'));

  // Le chargement réseau de l'art échoue en test : on absorbe l'erreur comme
  // les captures le font, la tuile doit se mesurer malgré tout.
  Future<void> pump(WidgetTester tester, Widget w) async {
    await runZonedGuarded(() async {
      await tester.pumpWidget(w);
      await tester.pump();
    }, (e, s) {});
  }

  testWidgets('avec ou sans commandant, la tuile a la même taille et un ratio 16:9',
      (tester) async {
    await pump(tester, host(card(deck(commander: 'abc-123'))));
    final withArt = tester.getSize(find.byType(DeckListCard));
    expect(find.byType(ScryfallImage), findsOneWidget);

    await pump(tester, host(card(deck(name: 'Sans'))));
    final withoutArt = tester.getSize(find.byType(DeckListCard));

    expect(withoutArt, withArt);
    expect(withoutArt.width / withoutArt.height, closeTo(16 / 9, 0.001));
  });

  testWidgets('la rangée de pastilles réserve sa hauteur même vide',
      (tester) async {
    // La tuile a un ratio fixe : sa taille ne prouve rien. C'est la position
    // du nom et du compte, posés au-dessus et au-dessous de la rangée, qui
    // trahit une rangée écrasée.
    Offset where(String text) => tester.getTopLeft(find.textContaining(text,
        findRichText: true));

    await pump(tester, host(card(deck(colors: const ['W', 'U', 'B', 'R', 'G']))));
    expect(pips, findsNWidgets(5));
    final nameWith = where('Atraxa');
    final countWith = where('carte');

    await pump(tester, host(card(deck())));
    expect(pips, findsNothing);
    expect(where('Atraxa'), nameWith);
    expect(where('carte'), countWith);
  });

  testWidgets('sans commandant : pas d\'image, icône de deck présente',
      (tester) async {
    await pump(tester, host(card(deck())));
    expect(find.byType(ScryfallImage), findsNothing);
    expect(find.byIcon(Icons.style_outlined), findsOneWidget);
  });

  testWidgets('le badge affiche le format en majuscules', (tester) async {
    await pump(tester, host(card(deck(format: 'Modern'))));
    expect(find.text('MODERN'), findsOneWidget);
  });

  testWidgets('le compte vient de la somme des quantités du mainboard',
      (tester) async {
    final d = deck(mainboard: [
      DeckCard(scryfallId: 'a', name: 'A', quantity: 99),
      DeckCard(scryfallId: 'b', name: 'B', quantity: 8),
    ]);
    await pump(tester, host(card(d)));
    expect(find.textContaining('107 cartes', findRichText: true), findsOneWidget);
  });

  testWidgets('le prix est arrondi à l\'euro, « — » s\'il est inconnu',
      (tester) async {
    await pump(tester, host(card(deck(), price: 288.6)));
    expect(find.textContaining('289 €', findRichText: true), findsOneWidget);

    await pump(tester, host(card(deck(), price: 0)));
    expect(find.textContaining('—', findRichText: true), findsOneWidget);
    expect(find.textContaining('0 €', findRichText: true), findsNothing);
  });

  testWidgets('glisser de droite à gauche montre USE THE FORCE et demande confirmation',
      (tester) async {
    var asked = 0;
    await pump(
        tester,
        host(card(deck(), confirm: (_) async {
          asked++;
          return false;
        })));

    await tester.drag(find.byType(DeckListCard), const Offset(-300, 0));
    await tester.pump();
    expect(find.text('USE THE FORCE'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(asked, 1);
  });

  testWidgets('onLongPress est appelé', (tester) async {
    var pressed = 0;
    await pump(tester, host(card(deck(), onLongPress: () => pressed++)));
    await tester.longPress(find.byType(DeckListCard));
    expect(pressed, 1);
  });

  testWidgets('le nom reste lisible : fond déjà sombre sous le nom et ombre portée',
      (tester) async {
    await pump(tester, host(card(deck(commander: 'abc-123'))));

    final gradient = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((b) => b.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.gradient)
        .whereType<LinearGradient>()
        .single;
    // Le nom commence à ~25 % de la hauteur du bloc : le fond y est déjà à 60 %.
    final i = gradient.stops!.indexWhere((s) => s >= 0.25);
    expect(gradient.colors[i].a, greaterThanOrEqualTo(0.6));
    expect(gradient.colors.last.a, greaterThanOrEqualTo(0.85));

    final name = tester.widget<Text>(find.text('Atraxa'));
    expect(name.style!.shadows, isNotEmpty);
  });

  testWidgets('« 1 carte » au singulier, « 2 cartes » au pluriel',
      (tester) async {
    Deck withQty(int q) =>
        deck(mainboard: [DeckCard(scryfallId: 'a', name: 'A', quantity: q)]);

    await pump(tester, host(card(withQty(1))));
    expect(find.textContaining('1 carte ·', findRichText: true), findsOneWidget);

    await pump(tester, host(card(withQty(2))));
    expect(find.textContaining('2 cartes', findRichText: true), findsOneWidget);
  });
}
