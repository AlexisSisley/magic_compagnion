// Fichier : lib/widgets/common/collection_badge.dart
// Sprint 9 : Badge visuel indiquant si une carte est possedee/foil/wishlist.

import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Donnees du badge collection pour une carte.
class CollectionBadge {
  final int normalCount;
  final int foilCount;
  final bool inWishlist;

  int get totalCount => normalCount + foilCount;
  bool get isOwned => totalCount > 0;

  const CollectionBadge({
    this.normalCount = 0,
    this.foilCount = 0,
    this.inWishlist = false,
  });
}

/// Widget affichant le badge collection sur une tuile de carte.
class CollectionBadgeWidget extends StatelessWidget {
  final CollectionBadge? badge;

  const CollectionBadgeWidget({super.key, this.badge});

  @override
  Widget build(BuildContext context) {
    if (badge == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge!.isOwned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'x${badge!.totalCount}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (badge!.foilCount > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Icon(Icons.auto_awesome, color: AppColors.amber, size: 10),
                  ),
              ],
            ),
          ),
        if (badge!.inWishlist)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.favorite, color: Colors.pinkAccent, size: 14),
          ),
      ],
    );
  }
}
