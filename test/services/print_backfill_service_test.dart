// Tests du PrintBackfillService.
//
// Contrainte verrouillee par ce fichier : le backfill NE REECRIT JAMAIS le
// scryfallId d'une ligne de deck ou de collection. Il remplit uniquement le
// cache card_prints a cote. Voir lib/services/print_backfill_service.dart.
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_print.dart';
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
/// [onCall] est notifie a chaque requete HTTP (pour compter les appels).
CardResolver _stubResolver(AppDatabase db, {void Function()? onCall}) {
  final dio = _mockDio((_) {
    onCall?.call();
    return {
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
    };
  });
  return CardResolver(api: ScryfallApiService(dio: dio), db: db);
}

/// Un resolveur dont [resolveEditions] echoue toujours -- simule une panne
/// (reseau absent, etc.) survenant pendant la reprise.
class _FailingResolver extends CardResolver {
  _FailingResolver(AppDatabase db)
      : super(api: ScryfallApiService(dio: _mockDio((_) => 500)), db: db);

  @override
  Future<EditionResolution> resolveEditions(List<PrintRequest> requests) {
    throw Exception('panne simulee');
  }
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

  group('runOnce (declenchement au demarrage)', () {
    Future<void> seedOneDeckCard() async {
      await db.into(db.decks).insert(
          DecksCompanion.insert(id: 'deck-1', name: 'Test'));
      await db.into(db.deckCards).insert(DeckCardsCompanion.insert(
            deckId: 'deck-1',
            board: 'main',
            scryfallId: 'ancien-id',
            name: 'Sol Ring',
          ));
    }

    test('pose le drapeau AppSettings apres un succes', () async {
      await seedOneDeckCard();
      final service = PrintBackfillService(db: db, resolver: _stubResolver(db));

      await service.runOnce();

      expect(
        await db.getSetting(PrintBackfillService.backfillCompletedSettingKey),
        'true',
      );
      expect(await db.getCardPrint('ancien-id'), isNotNull);
    });

    test('ne s execute qu une seule fois : le drapeau pose court-circuite '
        'tout appel suivant', () async {
      await seedOneDeckCard();
      int calls = 0;
      final service =
          PrintBackfillService(db: db, resolver: _stubResolver(db, onCall: () => calls++));

      await service.runOnce();
      final callsAfterFirst = calls;
      expect(callsAfterFirst, greaterThan(0));

      await service.runOnce(); // drapeau deja pose : ne doit rien refaire

      expect(calls, callsAfterFirst);
    });

    test('un echec ne pose PAS le drapeau, pour etre retente au prochain '
        'lancement', () async {
      await seedOneDeckCard();
      final service = PrintBackfillService(db: db, resolver: _FailingResolver(db));

      await service.runOnce(); // ne doit pas lancer d'exception

      expect(
        await db.getSetting(PrintBackfillService.backfillCompletedSettingKey),
        isNull,
      );
      // Rien n'a ete mis en cache, et surtout aucune ligne de deck touchee.
      final rows = await db.select(db.deckCards).get();
      expect(rows.single.scryfallId, 'ancien-id');
    });

    test('un appel qui suit un echec retente la reprise (drapeau absent)',
        () async {
      await seedOneDeckCard();
      final failing = PrintBackfillService(db: db, resolver: _FailingResolver(db));
      await failing.runOnce();
      expect(
        await db.getSetting(PrintBackfillService.backfillCompletedSettingKey),
        isNull,
      );

      // Au "prochain lancement" (meme drapeau absent), un resolveur qui
      // fonctionne doit pouvoir aboutir.
      final retry = PrintBackfillService(db: db, resolver: _stubResolver(db));
      await retry.runOnce();

      expect(
        await db.getSetting(PrintBackfillService.backfillCompletedSettingKey),
        'true',
      );
      expect(await db.getCardPrint('ancien-id'), isNotNull);
    });
  });
}
