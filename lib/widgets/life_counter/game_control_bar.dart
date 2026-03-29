// Fichier : lib/widgets/life_counter/game_control_bar.dart
// Task 16: Floating control bar for in-game actions

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Floating bar with game controls: dice, timer, switch layout, settings, end game.
class GameControlBar extends StatelessWidget {
  final VoidCallback? onDiceRoll;
  final VoidCallback? onTimerToggle;
  final VoidCallback? onSwitchLayout;
  final VoidCallback? onSettings;
  final VoidCallback? onEndGame;
  final String? timerText;

  const GameControlBar({
    super.key,
    this.onDiceRoll,
    this.onTimerToggle,
    this.onSwitchLayout,
    this.onSettings,
    this.onEndGame,
    this.timerText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withAlpha(230),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BarButton(
            icon: Icons.casino,
            tooltip: 'Roll Dice',
            onTap: onDiceRoll,
          ),
          if (timerText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: onTimerToggle,
                child: Text(
                  timerText!,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            )
          else
            _BarButton(
              icon: Icons.timer,
              tooltip: 'Timer',
              onTap: onTimerToggle,
            ),
          _BarButton(
            icon: Icons.grid_view,
            tooltip: 'Switch Layout',
            onTap: onSwitchLayout,
          ),
          _BarButton(
            icon: Icons.settings,
            tooltip: 'Settings',
            onTap: onSettings,
          ),
          _BarButton(
            icon: Icons.stop_circle_outlined,
            tooltip: 'End Game',
            onTap: onEndGame,
            iconColor: AppColors.accentRed,
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _BarButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onTap,
      color: iconColor ?? AppColors.textPrimary,
      iconSize: 22,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}
