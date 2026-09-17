// Tests unitaires pour DeckListController (Sprint 10, Phase 2)
// Teste la logique d'etat, les helpers et le parsing d'import.

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/controllers/deck_list_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/collection_service.dart';
import 'package:magic_companion/services/deck_format_service.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/local_card_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';

/// Dio mocke : [handler] rend soit une Map (200), soit un int (code d'erreur
/// HTTP), soit un DioException tout construit. Recopie de
/// test/services/card_resolver_test.dart (pas de helper Dio partage).
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

/// Construit un DeckListController branche sur un CollectionService reel
/// (CardResolver + AppDatabase en memoire), Dio mocke, DeckService en repli
/// SharedPreferences -- meme pattern que les autres controllers testes ici
/// (ex. deck_suggestions_controller_test.dart pour LocalCardService()).
DeckListController _createImportController({
  required Dio dio,
  required AppDatabase db,
}) {
  final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);
  final collectionService = CollectionService(database: db, resolver: resolver);
  return DeckListController(
    deckService: DeckService(),
    localCardService: LocalCardService(),
    collectionService: collectionService,
  );
}

void main() {
  // Requis par LocalCardService.loadLocalData() (rootBundle) : importDeck()
  // charge les donnees locales via le controller dans les tests plus bas.
  TestWidgetsFlutterBinding.ensureInitialized();

  // =================================================================
  // DeckListState - Tests unitaires purs sur l'etat immutable
  // =================================================================

  group('DeckListState', () {
    test('initial state has correct defaults', () {
      const state = DeckListState();

      expect(state.decks, isEmpty);
      expect(state.filteredDecks, isEmpty);
      expect(state.deckPrices, isEmpty);
      expect(state.isLoading, true);
      expect(state.isImporting, false);
      expect(state.searchQuery, '');
      expect(state.selectedFormat, 'Tous');
      expect(state.selectedSort, 'name');
      expect(state.selectedIdentityName, isNull);
      expect(state.selectedIdentityColors, isNull);
    });

    test('copyWith preserves values when not specified', () {
      const state = DeckListState(
        searchQuery: 'test',
        selectedFormat: 'Commander',
        isImporting: true,
      );

      final copied = state.copyWith(searchQuery: 'new');

      expect(copied.searchQuery, 'new');
      expect(copied.selectedFormat, 'Commander');
      expect(copied.isImporting, true);
    });

    test('copyWith clearIdentity resets identity fields', () {
      const state = DeckListState(
        selectedIdentityName: 'Gruul',
        selectedIdentityColors: ['R', 'G'],
      );

      final cleared = state.copyWith(clearIdentity: true);

      expect(cleared.selectedIdentityName, isNull);
      expect(cleared.selectedIdentityColors, isNull);
    });
  });

  // =================================================================
  // DeckListActionResult
  // =================================================================

  group('DeckListActionResult', () {
    test('defaults to success', () {
      const result = DeckListActionResult();
      expect(result.success, true);
      expect(result.message, '');
    });

    test('can indicate failure', () {
      const result = DeckListActionResult(
        success: false,
        message: 'Import failed',
      );
      expect(result.success, false);
      expect(result.message, 'Import failed');
    });
  });

  // =================================================================
  // Import parsing scenarios (integration: DeckFormatService + import logic)
  // =================================================================

  group('Import parsing scenarios', () {
    test('Moxfield Commander deck parses correctly for import', () {
      const moxfieldTxt = '''
Commander
1 Atraxa, Praetors' Voice

Deck
1 Sol Ring
1 Arcane Signet
35 Plains
30 Island
30 Swamp

Sideboard
1 Path to Exile
''';
      final result = DeckFormatService.autoDetectAndParse(moxfieldTxt);

      expect(result.commanderName, "Atraxa, Praetors' Voice");
      expect(result.mainboard, isNotEmpty);
      expect(result.sideboard, isNotEmpty);
      expect(result.totalCards, greaterThan(90));
    });

    test('MTGO Standard deck parses correctly for import', () {
      const mtgoTxt = '''
4 Lightning Bolt
4 Goblin Guide
4 Monastery Swiftspear
4 Eidolon of the Great Revel
4 Lava Spike
4 Searing Blaze
4 Rift Bolt
4 Shard Volley
4 Skullcrack
4 Inspiring Vantage
4 Sacred Foundry
4 Fiery Islet
4 Sunbaked Canyon
8 Mountain

Sideboard
4 Smash to Smithereens
3 Path to Exile
2 Blood Moon
2 Kor Firewalker
2 Rest in Peace
2 Deflecting Palm
''';
      final result = DeckFormatService.autoDetectAndParse(mtgoTxt);

      expect(result.commanderName, isNull);
      expect(result.mainboard.length, 14);
      expect(result.sideboard.length, 6);
      // Total should be 60 + 15
      expect(result.totalCards, 75);
    });

    test('CSV Archidekt import with categories extracts tags', () {
      const archidektCsv = '''Quantity,Name,Categories
1,Sol Ring,"Ramp, Mana Rock"
1,Arcane Signet,"Ramp, Mana Rock"
1,Command Tower,"Land"
1,Counterspell,"Interaction"''';

      final result = DeckFormatService.autoDetectAndParse(archidektCsv);

      expect(result.mainboard.length, 4);
      expect(result.cardTags['Sol Ring'], ['Ramp', 'Mana Rock']);
      expect(result.cardTags['Command Tower'], ['Land']);
    });

    test('empty import content returns failure', () {
      final result = DeckFormatService.autoDetectAndParse('');
      expect(result.mainboard, isEmpty);
      expect(result.sideboard, isEmpty);
    });

    test('import with invalid text returns warnings', () {
      const invalidTxt = '''
Hello World
This is not a decklist
Random text here
''';
      final result = DeckFormatService.autoDetectAndParse(invalidTxt);
      expect(result.mainboard, isEmpty);
      expect(result.warnings, isNotEmpty);
    });
  });

  // =================================================================
  // colorFamilies static data
  // =================================================================

  group('DeckListController.colorFamilies', () {
    test('contains all expected families', () {
      const families = DeckListController.colorFamilies;
      expect(families.containsKey('Mono'), isTrue);
      expect(families.containsKey('Guilde (2)'), isTrue);
      expect(families.containsKey('Trio (3)'), isTrue);
      expect(families.containsKey('Nephilim (4)'), isTrue);
      expect(families.containsKey('WUBRG (5)'), isTrue);
    });

    test('Mono contains all 6 options', () {
      final mono = DeckListController.colorFamilies['Mono']!;
      expect(mono.length, 6);
      expect(mono.containsKey('Blanc'), isTrue);
      expect(mono.containsKey('Incolore'), isTrue);
    });

    test('Guilde contains 10 guilds', () {
      final guilds = DeckListController.colorFamilies['Guilde (2)']!;
      expect(guilds.length, 10);
    });
  });

  // =================================================================
  // importDeck : branche sur CollectionService/CardResolver (round 2)
  // =================================================================
  group('DeckListController.importDeck', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
        'une ligne avec edition produit un DeckCard dont le scryfallId est '
        'celui du tirage indique, pas une impression arbitraire', () async {
      final dio = _mockDio((options) {
        return {
          'data': [
            {
              'id': 'ltc-284-en',
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

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _createImportController(dio: dio, db: db);

      final result = await controller.importDeck('Deck Edition', '1 Sol Ring (LTC) 284');

      expect(result.success, isTrue);
      final deck = controller.state.decks.firstWhere((d) => d.name == 'Deck Edition');
      expect(deck.mainboard, hasLength(1));
      expect(deck.mainboard.single.scryfallId, 'ltc-284-en');
    });

    test('une decklist de plus de 75 cartes ne perd aucune carte', () async {
      // Le resolveur decoupe deja en lots de 75 en interne : le mock echoe
      // une carte par identifiant recu, quel que soit le lot, pour prouver
      // qu'aucune carte n'est perdue au-dela d'un plafond arbitraire cote
      // controller (le bug corrige par ce round : `ids.take(75)`).
      final dio = _mockDio((options) {
        final body = options.data as Map;
        final identifiers = (body['identifiers'] as List).cast<Map<String, dynamic>>();
        final cards = identifiers.map((id) {
          final name = id['name'] as String;
          return {
            'id': 'id-${name.hashCode}',
            'oracle_id': 'oracle-${name.hashCode}',
            'name': name,
            'set': 'tst',
            'collector_number': '1',
            'lang': 'en',
          };
        }).toList();
        return {'data': cards, 'not_found': []};
      });

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _createImportController(dio: dio, db: db);

      const cardCount = 80;
      final decklistText = List.generate(cardCount, (i) => '1 Filler Card $i').join('\n');

      final result = await controller.importDeck('Gros Deck', decklistText);

      expect(result.success, isTrue);
      final deck = controller.state.decks.firstWhere((d) => d.name == 'Gros Deck');
      expect(deck.mainboard, hasLength(cardCount));
      // Aucune carte repliee sur le sentinel LOCAL: (donc aucune perdue en route).
      expect(deck.mainboard.every((c) => !c.scryfallId.startsWith('LOCAL:')), isTrue);
      // Chaque carte a bien recu SON tirage propre, pas celui d'une autre.
      for (final card in deck.mainboard) {
        expect(card.scryfallId, 'id-${card.name.hashCode}');
      }
    });

    test('une resolution partielle rend success=false et nomme le nombre de cartes non identifiees', () async {
      final dio = _mockDio((options) {
        return {
          'data': [],
          'not_found': [
            {'name': 'Carte Fantome'}
          ],
        };
      });

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _createImportController(dio: dio, db: db);

      final result = await controller.importDeck('Deck Incomplet', '1 Carte Fantome');

      // Pas de succes silencieux : l'echec partiel est visible dans le
      // resultat, avec le decompte, pas juste "Deck importe avec succes."
      expect(result.success, isFalse);
      expect(result.message, isNot('Deck importé avec succès.'));
      expect(result.message, contains('1'));

      final deck = controller.state.decks.firstWhere((d) => d.name == 'Deck Incomplet');
      expect(deck.mainboard.single.scryfallId, 'LOCAL:Carte Fantome');
    });

    test(
        'une carte absente du bulk local mais resolue par Scryfall apporte '
        'quand meme sa couleur a l\'identite du deck (regression round 3)', () async {
      // Nom fictif garanti absent du bulk local (assets/json/oracle-cards.json,
      // fige a la date de build) : seul le ResolvedPrint rendu par le mock
      // Scryfall peut fournir sa couleur. Avec l'ancien code (colorIdentity
      // lue via LocalCardService.getCardByName), cette carte etait ignoree
      // silencieusement et l'identite du deck sous-estimee.
      const fictionalName = 'Carte Totalement Inventee Zzzqx Neuvieme Extension';
      expect(
        LocalCardService().getCardByName(fictionalName),
        isNull,
        reason: 'le nom de test doit rester absent du bulk local pour que le '
            'test verifie bien le bon chemin (sinon il passerait meme avec '
            'la regression)',
      );

      final dio = _mockDio((options) {
        return {
          'data': [
            {
              'id': 'neo-1-en',
              'oracle_id': 'oracle-carte-inventee',
              'name': fictionalName,
              'set': 'neo',
              'collector_number': '1',
              'lang': 'en',
              'color_identity': ['U', 'B'],
            }
          ],
          'not_found': [],
        };
      });

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _createImportController(dio: dio, db: db);

      final result = await controller.importDeck('Deck Neuf', '1 $fictionalName');

      expect(result.success, isTrue);
      final deck = controller.state.decks.firstWhere((d) => d.name == 'Deck Neuf');
      expect(deck.mainboard.single.scryfallId, 'neo-1-en');
      expect(deck.colors, ['U', 'B']);
    });
  });
}
