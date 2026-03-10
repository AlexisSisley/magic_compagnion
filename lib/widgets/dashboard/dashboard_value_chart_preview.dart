// Fichier : lib/widgets/dashboard/dashboard_value_chart_preview.dart
// Preview du graphique evolution valeur 30j.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'collection_value_chart.dart';
import 'dashboard_empty_state.dart';

class DashboardValueChartPreview extends StatelessWidget {
  final List<({String dateKey, double value})> valueHistory;

  const DashboardValueChartPreview({
    super.key,
    required this.valueHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.show_chart, color: AppColors.accentGreen, size: 18),
            const SizedBox(width: 8),
            Text(
              'Evolution Valeur (30j)',
              style: AppTextStyles.sectionTitle(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (valueHistory.isEmpty)
          const DashboardEmptyState(
            icon: Icons.show_chart,
            message: 'Ajoutez des cartes pour suivre l\'evolution !',
          )
        else
          CollectionValueChart(
            dataPoints: valueHistory,
            height: 120,
            compact: true,
          ),
      ],
    );
  }
}
