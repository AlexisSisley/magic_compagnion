// Fichier : lib/widgets/search/card_search_results_grid.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

import '../../controllers/card_search_controller.dart';
import '../common/collection_badge.dart';
import 'skyrim_sneak_loader.dart';

/// Displays search results as a 2-column image grid.
class CardSearchResultsGrid extends StatelessWidget {
  final CardSearchState state;
  final ScrollController scrollController;
  final void Function(String cardName) onCardTap;

  const CardSearchResultsGrid({
    super.key,
    required this.state,
    required this.scrollController,
    required this.onCardTap,
  });

  CollectionBadge? _getBadge(String scryfallId, String cardName) {
    final normal = state.collectionIndex[scryfallId] ?? 0;
    final foil = state.collectionFoilIndex[scryfallId] ?? 0;
    final inWishlist = state.wishlistCardNames.contains(cardName);
    if (normal == 0 && foil == 0 && !inWishlist) return null;
    return CollectionBadge(normalCount: normal, foilCount: foil, inWishlist: inWishlist);
  }

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: SkyrimSneakLoader());
    }

    if (state.searchResults.isEmpty) {
      return Center(
          child: Text(state.statusMessage,
              style: AppTextStyles.cinzel(color: AppColors.textSecondary)));
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: state.searchResults.length + 1,
      itemBuilder: (context, index) {
        if (index >= state.searchResults.length) {
          bool showLoader = state.hasMoreLocal || state.hasMoreApi;
          return showLoader
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox();
        }

        final card = state.searchResults[index];
        final String imageUrl =
            card.imageUrl.isNotEmpty ? card.imageUrl : (card.smallImageUrl ?? '');
        final badge = _getBadge(card.id, card.name);

        return GestureDetector(
          onTap: () => onCardTap(card.name),
          child: Card(
            clipBehavior: Clip.antiAlias,
            color: AppColors.textOnPrimary,
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.borderSubtle, width: 1)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.greyShade900,
                        child: Center(
                            child: Text(card.name,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 10)))),
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                          AppColors.textOnPrimary.withValues(alpha: 0.9),
                          AppColors.transparent
                        ])))),
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${card.prices['eur'] ?? '-'}EUR",
                          style: TextStyle(
                              color: AppColors.primaryShade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      _buildRarityBadge(card.rarity),
                    ],
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: CollectionBadgeWidget(badge: badge),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRarityBadge(String rarity) {
    Color c;
    switch (rarity) {
      case 'common':
        c = AppColors.textPrimary;
        break;
      case 'uncommon':
        c = Colors.blue.shade300;
        break;
      case 'rare':
        c = AppColors.amber;
        break;
      case 'mythic':
        c = Colors.orange.shade800;
        break;
      default:
        c = AppColors.synergyNeutral;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textOnPrimary, width: 1)),
    );
  }
}
