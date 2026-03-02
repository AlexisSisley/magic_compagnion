// Fichier : lib/widgets/collections/set_detail_filter_modal.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/search_filters.dart';

/// Shows the filter bottom sheet for SetDetailPage.
///
/// Returns nothing; applies filters via [onApply] callback.
void showSetDetailFilterModal({
  required BuildContext context,
  required SearchFilters initialFilters,
  required bool initialHideOwned,
  required void Function(SearchFilters filters, bool hideOwned) onApply,
}) {
  var currentFilters = initialFilters;
  var currentHideOwned = initialHideOwned;

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.scaffoldBackground,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return SafeArea(
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: AppColors.primaryShade800, width: 2)),
                color: AppColors.scaffoldBackground,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Filtres du Set',
                      style: AppTextStyles.bold(fontSize: 20),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),

                  // --- 1. COULEURS ---
                  Text('Couleurs',
                      style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildManaIconBtn(
                          'W', currentFilters, setModalState,
                          onUpdate: (f) => currentFilters = f),
                      _buildManaIconBtn(
                          'U', currentFilters, setModalState,
                          onUpdate: (f) => currentFilters = f),
                      _buildManaIconBtn(
                          'B', currentFilters, setModalState,
                          onUpdate: (f) => currentFilters = f),
                      _buildManaIconBtn(
                          'R', currentFilters, setModalState,
                          onUpdate: (f) => currentFilters = f),
                      _buildManaIconBtn(
                          'G', currentFilters, setModalState,
                          onUpdate: (f) => currentFilters = f),
                      _buildManaIconBtn(
                          'C', currentFilters, setModalState,
                          onUpdate: (f) => currentFilters = f),
                      _buildManaIconBtn(
                          'M', currentFilters, setModalState,
                          isMulti: true,
                          onUpdate: (f) => currentFilters = f),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 2. TYPES ---
                  Text('Type de carte',
                      style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Creature',
                      'Instant',
                      'Sorcery',
                      'Artifact',
                      'Enchantment',
                      'Land',
                      'Planeswalker'
                    ].map((type) {
                      final isSelected =
                          currentFilters.cardType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (val) {
                          setModalState(() {
                            currentFilters = currentFilters.copyWith(
                                cardType: val ? type : null);
                          });
                        },
                        selectedColor: AppColors.primaryShade900,
                        backgroundColor: AppColors.overlayMedium,
                        labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // --- 3. OPTIONS ---
                  Text("Options d'affichage",
                      style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: currentFilters.rarity,
                          decoration: const InputDecoration(
                              labelText: 'Rarete',
                              filled: true,
                              fillColor: AppColors.overlayMedium),
                          dropdownColor: AppColors.cardBackground,
                          items: const [
                            DropdownMenuItem(
                                value: null, child: Text('Toutes')),
                            DropdownMenuItem(
                                value: 'common',
                                child: Text('Commune')),
                            DropdownMenuItem(
                                value: 'uncommon',
                                child: Text('Unco')),
                            DropdownMenuItem(
                                value: 'rare', child: Text('Rare')),
                            DropdownMenuItem(
                                value: 'mythic',
                                child: Text('Mythique')),
                          ],
                          onChanged: (val) => setModalState(() =>
                              currentFilters =
                                  currentFilters.copyWith(rarity: val)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilterChip(
                          label: const Text('Masquer possedees'),
                          selected: currentHideOwned,
                          onSelected: (val) => setModalState(
                              () => currentHideOwned = val),
                          selectedColor:
                              Colors.green.withValues(alpha: 0.3),
                          checkmarkColor: AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      onApply(currentFilters, currentHideOwned);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryShade800,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16)),
                    child: Text('APPLIQUER',
                        style: AppTextStyles.bold(color: AppColors.textOnPrimary, fontSize: 16)),
                  )
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

Widget _buildManaIconBtn(
    String code, SearchFilters filters, StateSetter setModalState,
    {bool isMulti = false, required void Function(SearchFilters) onUpdate}) {
  final isSelected = filters.colors.contains(code);

  Widget content;
  if (isMulti) {
    content = Container(
      decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              colors: [Color(0xFFE6D68F), Color(0xFFC7A94E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)),
      child: Center(
          child: Text('M',
              style: AppTextStyles.bold(color: AppColors.textOnPrimary, fontSize: 16))),
    );
  } else {
    content = SvgPicture.network(
      'https://svgs.scryfall.io/card-symbols/$code.svg',
      placeholderBuilder: (_) =>
          CircleAvatar(backgroundColor: AppColors.synergyNeutral, child: Text(code)),
    );
  }

  return GestureDetector(
    onTap: () {
      setModalState(() {
        final newColors = Set<String>.from(filters.colors);
        if (isSelected) {
          newColors.remove(code);
        } else {
          newColors.add(code);
        }
        onUpdate(filters.copyWith(colors: newColors));
      });
    },
    child: Opacity(
      opacity: isSelected ? 1.0 : 0.4,
      child: Container(
        width: 40,
        height: 40,
        decoration: isSelected
            ? BoxDecoration(shape: BoxShape.circle, boxShadow: [
                BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.3), blurRadius: 10)
              ])
            : null,
        child: content,
      ),
    ),
  );
}
