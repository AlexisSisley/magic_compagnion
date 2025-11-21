// Fichier : lib/pages/collection_page.dart
// VERSION FINALE (Tri + Top Valo Wishlist + Refresh)

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/scryfall_card_model.dart';
import '../models/search_filters.dart';
import 'card_detail_page.dart';
import '../widgets/search/search_filter_modal.dart';
import '../models/deck_model.dart'; 
import '../services/collection_service.dart';
import '../services/wishlist_service.dart'; 

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> with TickerProviderStateMixin {
  final CollectionService _collectionService = CollectionService();
  final WishlistService _wishlistService = WishlistService();
  
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController(); 
  SearchFilters _activeFilters = SearchFilters(); 
  
  // Variable de tri
  String _currentSort = 'Type'; // Options: 'Type', 'Nom', 'Prix', 'Couleur'

  List<DeckCard> _collection = [];
  List<DeckCard> _wishlist = [];
  List<ScryfallCard> _fullCardData = [];
  bool _isLoading = true;

  // --- Données Financières ---
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

  Future<void> _loadFullCardData() async {
    final allCards = [..._collection, ..._wishlist];
    final uniqueCardIdentifiers = allCards
        .where((card) => card.scryfallId.isNotEmpty && !card.scryfallId.startsWith('LOCAL:'))
        .map((card) => {"id": card.scryfallId})
        .toSet()
        .toList();

    if (uniqueCardIdentifiers.isEmpty) {
      _fullCardData = [];
      return;
    }
    
    List<ScryfallCard> loadedCards = [];
    const int chunkSize = 75;
    
    for (var i = 0; i < uniqueCardIdentifiers.length; i += chunkSize) {
      final end = (i + chunkSize < uniqueCardIdentifiers.length) ? i + chunkSize : uniqueCardIdentifiers.length;
      final batch = uniqueCardIdentifiers.sublist(i, end);
      final requestBody = json.encode({'identifiers': batch});

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
        log('Erreur chargement Scryfall: $e');
      }
    }
    _fullCardData = loadedCards;
  }

  Future<void> _calculateFinancials() async {
    // 1. Calcul Collection
    double tempColTotal = 0.0;
    for (var deckCard in _collection) {
       tempColTotal += _getCardPrice(deckCard.scryfallId) * deckCard.quantity;
    }
    _totalCollectionValue = tempColTotal;

    // 2. Calcul Wishlist
    double tempWishTotal = 0.0;
    for (var deckCard in _wishlist) {
       tempWishTotal += _getCardPrice(deckCard.scryfallId) * deckCard.quantity;
    }
    _totalWishlistValue = tempWishTotal;
    
    // Sauvegarde historique collection uniquement
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
    // Recalcul rapide
    _calculateFinancials(); 
    serviceUpdate();
  }

  // --- LOGIQUE DE TRI ---

  List<DeckCard> _filterAndSortList(List<DeckCard> list) {
    // 1. Filtre
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

    // 2. Tri
    switch (_currentSort) {
      case 'Nom':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Prix':
        filtered.sort((a, b) {
          final priceA = _getCardPrice(a.scryfallId);
          final priceB = _getCardPrice(b.scryfallId);
          return priceB.compareTo(priceA); // Descendant (plus cher en premier)
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
        // Le tri par type est géré par le groupement plus tard
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    
    return filtered;
  }

  int _getCardColorIndex(String id) {
    try {
      final sc = _fullCardData.firstWhere((s) => s.id == id);
      if (sc.colorIdentity.isEmpty) return 10; // Incolore/Artefact
      if (sc.colorIdentity.length > 1) return 6; // Multicolore
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

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- En-tête ---
        Container(
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0.0),
          color: Colors.black.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ma Collection', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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

        // --- Contenu ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // ONGLET COLLECTION
                    RefreshIndicator(
                      onRefresh: () => _loadData(forceLoading: false),
                      color: Colors.yellow.shade800,
                      backgroundColor: const Color(0xFF1A1A1A),
                      child: Column(
                        children: [
                          if (_hasCalculatedFinance) 
                            _buildFinancialHeader(
                              title: "Valeur Collection",
                              value: _totalCollectionValue,
                              evoVal: _evolutionValue,
                              evoPct: _evolutionPercent,
                              onDetailPressed: () => _showFinancialDetail(_collection, "Top Collection"),
                            ),
                          Expanded(
                            child: _buildListView(
                              listSource: _collection,
                              isWishlist: false,
                              emptyMessage: "Votre collection est vide."
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // ONGLET WISHLIST
                    RefreshIndicator(
                      onRefresh: () => _loadData(forceLoading: false),
                      color: Colors.yellow.shade800,
                      backgroundColor: const Color(0xFF1A1A1A),
                      child: Column(
                        children: [
                          if (_hasCalculatedFinance) 
                            _buildFinancialHeader(
                              title: "Coût estimé Wishlist",
                              value: _totalWishlistValue,
                              evoVal: null,
                              evoPct: null,
                              // --- AJOUTÉ ICI : Le bouton Top Valo pour Wishlist ---
                              onDetailPressed: () => _showFinancialDetail(_wishlist, "Top Wishlist"),
                            ),
                          Expanded(
                            child: _buildListView(
                              listSource: _wishlist,
                              isWishlist: true,
                              emptyMessage: "Votre wishlist est vide."
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // --- WIDGET : En-tête Financier ---
  Widget _buildFinancialHeader({
    required String title,
    required double value,
    double? evoVal,
    double? evoPct,
    required VoidCallback onDetailPressed, // <-- Callback ajouté
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

          // Bouton Détails (Toujours affiché maintenant via le callback)
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            tooltip: 'Top Valorisation',
            onPressed: onDetailPressed,
          ),
        ],
      ),
    );
  }

  // --- MODALE : Détail Financier (Modifiée pour prendre une source) ---
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

  // --- CONSTRUCTION DE LA LISTE ---

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

  // --- Helpers ---
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
        // Tri interne si on est en mode 'Type' (par nom par défaut)
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