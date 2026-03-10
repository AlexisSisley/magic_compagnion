// Fichier : lib/widgets/dashboard/dashboard_widget_wrapper.dart
// Conteneur commun pour tous les widgets du dashboard.
// En mode edition : bordure gold pointillee + controles.

import 'package:flutter/material.dart';

import '../../models/dashboard_config_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class DashboardWidgetWrapper extends StatelessWidget {
  final Widget child;
  final bool editMode;
  final bool visible;
  final DashboardWidgetSize size;
  final VoidCallback? onToggleVisibility;
  final ValueChanged<DashboardWidgetSize>? onResize;

  const DashboardWidgetWrapper({
    super.key,
    required this.child,
    this.editMode = false,
    this.visible = true,
    this.size = DashboardWidgetSize.medium,
    this.onToggleVisibility,
    this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: visible ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: editMode
                ? [
                    AppColors.primaryShade900.withValues(alpha: 0.3),
                    AppColors.cardBackground,
                  ]
                : [
                    AppColors.cardBackground,
                    AppColors.surfaceDark.withValues(alpha: 0.9),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: editMode
                ? AppColors.primaryGold
                : AppColors.borderMedium,
            width: editMode ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: editMode ? _buildEditContent() : child,
      ),
    );
  }

  Widget _buildEditContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.drag_handle,
                color: AppColors.textMuted, size: 20),
            const Spacer(),
            // Size cycle button
            GestureDetector(
              onTap: () {
                if (onResize == null) return;
                final next = DashboardWidgetSize
                    .values[(size.index + 1) % DashboardWidgetSize.values.length];
                onResize!(next);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  size.name.toUpperCase()[0],
                  style: AppTextStyles.label(
                    color: AppColors.primaryGold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Visibility toggle
            GestureDetector(
              onTap: onToggleVisibility,
              child: Icon(
                visible ? Icons.visibility : Icons.visibility_off,
                color: visible ? AppColors.primaryGold : AppColors.textDisabled,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
