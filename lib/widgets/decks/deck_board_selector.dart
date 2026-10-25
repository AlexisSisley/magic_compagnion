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

  /// Widgets posés après les puces, dans le même `Wrap` (les interrupteurs
  /// d'affichage de la liste) : une rangée de moins au-dessus des cartes.
  final List<Widget> trailing;

  const DeckBoardSelector({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelect,
    required this.onDrop,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Les puces passent à la ligne quand elles ne tiennent pas : pendant un
    // glisser, chaque board doit rester à l'écran pour recevoir la carte,
    // sans défilement horizontal qui en cacherait une.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final board in DeckBoard.values)
              _BoardPill(
                board: board,
                count: counts[board] ?? 0,
                active: board == selected,
                onSelect: onSelect,
                onDrop: onDrop,
              ),
            ...trailing,
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
