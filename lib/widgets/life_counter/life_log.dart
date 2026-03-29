// Fichier : lib/widgets/life_counter/life_log.dart
// Sub-widget extracted from PlayerZone: floating change numbers overlay.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Data class for a single floating number animation.
class FloatingNumberData {
  final int id;
  final String text;
  final Color color;
  double top;
  double opacity;

  FloatingNumberData({
    required this.id,
    required this.text,
    required this.color,
    this.top = 20.0,
    this.opacity = 1.0,
  });
}

/// Displays floating change numbers (e.g., "+3", "-5") that animate upward and fade.
/// Placed as an overlay in the center of the player zone via IgnorePointer.
class LifeLog extends StatelessWidget {
  const LifeLog({
    super.key,
    required this.floatingNumbers,
  });

  final List<FloatingNumberData> floatingNumbers;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: floatingNumbers.map((n) => AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            top: n.top,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: n.opacity,
              child: Text(
                n.text,
                style: AppTextStyles.bold(color: n.color, fontSize: 48).copyWith(
                  shadows: [const Shadow(blurRadius: 4, color: AppColors.textOnPrimary)],
                ),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}
