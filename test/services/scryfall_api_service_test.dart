// Tests pour ScryfallApiService (Sprint 5)
// Teste le cache mémoire, rate limiting et les méthodes API

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';

/// Crée un Dio mocké via intercepteur qui appelle [handler] pour chaque requête.
Dio _createMockDio(Map<String, dynamic> Function(RequestOptions) handler, {int Function(RequestOptions)? callCounter}) {
  final dio = Dio(BaseOptions(baseUrl: ScryfallApiService.baseUrl));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, h) {
      callCounter?.call(options);
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
  group('ScryfallApiService - Cache', () {
    test('cache hit returns cached data without network call', () async {
      int networkCalls = 0;
      final dio = _createMockDio(
        (options) {
          networkCalls++;
          return {
            'data': [
              {'name': 'Lightning Bolt', 'id': 'bolt-123'}
            ],
            'has_more': false,
            'total_cards': 1,
          };
        },
      );

      final api = ScryfallApiService(dio: dio);

      // Premier appel : cache miss
      final result1 = await api.getAllSets();
      expect(networkCalls, 1);
      expect(result1['total_cards'], 1);

      // Deuxième appel : cache hit
      final result2 = await api.getAllSets();
      expect(networkCalls, 1); // Pas de nouvel appel réseau
      expect(result2['total_cards'], 1);
    });

    test('clearCache forces new network call', () async {
      int networkCalls = 0;
      final dio = _createMockDio((options) {
        networkCalls++;
        return {'data': [], 'total_cards': networkCalls};
      });

      final api = ScryfallApiService(dio: dio);

      await api.getAllSets();
      expect(networkCalls, 1);

      api.clearCache();
      expect(api.cacheSize, 0);

      await api.getAllSets();
      expect(networkCalls, 2);
    });

    test('invalidateCache removes matching entries', () async {
      final dio = _createMockDio((options) {
        return {'data': [], 'total_cards': 0};
      });

      final api = ScryfallApiService(dio: dio);

      await api.getAllSets();
      await api.searchCards('lightning bolt');
      expect(api.cacheSize, 2);

      api.invalidateCache('/sets');
      expect(api.cacheSize, 1);
    });

    test('cacheSize reflects number of entries', () async {
      final dio = _createMockDio((options) {
        return {'data': [], 'total_cards': 0};
      });

      final api = ScryfallApiService(dio: dio);
      expect(api.cacheSize, 0);

      await api.getAllSets();
      expect(api.cacheSize, 1);

      await api.searchCards('bolt');
      expect(api.cacheSize, 2);
    });
  });

  group('ScryfallApiService - API Methods', () {
    test('searchCards builds correct query parameters', () async {
      RequestOptions? capturedOptions;
      final dio = _createMockDio((options) {
        capturedOptions = options;
        return {
          'data': [
            {'name': 'Lightning Bolt'}
          ],
          'has_more': false,
          'total_cards': 1,
        };
      });

      final api = ScryfallApiService(dio: dio);
      await api.searchCards('lightning bolt', lang: 'fr', unique: 'cards');

      expect(capturedOptions, isNotNull);
      final uri = capturedOptions!.uri;
      expect(uri.queryParameters['q'], 'lightning bolt');
      expect(uri.queryParameters['lang'], 'fr');
      expect(uri.queryParameters['unique'], 'cards');
    });

    test('fetchNextPage uses absolute URL', () async {
      String? capturedPath;
      final dio = _createMockDio((options) {
        capturedPath = options.uri.toString();
        return {'data': [], 'has_more': false, 'total_cards': 0};
      });

      final api = ScryfallApiService(dio: dio);
      await api.fetchNextPage(
          'https://api.scryfall.com/cards/search?page=2&q=bolt');

      expect(capturedPath, contains('page=2'));
    });

    test('getCardBySetAndNumber builds correct path', () async {
      RequestOptions? capturedOptions;
      final dio = _createMockDio((options) {
        capturedOptions = options;
        return {'name': 'Lightning Bolt', 'id': 'bolt-123'};
      });

      final api = ScryfallApiService(dio: dio);
      await api.getCardBySetAndNumber('lea', '161');

      expect(capturedOptions!.uri.path, '/cards/lea/161');
    });

    test('getCardRulings returns rulings data', () async {
      final dio = _createMockDio((options) {
        return {
          'data': [
            {'comment': 'This is a ruling'}
          ]
        };
      });

      final api = ScryfallApiService(dio: dio);
      final result = await api.getCardRulings('bolt-123');
      expect(result['data'], hasLength(1));
    });

    test('fetchCollection sends POST with identifiers', () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: ScryfallApiService.baseUrl));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedOptions = options;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': [
                {'name': 'Lightning Bolt'}
              ],
              'not_found': []
            },
          ));
        },
      ));

      final api = ScryfallApiService(dio: dio);
      final result = await api.fetchCollection([
        {'name': 'Lightning Bolt'},
      ]);

      expect(capturedOptions!.method, 'POST');
      expect(result['data'], hasLength(1));
    });

    test('getAllSets uses long cache TTL', () async {
      int networkCalls = 0;
      final dio = _createMockDio((options) {
        networkCalls++;
        return {'data': [], 'total_cards': 0};
      });

      final api = ScryfallApiService(dio: dio);

      await api.getAllSets();
      await api.getAllSets();
      await api.getAllSets();

      expect(networkCalls, 1); // All cache hits
    });
  });

  group('ScryfallApiService - Rate Limiting', () {
    test('allows up to 10 requests per second', () async {
      int callCount = 0;
      final dio = _createMockDio((options) {
        callCount++;
        return {'data': [], 'total_cards': callCount};
      });

      final api = ScryfallApiService(dio: dio);

      // Fire 10 requests rapidly (each with unique query to avoid cache)
      for (int i = 0; i < 10; i++) {
        await api.searchCards('card_$i');
      }

      expect(callCount, 10);
    });
  });

  group('ScryfallApiService - Error Handling', () {
    test('DioException is rethrown on network error', () async {
      final dio = Dio(BaseOptions(baseUrl: ScryfallApiService.baseUrl));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'Connection refused',
          ));
        },
      ));

      final api = ScryfallApiService(dio: dio);
      expect(
        () => api.getAllSets(),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ScryfallApiService - Constructor', () {
    test('default constructor creates valid service', () {
      final api = ScryfallApiService();
      expect(api.cacheSize, 0);
      expect(api.dio, isNotNull);
    });

    test('custom Dio can be injected', () {
      final customDio = Dio(BaseOptions(baseUrl: 'https://custom.api.com'));
      final api = ScryfallApiService(dio: customDio);
      expect(api.dio.options.baseUrl, 'https://custom.api.com');
    });
  });
}
