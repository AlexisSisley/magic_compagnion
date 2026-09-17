// Tests du CardResolver. Fixtures calquees sur les reponses reelles de
// Scryfall pour eld/146, relevees le 2026-09-17.
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_print.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';

const _oracleId = '1cb0610b-a731-42c2-b93f-0a29f63cebf4';
const _enId = 'c9021f85-7ab4-4a78-a398-1611fe09cd14';
const _frId = '87027e87-e62d-42d6-9a79-c3e18394223d';

Map<String, dynamic> _enCard() => {
      'id': _enId,
      'oracle_id': _oracleId,
      'name': 'Thrill of Possibility',
      'set': 'eld',
      'collector_number': '146',
      'lang': 'en',
    };

Map<String, dynamic> _frCard() => {
      'id': _frId,
      'oracle_id': _oracleId,
      'name': 'Thrill of Possibility',
      'printed_name': 'Frisson de probabilité',
      'printed_text': 'Piochez deux cartes.',
      'set': 'eld',
      'collector_number': '146',
      'lang': 'fr',
    };

/// Dio mocke : [handler] rend soit une Map (200), soit un int (code d'erreur).
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

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('resolveEditions', () {
    test('resout un set et un numero vers le tirage exact', () async {
      final dio = _mockDio((_) => {'data': [_enCard()], 'not_found': []});
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      final results = await resolver.resolveEditions([
        const PrintRequest(name: 'Thrill of Possibility', setCode: 'eld', collectorNumber: '146'),
      ]);

      expect(results, hasLength(1));
      expect(results.first.scryfallId, _enId);
      expect(results.first.oracleId, _oracleId);
      expect(results.first.setCode, 'eld');
    });

    test('met le tirage resolu en cache', () async {
      final dio = _mockDio((_) => {'data': [_enCard()], 'not_found': []});
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      await resolver.resolveEditions([
        const PrintRequest(name: 'Thrill of Possibility', setCode: 'eld', collectorNumber: '146'),
      ]);

      final cached = await db.getCardPrint(_enId);
      expect(cached, isNotNull);
      expect(cached!.oracleId, _oracleId);
    });

    test('une carte deja en cache ne declenche aucune requete', () async {
      int calls = 0;
      final dio = _mockDio((_) {
        calls++;
        return {'data': [_enCard()], 'not_found': []};
      });
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);
      const request =
          PrintRequest(name: 'Thrill of Possibility', scryfallId: _enId);

      await resolver.resolveEditions([request]); // remplit le cache
      final callsAfterFirst = calls;
      await resolver.resolveEditions([request]);

      expect(calls, callsAfterFirst);
    });
  });

  group('resolveTranslation', () {
    test('rend la version francaise avec son nom imprime', () async {
      final dio = _mockDio((options) =>
          options.path.endsWith('/fr') ? _frCard() : _enCard());
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      final fr = await resolver.resolveTranslation(
        scryfallId: _enId, oracleId: _oracleId,
        setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      expect(fr, isNotNull);
      expect(fr!.scryfallId, _frId);
      expect(fr.printedName, 'Frisson de probabilité');
      expect(fr.lang, 'fr');
    });

    test('un 404 rend null et memorise l absence', () async {
      final dio = _mockDio((_) => 404);
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      final fr = await resolver.resolveTranslation(
        scryfallId: 'sld-en', oracleId: 'oracle-dreadbore',
        setCode: 'sld', collectorNumber: '141', lang: 'fr',
      );

      expect(fr, isNull);
      expect(await db.isTranslationAbsent('oracle-dreadbore', 'fr'), isTrue);
    });

    test('une absence memorisee ne redeclenche aucune requete', () async {
      int calls = 0;
      final dio = _mockDio((_) {
        calls++;
        return 404;
      });
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      await resolver.resolveTranslation(
        scryfallId: 'sld-en', oracleId: 'oracle-dreadbore',
        setCode: 'sld', collectorNumber: '141', lang: 'fr',
      );
      await resolver.resolveTranslation(
        scryfallId: 'sld-en', oracleId: 'oracle-dreadbore',
        setCode: 'sld', collectorNumber: '141', lang: 'fr',
      );

      expect(calls, 1);
    });

    test('une traduction en cache ne redeclenche aucune requete', () async {
      int calls = 0;
      final dio = _mockDio((options) {
        calls++;
        return options.path.endsWith('/fr') ? _frCard() : _enCard();
      });
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      await resolver.resolveTranslation(
        scryfallId: _enId, oracleId: _oracleId,
        setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );
      final callsAfterFirst = calls;
      await resolver.resolveTranslation(
        scryfallId: _enId, oracleId: _oracleId,
        setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      expect(calls, callsAfterFirst);
    });

    test('la traduction n ecrase pas le tirage possede', () async {
      final dio = _mockDio((options) =>
          options.path.endsWith('/fr') ? _frCard() : _enCard());
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      await resolver.resolveEditions([
        const PrintRequest(name: 'Thrill of Possibility', setCode: 'eld', collectorNumber: '146'),
      ]);
      await resolver.resolveTranslation(
        scryfallId: _enId, oracleId: _oracleId,
        setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      final owned = await db.getCardPrint(_enId);
      expect(owned!.lang, 'en');
      expect(owned.scryfallId, _enId);
    });
  });
}
