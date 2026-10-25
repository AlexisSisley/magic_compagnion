// Test de non-regression (round de correction 1, Task 8) : la projection
// d'affichage doit etre resolue et branchee bout-en-bout depuis
// DeckCardListTab, pas seulement testee isolement sur le provider et sur
// DeckCardTile. Le defaut constate : `resolveDisplay` existait et etait
// testee, mais aucune ligne de deck ne l'appelait -- les noms anglais
// restaient affiches a l'ecran malgre une traduction en cache.
//
// Sequence attendue par la spec : au premier frame (t=0) le tirage possede
// s'affiche immediatement (jamais de spinner), puis la traduction le
// remplace silencieusement une fois la resolution terminee (t=2s), sans
// jamais passer par un etat de chargement visible.
//
// Round de correction 2 : `_loadDisplays` n'avait ni jeton de sequence ni
// annulation. `didUpdateWidget` peut en declencher un second avant que le
// premier n'ait fini (deck modifie deux fois rapidement, import qui
// rafraichit la liste...) ; rien ne garantissait l'ordre de resolution des
// Future, donc un appel demarre en premier mais qui repond en dernier
// pouvait ecraser une projection fraiche par une perimee.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_tag.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/deck_view_prefs.dart';
import 'package:magic_companion/widgets/decks/deck_card_list_tab.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';

/// AppDatabase de test capable de retarder, sur commande, le PROCHAIN appel
/// a `getCardPrint` pour un `scryfallId` donne -- un seul cran : les appels
/// suivants au meme id ne sont plus retardes. Sert a forcer deterministe le
/// chevauchement de deux resolutions dans `_DeckCardListTabState`.
class _DelayableDb extends AppDatabase {
  _DelayableDb(super.executor);

  String? _delayedScryfallId;
  Completer<void>? _gate;

  void delayNextCardPrint(String scryfallId) {
    _delayedScryfallId = scryfallId;
    _gate = Completer<void>();
  }

  void releaseDelayedCardPrint() {
    _gate?.complete();
  }

  @override
  Future<DbCardPrint?> getCardPrint(String scryfallId) async {
    if (scryfallId == _delayedScryfallId) {
      final gate = _gate!;
      // Un seul cran : on ne re-retarde pas un appel ulterieur au meme id.
      _delayedScryfallId = null;
      await gate.future;
    }
    return super.getCardPrint(scryfallId);
  }
}

