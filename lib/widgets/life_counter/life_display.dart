// Fichier : lib/widgets/life_counter/life_display.dart
// Sub-widget extracted from PlayerZone: main life/counter display with +/- buttons.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'player_zone.dart' show CounterMode;

/// The central interactive area: minus button | value display | plus button.
/// Includes pulse/shake animations driven by external AnimationControllers.
class LifeDisplay extends StatelessWidget {
  const LifeDisplay({
    super.key,
    required this.displayValue,
    required this.editMode,
    required this.modeColor,
    required this.modeIcon,
    required this.onDecrement,
    required this.onDecrementLarge,
    required this.onIncrement,
    required this.onIncrementLarge,
    required this.onTapCenter,
    required this.pulseController,
    required this.pulseAnimation,
    required this.shakeController,
    required this.shakeAnimation,
  });

  final String displayValue;
  final CounterMode editMode;
  final Color modeColor;
  final IconData modeIcon;
  final VoidCallback onDecrement;
  final VoidCallback onDecrementLarge;
  final VoidCallback onIncrement;
  final VoidCallback onIncrementLarge;
  final VoidCallback onTapCenter;
  final AnimationController pulseController;
  final Animation<double> pulseAnimation;
  final AnimationController shakeController;
  final Animation<double> shakeAnimation;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Minus button
        Expanded(
          flex: 1,
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: onDecrement,
              onLongPress: onDecrementLarge,
              splashColor: Colors.black12,
              child: Center(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.remove, color: AppColors.textPrimary.withValues(alpha: 0.6), size: 48),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Center value display
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: onTapCenter,
            child: Container(
              color: AppColors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (editMode != CounterMode.life)
                    Icon(modeIcon, color: modeColor.withValues(alpha: 0.8), size: 24),
                  // US-14.3 : Animations pulse (gain vie) et shake (degats)
                  Flexible(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([pulseController, shakeController]),
                      builder: (context, child) {
                        final double scale = pulseController.isAnimating ? pulseAnimation.value : 1.0;
                        final double shakeX = shakeController.isAnimating ? shakeAnimation.value : 0.0;
                        return Transform.translate(
                          offset: Offset(shakeX, 0),
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        );
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          displayValue,
                          style: AppTextStyles.bold(
                            color: editMode == CounterMode.life ? Colors.white : modeColor,
                            fontSize: 60,
                          ).copyWith(shadows: [const Shadow(blurRadius: 5, color: AppColors.overlayMedium)]),
                        ),
                      ),
                    ),
                  ),
                  if (editMode != CounterMode.life)
                    Text(
                      editMode.name.toUpperCase().replaceAll('COMMANDERTAX', 'TAX'),
                      style: GoogleFonts.roboto(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Plus button
        Expanded(
          flex: 1,
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: onIncrement,
              onLongPress: onIncrementLarge,
              splashColor: Colors.black12,
              child: Center(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.add, color: AppColors.textPrimary.withValues(alpha: 0.6), size: 48),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
