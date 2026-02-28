// Fichier : lib/pages/collections/collection_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: Colors.transparent,
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
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Ajouter ${state.selectedCardIds.length} cartes à...", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.green),
                title: Text("Nouveau Deck", style: GoogleFonts.cinzel(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  _createNewDeckAndAddCards();
                },
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: decks.isEmpty
                  ? Center(child: Text("Aucun deck existant.", style: GoogleFonts.cinzel(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: decks.length,
                      itemBuilder: (context, index) {
                        final deck = decks[index];
                        return ListTile(
                          leading: const Icon(Icons.style, color: Colors.blueAccent),
                          title: Text(deck.name, style: GoogleFonts.cinzel(color: Colors.white)),
                          subtitle: Text("${deck.format} • ${deck.mainboard.length} cartes", style: const TextStyle(color: Colors.white54)),
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
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Nom du Deck", style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, style: const TextStyle(color: Colors.white), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annuler")),
          ElevatedButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text("Créer")),
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
        content: Text(result.message, style: GoogleFonts.cinzel()),
        backgroundColor: Colors.green,
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
                title: Text('Ma Collection', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                centerTitle: false,
                pinned: true,
                floating: true,
                expandedHeight: 120.0,
                backgroundColor: Colors.black,
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
                      const PopupMenuItem(value: 'import', child: Text("Importer (Masse)")),
                      const PopupMenuItem(value: 'clear', child: Text("Tout effacer", style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF1A1A1A),
                    child: Row(
                      children: [
                        // Barre de recherche
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Rechercher...",
                                hintStyle: TextStyle(color: Colors.white54),
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.search, color: Colors.white54),
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
                                color: activeFilterCount > 0 ? Colors.yellow.shade800 : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.tune),
                                color: activeFilterCount > 0 ? Colors.black : Colors.white70,
                                onPressed: _openUniversalModal,
                              ),
                            ),
                            if (activeFilterCount > 0)
                              Positioned(
                                top: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: Text("$activeFilterCount", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
                    indicatorColor: Colors.yellow.shade800,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
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
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
              label: Text("Ajouter au Deck (${state.selectedCardIds.length})", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
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
    return Container(color: const Color(0xFF1A1A1A), child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
