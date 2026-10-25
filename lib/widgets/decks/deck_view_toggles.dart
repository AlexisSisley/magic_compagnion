// Fichier : lib/widgets/decks/deck_view_toggles.dart
// Interrupteurs d'affichage de la liste d'un deck : regroupement
// « Catégorie | Type » et bascule grille/liste. Posés dans la rangée des puces
// de board pour ne pas consommer une ligne de plus au-dessus des cartes.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

import '../../services/deck_view_prefs.dart';

class DeckViewToggles extends StatelessWidget {
  final DeckViewPrefs prefs;
  final ValueChanged<DeckGrouping> onGrouping;
  final ValueChanged<DeckLayout> onLayout;

  const DeckViewToggles({
    super.key,
    required this.prefs,
    required this.onGrouping,
    required this.onLayout,
  });

  @override
  Widget build(BuildContext context) {
    // Un Wrap plutôt qu'une Row : sur un écran étroit (ou un texte agrandi),
    // le bouton grille/liste passe à la ligne au lieu de déborder.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: [_buildGroupingToggle(), _buildLayoutToggle()],
    );
  }

  /// Interrupteur « Catégorie | Type ». Le thème de base a un `primary`
  /// lilas : sans `foregroundColor` explicite, le libellé sélectionné sortirait
  /// lilas sur le fond or.
  Widget _buildGroupingToggle() {
    return SegmentedButton<DeckGrouping>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: DeckGrouping.category, label: Text('Catégorie')),
        ButtonSegment(value: DeckGrouping.type, label: Text('Type')),
      ],
      selected: {prefs.grouping},
      onSelectionChanged: (s) => onGrouping(s.first),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.textOnPrimary
              : AppColors.textSecondary,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.transparent,
        ),
      ),
    );
  }

  /// Un seul bouton de 48 px : il montre le mode vers lequel il bascule.
  Widget _buildLayoutToggle() {
    final toList = prefs.layout == DeckLayout.grid;
    return IconButton(
      icon: Icon(toList ? Icons.view_list : Icons.grid_view, size: 20),
      tooltip: toList ? 'Afficher en liste' : 'Afficher en grille',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      onPressed: () => onLayout(toList ? DeckLayout.list : DeckLayout.grid),
    );
  }
}
