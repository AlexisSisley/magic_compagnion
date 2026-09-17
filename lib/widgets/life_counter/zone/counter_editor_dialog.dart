// Fichier : lib/widgets/life_counter/zone/counter_editor_dialog.dart
//
// Lot 5, tâche 4 : dialogue de création d'un compteur personnalisé, ouvert
// depuis le tiroir joueur ("Nouveau compteur"). Ne fait QUE collecter les
// champs (nom, emoji, couleur, borne optionnelle) et rendre un `CounterType`
// candidat -- il n'appelle JAMAIS `CounterCatalogNotifier.saveCustomType`
// lui-même : c'est l'appelant (`_PlayerDrawerBody` dans `player_drawer.dart`,
// via le callback `onCreateCounter` du tiroir, remonté jusqu'à
// `life_counter_page._openPlayerDrawer`) qui sauvegarde réellement et
// affiche l'éventuel refus (nom usurpant un intégré, voir
// `CounterCatalogNotifier.saveCustomType`) -- un dialogue qui sauvegarderait
// lui-même ne pourrait pas rester ouvert pour laisser corriger un refus sans
// dupliquer cette logique.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'player_skin_picker.dart' show playerSkinColorOptions;

/// Dérive un id de compteur à partir du nom saisi -- ce dialogue n'a pas de
/// champ id dédié. Minuscules, tout ce qui n'est pas alphanumérique réduit à
/// un unique `_`, bornes recadrées.
///
/// Un nom "Poison" dérive donc l'id `poison`, usurpant volontairement l'id
/// du compteur intégré homonyme : c'est exactement le cas que
/// `CounterCatalogNotifier.saveCustomType` (tâche 1) est chargé de refuser
/// -- pas ce dialogue, qui reste une simple collecte de champs (voir le
/// commentaire de fichier).
String deriveCounterId(String name) {
  final normalized = name.trim().toLowerCase();
  final slug = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return slug.replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Dialogue de création d'un compteur personnalisé (nom, emoji, couleur,
/// borne optionnelle). Rend un `CounterType?` : le type saisi, ou `null` si
/// annulé.
class CounterEditorDialog extends StatefulWidget {
  const CounterEditorDialog({super.key});

  /// Affiche le dialogue et rend le `CounterType` candidat saisi, ou `null`
  /// si annulé -- ne sauvegarde rien (voir le doc-comment de fichier).
  static Future<CounterType?> show(BuildContext context) {
    return showDialog<CounterType>(
      context: context,
      builder: (_) => const CounterEditorDialog(),
    );
  }

  @override
  State<CounterEditorDialog> createState() => _CounterEditorDialogState();
}

class _CounterEditorDialogState extends State<CounterEditorDialog> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  final _maxValueController = TextEditingController();
  late Color _selectedColor = playerSkinColorOptions.first;

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _maxValueController.dispose();
    super.dispose();
  }

  /// Décision de conception (rapport de tâche, point 3) : nom et emoji
  /// doivent être non vides une fois recadrés (`trim`), ET l'id qui en est
  /// dérivé doit lui-même être non vide -- un nom qui ne réduit à rien
  /// ('!!!', uniquement de la ponctuation) resterait sinon un id vide,
  /// valide en apparence mais inutilisable comme clé de compteur. Le bouton
  /// "Créer" reste désactivé (`onPressed: null`) tant que cette condition
  /// n'est pas remplie -- refus visible (bouton inerte), jamais une création
  /// silencieusement invalide.
  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _emojiController.text.trim().isNotEmpty &&
      deriveCounterId(_nameController.text).isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    final maxValue = int.tryParse(_maxValueController.text.trim());
    Navigator.of(context).pop(CounterType(
      id: deriveCounterId(_nameController.text),
      name: _nameController.text.trim(),
      emoji: _emojiController.text.trim(),
      color: _selectedColor.toARGB32(),
      maxValue: maxValue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.scaffoldBackground,
      title: Text('Nouveau compteur', style: AppTextStyles.cardTitle()),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('counter_editor_name'),
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nom',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('counter_editor_emoji'),
              controller: _emojiController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Emoji',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('counter_editor_max_value'),
              controller: _maxValueController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Borne maximale (optionnel)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in playerSkinColorOptions)
                  GestureDetector(
                    key: ValueKey('counter_editor_color_${color.toARGB32()}'),
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      // Cible tactile >= 48x48 (contrainte du lot).
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor.toARGB32() == color.toARGB32()
                              ? AppColors.textPrimary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('counter_editor_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          key: const ValueKey('counter_editor_submit'),
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryShade800),
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
