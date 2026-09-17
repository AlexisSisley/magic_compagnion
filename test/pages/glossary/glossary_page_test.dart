// Round de correction 1 (Task 10) : `_toggleLanguage` declenche desormais un
// changement de langue persiste et un backfill de traduction en tache de
// fond, sans qu'aucun test ne couvre `GlossaryPage`. Ce fichier prouve trois
// choses :
//   1. la langue est bien ecrite (SharedPreferences ET son miroir en base) ;
//   2. les cartes possedees (deck/collection) sont enfilees pour la nouvelle
//      langue ;
//   3. et surtout : quand l'enfilement echoue (panne base), l'interface se
//      recharge quand meme -- c'est ce dernier point qui donne son sens au
//      try/catch defensif ajoute dans `_toggleLanguage`.
//
// Les trois scenarios vivent dans UNE seule `testWidgets` (phases separees
// par un demontage explicite de l'arbre). Constat empirique sur cette version
// de Flutter (3.35.6) : `rootBundle.loadString` (charge par cette page a
// chaque (re)montage) ne resout plus jamais son Future des le second
// `testWidgets` d'un meme fichier -- reproduit avec un StatefulWidget minimal
// n'utilisant ni Riverpod ni base de donnees, donc sans lien avec le code de
// cette tache. Rien de tel a l'interieur d'un seul test : les deux chemins
// (chargement initial francais, puis rechargement apres bascule) y
// fonctionnent, comme le prouvait deja chaque scenario execute isolement.
//
// Le `TranslationWorker` est remplace par un double qui ne fait rien : le
// drain lui-meme est deja teste et blinde ailleurs (test/services/
// translation_worker_test.dart) ; ici on ne veut ni reseau ni delai.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/pages/glossary/glossary_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/translation_worker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Double de [TranslationWorker] qui ne traite jamais la file : le drain est
/// deja couvert et blinde par ailleurs, et on ne veut ici ni reseau ni delai
/// dans un test de widget.
class _NoopTranslationWorker extends TranslationWorker {
  _NoopTranslationWorker({required super.resolver, required super.db});

  @override
  Future<int> drain({int batchSize = 50}) async => 0;
}

/// AppDatabase de test dont `getCardPrint` leve systematiquement -- simule
/// une panne base pendant l'enfilement du backfill (seul point de
/// `enqueueOwnedCardsForLanguage` qui l'appelle).
class _FailingEnqueueDb extends AppDatabase {
  _FailingEnqueueDb(super.executor);

  @override
  Future<DbCardPrint?> getCardPrint(String scryfallId) {
    throw Exception('panne simulee getCardPrint');
  }
}

DbCardPrint _print({
  required String scryfallId,
  required String lang,
  String oracleId = 'oracle-thrill',
}) =>
    DbCardPrint(
      scryfallId: scryfallId,
      oracleId: oracleId,
      setCode: 'eld',
      collectorNumber: '146',
      lang: lang,
      oracleName: 'Thrill of Possibility',
      printedName: 'Thrill of Possibility',
      printedText: null,
      imageUri: null,
      colorIdentity: '[]',
      fetchedAt: DateTime.utc(2026, 9, 17),
    );

Widget _buildPage(AppDatabase database, TranslationWorker worker) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      translationWorkerProvider.overrideWithValue(worker),
    ],
    child: const MaterialApp(home: Scaffold(body: GlossaryPage())),
  );
}

