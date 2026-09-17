import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/card_detail_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/collection_service.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/local_card_service.dart';
import 'package:magic_companion/services/scan_history_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/translation_worker.dart';
import 'package:magic_companion/services/wishlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  group('parsePrintFooter', () {
    test('lit set, numero et langue sur un bas de carte francais', () {
      final parsed = parsePrintFooter('146/280 C ELD FR');

      expect(parsed, isNotNull);
      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, 'fr');
    });

    test('sans code langue, la langue est nulle', () {
      final parsed = parsePrintFooter('ELD 146');

      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, isNull);
    });

    test('ignore un code langue qui n est pas supporte par Scryfall', () {
      final parsed = parsePrintFooter('146/280 C ELD ZZ');

      expect(parsed!.lang, isNull);
    });

    test('rend null sur un texte sans motif d edition', () {
      expect(parsePrintFooter('Créature : humain et éclaireur'), isNull);
    });

    // Round de correction 1 - constat 1 : le format moderne peut avoir un
    // code d'edition alphanumerique (ne commencant pas forcement par une
    // lettre). Seule la position (juste apres la rarete) l'identifie.
    test('reconnait un set alphanumerique (Double Masters)', () {
      final parsed = parsePrintFooter('150/332 M 2XM EN');

      expect(parsed!.setCode, '2XM');
      expect(parsed.collectorNumber, '150');
      expect(parsed.lang, 'en');
    });

    test('reconnait un set alphanumerique (Double Masters 2022)', () {
      final parsed = parsePrintFooter('45/332 R 2X2 FR');

      expect(parsed!.setCode, '2X2');
      expect(parsed.collectorNumber, '45');
      expect(parsed.lang, 'fr');
    });

    test('reconnait un set alphanumerique (Universes Beyond 40K)', () {
      final parsed = parsePrintFooter('10/407 M 40K EN');

      expect(parsed!.setCode, '40K');
      expect(parsed.collectorNumber, '10');
      expect(parsed.lang, 'en');
    });

    // Round de correction 1 - constats 2 et 3 : le bas d'une carte Magic
    // est imprime en MAJUSCULES. Du texte de regles en minuscules ne doit
    // jamais etre confondu avec le motif edition/numero, ni avec un code
    // langue.
    test('ignore du texte de regles ressemblant a "set cn" (turn 2)', () {
      expect(parsePrintFooter('... until end of turn 2'), isNull);
    });

    test('ignore du texte de regles ressemblant a "set cn" (put 2)', () {
      expect(parsePrintFooter('put 2 loyalty counters'), isNull);
    });

    test('n interprete pas "It" (debut de phrase) comme la langue italienne', () {
      final parsed = parsePrintFooter(
        '146/280 C ELD It was a dark and stormy night',
      );

      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, isNull);
    });
  });

  group('isMissingTranslation', () {
    test('vrai pour un 404 Scryfall', () {
      final requestOptions = RequestOptions(path: '/cards/eld/146/fr');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 404),
        type: DioExceptionType.badResponse,
      );

      expect(isMissingTranslation(error), isTrue);
    });

    test('faux pour une autre reponse HTTP (ex. 500)', () {
      final requestOptions = RequestOptions(path: '/cards/eld/146/fr');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 500),
        type: DioExceptionType.badResponse,
      );

      expect(isMissingTranslation(error), isFalse);
    });

    test('faux pour une panne reseau sans reponse HTTP', () {
      final requestOptions = RequestOptions(path: '/cards/eld/146/fr');
      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
      );

      expect(isMissingTranslation(error), isFalse);
    });

    test('faux pour une exception qui n est pas un DioException', () {
      expect(isMissingTranslation(Exception('boom')), isFalse);
    });
  });

  // =================================================================
  // Constat 4 de la revue finale : le scan ecrit le tirage en cache.
  // =================================================================

  group('identification precise par edition (chemin du scan)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
        'une identification reussie ecrit le tirage dans card_prints : sans '
        'cela, la carte scannee reste invisible pour la projection '
        'd\'affichage et pour le backfill de langue, definitivement',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final dio = _mockDio((_) => {
            'id': 'eld-146-en',
            'oracle_id': 'oracle-thrill',
            'name': 'Thrill of Possibility',
            'set': 'eld',
            'collector_number': '146',
            'lang': 'en',
            'color_identity': ['R'],
          });
      final api = ScryfallApiService(dio: dio);
      final resolver = CardResolver(api: api, db: db);

      final controller = CardDetailController(
        deckService: DeckService(database: db),
        collectionService: CollectionService(database: db, resolver: resolver),
        historyService: ScanHistoryService(database: db),
        wishlistService: WishlistService(database: db),
        localCardService: LocalCardService(),
        apiService: api,
        cardResolver: resolver,
        translationWorker: TranslationWorker(resolver: resolver, db: db),
        params: const CardDetailParams(),
      );
      addTearDown(controller.dispose);

      expect(await db.getCardPrint('eld-146-en'), isNull);

      final ok = await controller.fetchExactCard('eld', '146');

      expect(ok, isTrue);
      final cached = await db.getCardPrint('eld-146-en');
      expect(cached, isNotNull);
      expect(cached!.oracleId, 'oracle-thrill');
      expect(cached.setCode, 'eld');
      expect(cached.collectorNumber, '146');
      expect(cached.lang, 'en');
      // Le tirage possede n'est pas reecrit par une projection : seul le
      // cache a ete touche.
      expect(cached.scryfallId, 'eld-146-en');
    });
  });
}
