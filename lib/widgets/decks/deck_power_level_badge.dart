// Fichier : lib/widgets/decks/deck_power_level_badge.dart
// Sprint 12, US-12.2 : Badge visuel du power level Commander.
// US-12.6 : Migre vers AppColors + AppTextStyles.

import 'package:flutter/material.dart';

import '../../models/edhrec_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Badge affichant le power level estime d'un deck Commander.
/// Affiche le score (1-10), le label (Casual/Focused/etc.) et une couleur.
/// Cliquable pour afficher les facteurs detailles.
class DeckPowerLevelBadge extends StatelessWidget {
  final DeckPowerLevel powerLevel;

  const DeckPowerLevelBadge({super.key, required this.powerLevel});

  Color _colorForScore(int score) {
    if (score <= 3) return AppColors.powerCasual;
    if (score <= 5) return AppColors.powerFocused;
    if (score <= 7) return AppColors.powerOptimized;
    if (score <= 9) return AppColors.powerHigh;
    return AppColors.powerCEDH;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForScore(powerLevel.score);
    return GestureDetector(
      onTap: () => _showFactorsDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score circulaire
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.25),
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Text(
                  '${powerLevel.score}',
                  style: AppTextStyles.cardTitle(color: color, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Power Level',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  powerLevel.label,
                  style: AppTextStyles.bold(color: color, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.info_outline, color: AppColors.textDisabled, size: 16),
          ],
        ),
      ),
    );
  }

  void _showFactorsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: Row(
          children: [
            Icon(Icons.analytics, color: _colorForScore(powerLevel.score)),
            const SizedBox(width: 8),
            Text(
              'Power Level ${powerLevel.score}/10',
              style: AppTextStyles.sectionTitle(fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              powerLevel.label,
              style: AppTextStyles.cardTitle(
                color: _colorForScore(powerLevel.score),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ...powerLevel.factors.entries.map((entry) => _buildFactorRow(
              entry.key,
              entry.value,
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String name, double value) {
    final normalizedValue = value.clamp(1.0, 10.0);
    final color = _colorForScore(normalizedValue.round());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: normalizedValue / 10.0,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              normalizedValue.toStringAsFixed(1),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
