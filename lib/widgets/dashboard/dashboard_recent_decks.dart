// Fichier : lib/widgets/dashboard/dashboard_recent_decks.dart
// Liste des 3 derniers decks sur le dashboard.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/deck_model.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'dashboard_empty_state.dart';
import 'dashboard_section_header.dart';

class DashboardRecentDecks extends StatelessWidget {
  final List<Deck> recentDecks;

  const DashboardRecentDecks({
    super.key,
    required this.recentDecks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          title: 'Decks Recents',
          icon: Icons.style_outlined,
          onSeeAll: recentDecks.isNotEmpty
              ? () => context.go(AppRoutes.decks)
              : null,
        ),
        if (recentDecks.isEmpty)
          DashboardEmptyState(
            icon: Icons.style_outlined,
            message: 'Creez votre premier deck !',
            actionLabel: 'Nouveau Deck',
            onAction: () => context.go(AppRoutes.decks),
          )
        else
          ...recentDecks.map((deck) => _RecentDeckTile(
                deckName: deck.name,
                cardCount: deck.mainboard.fold<int>(
                    0, (sum, c) => sum + c.quantity),
                format: deck.format,
                onTap: () => context.push(
                  AppRoutes.deckDetail,
                  extra: deck,
                ),
              )),
      ],
    );
  }
}

class _RecentDeckTile extends StatelessWidget {
  final String deckName;
  final int cardCount;
  final String format;
  final VoidCallback onTap;

  const _RecentDeckTile({
    required this.deckName,
    required this.cardCount,
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.style_outlined,
                    color: AppColors.primaryGold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deckName,
                        style: AppTextStyles.cardTitle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$cardCount cartes - $format',
                        style: AppTextStyles.label(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
