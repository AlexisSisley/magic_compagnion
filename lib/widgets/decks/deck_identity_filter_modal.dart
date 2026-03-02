// Fichier : lib/widgets/decks/deck_identity_filter_modal.dart

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../controllers/deck_list_controller.dart';

/// Shows the identity color filter modal for the deck list.
void showDeckIdentityFilterModal({
  required BuildContext context,
  required DeckListState currentState,
  required DeckListController controller,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.scaffoldBackground,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Identite Couleur',
                        style: AppTextStyles.bold(fontSize: 20)),
                    if (currentState.selectedIdentityName != null)
                      TextButton(
                          onPressed: () {
                            controller.clearIdentityFilter();
                            Navigator.pop(context);
                          },
                          child: const Text('Effacer',
                              style: TextStyle(color: AppColors.accentRed)))
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderMedium),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: DeckListController.colorFamilies.entries
                      .map((familyEntry) {
                    return ExpansionTile(
                      title: Text(familyEntry.key,
                          style: AppTextStyles.bold(color: AppColors.primaryShade800)),
                      iconColor: AppColors.primaryShade800,
                      collapsedIconColor: AppColors.textMuted,
                      initiallyExpanded: true,
                      children:
                          familyEntry.value.entries.map((colorEntry) {
                        final name = colorEntry.key;
                        final colors = colorEntry.value;
                        final isSelected =
                            currentState.selectedIdentityName == name;

                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: AppColors.primaryShade900
                              .withValues(alpha: 0.2),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 0),
                          title: Row(
                            children: [
                              ...colors.map((c) => Padding(
                                    padding:
                                        const EdgeInsets.only(right: 4.0),
                                    child: _getManaIcon(c, size: 20),
                                  )),
                              if (colors.isEmpty)
                                _getManaIcon('C', size: 20),
                              const SizedBox(width: 12),
                              Text(name,
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.yellow
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check,
                                  color: AppColors.primary)
                              : null,
                          onTap: () {
                            controller.updateIdentityFilter(
                                name, colors);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _getManaIcon(String symbol, {double size = 20}) {
  final url = 'https://svgs.scryfall.io/card-symbols/$symbol.svg';
  return SvgPicture.network(
    url,
    height: size,
    width: size,
    placeholderBuilder: (_) =>
        Text(symbol, style: TextStyle(color: AppColors.textPrimary, fontSize: size)),
  );
}
