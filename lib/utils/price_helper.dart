// Fichier : lib/utils/price_helper.dart
// Sprint 14, US-14.1 : Helper centralise pour les prix Scryfall.
// Remplace 30+ patterns dupliques de lecture/parsing/affichage des prix.

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Currencies supportees par Scryfall.
enum PriceCurrency { eur, usd }

/// Helper centralise pour toutes les operations sur les prix Scryfall.
///
/// Les prix Scryfall arrivent sous forme de `Map<String, dynamic>` avec les cles :
/// `eur`, `eur_foil`, `usd`, `usd_foil` (valeurs = String ou null).
abstract final class PriceHelper {
  // ============================================================
  // PARSING
  // ============================================================

  /// Extrait le prix numerique d'une carte (normal ou foil).
  /// Retourne `null` si le prix n'est pas disponible.
  static double? parsePrice(
    Map<String, dynamic> prices, {
    bool isFoil = false,
    PriceCurrency currency = PriceCurrency.eur,
  }) {
    final key = _priceKey(currency, isFoil: isFoil);
    final value = prices[key];
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  /// Extrait le prix sous forme de String (ex: "12.50") ou `null`.
  static String? rawPrice(
    Map<String, dynamic> prices, {
    bool isFoil = false,
    PriceCurrency currency = PriceCurrency.eur,
  }) {
    final key = _priceKey(currency, isFoil: isFoil);
    final value = prices[key];
    return value?.toString();
  }

  /// Retourne le meilleur prix disponible (normal puis foil, EUR puis USD).
  /// Utile pour les calculs de valeur de collection.
  static double bestPrice(Map<String, dynamic> prices, {bool isFoil = false}) {
    // Essaie EUR d'abord, puis USD
    final eur = parsePrice(prices, isFoil: isFoil, currency: PriceCurrency.eur);
    if (eur != null) return eur;
    final usd = parsePrice(prices, isFoil: isFoil, currency: PriceCurrency.usd);
    return usd ?? 0.0;
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  /// Formate un prix pour affichage (ex: "12.50 EUR", "N/A").
  static String format(
    Map<String, dynamic> prices, {
    bool isFoil = false,
    PriceCurrency currency = PriceCurrency.eur,
    String fallback = 'N/A',
  }) {
    final raw = rawPrice(prices, isFoil: isFoil, currency: currency);
    if (raw == null) return fallback;
    final symbol = currency == PriceCurrency.eur ? '\u20AC' : '\$';
    return '$raw $symbol';
  }

  /// Formate un prix compact pour les listes (ex: "12.50\u20AC" ou "--").
  static String formatCompact(
    Map<String, dynamic> prices, {
    bool isFoil = false,
    PriceCurrency currency = PriceCurrency.eur,
    String fallback = '--',
  }) {
    final raw = rawPrice(prices, isFoil: isFoil, currency: currency);
    if (raw == null) return fallback;
    final symbol = currency == PriceCurrency.eur ? '\u20AC' : '\$';
    return '$raw$symbol';
  }

  /// Formate un double en prix (ex: 12.5 -> "12.50 EUR").
  static String formatValue(
    double value, {
    PriceCurrency currency = PriceCurrency.eur,
  }) {
    final symbol = currency == PriceCurrency.eur ? '\u20AC' : '\$';
    return '${value.toStringAsFixed(2)} $symbol';
  }

  // ============================================================
  // COMPARISON / SORTING
  // ============================================================

  /// Compare deux cartes par prix (pour le tri).
  /// Retourne un int compatible avec `Comparator<T>`.
  static int compareByPrice(
    Map<String, dynamic> pricesA,
    Map<String, dynamic> pricesB, {
    bool ascending = true,
    bool isFoil = false,
    PriceCurrency currency = PriceCurrency.eur,
  }) {
    final a = parsePrice(pricesA, isFoil: isFoil, currency: currency) ?? 0.0;
    final b = parsePrice(pricesB, isFoil: isFoil, currency: currency) ?? 0.0;
    return ascending ? a.compareTo(b) : b.compareTo(a);
  }

  // ============================================================
  // PRIVATE
  // ============================================================

  static String _priceKey(PriceCurrency currency, {required bool isFoil}) {
    final base = currency == PriceCurrency.eur ? 'eur' : 'usd';
    return isFoil ? '${base}_foil' : base;
  }
}

/// Widget reutilisable pour afficher un prix sous forme de tag.
///
/// Usage :
/// ```dart
/// PriceTag(prices: card.prices)
/// PriceTag(prices: card.prices, isFoil: true, style: PriceTagStyle.compact)
/// PriceTag.detailed(prices: card.prices)
/// ```
class PriceTag extends StatelessWidget {
  final Map<String, dynamic> prices;
  final bool isFoil;
  final PriceCurrency currency;
  final PriceTagStyle style;
  final double? fontSize;

  const PriceTag({
    super.key,
    required this.prices,
    this.isFoil = false,
    this.currency = PriceCurrency.eur,
    this.style = PriceTagStyle.compact,
    this.fontSize,
  });

  /// Affiche les prix normal ET foil cote a cote.
  const factory PriceTag.detailed({
    Key? key,
    required Map<String, dynamic> prices,
    PriceCurrency currency,
    double? fontSize,
  }) = _DetailedPriceTag;

  @override
  Widget build(BuildContext context) {
    final text = PriceHelper.formatCompact(
      prices,
      isFoil: isFoil,
      currency: currency,
    );
    final hasPrice = PriceHelper.rawPrice(prices, isFoil: isFoil, currency: currency) != null;

    return Text(
      text,
      style: TextStyle(
        color: hasPrice
            ? (isFoil ? AppColors.amber : AppColors.primaryShade700)
            : AppColors.textMuted,
        fontSize: fontSize ?? (style == PriceTagStyle.compact ? 12 : 20),
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// Variante detaillee affichant Normal + Foil cote a cote.
class _DetailedPriceTag extends PriceTag {
  const _DetailedPriceTag({
    super.key,
    required super.prices,
    super.currency = PriceCurrency.eur,
    super.fontSize,
  }) : super(style: PriceTagStyle.detailed);

  @override
  Widget build(BuildContext context) {
    final priceEur = PriceHelper.format(prices, currency: currency);
    final priceEurFoil = PriceHelper.format(prices, isFoil: true, currency: currency);
    final effectiveFontSize = fontSize ?? 20;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(children: [
          Text('Normal', style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
          Text(priceEur, style: AppTextStyles.pageTitle(fontSize: effectiveFontSize)),
        ]),
        Container(width: 1, height: 30, color: AppColors.borderMedium),
        Column(children: [
          Text('Foil (Brillant)', style: AppTextStyles.cinzel(color: Colors.amber.shade200)),
          Text(priceEurFoil, style: AppTextStyles.pageTitle(fontSize: effectiveFontSize)),
        ]),
      ],
    );
  }
}

/// Style d'affichage du PriceTag.
enum PriceTagStyle { compact, detailed }
