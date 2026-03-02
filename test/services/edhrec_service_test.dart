// Tests unitaires pour EdhrecService enrichi (Sprint 11, Phase 2).
// Mock Dio via intercepteur pour tester les 3 nouvelles methodes + cache.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/edhrec_service.dart';

/// Cree un Dio mocke via intercepteur.
/// [handler] recoit les RequestOptions et retourne la data de la Response.
/// Si [statusCode] est fourni, il est utilise pour toutes les reponses.
/// Si [shouldThrow] est true, le handler throw une DioException.
Dio _createMockDio(
  dynamic Function(RequestOptions) handler, {
  int statusCode = 200,
  bool shouldThrow = false,
  int Function(RequestOptions)? callCounter,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://json.edhrec.com'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, h) {
      callCounter?.call(options);
      if (shouldThrow) {
        h.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          message: 'Timeout',
        ));
        return;
      }
      final data = handler(options);
      h.resolve(Response(
        requestOptions: options,
        statusCode: statusCode,
        data: data,
      ));
    },
  ));
  return dio;
}

/// Fixture JSON simulant une reponse EDHREC /pages/commanders/{slug}.json
Map<String, dynamic> _commanderJsonFixture({
  List<Map<String, dynamic>>? cardLists,
  List<Map<String, dynamic>>? tagLinks,
  List<Map<String, dynamic>>? comboCounts,
  int numDecks = 12000,
}) {
  return {
    'container': {
      'json_dict': {
        'cardlists': cardLists ??
            [
              {
                'header': 'High Synergy Cards',
                'cardviews': [
                  {
                    'name': 'Sword of Truth and Justice',
                    'sanitized': 'sword-of-truth-and-justice',
                    'synergy': 0.35,
                    'inclusion': 45,
                    'num_decks': 5600,
                    'potential_decks': 12000,
                  },
                ],
              },
              {
                'header': 'Top Cards',
                'cardviews': [
                  {
                    'name': 'Sol Ring',
                    'sanitized': 'sol-ring',
                    'synergy': -0.05,
                    'inclusion': 98,
                    'num_decks': 150000,
                    'potential_decks': 155000,
                  },
                ],
              },
              {
                'header': 'Creatures',
                'cardviews': [
                  {
                    'name': 'Gyre Sage',
                    'sanitized': 'gyre-sage',
                    'synergy': 0.22,
                    'inclusion': 30,
                    'num_decks': 3000,
                    'potential_decks': 12000,
                  },
                ],
              },
            ],
        'taglinks': tagLinks ??
            [
              {
                'value': 'Infect',
                'href': '/themes/atraxa-praetors-voice/infect',
                'count': 6284,
              },
              {
                'value': 'Planeswalkers',
                'href': '/themes/atraxa-praetors-voice/planeswalkers',
                'count': 3654,
              },
              {
                'value': 'Obscure Theme',
                'href': '/themes/atraxa-praetors-voice/obscure',
                'count': 10, // < 50, should be filtered out
              },
            ],
        'combocounts': comboCounts ??
            [
              {'name': 'Vraska + Vorinclex', 'count': 24872},
              {'name': 'Exquisite Blood + Sanguine Bond', 'count': 18340},
            ],
        'num_decks': numDecks,
      },
    },
  };
}

/// Fixture JSON pour /pages/themes/{slug}/{theme}.json
Map<String, dynamic> _themeJsonFixture() {
  return {
    'container': {
      'json_dict': {
        'cardlists': [
          {
            'header': 'High Synergy Cards',
            'cardviews': [
              {
                'name': 'Blighted Agent',
                'sanitized': 'blighted-agent',
                'synergy': 0.55,
                'inclusion': 72,
                'num_decks': 4500,
                'potential_decks': 6284,
              },
              {
                'name': 'Glistener Elf',
                'sanitized': 'glistener-elf',
                'synergy': 0.48,
                'inclusion': 65,
                'num_decks': 4000,
                'potential_decks': 6284,
              },
            ],
          },
        ],
      },
    },
  };
}

/// Fixture JSON pour /pages/combos/{slug}.json
Map<String, dynamic> _combosJsonFixture({int comboCount = 3}) {
  final cardLists = <Map<String, dynamic>>[];
  for (var i = 0; i < comboCount; i++) {
    cardLists.add({
      'header': 'Combo ${i + 1}',
      'cardviews': [
        {'name': 'Card A$i'},
        {'name': 'Card B$i'},
      ],
      'combo': {
        'comboId': i + 1,
        'results': ['Infinite damage'],
        'colors': 'WUB',
        'count': 10000 - (i * 1000),
        'percentage': 1.0 - (i * 0.1),
        'rank': i + 1,
      },
    });
  }

  return {
    'container': {
      'json_dict': {
        'cardlists': cardLists,
      },
    },
  };
}

