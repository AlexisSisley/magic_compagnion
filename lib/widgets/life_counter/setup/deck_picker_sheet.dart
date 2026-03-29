// Fichier : lib/widgets/life_counter/setup/deck_picker_sheet.dart
// Task 15: Bottom sheet for selecting a deck from the collection

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Data class returned when a deck is picked.
class DeckPickerResult {
  final String deckId;
  final String deckName;
  final List<String> commanderNames;

  const DeckPickerResult({
    required this.deckId,
    required this.deckName,
    this.commanderNames = const [],
  });
}

/// Bottom sheet for selecting a deck from the user's collection.
class DeckPickerSheet extends StatefulWidget {
  /// List of available decks to pick from.
  final List<DeckPickerResult> decks;

  const DeckPickerSheet({super.key, required this.decks});

  @override
  State<DeckPickerSheet> createState() => _DeckPickerSheetState();
}

class _DeckPickerSheetState extends State<DeckPickerSheet> {
  String _search = '';

  List<DeckPickerResult> get _filteredDecks {
    if (_search.isEmpty) return widget.decks;
    final lower = _search.toLowerCase();
    return widget.decks
        .where((d) => d.deckName.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffoldBackground,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderMedium,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select Deck',
              style: AppTextStyles.sectionTitle(),
            ),
          ),
          const SizedBox(height: 12),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search decks...',
                hintStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          // Deck list
          Flexible(
            child: _filteredDecks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        widget.decks.isEmpty
                            ? 'No decks in your collection yet.'
                            : 'No decks match your search.',
                        style: AppTextStyles.body(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredDecks.length,
                    itemBuilder: (context, index) {
                      final deck = _filteredDecks[index];
                      return ListTile(
                        title: Text(
                          deck.deckName,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: deck.commanderNames.isNotEmpty
                            ? Text(
                                deck.commanderNames.join(', '),
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                        ),
                        onTap: () => Navigator.of(context).pop(deck),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
