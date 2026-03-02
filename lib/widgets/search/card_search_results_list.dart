// Fichier : lib/widgets/search/card_search_results_list.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/card_search_controller.dart';
import '../../models/scryfall_card_model.dart';
import '../common/collection_badge.dart';
import 'skyrim_sneak_loader.dart';

/// Displays search results as a scrollable list of card tiles.
class CardSearchResultsList extends StatelessWidget {
  final CardSearchState state;
  final ScrollController scrollController;
  final void Function(String cardName) onCardTap;
  final void Function(String id, String name, bool inWishlist) onToggleWishlist;
  final void Function(String id, String name, bool inCollection) onToggleCollection;

  const CardSearchResultsList({
    super.key,
    required this.state,
    required this.scrollController,
    required this.onCardTap,
    required this.onToggleWishlist,
    required this.onToggleCollection,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: SkyrimSneakLoader());
    }

    if (state.searchResults.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(state.statusMessage,
                  style: AppTextStyles.subtitle(fontSize: 16),
                  textAlign: TextAlign.center)));
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: state.searchResults.length + 1,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        if (index >= state.searchResults.length) {
          bool showLoader = state.hasMoreLocal || state.hasMoreApi;
          return showLoader
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()))
              : const SizedBox(height: 20);
        }

        if (index < 0) return const SizedBox();

        return _CardSearchListTile(
          state: state,
          card: state.searchResults[index],
          onCardTap: onCardTap,
          onToggleWishlist: onToggleWishlist,
          onToggleCollection: onToggleCollection,
        );
      },
    );
  }
}

/// A single list tile for a card search result.
class _CardSearchListTile extends StatelessWidget {
  final CardSearchState state;
  final ScryfallCard card;
  final void Function(String cardName) onCardTap;
  final void Function(String id, String name, bool inWishlist) onToggleWishlist;
  final void Function(String id, String name, bool inCollection) onToggleCollection;

  const _CardSearchListTile({
    required this.state,
    required this.card,
    required this.onCardTap,
    required this.onToggleWishlist,
    required this.onToggleCollection,
  });

  CollectionBadge? _getBadge() {
    final normal = state.collectionIndex[card.id] ?? 0;
    final foil = state.collectionFoilIndex[card.id] ?? 0;
    final inWishlist = state.wishlistCardNames.contains(card.name);
    if (normal == 0 && foil == 0 && !inWishlist) return null;
    return CollectionBadge(normalCount: normal, foilCount: foil, inWishlist: inWishlist);
  }

  @override
  Widget build(BuildContext context) {
    final String cardName = card.name;
    final String imageUrl = card.smallImageUrl ?? card.imageUrl;
    final String price = card.prices['eur'] ?? '--';

    final bool inWishlist = state.isCardInWishlist(cardName);
    final bool inCollection = state.isCardInCollection(card.id);
    final badge = _getBadge();

    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.45),
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: const BorderSide(color: AppColors.borderLight, width: 1)),
      child: InkWell(
        onTap: () => onCardTap(cardName),
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        width: 60,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            Container(width: 60, height: 84, color: AppColors.greyShade800))
                    : Container(
                        width: 60,
                        height: 84,
                        color: AppColors.greyShade800,
                        child: const Icon(Icons.image, color: AppColors.textDisabled)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cardName,
                        style: AppTextStyles.bold(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(card.typeLine,
                        style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.overlayDark,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.borderMedium)),
                          child: Text(card.setCode.toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text('${card.cmc?.toInt() ?? 0} CMC',
                            style: const TextStyle(color: AppColors.borderFaint, fontSize: 10)),
                        const SizedBox(width: 8),
                        _buildRarityBadge(card.rarity),
                        const Spacer(),
                        Text('$price EUR',
                            style: TextStyle(
                                color: AppColors.primaryShade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (badge != null) CollectionBadgeWidget(badge: badge),
                  _buildActionButton(
                      icon: inWishlist ? Icons.star : Icons.star_border,
                      color: inWishlist ? AppColors.info : AppColors.textDisabled,
                      onTap: () => onToggleWishlist(card.id, cardName, inWishlist)),
                  _buildActionButton(
                      icon: inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined,
                      color: inCollection ? AppColors.success : AppColors.textDisabled,
                      onTap: () => onToggleCollection(card.id, cardName, inCollection)),
                ],
              )
            ],
          ),
        ),
      ),
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
      width: 12,
      height: 12,
      decoration: BoxDecoration(
          color: c, shape: BoxShape.circle, border: Border.all(color: AppColors.textOnPrimary, width: 1)),
    );
  }

  Widget _buildActionButton(
      {required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, color: color, size: 22)),
    );
  }
}
