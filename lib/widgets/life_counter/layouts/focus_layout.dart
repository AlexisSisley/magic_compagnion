// Fichier : lib/widgets/life_counter/layouts/focus_layout.dart
// Task 16: Focus layout for 5-8 players (owner big, adversaries compact)

import 'package:flutter/material.dart';
import 'layout_strategy.dart';

/// Focus layout: the owner gets 40% of the screen at the bottom,
/// adversaries are displayed as a horizontally-scrollable compact strip at the top.
class FocusLayout extends StatelessWidget {
  /// The owner's full-size player zone (bottom, 40% height).
  final Widget ownerZone;

  /// Compact widgets for each adversary (top strip, 60% height).
  final List<Widget> adversaryZones;

  const FocusLayout({
    super.key,
    required this.ownerZone,
    required this.adversaryZones,
  });

  @override
  Widget build(BuildContext context) {
    final config = FocusLayoutConfig.forPlayerCount(adversaryZones.length + 1);

    return Column(
      children: [
        // Adversary strip (scrollable)
        Expanded(
          flex: ((1 - config.ownerHeightRatio) * 100).round(),
          child: adversaryZones.length <= 3
              ? Row(
                  children: [
                    for (final zone in adversaryZones) Expanded(child: zone),
                  ],
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final zone in adversaryZones)
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.35,
                        child: zone,
                      ),
                  ],
                ),
        ),
        const Divider(height: 1, thickness: 1),
        // Owner zone
        Expanded(
          flex: (config.ownerHeightRatio * 100).round(),
          child: ownerZone,
        ),
      ],
    );
  }
}
