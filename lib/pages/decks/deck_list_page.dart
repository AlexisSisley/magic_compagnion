// Fichier : lib/pages/decks/deck_list_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/deck_list_controller.dart';
import '../../controllers/deck_list_filters.dart';
import '../../models/deck_model.dart';
import '../../router/app_router.dart';
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

  DeckListController get _controller => ref.read(deckListControllerProvider.notifier);

  // --- ACTIONS (UI-only: dialogs, navigation, snackbars) ---

  Future<void> _deleteDeck(String deckId) async {
    await _controller.deleteDeck(deckId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
              const SizedBox(width: 12),
              Text('La Force a effacé ce deck.', style: AppTextStyles.bold(color: Colors.cyanAccent)),
            ],
          ),
          backgroundColor: AppColors.textOnPrimary,
          duration: const Duration(seconds: 2),
        )
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
          decoration: const InputDecoration(hintText: 'Nom du deck...', filled: true, fillColor: AppColors.overlayMedium),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryShade800),
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
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
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
                    icon: const Icon(Icons.file_upload_outlined, color: AppColors.textPrimary),
                    tooltip: 'Importer une liste',
                    onPressed: _showImportDeckDialog
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.scaffoldBackground,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Rechercher un deck...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) => _controller.updateSearchQuery(val),
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.textPrimary))
            : CustomScrollView(
                slivers: [
                  // Filtres
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildIdentityFilterChip(state),
                            const SizedBox(width: 8),
                            _buildChoiceChip(
                              label: state.selectedFormat ?? 'Tous',
                              items: ['Tous', ..._controller.availableFormats],
                              // « Tous » n'est qu'un libelle : le controleur
                              // reçoit null pour « aucun filtre ».
                              onSelected: (v) =>
                                  _controller.updateFormat(v == 'Tous' ? null : v),
                            ),
                            const SizedBox(width: 8),
                            _buildChoiceChip(
                              label: _controller.getSortLabel(state.selectedSort),
                              items: DeckSort.values.map(deckSortLabel).toList(),
                              onSelected: (label) => _controller.updateSort(
                                DeckSort.values.firstWhere(
                                  (s) => deckSortLabel(s) == label,
                                  orElse: () => DeckSort.name,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Liste
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80),
                    sliver: DeckLibraryGrid(
                      decks: state.filteredDecks,
                      prices: state.deckPrices,
                      activeFilters: activeFilterCount(state.criteria),
                      onClearFilters: _controller.clearAllFilters,
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

  Widget _buildIdentityFilterChip(DeckListState state) {
    final bool isActive = state.selectedIdentityName != null;
    return GestureDetector(
      onTap: _openIdentityFilterModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryShade900 : AppColors.textPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.primaryShade700 : AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            if (state.selectedIdentityColors != null && state.selectedIdentityColors!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  children: state.selectedIdentityColors!.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: _getManaIcon(c, size: 14),
                  )).toList(),
                ),
              ),
            Text(
              state.selectedIdentityName ?? 'Couleurs',
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: isActive ? Colors.white : AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({required String label, required List<String> items, required Function(String) onSelected}) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (ctx) => items.map((i) => PopupMenuItem(value: i, child: Text(i))).toList(),
      color: AppColors.cardBackground,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  void _openIdentityFilterModal() {
    final currentState = ref.read(deckListControllerProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Identité Couleur', style: AppTextStyles.pageTitle(fontSize: 20)),
                      if (currentState.selectedIdentityName != null)
                        TextButton(
                          onPressed: () {
                            _controller.clearIdentityFilter();
                            Navigator.pop(context);
                          },
                          child: const Text('Effacer', style: TextStyle(color: AppColors.accentRed))
                        )
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderMedium),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: DeckListController.colorFamilies.entries.map((familyEntry) {
                      return ExpansionTile(
                        title: Text(familyEntry.key, style: AppTextStyles.bold(color: AppColors.primaryShade800)),
                        iconColor: AppColors.primaryShade800,
                        collapsedIconColor: AppColors.textMuted,
                        initiallyExpanded: true,
                        children: familyEntry.value.entries.map((colorEntry) {
                          final name = colorEntry.key;
                          final colors = colorEntry.value;
                          final isSelected = currentState.selectedIdentityName == name;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: AppColors.primaryShade900.withValues(alpha: 0.2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                            title: Row(
                              children: [
                                ...colors.map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 4.0),
                                  child: _getManaIcon(c, size: 20),
                                )),
                                if(colors.isEmpty) _getManaIcon('C', size: 20),
                                const SizedBox(width: 12),
                                Text(name, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                            trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                            onTap: () {
                              _controller.updateIdentityFilter(name, colors);
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }
        );
      }
    );
  }

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
            title: const Text('Supprimer ?', style: TextStyle(color: AppColors.textPrimary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui')),
            ],
          ),
        ),
        onDismissed: () => _deleteDeck(deck.id),
    );
  }

  Widget _getManaIcon(String symbol, {double size = 20}) {
    final url = 'https://svgs.scryfall.io/card-symbols/$symbol.svg';
    return SvgPicture.network(
      url, height: size, width: size,
      placeholderBuilder: (_) => Text(symbol, style: TextStyle(color: AppColors.textPrimary, fontSize: size)),
    );
  }
}
