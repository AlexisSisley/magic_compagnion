import 'dart:math';
import 'package:flutter/material.dart';

/// Single layout widget for 2-8 players with a central bar slot.
///
/// Layout rule:
///   topCount = ceil(playerCount / 2)
///   bottomCount = playerCount - topCount
///
/// Top row is rotated 180° for face-to-face table play.
/// Special case: 8 players → each half becomes a 2×2 sub-grid.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> playerZones;
  final Widget centralBar;

  const AdaptiveGrid({
    super.key,
    required this.playerZones,
    required this.centralBar,
  });

  @override
  Widget build(BuildContext context) {
    final int playerCount = playerZones.length;
    final int topCount = (playerCount / 2).ceil();
    final int bottomCount = playerCount - topCount;

    final topZones = playerZones.sublist(0, topCount);
    final bottomZones = playerZones.sublist(topCount);

    return Column(
      children: [
        Expanded(
          child: _buildHalf(
            zones: topZones,
            rotate: true,
            useSubGrid: playerCount == 8,
          ),
        ),
        centralBar,
        Expanded(
          child: _buildHalf(
            zones: bottomZones,
            rotate: false,
            useSubGrid: playerCount == 8,
          ),
        ),
      ],
    );
  }

  Widget _buildHalf({
    required List<Widget> zones,
    required bool rotate,
    required bool useSubGrid,
  }) {
    if (useSubGrid && zones.length == 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                for (int i = 0; i < 2; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: rotate
                          ? RotatedBox(quarterTurns: 2, child: zones[i])
                          : zones[i],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                for (int i = 2; i < 4; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: rotate
                          ? RotatedBox(quarterTurns: 2, child: zones[i])
                          : zones[i],
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: zones
          .map((zone) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: rotate
                      ? RotatedBox(quarterTurns: 2, child: zone)
                      : zone,
                ),
              ))
          .toList(),
    );
  }
}
