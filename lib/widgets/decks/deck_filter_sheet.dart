// Fichier : lib/widgets/decks/deck_filter_sheet.dart
// Feuille de filtres de la bibliotheque : format, identite de couleur, tags et
// fourchette de prix. Les changements s'appliquent au fil de l'eau.

import 'package:flutter/material.dart';

import '../../controllers/deck_list_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'deck_identity_filter_modal.dart';

/// Pas du curseur de prix, en euros.
const double _priceStep = 10;

/// Plafond du curseur : le prix du deck le plus cher arrondi au multiple de 50
/// superieur. Sans prix connu (bibliotheque vide ou decks a 0 €), 50 : un
/// curseur de 0 a 0 serait invalide.
double deckPriceCeiling(double maxDeckPrice) {
  if (maxDeckPrice <= 0) return 50;
  return (maxDeckPrice / 50).ceil() * 50.0;
}

Future<void> showDeckFilterSheet(
  BuildContext context, {
  required DeckListState state,
  required DeckListController controller,
  required List<String> formats,
  required List<String> tags,
  required double maxPrice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.scaffoldBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DeckFilterSheet(
      initialState: state,
      controller: controller,
      formats: formats,
      tags: tags,
      maxPrice: maxPrice,
    ),
  );
}

class DeckFilterSheet extends StatefulWidget {
  final DeckListState initialState;
  final DeckListController controller;
  final List<String> formats;
  final List<String> tags;
  final double maxPrice;

  const DeckFilterSheet({
    super.key,
    required this.initialState,
    required this.controller,
    required this.formats,
    required this.tags,
    required this.maxPrice,
  });

  @override
  State<DeckFilterSheet> createState() => _DeckFilterSheetState();
}

class _DeckFilterSheetState extends State<DeckFilterSheet> {
  late DeckListState _state = widget.initialState;
  void Function()? _unsubscribe;

  /// Valeurs du curseur pendant le glissement : le controleur n'est sollicite
  /// qu'au relachement, pas a chaque pixel.
  RangeValues? _dragging;

  double get _ceiling => deckPriceCeiling(widget.maxPrice);

  @override
  void initState() {
    super.initState();
    // La feuille reste ouverte pendant que les filtres changent : elle relit
    // l'etat du controleur plutot que de garder sa propre copie.
    _unsubscribe = widget.controller.addListener((s) {
      if (mounted) setState(() => _state = s);
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  RangeValues get _sliderValues {
    final range = _state.priceRange;
    if (range == null) return RangeValues(0, _ceiling);
    // Une borne haute infinie est la butee droite : « sans plafond ».
    final end = range.$2.isInfinite ? _ceiling : range.$2;
    return RangeValues(
      range.$1.clamp(0, _ceiling).toDouble(),
      end.clamp(0, _ceiling).toDouble(),
    );
  }

  void _commitPrice(RangeValues v) {
    setState(() => _dragging = null);
    if (v.start <= 0 && v.end >= _ceiling) {
      widget.controller.updatePriceRange(null);
      return;
    }
    // Butee droite = pas de plafond, pour que « Dès 50 € » ne coupe pas les
    // decks plus chers que le curseur ne sait en representer.
    final end = v.end >= _ceiling ? double.infinity : v.end;
    widget.controller.updatePriceRange((v.start, end));
  }

  void _toggleTag(String tag, bool selected) {
    final next = [..._state.selectedTags];
    if (selected) {
      if (!next.contains(tag)) next.add(tag);
    } else {
      next.remove(tag);
    }
    widget.controller.updateTags(next);
  }

  String _priceSummary(RangeValues v) {
    if (v.start <= 0 && v.end >= _ceiling) return 'Tous les prix';
    return '${v.start.round()} € – ${v.end.round()} €';
  }

  @override
  Widget build(BuildContext context) {
    final values = _dragging ?? _sliderValues;
    final divisions = (_ceiling / _priceStep).round();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filtres', style: AppTextStyles.bold(fontSize: 20)),
                TextButton(
                  onPressed: widget.controller.clearAllFilters,
                  child: const Text(
                    'Tout effacer',
                    style: TextStyle(color: AppColors.accentRed),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _SectionTitle('Format'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: _state.selectedFormat == null,
                  onSelected: (_) => widget.controller.updateFormat(null),
                  selectedColor: AppColors.primary,
                  labelStyle: _chipLabel(_state.selectedFormat == null),
                ),
                for (final format in widget.formats)
                  ChoiceChip(
                    label: Text(format),
                    selected: _state.selectedFormat == format,
                    onSelected: (_) => widget.controller.updateFormat(format),
                    selectedColor: AppColors.primary,
                    labelStyle: _chipLabel(_state.selectedFormat == format),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Identité couleur'),
            OutlinedButton(
              key: const ValueKey('deck-filter-identity'),
              onPressed: () => showDeckIdentityFilterModal(
                context: context,
                currentState: _state,
                controller: widget.controller,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderMedium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_state.selectedIdentityName ?? 'Toutes les identités'),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Tags'),
            if (widget.tags.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aucun tag : appui long sur un deck pour en poser',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final tag in widget.tags)
                    FilterChip(
                      label: Text(tag),
                      selected: _state.selectedTags.contains(tag),
                      onSelected: (v) => _toggleTag(tag, v),
                      selectedColor: AppColors.primary,
                      checkmarkColor: AppColors.textOnPrimary,
                      labelStyle: _chipLabel(_state.selectedTags.contains(tag)),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle('Prix'),
                Text(
                  _priceSummary(values),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            RangeSlider(
              key: const ValueKey('deck-filter-price'),
              values: values,
              min: 0,
              max: _ceiling,
              divisions: divisions,
              activeColor: AppColors.primary,
              labels: RangeLabels(
                '${values.start.round()} €',
                '${values.end.round()} €',
              ),
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: _commitPrice,
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _chipLabel(bool selected) => TextStyle(
    color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppTextStyles.bold(color: AppColors.primaryShade800),
      ),
    );
  }
}
