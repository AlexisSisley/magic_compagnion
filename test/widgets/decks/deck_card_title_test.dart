// Tests widget pour DeckCardTile : projection d'affichage (langue preferee),
// badge de repli, et troncature sur une seule ligne quel que soit le nom.
//
// Round de correction 1 (Task 8) : la projection resolue en amont
// (`CardDisplay`) doit remplacer silencieusement `card.name` quand elle est
// disponible, sans jamais faire grandir la ligne du ListTile.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/providers/card_display_provider.dart';
import 'package:magic_companion/theme/app_colors.dart';
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

  group('DeckCardTile — sans prix', () {
    testWidgets('n\'affiche aucun montant même quand la carte a un prix', (
      tester,
    ) async {
      final sc = ScryfallCard.fromJson({
        'id': 'sld-141',
        'oracle_id': 'o-1',
        'name': 'Dreadbore',
        'type_line': 'Sorcery',
        'cmc': 2.0,
        'legalities': <String, dynamic>{},
        'prices': {'eur': '1.50', 'usd': '2.00'},
        'purchase_uris': <String, dynamic>{},
        'color_identity': ['B', 'R'],
        'set_name': 'Test',
        'set': 'tst',
        'collector_number': '1',
        'rarity': 'rare',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeckCardTile(
              card: card(),
              scryfallCard: sc,
              isInCollection: false,
              onMore: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('€'), findsNothing);
      expect(find.textContaining('1.50'), findsNothing);
    });
  });

  group('DeckCardGridTile — catégorie corrigée', () {
    Widget buildGrid({required bool locked}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 130,
          height: 160,
          child: DeckCardGridTile(
            card: card(),
            scryfallCard: null,
            isInCollection: false,
            categoryLocked: locked,
            onPlus: () {},
            onMinus: () {},
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );

    testWidgets('verrouillée : cadenas de 11 px et liseré or de 2 px', (
      tester,
    ) async {
      await tester.pumpWidget(buildGrid(locked: true));

      final lock = tester.widget<Icon>(find.byIcon(Icons.lock));
      expect(lock.size, 11);
      final shape =
          tester.widget<Card>(find.byType(Card)).shape as RoundedRectangleBorder;
      expect(shape.side.width, 2);
      expect(shape.side.color, AppColors.primary);
    });

    testWidgets('non verrouillée : ni cadenas ni liseré épais', (
      tester,
    ) async {
      await tester.pumpWidget(buildGrid(locked: false));

      expect(find.byIcon(Icons.lock), findsNothing);
      final shape =
          tester.widget<Card>(find.byType(Card)).shape as RoundedRectangleBorder;
      expect(shape.side.width, 1);
    });
  });
}
