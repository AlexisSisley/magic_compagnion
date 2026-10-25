// Fichier : lib/widgets/decks/card_tags_sheet.dart
// Feuille d'édition des tags d'une carte de deck : la liste ordonnée (le
// premier est le principal), les tags universels et ceux du deck à ajouter,
// la création d'un tag, et la remise à la suggestion automatique.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/card_tag_catalog_controller.dart';
import '../../models/card_tag.dart';
import '../../models/deck_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/card_tag_edit.dart';

/// Ouvre la feuille. [onSave] reçoit la liste finale (ordre = priorité) ;
/// [onReset] rend la carte à la suggestion automatique. Les deux ferment la
/// feuille ; « Annuler » ne touche à rien.
Future<void> showCardTagsSheet(
  BuildContext context, {
  required DeckCard card,
  required List<String> deckTags,
  required bool canSuggest,
  required ValueChanged<List<String>> onSave,
  required VoidCallback onReset,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.scaffoldBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => CardTagsSheet(
      card: card,
      deckTags: deckTags,
      canSuggest: canSuggest,
      onSave: onSave,
      onReset: onReset,
    ),
  );
}

class CardTagsSheet extends ConsumerStatefulWidget {
  final DeckCard card;
  final List<String> deckTags;
  final bool canSuggest;
  final ValueChanged<List<String>> onSave;
  final VoidCallback onReset;

  const CardTagsSheet({
    super.key,
    required this.card,
    required this.deckTags,
    required this.canSuggest,
    required this.onSave,
    required this.onReset,
  });

  @override
  ConsumerState<CardTagsSheet> createState() => _CardTagsSheetState();
}

class _CardTagsSheetState extends ConsumerState<CardTagsSheet> {
  final TextEditingController _input = TextEditingController();
  late List<String> _tags = [...widget.card.tags];
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add(String name, List<CardTagDef> catalog) =>
      setState(() => _tags = addTag(_tags, name, catalog));

  void _create(List<CardTagDef> catalog) {
    if (normalizeTagName(_input.text) == null) {
      setState(() => _error = 'Un tag fait de 1 à 24 caractères.');
      return;
    }
    setState(() {
      _error = null;
      _tags = addTag(_tags, _input.text, catalog);
    });
    _input.clear();
  }

  CardTagDef? _def(String tag, List<CardTagDef> catalog) =>
      catalog.where((d) => sameTag(d.name, tag)).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(cardTagCatalogProvider);
    final universal = [
      for (final d in catalog)
        if (!_tags.any((t) => sameTag(t, d.name))) d,
    ];
    final deckTags = [
      for (final t in widget.deckTags)
        if (!_tags.any((c) => sameTag(c, t)) &&
            !catalog.any((d) => sameTag(d.name, t)))
          t,
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.card.name, style: AppTextStyles.sectionTitle()),
              const SizedBox(height: 16),
              _heading('Tags de la carte'),
              if (_tags.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aucun tag.',
                    style: AppTextStyles.body(color: AppColors.textMuted),
                  ),
                ),
              for (var i = 0; i < _tags.length; i++)
                _cardTagRow(_tags[i], i == 0, catalog),
              if (universal.isNotEmpty) ...[
                const SizedBox(height: 12),
                _heading('Tags universels'),
                _chips([
                  for (final d in universal)
                    _addChip(d.name, Color(d.color), catalog),
                ]),
              ],
              if (deckTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                _heading('Tags de ce deck'),
                _chips([for (final t in deckTags) _addChip(t, null, catalog)]),
              ],
              const SizedBox(height: 16),
              _heading('Nouveau tag'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      style: const TextStyle(color: AppColors.textPrimary),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _create(catalog),
                      decoration: InputDecoration(
                        hintText: 'Nouveau tag',
                        errorText: _error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _create(catalog),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderMedium),
                    ),
                    child: const Text('Ajouter'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.canSuggest)
                    TextButton(
                      onPressed: () {
                        widget.onReset();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Suggestion auto'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () {
                      widget.onSave(_tags);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: AppColors.primaryGold,
                      // Le thème colore le texte des boutons en lilas : sur
                      // l'or, seul le noir de la charte est lisible.
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: AppTextStyles.label(color: AppColors.textSecondary),
    ),
  );

  Widget _chips(List<Widget> children) =>
      Wrap(spacing: 8, runSpacing: 4, children: children);

  Widget _addChip(String name, Color? color, List<CardTagDef> catalog) =>
      ActionChip(
        label: Text(name, style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.cardBackground,
        side: BorderSide(color: color ?? AppColors.borderMedium),
        onPressed: () => _add(name, catalog),
      );

  Widget _cardTagRow(String tag, bool primary, List<CardTagDef> catalog) {
    final def = _def(tag, catalog);
    final color = def == null ? null : Color(def.color);
    const box = BoxConstraints.tightFor(width: 48, height: 48);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(
                tag,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              backgroundColor:
                  color?.withValues(alpha: 0.25) ?? AppColors.cardBackground,
              side: BorderSide(color: color ?? AppColors.borderMedium),
            ),
          ),
        ),
        if (def == null)
          IconButton(
            tooltip: 'Rendre universel',
            constraints: box,
            icon: const Icon(Icons.public, color: AppColors.textSecondary),
            onPressed: () => ref.read(cardTagCatalogProvider.notifier).add(tag),
          ),
        IconButton(
          tooltip: primary ? 'Tag principal' : 'Rendre principal',
          constraints: box,
          icon: Icon(
            primary ? Icons.star : Icons.star_border,
            color: primary ? AppColors.amber : AppColors.textMuted,
          ),
          onPressed: () => setState(() => _tags = makePrimary(_tags, tag)),
        ),
        IconButton(
          tooltip: 'Retirer',
          constraints: box,
          icon: const Icon(Icons.close, color: AppColors.textMuted),
          onPressed: () => setState(() => _tags = removeTag(_tags, tag)),
        ),
      ],
    );
  }
}
