// Fichier : lib/widgets/dashboard/dashboard_section_header.dart
// Header de section reutilisable pour le dashboard.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class DashboardSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onSeeAll;

  const DashboardSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGold, size: 18),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.sectionTitle(fontSize: 16)),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Voir tout',
                  style: AppTextStyles.label(
                    color: AppColors.accent,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
