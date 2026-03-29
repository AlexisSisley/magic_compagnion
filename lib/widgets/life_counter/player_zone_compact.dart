// Fichier : lib/widgets/life_counter/player_zone_compact.dart
// Task 16: Compact player zone for adversaries in Focus mode

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// A minimal compact card showing player name, life total, and color.
/// Used for adversaries in Focus layout mode.
class PlayerZoneCompact extends StatelessWidget {
  final String playerName;
  final int lifeTotal;
  final Color playerColor;
  final bool isEliminated;
  final VoidCallback? onTap;

  const PlayerZoneCompact({
    super.key,
    required this.playerName,
    required this.lifeTotal,
    required this.playerColor,
    this.isEliminated = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isEliminated
              ? AppColors.surfaceDarkest.withAlpha(200)
              : playerColor.withAlpha(80),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: playerColor.withAlpha(150),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              playerName,
              style: AppTextStyles.label(
                color: isEliminated ? AppColors.textMuted : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              isEliminated ? '☠' : '$lifeTotal',
              style: TextStyle(
                fontSize: isEliminated ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: isEliminated ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
