// Test : lib/utils/price_helper.dart (Sprint 14, US-14.1)

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/utils/price_helper.dart';

void main() {
  group('PriceHelper', () {
    final prices = <String, dynamic>{
      'eur': '12.50',
      'eur_foil': '25.00',
      'usd': '14.00',
      'usd_foil': '30.00',
    };

    final emptyPrices = <String, dynamic>{};

    final nullPrices = <String, dynamic>{
      'eur': null,
      'eur_foil': null,
      'usd': null,
      'usd_foil': null,
    };

    group('parsePrice', () {
      test('extrait le prix EUR normal', () {
        expect(PriceHelper.parsePrice(prices), 12.50);
      });

      test('extrait le prix EUR foil', () {
        expect(PriceHelper.parsePrice(prices, isFoil: true), 25.00);
      });

      test('extrait le prix USD normal', () {
        expect(
          PriceHelper.parsePrice(prices, currency: PriceCurrency.usd),
          14.00,
        );
      });

      test('extrait le prix USD foil', () {
        expect(
          PriceHelper.parsePrice(prices,
              isFoil: true, currency: PriceCurrency.usd),
          30.00,
        );
      });

      test('retourne null si prix absent', () {
        expect(PriceHelper.parsePrice(emptyPrices), isNull);
      });

      test('retourne null si prix null', () {
        expect(PriceHelper.parsePrice(nullPrices), isNull);
      });
    });

    group('rawPrice', () {
      test('retourne le string brut', () {
        expect(PriceHelper.rawPrice(prices), '12.50');
      });

      test('retourne null si absent', () {
        expect(PriceHelper.rawPrice(emptyPrices), isNull);
      });
    });

    group('bestPrice', () {
      test('retourne le prix EUR si disponible', () {
        expect(PriceHelper.bestPrice(prices), 12.50);
      });

      test('retourne le prix USD si EUR absent', () {
        final usdOnly = <String, dynamic>{'usd': '14.00'};
        expect(PriceHelper.bestPrice(usdOnly), 14.00);
      });

      test('retourne 0.0 si aucun prix', () {
        expect(PriceHelper.bestPrice(emptyPrices), 0.0);
      });

      test('retourne le prix foil quand demande', () {
        expect(PriceHelper.bestPrice(prices, isFoil: true), 25.00);
      });
    });

    group('format', () {
      test('formate un prix EUR', () {
        expect(PriceHelper.format(prices), '12.50 \u20AC');
      });

      test('retourne N/A si absent', () {
        expect(PriceHelper.format(emptyPrices), 'N/A');
      });

      test('respecte le fallback custom', () {
        expect(
          PriceHelper.format(emptyPrices, fallback: '--'),
          '--',
        );
      });
    });

    group('formatCompact', () {
      test('formate un prix compact EUR', () {
        expect(PriceHelper.formatCompact(prices), '12.50\u20AC');
      });

      test('retourne -- si absent', () {
        expect(PriceHelper.formatCompact(emptyPrices), '--');
      });
    });

    group('formatValue', () {
      test('formate une valeur double en EUR', () {
        expect(PriceHelper.formatValue(12.5), '12.50 \u20AC');
      });

      test('formate une valeur double en USD', () {
        expect(
          PriceHelper.formatValue(12.5, currency: PriceCurrency.usd),
          '12.50 \$',
        );
      });
    });

    group('compareByPrice', () {
      final pricesA = <String, dynamic>{'eur': '5.00'};
      final pricesB = <String, dynamic>{'eur': '10.00'};

      test('compare ascending', () {
        expect(PriceHelper.compareByPrice(pricesA, pricesB), lessThan(0));
      });

      test('compare descending', () {
        expect(
          PriceHelper.compareByPrice(pricesA, pricesB, ascending: false),
          greaterThan(0),
        );
      });

      test('gere les prix absents (traites comme 0)', () {
        expect(
          PriceHelper.compareByPrice(emptyPrices, pricesB),
          lessThan(0),
        );
      });
    });
  });
}
