import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/moxfield_import.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/collection_import_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';

/// Dio mocke : [handler] rend une Map (200) ou un int (code d'erreur).
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

Map<String, dynamic> _carte({
  required String id,
  String set = 'ltc',
  String cn = '284',
  String name = 'Sol Ring',
  String lang = 'en',
}) =>
    {
      'id': id,
      'oracle_id': 'oracle-$name',
      'name': name,
      'set': set,
      'collector_number': cn,
      'lang': lang,
      'color_identity': <String>[],
    };

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  CollectionImportService _service(Dio dio) => CollectionImportService(
        db: db,
        resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      );

  test('une carte resolue entre en collection avec son tirage exact', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    final r = await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows.single.scryfallId, 'ltc-284-en');
    expect(rows.single.quantity, 2);
    expect(r.imported, 1);
    expect(r.added, 1);
    expect(r.tagged, 0);
  });

  test('reimporter le meme contenu laisse la collection identique', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
    ]);

    await _service(dio).import(parsed, preferredLang: 'fr');
    await _service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(1));
    expect(rows.single.quantity, 2, reason: 'quantite absolue, jamais additionnee');
  });

  test('la quantite du fichier remplace celle de l app', () async {
    await db.upsertCollectionCard(
        scryfallId: 'ltc-284-en', cardName: 'Sol Ring', absoluteQuantity: 9);
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows.single.quantity, 2);
  });

  test('une carte absente du fichier survit a l import', () async {
    await db.upsertCollectionCard(
        scryfallId: 'autre-id', cardName: 'Cultivate', absoluteQuantity: 4);
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows.map((r) => r.scryfallId), containsAll(['autre-id', 'ltc-284-en']));
    expect(rows.firstWhere((r) => r.scryfallId == 'autre-id').quantity, 4);
  });

  test('foil et non-foil du meme tirage sont deux lignes distinctes', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
        CollectionEntry(
            name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284', isFoil: true),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.isFoil), hasLength(1));
  });

  test('une carte introuvable est ajoutee par son nom et tagee', () async {
    final dio = _mockDio((options) {
      final ids = (options.data as Map)['identifiers'] as List;
      final parNom = ids.any((i) => (i as Map).containsKey('name'));
      return {
        'data': parNom ? [_carte(id: 'nom-seul-id', set: 'xxx', cn: '1')] : <dynamic>[],
        'not_found': parNom ? <dynamic>[] : ids,
      };
    });

    final r = await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'plst', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(1));
    expect(rows.single.tags, contains(kNeedsCheckTag));
    expect(r.tagged, 1);
    expect(r.taggedNames, contains('Sol Ring'));
  });

  test('une carte resolue exactement ne porte PAS le tag', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows.single.tags, isNot(contains(kNeedsCheckTag)));
  });

  test('un tirage hors langue preferee enfile une traduction', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en', lang: 'en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final taches = await db.nextTranslationTasks();
    expect(taches, hasLength(1));
    expect(taches.single.lang, 'fr');
  });

  test('un tirage deja dans la langue preferee n enfile rien', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-fr', lang: 'fr')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    expect(await db.nextTranslationTasks(), isEmpty);
  });

  test('les lignes illisibles sont reportees telles quelles', () async {
    final dio = _mockDio((_) => {'data': <dynamic>[], 'not_found': <dynamic>[]});

    final r = await _service(dio).import(
      const CollectionParseResult(
        entries: [],
        unreadableLines: ['beaucoup,Sol Ring'],
      ),
      preferredLang: 'fr',
    );

    expect(r.unreadableLines, ['beaucoup,Sol Ring']);
    expect(r.imported, 0);
  });

  test(
      'une ligne introuvable par edition ET par nom est comptee non identifiee, '
      'jamais perdue en silence (regle 4 : imported + notIdentified + illisibles = lignes lues)',
      () async {
    final dio = _mockDio((options) {
      final ids = (options.data as Map)['identifiers'] as List;
      final data = <Map<String, dynamic>>[];
      final notFound = <dynamic>[];
      for (final raw in ids) {
        final id = raw as Map;
        if (id['collector_number'] == '284') {
          data.add(_carte(id: 'ltc-284-en'));
        } else {
          // Ni l'edition precise de "Carte Fantome", ni son repli par nom,
          // ne trouvent de tirage : elle doit rester introuvable partout.
          notFound.add(id);
        }
      }
      return {'data': data, 'not_found': notFound};
    });

    const parsed = CollectionParseResult(
      entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
        CollectionEntry(
            name: 'Carte Fantome', quantity: 1, setCode: 'xxx', collectorNumber: '1'),
      ],
      unreadableLines: ['???,???'],
    );

    final r = await _service(dio).import(parsed, preferredLang: 'fr');

    expect(r.imported, 1);
    expect(r.notIdentified, 1);
    expect(r.notIdentifiedNames, contains('Carte Fantome'));
    expect(r.unreadableLines, ['???,???']);
    expect(
      r.imported + r.notIdentified + r.unreadableLines.length,
      parsed.linesRead,
      reason: 'aucune ligne ne doit disparaitre en silence',
    );
  });

  test(
      'deux lignes de meme nom mais d editions differentes restent deux lignes '
      'distinctes avec leurs quantites propres (pas de fusion par appariement partage)',
      () async {
    final dio = _mockDio((options) {
      final ids = (options.data as Map)['identifiers'] as List;
      final data = <Map<String, dynamic>>[];
      final notFound = <dynamic>[];
      for (final raw in ids) {
        final id = raw as Map;
        if (id['collector_number'] == '284') {
          // Edition exacte de la premiere ligne : trouvee.
          data.add(_carte(id: 'ltc-284-en'));
        } else if (id.containsKey('collector_number')) {
          // Edition exacte de la seconde ligne (m19/1) : introuvable, elle
          // devra passer par le repli sur le nom.
          notFound.add(id);
        } else {
          // Repli par nom seul : rend un tirage DIFFERENT de la premiere
          // ligne, pour prouver que la seconde ne lui est pas fusionnee.
          data.add(_carte(id: 'repli-sol-ring', set: 'm19', cn: '1'));
        }
      }
      return {'data': data, 'not_found': notFound};
    });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 3, setCode: 'ltc', collectorNumber: '284'),
        CollectionEntry(name: 'Sol Ring', quantity: 5, setCode: 'm19', collectorNumber: '1'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(2), reason: 'deux tirages distincts, jamais fusionnes');

    final exact = rows.firstWhere((r) => r.scryfallId == 'ltc-284-en');
    final replie = rows.firstWhere((r) => r.scryfallId == 'repli-sol-ring');
    expect(exact.quantity, 3);
    expect(replie.quantity, 5);
    expect(replie.tags, contains(kNeedsCheckTag));
  });

  test(
      'une entree sans edition introuvable n est pas retentee par nom '
      '(deja tentee au Temps 1, un repli redondant gaspillerait une requete)',
      () async {
    var appels = 0;
    final dio = _mockDio((options) {
      appels++;
      final ids = (options.data as Map)['identifiers'] as List;
      return {'data': <dynamic>[], 'not_found': ids};
    });

    final r = await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Carte Inconnue', quantity: 1),
      ]),
      preferredLang: 'fr',
    );

    expect(appels, 1);
    expect(r.notIdentified, 1);
  });
}
