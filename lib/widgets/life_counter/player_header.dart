// Fichier : lib/widgets/life_counter/player_header.dart
// Sub-widget extracted from PlayerZone: header with palette and rotation controls.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Displays the top-right palette button and top-left rotation button.
/// Also optionally shows the player name (center-top) with a tap callback.
/// Pure display + gesture forwarding, no business logic.
class PlayerHeader extends StatelessWidget {
  const PlayerHeader({
    super.key,
    required this.onShowColorPicker,
    required this.onRotate,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    this.playerName,
    this.onNameTap,
  });

  final VoidCallback onShowColorPicker;
  final VoidCallback onRotate;
  final void Function(LongPressStartDetails) onLongPressStart;
  final void Function(LongPressMoveUpdateDetails) onLongPressMoveUpdate;

  /// The player's display name shown in the center of the header.
  final String? playerName;

  /// Optional callback triggered when the player name is tapped.
  /// When non-null, the name is rendered with an underline to hint it is tappable.
  final VoidCallback? onNameTap;

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
        // Player name (center-top)
        if (playerName != null)
          Positioned(
            top: 4,
            left: 48,
            right: 48,
            child: GestureDetector(
              onTap: onNameTap,
              child: Text(
                playerName!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cinzel(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ).copyWith(
                  decoration: onNameTap != null
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
