// Fichier : lib/widgets/dashboard/dashboard_favorite_deck.dart
// Deck favori / le plus recemment modifie.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/deck_model.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/cards/scryfall_image.dart';
import 'dashboard_empty_state.dart';

class DashboardFavoriteDeck extends StatelessWidget {
  final Deck? favoriteDeck;

  const DashboardFavoriteDeck({
    super.key,
    this.favoriteDeck,
  });

  @override
  Widget build(BuildContext context) {
    if (favoriteDeck == null) {
      return DashboardEmptyState(
        icon: Icons.star_outline,
        message: 'Votre deck favori apparaitra ici',
        actionLabel: 'Nouveau Deck',
        onAction: () => context.go(AppRoutes.decks),
      );
    }

    final deck = favoriteDeck!;
    final cardCount =
        deck.mainboard.fold<int>(0, (sum, c) => sum + c.quantity);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.deckDetail, extra: deck),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            // Commander image or deck icon
            if (deck.commanderScryfallId != null)
              ScryfallImage(
                imageUrl:
                    'https://api.scryfall.com/cards/${deck.commanderScryfallId}?format=image&version=art_crop',
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(8),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.style_outlined,
                  color: AppColors.primaryGold,
                  size: 28,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    deck.name,
                    style: AppTextStyles.cardTitle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$cardCount cartes - ${deck.format}',
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
    );
  }
}
