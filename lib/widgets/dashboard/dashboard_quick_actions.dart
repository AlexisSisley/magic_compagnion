// Fichier : lib/widgets/dashboard/dashboard_quick_actions.dart
// Actions rapides : Scanner, Nouveau Deck, Recherche, Collection.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickActionButton(
          icon: Icons.camera_alt,
          label: 'Scanner',
          onTap: () => context.go(AppRoutes.scanner),
        ),
        const SizedBox(width: 10),
        _QuickActionButton(
          icon: Icons.add_circle_outline,
          label: 'Deck',
          onTap: () => context.go(AppRoutes.decks),
        ),
        const SizedBox(width: 10),
        _QuickActionButton(
          icon: Icons.search,
          label: 'Recherche',
          onTap: () => context.go(AppRoutes.search),
        ),
        const SizedBox(width: 10),
        _QuickActionButton(
          icon: Icons.inventory_2_outlined,
          label: 'Collection',
          onTap: () => context.go(AppRoutes.collection),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceDark,
                  AppColors.cardBackground.withValues(alpha: 0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryShade800.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.primaryGold, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTextStyles.label(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
