// Tests unitaires pour BulkDataService et getCatalog (Sprint 12, US-12.9 + US-12.10)
// Teste le modele BulkDataInfo, le service bulk data et les catalogs Scryfall.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/bulk_data_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';

/// Cree un Dio mocke via intercepteur qui appelle [handler] pour chaque requete.
Dio _createMockDio(Map<String, dynamic> Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: ScryfallApiService.baseUrl));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, h) {
      final data = handler(options);
      h.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: data,
      ));
    },
  ));
  return dio;
}

void main() {
  // ============================================================
  // BulkDataInfo model tests
  // ============================================================

  group('BulkDataInfo model', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'type': 'oracle_cards',
        'name': 'Oracle Cards',
        'description': 'Every Oracle card',
        'download_uri': 'https://example.com/oracle.json',
        'updated_at': '2026-03-01T10:00:00+00:00',
        'compressed_size': 54321,
      };

      final info = BulkDataInfo.fromJson(json);
      expect(info.type, 'oracle_cards');
      expect(info.name, 'Oracle Cards');
      expect(info.description, 'Every Oracle card');
      expect(info.downloadUri, 'https://example.com/oracle.json');
      expect(info.updatedAt.year, 2026);
      expect(info.updatedAt.month, 3);
      expect(info.compressedSize, 54321);
    });

    test('fromJson handles missing fields with defaults', () {
      final info = BulkDataInfo.fromJson({});
      expect(info.type, '');
      expect(info.name, '');
      expect(info.description, '');
      expect(info.downloadUri, '');
      expect(info.updatedAt.year, 2000);
      expect(info.compressedSize, isNull);
    });

    test('fromJson handles null values gracefully', () {
      final json = {
        'type': null,
        'name': null,
        'description': null,
        'download_uri': null,
        'updated_at': null,
        'compressed_size': null,
      };

      final info = BulkDataInfo.fromJson(json);
      expect(info.type, '');
      expect(info.name, '');
      expect(info.downloadUri, '');
    });

    test('fromJson parses compressed_size as int', () {
      final json = {
        'compressed_size': 1000000,
        'updated_at': '2026-01-01T00:00:00+00:00',
      };
      final info = BulkDataInfo.fromJson(json);
      expect(info.compressedSize, 1000000);
    });
  });

  // ============================================================
  // ScryfallApiService.getCatalog tests
  // ============================================================

  group('ScryfallApiService.getCatalog', () {
    test('getCatalog returns list of strings from data field', () async {
      final dio = _createMockDio((options) {
        return {
          'object': 'catalog',
          'uri': 'https://api.scryfall.com/catalog/creature-types',
          'total_values': 3,
          'data': ['Angel', 'Beast', 'Cat'],
        };
      });

      final api = ScryfallApiService(dio: dio);
      final result = await api.getCatalog('creature-types');

      expect(result, hasLength(3));
      expect(result, contains('Angel'));
      expect(result, contains('Beast'));
      expect(result, contains('Cat'));
    });

    test('getCatalog returns empty list when data is null', () async {
      final dio = _createMockDio((options) {
        return {
          'object': 'catalog',
          'total_values': 0,
        };
      });

      final api = ScryfallApiService(dio: dio);
      final result = await api.getCatalog('nonexistent');

      expect(result, isEmpty);
    });

    test('getCatalog handles empty data list', () async {
      final dio = _createMockDio((options) {
        return {
          'object': 'catalog',
          'data': [],
          'total_values': 0,
        };
      });

      final api = ScryfallApiService(dio: dio);
      final result = await api.getCatalog('empty-catalog');

      expect(result, isEmpty);
    });

    test('getCatalog calls correct endpoint path', () async {
      String? requestedPath;
      final dio = _createMockDio((options) {
        requestedPath = options.uri.path;
        return {'data': ['Test']};
      });

      final api = ScryfallApiService(dio: dio);
      await api.getCatalog('keyword-abilities');

      expect(requestedPath, '/catalog/keyword-abilities');
    });

    test('getCatalog uses long cache TTL', () async {
      int networkCalls = 0;
      final dio = _createMockDio((options) {
        networkCalls++;
        return {'data': ['Ability1', 'Ability2']};
      });

      final api = ScryfallApiService(dio: dio);

      // Premier appel : cache miss
      await api.getCatalog('keyword-abilities');
      expect(networkCalls, 1);

      // Deuxieme appel : cache hit
      await api.getCatalog('keyword-abilities');
      expect(networkCalls, 1); // Pas de nouvel appel
    });

    test('getCatalog works with different catalog names', () async {
      final catalogResponses = {
        'creature-types': ['Angel', 'Beast'],
        'keyword-abilities': ['Flying', 'Trample'],
        'land-types': ['Forest', 'Island'],
      };

      final dio = _createMockDio((options) {
        final path = options.uri.path;
        final catalogName = path.split('/').last;
        return {'data': catalogResponses[catalogName] ?? []};
      });

      final api = ScryfallApiService(dio: dio);

      final creatures = await api.getCatalog('creature-types');
      expect(creatures, contains('Angel'));

      final abilities = await api.getCatalog('keyword-abilities');
      expect(abilities, contains('Flying'));

      final lands = await api.getCatalog('land-types');
      expect(lands, contains('Forest'));
    });
  });

  // ============================================================
  // ScryfallApiService.getBulkDataByType tests
  // ============================================================

  group('ScryfallApiService.getBulkDataByType', () {
    test('getBulkDataByType returns bulk data metadata', () async {
      final dio = _createMockDio((options) {
        return {
          'object': 'bulk_data',
          'type': 'oracle_cards',
          'name': 'Oracle Cards',
          'description': 'Every Oracle card object',
          'download_uri': 'https://data.scryfall.io/oracle-cards.json',
          'updated_at': '2026-03-01T00:00:00+00:00',
          'compressed_size': 50000000,
        };
      });

      final api = ScryfallApiService(dio: dio);
      final result = await api.getBulkDataByType('oracle-cards');

      expect(result['type'], 'oracle_cards');
      expect(result['name'], 'Oracle Cards');
      expect(result['download_uri'], isNotNull);
    });

    test('getBulkDataByType calls correct endpoint', () async {
      String? requestedPath;
      final dio = _createMockDio((options) {
        requestedPath = options.uri.path;
        return {'type': 'oracle_cards'};
      });

      final api = ScryfallApiService(dio: dio);
      await api.getBulkDataByType('oracle-cards');

      expect(requestedPath, '/bulk-data/oracle-cards');
    });
  });

  // ============================================================
  // ScryfallApiService.getBulkDataList tests
  // ============================================================

  group('ScryfallApiService.getBulkDataList', () {
    test('getBulkDataList returns list of bulk data objects', () async {
      final dio = _createMockDio((options) {
        return {
          'object': 'list',
          'has_more': false,
          'data': [
            {'type': 'oracle_cards', 'name': 'Oracle Cards'},
            {'type': 'unique_artwork', 'name': 'Unique Artwork'},
          ],
        };
      });

      final api = ScryfallApiService(dio: dio);
      final result = await api.getBulkDataList();

      expect(result['data'], hasLength(2));
    });

    test('getBulkDataList calls correct endpoint', () async {
      String? requestedPath;
      final dio = _createMockDio((options) {
        requestedPath = options.uri.path;
        return {'data': []};
      });

      final api = ScryfallApiService(dio: dio);
      await api.getBulkDataList();

      expect(requestedPath, '/bulk-data');
    });
  });
}
