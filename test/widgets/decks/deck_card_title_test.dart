// Tests widget pour DeckCardTile : projection d'affichage (langue preferee),
// badge de repli, et troncature sur une seule ligne quel que soit le nom.
//
// Round de correction 1 (Task 8) : la projection resolue en amont
// (`CardDisplay`) doit remplacer silencieusement `card.name` quand elle est
// disponible, sans jamais faire grandir la ligne du ListTile.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/providers/card_display_provider.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';

void main() {
  DeckCard card({String name = 'Dreadbore'}) => DeckCard(
        scryfallId: 'sld-141',
        name: name,
        quantity: 1,
      );

  Widget buildTile({required DeckCard forCard, CardDisplay? display}) {
    return MaterialApp(
      home: Scaffold(
        body: DeckCardTile(
          card: forCard,
          scryfallCard: null,
          isInCollection: false,
          display: display,
          onMore: () {},
        ),
      ),
    );
  }

  group('DeckCardTile — projection de langue', () {
    testWidgets('affiche le nom traduit quand la projection est disponible',
        (tester) async {
      final c = card(name: 'Dreadbore');
      await tester.pumpWidget(buildTile(
        forCard: c,
        display: const CardDisplay(
          name: 'Foudre décimante',
          lang: 'fr',
          isFallback: false,
        ),
      ));

      expect(find.text('Foudre décimante'), findsOneWidget);
      expect(find.text('Dreadbore'), findsNothing);
    });

    testWidgets(
        'affiche le nom du tirage possede quand la projection n est pas encore resolue',
        (tester) async {
      final c = card(name: 'Dreadbore');
      await tester.pumpWidget(buildTile(forCard: c, display: null));

      expect(find.text('Dreadbore'), findsOneWidget);
    });
  });

  group('DeckCardTile — badge de repli', () {
    testWidgets('apparait quand isFallback est vrai', (tester) async {
      final c = card(name: 'Dreadbore');
      await tester.pumpWidget(buildTile(
        forCard: c,
        display: const CardDisplay(
          name: 'Dreadbore',
          lang: 'en',
          isFallback: true,
        ),
      ));

      expect(find.text('EN · pas de VF'), findsOneWidget);
    });

    testWidgets('n apparait pas quand isFallback est faux', (tester) async {
      final c = card(name: 'Dreadbore');
      await tester.pumpWidget(buildTile(
        forCard: c,
        display: const CardDisplay(
          name: 'Foudre décimante',
          lang: 'fr',
          isFallback: false,
        ),
      ));

      expect(find.textContaining('pas de VF'), findsNothing);
    });

    testWidgets('n apparait pas quand aucune projection n est fournie',
        (tester) async {
      final c = card(name: 'Dreadbore');
      await tester.pumpWidget(buildTile(forCard: c, display: null));

      expect(find.textContaining('pas de VF'), findsNothing);
    });
  });

  group('DeckCardTile — un nom de carte tient sur une ligne', () {
    const longName =
        "Libérateur, mécanoptère de combat d'Urza (nom de carte anormalement long pour tester la troncature)";

    testWidgets(
        'le Text du nom garde maxLines 1 et softWrap false meme pour un nom tres long',
        (tester) async {
      final c = card(name: longName);
      await tester.pumpWidget(buildTile(forCard: c, display: null));

      final textWidget = tester.widget<Text>(find.text(longName));
      expect(textWidget.maxLines, 1);
      expect(textWidget.softWrap, isFalse);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
        'la hauteur de la tuile ne depend pas de la longueur du nom affiche',
        (tester) async {
      await tester.pumpWidget(buildTile(forCard: card(name: 'Sol Ring')));
      final shortHeight =
          tester.getSize(find.byType(DeckCardTile)).height;

      await tester.pumpWidget(buildTile(forCard: card(name: longName)));
      final longHeight = tester.getSize(find.byType(DeckCardTile)).height;

      expect(longHeight, shortHeight);
    });

    testWidgets(
        'le badge de repli ne fait pas deborder ni grandir la ligne meme avec un nom long',
        (tester) async {
      await tester.pumpWidget(buildTile(forCard: card(name: 'Sol Ring')));
      final baselineHeight =
          tester.getSize(find.byType(DeckCardTile)).height;

      await tester.pumpWidget(buildTile(
        forCard: card(name: longName),
        display: const CardDisplay(name: longName, lang: 'en', isFallback: true),
      ));
      // Pas d'exception de overflow (RenderFlex) : pumpAndSettle leverait sinon.
      await tester.pumpAndSettle();
      final withBadgeHeight =
          tester.getSize(find.byType(DeckCardTile)).height;

      expect(withBadgeHeight, baselineHeight);
      expect(tester.takeException(), isNull);
    });
  });
}
