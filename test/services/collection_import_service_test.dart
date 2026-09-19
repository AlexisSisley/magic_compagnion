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

/// Regle 4 de la spec : aucune ligne ne disparait en silence.
///
/// Toute ligne lue est comptee dans exactement l'un de `imported`,
/// `notIdentified`, `failedTransient` ou `unreadableLines`. Cette egalite
/// est la garantie centrale du service : elle est verifiee sur CHAQUE
/// scenario de ce fichier, jamais sur un seul.
void _verifieInvariantDeSomme(
  CollectionImportResult r,
  CollectionParseResult parsed,
) {
  expect(
    r.imported + r.notIdentified + r.failedTransient + r.unreadableLines.length,
    parsed.linesRead,
    reason: 'imported + notIdentified + failedTransient + illisibles doit '
        'valoir exactement le nombre de lignes lues',
  );
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  CollectionImportService service(Dio dio) => CollectionImportService(
        db: db,
        resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      );

  test('une carte resolue entre en collection avec son tirage exact', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows.single.scryfallId, 'ltc-284-en');
    expect(rows.single.quantity, 2);
    expect(r.imported, 1);
    expect(r.added, 1);
    expect(r.tagged, 0);
    _verifieInvariantDeSomme(r, parsed);
  });

  test('reimporter le meme contenu laisse la collection identique', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
    ]);

    final premier = await service(dio).import(parsed, preferredLang: 'fr');
    final second = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(1));
    expect(rows.single.quantity, 2, reason: 'quantite absolue, jamais additionnee');
    _verifieInvariantDeSomme(premier, parsed);
    _verifieInvariantDeSomme(second, parsed);
  });

  test('la quantite du fichier remplace celle de l app', () async {
    await db.upsertCollectionCard(
        scryfallId: 'ltc-284-en', cardName: 'Sol Ring', absoluteQuantity: 9);
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows.single.quantity, 2);
    _verifieInvariantDeSomme(r, parsed);
  });

  test('une carte absente du fichier survit a l import', () async {
    await db.upsertCollectionCard(
        scryfallId: 'autre-id', cardName: 'Cultivate', absoluteQuantity: 4);
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows.map((r) => r.scryfallId), containsAll(['autre-id', 'ltc-284-en']));
    expect(rows.firstWhere((r) => r.scryfallId == 'autre-id').quantity, 4);
    _verifieInvariantDeSomme(r, parsed);
  });

  test('foil et non-foil du meme tirage sont deux lignes distinctes', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      CollectionEntry(
          name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284', isFoil: true),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.isFoil), hasLength(1));
    _verifieInvariantDeSomme(r, parsed);
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
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'plst', collectorNumber: '284'),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(1));
    expect(rows.single.tags, contains(kNeedsCheckTag));
    expect(r.tagged, 1);
    expect(r.taggedNames, contains('Sol Ring'));
    _verifieInvariantDeSomme(r, parsed);
  });

  test('une carte resolue exactement ne porte PAS le tag', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows.single.tags, isNot(contains(kNeedsCheckTag)));
    _verifieInvariantDeSomme(r, parsed);
  });

  // =================================================================
  // Les tags sont FUSIONNES, jamais remplaces : `upsertCollectionCard`
  // ecrase les tags existants quand `newTags` est non nul, et l'import
  // passait la seule liste [kNeedsCheckTag]. Une carte deja en collection
  // avec des tags utilisateur les perdait tous -- une destruction de
  // donnees, la ou l'import promet de ne jamais rien effacer.
  // =================================================================

  test(
      'les tags utilisateur d une carte deja en collection SURVIVENT a l import '
      '(le tag systeme s ajoute, il ne remplace rien)', () async {
    await db.upsertCollectionCard(
      scryfallId: 'nom-seul-id',
      cardName: 'Sol Ring',
      absoluteQuantity: 1,
      newTags: ['à échanger', 'deck Atraxa'],
    );
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'nom-seul-id', set: 'xxx', cn: '1')],
          'not_found': <dynamic>[],
        });
    // Ligne sans edition : elle sera resolue par son nom seul, donc taguee.
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 3),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows.single.tags, contains('à échanger'),
        reason: 'un tag utilisateur ne doit JAMAIS disparaitre a l import');
    expect(rows.single.tags, contains('deck Atraxa'));
    expect(rows.single.tags, contains(kNeedsCheckTag));
    expect(rows.single.quantity, 3);
    _verifieInvariantDeSomme(r, parsed);
  });

  test(
      'le tag systeme DISPARAIT quand la carte redevient identifiable, '
      'les autres tags restent', () async {
    await db.upsertCollectionCard(
      scryfallId: 'ltc-284-en',
      cardName: 'Sol Ring',
      absoluteQuantity: 1,
      newTags: [kNeedsCheckTag, 'à échanger'],
    );
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });
    // Cette fois la ligne porte une identite complete : le tirage est resolu
    // exactement, le doute est leve, le tag systeme n'a plus lieu d'etre.
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows.single.tags, isNot(contains(kNeedsCheckTag)));
    expect(rows.single.tags, contains('à échanger'),
        reason: 'retirer le tag systeme ne doit pas emporter les autres');
    _verifieInvariantDeSomme(r, parsed);
  });

  // =================================================================
  // Deux lignes DISTINCTES peuvent retomber sur le meme tirage (meme nom en
  // mode degrade, ou meme set+numero dans deux langues -- POST
  // /cards/collection ignore la langue). La cle d'ecriture etant
  // (scryfallId, isFoil) avec une quantite ABSOLUE, la seconde ecrasait la
  // premiere : 3 + 2 devenait 2.
  // =================================================================

  test(
      'deux lignes qui retombent sur le meme tirage voient leurs quantites '
      'SOMMEES, jamais la derniere ecrasant la premiere', () async {
    final dio = _mockDio((options) {
      final ids = (options.data as Map)['identifiers'] as List;
      return {
        'data': [for (final _ in ids) _carte(id: 'ltc-284-en')],
        'not_found': <dynamic>[],
      };
    });
    // Deux lignes de meme nom, sans edition : le meme Sol Ring possede en LTC
    // et en M19, que le mode degrade ramene sur un unique tirage.
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 3),
      CollectionEntry(name: 'Sol Ring', quantity: 2),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(1), reason: 'un seul tirage, donc une seule ligne');
    expect(rows.single.quantity, 5,
        reason: '3 + 2 : la seconde ligne ne doit pas ecraser la premiere');
    expect(r.imported, 2, reason: 'les deux lignes du fichier sont comptees');
    expect(r.added, 1, reason: 'une seule ligne de collection creee');
    expect(r.updated, 0);
    _verifieInvariantDeSomme(r, parsed);
  });

  // =================================================================
  // Invariant n.1 de la spec : l'app ne contacte JAMAIS Moxfield pour la
  // collection. Aujourd'hui garanti par la seule structure des imports --
  // ce test le garde explicitement.
  // =================================================================

  test('l import de collection ne contacte JAMAIS un hote Moxfield', () async {
    final hotes = <String>[];
    final dio = _mockDio((options) {
      hotes.add(options.uri.host);
      final ids = (options.data as Map)['identifiers'] as List;
      return {
        'data': [for (final _ in ids) _carte(id: 'ltc-284-en')],
        'not_found': <dynamic>[],
      };
    });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      CollectionEntry(name: 'Cultivate', quantity: 1),
    ]);

    await service(dio).import(parsed, preferredLang: 'fr');

    expect(hotes, isNotEmpty, reason: 'le test ne prouve rien sans requete');
    for (final hote in hotes) {
      expect(hote.toLowerCase(), isNot(contains('moxfield')),
          reason: 'la collection ne passe que par Scryfall, jamais par '
              'Moxfield : hote contacte = $hote');
      expect(hote, contains('scryfall'));
    }
  });

  test('les lignes illisibles sont reportees telles quelles', () async {
    final dio = _mockDio((_) => {'data': <dynamic>[], 'not_found': <dynamic>[]});
    const parsed = CollectionParseResult(
      entries: [],
      unreadableLines: ['beaucoup,Sol Ring'],
    );

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    expect(r.unreadableLines, ['beaucoup,Sol Ring']);
    expect(r.imported, 0);
    _verifieInvariantDeSomme(r, parsed);
  });

  test(
      'une ligne introuvable par edition ET par nom est comptee non identifiee, '
      'jamais perdue en silence (regle 4 : imported + notIdentified + failedTransient '
      '+ illisibles = lignes lues)',
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
          // Un not_found propre, jamais une panne reseau -- cette ligne
          // doit rejoindre notIdentified, pas failedTransient.
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

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    expect(r.imported, 1);
    expect(r.notIdentified, 1);
    expect(r.notIdentifiedNames, contains('Carte Fantome'));
    expect(r.failedTransient, 0, reason: 'un not_found propre n est pas une panne reseau');
    expect(r.unreadableLines, ['???,???']);
    _verifieInvariantDeSomme(r, parsed);
  });

  test(
      'un echec reseau (5xx) est distingue d un not_found propre : '
      'failedTransient d un cote, notIdentified de l autre, jamais les deux confondus',
      () async {
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 1),
    ]);

    final dioEnPanne = _mockDio((_) => 500);
    final rEnPanne = await service(dioEnPanne).import(parsed, preferredLang: 'fr');
    expect(rEnPanne.failedTransient, 1);
    expect(rEnPanne.notIdentified, 0);
    expect(rEnPanne.imported, 0);
    _verifieInvariantDeSomme(rEnPanne, parsed);

    final dioIntrouvable = _mockDio((options) {
      final ids = (options.data as Map)['identifiers'] as List;
      return {'data': <dynamic>[], 'not_found': ids};
    });
    final rIntrouvable = await service(dioIntrouvable).import(parsed, preferredLang: 'fr');
    expect(rIntrouvable.notIdentified, 1);
    expect(rIntrouvable.failedTransient, 0);
    expect(rIntrouvable.imported, 0);
    _verifieInvariantDeSomme(rIntrouvable, parsed);
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

    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 3, setCode: 'ltc', collectorNumber: '284'),
      CollectionEntry(name: 'Sol Ring', quantity: 5, setCode: 'm19', collectorNumber: '1'),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(2), reason: 'deux tirages distincts, jamais fusionnes');

    final exact = rows.firstWhere((r) => r.scryfallId == 'ltc-284-en');
    final replie = rows.firstWhere((r) => r.scryfallId == 'repli-sol-ring');
    expect(exact.quantity, 3);
    expect(replie.quantity, 5);
    expect(replie.tags, contains(kNeedsCheckTag));
    _verifieInvariantDeSomme(r, parsed);
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
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Carte Inconnue', quantity: 1),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    expect(appels, 1);
    expect(r.notIdentified, 1);
    _verifieInvariantDeSomme(r, parsed);
  });

  test('un tirage hors langue preferee enfile une traduction', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en', lang: 'en')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    final taches = await db.nextTranslationTasks();
    expect(taches, hasLength(1));
    expect(taches.single.lang, 'fr');
    _verifieInvariantDeSomme(r, parsed);
  });

  test('un tirage deja dans la langue preferee n enfile rien', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-fr', lang: 'fr')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
    ]);

    final r = await service(dio).import(parsed, preferredLang: 'fr');

    expect(await db.nextTranslationTasks(), isEmpty);
    _verifieInvariantDeSomme(r, parsed);
  });
}
