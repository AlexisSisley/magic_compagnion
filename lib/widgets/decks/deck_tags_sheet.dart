// Fichier : lib/widgets/decks/deck_tags_sheet.dart
// Feuille « Dossiers » d'un deck : on coche les tags existants ou on en cree
// un. C'est le seul endroit ou l'on pose des tags, donc le seul moyen de
// donner quelque chose a filtrer a la feuille de filtres.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Rend la nouvelle liste de tags du deck, ou `null` si la feuille est
/// fermee sans enregistrer.
Future<List<String>?> showDeckTagsSheet(
  BuildContext context, {
  required String deckName,
  required List<String> current,
  required List<String> known,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.scaffoldBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DeckTagsSheet(
      deckName: deckName,
      current: current,
      known: known,
    ),
  );
}

class DeckTagsSheet extends StatefulWidget {
  final String deckName;
  final List<String> current;
  final List<String> known;

  const DeckTagsSheet({
    super.key,
    required this.deckName,
    required this.current,
    required this.known,
  });

  @override
  State<DeckTagsSheet> createState() => _DeckTagsSheetState();
}

class _DeckTagsSheetState extends State<DeckTagsSheet> {
  final TextEditingController _input = TextEditingController();
  late final List<String> _selected = [...widget.current];

  /// Tags proposes : les connus, plus ceux du deck qu'aucune liste ne
  /// referencerait (et ceux crees ici, avant l'enregistrement).
  late final List<String> _options = _merge(widget.known, widget.current);

  static List<String> _merge(List<String> a, List<String> b) {
    final seen = <String>{};
    final out = <String>[];
    for (final t in [...a, ...b]) {
      if (seen.add(t.toLowerCase())) out.add(t);
    }
    return out;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String? _existing(String tag) {
    final lower = tag.toLowerCase();
    for (final t in _options) {
      if (t.toLowerCase() == lower) return t;
    }
    return null;
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      // Un doublon de casse ne cree rien : le tag existant est selectionne,
      // pour que « Casual » et « casual » ne scindent pas un dossier en deux.
      final existing = _existing(text);
      final tag = existing ?? text;
      if (existing == null) _options.add(tag);
      if (!_selected.contains(tag)) _selected.add(tag);
      _input.clear();
    });
  }

  void _toggle(String tag, bool on) {
    setState(() {
      if (on) {
        if (!_selected.contains(tag)) _selected.add(tag);
      } else {
        _selected.remove(tag);
      }
    });
  }

  TextStyle _chipLabel(bool selected) => TextStyle(
    color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
  );

  @override
  Widget build(BuildContext context) {
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
            Text(
              'Dossiers de ${widget.deckName}',
              style: AppTextStyles.bold(fontSize: 20),
            ),
            const SizedBox(height: 12),
            if (_options.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aucun dossier pour le moment',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final tag in _options)
                    FilterChip(
                      label: Text(tag),
                      selected: _selected.contains(tag),
                      onSelected: (v) => _toggle(tag, v),
                      selectedColor: AppColors.primary,
                      checkmarkColor: AppColors.textOnPrimary,
                      labelStyle: _chipLabel(_selected.contains(tag)),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('deck-tags-input'),
                    controller: _input,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textInputAction: TextInputAction.done,
                    maxLength: 30,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                      labelText: 'Nouveau dossier',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.overlayMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const ValueKey('deck-tags-add'),
                  onPressed: _add,
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('deck-tags-save'),
                onPressed: () => Navigator.pop(context, [..._selected]),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: AppColors.primaryShade800,
                  // Le theme de base colore le texte des boutons en lilas : sur
                  // l'or, seul le noir de la charte est lisible.
                  foregroundColor: AppColors.textOnPrimary,
                ),
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
