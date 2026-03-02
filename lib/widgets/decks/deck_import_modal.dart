// Fichier : lib/widgets/decks/deck_import_modal.dart
// Modal d'import multi-format (Sprint 10, US-10.1).
// 2 onglets : coller du texte / importer un fichier (.txt/.csv).

import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/deck_list_controller.dart';

class DeckImportModal extends ConsumerStatefulWidget {
  const DeckImportModal({super.key});

  @override
  ConsumerState<DeckImportModal> createState() => _DeckImportModalState();
}

class _DeckImportModalState extends ConsumerState<DeckImportModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  String? _selectedFileName;
  String? _fileContent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      setState(() {
        _selectedFileName = result.files.single.name;
        _fileContent = content;
      });
    }
  }

  Future<void> _doImport() async {
    final String deckName = _nameController.text.trim();
    if (deckName.isEmpty) return;

    String content;
    if (_tabController.index == 0) {
      // Tab "Coller du texte"
      content = _textController.text.trim();
    } else {
      // Tab "Fichier"
      content = _fileContent ?? '';
    }

    if (content.isEmpty) return;

    final controller = ref.read(deckListControllerProvider.notifier);

    // Easter egg check
    final (resolvedName, resolvedContent) =
        controller.resolveEasterEgg(deckName, content);

    if (!mounted) return;
    Navigator.pop(context);

    final result = await controller.importDeck(resolvedName, resolvedContent);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green.shade800 : Colors.red.shade800,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImporting = ref.watch(deckListControllerProvider).isImporting;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Importer un Deck',
              style: AppTextStyles.bold(fontSize: 20),
            ),
            const SizedBox(height: 12),

            // Nom du deck
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nom du nouveau deck',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.overlayDark,
              ),
            ),
            const SizedBox(height: 12),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryShade800,
              labelColor: AppColors.primaryShade800,
              unselectedLabelColor: AppColors.textMuted,
              tabs: const [
                Tab(text: 'Coller du texte'),
                Tab(text: 'Depuis un fichier'),
              ],
            ),
            const SizedBox(height: 12),

            // Tab content
            SizedBox(
              height: 200,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Paste text
                  TextField(
                    controller: _textController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText:
                          'Collez votre decklist ici...\n\nExemple:\n4 Lightning Bolt\n4 Goblin Guide\n\nSideboard\n2 Blood Moon',
                      hintStyle: TextStyle(color: AppColors.textDisabled),
                      filled: true,
                      fillColor: AppColors.overlayDark,
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // Tab 2: File picker
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_open),
                        label: const Text('Choisir un fichier (.txt / .csv)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.greyShade800,
                          foregroundColor: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedFileName != null) ...[
                        Icon(Icons.check_circle, color: Colors.green.shade400),
                        const SizedBox(height: 4),
                        Text(
                          _selectedFileName!,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ] else
                        const Text(
                          'Formats supportes : TXT (Moxfield, MTGO), CSV (Archidekt)',
                          style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isImporting ? null : _doImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryShade800,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.textPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Importer',
                        style: AppTextStyles.bold(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
