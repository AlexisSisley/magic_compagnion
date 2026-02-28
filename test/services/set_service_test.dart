// Tests pour SetService avec injection ScryfallApiService (Sprint 5)

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/set_service.dart';

/// Mock ScryfallApiService pour les tests.
class _MockScryfallApi extends ScryfallApiService {
  final Map<String, dynamic>? _setsData;
  final bool _shouldThrow;

  _MockScryfallApi({Map<String, dynamic>? setsData, bool shouldThrow = false})
      : _setsData = setsData,
        _shouldThrow = shouldThrow;

  @override
  Future<Map<String, dynamic>> getAllSets() async {
    if (_shouldThrow) throw Exception('Network error');
    return _setsData ?? {'data': []};
  }
}

void main() {
  group('SetService', () {
    test('getAllSets returns parsed sets from API', () async {
      final api = _MockScryfallApi(setsData: {
        'data': [
          {
            'id': 'lea-id',
            'code': 'lea',
            'name': 'Limited Edition Alpha',
            'set_type': 'core',
            'released_at': '1993-08-05',
            'card_count': 295,
            'icon_svg_uri': 'https://svgs.scryfall.io/sets/lea.svg',
          },
          {
            'id': 'leb-id',
            'code': 'leb',
            'name': 'Limited Edition Beta',
            'set_type': 'core',
            'released_at': '1993-10-01',
            'card_count': 302,
            'icon_svg_uri': 'https://svgs.scryfall.io/sets/leb.svg',
          },
        ],
      });

      final service = SetService(api: api);
      final sets = await service.getAllSets();
      expect(sets, hasLength(2));
      expect(sets.first.code, 'lea');
      expect(sets.last.code, 'leb');
    });

    test('getAllSets returns empty list on error', () async {
      final api = _MockScryfallApi(shouldThrow: true);
      final service = SetService(api: api);

      final sets = await service.getAllSets();
      expect(sets, isEmpty);
    });

    test('getAllSets returns empty list when data is empty', () async {
      final api = _MockScryfallApi(setsData: {'data': []});
      final service = SetService(api: api);

      final sets = await service.getAllSets();
      expect(sets, isEmpty);
    });

    test('SetService works without injected API', () {
      final service = SetService();
      expect(service, isNotNull);
    });
  });
}
