// Fichier : lib/pages/settings/card_tags_page.dart
// Gestion du catalogue des tags universels : ordre, couleur, nom, suppression.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/card_tag_catalog_controller.dart';
import '../../models/card_tag.dart';
import '../../providers/service_providers.dart';
import '../../services/card_tag_catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/magic_palette.dart';

String _cardsLabel(int n) => '$n ${n > 1 ? 'cartes' : 'carte'}';

class CardTagsPage extends ConsumerStatefulWidget {
  const CardTagsPage({super.key});

  @override
  ConsumerState<CardTagsPage> createState() => _CardTagsPageState();
}

class _CardTagsPageState extends ConsumerState<CardTagsPage> {
  /// Nombre de cartes par tag, indexé par nom exact du catalogue.
  Map<String, int> _counts = const {};

  CardTagCatalog get _catalog => CardTagCatalog(ref.read(appDatabaseProvider));
  CardTagCatalogController get _ctrl =>
      ref.read(cardTagCatalogProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshCounts(ref.read(cardTagCatalogProvider)),
    );
  }

  Future<void> _refreshCounts(List<CardTagDef> tags) async {
    final catalog = _catalog;
    final counts = <String, int>{};
    for (final t in tags) {
      counts[t.name] = await catalog.usageCount(t.name);
    }
    if (mounted) setState(() => _counts = counts);
  }

  Future<void> _pickColor(CardTagDef tag) async {
    final color = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => _ColorSheet(current: tag.color),
    );
    if (color != null) await _ctrl.setColor(tag.name, color);
  }

  Future<void> _rename(CardTagDef tag) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TagNameDialog(
        title: 'Renommer le tag',
        initial: tag.name,
        confirmLabel: 'Renommer',
        submit: (name) => _ctrl.rename(tag.name, name),
      ),
    );
  }

  Future<void> _add() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TagNameDialog(
        title: 'Nouveau tag',
        initial: '',
        confirmLabel: 'Ajouter',
        submit: (raw) async {
          if (await _ctrl.add(raw)) return RenameResult.ok;
          // `add` ne distingue pas ses deux refus : on les départage ici.
          final name = normalizeTagName(raw);
          final taken =
              name != null &&
              ref
                  .read(cardTagCatalogProvider)
                  .any((t) => sameTag(t.name, name));
          return taken ? RenameResult.duplicate : RenameResult.invalid;
        },
      ),
    );
  }

  Future<void> _delete(CardTagDef tag) async {
    final count = await _catalog.usageCount(tag.name);
    if (!mounted) return;
    final p = MagicPalette.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.overlay,
        title: Text(
          'Supprimer le tag ${tag.name} ?',
          style: AppTextStyles.bold(color: p.inkPrimary),
        ),
        content: Text(
          'Il sera retiré de ${_cardsLabel(count)}.',
          style: AppTextStyles.text(color: p.inkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _ctrl.delete(tag.name);
  }

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    final tags = ref.watch(cardTagCatalogProvider);
    ref.listen<List<CardTagDef>>(
      cardTagCatalogProvider,
      (_, next) => _refreshCounts(next),
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('Tags de cartes', style: AppTextStyles.bold()),
        backgroundColor: AppColors.textOnPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.all(16),
              itemCount: tags.length,
              onReorder: (o, n) => _ctrl.reorder(o, n),
              itemBuilder: (context, i) {
                final tag = tags[i];
                final count = _counts[tag.name];
                return Padding(
                  key: ValueKey('tag-${tag.name}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: p.raised,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.drag_handle,
                              color: p.inkSecondary,
                            ),
                          ),
                        ),
                        InkWell(
                          key: ValueKey('color-${tag.name}'),
                          onTap: () => _pickColor(tag),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Color(tag.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tag.name,
                                style: AppTextStyles.text(color: p.inkPrimary),
                              ),
                              if (count != null)
                                Text(
                                  _cardsLabel(count),
                                  style: AppTextStyles.text(
                                    color: p.inkSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Renommer',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: Icon(
                            Icons.edit_outlined,
                            color: p.inkSecondary,
                          ),
                          onPressed: () => _rename(tag),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: Icon(
                            Icons.delete_outline,
                            color: p.inkSecondary,
                          ),
                          onPressed: () => _delete(tag),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau tag'),
                  onPressed: _add,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSheet extends StatelessWidget {
  final int current;
  const _ColorSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in kCardTagPalette)
              InkWell(
                key: ValueKey('palette-$c'),
                borderRadius: BorderRadius.circular(24),
                onTap: () => Navigator.pop(context, c),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: c == current
                            ? Border.all(color: p.inkPrimary, width: 3)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialogue de saisie d'un nom de tag ; reste ouvert tant que [submit] refuse.
class _TagNameDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String confirmLabel;
  final Future<RenameResult> Function(String name) submit;

  const _TagNameDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    required this.submit,
  });

  @override
  State<_TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<_TagNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final result = await widget.submit(_controller.text);
    if (!mounted) return;
    switch (result) {
      case RenameResult.ok:
        Navigator.pop(context);
      case RenameResult.invalid:
        setState(() => _error = 'Un tag fait de 1 à 24 caractères.');
      case RenameResult.duplicate:
        setState(() => _error = 'Un tag porte déjà ce nom.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    return AlertDialog(
      backgroundColor: p.overlay,
      title: Text(widget.title, style: AppTextStyles.bold(color: p.inkPrimary)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: AppTextStyles.text(color: p.inkPrimary),
        decoration: InputDecoration(labelText: 'Nom', errorText: _error),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
