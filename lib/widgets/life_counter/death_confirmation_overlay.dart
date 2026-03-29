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
  /// Death reason: 'life', 'poison', 'commander', or null (defaults to life).
  final String? deathReason;

  const DeathConfirmationOverlay({
    super.key,
    required this.playerName,
    required this.currentLife,
    required this.onDismiss,
    required this.onConfirmElimination,
    this.deathReason,
  });

  String get _reasonEmoji {
    switch (deathReason) {
      case 'poison': return '\u{2620}\u{FE0F}'; // ☠️
      case 'commander': return '\u{1F6E1}\u{FE0F}'; // 🛡️
      default: return '\u{1F480}'; // 💀
    }
  }

  String get _reasonLabel {
    switch (deathReason) {
      case 'poison': return 'Poison l\u{00E9}tal !';
      case 'commander': return 'D\u{00E9}g\u{00E2}ts de commandant !';
      default: return '$currentLife PV';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.overlayDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_reasonEmoji $playerName',
                  style: AppTextStyles.bold(color: AppColors.textPrimary, fontSize: 14),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$_reasonLabel \u{2014} \u{00C9}limin\u{00E9} ?',
                  style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Non',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: onConfirmElimination,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Oui',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
