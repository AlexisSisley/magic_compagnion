// Tests de DeckListController.importDeckFromMoxfieldUrl (Task 7).
//
// Deux Dio mockes distincts, comme le vrai controller : un pour
// MoxfieldDeckClient (recupere le JSON du deck), un pour ScryfallApiService
// (resout chaque scryfall_id via POST /cards/collection). Squelette de
// montage calque sur test/controllers/deck_list_controller_test.dart.

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/controllers/deck_list_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/collection_service.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/local_card_service.dart';
import 'package:magic_companion/services/moxfield_deck_client.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/translation_worker.dart';

/// Dio mocke generique : [handler] rend soit une Map (200), soit un int
/// (code d'erreur HTTP, encapsule en badResponse). Recopie du helper de
/// test/services/card_resolver_test.dart et test/controllers/deck_list_controller_test.dart.
Dio _mockDio(Object Function(RequestOptions) handler) {
  final dio = Dio();
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

/// Le deck Moxfield fixture reutilise par les tests : un mainboard (Wurmcoil
/// Engine, une seconde carte), un commandant (Toph) dans son propre board, et
/// une carte au maybeboard (Contagion Engine) qui doit atterrir dans
/// `considering`.
Map<String, dynamic> _deckJson() => {
      'name': 'Invincible toph',
      'format': 'commander',
      'boards': {
        'commanders': {
          'cards': {
            'c1': {
              'quantity': 1,
              'isFoil': false,
              'isProxy': false,
              'card': {'scryfall_id': 'toph-id', 'name': 'Toph, Metalbender'},
            },
          },
        },
        'mainboard': {
          'cards': {
            'm1': {
              'quantity': 1,
              'isFoil': false,
              'isProxy': false,
              'card': {'scryfall_id': 'wurmcoil-id', 'name': 'Wurmcoil Engine'},
            },
            'm2': {
              'quantity': 1,
              'isFoil': false,
              'isProxy': false,
              'card': {'scryfall_id': 'lattice-id', 'name': 'Trinisphere'},
            },
          },
        },
        'sideboard': {'cards': {}},
        'maybeboard': {
          'cards': {
            'mb1': {
              'quantity': 1,
              'isFoil': false,
              'isProxy': false,
              'card': {'scryfall_id': 'contagion-id', 'name': 'Contagion Engine'},
            },
          },
        },
      },
    };

/// Dio Moxfield mocke : rend le deck fixture pour n'importe quel publicId,
/// sur la route v3 des decks.
Dio _mockMoxfieldDio() => _mockDio((_) => _deckJson());

/// Dio Scryfall mocke qui echoue une carte plausible pour chaque identifiant
/// recu (tous par `id`, jamais par `name` -- voir test 2). Capture aussi les
/// identifiants envoyes dans [sentIdentifiers] pour inspection.
Dio _mockScryfallDio(List<dynamic> sentIdentifiers) {
  return _mockDio((options) {
    final body = options.data as Map;
    final identifiers = (body['identifiers'] as List).cast<Map<String, dynamic>>();
    sentIdentifiers.addAll(identifiers);
    final data = [
      for (final identifier in identifiers)
        {
          'id': identifier['id'],
          'oracle_id': 'oracle-${identifier['id']}',
          'name': identifier['id'],
          'set': 'tst',
          'collector_number': '1',
          'lang': 'en',
          'color_identity': <String>[],
        },
    ];
    return {'data': data, 'not_found': []};
  });
}

DeckListController _buildController({
  required Dio moxfieldDio,
  required Dio scryfallDio,
  required AppDatabase db,
}) {
  final resolver = CardResolver(api: ScryfallApiService(dio: scryfallDio), db: db);
  final collectionService = CollectionService(database: db, resolver: resolver);
  return DeckListController(
    deckService: DeckService(),
    localCardService: LocalCardService(),
    collectionService: collectionService,
    translationWorker: TranslationWorker(resolver: resolver, db: db),
    cardResolver: resolver,
    moxfieldClient: MoxfieldDeckClient(dio: moxfieldDio),
    db: db,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeckListController.importDeckFromMoxfieldUrl', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('un deck importe par URL porte les tirages exacts de Moxfield', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _buildController(
        moxfieldDio: _mockMoxfieldDio(),
        scryfallDio: _mockScryfallDio([]),
        db: db,
      );

      final result = await controller.importDeckFromMoxfieldUrl(
          'https://moxfield.com/decks/f-27i01CpkmBPljy89HQeA');

      expect(result.success, isTrue, reason: result.message);

      final deckService = DeckService();
      final decks = await deckService.loadDecks();
      final deck = decks.firstWhere((d) => d.name == 'Invincible toph');

      expect(deck.mainboard.map((c) => c.scryfallId),
          containsAll(['wurmcoil-id', 'lattice-id']));
      expect(deck.commanderScryfallId, 'toph-id');
      expect(deck.considering.map((c) => c.name), contains('Contagion Engine'));
    });

    test('les identifiants envoyes a Scryfall sont des scryfall_id, jamais des noms',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final sentIdentifiers = <dynamic>[];
      final controller = _buildController(
        moxfieldDio: _mockMoxfieldDio(),
        scryfallDio: _mockScryfallDio(sentIdentifiers),
        db: db,
      );

      final result = await controller
          .importDeckFromMoxfieldUrl('https://moxfield.com/decks/abc');

      expect(result.success, isTrue, reason: result.message);
      expect(sentIdentifiers, isNotEmpty);
      expect(sentIdentifiers.every((i) => (i as Map).containsKey('id')), isTrue);
      expect(sentIdentifiers.any((i) => (i as Map).containsKey('name')), isFalse);
    });

    test('une URL invalide ne declenche AUCUNE requete', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      int moxfieldAppels = 0;
      int scryfallAppels = 0;
      final moxfieldDio = _mockDio((_) {
        moxfieldAppels++;
        return _deckJson();
      });
      final scryfallDio = _mockDio((_) {
        scryfallAppels++;
        return {'data': [], 'not_found': []};
      });
      final controller = _buildController(
        moxfieldDio: moxfieldDio,
        scryfallDio: scryfallDio,
        db: db,
      );

      final result = await controller.importDeckFromMoxfieldUrl('bonjour');

      expect(result.success, isFalse);
      expect(result.message, contains('URL'));
      expect(moxfieldAppels, 0);
      expect(scryfallAppels, 0);
    });

    test('un deck prive rend un message parlant, pas une trace technique', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final moxfieldDio = _mockDio((_) => 404);
      final controller = _buildController(
        moxfieldDio: moxfieldDio,
        scryfallDio: _mockScryfallDio([]),
        db: db,
      );

      final result = await controller
          .importDeckFromMoxfieldUrl('https://moxfield.com/decks/prive');

      expect(result.success, isFalse);
      expect(result.message, contains('public'));
      expect(result.message, isNot(contains('DioException')));
    });

    // =================================================================
    // La chaine de traduction doit etre fermee (constat 1 de la relecture) :
    // CardResolver.resolveEditions (impose par la resolution par identifiant
    // exact) n'enfile rien lui-meme, a la difference de
    // CollectionService.resolveImportedEntries -- sans une boucle explicite
    // d'enfilement, `unawaited(_translationWorker.drain())` viderait une
    // file vide, et un deck importe par URL resterait dans sa langue
    // d'origine indefiniment.
    // =================================================================

    test(
        'les tirages anglais enfilent une traduction vers la langue preferee '
        '(francais par defaut)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _buildController(
        moxfieldDio: _mockMoxfieldDio(),
        // Rend des cartes 'lang': 'en' pour chaque identifiant -- voir
        // _mockScryfallDio.
        scryfallDio: _mockScryfallDio([]),
        db: db,
      );

      final result = await controller.importDeckFromMoxfieldUrl(
          'https://moxfield.com/decks/f-27i01CpkmBPljy89HQeA');

      expect(result.success, isTrue, reason: result.message);

      // Verifie IMMEDIATEMENT apres le retour de importDeckFromMoxfieldUrl,
      // avant que le drain (unawaited, donc pas encore attendu) n'ait eu la
      // moindre chance de vider la file -- le vidage reel necessite
      // plusieurs tours de boucle d'evenements (voir _waitForEmptyQueue dans
      // deck_list_controller_test.dart), jamais un seul `await`.
      final tasks = await db.nextTranslationTasks();
      expect(tasks, isNotEmpty,
          reason: 'les tirages resolus sont en anglais et la langue '
              'preferee par defaut est le francais : sans enfilement, ce '
              'deck resterait en anglais indefiniment');
      expect(tasks.every((t) => t.lang == 'fr'), isTrue);
    });

    test('un tirage deja dans la langue preferee n\'enfile aucune traduction',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final scryfallDio = _mockDio((options) {
        final body = options.data as Map;
        final identifiers =
            (body['identifiers'] as List).cast<Map<String, dynamic>>();
        final data = [
          for (final identifier in identifiers)
            {
              'id': identifier['id'],
              'oracle_id': 'oracle-${identifier['id']}',
              'name': identifier['id'],
              'set': 'tst',
              'collector_number': '1',
              // Deja dans la langue preferee par defaut (francais) : aucune
              // traduction ne doit etre enfilee pour ce tirage.
              'lang': 'fr',
              'color_identity': <String>[],
            },
        ];
        return {'data': data, 'not_found': []};
      });
      final controller = _buildController(
        moxfieldDio: _mockMoxfieldDio(),
        scryfallDio: scryfallDio,
        db: db,
      );

      final result = await controller.importDeckFromMoxfieldUrl(
          'https://moxfield.com/decks/f-27i01CpkmBPljy89HQeA');

      expect(result.success, isTrue, reason: result.message);
      expect(await db.nextTranslationTasks(), isEmpty);
    });

    // =================================================================
    // Le commandant doit figurer dans le mainboard (constat 2 de la
    // relecture) : Moxfield le decrit dans un board "commanders" distinct du
    // "mainboard" -- _deckJson() ne place 'toph-id' que dans "commanders".
    // =================================================================

    test(
        'le commandant absent du mainboard Moxfield rejoint le mainboard '
        'avec quantite 1', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _buildController(
        moxfieldDio: _mockMoxfieldDio(),
        scryfallDio: _mockScryfallDio([]),
        db: db,
      );

      final result = await controller.importDeckFromMoxfieldUrl(
          'https://moxfield.com/decks/f-27i01CpkmBPljy89HQeA');

      expect(result.success, isTrue, reason: result.message);

      final deckService = DeckService();
      final decks = await deckService.loadDecks();
      final deck = decks.firstWhere((d) => d.name == 'Invincible toph');

      final commanderCard =
          deck.mainboard.firstWhere((c) => c.scryfallId == 'toph-id');
      expect(commanderCard.quantity, 1);
    });

    // =================================================================
    // `commanderIds` etait calcule en excluant TOUS les boards : un
    // commandant present au sideboard (ou en considering) mais absent du
    // mainboard n'y etait donc jamais ajoute. La garde anti-duplication doit
    // porter sur le seul mainboard.
    // =================================================================

    test(
        'un commandant present au SIDEBOARD mais absent du mainboard rejoint '
        'quand meme le mainboard', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final json = _deckJson();
      // Toph est desormais aussi listee au sideboard : sans correctif, son id
      // figure dans `lineIds` et elle est ecartee de `commanderIds`.
      (json['boards'] as Map)['sideboard'] = {
        'cards': {
          's1': {
            'quantity': 1,
            'isFoil': false,
            'isProxy': false,
            'card': {'scryfall_id': 'toph-id', 'name': 'Toph, Metalbender'},
          },
        },
      };
      final controller = _buildController(
        moxfieldDio: _mockDio((_) => json),
        scryfallDio: _mockScryfallDio([]),
        db: db,
      );

      final result = await controller.importDeckFromMoxfieldUrl(
          'https://moxfield.com/decks/f-27i01CpkmBPljy89HQeA');

      expect(result.success, isTrue, reason: result.message);

      final decks = await DeckService().loadDecks();
      final deck = decks.firstWhere((d) => d.name == 'Invincible toph');

      expect(deck.mainboard.where((c) => c.scryfallId == 'toph-id'), hasLength(1),
          reason: 'le commandant doit etre au mainboard, une seule fois');
      expect(deck.sideboard.map((c) => c.scryfallId), contains('toph-id'),
          reason: 'le sideboard de Moxfield est rendu tel quel');
    });

    // =================================================================
    // Le deck a remplir etait retrouve par son NOM, et `getAllDecksRaw` ne
    // trie pas : `firstWhere` rendait le plus ancien deck de ce nom, dont
    // `updateDeck` vide les cartes avant de les reinserer. Importer deux fois
    // le meme deck Moxfield (ou un deck homonyme d'un deck local) detruisait
    // le deck existant -- et le nom vient de Moxfield, l'utilisateur ne le
    // choisit ni ne le voit avant.
    // =================================================================

    test(
        'importer DEUX FOIS le meme deck par URL ne detruit pas le premier '
        '(le deck est retrouve par son identifiant, jamais par son nom)',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _buildController(
        moxfieldDio: _mockMoxfieldDio(),
        scryfallDio: _mockScryfallDio([]),
        db: db,
      );

      const url = 'https://moxfield.com/decks/f-27i01CpkmBPljy89HQeA';
      expect((await controller.importDeckFromMoxfieldUrl(url)).success, isTrue);
      expect((await controller.importDeckFromMoxfieldUrl(url)).success, isTrue);

      final decks = await DeckService().loadDecks();
      final homonymes =
          decks.where((d) => d.name == 'Invincible toph').toList();

      expect(homonymes, hasLength(2),
          reason: 'deux imports, deux decks : rien n a ete efface');
      for (final deck in homonymes) {
        expect(deck.mainboard, isNotEmpty,
            reason: 'aucun des deux decks ne doit avoir ete vide par le second '
                'import (clearDeckCards puis reinsertion dans le mauvais deck)');
        expect(deck.mainboard.map((c) => c.scryfallId),
            containsAll(['wurmcoil-id', 'lattice-id']));
      }
    });
  });
}