/// Monte la page (chargement initial en francais, `glossaryLang` doit deja
/// valoir `fr` dans les preferences mockees), tape le bouton de langue, puis
/// attend le rechargement.
Future<void> _toggleLanguageViaUi(
  WidgetTester tester,
  AppDatabase database,
  TranslationWorker worker,
) async {
  await tester.pumpWidget(_buildPage(database, worker));
  await tester.pumpAndSettle();

  final toggleButton = find.widgetWithText(TextButton, 'FR');
  expect(toggleButton, findsOneWidget,
      reason: 'la page doit demarrer en francais (glossaryLang=fr)');
  await tester.tap(toggleButton);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bascule de langue : ecriture, enfilement, resilience aux pannes',
      (tester) async {
    // --- Phase 1 : la langue est bien ecrite, prefs ET miroir en base. ---
    final dbWrite = AppDatabase(NativeDatabase.memory());
    addTearDown(() => dbWrite.close());
    SharedPreferences.setMockInitialValues({'glossaryLang': 'fr'});
    final workerWrite = _NoopTranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(), db: dbWrite),
      db: dbWrite,
    );

    await _toggleLanguageViaUi(tester, dbWrite, workerWrite);

    final prefsAfterWrite = await SharedPreferences.getInstance();
    expect(prefsAfterWrite.getString('glossaryLang'), 'en');
    expect(await dbWrite.getSetting('glossaryLang'), 'en');

    // Demonte l'arbre avant la phase suivante.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // --- Phase 2 : les cartes possedees sont enfilees pour la nouvelle
    // langue -- bornee au deck/collection, comme le prouve deja
    // preferred_language_provider_test.dart ; ici on prouve seulement que
    // GlossaryPage declenche bien cet enfilement. ---
    final dbEnqueue = AppDatabase(NativeDatabase.memory());
    addTearDown(() => dbEnqueue.close());
    SharedPreferences.setMockInitialValues({'glossaryLang': 'fr'});
    await dbEnqueue
        .into(dbEnqueue.decks)
        .insert(DecksCompanion.insert(id: 'deck-1', name: 'Test'));
    await dbEnqueue.into(dbEnqueue.deckCards).insert(DeckCardsCompanion.insert(
          deckId: 'deck-1',
          board: 'main',
          scryfallId: 'owned-id',
          name: 'Thrill of Possibility',
        ));
    // Le tirage possede est en francais : basculer vers l'anglais doit
    // enfiler sa traduction anglaise.
    await dbEnqueue.upsertCardPrint(_print(scryfallId: 'owned-id', lang: 'fr'));
    final workerEnqueue = _NoopTranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(), db: dbEnqueue),
      db: dbEnqueue,
    );

    await _toggleLanguageViaUi(tester, dbEnqueue, workerEnqueue);

    final tasks = await dbEnqueue.nextTranslationTasks();
    expect(tasks, hasLength(1));
    expect(tasks.first.scryfallId, 'owned-id');
    expect(tasks.first.lang, 'en');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // --- Phase 3 : une panne pendant l'enfilement ne bloque pas le
    // changement de langue -- l'interface se recharge quand meme. ---
    final dbFailing = _FailingEnqueueDb(NativeDatabase.memory());
    addTearDown(() => dbFailing.close());
    SharedPreferences.setMockInitialValues({'glossaryLang': 'fr'});
    await dbFailing
        .into(dbFailing.decks)
        .insert(DecksCompanion.insert(id: 'deck-1', name: 'Test'));
    await dbFailing.into(dbFailing.deckCards).insert(DeckCardsCompanion.insert(
          deckId: 'deck-1',
          board: 'main',
          scryfallId: 'owned-id',
          name: 'Thrill of Possibility',
        ));
    final workerFailing = _NoopTranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(), db: dbFailing),
      db: dbFailing,
    );

    await _toggleLanguageViaUi(tester, dbFailing, workerFailing);

    // La preference a bien ete ecrite (elle precede l'appel qui a echoue) :
    // une panne pendant l'enfilement ne doit pas empecher le changement de
    // langue de "prendre" et de se voir a l'ecran.
    final prefsAfterFailure = await SharedPreferences.getInstance();
    expect(prefsAfterFailure.getString('glossaryLang'), 'en');
    expect(await dbFailing.getSetting('glossaryLang'), 'en');

    // L'interface a bien rechargee en anglais malgre la panne : le bouton
    // affiche desormais EN et le champ de recherche son placeholder anglais.
    expect(find.widgetWithText(TextButton, 'EN'), findsOneWidget);
    expect(find.text('Search a keyword...'), findsOneWidget);

    // Sanity check : la panne a bien eu lieu, aucune tache n'a pu etre
    // enfilee -- on ne prouve pas un chemin qui n'aurait jamais ete
    // emprunte.
    expect(await dbFailing.nextTranslationTasks(), isEmpty);
  });
}
