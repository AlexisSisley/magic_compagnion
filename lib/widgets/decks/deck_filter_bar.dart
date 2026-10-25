// Fichier : lib/widgets/decks/deck_filter_bar.dart
// Barre de filtres de la bibliotheque : pilule « Filtres » avec son compteur,
// une puce par filtre actif, et le tri a droite.

import 'package:flutter/material.dart';

import '../../controllers/deck_list_controller.dart';
import '../../controllers/deck_list_filters.dart';
import '../../theme/app_colors.dart';

/// Filtre qu'une puce permet de retirer.
enum DeckFilterKind { format, identity, tags, price }

/// Hauteur de la zone tactile de chaque pilule : le dessin fait 32, la cible
/// reste de 48 pour ne pas descendre sous le minimum tactile.
const double _hitHeight = 48;
const double _pillHeight = 32;

/// Libelle de la puce de prix. Une borne haute infinie veut dire « sans
/// plafond » : le curseur de la feuille y pose sa butee droite.
String deckPriceChipLabel((double, double) range) {
  String euros(double v) => '${v.round()} €';
  if (range.$2.isInfinite) return 'Dès ${euros(range.$1)}';
  if (range.$1 == 0) return 'Sous ${euros(range.$2)}';
  return '${range.$1.round()}–${euros(range.$2)}';
}

/// Nom de l'identite pour une liste de couleurs : celui de la famille de
/// couleurs du controleur quand il existe (« Azorius »), sinon les symboles.
String deckIdentityChipLabel(List<String> colors) {
  final wanted = colors.toSet();
  for (final family in DeckListController.colorFamilies.values) {
    for (final entry in family.entries) {
      final candidate = entry.value.toSet();
      if (candidate.length == wanted.length && candidate.containsAll(wanted)) {
        return entry.key;
      }
    }
  }
  return colors.join();
}

class DeckFilterBar extends StatelessWidget {
  final DeckFilterCriteria criteria;
  final int activeCount;
  final VoidCallback onOpenFilters;
  final ValueChanged<DeckSort> onSort;
  final void Function(DeckFilterKind) onClear;

  const DeckFilterBar({
    super.key,
    required this.criteria,
    required this.activeCount,
    required this.onOpenFilters,
    required this.onSort,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (criteria.format != null)
        _ActiveChip(
          kind: DeckFilterKind.format,
          label: criteria.format!,
          onClear: onClear,
        ),
      if (criteria.identityColors != null)
        _ActiveChip(
          kind: DeckFilterKind.identity,
          label: criteria.identityColors!.isEmpty
              ? 'Incolore'
              : deckIdentityChipLabel(criteria.identityColors!),
          onClear: onClear,
        ),
      if (criteria.tags.isNotEmpty)
        _ActiveChip(
          kind: DeckFilterKind.tags,
          label: criteria.tags.length == 1
              ? criteria.tags.first
              : '${criteria.tags.length} tags',
          onClear: onClear,
        ),
      if (criteria.priceRange != null)
        _ActiveChip(
          kind: DeckFilterKind.price,
          label: deckPriceChipLabel(criteria.priceRange!),
          onClear: onClear,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FiltersPill(count: activeCount, onTap: onOpenFilters),
          const SizedBox(width: 8),
          // Les puces defilent : sur un telephone, quatre filtres actifs ne
          // tiennent pas a cote du tri.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final chip in chips)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: chip,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SortPill(sort: criteria.sort, onSort: onSort),
        ],
      ),
    );
  }
}

/// Pilule dessinee sur 32 dans une zone de 48. Le contenu est pose PAR-DESSUS
/// le dessin et non dedans : dans un conteneur de 32, une croix de 48 serait
/// ecrasee a 32 et la cible tactile avec elle.
class _PillFrame extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _PillFrame({
    required this.child,
    this.borderColor = AppColors.borderSubtle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _hitHeight,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: (_hitHeight - _pillHeight) / 2,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(_pillHeight / 2),
                  border: Border.all(color: borderColor),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _FiltersPill extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FiltersPill({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 0 ? 'Filtres' : 'Filtres, $count actifs',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('deck-filter-open'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(_hitHeight / 2),
        child: _PillFrame(
          borderColor: AppColors.primary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Filtres',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    key: const ValueKey('deck-filter-badge'),
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final DeckFilterKind kind;
  final String label;
  final void Function(DeckFilterKind) onClear;

  const _ActiveChip({
    required this.kind,
    required this.label,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _PillFrame(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          // La croix garde une cible de 48 x 48 : elle deborde de la pilule
          // dessinee mais pas de la zone de 48 de la ligne.
          InkWell(
            key: ValueKey('deck-filter-clear-${kind.name}'),
            onTap: () => onClear(kind),
            customBorder: const CircleBorder(),
            child: Semantics(
              button: true,
              label: 'Retirer le filtre $label',
              excludeSemantics: true,
              child: const SizedBox(
                width: _hitHeight,
                height: _hitHeight,
                child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  final DeckSort sort;
  final ValueChanged<DeckSort> onSort;

  const _SortPill({required this.sort, required this.onSort});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DeckSort>(
      key: const ValueKey('deck-filter-sort'),
      tooltip: 'Trier',
      color: AppColors.cardBackground,
      onSelected: onSort,
      itemBuilder: (_) => [
        for (final s in DeckSort.values)
          PopupMenuItem<DeckSort>(
            value: s,
            child: Text(
              deckSortLabel(s),
              style: TextStyle(
                color: s == sort ? AppColors.primary : AppColors.textPrimary,
                fontWeight: s == sort ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
      ],
      child: _PillFrame(
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                deckSortLabel(sort),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
