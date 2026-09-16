// Fichier : lib/widgets/life_counter/life_log.dart
// Sub-widget extracted from PlayerZone: floating change numbers overlay.

import 'package:flutter/material.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Displays floating change numbers (e.g., "+3", "-5") that animate upward and fade.
/// Placed as an overlay in the center of the player zone via IgnorePointer.
///
/// `FloatingNumber` (le modèle, pas de type dupliqué ici) vient du notifier
/// `PlayerZoneNotifier` — c'est lui qui possède désormais le cycle de vie
/// (apparition, animation, retrait) de ces nombres.
class LifeLog extends StatelessWidget {
  const LifeLog({
    super.key,
    required this.floatingNumbers,
  });

  final List<FloatingNumber> floatingNumbers;

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
