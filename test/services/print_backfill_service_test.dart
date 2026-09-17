// Tests du PrintBackfillService.
//
// Contrainte verrouillee par ce fichier : le backfill NE REECRIT JAMAIS le
// scryfallId (ni aucun autre champ) d'une ligne de deck ou de collection. Il
// remplit uniquement le cache card_prints a cote.
// Voir lib/services/print_backfill_service.dart.
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

/// Un VRAI CardResolver qui rend toujours le meme tirage (Sol Ring,
/// ancien-id). [onCall] est notifie a chaque requete HTTP (pour compter les
/// appels).
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

/// Un VRAI CardResolver dont le lot echoue en 500 -- panne reseau/serveur
/// realiste. CardResolver.resolveEditions ne leve JAMAIS dans ce cas : la
/// requete atterit dans EditionResolution.failed. C'est le chemin reel
/// qu'une sous-classe qui leve ne peut pas exercer.
CardResolver _serverErrorResolver(AppDatabase db) {
  final dio = _mockDio((_) => 500);
  return CardResolver(api: ScryfallApiService(dio: dio), db: db);
}

/// Un VRAI CardResolver que Scryfall declare "introuvable" pour toute
/// requete -- lui non plus ne leve jamais : la requete atterit dans
/// EditionResolution.notFound. [onCall] est notifie a chaque requete HTTP.
CardResolver _notFoundResolver(AppDatabase db, {void Function()? onCall}) {
  final dio = _mockDio((_) {
    onCall?.call();
    return {
      'data': [],
      'not_found': [
        {'id': 'ancien-id'}
      ],
    };
  });
  return CardResolver(api: ScryfallApiService(dio: dio), db: db);
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> seedOneDeckCard(AppDatabase database) async {
    await database.into(database.decks).insert(
        DecksCompanion.insert(id: 'deck-1', name: 'Test'));
    await database.into(database.deckCards).insert(DeckCardsCompanion.insert(
          deckId: 'deck-1',
          board: 'main',
          scryfallId: 'ancien-id',
          name: 'Sol Ring',
        ));
  }

  group('Reprise de l existant', () {
    test(
        'le backfill met les tirages en cache sans toucher a la ligne de '
        'deck (scryfallId ET nom inchanges)', () async {
      await seedOneDeckCard(db);

      final avant = await db.select(db.deckCards).get();
      expect(avant.single.scryfallId, 'ancien-id');
      expect(avant.single.name, 'Sol Ring');

      // Un resolveur qui rend toujours le meme tirage.
      final service = PrintBackfillService(db: db, resolver: _stubResolver(db));
      final resolved = await service.run();

      final apres = await db.select(db.deckCards).get();
      // Pas seulement scryfallId : un autre champ (name) est verifie aussi,
      // pour distinguer "jamais touche" de "reecrit avec la meme valeur"
      // (une regression qui recopierait la ligne entiere se verrait ici).
      expect(apres.single.scryfallId, 'ancien-id');
      expect(apres.single.name, 'Sol Ring');
      expect(resolved, 1);
      expect(await db.getCardPrint('ancien-id'), isNotNull);
    });

    test('un tirage deja en cache n est pas recompte', () async {
      await seedOneDeckCard(db);

      final service = PrintBackfillService(db: db, resolver: _stubResolver(db));
      final first = await service.run();
      expect(first, 1);

      final second = await service.run();
      expect(second, 0); // deja en cache, rien de nouveau a resoudre
    });

    test(
        'couvre aussi les cartes de collection, sans y toucher (scryfallId '
        'ET nom inchanges)', () async {
      await db.into(db.collectionCards).insert(CollectionCardsCompanion.insert(
            scryfallId: 'ancien-id',
            name: 'Sol Ring',
          ));

      final service = PrintBackfillService(db: db, resolver: _stubResolver(db));
      final resolved = await service.run();

      final apres = await db.select(db.collectionCards).get();
      expect(apres.single.scryfallId, 'ancien-id');
      expect(apres.single.name, 'Sol Ring');
      expect(resolved, 1);
      expect(await db.getCardPrint('ancien-id'), isNotNull);
    });
  });

  group('runOnce (declenchement au demarrage)', () {
    test('pose le drapeau AppSettings quand la resolution est complete',
        () async {
      await seedOneDeckCard(db);
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
      await seedOneDeckCard(db);
      int calls = 0;
      final service =
          PrintBackfillService(db: db, resolver: _stubResolver(db, onCall: () => calls++));

      await service.runOnce();
      final callsAfterFirst = calls;
      expect(callsAfterFirst, greaterThan(0));

      await service.runOnce(); // drapeau deja pose : ne doit rien refaire

      expect(calls, callsAfterFirst);
    });

    test(
        'un lot en echec (500, VRAI CardResolver) ne pose PAS le drapeau -- '
        'resolveEditions ne leve jamais, runOnce doit donc inspecter le '
        'resultat plutot que se fier a l absence d exception', () async {
      await seedOneDeckCard(db);
      final service =
          PrintBackfillService(db: db, resolver: _serverErrorResolver(db));

      await service.runOnce(); // ne doit pas lancer d'exception

      expect(
        await db.getSetting(PrintBackfillService.backfillCompletedSettingKey),
        isNull,
      );
      // Rien n'a ete mis en cache, et surtout aucune ligne de deck touchee.
      final rows = await db.select(db.deckCards).get();
      expect(rows.single.scryfallId, 'ancien-id');
      expect(rows.single.name, 'Sol Ring');
      expect(await db.getCardPrint('ancien-id'), isNull);
    });

    test(
        'une carte declaree DEFINITIVEMENT introuvable (VRAI CardResolver) '
        'pose quand meme le drapeau -- notFound n est pas failed, retenter '
        'ne changerait rien et empecherait toute convergence', () async {
      await seedOneDeckCard(db);
      int calls = 0;
      final service = PrintBackfillService(
          db: db, resolver: _notFoundResolver(db, onCall: () => calls++));

      await service.runOnce();

      expect(
        await db.getSetting(PrintBackfillService.backfillCompletedSettingKey),
        'true',
      );

      // Prochain "lancement" : le drapeau etant pose, aucun nouvel appel
      // HTTP ne doit avoir lieu -- la reprise ne doit PAS se relancer
      // indefiniment pour une carte que Scryfall ne connait pas.
      final callsAfterFirst = calls;
      await service.runOnce();
      expect(calls, callsAfterFirst);
    });

    test(
        'un appel qui suit un lot en echec retente REELLEMENT la reprise '
        '(drapeau absent, nouvel appel HTTP, tirage effectivement mis en '
        'cache)', () async {
      await seedOneDeckCard(db);
      final failing =
          PrintBackfillService(db: db, resolver: _serverErrorResolver(db));
      await failing.runOnce();
      expect(
        await db.getSetting(PrintBackfillService.backfillCompletedSettingKey),
        isNull,
      );
      expect(await db.getCardPrint('ancien-id'), isNull);

      // Au "prochain lancement" (meme drapeau absent), un resolveur qui
      // fonctionne doit pouvoir aboutir.
      int calls = 0;
      final retry = PrintBackfillService(
          db: db, resolver: _stubResolver(db, onCall: () => calls++));
      await retry.runOnce();

      expect(calls, greaterThan(0)); // une vraie requete a bien ete refaite
      expect(
        await db.getSetting(PrintBackfillService.backfillCompletedSettingKey),
        'true',
      );
      expect(await db.getCardPrint('ancien-id'), isNotNull);
    });

    test(
        'une panne pendant la lecture du drapeau lui-meme (base fermee) ne '
        's echappe pas de runOnce', () async {
      final localDb = AppDatabase(NativeDatabase.memory());
      await seedOneDeckCard(localDb);
      final service =
          PrintBackfillService(db: localDb, resolver: _stubResolver(localDb));

      await localDb.close(); // la base n'est plus utilisable

      // runOnce lit le drapeau AVANT toute autre chose : cet appel doit
      // echouer en interne, etre attrape, et ne jamais faire rejeter le
      // Future -- sans quoi un `unawaited(...)` au demarrage (main.dart)
      // produirait un rejet de Future non gere.
      await expectLater(service.runOnce(), completes);
    });
  });
}
