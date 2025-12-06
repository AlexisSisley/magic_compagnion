// Fichier : lib/pages/collections/collection_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:magic_companion/pages/collections/global_stats_page.dart';
import 'package:magic_companion/pages/collections/wishlist_tab.dart';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

import '../../models/scryfall_card_model.dart';
import '../../models/search_filters.dart';
import '../../models/deck_model.dart';
import '../../models/wishlist_model.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../services/local_card_service.dart';
import '../../services/deck_service.dart'; 
import '../../widgets/search/search_filter_modal.dart';

import '../../widgets/collection/collection_list_tab.dart';
import '../../widgets/collection/collection_sets_tab.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> with TickerProviderStateMixin {
  final CollectionService _collectionService = CollectionService();
  final WishlistService _wishlistService = WishlistService();
  final LocalCardService _localCardService = LocalCardService();
  final DeckService _deckService = DeckService(); 

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<DeckCard> _collection = [];
  List<Wishlist> _wishlists = []; 
  List<ScryfallCard> _fullCardData = [];
  
  bool _isLoading = true; 
  // ignore: unused_field
  bool _isImporting = false; // Restauré
  
  // --- NOUVEAU : Mode Sélection ---
  bool _isSelectionMode = false;
  final Set<String> _selectedCardIds = {}; 

  SearchFilters _activeFilters = SearchFilters();
  String _currentSort = 'Type';

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
      if (_isSelectionMode) _toggleSelectionMode();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- CHARGEMENT DONNÉES ---
  Future<void> _loadData({bool forceLoading = true}) async {
    if (forceLoading) setState(() => _isLoading = true);

    await Future.wait([
      _collectionService.loadCollection().then((data) => _collection = data),
      _wishlistService.loadWishlists().then((data) => _wishlists = data),
    ]);

    if (!_localCardService.isLoaded) {
       await _localCardService.loadLocalData();
    }

    await _loadFullCardData(); 
    await _calculateFinancials();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
        if (localCard != null) {
          loadedCards.add(localCard);
        } else {
          missingIds.add(id);
        }
      }
    } else {
      missingIds = uniqueIds;
    }

    if (missingIds.isNotEmpty) {
      const int chunkSize = 75;
      for (var i = 0; i < missingIds.length; i += chunkSize) {
        final end = (i + chunkSize < missingIds.length) ? i + chunkSize : missingIds.length;
        final batch = missingIds.sublist(i, end);
        final requestBody = json.encode({'identifiers': batch.map((id) => {'id': id}).toList()});

        try {
          final response = await http.post(
            Uri.parse('https://api.scryfall.com/cards/collection'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          );
          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
            final List<ScryfallCard> batchCards = (data['data'] as List).map((cardJson) => ScryfallCard.fromJson(cardJson)).toList();
            loadedCards.addAll(batchCards);
          }
        } catch (e) { log('Erreur API: $e'); }
      }
    }
    _fullCardData = loadedCards;
  }

  Future<void> _calculateFinancials() async {
    double getPrice(String id) {
      try {
        final c = _fullCardData.firstWhere((s) => s.id == id);
        return double.tryParse(c.prices['eur'] ?? '0') ?? 0.0;
      } catch (e) { return 0.0; }
    }
    
    _totalCollectionValue = _collection.fold(0.0, (sum, c) => sum + (getPrice(c.scryfallId) * c.quantity));
    
    _totalWishlistValue = 0.0;
    for (var list in _wishlists) {
      for (var c in list.cards) {
        _totalWishlistValue += (getPrice(c.scryfallId) * c.quantity);
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

  // --- ACTIONS ---
  
  // RESTAURÉ : Modale Import Massif
  Future<void> _showBulkImportDialog() async {
    final TextEditingController importController = TextEditingController();
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const Text("Import de masse (Collection)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(child: TextField(controller: importController, maxLines: null, expands: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(filled: true, fillColor: Colors.black45, hintText: "Collez votre liste ici..."))),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () { Navigator.pop(context); _performBulkImport(importController.text); },
                  child: const Text("Importer"),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // RESTAURÉ : Action Import Massif
  Future<void> _performBulkImport(String text) async {
    setState(() { _isLoading = true; _isImporting = true; });
    final lines = text.split('\n').where((s) => s.trim().isNotEmpty).toList();
    final result = await _collectionService.importBatchCards(lines);
    await _loadData(forceLoading: false);
    if (mounted) {
      setState(() { _isLoading = false; _isImporting = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ajouté: ${result['added']} cartes"), backgroundColor: Colors.green));
    }
  }

  void _exportCurrentList() {
    if (_tabController.index == 1) {
      StringBuffer sb = StringBuffer();
      sb.writeln("=== Mes Wishlists ===");
      for(var w in _wishlists) {
        sb.writeln("\n[${w.name}]");
        for(var c in w.cards) sb.writeln("${c.quantity} ${c.name}");
      }
      Share.share(sb.toString());
    } else {
      if (_collection.isEmpty) return;
      StringBuffer sb = StringBuffer();
      for (var c in _collection) sb.writeln("${c.quantity} ${c.name}");
      Share.share(sb.toString());
    }
  }

  Future<void> _openFilterModal() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => SearchFilterModal(initialFilters: _activeFilters),
    );
    if (newFilters != null) setState(() => _activeFilters = newFilters);
  }

  void _openStatsPage() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => GlobalStatsPage(
      collection: _collection,
      fullCardData: _fullCardData,
      totalValue: _totalCollectionValue,
    )));
  }

  Future<void> _showClearCollectionDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Vider la Collection ?", style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Attention, cette action supprimera définitivement toutes les cartes de votre collection. Êtes-vous sûr ?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
            child: const Text("Tout Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm == true) {
      await _collectionService.clearCollection();
      setState(() {
        _collection = [];
        _totalCollectionValue = 0;
        _evolutionValue = 0;
        _evolutionPercent = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Collection vidée."), backgroundColor: Colors.red));
    }
  }
  // --- LOGIQUE DE SÉLECTION MULTIPLE ---

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
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, controller.text), 
            child: const Text("Créer")
          ),
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
      } catch (e) {
        print("Erreur ajout carte $id : $e");
      }
    }

    if (mounted) {
      setState(() { 
        _isLoading = false; 
        _isSelectionMode = false; 
        _selectedCardIds.clear(); 
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("$count cartes ajoutées à $deckName", style: GoogleFonts.cinzel()),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( 
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            color: Colors.black.withOpacity(0.3),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white70),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                        const SizedBox(width: 8),
                        Text('Ma Collection', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [   
                        if (_tabController.index == 0)
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                            tooltip: "Vider la collection",
                            onPressed: _showClearCollectionDialog,
                          ),                     
                        IconButton(
                          icon: const Icon(Icons.bar_chart, color: Colors.blueAccent),
                          tooltip: "Statistiques Globales",
                          onPressed: _openStatsPage,
                        ),
                        IconButton(icon: const Icon(Icons.file_upload_outlined), color: Colors.yellow.shade700, onPressed: _showBulkImportDialog),
                        
                        IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _exportCurrentList),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // BARRE DE RECHERCHE
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.cinzel(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Rechercher / Filtrer...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.filter_list, color: Colors.white70), onPressed: _openFilterModal),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.sort, color: Colors.white70),
                          onSelected: (val) => setState(() => _currentSort = val),
                          itemBuilder: (ctx) => ['Type', 'Nom', 'Prix'].map((t) => PopupMenuItem(value: t, child: Text(t))).toList(),
                        )
                      ],
                    ),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState((){}),
                ),
                
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.yellow.shade800,
                  labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Cartes (${_collection.length})'),
                    Tab(text: 'Wishlists (${_wishlists.length})'),
                    const Tab(text: 'Éditions'),
                  ],
                ),
              ],
            ),
          ),

          // CONTENU
          Expanded(
            child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        CollectionListTab(
                          cards: _collection,
                          fullCardData: _fullCardData,
                          filterQuery: _searchController.text,
                          activeFilters: _activeFilters,
                          currentSort: _currentSort,
                          isWishlist: false,
                          financialTotal: _totalCollectionValue,
                          evoVal: _evolutionValue,
                          evoPct: _evolutionPercent,
                          hasCalculatedFinance: _hasCalculatedFinance,
                          isSelectionMode: _isSelectionMode,
                          selectedIds: _selectedCardIds,
                          onToggleSelection: _toggleCardSelection,
                          onToggleSelectionMode: _toggleSelectionMode,
                          onRefresh: () => _loadData(forceLoading: false),
                          onUpdateQuantity: (c, q) async {
                             // upsertCardInCollection retourne la liste mise à jour
                             final updatedList = await _collectionService.upsertCardInCollection(
                               scryfallId: c.scryfallId, 
                               cardName: c.name, 
                               quantityToAdd: q
                             );
                             
                             // IMPORTANT : On met à jour l'état local pour rafraîchir l'interface
                             // Si qté = 0, la carte n'est plus dans updatedList, donc elle disparaît
                             setState(() {
                               _collection = updatedList;
                             });
                             
                             _calculateFinancials();
                          },
                        ),
                        // UTILISATION DU NOUVEAU WIDGET WISHLIST
                        WishlistTab(
                          wishlists: _wishlists,
                          fullCardData: _fullCardData,
                          totalValue: _totalWishlistValue,
                          wishlistService: _wishlistService,
                          onRefresh: () => _loadData(forceLoading: false),
                        ),
                        CollectionSetsTab(
                          collection: _collection,
                          onRefresh: () => _loadData(forceLoading: false),
                        ),
                      ],
                    ),
          ),
        ],
      ),
      floatingActionButton: (_isSelectionMode && _selectedCardIds.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _addSelectedToDeck,
              backgroundColor: Colors.green.shade700,
              icon: const Icon(Icons.add_to_photos),
              label: Text("Ajouter au Deck (${_selectedCardIds.length})", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}