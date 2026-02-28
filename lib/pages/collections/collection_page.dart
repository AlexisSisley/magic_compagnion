// Fichier : lib/pages/collections/collection_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/pages/collections/global_stats_page.dart';
import 'package:magic_companion/pages/collections/wishlist_tab.dart';

import '../../models/scryfall_card_model.dart';
import '../../models/search_filters.dart';
import '../../models/deck_model.dart';
import '../../models/wishlist_model.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../services/local_card_service.dart';
import '../../services/deck_service.dart';
import '../../services/scryfall_api_service.dart';
import '../../providers/service_providers.dart';
import '../../widgets/search/universal_filter_modal.dart';
import '../../widgets/collection/collection_list_tab.dart';
import '../../widgets/collection/collection_sets_tab.dart';

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> with TickerProviderStateMixin {
  CollectionService get _collectionService => ref.read(collectionServiceProvider);
  WishlistService get _wishlistService => ref.read(wishlistServiceProvider);
  LocalCardService get _localCardService => ref.read(localCardServiceProvider);
  DeckService get _deckService => ref.read(deckServiceProvider);
  ScryfallApiService get _apiService => ref.read(scryfallApiServiceProvider);

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<DeckCard> _collection = [];
  List<Wishlist> _wishlists = []; 
  List<ScryfallCard> _fullCardData = [];
  List<String> _availableTags = [];
  
  bool _isLoading = true; 
  SearchFilters _activeFilters = SearchFilters();

  // --- SELECTION MODE ---
  bool _isSelectionMode = false;
  final Set<String> _selectedCardIds = {};

  // Stats
  double _totalCollectionValue = 0.0;
  double _totalWishlistValue = 0.0;
  double? _evolutionValue;
  double? _evolutionPercent;
  bool _hasCalculatedFinance = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _localCardService.loadLocalData(); 
    _loadData();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      if (_tabController.index == 1 || _tabController.index == 2) {
        _loadData(forceLoading: false);
      }
      // Désactiver la sélection si on change d'onglet
      if (_isSelectionMode) _toggleSelectionMode();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- CHARGEMENT ---
  Future<void> _loadData({bool forceLoading = true}) async {
    if (forceLoading) setState(() => _isLoading = true);

    await Future.wait([
      _collectionService.loadCollection().then((data) => _collection = data),
      _wishlistService.loadWishlists().then((data) => _wishlists = data),
      _collectionService.getAllUniqueTags().then((data) => _availableTags = data),
    ]);

    if (!_localCardService.isLoaded) await _localCardService.loadLocalData();

    await _loadFullCardData(); 
    await _calculateFinancials();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadFullCardData() async {
    final List<DeckCard> allWishlistCards = _wishlists.expand((w) => w.cards).toList();
    final allCards = [..._collection, ...allWishlistCards];
    final uniqueIds = allCards
        .where((card) => card.scryfallId.isNotEmpty && !card.scryfallId.startsWith('LOCAL:'))
        .map((card) => card.scryfallId).toSet().toList();

    if (uniqueIds.isEmpty) { _fullCardData = []; return; }

    List<ScryfallCard> loadedCards = [];
    List<String> missingIds = [];

    if (_localCardService.isLoaded) {
      for (String id in uniqueIds) {
        final localCard = _localCardService.getCardById(id);
        if (localCard != null) loadedCards.add(localCard);
        else missingIds.add(id);
      }
    } else {
      missingIds = uniqueIds;
    }

    if (missingIds.isNotEmpty) {
      const int chunkSize = 75;
      for (var i = 0; i < missingIds.length; i += chunkSize) {
        final end = (i + chunkSize < missingIds.length) ? i + chunkSize : missingIds.length;
        final batch = missingIds.sublist(i, end);
        try {
          final data = await _apiService.fetchCollection(
            batch.map((id) => {'id': id}).toList(),
          );
          loadedCards.addAll((data['data'] as List).map((j) => ScryfallCard.fromJson(j)));
        } catch (e) { log('Erreur API: $e'); }
      }
    }
    _fullCardData = loadedCards;
  }

  Future<void> _calculateFinancials() async {
    double getPrice(String id, bool isFoil) {
      try {
        final c = _fullCardData.firstWhere((s) => s.id == id);
        if (isFoil) return double.tryParse(c.prices['eur_foil'] ?? c.prices['eur'] ?? '0') ?? 0.0;
        else return double.tryParse(c.prices['eur'] ?? '0') ?? 0.0;
      } catch (e) { return 0.0; }
    }
    _totalCollectionValue = _collection.fold(0.0, (sum, c) => sum + (getPrice(c.scryfallId, c.isFoil) * c.quantity));
    _totalWishlistValue = 0.0;
    for (var list in _wishlists) {
      for (var c in list.cards) {
        _totalWishlistValue += (getPrice(c.scryfallId, c.isFoil) * c.quantity);
      }
    }
    await _collectionService.recordDailyValue(_totalCollectionValue);
    final evo = await _collectionService.getEvolutionSince(7);
    if (mounted) {
      setState(() {
        _evolutionValue = evo?['diffValue'];
        _evolutionPercent = evo?['diffPercentage'];
        _hasCalculatedFinance = true;
      });
    }
  }

  // --- ACTIONS UX ---
  Future<void> _openUniversalModal() async {
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UniversalFilterModal(
        currentFilters: _activeFilters,
        availableTags: _availableTags,
      ),
    );

    if (result != null) {
      setState(() { _activeFilters = result; });
    }
  }

  void _openStatsPage() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => GlobalStatsPage(
      collection: _collection,
      fullCardData: _fullCardData,
      totalValue: _totalCollectionValue,
    )));
  }

  // --- GESTION SÉLECTION ---
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedCardIds.clear();
    });
  }

  void _toggleCardSelection(String scryfallId) {
    setState(() {
      if (_selectedCardIds.contains(scryfallId)) {
        _selectedCardIds.remove(scryfallId);
      } else {
        _selectedCardIds.add(scryfallId);
      }
    });
  }

  Future<void> _addSelectedToDeck() async {
    if (_selectedCardIds.isEmpty) return;
    final decks = await _deckService.loadDecks();
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
              Text("Ajouter ${_selectedCardIds.length} cartes à...", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
      await _deckService.createNewDeck(name);
      final decks = await _deckService.loadDecks();
      final newDeck = decks.last; 
      _processAddCardsToDeck(newDeck.id, newDeck.name);
    }
  }

  Future<void> _processAddCardsToDeck(String deckId, String deckName) async {
    setState(() => _isLoading = true);
    int count = 0;
    for (String id in _selectedCardIds) {
      try {
        final collectionCard = _collection.firstWhere((c) => c.scryfallId == id);
        await _deckService.upsertCardInDeck(
          deckId: deckId, 
          scryfallId: id, 
          cardName: collectionCard.name, 
          quantityToAdd: 1
        );
        count++;
      } catch (e) { log("Erreur ajout carte $id : $e", name: 'CollectionPage'); }
    }

    if (mounted) {
      setState(() { _isLoading = false; _isSelectionMode = false; _selectedCardIds.clear(); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$count cartes ajoutées à $deckName", style: GoogleFonts.cinzel()),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _importBulk() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fonction d'import conservée (TODO: Implémenter appel modale)")));
  }

  @override
  Widget build(BuildContext context) {
    int activeFilterCount = 0;
    if (_activeFilters.colors.isNotEmpty) activeFilterCount++;
    if (_activeFilters.cardType != null) activeFilterCount++;
    if (_activeFilters.tags.isNotEmpty) activeFilterCount++;
    if (_activeFilters.keyword != null) activeFilterCount++;

    // --- CORRECTION : Suppression du Scaffold interne ---
    // Nous utilisons un Stack pour que le FAB flotte au dessus du contenu
    // Le NestedScrollView permet de gérer la SliverAppBar qui contient le bouton menu.
    // Le bouton menu trouvera le Scaffold parent (dans AppShell) car il n'est plus bloqué.
    
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
                  // Le context ici est celui du Builder du NestedScrollView, enfant de CollectionPage.
                  // Comme CollectionPage n'a plus de Scaffold, il remonte à AppShell.
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.bar_chart), onPressed: _openStatsPage),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'import') _importBulk();
                      if (val == 'clear') _collectionService.clearCollection().then((_) => _loadData());
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
                      Tab(text: 'Cartes (${_collection.length})'),
                      Tab(text: 'Wishlists (${_wishlists.length})'),
                      const Tab(text: 'Éditions'),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : TabBarView(
                controller: _tabController,
                children: [
                  CollectionListTab(
                    cards: _collection,
                    fullCardData: _fullCardData,
                    filterQuery: _searchController.text,
                    activeFilters: _activeFilters,
                    currentSort: _activeFilters.sortType,
                    isWishlist: false,
                    financialTotal: _totalCollectionValue,
                    evoVal: _evolutionValue,
                    evoPct: _evolutionPercent,
                    hasCalculatedFinance: _hasCalculatedFinance,
                    
                    // --- SELECTION PROPS ---
                    isSelectionMode: _isSelectionMode,
                    selectedIds: _selectedCardIds,
                    onToggleSelection: _toggleCardSelection,
                    onToggleSelectionMode: _toggleSelectionMode,
                    
                    onRefresh: () => _loadData(forceLoading: false),
                    onUpdateQuantity: (c, q) async {
                       await _collectionService.upsertCardInCollection(scryfallId: c.scryfallId, cardName: c.name, quantityToAdd: q, isFoil: c.isFoil);
                       _loadData(forceLoading: false);
                    },
                    onToggleFoil: (c) async {
                      await _collectionService.upsertCardInCollection(scryfallId: c.scryfallId, cardName: c.name, quantityToAdd: -1, isFoil: c.isFoil);
                      await _collectionService.upsertCardInCollection(scryfallId: c.scryfallId, cardName: c.name, quantityToAdd: 1, isFoil: !c.isFoil, newTags: c.tags);
                      _loadData(forceLoading: false);
                    },
                    onUpdateTags: (c, newTags) async {
                      await _collectionService.upsertCardInCollection(scryfallId: c.scryfallId, cardName: c.name, isFoil: c.isFoil, newTags: newTags);
                      _loadData(forceLoading: false);
                    },
                    availableTags: _availableTags,
                  ),
                  WishlistTab(
                    wishlists: _wishlists,
                    fullCardData: _fullCardData,
                    totalValue: _totalWishlistValue,
                    wishlistService: _wishlistService,
                    onRefresh: () => _loadData(forceLoading: false),
                  ),
                  CollectionSetsTab(collection: _collection, onRefresh: () => _loadData(forceLoading: false)),
                ],
              ),
        ),
        
        // --- FAB POSITIONNÉ MANUELLEMENT ---
        if (_isSelectionMode && _selectedCardIds.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _addSelectedToDeck,
              backgroundColor: Colors.green.shade700,
              icon: const Icon(Icons.add_to_photos),
              label: Text("Ajouter au Deck (${_selectedCardIds.length})", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
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