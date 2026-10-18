// Fichier : lib/widgets/life_counter/player_header.dart
// Sub-widget extracted from PlayerZone: header with palette and player name.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Displays the top-right palette button and, optionally, the player name
/// (center-top) with a tap callback.
/// Pure display + gesture forwarding, no business logic.
///
/// Tâche 8b : le bouton de rotation (en haut à gauche) est retiré, avec son
/// appui long « glisser pour tourner ». Il faisait tourner la zone d'un
/// quart de tour par appui : trois appuis pour 270°, sans rien qui dise où
/// l'on va (spec §1.7). Le sélecteur à quatre flèches du mode
/// réorganisation le remplace. Le nom garde sa marge gauche de 48 pour
/// rester centré face au bouton palette.
class PlayerHeader extends StatelessWidget {
  const PlayerHeader({
    super.key,
    required this.onShowColorPicker,
    this.playerName,
    this.onNameTap,
  });

  final VoidCallback onShowColorPicker;

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
                style: AppTextStyles.text(
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
