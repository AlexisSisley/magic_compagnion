// Fichier : lib/pages/collections/collection_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

import '../../models/scryfall_card_model.dart';
import '../../models/search_filters.dart';
import '../../models/deck_model.dart';
import '../../models/wishlist_model.dart';
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../services/local_card_service.dart';
import '../../widgets/search/search_filter_modal.dart';

import '../../widgets/collection/collection_list_tab.dart';
import '../../widgets/collection/collection_sets_tab.dart';
import '../../widgets/collection/quick_add_view.dart';
import '../wishlists/wishlist_detail_page.dart';

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
  
  List<DeckCard> _collection = [];
  List<Wishlist> _wishlists = []; 
  List<ScryfallCard> _fullCardData = [];
  
  bool _isLoading = true; // Chargement initial bloquant (juste la liste locale)
  bool _isBackgroundLoading = false; // Chargement des prix/images (non bloquant)
  
  // ignore: unused_field
  bool _isImporting = false;
  bool _isQuickAddMode = false;
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
      // Rafraichir si on arrive sur Wishlist (1) OU Éditions (2)
      if (_tabController.index == 1 || _tabController.index == 2) {
        _loadData(forceLoading: false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- CHARGEMENT DONNÉES OPTIMISÉ ---
  Future<void> _loadData({bool forceLoading = true}) async {
    // 1. Afficher le loader bloquant uniquement si demandé (ex: premier lancement)
    if (forceLoading) setState(() => _isLoading = true);

    // 2. Charger les listes locales (Très rapide : JSON local)
    await Future.wait([
      _collectionService.loadCollection().then((data) => _collection = data),
      _wishlistService.loadWishlists().then((data) => _wishlists = data),
    ]);

    // 3. AFFICHER L'UI IMMÉDIATEMENT (On débloque l'interface ici !)
    if (mounted) {
      setState(() {
        _isLoading = false; 
        _isBackgroundLoading = true; // On indique que les prix chargent
      });
    }

    // 4. TÂCHE DE FOND : Récupérer les données API (Lent)
    // On s'assure d'abord que la DB locale est prête pour éviter d'appeler l'API pour rien
    if (!_localCardService.isLoaded) {
       await _localCardService.loadLocalData();
    }

    await _loadFullCardData(); // Appel API ou Local DB Match
    await _calculateFinancials();

    // 5. Mise à jour finale (Apparition des prix et images)
    if (mounted) {
      setState(() {
        _isBackgroundLoading = false;
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

    // Priorité à la base locale (Instantané)
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

    // Appel API uniquement pour les cartes manquantes (Batch par 75)
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

  void _toggleQuickAddMode() {
    setState(() {
      _isQuickAddMode = !_isQuickAddMode;
      if (!_isQuickAddMode) _searchController.clear();
    });
    if (!_isQuickAddMode) _loadData(forceLoading: false);
  }

  Future<void> _showCreateWishlistDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Nouvelle Wishlist", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller, 
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nom (ex: Deck Commander)",
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Annuler", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _wishlistService.createWishlist(controller.text);
                Navigator.pop(c);
                _loadData(forceLoading: false);
              }
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
            child: const Text("Créer", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
          )
        ],
      )
    );
  }

  void _showGlobalWishlistTopCards() {
    List<Map<String, dynamic>> topCards = [];
    for (var wishlist in _wishlists) {
      for (var card in wishlist.cards) {
        try {
          final scryfallCard = _fullCardData.firstWhere((s) => s.id == card.scryfallId);
          final double price = double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
          if (price > 0) {
            topCards.add({
              'name': scryfallCard.name,
              'wishlistName': wishlist.name,
              'price': price,
              'quantity': card.quantity,
              'image': scryfallCard.smallImageUrl,
              'totalPrice': price * card.quantity,
            });
          }
        } catch (e) { }
      }
    }
    topCards.sort((a, b) => (b['totalPrice'] as double).compareTo(a['totalPrice'] as double));
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 20), decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text("Top Valeur (Global)", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              Expanded(
                child: topCards.isEmpty 
                  ? Center(child: Text("Aucune carte avec prix.", style: GoogleFonts.cinzel(color: Colors.white38)))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: topCards.length,
                      separatorBuilder: (_,__) => const Divider(color: Colors.white10),
                      itemBuilder: (ctx, i) {
                        final item = topCards[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: item['image'] != null ? Image.network(item['image'], width: 40, height: 56, fit: BoxFit.cover) : Container(width: 40, height: 56, color: Colors.grey[800], child: const Icon(Icons.image)),
                          ),
                          title: Text(item['name'], style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: RichText(
                            text: TextSpan(style: const TextStyle(color: Colors.white54, fontSize: 12), children: [const TextSpan(text: "Dans : "), TextSpan(text: "${item['wishlistName']}\n", style: const TextStyle(color: Colors.blueAccent)), TextSpan(text: "${item['quantity']}x  @ ${item['price']} €")]),
                          ),
                          trailing: Text("${(item['totalPrice'] as double).toStringAsFixed(2)} €", style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                        );
                      }
                    ),
              ),
            ],
          );
        }
      )
    );
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
                        IconButton(
                          icon: Icon(_isQuickAddMode ? Icons.close : Icons.flash_on),
                          color: _isQuickAddMode ? Colors.red : Colors.yellow,
                          onPressed: _toggleQuickAddMode,
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
                
                // BARRE DE CHARGEMENT DISCRÈTE (Pour l'arrière-plan)
                if (_isBackgroundLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: LinearProgressIndicator(minHeight: 2, color: Colors.yellow, backgroundColor: Colors.transparent),
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
                        // Onglet Collection
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
                        // Onglet Wishlists
                        _buildWishlistsTab(),
                        // Onglet Éditions
                        CollectionSetsTab(
                          collection: _collection,
                          onRefresh: () => _loadData(forceLoading: false), // Passer le callback pour le refresh
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistsTab() {
    return Column(
      children: [
        // Header Financier Global
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade900.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // FIX OVERFLOW : Expanded
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Wishlists", style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                    // FittedBox pour ajuster la taille du prix
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text("${_totalWishlistValue.toStringAsFixed(2)} €", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              // Partie Droite (Menu Popup)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                tooltip: "Actions Wishlist",
                color: const Color(0xFF1A1A1A),
                onSelected: (value) {
                  if (value == 'create') _showCreateWishlistDialog();
                  if (value == 'stats') _showGlobalWishlistTopCards();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'create',
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle, color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        Text('Créer une liste', style: GoogleFonts.cinzel(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'stats',
                    child: Row(
                      children: [
                        const Icon(Icons.analytics_outlined, color: Colors.amber),
                        const SizedBox(width: 12),
                        Text('Analyse Globale', style: GoogleFonts.cinzel(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => await _loadData(forceLoading: false),
            color: Colors.yellow.shade800,
            backgroundColor: const Color(0xFF1A1A1A),
            child: _wishlists.isEmpty 
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: Center(child: Text("Aucune wishlist créée.", style: GoogleFonts.cinzel(color: Colors.white38))))]
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _wishlists.length,
                  itemBuilder: (context, index) {
                    final list = _wishlists[index];
                    
                    // --- LOGIQUE DE L'IMAGE DE COUVERTURE ---
                    String? coverImageUrl;
                    
                    // 1. Choix manuel de l'utilisateur
                    if (list.iconScryfallId != null) {
                      try {
                        final card = _fullCardData.firstWhere((s) => s.id == list.iconScryfallId);
                        coverImageUrl = card.smallImageUrl ?? card.imageUrl;
                      } catch(e) {}
                    }
                    
                    // 2. Sinon : La carte la plus chère
                    if (coverImageUrl == null && list.cards.isNotEmpty) {
                      double maxPrice = -1.0;
                      ScryfallCard? mostExpensive;
                      
                      for (var c in list.cards) {
                        try {
                          final sc = _fullCardData.firstWhere((s) => s.id == c.scryfallId);
                          final price = double.tryParse(sc.prices['eur'] ?? '0') ?? 0.0;
                          if (price > maxPrice) {
                            maxPrice = price;
                            mostExpensive = sc;
                          }
                        } catch (e) {}
                      }
                      
                      if (mostExpensive != null) {
                        coverImageUrl = mostExpensive.smallImageUrl ?? mostExpensive.imageUrl;
                      }
                    }

                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.white.withOpacity(0.1))),
                      child: ListTile(
                        // --- AFFICHAGE DE L'IMAGE DANS LE LEADING ---
                        leading: Container(
                          width: 50, // Un peu plus large pour voir l'image
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900.withOpacity(0.3), 
                            borderRadius: BorderRadius.circular(8), // Forme carte
                            border: Border.all(color: Colors.white24)
                          ),
                          child: coverImageUrl != null 
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(coverImageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 20))
                              )
                            : const Icon(Icons.bookmark, color: Colors.blueAccent),
                        ),
                        title: Text(list.name, style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("${list.totalCards} cartes", style: const TextStyle(color: Colors.white54)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => WishlistDetailPage(wishlist: list)));
                          _loadData(forceLoading: false);
                        },
                        onLongPress: () async {
                           final del = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                             backgroundColor: const Color(0xFF1A1A1A),
                             title: const Text("Supprimer la liste ?", style: TextStyle(color: Colors.white)),
                             actions: [TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Non")), TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Oui", style: TextStyle(color: Colors.red)))],
                           ));
                           if(del == true) {
                             await _wishlistService.deleteWishlist(list.id);
                             _loadData(forceLoading: false);
                           }
                        },
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }
}