// Fichier : lib/pages/collection_page.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart'; 

import '../../models/scryfall_card_model.dart';
import '../../models/search_filters.dart';
import '../cards/card_detail_page.dart';
import '../../widgets/search/search_filter_modal.dart';
import '../../models/deck_model.dart'; 
import '../../services/collection_service.dart';
import '../../services/wishlist_service.dart';
import '../../services/local_card_service.dart'; // <-- Import du service local

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
  SearchFilters _activeFilters = SearchFilters(); 
  
  String _currentSort = 'Type';
  List<DeckCard> _collection = [];
  List<DeckCard> _wishlist = [];
  List<ScryfallCard> _fullCardData = [];
  bool _isLoading = true;
  bool _isImporting = false; // Pour le loader d'import

  double _totalCollectionValue = 0.0;
  double _totalWishlistValue = 0.0;
  double? _evolutionValue;
  double? _evolutionPercent;
  bool _hasCalculatedFinance = false;

  final RegExp _manaPipRegex = RegExp(r'\{([WUBRGCTPXYZS0-9/]+)\}');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    
    // On s'assure que le service local est chargé (silencieusement)
    _localCardService.loadLocalData().then((_) {
       if (mounted) setState(() {}); // Rafraîchir si le chargement finit pendant qu'on est là
    });
    
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceLoading = true}) async {
    if (forceLoading) {
      setState(() { _isLoading = true; });
    }

    await Future.wait([
      _collectionService.loadCollection().then((data) => _collection = data),
      _wishlistService.loadWishlist().then((data) => _wishlist = data),
    ]);
    
    if (!mounted) return;

    await _loadFullCardData(); 
    await _calculateFinancials();

    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  // --- LOGIQUE HYBRIDE (LOCAL + API) ---
  Future<void> _loadFullCardData() async {
    final allCards = [..._collection, ..._wishlist];
    
    // Liste des IDs uniques
    final uniqueIds = allCards
        .where((card) => card.scryfallId.isNotEmpty && !card.scryfallId.startsWith('LOCAL:'))
        .map((card) => card.scryfallId)
        .toSet()
        .toList();

    if (uniqueIds.isEmpty) {
      _fullCardData = [];
      return;
    }
    
    List<ScryfallCard> loadedCards = [];
    List<String> missingIds = []; // IDs non trouvés en local

    // 1. Recherche dans la base locale (Oracle)
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
      // Si pas chargé, tout doit venir de l'API
      missingIds = uniqueIds;
    }

    // 2. Récupération API pour les manquants (Batch)
    if (missingIds.isNotEmpty) {
      const int chunkSize = 75;
      for (var i = 0; i < missingIds.length; i += chunkSize) {
        final end = (i + chunkSize < missingIds.length) ? i + chunkSize : missingIds.length;
        final batch = missingIds.sublist(i, end);
        
        // Formatage pour l'endpoint /collection
        final requestBody = json.encode({'identifiers': batch.map((id) => {'id': id}).toList()});

        try {
          final response = await http.post(
            Uri.parse('https://api.scryfall.com/cards/collection'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          );
          
          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
            final List<ScryfallCard> batchCards = (data['data'] as List)
                .map((cardJson) => ScryfallCard.fromJson(cardJson))
                .toList();
            loadedCards.addAll(batchCards);
          }
        } catch (e) {
          log('Erreur chargement Scryfall (Batch): $e');
        }
      }
    }
    
    _fullCardData = loadedCards;
  }

  Future<void> _calculateFinancials() async {
    double tempColTotal = 0.0;
    for (var deckCard in _collection) {
       tempColTotal += _getCardPrice(deckCard.scryfallId) * deckCard.quantity;
    }
    _totalCollectionValue = tempColTotal;

    double tempWishTotal = 0.0;
    for (var deckCard in _wishlist) {
       tempWishTotal += _getCardPrice(deckCard.scryfallId) * deckCard.quantity;
    }
    _totalWishlistValue = tempWishTotal;
    
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

  double _getCardPrice(String scryfallId) {
    if (scryfallId.startsWith('LOCAL:')) return 0.0;
    try {
      final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == scryfallId);
      return double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _updateLocalQuantity(List<DeckCard> list, DeckCard card, int change, Function serviceUpdate) async {
    setState(() {
      card.quantity += change;
      if (card.quantity <= 0) {
        list.remove(card);
      }
    });
    _calculateFinancials(); 
    serviceUpdate();
  }

  Future<void> _showBulkImportDialog() async {
    final TextEditingController importController = TextEditingController();
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // On récupère la hauteur du clavier ET la hauteur de la barre de navigation
        final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final double navBarHeight = MediaQuery.of(context).padding.bottom;

        return Padding(
          // Padding externe : Pousse la modale au-dessus du clavier
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            // Padding interne : On ajoute la hauteur de la barre de nav au padding du bas (16 + navBarHeight)
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + navBarHeight),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Importation de masse", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                Text(
                  "Collez une liste de cartes (format Arena ou texte).\nEx: '4 Sol Ring' ou juste 'Sol Ring'.\nL'application gérera automatiquement les paquets de 75 cartes.",
                  style: GoogleFonts.roboto(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: importController,
                    maxLines: null,
                    expands: true,
                    style: GoogleFonts.cinzel(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "Collez votre liste ici...",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (importController.text.trim().isEmpty) return;
                    Navigator.pop(context); // Fermer la modale
                    _performBulkImport(importController.text);
                  },
                  icon: const Icon(Icons.download),
                  label: Text("Lancer l'importation", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
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
    
    // Découper par ligne
    List<String> lines = text.split('\n').where((s) => s.trim().isNotEmpty).toList();
    
    final result = await _collectionService.importBatchCards(lines);
    
    await _loadData(forceLoading: false); // Recharger la collection
    
    if (mounted) {
      setState(() { _isLoading = false; _isImporting = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Import terminé : ${result['added']} cartes ajoutées.", style: GoogleFonts.cinzel()),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  void _exportCurrentList() {
    final bool isWishlist = _tabController.index == 1;
    final List<DeckCard> sourceList = isWishlist ? _wishlist : _collection;
    final double totalValue = isWishlist ? _totalWishlistValue : _totalCollectionValue;
    final String title = isWishlist ? "Ma Wishlist Magic" : "Ma Collection Magic";

    if (sourceList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Rien à exporter !', style: GoogleFonts.cinzel()),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    StringBuffer sb = StringBuffer();
    sb.writeln(title);
    sb.writeln("====================");
    sb.writeln("Total cartes : ${sourceList.fold(0, (s, c) => s + c.quantity)}");
    sb.writeln("Valeur estimée : ${totalValue.toStringAsFixed(2)} €");
    sb.writeln("====================");
    sb.writeln("");

    final sortedList = List<DeckCard>.from(sourceList)..sort((a, b) => a.name.compareTo(b.name));

    for (var card in sortedList) {
      double price = _getCardPrice(card.scryfallId);
      String priceStr = price > 0 ? "(${price.toStringAsFixed(2)}€/u)" : "";
      sb.writeln("${card.quantity}x ${card.name} $priceStr");
    }

    sb.writeln("");
    sb.writeln("Généré par Magic Companion");

    Share.share(sb.toString());
  }

  List<DeckCard> _filterAndSortList(List<DeckCard> list) {
    final query = _searchController.text.toLowerCase();
    List<DeckCard> filtered = list.where((card) {
      final matchesName = card.name.toLowerCase().contains(query);
      if (!matchesName) return false;

      if (_activeFilters.cardType != null || _activeFilters.colors.isNotEmpty) {
        try {
          final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == card.scryfallId);
          if (_activeFilters.cardType != null) {
            if (!scryfallCard.typeLine.toLowerCase().contains(_activeFilters.cardType!.toLowerCase())) return false;
          }
          if (_activeFilters.colors.isNotEmpty) {
             final cardColors = scryfallCard.colorIdentity.toSet();
             if (!_activeFilters.colors.every((c) => cardColors.contains(c))) return false;
          }
        } catch (e) { return false; }
      }
      return true;
    }).toList();

    switch (_currentSort) {
      case 'Nom':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Prix':
        filtered.sort((a, b) {
          final priceA = _getCardPrice(a.scryfallId);
          final priceB = _getCardPrice(b.scryfallId);
          return priceB.compareTo(priceA);
        });
        break;
      case 'Couleur':
        filtered.sort((a, b) {
          final cA = _getCardColorIndex(a.scryfallId);
          final cB = _getCardColorIndex(b.scryfallId);
          return cA.compareTo(cB);
        });
        break;
      case 'Type':
      default:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    
    return filtered;
  }

  int _getCardColorIndex(String id) {
    try {
      final sc = _fullCardData.firstWhere((s) => s.id == id);
      if (sc.colorIdentity.isEmpty) return 10; 
      if (sc.colorIdentity.length > 1) return 6; 
      const map = {'W': 1, 'U': 2, 'B': 3, 'R': 4, 'G': 5};
      return map[sc.colorIdentity.first] ?? 10;
    } catch (e) { return 10; }
  }
  
  Future<void> _openFilterModal() async {
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => SearchFilterModal(initialFilters: _activeFilters),
    );
    if (newFilters != null) { setState(() => _activeFilters = newFilters); }
  }  
  Future<void> _copyForCardmarket() async {
    if (_wishlist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wishlist vide !")));
      return;
    }

    StringBuffer buffer = StringBuffer();
    // Format Cardmarket: "Quantité Nom" (Le set est optionnel mais conseillé si possible, format MKM est parfois strict)
    // Format le plus simple et compatible : "1 Black Lotus"
    
    for (var card in _wishlist) {
      // Nettoyage du nom pour éviter les problèmes (ex: retirer les // pour les cartes doubles si besoin)
      String cleanName = card.name.split(' // ')[0]; 
      buffer.writeln("${card.quantity} $cleanName");
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text("Copié !", style: GoogleFonts.cinzel(color: Colors.green)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Votre liste est dans le presse-papier au format :", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black,
                child: Text("4 Sol Ring\n2 Arcane Signet\n...", style: GoogleFonts.robotoMono(color: Colors.yellow, fontSize: 12)),
              ),
              const SizedBox(height: 8),
              const Text("Vous n'avez plus qu'à coller ça dans la section 'Wants > Bulk Import' de Cardmarket.", style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Génial"))
          ],
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
          color: Colors.black.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ma Collection', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      // BOUTON IMPORT (Nouveau)
                      IconButton(
                        icon: const Icon(Icons.file_upload_outlined),
                        color: Colors.yellow.shade700,
                        tooltip: 'Importer en masse',
                        onPressed: _showBulkImportDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        color: Colors.white,
                        tooltip: 'Exporter la liste',
                        onPressed: _exportCurrentList,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: _searchController,
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: GoogleFonts.cinzel(color: Colors.white54),
                  prefixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.filter_list, 
                          color: (_activeFilters.cardType != null || _activeFilters.colors.isNotEmpty) 
                              ? Colors.yellow.shade700 : Colors.white70),
                        onPressed: _openFilterModal,
                        tooltip: "Filtrer",
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.sort, color: _currentSort != 'Type' ? Colors.yellow.shade700 : Colors.white70),
                        tooltip: "Trier par...",
                        color: const Color(0xFF1A1A1A),
                        onSelected: (val) => setState(() => _currentSort = val),
                        itemBuilder: (context) => ['Type', 'Nom', 'Prix', 'Couleur'].map((choice) => 
                          PopupMenuItem(
                            value: choice, 
                            child: Text(choice, style: TextStyle(color: _currentSort == choice ? Colors.yellow : Colors.white))
                          )
                        ).toList(),
                      ),
                    ],
                  ),
                  suffixIcon: _searchController.text.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54), onPressed: () => _searchController.clear())
                      : const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
                onChanged: (val) => setState(() {}),
              ),
              
              TabBar(
                controller: _tabController,
                labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.cinzel(),
                indicatorColor: Colors.yellow.shade800,
                tabs: [
                  Tab(text: 'Collection (${_collection.fold(0, (sum, c) => sum + c.quantity)})'),
                  Tab(text: 'Wishlist (${_wishlist.fold(0, (sum, c) => sum + c.quantity)})'),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      if (_isImporting) ...[
                        const SizedBox(height: 16),
                        Text("Importation de masse en cours...", style: GoogleFonts.cinzel(color: Colors.yellow.shade700)),
                        const SizedBox(height: 8),
                        const Text("Traitement des paquets de 75 cartes (Scryfall Limit)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ]
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab Collection (Ton code existant pour l'affichage)
                    _buildCollectionTab(),
                    // Tab Wishlist (Ton code existant)
                    _buildWishlistTab(),
                  ],
                ),       
        ),
      ],
    );
  }

  Widget _buildCollectionTab() {
     return RefreshIndicator(
        onRefresh: () => _loadData(forceLoading: false),
        child: Column(
          children: [
             if (_hasCalculatedFinance) 
                _buildFinancialHeader(
                  title: "Valeur Collection", value: _totalCollectionValue, 
                  evoVal: _evolutionValue, evoPct: _evolutionPercent,
                  onDetailPressed: () => _showFinancialDetail(_collection, "Top Collection"),
                ),
             Expanded(child: _buildListView(listSource: _collection, isWishlist: false, emptyMessage: "Collection vide.")),
          ],
        ),
     );
  }

  Widget _buildWishlistTab() {
    return RefreshIndicator(
      onRefresh: () => _loadData(forceLoading: false),
      child: Column(
        children: [
          if (_hasCalculatedFinance)
            _buildFinancialHeader(
              title: "Coût Wishlist", value: _totalWishlistValue,
              evoVal: null, evoPct: null,
              onDetailPressed: () => _showFinancialDetail(_wishlist, "Top Wishlist"),
            ),
          
          // --- NOUVEAU BOUTON ICI ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 4.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("Copier pour Cardmarket (Mass Import)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade900.withOpacity(0.5),
                  foregroundColor: Colors.white,
                ),
                onPressed: _copyForCardmarket,
              ),
            ),
          ),
          // ---------------------------

          Expanded(child: _buildListView(listSource: _wishlist, isWishlist: true, emptyMessage: "Wishlist vide.")),
        ],
      ),
    );
  }

  Widget _buildFinancialHeader({
    required String title,
    required double value,
    double? evoVal,
    double? evoPct,
    required VoidCallback onDetailPressed,
  }) {
    final bool hasEvolution = evoVal != null;
    final isPositive = (evoVal ?? 0) >= 0;
    final color = isPositive ? Colors.green.shade400 : Colors.red.shade400;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    final sign = isPositive ? '+' : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.yellow.shade900.withOpacity(0.3), Colors.black.withOpacity(0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade800.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '${value.toStringAsFixed(2)} €',
                style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          if (hasEvolution)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Sur 7 jours', style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$sign${evoVal.toStringAsFixed(2)} €',
                      style: GoogleFonts.cinzel(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '($sign${evoPct!.toStringAsFixed(1)}%)',
                  style: GoogleFonts.cinzel(color: color.withOpacity(0.8), fontSize: 12),
                ),
              ],
            )
          else if (title.contains('Collection'))
             Text('Pas assez de données', style: GoogleFonts.cinzel(color: Colors.white38, fontSize: 10), textAlign: TextAlign.right),

          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            tooltip: 'Top Valorisation',
            onPressed: onDetailPressed,
          ),
        ],
      ),
    );
  }

  void _showFinancialDetail(List<DeckCard> sourceList, String title) {
    List<Map<String, dynamic>> topCards = [];
    
    for (final deckCard in sourceList) {
       if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
       try {
         final scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
         final double unitPrice = double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
         if (unitPrice > 0) {
           topCards.add({
             'name': scryfallCard.name,
             'unitPrice': unitPrice,
             'quantity': deckCard.quantity,
             'totalPrice': unitPrice * deckCard.quantity,
             'image': scryfallCard.smallImageUrl
           });
         }
       } catch (e) { /* ... */ }
    }

    topCards.sort((a, b) => (b['totalPrice'] as double).compareTo(a['totalPrice'] as double));
    final top10 = topCards.take(15).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text(title, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    sourceList == _wishlist 
                      ? 'Les cartes les plus coûteuses de votre liste de souhaits'
                      : 'Les cartes les plus précieuses de votre collection',
                    style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 14)
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: top10.length,
                      separatorBuilder: (ctx, i) => const Divider(color: Colors.white10),
                      itemBuilder: (context, index) {
                        final item = top10[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: item['image'] != null 
                                ? Image.network(item['image'], width: 40, height: 56, fit: BoxFit.cover)
                                : Container(width: 40, height: 56, color: Colors.grey.shade800),
                          ),
                          title: Text(item['name'], style: GoogleFonts.cinzel(color: Colors.white), overflow: TextOverflow.ellipsis),
                          subtitle: Text('${item['quantity']}x  @ ${item['unitPrice']} €', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: Text(
                            '${(item['totalPrice'] as double).toStringAsFixed(2)} €',
                            style: GoogleFonts.cinzel(color: Colors.yellow.shade700, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildListView({
    required List<DeckCard> listSource,
    required bool isWishlist,
    required String emptyMessage,
  }) {
    final filteredList = _filterAndSortList(listSource);

    if (filteredList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(child: Text(emptyMessage, style: GoogleFonts.cinzel(color: Colors.white70))),
        ],
      );
    }

    if (_currentSort == 'Type') {
       return _buildGroupedLayout(filteredList, listSource, isWishlist);
    } else {
       return _buildFlatLayout(filteredList, listSource, isWishlist);
    }
  }

  Widget _buildGroupedLayout(List<DeckCard> cards, List<DeckCard> originalSource, bool isWishlist) {
    final groupedList = _buildGroupedList(cards);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24.0, top: 8.0, left: 4.0, right: 4.0),
      itemCount: groupedList.length,
      itemBuilder: (context, index) {
        final group = groupedList[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Text('${group.title} (${group.cards.fold(0, (sum, c) => sum + c.quantity)})', 
                  style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...group.cards.map((card) => _buildCardTile(card, originalSource, isWishlist)),
          ],
        );
      },
    );
  }

  Widget _buildFlatLayout(List<DeckCard> cards, List<DeckCard> originalSource, bool isWishlist) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24.0, top: 8.0, left: 4.0, right: 4.0),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _buildCardTile(cards[index], originalSource, isWishlist);
      },
    );
  }

  Widget _buildCardTile(DeckCard card, List<DeckCard> originalSource, bool isWishlist) {
    ScryfallCard? scryfallCard;
    try {
        scryfallCard = _fullCardData.firstWhere((sc) => sc.id == card.scryfallId);
    } catch (e) { /* fallback */ }

    final imageUrl = scryfallCard?.smallImageUrl;
    final price = scryfallCard?.prices['eur']; 

    return Card(
      color: Colors.black.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        onTap: () {
          if (scryfallCard != null && !scryfallCard.id.startsWith('LOCAL:')) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => RecognitionResultPage(cardName: scryfallCard!.name)));
          }
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: imageUrl != null 
            ? Image.network(imageUrl, width: 40, height: 56, fit: BoxFit.cover)
            : Container(width: 40, height: 56, color: Colors.grey.shade800, child: const Icon(Icons.image_not_supported, size: 20)),
        ),
        title: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              _buildManaCostRow(scryfallCard?.manaCost),
              if (price != null)
                Text('$price €', style: TextStyle(color: Colors.yellow.shade700, fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
              onPressed: () => _updateLocalQuantity(
                originalSource, card, -1, 
                () => isWishlist 
                    ? _wishlistService.upsertCardInWishlist(scryfallId: card.scryfallId, cardName: card.name, quantityToAdd: -1)
                    : _collectionService.upsertCardInCollection(scryfallId: card.scryfallId, cardName: card.name, quantityToAdd: -1)
              ),
            ),
            Text('${card.quantity}', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
              onPressed: () => _updateLocalQuantity(
                originalSource, card, 1,
                () => isWishlist 
                    ? _wishlistService.upsertCardInWishlist(scryfallId: card.scryfallId, cardName: card.name, quantityToAdd: 1)
                    : _collectionService.upsertCardInCollection(scryfallId: card.scryfallId, cardName: card.name, quantityToAdd: 1)
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_GroupedCardList> _buildGroupedList(List<DeckCard> cardList) {
    Map<String, List<DeckCard>> groupedMap = {
      'Créatures': [], 'Planeswalkers': [], 'Sorts': [], 
      'Artefacts': [], 'Enchantements': [], 'Terrains': [], 'Autres': [],
    };
    for (final deckCard in cardList) {
      ScryfallCard? scryfallCard;
      try {
        if (deckCard.scryfallId.startsWith('LOCAL:')) throw Exception("Local");
        scryfallCard = _fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
      } catch (e) {
        scryfallCard = ScryfallCard.fromJson({
            'id': deckCard.scryfallId, 'name': deckCard.name, 
            'legalities': {}, 'prices': {}, 'lang': 'fr', 
            'type_line': deckCard.name, 'color_identity': [], 'mana_cost': '', 'cmc': 0.0,
            'set_name': '', 'set': '', 'collector_number': '', 'oracle_id': ''
        });
      }
      final type = _getPrimaryType(scryfallCard.typeLine);
      groupedMap[type]?.add(deckCard);
    }
    List<_GroupedCardList> groupedList = [];
    groupedMap.forEach((title, cards) {
      if (cards.isNotEmpty) {
        cards.sort((a, b) => a.name.compareTo(b.name));
        groupedList.add(_GroupedCardList(title: title, cards: cards));
      }
    });
    return groupedList;
  }
  
  String _getPrimaryType(String typeLine) {
    String lowerType = typeLine.toLowerCase();
    if (!lowerType.contains(' — ') && (lowerType.contains('swamp') || lowerType.contains('plains') || lowerType.contains('island') || lowerType.contains('mountain') || lowerType.contains('forest'))) return 'Terrains';
    if (lowerType.contains('creature')) return 'Créatures';
    if (lowerType.contains('planeswalker')) return 'Planeswalkers';
    if (lowerType.contains('land')) return 'Terrains';
    if (lowerType.contains('artifact')) return 'Artefacts';
    if (lowerType.contains('enchantment')) return 'Enchantements';
    if (lowerType.contains('instant')) return 'Sorts';
    if (lowerType.contains('sorcery')) return 'Sorts';
    return 'Autres';
  }  

  Widget _buildManaCostRow(String? manaCost) {
    if (manaCost == null || manaCost.isEmpty) { return const SizedBox.shrink(); }
    final List<String> symbols = _manaPipRegex.allMatches(manaCost).map((match) => match.group(0)!).toList();
    return Container(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.start, children: symbols.map((symbol) => Padding(padding: const EdgeInsets.symmetric(horizontal: 1.0), child: _getManaIcon(symbol))).toList()),
    );
  }
  Widget _getManaIcon(String symbol) {
    final String cleanSymbol = symbol.replaceAll(RegExp(r'[{}/]'), '').toUpperCase();
    return SvgPicture.network('https://svgs.scryfall.io/card-symbols/$cleanSymbol.svg', height: 14, width: 14, placeholderBuilder: (context) => Text(symbol, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14)));
  }
}

class _GroupedCardList {
  final String title;
  final List<DeckCard> cards;
  _GroupedCardList({required this.title, required this.cards});
}