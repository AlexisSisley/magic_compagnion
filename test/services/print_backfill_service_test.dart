// Tests du PrintBackfillService.
//
// Contrainte verrouillee par ce fichier : le backfill NE REECRIT JAMAIS le
// scryfallId d'une ligne de deck ou de collection. Il remplit uniquement le
// cache card_prints a cote. Voir lib/services/print_backfill_service.dart.
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/print_backfill_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';

/// Dio mocke : [handler] rend soit une Map (200), soit un int (code d'erreur
/// HTTP, encapsule en badResponse), soit un DioException tout construit
/// (pour simuler un timeout ou tout autre type d'echec sans reponse HTTP).
/// Recopie de test/services/card_resolver_test.dart (helper non partage).
Dio _mockDio(Object Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: ScryfallApiService.baseUrl));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, h) {
    final result = handler(options);
    if (result is DioException) {
      h.reject(result);
      return;
    }
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

/// Un resolveur qui rend toujours le meme tirage (Sol Ring, ancien-id).
CardResolver _stubResolver(AppDatabase db) {
  final dio = _mockDio((_) => {
        'data': [
          {
            'id': 'ancien-id',
            'oracle_id': 'oracle-sol-ring',
            'name': 'Sol Ring',
            'set': 'ltc',
            'collector_number': '284',
            'lang': 'en',
          }
        ],
        'not_found': [],
      });
  return CardResolver(api: ScryfallApiService(dio: dio), db: db);
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('Reprise de l existant', () {
    test('le backfill met les tirages en cache sans toucher aux scryfallId',
        () async {
      await db.into(db.decks).insert(
          DecksCompanion.insert(id: 'deck-1', name: 'Test'));
      await db.into(db.deckCards).insert(DeckCardsCompanion.insert(
            deckId: 'deck-1',
            board: 'main',
            scryfallId: 'ancien-id',
            name: 'Sol Ring',
          ));

      final avant = await db.select(db.deckCards).get();
      expect(avant.single.scryfallId, 'ancien-id');

      // Un resolveur qui rend toujours le meme tirage.
      final service = PrintBackfillService(db: db, resolver: _stubResolver(db));
      final resolved = await service.run();

      final apres = await db.select(db.deckCards).get();
      expect(apres.single.scryfallId, 'ancien-id'); // jamais reecrit
      expect(resolved, 1);
      expect(await db.getCardPrint('ancien-id'), isNotNull);
    });

    test('un tirage deja en cache n est pas recompte', () async {
      await db.into(db.decks).insert(
          DecksCompanion.insert(id: 'deck-1', name: 'Test'));
      await db.into(db.deckCards).insert(DeckCardsCompanion.insert(
            deckId: 'deck-1',
            board: 'main',
            scryfallId: 'ancien-id',
            name: 'Sol Ring',
          ));

      final service = PrintBackfillService(db: db, resolver: _stubResolver(db));
      final first = await service.run();
      expect(first, 1);

      final second = await service.run();
      expect(second, 0); // deja en cache, rien de nouveau a resoudre
    });

    test('couvre aussi les cartes de collection, sans y toucher', () async {
      await db.into(db.collectionCards).insert(CollectionCardsCompanion.insert(
            scryfallId: 'ancien-id',
            name: 'Sol Ring',
          ));

      final service = PrintBackfillService(db: db, resolver: _stubResolver(db));
      final resolved = await service.run();

      final apres = await db.select(db.collectionCards).get();
      expect(apres.single.scryfallId, 'ancien-id');
      expect(resolved, 1);
      expect(await db.getCardPrint('ancien-id'), isNotNull);
    });
  });
}
