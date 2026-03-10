// Fichier : lib/widgets/dashboard/dashboard_collection_stats.dart
// Stats rapides de la collection : top cartes, repartition couleurs, nb editions.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/deck_model.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/price_helper.dart';
import '../../widgets/cards/scryfall_image.dart';
import 'dashboard_empty_state.dart';
import 'dashboard_section_header.dart';

class DashboardCollectionStats extends StatelessWidget {
  final List<DeckCard> topValueCards;
  final Map<String, int> colorDistribution;
  final int editionCount;

  const DashboardCollectionStats({
    super.key,
    required this.topValueCards,
    required this.colorDistribution,
    required this.editionCount,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty =
        topValueCards.isEmpty && colorDistribution.isEmpty && editionCount == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Stats Collection',
          icon: Icons.bar_chart,
        ),
        if (isEmpty)
          DashboardEmptyState(
            icon: Icons.bar_chart,
            message: 'Scannez votre premiere carte !',
            actionLabel: 'Scanner',
            onAction: () => context.go(AppRoutes.scanner),
          )
        else ...[
          // Top 3 most valuable cards
          if (topValueCards.isNotEmpty) ...[
            Text(
              'Top cartes',
              style: AppTextStyles.label(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            ...topValueCards.map((card) => _TopCardTile(card: card)),
            const SizedBox(height: 12),
          ],

          // Color distribution
          if (colorDistribution.isNotEmpty) ...[
            Text(
              'Couleurs',
              style: AppTextStyles.label(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            _ColorDistributionBar(distribution: colorDistribution),
            const SizedBox(height: 12),
          ],

          // Edition count
          if (editionCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.collections_bookmark,
                      color: AppColors.accent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '$editionCount editions',
                    style: AppTextStyles.label(
                      color: AppColors.accent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _TopCardTile extends StatelessWidget {
  final DeckCard card;

  const _TopCardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        'https://api.scryfall.com/cards/${card.scryfallId}?format=image&version=small';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          ScryfallImage(
            imageUrl: imageUrl,
            width: 24,
            height: 34,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              card.name,
              style: AppTextStyles.label(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            PriceHelper.formatValue(card.quantity.toDouble()),
            style: AppTextStyles.label(
              color: AppColors.primaryGold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDistributionBar extends StatelessWidget {
  final Map<String, int> distribution;

  const _ColorDistributionBar({required this.distribution});

  static const _manaColors = {
    'W': AppColors.manaWhite,
    'U': AppColors.manaBlue,
    'B': AppColors.manaBlack,
    'R': AppColors.manaRed,
    'G': AppColors.manaGreen,
    'C': AppColors.manaColorless,
    'M': AppColors.manaMulti,
  };

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 12,
        child: Row(
          children: distribution.entries.map((entry) {
            final fraction = entry.value / total;
            final color = _manaColors[entry.key] ?? AppColors.manaColorless;
            return Expanded(
              flex: (fraction * 100).round().clamp(1, 100),
              child: Container(color: color),
            );
          }).toList(),
        ),
      ),
    );
  }
}
