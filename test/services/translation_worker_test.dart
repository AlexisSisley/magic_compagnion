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
}
