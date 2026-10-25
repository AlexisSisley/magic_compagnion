// Fichier : lib/widgets/decks/deck_library_grid.dart

import 'package:flutter/material.dart';

import '../../models/deck_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Nombre de colonnes pour une largeur DISPONIBLE donnée : < 600 → 1,
/// < 1000 → 2, sinon 3. C'est la largeur laissée au contenu et non celle de
/// l'écran qui compte : un pli déplié ou une fenêtre redimensionnée doivent
/// donner la grille de leur largeur réelle.
int deckLibraryColumns(double availableWidth) {
  if (availableWidth < 600) return 1;
  if (availableWidth < 1000) return 2;
  return 3;
}

/// Sliver de la bibliothèque : grille de tuiles 16:9, ou état vide.
///
/// La hauteur d'une rangée est dérivée de la largeur d'une colonne
/// (`mainAxisExtent` = largeur × 9 / 16) : la tuile est un 16:9 pur, quelle que
/// soit la largeur de la grille.
class DeckLibraryGrid extends StatelessWidget {
  final List<Deck> decks;
  final Map<String, double> prices;

  /// Nombre de filtres actifs (pas la recherche) : il choisit entre
  /// « aucun deck ne correspond » et « aucun deck du tout ».
  final int activeFilters;
  final VoidCallback onClearFilters;
  final Widget Function(Deck) tileBuilder;

  const DeckLibraryGrid({
    super.key,
    required this.decks,
    required this.prices,
    required this.activeFilters,
    required this.onClearFilters,
    required this.tileBuilder,
  });

  static const double _gutter = 14;
  static const double _sideMargin = 20;

  @override
  Widget build(BuildContext context) {
    if (decks.isEmpty) return _buildEmpty();

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = deckLibraryColumns(width);
        final columnWidth =
            (width - 2 * _sideMargin - _gutter * (columns - 1)) / columns;

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _gutter,
              crossAxisSpacing: _gutter,
              mainAxisExtent: columnWidth * 9 / 16,
            ),
            delegate: SliverChildBuilderDelegate(
              // La clé est portée par l'élément de grille, hors de la tuile :
              // sans elle, supprimer un deck réutiliserait l'état de la case
              // voisine et laisserait un Dismissible fantôme.
              (context, index) => KeyedSubtree(
                key: ValueKey(decks[index].id),
                child: tileBuilder(decks[index]),
              ),
              childCount: decks.length,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final i = decks.indexWhere((d) => d.id == key.value);
                return i < 0 ? null : i;
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    final filtered = activeFilters > 0;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              filtered
                  ? 'Aucun deck ne correspond aux filtres'
                  : 'Aucun deck pour l\'instant',
              textAlign: TextAlign.center,
              style: AppTextStyles.text(
                  color: AppColors.textSecondary, fontSize: 16),
            ),
            if (filtered) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton(
                  onPressed: onClearFilters,
                  child: const Text('Effacer les filtres'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
