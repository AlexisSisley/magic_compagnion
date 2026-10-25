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
import 'package:magic_companion/models/card_category.dart';
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
    // Ces tests parlent surtout des sections par catégorie : on les pose
    // explicitement, le défaut de l'app étant le regroupement par type.
    DeckViewPrefs viewPrefs = const DeckViewPrefs(
      grouping: DeckGrouping.category,
    ),
    ValueChanged<DeckGrouping>? onGrouping,
    ValueChanged<DeckLayout>? onLayout,
    void Function(DeckCard, CardCategory)? onSetCategory,
    ValueChanged<DeckCard>? onResetCategory,
  }) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        home: Scaffold(
          body: DeckCardListTab(
            cardList: cardList,
            fullCardData: fullCardData,
            collection: const [],
            currentBoard: DeckBoard.main,
            onUpdateQuantity: (_, _) {},
            viewPrefs: viewPrefs,
            onGrouping: onGrouping ?? (_) {},
            onLayout: onLayout ?? (_) {},
            onSetCategory: onSetCategory ?? (_, _) {},
            onResetCategory: onResetCategory ?? (_) {},
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
  group('liste par catégories', () {
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
      CardCategory? category,
      bool locked = false,
      int quantity = 1,
    }) => DeckCard(
      scryfallId: id,
      name: id,
      quantity: quantity,
      category: category,
      categoryLocked: locked,
    );

    testWidgets('grille par défaut, sections dans l\'ordre de l\'enum', (
      tester,
    ) async {
      // Volontairement fournies dans le désordre : l'ordre affiché est celui
      // de la taxonomie, pas celui de la liste reçue.
      final cards = [
        dc('bears', category: CardCategory.creatures),
        dc('swords', category: CardCategory.removal),
        dc('signet', category: CardCategory.ramp),
      ];
      await tester.pumpWidget(buildTabWithDb(cards, db));
      await tester.pumpAndSettle();

      expect(find.byType(DeckCardTile), findsNothing);
      expect(find.byType(DeckCardGridTile), findsNWidgets(3));
      final ramp = tester.getTopLeft(find.text('RAMP')).dy;
      final removal = tester.getTopLeft(find.text('REMOVAL')).dy;
      final creatures = tester.getTopLeft(find.text('CRÉATURES')).dy;
      expect(ramp, lessThan(removal));
      expect(removal, lessThan(creatures));
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('l\'en-tête porte la quantité et le CMC moyen à virgule', (
      tester,
    ) async {
      final cards = [
        dc('a', category: CardCategory.ramp),
        dc('b', category: CardCategory.ramp),
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
        buildTabWithDb([dc('a', category: CardCategory.lands)], db),
      );
      await tester.pumpAndSettle();

      expect(find.text('TERRAINS'), findsOneWidget);
      expect(find.textContaining('CMC moyen'), findsNothing);
    });

    testWidgets('une carte sans catégorie tombe dans Autres', (tester) async {
      await tester.pumpWidget(buildTabWithDb([dc('mystere')], db));
      await tester.pumpAndSettle();

      expect(find.text('AUTRES'), findsOneWidget);
    });

    testWidgets('sans préférence, les sections sont celles des types', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb(
          [dc('bears', category: CardCategory.ramp)],
          db,
          viewPrefs: const DeckViewPrefs(),
          fullCardData: [sc('bears', 'Creature — Bear', 2)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Créatures (1)'), findsOneWidget);
      expect(find.text('RAMP'), findsNothing);
    });

    testWidgets('l\'interrupteur Type appelle onGrouping(type)', (
      tester,
    ) async {
      DeckGrouping? got;
      await tester.pumpWidget(
        buildTabWithDb(
          [dc('a', category: CardCategory.ramp)],
          db,
          onGrouping: (g) => got = g,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type'));
      await tester.pump();

      expect(got, DeckGrouping.type);
    });

    testWidgets('en mode type, les en-têtes d\'origine reviennent', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb(
          [dc('bears', category: CardCategory.ramp), dc('bolt')],
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

    testWidgets('l\'icône liste appelle onLayout(list)', (tester) async {
      DeckLayout? got;
      await tester.pumpWidget(
        buildTabWithDb(
          [dc('a', category: CardCategory.ramp)],
          db,
          onLayout: (l) => got = l,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pump();

      expect(got, DeckLayout.list);
    });

    testWidgets('en mode liste, des DeckCardTile et plus de grille', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb(
          [dc('a', category: CardCategory.ramp)],
          db,
          viewPrefs: const DeckViewPrefs(layout: DeckLayout.list),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeckCardTile), findsOneWidget);
      expect(find.byType(DeckCardGridTile), findsNothing);
    });

    testWidgets('les interrupteurs ont des cibles de 48 px de haut', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb([dc('a', category: CardCategory.ramp)], db),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(SegmentedButton<DeckGrouping>)).height,
        greaterThanOrEqualTo(48),
      );
      for (final icon in [Icons.grid_view, Icons.view_list]) {
        expect(
          tester.getSize(
            find.ancestor(
              of: find.byIcon(icon),
              matching: find.byType(IconButton),
            ),
          ),
          const Size(48, 48),
        );
      }
    });

    testWidgets('une carte verrouillée porte le cadenas, pas les autres', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTabWithDb([
          dc('verrou', category: CardCategory.wincon, locked: true),
          dc('libre', category: CardCategory.ramp),
        ], db),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsOneWidget);
      // Le libellé vit sur le nœud Semantics du cadenas, pas sur la tuile :
      // un lecteur d'écran l'annonce même fusionné au reste de la vignette.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Catégorie corrigée à la main',
        ),
        findsOneWidget,
      );
    });

    testWidgets('options : Catégorie… puis Pioche appelle onSetCategory', (
      tester,
    ) async {
      DeckCard? gotCard;
      CardCategory? gotCategory;
      final card = dc('harmonize', category: CardCategory.other);
      await tester.pumpWidget(
        buildTabWithDb(
          [card],
          db,
          onSetCategory: (c, cat) {
            gotCard = c;
            gotCategory = cat;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(DeckCardGridTile));
      await tester.pumpAndSettle();
      expect(find.text('Déduire automatiquement'), findsNothing);
      await tester.tap(find.text('Catégorie…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pioche'));
      await tester.pumpAndSettle();

      expect(gotCard, same(card));
      expect(gotCategory, CardCategory.draw);
    });

    testWidgets('options : Déduire automatiquement existe si verrouillée', (
      tester,
    ) async {
      DeckCard? reset;
      final card = dc('verrou', category: CardCategory.wincon, locked: true);
      await tester.pumpWidget(
        buildTabWithDb([card], db, onResetCategory: (c) => reset = c),
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
