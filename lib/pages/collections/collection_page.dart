import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

import '../../models/scryfall_card_model.dart';
import '../../models/search_filters.dart';
import '../../models/deck_model.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../services/local_card_service.dart';
import '../../widgets/search/search_filter_modal.dart';

// WIDGETS DÉCOUPÉS
import '../../widgets/collection/collection_list_tab.dart';
import '../../widgets/collection/collection_sets_tab.dart';
import '../../widgets/collection/quick_add_view.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> with TickerProviderStateMixin {
  final CollectionService _collectionService = CollectionService();
  final WishlistService _wishlistService = WishlistService();
  final LocalCardService _localCardService = LocalCardService();

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // Données
  List<DeckCard> _collection = [];
  List<DeckCard> _wishlist = [];
  List<ScryfallCard> _fullCardData = [];
  
  // États
  bool _isLoading = true;
  // ignore: unused_field
  bool _isImporting = false;
  bool _isQuickAddMode = false;
  SearchFilters _activeFilters = SearchFilters();
  String _currentSort = 'Type';

  // Finance
  double _totalCollectionValue = 0.0;
  double _totalWishlistValue = 0.0;
  double? _evolutionValue;
  double? _evolutionPercent;
  bool _hasCalculatedFinance = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _localCardService.loadLocalData().then((_) { if (mounted) setState(() {}); });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- CHARGEMENT DONNÉES ---
  Future<void> _loadData({bool forceLoading = true}) async {
    if (forceLoading) setState(() => _isLoading = true);

    await Future.wait([
      _collectionService.loadCollection().then((data) => _collection = data),
      _wishlistService.loadWishlist().then((data) => _wishlist = data),
    ]);

    if (!mounted) return;
    await _loadFullCardData();
    await _calculateFinancials();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadFullCardData() async {
    final allCards = [..._collection, ..._wishlist];
    final uniqueIds = allCards
        .where((card) => card.scryfallId.isNotEmpty && !card.scryfallId.startsWith('LOCAL:'))
        .map((card) => card.scryfallId).toSet().toList();

    if (uniqueIds.isEmpty) { _fullCardData = []; return; }

    List<ScryfallCard> loadedCards = [];
    List<String> missingIds = [];

    if (_localCardService.isLoaded) {
      for (String id in uniqueIds) {
        final localCard = _localCardService.getCardById(id);
        if (localCard != null) loadedCards.add(localCard); else missingIds.add(id);
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
    _totalWishlistValue = _wishlist.fold(0.0, (sum, c) => sum + (getPrice(c.scryfallId) * c.quantity));

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

  // --- ACTIONS (IMPORT / EXPORT / FILTRES) ---
  
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
                const Text("Import de masse", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
    final list = _tabController.index == 1 ? _wishlist : _collection;
    if (list.isEmpty) return;
    StringBuffer sb = StringBuffer();
    for (var c in list) sb.writeln("${c.quantity} ${c.name}");
    Share.share(sb.toString());
  }

  Future<void> _openFilterModal() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => SearchFilterModal(initialFilters: _activeFilters),
    );
    if (newFilters != null) setState(() => _activeFilters = newFilters);
  }

  void _toggleQuickAddMode() {
    setState(() {
      _isQuickAddMode = !_isQuickAddMode;
      if (!_isQuickAddMode) _searchController.clear();
    });
    if (!_isQuickAddMode) _loadData(forceLoading: false);
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // HEADER (RESTAURÉ AVEC BOUTONS)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            color: Colors.black.withOpacity(0.3),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ma Collection', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_isQuickAddMode ? Icons.close : Icons.flash_on),
                          color: _isQuickAddMode ? Colors.red : Colors.yellow,
                          onPressed: _toggleQuickAddMode,
                        ),
                        // Boutons restaurés
                        IconButton(icon: const Icon(Icons.file_upload_outlined), color: Colors.yellow.shade700, onPressed: _showBulkImportDialog),
                        IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _exportCurrentList),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.cinzel(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _isQuickAddMode ? 'Recherche rapide...' : 'Filtrer...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _isQuickAddMode ? null : Row(
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
                    fillColor: _isQuickAddMode ? Colors.yellow.withOpacity(0.1) : Colors.black.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) { if (!_isQuickAddMode) setState((){}); },
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.yellow.shade800,
                  labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Cartes (${_collection.length})'),
                    Tab(text: 'Wishlist (${_wishlist.length})'),
                    const Tab(text: 'Éditions'),
                  ],
                ),
              ],
            ),
          ),

          // CONTENU
          Expanded(
            child: _isQuickAddMode
              ? QuickAddView(
                  query: _searchController.text,
                  collection: _collection,
                  onAdd: (c) => _collectionService.upsertCardInCollection(scryfallId: c.id, cardName: c.name, quantityToAdd: 1),
                  onRemove: (c) => _collectionService.upsertCardInCollection(scryfallId: c.id, cardName: c.name, quantityToAdd: -1),
                )
              : _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Onglet Collection (utilise le nouveau widget complexe)
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
                          onRefresh: () => _loadData(forceLoading: false),
                          onUpdateQuantity: (c, q) async {
                             await _collectionService.upsertCardInCollection(scryfallId: c.scryfallId, cardName: c.name, quantityToAdd: q);
                             _calculateFinancials();
                          },
                        ),
                        // Onglet Wishlist
                        CollectionListTab(
                          cards: _wishlist,
                          fullCardData: _fullCardData,
                          filterQuery: _searchController.text,
                          activeFilters: _activeFilters,
                          currentSort: _currentSort,
                          isWishlist: true,
                          financialTotal: _totalWishlistValue,
                          hasCalculatedFinance: _hasCalculatedFinance,
                          onRefresh: () => _loadData(forceLoading: false),
                          onUpdateQuantity: (c, q) async {
                             await _wishlistService.upsertCardInWishlist(scryfallId: c.scryfallId, cardName: c.name, quantityToAdd: q);
                             _calculateFinancials();
                          },
                        ),
                        // Onglet Éditions
                        CollectionSetsTab(collection: _collection),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}