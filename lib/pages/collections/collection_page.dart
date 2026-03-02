// Fichier : lib/pages/collections/collection_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/pages/collections/wishlist_tab.dart';

import '../../controllers/collection_controller.dart';
import '../../models/search_filters.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../widgets/search/universal_filter_modal.dart';
import '../../widgets/collection/collection_list_tab.dart';
import '../../widgets/collection/collection_sets_tab.dart';

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  CollectionController get _controller => ref.read(collectionControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      _controller.onTabChanged(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- ACTIONS UX (dialogs, navigation, snackbars) ---

  Future<void> _openUniversalModal() async {
    final state = ref.read(collectionControllerProvider);
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => UniversalFilterModal(
        currentFilters: state.activeFilters,
        availableTags: state.availableTags,
      ),
    );

    if (result != null) {
      _controller.updateFilters(result);
    }
  }

  void _openStatsPage() {
    final state = ref.read(collectionControllerProvider);
    context.push(AppRoutes.globalStats, extra: {
      'collection': state.collection,
      'fullCardData': state.fullCardData,
      'totalValue': state.totalCollectionValue,
    });
  }

  Future<void> _addSelectedToDeck() async {
    final state = ref.read(collectionControllerProvider);
    if (state.selectedCardIds.isEmpty) return;
    final decks = await _controller.getDecks();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajouter ${state.selectedCardIds.length} cartes à...', style: AppTextStyles.pageTitle(fontSize: 20)),
              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.add_circle, color: AppColors.success),
                title: Text('Nouveau Deck', style: AppTextStyles.cinzel()),
                onTap: () async {
                  Navigator.pop(context);
                  _createNewDeckAndAddCards();
                },
              ),
              const Divider(color: AppColors.borderMedium),
              Expanded(
                child: decks.isEmpty
                  ? Center(child: Text('Aucun deck existant.', style: AppTextStyles.cinzel(color: AppColors.textMuted)))
                  : ListView.builder(
                      itemCount: decks.length,
                      itemBuilder: (context, index) {
                        final deck = decks[index];
                        return ListTile(
                          leading: const Icon(Icons.style, color: AppColors.accent),
                          title: Text(deck.name, style: AppTextStyles.cinzel()),
                          subtitle: Text('${deck.format} • ${deck.mainboard.length} cartes', style: const TextStyle(color: AppColors.textMuted)),
                          onTap: () {
                            Navigator.pop(context);
                            _processAddCardsToDeck(deck.id, deck.name);
                          },
                        );
                      },
                    ),
              )
            ],
          ),
        );
      }
    );
  }

  Future<void> _createNewDeckAndAddCards() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        title: const Text('Nom du Deck', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(controller: controller, style: const TextStyle(color: AppColors.textPrimary), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Créer')),
        ],
      )
    );

    if (name != null && name.isNotEmpty) {
      final deckId = await _controller.createNewDeckAndGetId(name);
      _processAddCardsToDeck(deckId, name);
    }
  }

  Future<void> _processAddCardsToDeck(String deckId, String deckName) async {
    final result = await _controller.addSelectedCardsToDeck(deckId, deckName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message, style: AppTextStyles.cinzel()),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _importBulk() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fonction d'import conservée (TODO: Implémenter appel modale)")));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionControllerProvider);
    final activeFilterCount = state.activeFilterCount;

    return Stack(
      children: [
        NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                title: Text('Ma Collection', style: AppTextStyles.bold()),
                centerTitle: false,
                pinned: true,
                floating: true,
                expandedHeight: 120.0,
                backgroundColor: AppColors.textOnPrimary,
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.bar_chart), onPressed: _openStatsPage),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'import') _importBulk();
                      if (val == 'clear') _controller.clearCollection();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'import', child: Text('Importer (Masse)')),
                      const PopupMenuItem(value: 'clear', child: Text('Tout effacer', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.scaffoldBackground,
                    child: Row(
                      children: [
                        // Barre de recherche
                        Expanded(
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
                                hintText: 'Rechercher...',
                                hintStyle: TextStyle(color: AppColors.textMuted),
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: (val) => setState((){}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Bouton Filtre Unifié
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: activeFilterCount > 0 ? AppColors.primaryShade800 : AppColors.textPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.tune),
                                color: activeFilterCount > 0 ? Colors.black : AppColors.textSecondary,
                                onPressed: _openUniversalModal,
                              ),
                            ),
                            if (activeFilterCount > 0)
                              Positioned(
                                top: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                  child: Text('$activeFilterCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primaryShade800,
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: AppTextStyles.bold(),
                    tabs: [
                      Tab(text: 'Cartes (${state.collection.length})'),
                      Tab(text: 'Wishlists (${state.wishlists.length})'),
                      const Tab(text: 'Éditions'),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.textPrimary))
            : TabBarView(
                controller: _tabController,
                children: [
                  CollectionListTab(
                    cards: state.collection,
                    fullCardData: state.fullCardData,
                    filterQuery: _searchController.text,
                    activeFilters: state.activeFilters,
                    currentSort: state.activeFilters.sortType,
                    isWishlist: false,
                    financialTotal: state.totalCollectionValue,
                    evoVal: state.evolutionValue,
                    evoPct: state.evolutionPercent,
                    hasCalculatedFinance: state.hasCalculatedFinance,

                    // --- SELECTION PROPS ---
                    isSelectionMode: state.isSelectionMode,
                    selectedIds: state.selectedCardIds,
                    onToggleSelection: _controller.toggleCardSelection,
                    onToggleSelectionMode: _controller.toggleSelectionMode,

                    onRefresh: () => _controller.loadData(forceLoading: false),
                    onUpdateQuantity: (c, q) => _controller.updateQuantity(c, q),
                    onToggleFoil: (c) => _controller.toggleFoil(c),
                    onUpdateTags: (c, newTags) => _controller.updateTags(c, newTags),
                    availableTags: state.availableTags,
                  ),
                  WishlistTab(
                    wishlists: state.wishlists,
                    fullCardData: state.fullCardData,
                    totalValue: state.totalWishlistValue,
                    wishlistService: ref.read(wishlistServiceProvider),
                    onRefresh: () => _controller.loadData(forceLoading: false),
                  ),
                  CollectionSetsTab(collection: state.collection, onRefresh: () => _controller.loadData(forceLoading: false)),
                ],
              ),
        ),

        // --- FAB POSITIONNÉ MANUELLEMENT ---
        if (state.isSelectionMode && state.selectedCardIds.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _addSelectedToDeck,
              backgroundColor: Colors.green.shade700,
              icon: const Icon(Icons.add_to_photos),
              label: Text('Ajouter au Deck (${state.selectedCardIds.length})', style: AppTextStyles.bold()),
            ),
          ),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverTabBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.scaffoldBackground, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
