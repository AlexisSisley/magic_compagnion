// Fichier : lib/widgets/collections/set_detail_card_tile.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../../controllers/set_detail_controller.dart';
import '../../models/scryfall_card_model.dart';
import '../../utils/price_helper.dart';

class SetDetailCardTile extends StatelessWidget {
  final SetDetailState state;
  final SetCardDisplayItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SetDetailCardTile({
    super.key,
    required this.state,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final ScryfallCard card = item.card;
    final bool isFoilSlot = item.isFoil;

    final String key = makeKey(card.id, isFoilSlot);
    final bool isOwned = state.ownedKeys.contains(key);
    final bool isSelected = state.selectedKeys.contains(key);
    final bool isWanted = state.wishlistKeys.contains(key);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: isSelected ? 1.0 : (isOwned ? 1.0 : 0.4),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: isSelected
                      ? BorderSide(color: AppColors.primaryShade700, width: 3)
                      : (isOwned
                          ? BorderSide(
                              color: Colors.green.shade800, width: 2)
                          : BorderSide.none)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(card.smallImageUrl ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.image_not_supported))),
                  if (isFoilSlot)
                    Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                            AppColors.transparent,
                            Colors.purple.withValues(alpha: 0.3),
                            AppColors.transparent,
                            Colors.amber.withValues(alpha: 0.3)
                          ],
                              stops: const [
                            0.0,
                            0.4,
                            0.6,
                            1.0
                          ])),
                    ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
                top: 4,
                right: 4,
                child: Container(
                    decoration: const BoxDecoration(
                        color: AppColors.overlayVeryDark, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 24))),
          if (isOwned && !isSelected)
            Positioned(
                top: 4,
                left: 4,
                child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: AppColors.overlayDark, shape: BoxShape.circle),
                    child: const Icon(Icons.inventory_2,
                        color: AppColors.success, size: 16))),
          if (isWanted && !isSelected && !isOwned)
            Positioned(
                top: 4,
                right: 4,
                child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: AppColors.overlayDark, shape: BoxShape.circle),
                    child: Icon(Icons.star,
                        color: Colors.blue.shade400, size: 16))),
          Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.overlayVeryDark,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderMedium)),
                  child: Text(isFoilSlot ? 'FOIL' : 'NORM',
                      style: TextStyle(
                          color:
                              isFoilSlot ? Colors.amberAccent : AppColors.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)))),
          Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.overlayDark,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('#${card.collectorNumber}',
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 10)))),
          // Prix via PriceTag
          Positioned(
              bottom: 20,
              right: 4,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.overlayVeryDark,
                      borderRadius: BorderRadius.circular(4)),
                  child: PriceTag(
                    prices: card.prices,
                    isFoil: isFoilSlot,
                    fontSize: 10,
                  ))),
        ],
      ),
    );
  }
}
