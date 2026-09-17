import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/translation_worker.dart';

const _oracleId = '1cb0610b-a731-42c2-b93f-0a29f63cebf4';
const _enId = 'c9021f85-7ab4-4a78-a398-1611fe09cd14';

Dio _mockDio(Object Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: ScryfallApiService.baseUrl));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, h) {
    final result = handler(options);
    if (result is int) {
      h.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: result),
        type: DioExceptionType.badResponse,
      ));
      return;
    }
    h.resolve(Response(requestOptions: options, statusCode: 200, data: result));
  }));
  return dio;
}

/// Double pour prouver qu'une panne base isolee a une tache n'empeche pas
/// le traitement des taches suivantes de la meme passe : [getCardPrint]
/// leve pour [_failingScryfallId] et delegue normalement pour le reste.
class _FlakyCardPrintDb extends AppDatabase {
  final String _failingScryfallId;

  _FlakyCardPrintDb(super.executor, this._failingScryfallId);

  @override
  Future<DbCardPrint?> getCardPrint(String scryfallId) {
    if (scryfallId == _failingScryfallId) {
      throw Exception('panne simulee getCardPrint');
    }
    return super.getCardPrint(scryfallId);
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Le tirage possede doit etre en cache : le worker y lit l'oracleId.
    await db.upsertCardPrint(DbCardPrint(
      scryfallId: _enId,
      oracleId: _oracleId,
      setCode: 'eld',
      collectorNumber: '146',
      lang: 'en',
      oracleName: 'Thrill of Possibility',
      printedName: null,
      printedText: null,
      imageUri: null,
      colorIdentity: '[]',
      fetchedAt: DateTime.utc(2026, 9, 17),
    ));
  });

  tearDown(() async => db.close());

  test('le worker vide la file et met la traduction en cache', () async {
    final dio = _mockDio((_) => {
          'id': 'fr-id',
          'oracle_id': _oracleId,
          'name': 'Thrill of Possibility',
          'printed_name': 'Frisson de probabilité',
          'set': 'eld',
          'collector_number': '146',
          'lang': 'fr',
        });
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      db: db,
    );
    await db.enqueueTranslation(
      scryfallId: _enId, setCode: 'eld', collectorNumber: '146', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 1);
    expect(await db.nextTranslationTasks(), isEmpty);
    final fr = await db.findTranslation(_oracleId, 'fr');
    expect(fr!.printedName, 'Frisson de probabilité');
  });

  test('un 404 retire la tache de la file sans la rejouer', () async {
    final dio = _mockDio((_) => 404);
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      db: db,
    );
    await db.enqueueTranslation(
      scryfallId: _enId, setCode: 'eld', collectorNumber: '146', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 1);
    expect(await db.select(db.translationTasks).get(), isEmpty);
    expect(await db.isTranslationAbsent(_oracleId, 'fr'), isTrue);
  });

  test('une panne reseau laisse la tache en file avec un backoff', () async {
    final dio = _mockDio((_) => 503);
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      db: db,
    );
    await db.enqueueTranslation(
      scryfallId: _enId, setCode: 'eld', collectorNumber: '146', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 0);
    final remaining = await db.select(db.translationTasks).get();
    expect(remaining, hasLength(1));
    expect(remaining.first.attempts, 1);
    expect(remaining.first.nextAttemptAt.isAfter(DateTime.now()), isTrue);
  });

  test('une tache dont le tirage possede est inconnu est abandonnee', () async {
    final dio = _mockDio((_) => {'id': 'x', 'oracle_id': 'y', 'lang': 'fr'});
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      db: db,
    );
    await db.enqueueTranslation(
      scryfallId: 'inconnu', setCode: 'xxx', collectorNumber: '1', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 1);
    expect(await db.select(db.translationTasks).get(), isEmpty);
  });

  test('une panne de lecture de la file fait rendre 0 sans lever', () async {
    final brokenDb = AppDatabase(NativeDatabase.memory());
    await brokenDb.close();
    final dio = _mockDio((_) => 503);
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: brokenDb),
      db: brokenDb,
    );

    final done = await worker.drain();

    expect(done, 0);
  });

  test('une panne sur une tache n empeche pas le traitement des autres',
      () async {
    final flakyDb = _FlakyCardPrintDb(NativeDatabase.memory(), 'panne-id');
    await flakyDb.upsertCardPrint(DbCardPrint(
      scryfallId: _enId,
      oracleId: _oracleId,
      setCode: 'eld',
      collectorNumber: '146',
      lang: 'en',
      oracleName: 'Thrill of Possibility',
      printedName: null,
      printedText: null,
      imageUri: null,
      colorIdentity: '[]',
      fetchedAt: DateTime.utc(2026, 9, 17),
    ));
    final dio = _mockDio((_) => {
          'id': 'fr-id',
          'oracle_id': _oracleId,
          'name': 'Thrill of Possibility',
          'printed_name': 'Frisson de probabilité',
          'set': 'eld',
          'collector_number': '146',
          'lang': 'fr',
        });
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: flakyDb),
      db: flakyDb,
    );
    // Enfilee en premier : sa lecture de tirage possede va lever.
    await flakyDb.enqueueTranslation(
      scryfallId: 'panne-id', setCode: 'xxx', collectorNumber: '1', lang: 'fr',
    );
    // Enfilee ensuite : doit quand meme etre traitee malgre la panne precedente.
    await flakyDb.enqueueTranslation(
      scryfallId: _enId, setCode: 'eld', collectorNumber: '146', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 1);
    final remaining = await flakyDb.select(flakyDb.translationTasks).get();
    expect(remaining, hasLength(1));
    expect(remaining.first.scryfallId, 'panne-id');
    // Et elle est REPOUSSEE, pas laissee prete : sans backoff ici, la boucle
    // de drain la relirait a chaque passe et tournerait a vide sans fin.
    expect(remaining.first.attempts, 1);
    expect(remaining.first.nextAttemptAt.isAfter(DateTime.now()), isTrue);

    await flakyDb.close();
  });

  // =================================================================
  // Constat 2 de la revue finale : le drain boucle jusqu'a vider la file,
  // et ne peut pas devenir une boucle serree.
  // =================================================================

  test(
      'le drain vide une file de plus de 50 taches en un seul appel, pas 50 '
      'a la fois', () async {
    // Une passe est plafonnee a 50. Sans boucle, une collection de 3000
    // cartes aurait demande 60 bascules de langue manuelles pour converger.
    // Taches orphelines (tirage possede absent du cache) : elles se cloturent
    // sans aucune requete reseau, ce qui isole la boucle de tout autre effet.
    const taskCount = 130;
    final dio = _mockDio((_) => {'id': 'x', 'oracle_id': 'y', 'lang': 'fr'});
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      db: db,
    );
    for (var i = 0; i < taskCount; i++) {
      await db.enqueueTranslation(
        scryfallId: 'inconnu-$i',
        setCode: 'xxx',
        collectorNumber: '$i',
        lang: 'fr',
      );
    }

    final done = await worker.drain();

    expect(done, taskCount);
    expect(await db.select(db.translationTasks).get(), isEmpty);
  });

  test(
      'une panne de lecture du tirage possede repousse la tache : le drain se '
      'termine au lieu de boucler sur elle', () async {
    // Le piege de la boucle : avant ce lot, cette panne laissait la tache en
    // file SANS backoff. Acceptable tant que le drain etait declenche par
    // evenement ; boucle serree des qu'il boucle. Le test se termine (donc ne
    // boucle pas) ET verifie que la tache a bien ete repoussee.
    final flakyDb = _FlakyCardPrintDb(NativeDatabase.memory(), 'panne-id');
    final dio = _mockDio((_) => {'id': 'x', 'oracle_id': 'y', 'lang': 'fr'});
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: flakyDb),
      db: flakyDb,
    );
    await flakyDb.enqueueTranslation(
      scryfallId: 'panne-id', setCode: 'xxx', collectorNumber: '1', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 0);
    final remaining = await flakyDb.select(flakyDb.translationTasks).get();
    expect(remaining, hasLength(1));
    expect(remaining.first.attempts, 1);
    expect(remaining.first.nextAttemptAt.isAfter(DateTime.now()), isTrue);

    await flakyDb.close();
  }, timeout: const Timeout(Duration(seconds: 15)));
}