void main() {
  // ============================================================
  // getCommanderData
  // ============================================================

  group('EdhrecService.getCommanderData', () {
    test('parses suggestions, themes, and combocounts correctly', () async {
      final dio = _createMockDio((_) => _commanderJsonFixture());
      final service = EdhrecService(dio: dio);

      final data = await service.getCommanderData('Atraxa, Praetors\' Voice');

      // Suggestions
      expect(data.categorizedSuggestions, isNotEmpty);
      expect(data.categorizedSuggestions.containsKey('Haute Synergie'), true);
      expect(data.categorizedSuggestions['Haute Synergie']!.first.name, 'Sword of Truth and Justice');
      expect(data.categorizedSuggestions['Haute Synergie']!.first.synergy, 0.35);

      expect(data.categorizedSuggestions.containsKey('Top Cartes'), true);
      expect(data.categorizedSuggestions['Top Cartes']!.first.name, 'Sol Ring');

      expect(data.categorizedSuggestions.containsKey('Creatures'), true);

      // Themes (filtered: only >= 50 decks)
      expect(data.themes, hasLength(2)); // Obscure Theme filtered out
      expect(data.themes[0].name, 'Infect');
      expect(data.themes[0].slug, 'infect');
      expect(data.themes[0].deckCount, 6284);
      expect(data.themes[1].name, 'Planeswalkers');

      // Top combos
      expect(data.topCombos, hasLength(2));
      expect(data.topCombos[0].name, 'Vraska + Vorinclex');
      expect(data.topCombos[0].deckCount, 24872);

      // Total decks
      expect(data.totalDecks, 12000);
      expect(data.isEmpty, false);
    });

    test('returns empty for 404 response', () async {
      final dio = _createMockDio((_) => {}, statusCode: 404);
      final service = EdhrecService(dio: dio);

      final data = await service.getCommanderData('Unknown Commander');

      expect(data.isEmpty, true);
      expect(data.categorizedSuggestions, isEmpty);
      expect(data.themes, isEmpty);
    });

    test('returns empty on Dio exception (timeout)', () async {
      final dio = _createMockDio((_) => {}, shouldThrow: true);
      final service = EdhrecService(dio: dio);

      final data = await service.getCommanderData('Atraxa');

      expect(data.isEmpty, true);
    });

    test('returns empty when no container in response', () async {
      final dio = _createMockDio((_) => {'some_other_key': 'value'});
      final service = EdhrecService(dio: dio);

      final data = await service.getCommanderData('Atraxa');

      expect(data.isEmpty, true);
    });

    test('returns empty when container has no json_dict', () async {
      final dio = _createMockDio((_) => {
            'container': {'other_field': true}
          });
      final service = EdhrecService(dio: dio);

      final data = await service.getCommanderData('Atraxa');

      expect(data.categorizedSuggestions, isEmpty);
      expect(data.themes, isEmpty);
    });

    test('filters themes with less than 50 decks', () async {
      final dio = _createMockDio((_) => _commanderJsonFixture(
            tagLinks: [
              {'value': 'Big Theme', 'href': '/themes/cmd/big', 'count': 500},
              {'value': 'Small Theme', 'href': '/themes/cmd/small', 'count': 30},
              {'value': 'Exact 50', 'href': '/themes/cmd/exact', 'count': 50},
            ],
          ));
      final service = EdhrecService(dio: dio);

      final data = await service.getCommanderData('Commander');

      expect(data.themes, hasLength(2)); // Big Theme and Exact 50
      expect(data.themes[0].name, 'Big Theme');
      expect(data.themes[1].name, 'Exact 50');
    });

    test('caches result and returns cached data on second call', () async {
      int networkCalls = 0;
      final dio = _createMockDio(
        (_) => _commanderJsonFixture(),
        callCounter: (_) => networkCalls++,
      );
      final service = EdhrecService(dio: dio);

      // First call - cache miss
      final data1 = await service.getCommanderData('Atraxa');
      expect(networkCalls, 1);
      expect(data1.categorizedSuggestions, isNotEmpty);

      // Second call - cache hit
      final data2 = await service.getCommanderData('Atraxa');
      expect(networkCalls, 1); // No new network call
      expect(data2.categorizedSuggestions, isNotEmpty);
    });

    test('handles commandant without taglinks or combocounts', () async {
      final dio = _createMockDio((_) => _commanderJsonFixture(
            tagLinks: [],
            comboCounts: [],
          ));
      final service = EdhrecService(dio: dio);

      final data = await service.getCommanderData('Simple Commander');

      expect(data.themes, isEmpty);
      expect(data.topCombos, isEmpty);
      expect(data.categorizedSuggestions, isNotEmpty); // Still has suggestions
    });
  });

  // ============================================================
  // getThemeCards
  // ============================================================

  group('EdhrecService.getThemeCards', () {
    test('parses theme cards correctly', () async {
      final dio = _createMockDio((_) => _themeJsonFixture());
      final service = EdhrecService(dio: dio);

      final cards = await service.getThemeCards('Atraxa', 'infect');

      expect(cards, hasLength(2));
      expect(cards[0].name, 'Blighted Agent');
      expect(cards[0].synergy, 0.55);
      expect(cards[1].name, 'Glistener Elf');
    });

    test('returns empty on error', () async {
      final dio = _createMockDio((_) => {}, shouldThrow: true);
      final service = EdhrecService(dio: dio);

      final cards = await service.getThemeCards('Atraxa', 'infect');

      expect(cards, isEmpty);
    });

    test('caches theme cards on second call', () async {
      int networkCalls = 0;
      final dio = _createMockDio(
        (_) => _themeJsonFixture(),
        callCounter: (_) => networkCalls++,
      );
      final service = EdhrecService(dio: dio);

      await service.getThemeCards('Atraxa', 'infect');
      expect(networkCalls, 1);

      await service.getThemeCards('Atraxa', 'infect');
      expect(networkCalls, 1); // Cache hit
    });

    test('returns empty for 404 response', () async {
      final dio = _createMockDio((_) => {}, statusCode: 404);
      final service = EdhrecService(dio: dio);

      final cards = await service.getThemeCards('Atraxa', 'nonexistent');

      expect(cards, isEmpty);
    });
  });

  // ============================================================
  // getCommanderCombos
  // ============================================================

  group('EdhrecService.getCommanderCombos', () {
    test('parses combos correctly', () async {
      final dio = _createMockDio((_) => _combosJsonFixture(comboCount: 3));
      final service = EdhrecService(dio: dio);

      final combos = await service.getCommanderCombos('Atraxa');

      expect(combos, hasLength(3));
      expect(combos[0].deckCount, 10000); // Sorted by deckCount desc
      expect(combos[0].cardNames, ['Card A0', 'Card B0']);
      expect(combos[0].results, ['Infinite damage']);
    });

    test('limits to 50 combos', () async {
      final dio = _createMockDio((_) => _combosJsonFixture(comboCount: 80));
      final service = EdhrecService(dio: dio);

      final combos = await service.getCommanderCombos('Atraxa');

      expect(combos.length, 50); // Max 50
    });

    test('returns empty on error', () async {
      final dio = _createMockDio((_) => {}, shouldThrow: true);
      final service = EdhrecService(dio: dio);

      final combos = await service.getCommanderCombos('Atraxa');

      expect(combos, isEmpty);
    });

    test('caches combos on second call', () async {
      int networkCalls = 0;
      final dio = _createMockDio(
        (_) => _combosJsonFixture(comboCount: 5),
        callCounter: (_) => networkCalls++,
      );
      final service = EdhrecService(dio: dio);

      await service.getCommanderCombos('Atraxa');
      expect(networkCalls, 1);

      await service.getCommanderCombos('Atraxa');
      expect(networkCalls, 1); // Cache hit
    });

    test('returns empty for 404 response', () async {
      final dio = _createMockDio((_) => {}, statusCode: 404);
      final service = EdhrecService(dio: dio);

      final combos = await service.getCommanderCombos('Unknown');

      expect(combos, isEmpty);
    });

    test('sorts combos by deckCount descending', () async {
      final fixture = {
        'container': {
          'json_dict': {
            'cardlists': [
              {
                'header': 'Low combo',
                'cardviews': [
                  {'name': 'Card Low'}
                ],
                'combo': {'comboId': 1, 'count': 100, 'rank': 3},
              },
              {
                'header': 'High combo',
                'cardviews': [
                  {'name': 'Card High'}
                ],
                'combo': {'comboId': 2, 'count': 5000, 'rank': 1},
              },
              {
                'header': 'Mid combo',
                'cardviews': [
                  {'name': 'Card Mid'}
                ],
                'combo': {'comboId': 3, 'count': 1000, 'rank': 2},
              },
            ],
          },
        },
      };
      final dio = _createMockDio((_) => fixture);
      final service = EdhrecService(dio: dio);

      final combos = await service.getCommanderCombos('Test');

      expect(combos[0].deckCount, 5000);
      expect(combos[1].deckCount, 1000);
      expect(combos[2].deckCount, 100);
    });
  });

  // ============================================================
  // clearCache
  // ============================================================

  group('EdhrecService.clearCache', () {
    test('forces new network call after clearing', () async {
      int networkCalls = 0;
      final dio = _createMockDio(
        (_) => _commanderJsonFixture(),
        callCounter: (_) => networkCalls++,
      );
      final service = EdhrecService(dio: dio);

      await service.getCommanderData('Atraxa');
      expect(networkCalls, 1);

      service.clearCache();

      await service.getCommanderData('Atraxa');
      expect(networkCalls, 2); // Cache was cleared
    });
  });

  // ============================================================
  // getRecommendations (retrocompatibilite)
  // ============================================================

  group('EdhrecService.getRecommendations (retrocompat)', () {
    test('still returns Map<String, List<String>> format', () async {
      final dio = _createMockDio((_) => _commanderJsonFixture());
      final service = EdhrecService(dio: dio);

      final results = await service.getRecommendations('Atraxa');

      expect(results, isA<Map<String, List<String>>>());
      expect(results.containsKey('Haute Synergie'), true);
      expect(results['Haute Synergie'], contains('Sword of Truth and Justice'));
    });
  });
}
