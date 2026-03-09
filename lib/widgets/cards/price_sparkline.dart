// Fichier : lib/widgets/cards/price_sparkline.dart
// Sprint 14, US-14.10 : Mini graphique sparkline inline pour le prix d'une carte.
// Affiche l'evolution du prix sur 30 jours dans card_detail_page.
// Note : L'API Scryfall ne fournit pas d'historique de prix par carte.
// Ce widget affiche les donnees de CollectionValueHistory comme proxy,
// ou un placeholder si pas de donnees.
// A terme, un backend prix pourrait alimenter des donnees par carte.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Mini sparkline affichant une tendance de prix.
/// Concu pour etre inline dans une fiche carte (hauteur ~60px).
class PriceSparkline extends StatelessWidget {
  /// Points de donnees (valeurs brutes, l'axe X est implicite).
  final List<double> values;

  /// Hauteur du sparkline.
  final double height;

  /// Largeur du sparkline (null = expand).
  final double? width;

  /// Couleur de la ligne (par defaut or MTG).
  final Color lineColor;

  /// Label optionnel affiche sous le sparkline.
  final String? label;

  const PriceSparkline({
    super.key,
    required this.values,
    this.height = 50,
    this.width,
    this.lineColor = AppColors.primaryGold,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return _buildNoDataPlaceholder();
    }

    final spots = List.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i]),
    );

    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding = range * 0.15;

    // Determine la couleur selon la tendance
    final trend = values.last - values.first;
    final effectiveColor = trend >= 0 ? AppColors.accentGreen : AppColors.accentRed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          width: width,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
              minY: (minY - padding).clamp(0, double.infinity),
              maxY: maxY + padding,
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  preventCurveOverShooting: true,
                  color: effectiveColor,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        effectiveColor.withValues(alpha: 0.2),
                        effectiveColor.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 300),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            style: AppTextStyles.label(
              color: AppColors.textDisabled,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoDataPlaceholder() {
    return SizedBox(
      height: height,
      width: width,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, color: AppColors.textDisabled, size: 16),
            const SizedBox(width: 6),
            Text(
              'Historique non disponible',
              style: AppTextStyles.label(
                color: AppColors.textDisabled,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
