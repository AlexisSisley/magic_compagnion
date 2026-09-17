// Fichier : test/services/collection_service_test.dart
//
// Tests unitaires pour CollectionService.
// Auteur : Sanji (Lead Developer)

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_print.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/collection_service.dart';
import 'package:magic_companion/services/deck_format_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/models/deck_model.dart';

/// Dio mocke : [handler] rend soit une Map (200), soit un int (code d'erreur
/// HTTP, encapsule en badResponse), soit un DioException tout construit
/// (pour simuler un timeout ou tout autre type d'echec sans reponse HTTP).
/// Recopie de test/services/card_resolver_test.dart (pas de helper partage).
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CollectionService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = CollectionService();
  });

  // ---------------------------------------------------------------------------
  // 1. loadCollection() retourne [] quand vide
  // ---------------------------------------------------------------------------
  group('loadCollection', () {
    test('retourne une liste vide quand aucune donnee n\'est sauvegardee', () async {
      final result = await service.loadCollection();
      expect(result, isEmpty);
      expect(result, isA<List<DeckCard>>());
    });
  });

  // ---------------------------------------------------------------------------
  // 2. upsertCardInCollection() - ajout d'une nouvelle carte (quantityToAdd)
  // ---------------------------------------------------------------------------
  group('upsertCardInCollection - ajout nouvelle carte', () {
    test('ajoute une nouvelle carte avec quantityToAdd', () async {
      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 3,
      );

      expect(collection.length, 1);
      expect(collection.first.scryfallId, 'card-001');
      expect(collection.first.name, 'Lightning Bolt');
      expect(collection.first.quantity, 3);
      expect(collection.first.isFoil, false);
      expect(collection.first.tags, isEmpty);
    });

    test('ne cree pas de carte si quantityToAdd est <= 0', () async {
      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 0,
      );

      expect(collection, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. upsertCardInCollection() - mise a jour quantite (quantityToAdd existant)
  // ---------------------------------------------------------------------------
  group('upsertCardInCollection - mise a jour quantite existante', () {
    test('incremente la quantite d\'une carte existante avec quantityToAdd', () async {
      // Ajout initial
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 2,
      );

      // Mise a jour
      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 3,
      );

      expect(collection.length, 1);
      expect(collection.first.quantity, 5);
    });

    test('decremente la quantite d\'une carte existante avec quantityToAdd negatif', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 4,
      );

      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: -2,
      );

      expect(collection.length, 1);
      expect(collection.first.quantity, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. upsertCardInCollection() - absoluteQuantity
  // ---------------------------------------------------------------------------
  group('upsertCardInCollection - absoluteQuantity', () {
    test('definit la quantite absolue sur une nouvelle carte', () async {
      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-002',
        cardName: 'Counterspell',
        absoluteQuantity: 7,
      );

      expect(collection.length, 1);
      expect(collection.first.quantity, 7);
    });

    test('remplace la quantite d\'une carte existante avec absoluteQuantity', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-002',
        cardName: 'Counterspell',
        quantityToAdd: 3,
      );

      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-002',
        cardName: 'Counterspell',
        absoluteQuantity: 10,
      );

      expect(collection.length, 1);
      expect(collection.first.quantity, 10);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. upsertCardInCollection() - supprime quand quantite <= 0
  // ---------------------------------------------------------------------------
  group('upsertCardInCollection - suppression quand quantite <= 0', () {
    test('supprime la carte quand quantityToAdd rend la quantite <= 0', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 2,
      );

      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: -2,
      );

      expect(collection, isEmpty);
    });

    test('supprime la carte quand quantityToAdd rend la quantite negative', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 1,
      );

      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: -5,
      );

      expect(collection, isEmpty);
    });

    test('supprime la carte quand absoluteQuantity est <= 0', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 4,
      );

      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        absoluteQuantity: 0,
      );

      expect(collection, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Foil vs Non-Foil : meme scryfallId, deux entrees separees
  // ---------------------------------------------------------------------------
  group('Foil vs Non-Foil', () {
    test('cree deux entrees distinctes pour la meme carte foil et non-foil', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 2,
        isFoil: false,
      );

      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 1,
        isFoil: true,
      );

      expect(collection.length, 2);

      final nonFoil = collection.firstWhere((c) => !c.isFoil);
      final foil = collection.firstWhere((c) => c.isFoil);

      expect(nonFoil.quantity, 2);
      expect(nonFoil.isFoil, false);
      expect(foil.quantity, 1);
      expect(foil.isFoil, true);
      expect(nonFoil.scryfallId, foil.scryfallId);
    });

    test('modifie uniquement la version foil sans toucher la non-foil', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 4,
        isFoil: false,
      );

      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 2,
        isFoil: true,
      );

      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 3,
        isFoil: true,
      );

      final nonFoil = collection.firstWhere((c) => !c.isFoil);
      final foil = collection.firstWhere((c) => c.isFoil);

      expect(nonFoil.quantity, 4); // Inchange
      expect(foil.quantity, 5);    // 2 + 3
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Tags : ajout et modification
  // ---------------------------------------------------------------------------
  group('Tags', () {
    test('ajoute une carte avec des tags initiaux', () async {
      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-003',
        cardName: 'Sol Ring',
        quantityToAdd: 1,
        newTags: ['Commander', 'Ramp'],
      );

      expect(collection.first.tags, ['Commander', 'Ramp']);
    });

    test('modifie les tags d\'une carte existante', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-003',
        cardName: 'Sol Ring',
        quantityToAdd: 1,
        newTags: ['Commander'],
      );

      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-003',
        cardName: 'Sol Ring',
        quantityToAdd: 1,
        newTags: ['Trade', 'Staple'],
      );

      expect(collection.first.tags, ['Trade', 'Staple']);
    });

    test('ne modifie pas les tags si newTags est null', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-003',
        cardName: 'Sol Ring',
        quantityToAdd: 1,
        newTags: ['Commander', 'Ramp'],
      );

      final collection = await service.upsertCardInCollection(
        scryfallId: 'card-003',
        cardName: 'Sol Ring',
        quantityToAdd: 1,
        // newTags non fourni -> null
      );

      expect(collection.first.tags, ['Commander', 'Ramp']);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. clearCollection() vide tout
  // ---------------------------------------------------------------------------
  group('clearCollection', () {
    test('supprime toutes les cartes de la collection', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 4,
      );

      await service.upsertCardInCollection(
        scryfallId: 'card-002',
        cardName: 'Counterspell',
        quantityToAdd: 2,
      );

      // Verification avant clear
      final before = await service.loadCollection();
      expect(before.length, 2);

      await service.clearCollection();

      final after = await service.loadCollection();
      expect(after, isEmpty);
    });

    test('clearCollection sur une collection deja vide ne pose pas de probleme', () async {
      await service.clearCollection();
      final result = await service.loadCollection();
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. getAllUniqueTags() retourne les tags tries sans doublons
  // ---------------------------------------------------------------------------
  group('getAllUniqueTags', () {
    test('retourne les tags uniques tries alphabetiquement', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 1,
        newTags: ['Burn', 'Staple'],
      );

      await service.upsertCardInCollection(
        scryfallId: 'card-002',
        cardName: 'Counterspell',
        quantityToAdd: 1,
        newTags: ['Control', 'Staple'],
      );

      await service.upsertCardInCollection(
        scryfallId: 'card-003',
        cardName: 'Sol Ring',
        quantityToAdd: 1,
        newTags: ['Ramp', 'Commander', 'Staple'],
      );

      final tags = await service.getAllUniqueTags();

      expect(tags, ['Burn', 'Commander', 'Control', 'Ramp', 'Staple']);
      // Pas de doublon pour 'Staple' malgre 3 occurrences
      expect(tags.where((t) => t == 'Staple').length, 1);
    });

    test('retourne une liste vide quand aucune carte n\'a de tags', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 1,
      );

      final tags = await service.getAllUniqueTags();
      expect(tags, isEmpty);
    });

    test('retourne une liste vide quand la collection est vide', () async {
      final tags = await service.getAllUniqueTags();
      expect(tags, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. recordDailyValue() + getEvolutionSince() : historique financier
  // ---------------------------------------------------------------------------
  group('recordDailyValue et getEvolutionSince', () {
    test('enregistre et recupere l\'evolution financiere', () async {
      // On injecte manuellement un historique avec plusieurs jours
      // pour simuler des enregistrements passes.
      final now = DateTime.now();
      final Map<String, dynamic> history = {};

      for (int i = 7; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        history[key] = 100.0 + (7 - i) * 10.0; // 100, 110, 120, ... 170
      }

      SharedPreferences.setMockInitialValues({
        'collection_value_history': json.encode(history),
      });

      final service = CollectionService();
      final evolution = await service.getEvolutionSince(7);

      expect(evolution, isNotNull);
      expect(evolution!['currentValue'], 170.0);
      expect(evolution['pastValue'], 100.0);
      expect(evolution['diffValue'], 70.0);
      expect(evolution['diffPercentage'], 70.0);
    });

    test('recordDailyValue sauvegarde la valeur du jour', () async {
      await service.recordDailyValue(250.0);

      final evolution = await service.getEvolutionSince(0);

      expect(evolution, isNotNull);
      expect(evolution!['currentValue'], 250.0);
      expect(evolution['diffValue'], 0.0);
    });

    test('recordDailyValue ecrase la valeur si le meme jour est enregistre deux fois', () async {
      await service.recordDailyValue(100.0);
      await service.recordDailyValue(200.0);

      final evolution = await service.getEvolutionSince(0);

      expect(evolution, isNotNull);
      expect(evolution!['currentValue'], 200.0);
    });
  });

  // ---------------------------------------------------------------------------
  // 11. getEvolutionSince() retourne null quand pas d'historique
  // ---------------------------------------------------------------------------
  group('getEvolutionSince - pas d\'historique', () {
    test('retourne null quand aucun historique n\'existe', () async {
      final result = await service.getEvolutionSince(7);
      expect(result, isNull);
    });

    test('retourne null quand l\'historique est un objet vide', () async {
      SharedPreferences.setMockInitialValues({
        'collection_value_history': json.encode({}),
      });

      final service = CollectionService();
      final result = await service.getEvolutionSince(7);

      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Bonus : persistance entre appels (verification SharedPreferences)
  // ---------------------------------------------------------------------------
  group('Persistance', () {
    test('les donnees persistent entre deux appels loadCollection', () async {
      await service.upsertCardInCollection(
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 4,
        newTags: ['Burn'],
        isFoil: true,
      );

      // Nouvel appel loadCollection (simule un reload)
      final reloaded = await service.loadCollection();

      expect(reloaded.length, 1);
      expect(reloaded.first.scryfallId, 'card-001');
      expect(reloaded.first.name, 'Lightning Bolt');
      expect(reloaded.first.quantity, 4);
      expect(reloaded.first.isFoil, true);
      expect(reloaded.first.tags, ['Burn']);
    });
  });

  // ---------------------------------------------------------------------------
  // 12. resolveImportedEntries() : import par edition, traductions enfilees
  // ---------------------------------------------------------------------------
  group('resolveImportedEntries', () {
    test('l import resout par edition et n attend pas les traductions', () async {
      int collectionCalls = 0;
      int unitaryCalls = 0;
      final dio = _mockDio((options) {
        if (options.path.contains('/cards/collection')) {
          collectionCalls++;
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
        }
        unitaryCalls++;
        return {'id': 'ltc-284-fr', 'oracle_id': 'oracle-sol-ring', 'lang': 'fr'};
      });

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      final entries = DeckFormatService.parseDecklistText('1 Sol Ring (LTC) 284 *F*').mainboard;
      final resolution = await resolver.resolveEditions(entries
          .map((e) => PrintRequest(
                name: e.name,
                setCode: e.setCode,
                collectorNumber: e.collectorNumber,
              ))
          .toList());

      for (final print in resolution.resolved) {
        await db.enqueueTranslation(
          scryfallId: print.scryfallId,
          setCode: print.setCode,
          collectorNumber: print.collectorNumber,
          lang: 'fr',
        );
      }

      // Temps 1 seulement : l'edition est exacte, aucune requete unitaire n'a eu lieu.
      expect(resolution.resolved.single.scryfallId, 'ltc-284-en');
      expect(resolution.resolved.single.setCode, 'ltc');
      expect(resolution.isComplete, isTrue);
      expect(collectionCalls, 1);
      expect(unitaryCalls, 0);
      expect(await db.nextTranslationTasks(), hasLength(1));
    });

    test('CollectionService.resolveImportedEntries branche le resolveur et enfile la traduction', () async {
      int collectionCalls = 0;
      int unitaryCalls = 0;
      final dio = _mockDio((options) {
        if (options.path.contains('/cards/collection')) {
          collectionCalls++;
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
        }
        unitaryCalls++;
        return {'id': 'ltc-284-fr', 'oracle_id': 'oracle-sol-ring', 'lang': 'fr'};
      });

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);
      final importService = CollectionService(database: db, resolver: resolver);

      final entries = DeckFormatService.parseDecklistText('1 Sol Ring (LTC) 284 *F*').mainboard;

      final resolution = await importService.resolveImportedEntries(
        entries,
        preferredLang: 'fr',
      );

      // L'import rend la main des que l'edition est connue : aucune requete
      // unitaire de traduction n'a ete attendue dans le chemin d'import.
      expect(resolution.resolved.single.scryfallId, 'ltc-284-en');
      expect(resolution.isComplete, isTrue);
      expect(collectionCalls, 1);
      expect(unitaryCalls, 0);

      // Mais la traduction a bien ete enfilee pour un traitement en fond.
      final tasks = await db.nextTranslationTasks();
      expect(tasks, hasLength(1));
      expect(tasks.single.scryfallId, 'ltc-284-en');
      expect(tasks.single.lang, 'fr');
    });

    test('n enfile pas de traduction quand le tirage est deja dans la langue preferee', () async {
      final dio = _mockDio((options) {
        return {
          'data': [
            {
              'id': 'ltc-284-fr',
              'oracle_id': 'oracle-sol-ring',
              'name': 'Sol Ring',
              'set': 'ltc',
              'collector_number': '284',
              'lang': 'fr',
            }
          ],
          'not_found': [],
        };
      });

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);
      final importService = CollectionService(database: db, resolver: resolver);

      final entries = DeckFormatService.parseDecklistText('1 Sol Ring (LTC) 284').mainboard;

      await importService.resolveImportedEntries(entries, preferredLang: 'fr');

      expect(await db.nextTranslationTasks(), isEmpty);
    });
  });
}
