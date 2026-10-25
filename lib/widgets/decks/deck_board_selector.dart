// Fichier : lib/widgets/decks/deck_board_selector.dart
// Puces de board de l'onglet Liste. Chacune choisit le board affiché et
// accepte le dépôt d'une carte glissée depuis la liste, comme le faisaient
// les anciens onglets Main, Side, Considering et Wishlist.

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

import '../../models/deck_model.dart';
import '../../services/deck_service.dart';

/// Libellé affiché d'un board, sans son compte.
String deckBoardLabel(DeckBoard board) {
  switch (board) {
    case DeckBoard.main:
      return 'Main';
    case DeckBoard.side:
      return 'Side';
    case DeckBoard.considering:
      return 'Considering';
    case DeckBoard.wishlist:
      return 'Wishlist';
  }
}

class DeckBoardSelector extends StatelessWidget {
  final DeckBoard selected;
  final Map<DeckBoard, int> counts;
  final ValueChanged<DeckBoard> onSelect;
  final void Function(DeckCard card, DeckBoard from, DeckBoard to) onDrop;

  const DeckBoardSelector({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelect,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    // Défilement horizontal : quatre puces ne tiennent pas toujours sur un
    // téléphone étroit, et une puce tronquée ne serait plus une cible lisible.
    // Calées à gauche, comme sur la maquette, quelle que soit la largeur.
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            for (final board in DeckBoard.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _BoardPill(
                  board: board,
                  count: counts[board] ?? 0,
                  active: board == selected,
                  onSelect: onSelect,
                  onDrop: onDrop,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardPill extends StatelessWidget {
  final DeckBoard board;
  final int count;
  final bool active;
  final ValueChanged<DeckBoard> onSelect;
  final void Function(DeckCard card, DeckBoard from, DeckBoard to) onDrop;

  const _BoardPill({
    required this.board,
    required this.count,
    required this.active,
    required this.onSelect,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Map<String, dynamic>>(
      // Déposer une carte sur son propre board n'a pas de sens : refusé, la
      // puce ne s'allume pas et rien n'est appelé.
      onWillAcceptWithDetails: (details) =>
          details.data['sourceBoard'] != board,
      onAcceptWithDetails: (details) {
        final DeckCard card = details.data['card'];
        final DeckBoard source = details.data['sourceBoard'];
        onDrop(card, source, board);
      },
      builder: (context, candidateData, rejectedData) {
        final hovered = candidateData.isNotEmpty;
        final Color background = active
            ? AppColors.primary
            : hovered
            ? AppColors.primaryShade900.withValues(alpha: 0.5)
            : AppColors.transparent;
        final Color foreground = active
            ? AppColors.textOnPrimary
            : AppColors.textSecondary;
        return Semantics(
          button: true,
          selected: active,
          child: Material(
            color: background,
            shape: StadiumBorder(
              side: BorderSide(
                color: active ? AppColors.primary : AppColors.borderMedium,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(board),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '${deckBoardLabel(board)} $count',
                      style: AppTextStyles.text(
                        color: foreground,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
