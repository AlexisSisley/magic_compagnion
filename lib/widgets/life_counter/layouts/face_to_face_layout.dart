// Fichier : lib/widgets/life_counter/layouts/face_to_face_layout.dart
// Task 16: Face-to-face layout for 2 players (top rotated 180°)

import 'package:flutter/material.dart';

/// Two-player layout: zones stacked vertically, top player rotated 180°
/// so both players can read their zone when the phone is flat on the table.
class FaceToFaceLayout extends StatelessWidget {
  /// The widget for player at index 0 (top, rotated 180°).
  final Widget topPlayer;

  /// The widget for player at index 1 (bottom, normal orientation).
  final Widget bottomPlayer;

  const FaceToFaceLayout({
    super.key,
    required this.topPlayer,
    required this.bottomPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 2,
            child: topPlayer,
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: bottomPlayer,
        ),
      ],
    );
  }
}
