// Fichier : lib/widgets/dashboard/collection_value_chart.dart
// Sprint 14, US-14.7 : Graphique d'evolution de la valeur de la collection (30j).
// Utilise fl_chart LineChart avec gradient sous la courbe et tooltip date+valeur.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Graphique LineChart montrant l'evolution du prix de la collection sur 30 jours.
class CollectionValueChart extends StatelessWidget {
  /// Liste de points (dateKey format "YYYY-M-D", value en EUR).
  final List<({String dateKey, double value})> dataPoints;

  /// Hauteur du graphique.
  final double height;

  /// Affiche un mini-mode compact (pour le dashboard preview).
  final bool compact;

  const CollectionValueChart({
    super.key,
    required this.dataPoints,
    this.height = 220,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return _buildPlaceholder();
    }

    final spots = _buildSpots();
    if (spots.length < 2) {
      return _buildPlaceholder();
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPadding = (maxY - minY) * 0.1;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: compact ? 0 : 8,
          right: compact ? 0 : 16,
          top: compact ? 0 : 8,
          bottom: compact ? 0 : 4,
        ),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: !compact,
              drawVerticalLine: false,
              horizontalInterval: _computeInterval(minY, maxY),
              getDrawingHorizontalLine: (value) => const FlLine(
                color: AppColors.borderLight,
                strokeWidth: 0.5,
              ),
            ),
            titlesData: compact
                ? const FlTitlesData(show: false)
                : FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}e',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: _bottomInterval(spots.length),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= dataPoints.length) {
                            return const SizedBox.shrink();
                          }
                          final date = _parseDate(dataPoints[index].dateKey);
                          if (date == null) return const SizedBox.shrink();
                          return Text(
                            DateFormat('dd/MM').format(date),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (spots.length - 1).toDouble(),
            minY: (minY - yPadding).clamp(0, double.infinity),
            maxY: maxY + yPadding,
            lineTouchData: compact
                ? const LineTouchData(enabled: false)
                : LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          String dateLabel = '';
                          if (index >= 0 && index < dataPoints.length) {
                            final date =
                                _parseDate(dataPoints[index].dateKey);
                            if (date != null) {
                              dateLabel =
                                  DateFormat('dd MMM', 'fr_FR').format(date);
                            }
                          }
                          return LineTooltipItem(
                            '$dateLabel\n${spot.y.toStringAsFixed(2)} EUR',
                            AppTextStyles.label(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                preventCurveOverShooting: true,
                color: AppColors.primaryGold,
                barWidth: compact ? 2 : 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: !compact,
                  // ignore: unnecessary_underscores
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.primaryGold,
                    strokeWidth: 1,
                    strokeColor: AppColors.scaffoldBackground,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryGold.withValues(alpha: 0.3),
                      AppColors.primaryGold.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    return List.generate(dataPoints.length, (i) {
      return FlSpot(i.toDouble(), dataPoints[i].value);
    });
  }

  double _computeInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 10) return 2;
    if (range <= 50) return 10;
    if (range <= 200) return 50;
    if (range <= 1000) return 200;
    return (range / 5).roundToDouble();
  }

  double _bottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 15) return 3;
    return 5;
  }

  DateTime? _parseDate(String dateKey) {
    try {
      final parts = dateKey.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return null;
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, color: AppColors.textDisabled, size: 48),
            const SizedBox(height: 12),
            Text(
              'Pas encore de donnees',
              style: AppTextStyles.subtitle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Le graphique apparaitra apres quelques jours\nd\'utilisation de votre collection.',
              textAlign: TextAlign.center,
              style: AppTextStyles.label(
                color: AppColors.textDisabled,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
