// Fichier : lib/widgets/decks/mana_pips.dart

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Rangée de pastilles de couleur d'un deck (tuile et bandeau).
///
/// Les pastilles utilisent les couleurs de mana de la charte et non les SVG
/// de Scryfall : l'écran doit rester rendable hors ligne et en test. La rangée
/// réserve sa hauteur même vide, pour que ce qui l'entoure ne bouge pas selon
/// le deck.
class ManaPips extends StatelessWidget {
  final List<String> colors;
  final double size;

  const ManaPips({super.key, required this.colors, required this.size});

  static Color manaColor(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'W':
        return AppColors.manaWhite;
      case 'U':
        return AppColors.manaBlue;
      case 'B':
        return AppColors.manaBlack;
      case 'R':
        return AppColors.manaRed;
      case 'G':
        return AppColors.manaGreen;
      default:
        return AppColors.manaColorless;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, c) in colors.indexed)
            Container(
              key: ValueKey('deck-color-pip-$i'),
              width: size,
              height: size,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: manaColor(c),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
            ),
        ],
      ),
    );
  }
}
