// Tests du schema v4 : cache de tirages, absences de traduction, file de travail.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';

AppDatabase _createTestDb() => AppDatabase(NativeDatabase.memory());

DbCardPrint _print({
  required String scryfallId,
  required String lang,
  String oracleId = 'oracle-thrill',
  String? printedName,
}) {
  return DbCardPrint(
    scryfallId: scryfallId,
    oracleId: oracleId,
    setCode: 'eld',
    collectorNumber: '146',
    lang: lang,
    printedName: printedName,
    printedText: null,
    imageUri: null,
    fetchedAt: DateTime.utc(2026, 9, 17),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = _createTestDb());
  tearDown(() async => db.close());

  group('Cache de tirages', () {
    test('un tirage ecrit est relu par son scryfallId', () async {
      await db.upsertCardPrint(_print(scryfallId: 'en-id', lang: 'en'));

      final read = await db.getCardPrint('en-id');
      expect(read, isNotNull);
      expect(read!.lang, 'en');
      expect(read.oracleId, 'oracle-thrill');
    });

    test('findTranslation retrouve la version francaise par oracleId', () async {
      await db.upsertCardPrint(_print(scryfallId: 'en-id', lang: 'en'));
      await db.upsertCardPrint(
        _print(scryfallId: 'fr-id', lang: 'fr', printedName: 'Frisson de probabilité'),
      );

      final fr = await db.findTranslation('oracle-thrill', 'fr');
      expect(fr!.scryfallId, 'fr-id');
      expect(fr.printedName, 'Frisson de probabilité');
    });

    test('findTranslation rend null quand la langue est absente du cache', () async {
      await db.upsertCardPrint(_print(scryfallId: 'en-id', lang: 'en'));

      expect(await db.findTranslation('oracle-thrill', 'it'), isNull);
    });

    test('upsert deux fois le meme scryfallId ne cree pas de doublon', () async {
      await db.upsertCardPrint(_print(scryfallId: 'fr-id', lang: 'fr', printedName: 'Ancien'));
      await db.upsertCardPrint(_print(scryfallId: 'fr-id', lang: 'fr', printedName: 'Nouveau'));

      final read = await db.getCardPrint('fr-id');
      expect(read!.printedName, 'Nouveau');
    });
  });

  group('Absences de traduction', () {
    test('une absence non enregistree est fausse', () async {
      expect(await db.isTranslationAbsent('oracle-dreadbore', 'fr'), isFalse);
    });

    test('une absence enregistree est memorisee', () async {
      await db.markTranslationAbsent('oracle-dreadbore', 'fr');

      expect(await db.isTranslationAbsent('oracle-dreadbore', 'fr'), isTrue);
      expect(await db.isTranslationAbsent('oracle-dreadbore', 'de'), isFalse);
    });

    test('marquer deux fois la meme absence ne leve pas', () async {
      await db.markTranslationAbsent('oracle-dreadbore', 'fr');
      await db.markTranslationAbsent('oracle-dreadbore', 'fr');

      expect(await db.isTranslationAbsent('oracle-dreadbore', 'fr'), isTrue);
    });
  });

  group('File de traduction', () {
    test('une tache enfilee ressort de nextTranslationTasks', () async {
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      final tasks = await db.nextTranslationTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.scryfallId, 'en-id');
      expect(tasks.first.lang, 'fr');
      expect(tasks.first.attempts, 0);
    });

    test('une tache terminee quitte la file', () async {
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );
      final task = (await db.nextTranslationTasks()).first;

      await db.completeTranslationTask(task.id);

      expect(await db.nextTranslationTasks(), isEmpty);
    });

    test('une tache en echec reste en file, compte ses tentatives et recule', () async {
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );
      final task = (await db.nextTranslationTasks()).first;

      await db.failTranslationTask(task.id, 'SocketException');

      // NB: nextTranslationTasks() filtre sur nextAttemptAt <= now, et la
      // tache vient d etre reculee de 30 s : on interroge donc la table.
      final after = await db.select(db.translationTasks).get();
      expect(after, hasLength(1));
      expect(after.first.attempts, 1);
      expect(after.first.lastError, 'SocketException');
      expect(after.first.nextAttemptAt.isAfter(DateTime.now()), isTrue);
    });

    test('enfiler deux fois le meme couple ne cree pas de doublon', () async {
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      expect(await db.nextTranslationTasks(), hasLength(1));
    });
  });
}
