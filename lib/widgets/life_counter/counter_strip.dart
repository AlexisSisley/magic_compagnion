// Fichier : lib/widgets/life_counter/counter_strip.dart
// Sub-widget extracted from PlayerZone: bottom counter strip (poison, energy, tax, cmd damage).

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'player_zone.dart' show CounterMode;

/// Displays the bottom row of mini counters (poison, energy, commander tax)
/// plus an optional commander damage indicator.
class CounterStrip extends StatelessWidget {
  const CounterStrip({
    super.key,
    required this.editMode,
    required this.poisonValue,
    required this.energyValue,
    required this.commanderTaxValue,
    required this.totalCommanderDamage,
    required this.isCommander,
    required this.onModeSelected,
    required this.onShowCommanderDamage,
  });

  final CounterMode editMode;
  final int poisonValue;
  final int energyValue;
  final int commanderTaxValue;
  final int totalCommanderDamage;
  final bool isCommander;
  final void Function(CounterMode) onModeSelected;
  final VoidCallback onShowCommanderDamage;

  Color _getModeColor(CounterMode mode) {
    switch (mode) {
      case CounterMode.poison: return AppColors.accentGreen;
      case CounterMode.energy: return AppColors.accent;
      case CounterMode.commanderTax: return AppColors.amber;
      default: return AppColors.textPrimary;
    }
  }

  IconData _getModeIcon(CounterMode mode) {
    switch (mode) {
      case CounterMode.poison: return Icons.science;
      case CounterMode.energy: return Icons.flash_on;
      case CounterMode.commanderTax: return Icons.local_police;
      default: return Icons.favorite;
    }
  }

  Widget _buildMiniCounter(CounterMode mode, int value) {
    final bool isActive = editMode == mode;
    final Color color = _getModeColor(mode);
    final IconData icon = _getModeIcon(mode);
    final double opacity = (value > 0 || isActive) ? 1.0 : 0.7;

    return GestureDetector(
      onTap: () => onModeSelected(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.overlayDark : AppColors.overlayLight,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: color, width: 1) : Border.all(color: AppColors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color.withValues(alpha: opacity)),
            const SizedBox(width: 4),
            Text('$value', style: TextStyle(color: color.withValues(alpha: opacity), fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildCmdDamageIndicator() {
    return GestureDetector(
      onTap: onShowCommanderDamage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: AppColors.overlayLight, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.shield, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('$totalCommanderDamage', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMiniCounter(CounterMode.poison, poisonValue),
            const SizedBox(width: 8),
            _buildMiniCounter(CounterMode.energy, energyValue),
            if (isCommander) ...[
              const SizedBox(width: 8),
              _buildMiniCounter(CounterMode.commanderTax, commanderTaxValue),
              const SizedBox(width: 8),
              _buildCmdDamageIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
