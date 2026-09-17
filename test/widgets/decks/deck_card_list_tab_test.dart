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

DbCardPrint _print({
  required String scryfallId,
  required String lang,
  String? printedName,
  required String oracleId,
  required String oracleName,
}) =>
    DbCardPrint(
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

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'glossaryLang': 'fr'});
  });

  tearDown(() async => db.close());

  Widget buildTab(List<DeckCard> cardList) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
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

  testWidgets(
      'remplace silencieusement le nom possede par la traduction en cache, sans spinner',
      (tester) async {
    await db.upsertCardPrint(_print(
      scryfallId: 'sld-141',
      lang: 'en',
      printedName: 'Dreadbore',
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
      'garde le tirage possede et signale le repli quand aucune traduction n existe',
      (tester) async {
    await db.upsertCardPrint(_print(
      scryfallId: 'sld-141',
      lang: 'en',
      printedName: 'Dreadbore',
      oracleId: 'oracle-dreadbore',
      oracleName: 'Dreadbore',
    ));

    final cardList = [
      DeckCard(scryfallId: 'sld-141', name: 'Dreadbore', quantity: 1),
    ];

    await tester.pumpWidget(buildTab(cardList));
    await tester.pumpAndSettle();

    expect(find.text('Dreadbore'), findsOneWidget);
    expect(find.text('EN · pas de VF'), findsOneWidget);
  });
}
