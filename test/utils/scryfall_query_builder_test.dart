// Tests unitaires pour ScryfallQueryBuilder
// Verifie la construction de requetes Scryfall a partir de filtres.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/search_filters.dart';
import 'package:magic_companion/utils/scryfall_query_builder.dart';

void main() {
  // ============================================================
  // ScryfallQueryBuilder.buildQuery
  // ============================================================

  group('ScryfallQueryBuilder.buildQuery', () {
    test('returns text query alone when no filters', () {
      const filters = SearchFilters();
      final result = ScryfallQueryBuilder.buildQuery('dragon', filters);
      expect(result, 'dragon');
    });

    test('returns only filter parts when text query is empty', () {
      const filters = SearchFilters(setCode: 'mkm', rarity: 'mythic');
      final result = ScryfallQueryBuilder.buildQuery('', filters);
      expect(result, 'e:mkm r:mythic');
    });

    test('combines text query with all filter types', () {
      const filters = SearchFilters(
        setCode: 'dom',
        colors: {'R', 'U'},
        cardType: 'Creature',
        rarity: 'rare',
        minCmc: 2,
        maxCmc: 5,
        keyword: 'flying',
      );
      final result = ScryfallQueryBuilder.buildQuery('dragon', filters);
      expect(result, contains('dragon'));
      expect(result, contains('e:dom'));
      expect(result, contains('c:RU'));
      expect(result, contains('t:Creature'));
      expect(result, contains('r:rare'));
      expect(result, contains('cmc>=2'));
      expect(result, contains('cmc<=5'));
      expect(result, contains('o:"flying"'));
    });

    test('handles color filter correctly', () {
      const filters = SearchFilters(colors: {'W', 'B'});
      final result = ScryfallQueryBuilder.buildQuery('angel', filters);
      expect(result, contains('c:'));
      // Colors are joined without separator
      expect(result, matches(RegExp(r'c:[WB]{2}')));
    });

    test('handles CMC range filter', () {
      const filters = SearchFilters(minCmc: 3, maxCmc: 6);
      final result = ScryfallQueryBuilder.buildQuery('', filters);
      expect(result, 'cmc>=3 cmc<=6');
    });

    test('handles keyword with special characters stripped', () {
      const filters = SearchFilters(keyword: 'draw "a" card');
      final result = ScryfallQueryBuilder.buildQuery('', filters);
      // Quotes inside keyword are removed
      expect(result, 'o:"draw a card"');
    });

    test('returns empty string when no text and no filters', () {
      const filters = SearchFilters();
      final result = ScryfallQueryBuilder.buildQuery('', filters);
      expect(result, '');
    });
  });

  // ============================================================
  // ScryfallQueryBuilder.uniqueParam
  // ============================================================

  group('ScryfallQueryBuilder.uniqueParam', () {
    test('returns prints when setCode is present', () {
      const filters = SearchFilters(setCode: 'mkm');
      expect(ScryfallQueryBuilder.uniqueParam(filters), 'prints');
    });

    test('returns cards when no setCode', () {
      const filters = SearchFilters();
      expect(ScryfallQueryBuilder.uniqueParam(filters), 'cards');
    });
  });

  // ============================================================
  // ScryfallQueryBuilder.orderParam
  // ============================================================

  group('ScryfallQueryBuilder.orderParam', () {
    test('returns cmc for cmc sort', () {
      expect(ScryfallQueryBuilder.orderParam('cmc'), 'cmc');
    });

    test('returns eur for eur sort', () {
      expect(ScryfallQueryBuilder.orderParam('eur'), 'eur');
    });

    test('returns eur for price_desc sort', () {
      expect(ScryfallQueryBuilder.orderParam('price_desc'), 'eur');
    });

    test('returns eur for price_asc sort', () {
      expect(ScryfallQueryBuilder.orderParam('price_asc'), 'eur');
    });

    test('returns name for name sort', () {
      expect(ScryfallQueryBuilder.orderParam('name'), 'name');
    });

    test('returns name for unknown sort', () {
      expect(ScryfallQueryBuilder.orderParam('unknown'), 'name');
    });
  });
}
