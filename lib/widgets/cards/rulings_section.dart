// Fichier : lib/widgets/cards/rulings_section.dart
// Sprint 12 : Section d'affichage des rulings Scryfall avec lazy loading.

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

import '../../models/scryfall_ruling.dart';

/// Section affichant les rulings officiels d'une carte Scryfall.
/// Supporte le lazy loading et l'affichage de l'etat de chargement.
class RulingsSection extends StatelessWidget {
  final List<ScryfallRuling> rulings;
  final bool isLoading;

  const RulingsSection({
    super.key,
    required this.rulings,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (rulings.isEmpty) {
      return Text(
        'Aucune regle specifique pour cette carte',
        style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rulings.map((ruling) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ruling.date,
                style: AppTextStyles.bold(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                ruling.comment,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
