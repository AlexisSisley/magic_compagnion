// Fichier : lib/widgets/dashboard/dashboard_collection_summary.dart
// Resume de la collection (nb cartes + valeur totale).

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/price_helper.dart';

class DashboardCollectionSummary extends StatelessWidget {
  final int totalCards;
  final double totalValue;
  final bool isLoadingValue;

  const DashboardCollectionSummary({
    super.key,
    required this.totalCards,
    required this.totalValue,
    required this.isLoadingValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryShade900.withValues(alpha: 0.25),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              icon: Icons.inventory_2_outlined,
              label: 'Cartes',
              value: totalCards.toString(),
              color: AppColors.accent,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppColors.borderMedium,
          ),
          Expanded(
            child: isLoadingValue
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGold,
                      ),
                    ),
                  )
                : _StatColumn(
                    icon: Icons.euro,
                    label: 'Valeur',
                    value: PriceHelper.formatValue(totalValue),
                    color: AppColors.accentGreen,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.sectionTitle(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.label(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
