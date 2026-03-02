// Fichier : lib/widgets/common/tag_editor_dialog.dart
// Dialog d'edition de tags pour cartes (Sprint 10, US-10.4).
// Affiche les tags actuels, permet d'en ajouter/supprimer avec autocomplete.

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Dialog pour editer les tags d'une carte (collection ou deck).
/// Retourne la liste de tags mise a jour, ou null si annule.
class TagEditorDialog extends StatefulWidget {
  final String cardName;
  final List<String> currentTags;
  final List<String> availableTags; // Suggestions existantes

  const TagEditorDialog({
    super.key,
    required this.cardName,
    required this.currentTags,
    required this.availableTags,
  });

  /// Affiche le dialog et retourne la liste de tags mise a jour (ou null).
  static Future<List<String>?> show(
    BuildContext context, {
    required String cardName,
    required List<String> currentTags,
    required List<String> availableTags,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => TagEditorDialog(
        cardName: cardName,
        currentTags: currentTags,
        availableTags: availableTags,
      ),
    );
  }

  @override
  State<TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<TagEditorDialog> {
  late List<String> _tags;
  final TextEditingController _textController = TextEditingController();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.currentTags);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _tags.contains(trimmed)) return;
    setState(() {
      _tags.add(trimmed);
      _textController.clear();
      _suggestions = [];
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _suggestions = widget.availableTags
          .where((t) => t.toLowerCase().contains(lower) && !_tags.contains(t))
          .take(5)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.scaffoldBackground,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tags',
            style: AppTextStyles.bold(),
          ),
          Text(
            widget.cardName,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags actuels
            if (_tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                    backgroundColor: AppColors.primaryShade900.withValues(alpha: 0.4),
                    deleteIconColor: Colors.red.shade300,
                    onDeleted: () => _removeTag(tag),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            if (_tags.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aucun tag. Ajoutez-en ci-dessous.',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),

            // Champ de saisie avec autocomplete
            TextField(
              controller: _textController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nouveau tag...',
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.overlayDark,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () => _addTag(_textController.text),
                ),
              ),
              onChanged: _updateSuggestions,
              onSubmitted: _addTag,
            ),

            // Suggestions
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...(_suggestions.map((s) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(s, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                trailing: const Icon(Icons.add, color: AppColors.borderFaint, size: 16),
                onTap: () => _addTag(s),
              ))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _tags),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryShade800),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
