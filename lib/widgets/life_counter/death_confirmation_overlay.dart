import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Overlay displayed when a player's life stays at ≤ 0 for 2 seconds.
///
/// Shows "💀 {PlayerName} est à {life} PV — Éliminé ?" with
/// "Non — corriger" (green) and "Oui — éliminé" (red) buttons.
///
/// The 2-second timer logic lives in the parent page, not here.
class DeathConfirmationOverlay extends StatelessWidget {
  final String playerName;
  final int currentLife;
  final VoidCallback onDismiss;
  final VoidCallback onConfirmElimination;

  const DeathConfirmationOverlay({
    super.key,
    required this.playerName,
    required this.currentLife,
    required this.onDismiss,
    required this.onConfirmElimination,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.overlayDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\u{1F480} $playerName est \u{00E0} $currentLife PV',
                style: AppTextStyles.bold(color: AppColors.textPrimary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '\u{00C9}limin\u{00E9} ?',
                style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Non \u{2014} corriger',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onConfirmElimination,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Oui \u{2014} \u{00E9}limin\u{00E9}',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
