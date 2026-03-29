// Fichier : lib/widgets/life_counter/player_header.dart
// Sub-widget extracted from PlayerZone: header with palette and rotation controls.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Displays the top-right palette button and top-left rotation button.
/// Pure display + gesture forwarding, no business logic.
class PlayerHeader extends StatelessWidget {
  const PlayerHeader({
    super.key,
    required this.onShowColorPicker,
    required this.onRotate,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
  });

  final VoidCallback onShowColorPicker;
  final VoidCallback onRotate;
  final void Function(LongPressStartDetails) onLongPressStart;
  final void Function(LongPressMoveUpdateDetails) onLongPressMoveUpdate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Palette button (top-right)
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.palette, color: AppColors.borderMedium, size: 20),
            onPressed: onShowColorPicker,
          ),
        ),
        // Rotation button (top-left)
        Positioned(
          top: 0,
          left: 0,
          child: GestureDetector(
            onTap: onRotate,
            onLongPressStart: onLongPressStart,
            onLongPressMoveUpdate: onLongPressMoveUpdate,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.transparent,
              child: const Icon(Icons.rotate_right, color: AppColors.borderMedium, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
