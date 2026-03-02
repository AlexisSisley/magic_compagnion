// Fichier : lib/widgets/search/card_search_wishlist_selector.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

import '../../services/wishlist_service.dart';

/// Modal bottom sheet that lets the user pick or create a wishlist.
/// Returns the selected wishlist ID or null if cancelled.
class CardSearchWishlistSelector {
  final BuildContext context;
  final WishlistService wishlistService;

  CardSearchWishlistSelector({
    required this.context,
    required this.wishlistService,
  });

  Future<String?> show() async {
    final wishlists = await wishlistService.loadWishlists();
    if (!context.mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              constraints:
                  BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Choisir une Wishlist',
                        style: AppTextStyles.bold(fontSize: 18)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle, color: AppColors.accentGreen),
                    title: Text('Creer une nouvelle liste',
                        style: AppTextStyles.cinzel()),
                    onTap: () async {
                      final name = await _showCreateWishlistDialog();
                      if (name != null && context.mounted) {
                        final updatedLists = await wishlistService.loadWishlists();
                        try {
                          final newList =
                              updatedLists.lastWhere((w) => w.name == name);
                          if (!context.mounted) return;
                          Navigator.pop(context, newList.id);
                        } catch (_) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                  const Divider(color: AppColors.borderMedium),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: wishlists.length,
                      itemBuilder: (context, index) {
                        final list = wishlists[index];
                        return ListTile(
                          leading:
                              const Icon(Icons.bookmark_border, color: AppColors.accent),
                          title: Text(list.name,
                              style: const TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text('${list.totalCards} cartes',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          onTap: () => Navigator.pop(context, list.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showCreateWishlistDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        title: const Text('Nouvelle Liste', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Nom de la liste'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await wishlistService.createWishlist(controller.text);
                if (!c.mounted) return;
                Navigator.pop(c, controller.text);
              }
            },
            child: const Text('Creer'),
          )
        ],
      ),
    );
  }
}
