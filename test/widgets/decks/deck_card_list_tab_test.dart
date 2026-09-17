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
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/widgets/decks/deck_card_list_tab.dart';

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

  Widget buildTabWithDb(List<DeckCard> cardList, AppDatabase database) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        home: Scaffold(
          body: DeckCardListTab(
            cardList: cardList,
            fullCardData: const [],
            collection: const [],
            currentBoard: DeckBoard.main,
            onUpdateQuantity: (_, _) {},
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
}
