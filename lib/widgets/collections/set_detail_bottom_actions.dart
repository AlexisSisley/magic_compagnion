// Fichier : lib/widgets/collections/set_detail_bottom_actions.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

import '../../controllers/set_detail_controller.dart';

class SetDetailBottomActions extends StatelessWidget {
  final SetDetailState state;
  final VoidCallback onAddToWishlist;
  final VoidCallback onRemoveFromWishlist;
  final VoidCallback onAddToCollection;
  final VoidCallback onRemoveFromCollection;

  const SetDetailBottomActions({
    super.key,
    required this.state,
    required this.onAddToWishlist,
    required this.onRemoveFromWishlist,
    required this.onAddToCollection,
    required this.onRemoveFromCollection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C2C2C), Color(0xFF111111)]),
        border: Border(
            top: BorderSide(color: AppColors.primaryShade800, width: 2.0)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.style, color: AppColors.primaryShade800, size: 16),
                const SizedBox(width: 8),
                Text('${state.selectedKeys.length} selectionne(s)',
                    style: AppTextStyles.bold(color: const Color(0xFFE0E0E0), fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildActionButton(
                              icon: Icons.star_border,
                              color: Colors.red.shade300,
                              label: 'Suppr.',
                              isNegative: true,
                              onTap: onRemoveFromWishlist)),
                      const SizedBox(width: 4),
                      Expanded(
                          child: _buildActionButton(
                              icon: Icons.star,
                              color: AppColors.accent,
                              label: 'Wishlist',
                              onTap: onAddToWishlist)),
                    ],
                  ),
                ),
                Container(
                    height: 32,
                    width: 1,
                    color: AppColors.borderSubtle,
                    margin: const EdgeInsets.symmetric(horizontal: 8)),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildActionButton(
                              icon: Icons.inventory_2_outlined,
                              color: Colors.red.shade300,
                              label: 'Suppr.',
                              isNegative: true,
                              onTap: onRemoveFromCollection)),
                      const SizedBox(width: 4),
                      Expanded(
                          child: _buildActionButton(
                              icon: Icons.inventory_2,
                              color: AppColors.success,
                              label: 'Collect.',
                              onTap: onAddToCollection)),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isNegative = false,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isNegative ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.2),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
