import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/providers/preferred_language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('readPreferredLanguage', () {
    test('rend fr par defaut', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await readPreferredLanguage(), 'fr');
    });

    test('rend la langue enregistree', () async {
      SharedPreferences.setMockInitialValues({'glossaryLang': 'it'});
      expect(await readPreferredLanguage(), 'it');
    });
  });

  group('enqueueOwnedCardsForLanguage', () {
    setUp(() async {
      await db.into(db.decks).insert(DecksCompanion.insert(id: 'deck-1', name: 'Test'));
      await db.into(db.deckCards).insert(DeckCardsCompanion.insert(
            deckId: 'deck-1',
            board: 'main',
            scryfallId: 'en-id',
            name: 'Thrill of Possibility',
          ));
      await db.upsertCardPrint(_print(scryfallId: 'en-id', lang: 'en'));
    });

    test('enfile les cartes d un deck dans la nouvelle langue', () async {
      final queued = await enqueueOwnedCardsForLanguage(db: db, lang: 'fr');

      expect(queued, 1);
      final tasks = await db.nextTranslationTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.lang, 'fr');
    });

    test('n enfile pas une carte deja dans la bonne langue', () async {
      final queued = await enqueueOwnedCardsForLanguage(db: db, lang: 'en');

      expect(queued, 0);
      expect(await db.nextTranslationTasks(), isEmpty);
    });

    test('n enfile pas une traduction deja en cache', () async {
      await db.upsertCardPrint(_print(scryfallId: 'fr-id', lang: 'fr'));

      expect(await enqueueOwnedCardsForLanguage(db: db, lang: 'fr'), 0);
    });

    test('n enfile pas une absence deja connue', () async {
      await db.markTranslationAbsent('oracle-thrill', 'fr');

      expect(await enqueueOwnedCardsForLanguage(db: db, lang: 'fr'), 0);
    });

    test('ne touche a rien hors deck et collection', () async {
      // Un tirage en cache qui n'est dans aucun deck ni collection.
      await db.upsertCardPrint(
          _print(scryfallId: 'orphelin', lang: 'en', oracleId: 'oracle-autre'));

      expect(await enqueueOwnedCardsForLanguage(db: db, lang: 'fr'), 1);
    });
  });
}
