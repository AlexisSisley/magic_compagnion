// Fichier : lib/pages/decks/deck_list_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/deck_list_controller.dart';
import '../../controllers/deck_list_filters.dart';
import '../../models/deck_model.dart';
import '../../router/app_router.dart';
import '../../widgets/decks/deck_filter_bar.dart';
import '../../widgets/decks/deck_filter_sheet.dart';
import '../../widgets/decks/deck_import_modal.dart';
import '../../widgets/decks/deck_library_grid.dart';
import '../../widgets/decks/deck_list_card.dart';

class DeckListPage extends ConsumerStatefulWidget {
  const DeckListPage({super.key});

  @override
  ConsumerState<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends ConsumerState<DeckListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DeckListController get _controller =>
      ref.read(deckListControllerProvider.notifier);

  // --- ACTIONS (UI-only: dialogs, navigation, snackbars) ---

  /// Le champ de recherche garde son propre texte : il faut le vider aussi,
  /// sinon la liste est rendue mais la recherche reste affichee.
  void _clearSearchAndFilters() {
    _searchController.clear();
    _controller.clearSearchAndFilters();
  }

  void _clearFilter(DeckFilterKind kind) {
    switch (kind) {
      case DeckFilterKind.format:
        _controller.updateFormat(null);
      case DeckFilterKind.identity:
        _controller.clearIdentityFilter();
      case DeckFilterKind.tags:
        _controller.updateTags(const []);
      case DeckFilterKind.price:
        _controller.updatePriceRange(null);
    }
  }

  Future<void> _openFilterSheet(DeckListState state) {
    // Le plafond du curseur suit le deck le plus cher ; la feuille l'arrondit
    // et retombe sur 50 € quand aucun prix n'est connu.
    final maxPrice = state.deckPrices.values.fold<double>(
      0,
      (max, p) => p > max ? p : max,
    );
    return showDeckFilterSheet(
      context,
      state: state,
      controller: _controller,
      formats: _controller.availableFormats,
      tags: _controller.availableTags,
      maxPrice: maxPrice,
    );
  }

  Future<void> _deleteDeck(String deckId) async {
    await _controller.deleteDeck(deckId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
              const SizedBox(width: 12),
              Text(
                'La Force a effacé ce deck.',
                style: AppTextStyles.bold(color: Colors.cyanAccent),
              ),
            ],
          ),
          backgroundColor: AppColors.textOnPrimary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showCreateDeckDialog() async {
    final controller = TextEditingController();
    final String? name = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        title: Text('Nouveau Deck', style: AppTextStyles.sectionTitle()),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nom du deck...',
            filled: true,
            fillColor: AppColors.overlayMedium,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryShade800,
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _controller.createNewDeck(name);
    }
  }

  Future<void> _showImportDeckDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => const DeckImportModal(),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deckListControllerProvider);

    // Fond opaque : le shell peint sa texture derrière tous les onglets, et la
    // grille d'art ne doit pas la laisser transparaître entre les tuiles.
    return ColoredBox(
      color: AppColors.scaffoldBackground,
      child: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    SliverAppBar(
                      title: Text('Mes Decks', style: AppTextStyles.bold()),
                      centerTitle: false,
                      pinned: true,
                      floating: true,
                      snap: true,
                      expandedHeight: 120.0,
                      backgroundColor: AppColors.textOnPrimary,
                      // Pas de `leading` : le Drawer a disparu du shell, et la
                      // poignee qui l'ouvrait ne faisait plus rien. Un bouton
                      // menu inerte est la premiere chose qu'un utilisateur tape
                      // apres la mise a jour.
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            color: AppColors.textPrimary,
                          ),
                          tooltip: 'Importer une liste',
                          onPressed: _showImportDeckDialog,
                        ),
                      ],
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(70),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: AppColors.scaffoldBackground,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Rechercher un deck...',
                                hintStyle: TextStyle(
                                  color: AppColors.textMuted,
                                ),
                                border: InputBorder.none,
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: AppColors.textMuted,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              onChanged: (val) =>
                                  _controller.updateSearchQuery(val),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ];
                },
            body: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.textPrimary,
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Filtres
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: DeckFilterBar(
                            criteria: state.criteria,
                            activeCount: activeFilterCount(state.criteria),
                            onOpenFilters: () => _openFilterSheet(state),
                            onSort: _controller.updateSort,
                            onClear: _clearFilter,
                          ),
                        ),
                      ),

                      // Liste
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 80),
                        sliver: DeckLibraryGrid(
                          decks: state.filteredDecks,
                          libraryEmpty: state.decks.isEmpty,
                          onClearAll: _clearSearchAndFilters,
                          tileBuilder: (deck) => _buildDeckCard(deck, state),
                        ),
                      ),
                    ],
                  ),
          ),

          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _showCreateDeckDialog,
              backgroundColor: AppColors.primaryShade800,
              foregroundColor: AppColors.textOnPrimary,
              icon: const Icon(Icons.add),
              // Pas de couleur explicite : le libelle herite du
              // `foregroundColor` du bouton. Une couleur posee sur le
              // TextStyle GAGNE sur le foregroundColor -- c'est ainsi que ce
              // libelle restait blanc sur l'or, a 3,77:1, alors que l'icone
              // etait deja passee en encre sombre.
              label: const Text('Nouveau Deck'),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildDeckCard(Deck deck, DeckListState state) {
    // Pas de marge ici : la grille porte marges et gouttières.
    return DeckListCard(
      deck: deck,
      totalPrice: state.deckPrices[deck.id] ?? 0.0,
      onTap: () async {
        await context.push(AppRoutes.deckDetail, extra: deck);
        _controller.loadDecks();
      },
      confirmDismiss: (d) => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          title: const Text(
            'Supprimer ?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Oui'),
            ),
          ],
        ),
      ),
      onDismissed: () => _deleteDeck(deck.id),
    );
  }
}
