// Fichier : lib/widgets/life_counter/setup/format_chip.dart
// Shared FormatChip widget used by QuickStartPage and AdvancedSettingsPage

import 'package:flutter/material.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Compact format chip for format selection rows.
class FormatChip extends StatelessWidget {
  final GameFormat format;
  final bool isSelected;
  final VoidCallback onTap;

  const FormatChip({
    super.key,
    required this.format,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderMedium,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              format.name,
              style: TextStyle(
                color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              '${format.startingLife}',
              style: TextStyle(
                color: isSelected ? AppColors.textOnPrimary.withAlpha(200) : AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