/// Fabrique un tirage en respectant le contrat de [DbCardPrint] :
/// `printedName` porte le nom localise de CE tirage et reste NUL quand il n'y
/// en a pas -- ce qui est le cas de tout tirage anglais. Poser
/// `printedName: 'Dreadbore'` sur un tirage `lang: 'en'` violait ce contrat et
/// avait un effet pervers : le repli `printedName ?? oracleName` de
/// `resolveDisplay` n'etait jamais exerce par ces tests. L'assertion ci-dessous
/// empeche la violation de revenir.
DbCardPrint _print({
  required String scryfallId,
  required String lang,
  String? printedName,
  required String oracleId,
  required String oracleName,
}) {
  assert(
    lang != 'en' || printedName == null,
    'un tirage anglais n\'a pas de nom imprime : printedName doit rester nul '
    '(le nom affiche vient alors de oracleName)',
  );
  return DbCardPrint(
      scryfallId: scryfallId,
      oracleId: oracleId,
      oracleName: oracleName,
      setCode: 'sld',
      collectorNumber: '141',
      lang: lang,
      printedName: printedName,
      printedText: null,
      imageUri: null,
      colorIdentity: '[]',
      fetchedAt: DateTime.utc(2026, 9, 17),
    );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'glossaryLang': 'fr'});
  });

  tearDown(() async => db.close());

  Widget buildTabWithDb(
    List<DeckCard> cardList,
    AppDatabase database, {
    List<ScryfallCard> fullCardData = const [],
    // Ces tests parlent surtout des sections par tag : on les pose
    // explicitement, le défaut de l'app étant le regroupement par type.
    DeckViewPrefs viewPrefs = const DeckViewPrefs(grouping: DeckGrouping.tag),
    List<CardTagDef> tagCatalog = kDefaultCardTags,
    DeckBoard currentBoard = DeckBoard.main,
    VoidCallback? onExportToGlobalWishlist,
    void Function(DeckCard, List<String>)? onSetTags,
    ValueChanged<DeckCard>? onResetTags,
  }) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        home: Scaffold(
          body: DeckCardListTab(
            cardList: cardList,
            fullCardData: fullCardData,
            collection: const [],
            currentBoard: currentBoard,
            onUpdateQuantity: (_, _) {},
            onExportToGlobalWishlist: onExportToGlobalWishlist,
            viewPrefs: viewPrefs,
            tagCatalog: tagCatalog,
            onSetTags: onSetTags ?? (_, _) {},
            onResetTags: onResetTags ?? (_) {},
          ),
        ),
      ),
    );
  }

  Widget buildTab(List<DeckCard> cardList) => buildTabWithDb(cardList, db);

  testWidgets(
      'remplace silencieusement le nom possede par la traduction en cache, sans spinner',
      (tester) async {
    await db.upsertCardPrint(_print(
      scryfallId: 'sld-141',
      lang: 'en',
      oracleId: 'oracle-dreadbore',
      oracleName: 'Dreadbore',
    ));
    await db.upsertCardPrint(_print(
      scryfallId: 'fr-141',
      lang: 'fr',
      printedName: 'Foudre décimante',
      oracleId: 'oracle-dreadbore',
      oracleName: 'Dreadbore',
    ));

    final cardList = [
      DeckCard(scryfallId: 'sld-141', name: 'Dreadbore', quantity: 1),
    ];

    await tester.pumpWidget(buildTab(cardList));

    // t=0 : premier frame, avant toute resolution -- le tirage possede
    // s'affiche tout de suite, jamais de spinner.
    expect(find.text('Dreadbore'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // La resolution (lecture DB + SharedPreferences) se termine.
    await tester.pumpAndSettle();

    // La traduction remplace silencieusement le nom -- toujours aucun
    // spinner entre les deux etats.
    expect(find.text('Foudre décimante'), findsOneWidget);
    expect(find.text('Dreadbore'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'garde le tirage possede et signale le repli quand l absence de '
      'traduction est CONFIRMEE',
      (tester) async {
    await db.upsertCardPrint(_print(
      scryfallId: 'sld-141',
      lang: 'en',
      oracleId: 'oracle-dreadbore',
      oracleName: 'Dreadbore',
    ));
    // Scryfall a repondu 404 sur la route de traduction : l'absence est un
    // fait etabli. Sans cette confirmation, le repli est silencieux (voir le
    // test suivant) -- sinon chaque ligne d'un deck fraichement importe
    // afficherait "EN · pas de VF", y compris les cartes qui ont une VF.
    await db.markTranslationAbsent('oracle-dreadbore', 'fr');

    final cardList = [
      DeckCard(scryfallId: 'sld-141', name: 'Dreadbore', quantity: 1),
    ];

    await tester.pumpWidget(buildTab(cardList));
    await tester.pumpAndSettle();

    expect(find.text('Dreadbore'), findsOneWidget);
    expect(find.text('EN · pas de VF'), findsOneWidget);
  });

  testWidgets(
      'juste apres un import, aucune ligne n affiche "pas de VF" : la '
      'traduction n a pas encore ete demandee',
      (tester) async {
    // L'etat exact d'un deck fraichement importe : le tirage possede est en
    // cache, la traduction est encore en file. Le badge doit rester muet --
    // c'est la premiere chose que l'utilisateur voit a l'ecran.
    await db.upsertCardPrint(_print(
      scryfallId: 'sld-141',
      lang: 'en',
      oracleId: 'oracle-dreadbore',
      oracleName: 'Dreadbore',
    ));

    final cardList = [
      DeckCard(scryfallId: 'sld-141', name: 'Dreadbore', quantity: 1),
    ];

    await tester.pumpWidget(buildTab(cardList));
    await tester.pumpAndSettle();

    expect(find.text('Dreadbore'), findsOneWidget);
    expect(find.text('EN · pas de VF'), findsNothing);
  });

  group('_loadDisplays — jeton de sequence', () {
    testWidgets(
        'un chargement demarre en premier mais qui repond en dernier n ecrase pas le resultat du chargement le plus recent',
        (tester) async {
      final delayableDb = _DelayableDb(NativeDatabase.memory());
      addTearDown(() => delayableDb.close());

      // Etat initial : seule "card-a" existe, en anglais, pas de traduction.
      await delayableDb.upsertCardPrint(_print(
        scryfallId: 'card-a',
        lang: 'en',
        oracleId: 'oracle-a',
        oracleName: 'CardA v1',
      ));

      // Le PROCHAIN appel a getCardPrint('card-a') sera bloque jusqu'a
      // liberation explicite -- il simule le premier chargement, lent.
      delayableDb.delayNextCardPrint('card-a');

      final cardList1 = [
        DeckCard(scryfallId: 'card-a', name: 'CardA fallback', quantity: 1),
      ];

      await tester.pumpWidget(buildTabWithDb(cardList1, delayableDb));
      // Laisse le premier chargement demarrer et se bloquer sur le gate.
      await tester.pump();

      // Le deck est modifie pendant que le premier chargement est bloque :
      // "card-a" est mise a jour (nouveau nom) et "card-b" apparait. C'est
      // exactement le scenario cite par la revue : deck modifie deux fois
      // rapidement / import qui rafraichit la liste.
      await delayableDb.upsertCardPrint(_print(
        scryfallId: 'card-a',
        lang: 'en',
        oracleId: 'oracle-a',
        oracleName: 'CardA v2',
      ));
      await delayableDb.upsertCardPrint(_print(
        scryfallId: 'card-b',
        lang: 'en',
        oracleId: 'oracle-b',
        oracleName: 'CardB-projected',
      ));

      final cardList2 = [
        DeckCard(scryfallId: 'card-a', name: 'CardA fallback', quantity: 1),
        DeckCard(scryfallId: 'card-b', name: 'CardB-original', quantity: 1),
      ];

      // Signature de cardList differente de cardList1 -> didUpdateWidget
      // relance un second chargement (plus rapide : rien ne le retarde).
      await tester.pumpWidget(buildTabWithDb(cardList2, delayableDb));

      // Laisse le second chargement (le plus recent) se terminer completement
      // pendant que le premier reste bloque sur son gate.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.text('CardA v2'), findsOneWidget);
      expect(find.text('CardB-projected'), findsOneWidget);
      expect(find.text('CardA fallback'), findsNothing);
      expect(find.text('CardB-original'), findsNothing);

      // Le premier chargement (perime) est enfin libere et se termine APRES
      // le second. Sans jeton de sequence, son resultat -- construit sur la
      // liste a un seul element qu'il avait capturee au demarrage --
      // ecraserait la map et ferait disparaitre la projection de "card-b".
      delayableDb.releaseDelayedCardPrint();
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      // Le dernier lancement gagne : la projection de card-b doit survivre
      // au retour tardif du premier chargement.
      expect(find.text('CardA v2'), findsOneWidget);
      expect(find.text('CardB-projected'), findsOneWidget);
      expect(find.text('CardB-original'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
  group('liste par tags', () {
    ScryfallCard sc(String id, String type, double cmc) =>
        ScryfallCard.fromJson({
          'id': id,
          'oracle_id': 'o-$id',
          'name': id,
          'type_line': type,
          'cmc': cmc,
          'legalities': <String, dynamic>{},
          'prices': <String, dynamic>{},
          'purchase_uris': <String, dynamic>{},
          'color_identity': <String>[],
          'set_name': 'Test',
          'set': 'tst',
          'collector_number': '1',
          'rarity': 'common',
        });

    DeckCard dc(
      String id, {
      List<String> tags = const [],
      bool edited = false,
      int quantity = 1,
    }) => DeckCard(
      scryfallId: id,
      name: id,
      quantity: quantity,
      tags: tags,
      tagsEdited: edited,
    );

    testWidgets('tag grouping orders catalogue, deck tags, then Sans tag', (
      tester,
    ) async {
      // Volontairement fournies dans le désordre : l'ordre affiché est celui
      // du catalogue, puis l'alphabet pour les tags de deck.
      final cards = [
        dc('sans'),
        dc('zebre', tags: ['Zèbre']),
        dc('pioche', tags: ['Pioche', 'Ramp']),
        dc('alpha', tags: ['Alpha']),
        dc('ramp', tags: ['Ramp']),
      ];
      // Assez haut pour que toutes les sections soient construites.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(buildTabWithDb(cards, db));
      await tester.pumpAndSettle();

      expect(find.byType(DeckCardTile), findsNothing);
      expect(find.byType(DeckCardGridTile), findsNWidgets(5));
      final ys = [
        'RAMP',
        'PIOCHE',
        'ALPHA',
        'ZÈBRE',
        'SANS TAG',
      ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(ys, orderedEquals([...ys]..sort()));
      expect(ys.toSet(), hasLength(5));
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('seul le tag principal fait la section, à la casse près du '
        'catalogue', (tester) async {
      await tester.pumpWidget(
        buildTabWithDb([
          dc('a', tags: ['ramp', 'Pioche']),
          dc('b', tags: ['Ramp']),
        ], db),
      );
      await tester.pumpAndSettle();

      expect(find.text('RAMP'), findsOneWidget);
      expect(find.text('PIOCHE'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('un catalogue réordonné donne l\'ordre des sections', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb(
          [
            dc('a', tags: ['Ramp']),
            dc('b', tags: ['Wipe']),
          ],
          db,
          tagCatalog: const [
            CardTagDef(key: 'wipe', name: 'Wipe', color: 0xFFAB47BC),
            CardTagDef(key: 'ramp', name: 'Ramp', color: 0xFF4CAF50),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('WIPE')).dy,
        lessThan(tester.getTopLeft(find.text('RAMP')).dy),
      );
    });

    testWidgets('l\'en-tête porte la quantité et le CMC moyen à virgule', (
      tester,
    ) async {
      final cards = [
        dc('a', tags: ['Ramp']),
        dc('b', tags: ['Ramp']),
      ];
      await tester.pumpWidget(
        buildTabWithDb(
          cards,
          db,
          fullCardData: [sc('a', 'Artifact', 1), sc('b', 'Artifact', 2)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 · CMC moyen 1,5'), findsOneWidget);
    });

    testWidgets('sans CMC connu, l\'en-tête ne garde que la quantité', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb([
          dc('a', tags: ['Ramp']),
        ], db),
      );
      await tester.pumpAndSettle();

      expect(find.text('RAMP'), findsOneWidget);
      expect(find.textContaining('CMC moyen'), findsNothing);
    });

    testWidgets('une carte sans tag tombe dans Sans tag', (tester) async {
      await tester.pumpWidget(buildTabWithDb([dc('mystere')], db));
      await tester.pumpAndSettle();

      expect(find.text('SANS TAG'), findsOneWidget);
    });

    for (final grouping in DeckGrouping.values) {
      testWidgets('en mode ${grouping.name}, une section est triée par mana '
          'value puis par nom', (tester) async {
        // Noms choisis à rebours de la mana value : un tri par nom seul
        // donnerait l'ordre inverse.
        DeckCard named(String id, String name) => DeckCard(
          scryfallId: id,
          name: name,
          quantity: 1,
          tags: const ['Ramp'],
        );
        await tester.pumpWidget(
          buildTabWithDb(
            [
              named('c5', 'Aaa'),
              named('c1', 'Zzz'),
              named('c3', 'Mmm'),
              named('c3b', 'Bbb'),
            ],
            db,
            viewPrefs: DeckViewPrefs(
              grouping: grouping,
              layout: DeckLayout.list,
            ),
            fullCardData: [
              sc('c5', 'Creature — Angel', 5),
              sc('c1', 'Creature — Elf', 1),
              sc('c3', 'Creature — Bear', 3),
              sc('c3b', 'Creature — Bear', 3),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final ys = [
          'Zzz',
          'Bbb',
          'Mmm',
          'Aaa',
        ].map((n) => tester.getTopLeft(find.text(n)).dy).toList();
        expect(ys, orderedEquals([...ys]..sort()));
        expect(ys.toSet(), hasLength(4));
      });
    }

    testWidgets('sans préférence, les sections sont celles des types', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb(
          [
            dc('bears', tags: ['Ramp']),
          ],
          db,
          viewPrefs: const DeckViewPrefs(),
          fullCardData: [sc('bears', 'Creature — Bear', 2)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Créatures (1)'), findsOneWidget);
      expect(find.text('RAMP'), findsNothing);
    });

    testWidgets('en mode type, les en-têtes d\'origine reviennent', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb(
          [
            dc('bears', tags: ['Ramp']),
            dc('bolt'),
          ],
          db,
          viewPrefs: const DeckViewPrefs(grouping: DeckGrouping.type),
          fullCardData: [
            sc('bears', 'Creature — Bear', 2),
            sc('bolt', 'Instant', 1),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Créatures (1)'), findsOneWidget);
      expect(find.text('Sorts (1)'), findsOneWidget);
      expect(find.text('RAMP'), findsNothing);
    });

    testWidgets('en mode liste, des DeckCardTile et plus de grille', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb(
          [
            dc('a', tags: ['Ramp']),
          ],
          db,
          viewPrefs: const DeckViewPrefs(layout: DeckLayout.list),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeckCardTile), findsOneWidget);
      expect(find.byType(DeckCardGridTile), findsNothing);
    });

    testWidgets('sur le main, ni compte de cartes ni interrupteurs : la '
        'liste commence tout de suite', (tester) async {
      await tester.pumpWidget(
        buildTabWithDb([
          dc('a', tags: ['Ramp']),
        ], db),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('cartes'), findsNothing);
      expect(find.byType(SegmentedButton<DeckGrouping>), findsNothing);
      expect(find.byIcon(Icons.view_list), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('sur la wishlist, la ligne des achats garde ses deux boutons', (
      tester,
    ) async {
      var exported = 0;
      await tester.pumpWidget(
        buildTabWithDb(
          [
            dc('a', tags: ['Ramp']),
          ],
          db,
          currentBoard: DeckBoard.wishlist,
          onExportToGlobalWishlist: () => exported++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Export Cardmarket Mass Entry'), findsOneWidget);
      await tester.tap(find.byTooltip('Créer une Wishlist Globale (App)'));
      expect(exported, 1);
      expect(find.byType(SegmentedButton<DeckGrouping>), findsNothing);
    });

    testWidgets('sur considering, seul l\'export Cardmarket reste', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb(
          [
            dc('a', tags: ['Ramp']),
          ],
          db,
          currentBoard: DeckBoard.considering,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Export Cardmarket Mass Entry'), findsOneWidget);
      expect(find.byTooltip('Créer une Wishlist Globale (App)'), findsNothing);
    });

    testWidgets('des tags corrigés à la main ne mettent pas de cadenas', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb([
          dc('edite', tags: ['Win-con'], edited: true),
        ], db),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsNothing);
    });

    testWidgets('options : une seule entrée Tags…, qui appelle onSetTags', (
      tester,
    ) async {
      DeckCard? gotCard;
      List<String>? gotTags;
      final card = dc('harmonize', tags: ['Pioche']);
      await tester.pumpWidget(
        buildTabWithDb(
          [card],
          db,
          onSetTags: (c, tags) {
            gotCard = c;
            gotTags = tags;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(DeckCardGridTile));
      await tester.pumpAndSettle();
      expect(find.text('Catégorie…'), findsNothing);
      expect(find.text('Gérer les Tags'), findsNothing);
      expect(find.text('Déduire automatiquement'), findsNothing);
      await tester.tap(find.text('Tags…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Perso');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byIcon(Icons.add),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(gotCard, same(card));
      expect(gotTags, ['Pioche', 'Perso']);
    });

    testWidgets('options : Déduire automatiquement existe si tags édités', (
      tester,
    ) async {
      DeckCard? reset;
      final card = dc('edite', tags: ['Win-con'], edited: true);
      await tester.pumpWidget(
        buildTabWithDb([card], db, onResetTags: (c) => reset = c),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(DeckCardGridTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Déduire automatiquement'));
      await tester.pumpAndSettle();

      expect(reset, same(card));
    });
  });
}
