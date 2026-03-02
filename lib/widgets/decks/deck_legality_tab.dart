// Fichier : lib/widgets/decks/deck_legality_tab.dart
// Widget onglet legalite du deck (Sprint 10, US-10.3).
// Affiche un rapport de legalite pour 8 formats avec badges et violations.

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

import '../../models/legality_report.dart';

class DeckLegalityTab extends StatelessWidget {
  final LegalityReport report;

  const DeckLegalityTab({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resume
          _buildSummary(),
          const SizedBox(height: 8),

          // Avertissement cartes non resolues
          if (report.unresolvedCards > 0) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${report.unresolvedCards} carte(s) non resolue(s) (ignorees)',
                    style: const TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Liste des formats
          ...report.results.map((result) => _buildFormatCard(result)),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            '${report.legalCount}',
            'Legal',
            AppColors.success,
          ),
          _buildSummaryItem(
            '${report.illegalCount}',
            'Illegal',
            AppColors.error,
          ),
          _buildSummaryItem(
            '${report.results.length}',
            'Formats',
            AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.bold(color: color, fontSize: 24),
        ),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFormatCard(FormatLegalityResult result) {
    final isLegal = result.status == LegalityStatus.legal;
    final isUnknown = result.status == LegalityStatus.unknown;
    final statusColor = isLegal
        ? Colors.green
        : isUnknown
            ? Colors.grey
            : AppColors.error;
    final statusIcon = isLegal
        ? Icons.check_circle
        : isUnknown
            ? Icons.help_outline
            : Icons.cancel;
    final statusLabel = isLegal ? 'Legal' : isUnknown ? 'Inconnu' : 'Illegal';

    final formatLabel = _formatLabel(result.format);

    if (result.violations.isEmpty) {
      // Simple row for legal formats
      return Card(
        color: AppColors.textPrimary.withValues(alpha: 0.05),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          dense: true,
          leading: Icon(statusIcon, color: statusColor, size: 22),
          title: Text(
            formatLabel,
            style: AppTextStyles.cinzel(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    // ExpansionTile for formats with violations
    return Card(
      color: AppColors.textPrimary.withValues(alpha: 0.05),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor, size: 22),
        title: Row(
          children: [
            Text(
              formatLabel,
              style: AppTextStyles.cinzel(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$statusLabel (${result.violations.length})',
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        iconColor: AppColors.textMuted,
        collapsedIconColor: AppColors.borderMedium,
        children: result.violations.map((v) {
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.warning, color: AppColors.error, size: 14),
            title: Text(v, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }

  String _formatLabel(String format) {
    switch (format) {
      case 'standard': return 'Standard';
      case 'pioneer': return 'Pioneer';
      case 'modern': return 'Modern';
      case 'legacy': return 'Legacy';
      case 'vintage': return 'Vintage';
      case 'pauper': return 'Pauper';
      case 'commander': return 'Commander';
      case 'brawl': return 'Brawl';
      default: return format;
    }
  }
}
