// Fichier : lib/widgets/collections/set_detail_control_bar.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../../controllers/set_detail_controller.dart';

class SetDetailControlBar extends StatelessWidget {
  final SetDetailState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final ValueChanged<String> onSortSelected;

  const SetDetailControlBar({
    super.key,
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.textOnPrimary.withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
                color: state.hasActiveFilters
                    ? AppColors.primaryShade900
                    : AppColors.textPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: AppColors.textSecondary),
              onPressed: onFilterTap,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: _buildSortMenu(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort, color: AppColors.textSecondary, size: 20),
      color: AppColors.scaffoldBackground,
      onSelected: onSortSelected,
      itemBuilder: (ctx) => [
        _buildPopupItem('number', 'Numero', Icons.format_list_numbered),
        _buildPopupItem('name', 'Nom', Icons.sort_by_alpha),
        _buildPopupItem('rarity', 'Rarete', Icons.diamond),
        _buildPopupItem('price', 'Prix', Icons.euro),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      String value, String text, IconData icon) {
    final bool isSelected = state.sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted, size: 18),
          const SizedBox(width: 12),
          Text(text,
              style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary)),
          if (isSelected) ...[
            const Spacer(),
            Icon(state.sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                color: AppColors.primary, size: 14)
          ]
        ],
      ),
    );
  }
}
