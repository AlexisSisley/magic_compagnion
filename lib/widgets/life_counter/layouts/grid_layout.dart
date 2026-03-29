// Fichier : lib/widgets/life_counter/layouts/grid_layout.dart
// Task 16: Grid layout for 3-4 players

import 'package:flutter/material.dart';
import 'layout_strategy.dart';

/// Grid layout that arranges player zones in a 2-column grid.
/// - 3 players: 2 on top, 1 full-width on bottom
/// - 4 players: 2×2 grid
class GridLayout extends StatelessWidget {
  final List<Widget> playerZones;

  const GridLayout({
    super.key,
    required this.playerZones,
  });

  @override
  Widget build(BuildContext context) {
    final config = GridLayoutConfig.forPlayerCount(playerZones.length);

    return Column(
      children: [
        // Top row (always 2 columns, top players rotated 180°)
        Expanded(
          child: Row(
            children: [
              for (int i = 0; i < config.topRowCount; i++)
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: playerZones[i],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        // Bottom row
        Expanded(
          child: config.bottomRowFullWidth && config.bottomRowCount == 1
              ? playerZones[config.topRowCount]
              : Row(
                  children: [
                    for (int i = 0; i < config.bottomRowCount; i++)
                      Expanded(
                        child: playerZones[config.topRowCount + i],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
